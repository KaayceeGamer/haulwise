// Parses and validates a Haulwise export string ("/haul export"). Mirrors GP:ImportString in Share.lua.
// Anything implausible is rejected outright rather than "cleaned", so broken or fake uploads
// never reach the database.

export type Counts = [number, number, number][]; // [itemID, kills it dropped on, total quantity]

export interface Mob {
  npc: number; name: string | null; minL: number | null; maxL: number | null;
  kills: number; money: number; gathered: number; pp: number; ppMoney: number;
  tIntervals: number; tSeconds: number; zones: Record<string, number>;
  items: Counts; gather: Counts; ppItems: Counts;
}

export interface Trainer { recipe: string; npc: string; zone: string; cost: number; skill: number; prof: string }
export interface Vendor { recipe: string; npc: string; zone: string; price: number; limited: boolean; item: number }
export interface Place { npc: number; name: string; kind: string; prof: string; fac: string; map: number; x: number; y: number }
export interface Craft { out: number; qty: number; prof: string; reagents: [number, number][] }
export interface Extra {
  trainers: Trainer[];
  vendors: Vendor[];
  buys: [number, number][];        // [itemID, price a vendor sells it for]
  recipeItems: [string, number][]; // [recipe name, itemID of the pattern]
  places: Place[];                 // where trainers and vendors stand (for waypoints)
  crafts: Craft[];                 // recipes players know: what they make and from what
}
export interface Parsed { uid: string; build: string; mobs: Mob[]; kills: number; extra: Extra }

const MAX_LEN = 2_000_000;
const MAX_MOBS = 5000;
const MAX_ITEMS = 300;
const MAX_EXTRA = 5000;

function text(s: string | undefined, what: string): string {
  const t = (s ?? "").trim();
  if (t.length === 0 || t.length > 80 || /[|<>]/.test(t)) throw new Error(`bad text in ${what}`);
  return t;
}

function int(s: string | undefined, max: number, what: string): number {
  if (s === undefined || !/^\d+$/.test(s)) throw new Error(`bad number in ${what}`);
  const n = Number(s);
  if (!Number.isSafeInteger(n) || n > max) throw new Error(`${what} out of range`);
  return n;
}

function counts(s: string, trials: number, what: string): Counts {
  const out: Counts = [];
  if (!s) return out;
  const seen = new Set<number>();
  for (const part of s.split("/")) {
    const m = /^(\d+):(\d+):(\d+)$/.exec(part);
    if (!m) throw new Error(`bad item in ${what}`);
    const id = int(m[1], 9_999_999, what);
    const k = int(m[2], trials, `${what} (dropped more often than killed)`);
    const q = int(m[3], k * 200, `${what} quantity`);
    if (id === 0 || q < k || seen.has(id)) throw new Error(`bad item in ${what}`);
    seen.add(id);
    out.push([id, k, q]);
  }
  if (out.length > MAX_ITEMS) throw new Error(`too many items in ${what}`);
  return out;
}

function zones(s: string): Record<string, number> {
  const out: Record<string, number> = {};
  if (!s) return out;
  for (const part of s.split("/").slice(0, 20)) {
    const m = /^(.{1,60}):(\d+)$/.exec(part);
    if (m) out[m[1].trim()] = int(m[2], 100_000, "zone");
  }
  return out;
}

function extraRecord(kind: string, f: string[], extra: Parsed["extra"]): void {
  if (kind === "T") {
    extra.trainers.push({ recipe: text(f[1], "trainer recipe").toLowerCase(), npc: text(f[2], "trainer name"),
      zone: text(f[3], "trainer zone"), cost: int(f[4], 100_000_000, "trainer cost"), skill: int(f[5], 1000, "trainer skill"),
      prof: (f[6] ?? "").trim().slice(0, 40) });
  } else if (kind === "V") {
    extra.vendors.push({ recipe: text(f[1], "vendor recipe").toLowerCase(), npc: text(f[2], "vendor name"),
      zone: text(f[3], "vendor zone"), price: int(f[4], 100_000_000, "vendor price"), limited: f[5] === "1",
      item: int(f[6], 9_999_999, "vendor item") });
  } else if (kind === "P") {
    const coord = (v: string | undefined, what: string) => {
      if (!v || !/^\d{1,3}(\.\d{1,2})?$/.test(v) || Number(v) > 100) throw new Error(`bad ${what}`);
      return Number(v);
    };
    const k = (f[3] ?? "").trim();
    if (k !== "T" && k !== "V") throw new Error("bad place kind");
    const fac = (f[5] ?? "").trim();
    extra.places.push({ npc: int(f[1], 9_999_999, "place npc"), name: text(f[2], "place name"), kind: k,
      prof: (f[4] ?? "").trim().slice(0, 40), fac: fac === "A" || fac === "H" ? fac : "",
      map: int(f[6], 99_999, "place map"), x: coord(f[7], "place x"), y: coord(f[8], "place y") });
  } else if (kind === "C") {
    const reagents: [number, number][] = [];
    for (const part of (f[4] ?? "").split("/")) {
      const m = /^(\d+):(\d+)$/.exec(part);
      if (!m) throw new Error("bad craft reagent");
      reagents.push([int(m[1], 9_999_999, "craft reagent"), int(m[2], 200, "craft reagent count")]);
    }
    if (reagents.length === 0 || reagents.length > 12) throw new Error("bad craft reagents");
    const qty = int(f[2], 100, "craft count");
    extra.crafts.push({ out: int(f[1], 9_999_999, "craft item"), qty: Math.max(1, qty),
      prof: text(f[3], "craft profession").slice(0, 40), reagents });
  } else if (kind === "B") {
    extra.buys.push([int(f[1], 9_999_999, "vendor item"), int(f[2], 100_000_000, "vendor price")]);
  } else {
    extra.recipeItems.push([text(f[1], "recipe").toLowerCase(), int(f[2], 9_999_999, "recipe item")]);
  }
}

export function parseExport(raw: string): Parsed {
  const str = raw.trim();
  if (str.length > MAX_LEN) throw new Error("upload too large");
  const records = str.split(";");
  const head = records[0].split(",");
  if ((head[0] !== "CF1" && head[0] !== "CF2") || !/^[0-9a-f]{8,32}$/.test(head[1] ?? "")) {
    throw new Error("not a Haulwise export string (use /haul export in game)");
  }
  const uid = head[1];
  const build = /^[\d.]{1,20}$/.test(head[4] ?? "") ? head[4] : "";
  if (records.length - 1 > MAX_MOBS) throw new Error("too many mobs");

  const mobs: Mob[] = [];
  const seen = new Set<number>();
  const extra: Extra = { trainers: [], vendors: [], buys: [], recipeItems: [], places: [], crafts: [] };
  let kills = 0;
  for (let i = 1; i < records.length; i++) {
    const f = records[i].split(",");
    const kind = f[0];
    // Trainer, vendor, price and recipe records are extras: one bad one (an empty name from an
    // older addon version) is skipped instead of throwing the whole upload away.
    if (kind === "T" || kind === "V" || kind === "B" || kind === "R" || kind === "P" || kind === "C") {
      try { extraRecord(kind, f, extra); } catch { /* skip this record */ }
      continue;
    }
    // A record type from a newer addon version: skip it instead of failing the upload.
    if (/^[A-Z]$/.test(kind)) continue;
    if (f.length < 15) throw new Error(`record ${i} is cut short`);
    const what = `mob ${f[0]}`;
    const npc = int(f[0], 9_999_999, what);
    if (npc === 0 || seen.has(npc)) throw new Error(`bad or duplicate ${what}`);
    seen.add(npc);
    const k = int(f[4], 100_000, `${what} kills`);
    if (k === 0) continue;
    const gathered = int(f[6], k, `${what} gathered`);
    const pp = int(f[7], 100_000, `${what} pickpockets`);
    const tIntervals = int(f[9], k, `${what} timing`);
    const tSeconds = int(f[10], 1e9, `${what} timing`);
    if (tIntervals > 0 && tSeconds / tIntervals < 2) throw new Error(`${what}: kills faster than 2s apart`);
    const minL = int(f[2], 100, `${what} level`);
    const maxL = int(f[3], 100, `${what} level`);
    mobs.push({
      npc, name: f[1].trim().slice(0, 80) || null,
      minL: minL || null, maxL: maxL || null,
      kills: k,
      money: int(f[5], k * 1_000_000, `${what} coins`),   // at most 100 gold per kill
      gathered, pp, ppMoney: int(f[8], pp * 1_000_000, `${what} pickpocket coins`),
      tIntervals, tSeconds, zones: zones(f[11]),
      items: counts(f[12], k, `${what} drops`),
      gather: counts(f[13], gathered, `${what} gathering`),
      ppItems: counts(f[14], pp, `${what} pickpocket`),
    });
    kills += k;
  }
  for (const [k, list] of Object.entries(extra)) {
    if ((list as unknown[]).length > MAX_EXTRA) throw new Error(`too many ${k}`);
  }
  if (mobs.length === 0 && extra.trainers.length + extra.vendors.length + extra.buys.length + extra.places.length + extra.crafts.length === 0) {
    throw new Error("nothing to share yet: kill and loot something, or visit a trainer or vendor");
  }
  return { uid, build, mobs, kills, extra };
}
