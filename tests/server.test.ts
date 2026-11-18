// Server test: real Postgres (PGlite), the real migration, the real upload parser.
// Run: node --experimental-strip-types tests/server.test.ts
import { PGlite } from "@electric-sql/pglite";
import { readFileSync, writeFileSync } from "node:fs";
import { parseExport } from "../supabase/functions/submit/parse.ts";

let failures = 0;
const check = (ok: boolean, msg: string) => { console.log(`${ok ? "ok  " : "FAIL"} ${msg}`); if (!ok) failures++; };

let seed = 7;
const rand = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);

// Build an export string like /haul export makes.
function exportString(uid: string, mobs: { npc: number; name: string; kills: number; meat: number; claw: number }[]) {
  const recs = [`CF1,${uid},Somebody,1763340000,1.60.1`];
  for (const m of mobs) {
    let meat = 0, claw = 0, money = 0;
    for (let i = 0; i < m.kills; i++) {
      if (rand() < m.meat) meat++;
      if (rand() < m.claw) claw++;
      money += 30;
    }
    const items = [`2673:${meat}:${meat}`, claw ? `5635:${claw}:${claw}` : ""].filter(Boolean).join("/");
    const skinned = Math.floor(m.kills * 0.8);
    recs.push([m.npc, m.name, 10, 11, m.kills, money, skinned, 0, 0, m.kills - 1, (m.kills - 1) * 45,
      "Mulgore:" + m.kills, items, `4234:${skinned}:${skinned}`, ""].join(","));
  }
  return recs.join(";");
}

// --- Parser
const good = exportString("a1b2c3d4e5f60718", [{ npc: 113, name: "Coyote", kills: 400, meat: 0.39, claw: 0.01 }]);
check(parseExport(good).mobs[0].kills === 400, "parser reads a normal export");
const bad: [string, string][] = [
  ["hello", "garbage"],
  [good.replace(",400,", ",400000,"), "impossible kill count"],
  [good.replace(/2673:\d+:/, "2673:999:"), "item dropped more often than killed"],
  [good.replace(",399,17955,", ",399,100,"), "kills faster than 2s apart"],
  [good.replace(",12000,", ",999999999,"), "100+ gold per kill"],
];
for (const [s, why] of bad) {
  let threw = false;
  try { parseExport(s); } catch { threw = true; }
  check(threw, `parser rejects: ${why}`);
}

// --- Database
const db = new PGlite();
await db.exec("create role anon; create role authenticated; create role service_role;");
await db.exec(readFileSync(new URL("../supabase/migrations/001_coffer.sql", import.meta.url), "utf8"));

async function upload(uid: string, s: string) {
  const p = parseExport(s);
  await db.query("select replace_contribution($1, $2, $3::jsonb)", ["h_" + uid, p.build, JSON.stringify(p.mobs)]);
}

for (let i = 0; i < 5; i++) {
  await upload("honest" + i, exportString(`aaaaaaaa0000000${i}`, [
    { npc: 113, name: "Coyote", kills: 400, meat: 0.39, claw: 0.01 },
    { npc: 2359, name: "Elemental Slave", kills: 120, meat: 0, claw: 0.13 },
  ]));
}
await upload("whale", exportString("bbbbbbbb00000000", [{ npc: 113, name: "Coyote", kills: 20000, meat: 0.39, claw: 0.01 }]));
await upload("cheater", exportString("cccccccc00000000", [{ npc: 113, name: "Coyote", kills: 400, meat: 0.95, claw: 0.5 }]));
// Sources: three players saw the same trainer; one typo'd the cost. Vendor and reagent prices too.
for (let i = 0; i < 3; i++) {
  const recs = [`CF2,dddddddd0000000${i},X,1763340000,1.60.1`,
    `T,bolt of silk cloth,Darianna,Darnassus,${i === 2 ? 999 : 500},100,Tailoring`,
    `V,red linen robe,Bale,Darnassus,9000,1,6271`, `B,2321,100`, `R,red linen robe,6271`];
  const p = parseExport(recs.join(";"));
  await db.query("select replace_contribution($1, $2, $3::jsonb, $4::jsonb)", ["h_src" + i, p.build, JSON.stringify(p.mobs), JSON.stringify(p.extra)]);
}
let badSrc = false;
try { parseExport("CF2,eeeeeeee00000000,X,1,1;T,a|cff,b,c,1,1,x"); } catch { badSrc = true; }
check(badSrc, "parser rejects UI escape codes in names");

// Re-uploading must replace, not add.
await upload("honest0", exportString("aaaaaaaa00000000", [{ npc: 113, name: "Coyote", kills: 400, meat: 0.39, claw: 0.01 }]));

const raw = (await db.query<{ n: number }>("select sum(kills)::int n from mob_stats where uid_hash='h_honest0'")).rows[0].n;
check(raw === 400, `re-upload replaced old data (honest0 has ${raw} kills)`);

await db.exec("select refresh_community()");
const meta = (await db.query<any>("select * from community_meta")).rows[0];
console.log("     meta:", meta.contributors, "contributors,", meta.kills, "kills,", meta.excluded, "excluded");
check(meta.excluded === 1, "cheater excluded");

const coyote = (await db.query<any>("select kills, contributors from community_mobs where npc=113")).rows[0];
check(coyote.kills === 5 * 400 + 3000, `whale capped at 3000 (community coyote kills = ${coyote.kills})`);
check(coyote.contributors === 6, "6 contributors kept for Coyote");
const meat = (await db.query<any>("select k from community_items where npc=113 and item=2673 and bucket='drop'")).rows[0].k;
const rate = meat / coyote.kills;
check(Math.abs(rate - 0.39) < 0.03, `pooled meat rate ${(rate * 100).toFixed(1)}% (true 39%)`);

const tr = (await db.query<any>("select * from community_trainer")).rows[0];
check(tr && tr.cost === 500 && tr.seen_by === 3, `trainer cost: the majority value wins (500, seen by ${tr?.seen_by})`);
const vb = (await db.query<any>("select * from community_vendor_buy where item = 2321")).rows[0];
check(vb && vb.price === 100, "vendor reagent price pooled");

// Public access: anon can call the two read functions and nothing else.
await db.exec("set role anon");
const exp = (await db.query<any>("select community_export() s")).rows[0].s as string;
let blocked = false;
try { await db.query("select replace_contribution('x','1',' []')"); } catch { blocked = true; }
check(blocked, "anon cannot call replace_contribution");
let blocked2 = false;
try { await db.query("select refresh_community()"); } catch { blocked2 = true; }
check(blocked2, "anon cannot call refresh_community");
await db.exec("reset role");

check(exp.startsWith("CF2,community,Community,") && exp.includes(";113,Coyote,"), "community export has the right format");
check(exp.includes(";T,bolt of silk cloth,Darianna,Darnassus,500,100,Tailoring") && exp.includes(";V,red linen robe,Bale") && exp.includes(";B,2321,100") && exp.includes(";R,red linen robe,6271"),
  "community export includes trainers, vendors, vendor prices and recipe items");
writeFileSync(new URL("./community_export.txt", import.meta.url), exp);
console.log("     export:", exp.length, "chars:", exp.slice(0, 140), "...");

if (failures) { console.log(`${failures} FAILED`); process.exit(1); }
// Trainer and vendor positions (migration 003; pg_cron isn't in PGlite, so the schedule is left out).
const m3 = readFileSync(new URL("../supabase/migrations/003_places.sql", import.meta.url), "utf8")
  .split("\n").filter((l) => !l.startsWith("select cron.")).join("\n");
await db.exec(m3);
const withPlaces = "CF2,abcdef0123456789,Me,1763340000,1.60.1;P,1346,Georgio Bolero,T,Tailoring,A,1453,53.20,81.50;" +
  "P,1347,Bad,X,,A,1453,1,1;P,1348,Too Far,V,,A,1453,150,1;Z,from,a,newer,addon";
const pp = parseExport(withPlaces);
check(pp.extra.places.length === 1 && pp.extra.places[0].npc === 1346 && pp.extra.places[0].x === 53.2,
  "places are parsed; bad ones and unknown record types are skipped");
await db.query("select replace_places($1, $2::jsonb)", ["h_p1", JSON.stringify(pp.extra.places)]);
await db.query("select replace_places($1, $2::jsonb)", ["h_p2", JSON.stringify([{ ...pp.extra.places[0], x: 53.4, y: 81.7 }])]);
await db.query("select replace_places($1, $2::jsonb)", ["h_p3", JSON.stringify([{ ...pp.extra.places[0], map: 1, x: 10, y: 10 }])]);
await db.exec("select refresh_places()");
const pe = (await db.query("select community_places_export() as s")).rows[0] as { s: string };
console.log("     places: " + pe.s);
check(/^P,1346,Georgio Bolero,T,Tailoring,A,1453,53\.[23]\d*,81\.[56]\d*$/.test(pe.s), "pool keeps the map most saw it on and the median spot there");
await db.exec("set role anon");
let blockedP = false;
try { await db.query("select replace_places('x','[]'::jsonb)"); } catch { blockedP = true; }
check(blockedP, "anon cannot call replace_places");
await db.exec("reset role");
if (failures) throw new Error(failures + " failures");
console.log("SERVER TESTS PASSED");
