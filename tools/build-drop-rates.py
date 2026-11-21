#!/usr/bin/env python3
"""Build HaulwiseData/Drops.lua: estimated drop rates and coins per kill for WoW Forever's mobs.

The rates come from the CMaNGOS Classic DB (GPLv3, https://github.com/cmangos/classic-db), an
open-source reconstruction of Classic's loot tables. Only mobs that exist in QuestieDB's Forever
dataset are kept, with Forever's names, levels and zones. Forever may have changed some loot, so
Haulwise treats these numbers as a starting estimate that real kills (yours and shared) take over.

Usage: python3 tools/build-drop-rates.py <classic-db checkout> <QuestieDB checkout> [out file]
Reads the SQL dump as text and QuestieDB's data literals; runs no code from either.
"""
import gzip, glob, os, sys
import lupa.lua51 as L

cdb, qdb = sys.argv[1], sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(__file__), "..", "HaulwiseData", "Drops.lua")

MIN_CHANCE = 0.005   # drops under 0.5% add little to gold per hour and a lot to the file
MAX_ITEMS = 15       # per mob, most likely first

# --- SQL dump: INSERT INTO `table` VALUES (...),(...); -----------------------------------------
def tuples(sql_values):
    """Split a VALUES list into tuples of Python values (str, int, float, None)."""
    rows, row, field, i, n = [], [], [], 0, len(sql_values)
    in_str, depth = False, 0
    while i < n:
        c = sql_values[i]
        if in_str:
            if c == "\\" and i + 1 < n:
                field.append(sql_values[i + 1]); i += 2; continue
            if c == "'":
                if i + 1 < n and sql_values[i + 1] == "'": field.append("'"); i += 2; continue
                in_str = False
            else:
                field.append(c)
        elif c == "'":
            in_str = True; field.append("\0")  # marks a string field
        elif c == "(":
            depth += 1
            if depth == 1: row, field = [], []
        elif c == ")":
            depth -= 1
            if depth == 0:
                row.append(value("".join(field))); rows.append(row)
        elif c == "," and depth == 1:
            row.append(value("".join(field))); field = []
        elif depth >= 1:
            field.append(c)
        i += 1
    return rows

def value(s):
    if s.startswith("\0"): return s[1:]
    s = s.strip()
    if s == "NULL": return None
    try: return int(s)
    except ValueError:
        try: return float(s)
        except ValueError: return s

def table_rows(dump, name):
    head = "INSERT INTO `%s` VALUES " % name
    rows = []
    for line in dump:
        if line.startswith(head):
            rows.extend(tuples(line[len(head):].rstrip().rstrip(";")))
    return rows

path = sorted(glob.glob(os.path.join(cdb, "Full_DB", "*.sql.gz")))[-1]
with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
    dump = [l for l in f if l.startswith("INSERT INTO `creature_template`") or l.startswith("INSERT INTO `creature_loot_template`")
            or l.startswith("INSERT INTO `reference_loot_template`") or l.startswith("INSERT INTO `skinning_loot_template`")]

# creature_template columns (0-based): Entry 0, Family 11, CreatureType 12, Rank 33, MinLootGold 54,
# MaxLootGold 55, LootId 56, SkinningLootId 58
templates = {}
for r in table_rows(dump, "creature_template"):
    templates[r[0]] = {"rank": r[33], "gold": ((r[54] or 0) + (r[55] or 0)) / 2, "loot": r[56] or 0, "skin": r[58] or 0,
                       "type": r[12] or 0, "family": r[11] or 0}

def loot_table(name):
    t = {}
    for r in table_rows(dump, name):
        t.setdefault(r[0], []).append({"item": r[1], "chance": r[2], "group": r[3], "min": r[4], "max": r[5], "cond": r[6]})
    return t

creature_loot, reference_loot, skinning_loot = loot_table("creature_loot_template"), loot_table("reference_loot_template"), loot_table("skinning_loot_template")

def drops(table, entry, scale=1.0, out=None, depth=0):
    """Chance per kill (0-1) and average count, per item, for one loot entry."""
    out = {} if out is None else out
    if depth > 4: return out
    rows = table.get(entry, [])
    groups = {}
    for r in rows:
        if r["chance"] < 0 or r["cond"]: continue   # quest items and conditional loot
        groups.setdefault(r["group"], []).append(r)
    for g, rs in groups.items():
        if g == 0:
            shares = [(r, r["chance"] / 100) for r in rs]
        else:  # one item per group roll: the zero-chance ones share what's left
            fixed = sum(r["chance"] for r in rs if r["chance"] > 0) / 100
            zero = [r for r in rs if r["chance"] == 0]
            rest = max(0.0, 1 - fixed) / len(zero) if zero else 0
            shares = [(r, r["chance"] / 100 if r["chance"] > 0 else rest) for r in rs]
        for r, p in shares:
            p *= scale
            if p <= 0: continue
            if r["min"] < 0:   # a reference to a shared loot table, rolled maxcount times
                drops(reference_loot, -r["min"], p * max(1, r["max"]), out, depth + 1)
                continue
            e = out.setdefault(r["item"], [0.0, 0.0])
            e[0] = min(1.0, e[0] + p)
            e[1] += p * (r["min"] + r["max"]) / 2
    return out

# --- QuestieDB: which mobs are in Forever, with Forever's names, levels and zones --------------
lua = L.LuaRuntime(unpack_returned_tuples=True)
lua.execute('''local mods = {}
QuestieLoader = { ImportModule = function(_, name) mods[name] = mods[name] or { private = {} }; return mods[name] end }
MODS = mods''')
for f in ["data/Forever/foreverNpcDB.lua", "support/Forever/Zones/areaIdToUiMapId.lua"]:
    lua.execute(open(os.path.join(qdb, f), encoding="utf-8").read())
lua.execute('''local Q = MODS.QuestieDB
NPCS = loadstring(Q.npcData)()
NK = Q.npcKeys
local Z = MODS.ZoneDB.private
AREA = loadstring(Z.areaIdToUiMapId)()
local over = Z.areaIdToUiMapIdOverride and loadstring(Z.areaIdToUiMapIdOverride)() or {}
for k, v in pairs(over) do AREA[k] = v end''')
g = lua.globals()
NK = g.NK

def main_map(n):
    sp = n[NK.spawns]
    best, most = 0, 0
    if not sp: return 0
    for area, pts in sp.items():
        ui = g.AREA[area]
        cnt = len(list(pts.values())) if pts else 0
        if ui and ui != 0 and cnt > most: best, most = int(ui), cnt
    return best

def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"')

mobs = {}
for nid, n in g.NPCS.items():
    nid = int(nid)
    t = templates.get(nid)
    if not t or t["rank"] != 0: continue          # normal mobs only: elites and bosses aren't farms
    # Friendly to one faction (guards, townsfolk) or an NPC with a job: not a mob to farm.
    # "AH" is neutral to both, like most beasts: those are farms.
    if n[NK.friendlyToFaction] in ("A", "H") or (n[NK.npcFlags] or 0) or n[NK.subName]: continue
    if not n[NK.name]: continue
    items = drops(creature_loot, t["loot"]) if t["loot"] else {}
    skin = drops(skinning_loot, t["skin"]) if t["skin"] else {}
    def pack(d):
        best = sorted(((i, e) for i, e in d.items() if e[0] >= MIN_CHANCE), key=lambda x: -x[1][0])[:MAX_ITEMS]
        # item:chance%:average count when it drops
        return "/".join("%d:%g:%g" % (i, round(e[0] * 100, 2), round(e[1] / e[0], 2) if e[0] else 1) for i, e in best)
    di, si = pack(items), pack(skin)
    if not di and not t["gold"]: continue
    m = main_map(n)
    if not m: continue
    mobs[nid] = (n[NK.name], int(n[NK.minLevel] or 0), int(n[NK.maxLevel] or 0), m, int(t["gold"]), di, si,
                 int(t["type"]), int(t["family"]))

lines = [
    "-- Haulwise Data: estimated drop rates and coins per kill for WoW Forever's mobs.",
    "-- Generated by tools/build-drop-rates.py from the CMaNGOS Classic DB (GPLv3,",
    "-- https://github.com/cmangos/classic-db; thanks to the CMaNGOS team and contributors), with",
    "-- Forever's mob names, levels and zones from QuestieDB (GPLv3). Licensed under the GNU GPL v3.",
    "-- [npcID] = { name, min level, max level, map number, coins per kill (copper),",
    "--             \"item:chance%:count/...\" (loot), \"item:chance%:count/...\" (skinning),",
    "--             creature type (1 beast ... 7 humanoid ...), beast family (1 wolf, 3 spider ...) }",
    "HaulwiseData = HaulwiseData or {}",
    "HaulwiseData.estimates = {",
]
for nid in sorted(mobs):
    name, lo, hi, m, gold, di, si, ty, fam = mobs[nid]
    lines.append('    [%d] = { "%s", %d, %d, %d, %d, "%s", "%s", %d, %d },' % (nid, esc(name), lo, hi, m, gold, di, si, ty, fam))
lines.append("}")
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("mobs with estimates", len(mobs), "->", out)
