#!/usr/bin/env python3
"""Build HaulwiseData/Data.lua for WoW Forever from QuestieDB's Forever dataset (GPLv3,
https://github.com/Questie/QuestieDB): profession trainers and recipe vendors with their
positions, the quests that need each item, and where items drop and who sells them.

Usage: python3 tools/build-haulwise-data.py <path to a QuestieDB checkout> [out file]
Only reads Lua tables; never runs QuestieDB code beyond returning its data literals.
"""
import sys, os, re
import lupa.lua51 as L

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "HaulwiseData", "Data.lua")
lua = L.LuaRuntime(unpack_returned_tuples=True)
# The data files assign strings like QuestieDB.npcData = [[return {...}]]; give them a stub loader.
lua.execute('''
local mods = {}
QuestieLoader = { ImportModule = function(_, name) mods[name] = mods[name] or { private = {} }; return mods[name] end }
MODS = mods
''')
def run(path):
    lua.execute(open(path, encoding="utf-8").read())
run(os.path.join(src, "data/Forever/foreverNpcDB.lua"))
run(os.path.join(src, "data/Forever/foreverItemDB.lua"))
run(os.path.join(src, "data/Forever/foreverQuestDB.lua"))
run(os.path.join(src, "support/Forever/Zones/areaIdToUiMapId.lua"))
lua.execute('''
local Q = MODS.QuestieDB
NPCS = loadstring(Q.npcData)()
ITEMS = loadstring(Q.itemData)()
QUESTS = loadstring(Q.questData)()
QK = Q.questKeys
local Z = MODS.ZoneDB.private
AREA = loadstring(Z.areaIdToUiMapId)()
local over = Z.areaIdToUiMapIdOverride and loadstring(Z.areaIdToUiMapIdOverride)() or {}
for k, v in pairs(over) do AREA[k] = v end
NK = Q.npcKeys
IK = Q.itemKeys
''')
g = lua.globals()
NK, IK, QK = g.NK, g.IK, g.QK

PROFS = {
    "Alchemy": ["Alchemy", "Alchemist"], "Blacksmithing": ["Blacksmith", "Armorsmith", "Weaponsmith"],
    "Cooking": ["Cooking", "Cook", "Chef"], "Enchanting": ["Enchant"], "Engineering": ["Engineer", "Gnomish", "Goblin Engineer"],
    "First Aid": ["First Aid"], "Fishing": ["Fishing", "Fisherman"], "Herbalism": ["Herbalis"],
    "Leatherworking": ["Leatherwork", "Dragonscale", "Elemental Leather", "Tribal Leather"], "Mining": ["Mining", "Miner"],
    "Skinning": ["Skinning", "Skinner"], "Tailoring": ["Tailor"],
}
TRAINER, VENDOR = 16, 4

def prof_of(sub):
    if not sub: return None
    for p, words in PROFS.items():
        for w in words:
            if w.lower() in sub.lower(): return p
    return None

def spawns(npc):
    sp = npc[NK.spawns]
    out = []
    if not sp: return out
    for area, pts in sp.items():
        ui = g.AREA[area]
        if not ui or ui == 0 or not pts: continue
        for pt in pts.values():
            x, y = pt[1], pt[2]
            if x is None or x < 0: continue
            out.append((int(ui), round(float(x), 2), round(float(y), 2)))
            if len(out) >= 3: return out
    return out

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

npcs, trainers, vendors = {}, {}, {}
for nid, n in g.NPCS.items():
    flags = n[NK.npcFlags] or 0
    sub = n[NK.subName]
    if flags & TRAINER:
        p = prof_of(sub)
        if p and "World " not in (n[NK.name] or ""):
            s = spawns(n)
            if s:
                npcs[nid] = n; trainers.setdefault(p, []).append(nid)

for iid, it in g.ITEMS.items():
    if it[IK["class"]] != 9: continue  # recipes
    vs = it[IK.vendors]
    if not vs: continue
    ids = []
    for v in vs.values():
        n = g.NPCS[v]
        if n and spawns(n):
            npcs[v] = n; ids.append(v)
    if ids: vendors[iid] = sorted(set(ids))

# Quests that need an item: item objectives and items the quest needs that aren't objectives.
ALLIANCE, HORDE = 1 | 4 | 8 | 64, 2 | 16 | 32 | 128
def faction(mask):
    mask = int(mask or 0)
    a, h = mask & ALLIANCE, mask & HORDE
    return "A" if a and not h else "H" if h and not a else ""

quests, quest_items = {}, {}
for qid, q in g.QUESTS.items():
    needed = []
    obj = q[QK.objectives]
    if obj and obj[3]:
        for e in obj[3].values():
            if e and e[1]: needed.append(int(e[1]))
    req = q[QK.requiredSourceItems]
    if req:
        for i in req.values(): needed.append(int(i))
    provided = q[QK.sourceItemId]
    needed = [i for i in needed if i != provided]
    if not needed or not q[QK.name]: continue
    quests[int(qid)] = (q[QK.name], int(q[QK.questLevel] or 0), int(q[QK.requiredLevel] or 0), faction(q[QK.requiredRaces]))
    for i in set(needed): quest_items.setdefault(i, []).append(int(qid))

# Where items come from: who sells them (up to 3) and which mobs drop them (up to 6; items that
# drop from more than 12 mobs are world drops and just say so).
MAX_VENDORS, MAX_DROPS, WORLD_DROP = 3, 6, 12
def first_map(n):
    s = spawns(n)
    return s[0][0] if s else 0
src_npcs, sources = {}, {}
for iid, it in g.ITEMS.items():
    vend, drops, world = [], [], 0
    vs = it[IK.vendors]
    if vs:
        for v in list(vs.values())[:MAX_VENDORS]:
            n = g.NPCS[v]
            if n and n[NK.name]: vend.append(int(v)); src_npcs[int(v)] = (n[NK.name], first_map(n))
    ds = it[IK.npcDrops]
    if ds:
        ds = list(ds.values())
        if len(ds) > WORLD_DROP: world = len(ds)
        else:
            for d in ds[:MAX_DROPS]:
                n = g.NPCS[d]
                if n and n[NK.name]: drops.append(int(d)); src_npcs[int(d)] = (n[NK.name], first_map(n))
            if len(ds) > MAX_DROPS: world = len(ds)
    if vend or drops or world: sources[int(iid)] = (vend, drops, world)

lines = ["-- Haulwise Data: profession trainers and recipe vendors for WoW Forever, with positions,",
         "-- the quests that need each item, and where items drop and who sells them.",
         "-- Generated by tools/build-haulwise-data.py from QuestieDB's Forever dataset",
         "-- (https://github.com/Questie/QuestieDB, GPLv3; thanks to the Questie team and contributors).",
         "-- This file is licensed under the GNU GPL v3; see LICENSE.md.",
         "HaulwiseData = {", "    version = 1,", "    npcs = {"]
for nid in sorted(npcs):
    n = npcs[nid]
    fac = n[NK.friendlyToFaction] or ""
    pos = ", ".join("{ %d, %.2f, %.2f }" % s for s in spawns(n))
    lines.append('        [%d] = { "%s", "%s", "%s", %s },' % (nid, esc(n[NK.name] or "?"), esc(n[NK.subName] or ""), fac, pos))
lines.append("    },")
lines.append("    trainers = {")
for p in sorted(trainers):
    lines.append('        ["%s"] = { %s },' % (p, ", ".join(str(i) for i in sorted(trainers[p]))))
lines.append("    },")
lines.append("    recipeVendors = {")
for iid in sorted(vendors):
    lines.append("        [%d] = { %s }," % (iid, ", ".join(str(i) for i in vendors[iid])))
lines.append("    },")
# quests[id] = { name, level, required level, faction ("A", "H" or "" for both) }
lines.append("    quests = {")
for qid in sorted(quests):
    n, lvl, req, fac = quests[qid]
    lines.append('        [%d] = { "%s", %d, %d, "%s" },' % (qid, esc(n), lvl, req, fac))
lines.append("    },")
# questItems[itemID] = { quest IDs that need it }
lines.append("    questItems = {")
for iid in sorted(quest_items):
    lines.append("        [%d] = { %s }," % (iid, ", ".join(str(q) for q in sorted(set(quest_items[iid])))))
lines.append("    },")
# sources[itemID] = { { vendor NPC IDs }, { NPC IDs it drops from }, world-drop mob count or 0 }
lines.append("    sources = {")
for iid in sorted(sources):
    v, d, w = sources[iid]
    lines.append("        [%d] = { { %s }, { %s }, %d }," % (iid, ", ".join(map(str, v)), ", ".join(map(str, d)), w))
lines.append("    },")
# sourceNpcs[npcID] = { name, map number of its first spawn (0 if none) }
lines.append("    sourceNpcs = {")
for nid in sorted(src_npcs):
    n, m = src_npcs[nid]
    lines.append('        [%d] = { "%s", %d },' % (nid, esc(n), m))
lines.append("    },")
lines.append("}")
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("quests", len(quests), "quest items", len(quest_items), "item sources", len(sources), "source npcs", len(src_npcs))
print("npcs", len(npcs), "trainers", {p: len(v) for p, v in trainers.items()}, "recipes with vendors", len(vendors), "->", out)
