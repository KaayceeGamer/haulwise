-- Haulwise: auction house prices shared between players.
--
-- Sharing: Share data adds one "A" record with the 10th-percentile price of the items Haulwise
-- cares about (drops, reagents, crafts, what you own) from your last scan, if it's at most 3 days
-- old, with the realm and faction it was scanned on. At most 2000 items (about 30 KB), never the whole AH.
--
-- Using: your own scan always wins while it's fresh. Otherwise Haulwise uses, in this order:
--   prices for your realm and faction that you imported from the website ("realm"),
--   your own older scan, Auctionator, and the median over all realms shipped with every release
--   ("all", a rough guess: realms' economies differ a lot).
local _, GP = ...
local L = GP.L

local FRESH = 3 * 86400
local MAX_SHARED = 2000

function GP.FactionLetter()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f == "Horde" and "H" or (f == "Alliance" and "A" or nil)
end

local function cleanRealm(s)
    s = tostring(s or ""):gsub("[,;:/~|<>\n\r]", " "):match("^%s*(.-)%s*$")
    if s == "" or #s > 60 then return nil end
    return s
end

-- "Realm|A": the key imported prices are stored under, for the character you're playing.
function GP.RealmKey()
    local realm, fac = cleanRealm(GetRealmName and GetRealmName()), GP.FactionLetter()
    if not (realm and fac) then return nil end
    return realm .. "|" .. fac
end

-- Called when a scan finishes: remember where it was taken.
function GP:NoteScanRealm(t)
    local realm, fac = cleanRealm(GetRealmName and GetRealmName()), GP.FactionLetter()
    if realm and fac then self.db.scanRealm = { r = realm, f = fac, t = t or time() } end
end

-- Items worth sharing a price for: what drops (yours and the estimates), what recipes use and
-- make, what you own, and what vendors sell as reagents.
function GP:SharedPriceItems()
    local set = {}
    local function add(id) id = tonumber(id); if id and id > 0 then set[id] = true end end
    for _, m in pairs(self.db.mobs or {}) do
        for _, bucket in ipairs({ m.items, m.gather, m.ppItems }) do for id in pairs(bucket or {}) do add(id) end end
    end
    local raw = type(HaulwiseData) == "table" and HaulwiseData.estimates
    for _, e in pairs(raw or {}) do
        for _, s in ipairs({ e[6], e[7] }) do
            if type(s) == "string" then for id in s:gmatch("(%d+):[%d.]+") do add(id) end end
        end
    end
    for _, c in pairs(self.db.chars or {}) do
        for _, rec in pairs(c.recipes or {}) do
            add(rec.out)
            for id in tostring(rec.r or ""):gmatch("(%d+):") do add(id) end
        end
        for _, where in ipairs({ c.bags, c.bank, c.mail }) do
            if type(where) == "table" then for id in pairs(where) do add(id) end end
        end
    end
    for id, c in pairs(self.SharedCrafts and self:SharedCrafts() or {}) do
        add(id)
        for _, r in ipairs(c.reagents or {}) do add(r[1]) end
    end
    for id in pairs(self.db.vendorBuy or {}) do add(id) end
    return set
end

-- "A,realm,faction,day,id:price:units/..." or nil when there's no fresh scan to share.
function GP:SharedPriceRecord()
    local db, where = self.db, self.db.scanRealm
    if not (where and where.r and where.f and db.priceScanTime) then return nil end
    if time() - db.priceScanTime > FRESH then return nil end
    local wanted, list = self:SharedPriceItems(), {}
    for id in pairs(wanted) do
        local p = db.prices[id]
        if p and p.p and p.p > 0 and (p.q or 0) > 0 then list[#list + 1] = id end
    end
    if #list == 0 then return nil end
    -- Over the cap, keep the most traded items (most units listed).
    if #list > MAX_SHARED then
        table.sort(list, function(a, b) return (db.prices[a].q or 0) > (db.prices[b].q or 0) end)
        for i = #list, MAX_SHARED + 1, -1 do list[i] = nil end
    end
    table.sort(list)
    local parts = {}
    for i = 1, #list do
        local id = list[i]
        local p = db.prices[id]
        parts[#parts + 1] = string.format("%d:%d:%d", id, math.floor(p.p), math.min(999999, math.floor(p.q)))
    end
    return string.format("A,%s,%s,%d,%s", where.r, where.f, GP.Day(db.priceScanTime), table.concat(parts, "/")), #parts
end

-- Parsing (used by Share.lua's ParseExport) ----------------------------------------------------

local function priceList(s, withCount)
    local out, n = {}, 0
    for part in (s or ""):gmatch("[^/]+") do
        local id, p, q = part:match("^(%d+):(%d+):(%d+)$")
        id, p, q = tonumber(id), tonumber(p), tonumber(q)
        if id and p and id > 0 and id < 1e7 and p > 0 and p < 1e11 then
            out[id] = withCount and { p = p, n = q } or p
            n = n + 1
        end
    end
    return out, n
end

-- f = the split "A" record. Returns { realm, fac, day, items = { [id] = { p, n } }, count }.
function GP.ParsePriceRecord(f)
    local realm, fac, day = cleanRealm(f[2]), f[3], tonumber(f[4])
    if not realm or (fac ~= "A" and fac ~= "H") or not day then return nil end
    local items, n = priceList(f[5], true)
    if n == 0 then return nil end
    return { realm = realm, fac = fac, day = day, items = items, count = n }
end

-- f = the split "M" record (the median over all realms). Returns { [id] = { p, n } }, count.
function GP.ParseMedianRecord(f)
    return priceList(f[2], true)
end

-- Importing prices for your realm (the website's "Prices for your realm" string) -------------

function GP:StoreRealmPrices(src)
    local pr = src.prices
    if not pr then error(L["no prices in this string"]) end
    self.db.realmPrices = self.db.realmPrices or {}
    local key = pr.realm .. "|" .. pr.fac
    local old = self.db.realmPrices[key]
    if old and (old.day or 0) > pr.day then error(L["you already have newer prices for this realm"]) end
    self.db.realmPrices[key] = { day = pr.day, time = src.time, players = src.contributors, items = pr.items }
    local mine = GP.RealmKey()
    local fac = pr.fac == "H" and L["Horde"] or L["Alliance"]
    local msg = string.format(L["Prices for %s (%s): %d items from %s."], pr.realm, fac, pr.count,
        GP.Plural and GP.Plural(src.contributors or 1, "player", "players") or tostring(src.contributors or 1))
    if mine and mine ~= key then msg = msg .. " " .. L["They're used when you play on that realm."] end
    return msg
end

-- Looking a price up -------------------------------------------------------------------------

-- A shared price for one item: price, age in seconds, kind ("realm" or "all"), players or realms.
function GP:SharedPrice(id, allowAll)
    local key = GP.RealmKey()
    local mine = key and self.db.realmPrices and self.db.realmPrices[key]
    if mine and mine.items then
        local e = mine.items[id]
        if e then return e.p, math.max(0, (GP.Day() - (mine.day or 0)) * 86400), "realm", mine.players end
    end
    if allowAll == false then return nil end
    local com = self.CommunityInfo and self:CommunityInfo()
    local e = com and com.allPrices and com.allPrices[id]
    if e then return e.p, math.max(0, time() - (com.time or time())), "all", e.n end
    return nil
end

-- Imported realm prices older than two weeks are no use any more.
function GP:PruneRealmPrices()
    local today = GP.Day()
    for key, e in pairs(self.db.realmPrices or {}) do
        if type(e) ~= "table" or (today - (e.day or 0)) > 14 then self.db.realmPrices[key] = nil end
    end
end
