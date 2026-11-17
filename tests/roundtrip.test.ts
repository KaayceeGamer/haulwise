// The server accepts what the real addon exports.
import { readFileSync } from "node:fs";
import { parseExport } from "../supabase/functions/submit/parse.ts";
const p = parseExport(readFileSync(new URL("./addon_export.txt", import.meta.url), "utf8"));
console.log("addon export accepted by server:", p.mobs.length, "mobs,", p.kills, "kills, build", JSON.stringify(p.build));
