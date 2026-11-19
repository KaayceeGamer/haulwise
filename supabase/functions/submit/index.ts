// Haulwise upload endpoint. Deploy with "Verify JWT" OFF (the upload page is public).
// Secrets it needs (Dashboard -> Edge Functions -> Secrets):
//   COFFER_SALT  any long random string. Never change it: it keeps contributor ids stable.
// SUPABASE_URL and the service key are provided by Supabase automatically.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { parseExport } from "./parse.ts";

const MAX_UPLOADS_PER_DAY = 30;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type, authorization, apikey",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

// New Supabase projects provide SUPABASE_SECRET_KEYS (JSON); older ones SUPABASE_SERVICE_ROLE_KEY.
function serviceKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const keys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (keys) {
    try {
      const o = JSON.parse(keys) as Record<string, string>;
      return o.default ?? Object.values(o)[0] ?? "";
    } catch { /* fall through */ }
  }
  return "";
}

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST a /haul export string" }, 405);

  const salt = Deno.env.get("COFFER_SALT");
  if (!salt) return json({ error: "server not configured" }, 500);
  const key = serviceKey();
  if (!key) return json({ error: "server not configured (no service key)" }, 500);
  const db = createClient(Deno.env.get("SUPABASE_URL")!, key);

  // Rate limit by a hash of the IP that changes every day. The IP itself is never stored.
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "unknown";
  const day = new Date().toISOString().slice(0, 10);
  const { data: count, error: limitErr } = await db.rpc("bump_upload_limit", {
    p_ip_hash: await sha256(`${ip}|${day}|${salt}`),
  });
  if (limitErr) return json({ error: "server error" }, 500);
  if (count > MAX_UPLOADS_PER_DAY) return json({ error: "Too many uploads today. Try again tomorrow." }, 429);

  const body = await req.text();
  let parsed;
  try {
    parsed = parseExport(body);
  } catch (e) {
    return json({ error: (e as Error).message }, 400);
  }

  // The addon's random id, hashed so the stored id can't be traced back to an export string.
  // The character name in the export is ignored.
  const { error } = await db.rpc("replace_contribution", {
    p_uid_hash: await sha256(`${parsed.uid}|${salt}`),
    p_build: parsed.build,
    p_mobs: parsed.mobs,
    p_extra: parsed.extra,
  });
  if (error) return json({ error: "The server rejected this data." }, 400);
  // Trainer and vendor positions (migration 003). An older database without it still takes the rest.
  let places = 0;
  if (parsed.extra.places.length > 0) {
    const { data: n, error: placeErr } = await db.rpc("replace_places", {
      p_uid_hash: await sha256(`${parsed.uid}|${salt}`),
      p_places: parsed.extra.places,
    });
    if (!placeErr) places = n ?? 0;
  }
  // Recipes and their reagents (migration 005). An older database without it still takes the rest.
  let crafts = 0;
  if (parsed.extra.crafts.length > 0) {
    const { data: n, error: craftErr } = await db.rpc("replace_crafts", {
      p_uid_hash: await sha256(`${parsed.uid}|${salt}`),
      p_crafts: parsed.extra.crafts,
    });
    if (!craftErr) crafts = n ?? 0;
  }

  return json({
    ok: true, mobs: parsed.mobs.length, kills: parsed.kills,
    trainers: parsed.extra.trainers.length, vendors: parsed.extra.vendors.length, places, crafts,
  });
});
