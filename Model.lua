-- Haulwise: turns kills, drops and prices into gold per hour.
--
-- The unit of ranking is the MOB, not the item: one Coyote kill is worth its meat AND its claw
-- AND its coins, so every row is a farm you can actually go and do.
--
--   per kill  = sum over drops of (units per kill x what a unit is worth to you)
--             + coins per kill + skinning/mining/herbing (if you have it) + pickpocket (rogues)
--   gold/hr   = per kill x kills per hour (timed from YOUR kills of that mob, not a guess)
--   "safe"    = the same with every drop chance at the low end of its 95% interval,
--               so a 1-in-50 lucky streak can't put a mob at the top.
--   Thin markets: when you'd farm more per hour than a quarter of what is listed on the AH,
--   the extra units are valued at the vendor price, since nobody will buy them at AH price.
local _, GP = ...
local L = GP.L

local MIN_TIMED = 5          -- kill intervals needed before we trust a measured kills/hour
local GATHER_LINES = { [393] = true, [186] = true, [182] = true } -- skinning, mining, herbalism

local function addCount(dst, src)
    for id, e in pairs(src or {}) do
        local d = dst[id]
        if not d then d = { k = 0, q = 0 }; dst[id] = d end
        d.k = d.k + (e.k or 0)
        d.q = d.q + (e.q or 0)
    end
end

local function merge(into, m)
    into.name = into.name or m.name
    into.kills = into.kills + (m.kills or 0)
    into.money = into.money + (m.money or 0)
    into.gathered = into.gathered + (m.gathered or 0)
    into.pp = into.pp + (m.pp or 0)
    into.ppMoney = into.ppMoney + (m.ppMoney or 0)
    into.tIntervals = into.tIntervals + (m.tIntervals or 0)
    into.tSeconds = into.tSeconds + (m.tSeconds or 0)
    if m.minL then into.minL = math.min(into.minL or m.minL, m.minL) end
    if m.maxL then into.maxL = math.max(into.maxL or m.maxL, m.maxL) end
    for z, n in pairs(m.zones or {}) do into.zones[z] = (into.zones[z] or 0) + n end
    addCount(into.items, m.items)
    addCount(into.gather, m.gather)
    addCount(into.ppItems, m.ppItems)
end

-- Estimated drop rates and coins per kill for mobs nobody has shared yet (Haulwise Data, from
-- the CMaNGOS Classic DB). They count as PRIOR_KILLS kills' worth of evidence: enough to rank
-- a mob before anyone farms it, and soon outweighed by real kills.
local PRIOR_KILLS = 15
local estimates
local function parseDrops(s)
    local out = {}
    for id, p, c in (s or ""):gmatch("(%d+):([%d%.]+):([%d%.]+)") do
        out[tonumber(id)] = { p = tonumber(p) / 100, c = tonumber(c) }
    end
    return out
end
function GP:Estimates()
    if estimates then return estimates end
    estimates = {}
    local raw = type(HaulwiseData) == "table" and HaulwiseData.estimates
    for npc, e in pairs(raw or {}) do
        estimates[npc] = { name = e[1], minL = e[2] ~= 0 and e[2] or nil, maxL = e[3] ~= 0 and e[3] or nil,
                           zone = (e[4] or 0) > 0 and ("#" .. e[4]) or nil, coins = e[5] or 0, raw = e,
                           kph = (tonumber(e[11]) or 0) > 0 and tonumber(e[11]) or nil }
    end
    return estimates
end
function GP.ForgetEstimates() estimates = nil end

-- The parsed drops of one estimate (parsed when first needed: most are never looked at).
local function estimateDrops(est)
    if not est.items then est.items, est.skin = parseDrops(est.raw[6]), parseDrops(est.raw[7]) end
    return est.items, est.skin
end

-- A bucket of real counts with an estimate blended in as `prior` extra tries.
local function blend(bucket, n, prior, est)
    local out = {}
    for id, e in pairs(bucket or {}) do out[id] = { k = e.k, q = e.q } end
    for id, e in pairs(est or {}) do
        local o = out[id] or { k = 0, q = 0 }
        o.k = o.k + prior * e.p
        o.q = o.q + prior * e.p * (e.c or 1)
        out[id] = o
    end
    return out, n + prior
end

-- One mob's numbers minus another's (never below zero): the pool without your own upload.
local function minus(m, mine)
    local out = {}
    for k, v in pairs(m) do out[k] = v end
    for _, k in ipairs({ "kills", "money", "gathered", "pp", "ppMoney", "tIntervals", "tSeconds" }) do
        out[k] = math.max(0, (m[k] or 0) - (mine[k] or 0))
    end
    out.zones = {}
    for z, n in pairs(m.zones or {}) do
        local left = n - ((mine.zones or {})[z] or 0)
        if left > 0 then out.zones[z] = left end
    end
    for _, bucket in ipairs({ "items", "gather", "ppItems" }) do
        out[bucket] = {}
        for id, e in pairs(m[bucket] or {}) do
            local my = (mine[bucket] or {})[id] or {}
            local k, q = (e.k or 0) - (my.k or 0), (e.q or 0) - (my.q or 0)
            if k > 0 then out[bucket][id] = { k = k, q = math.max(k, q) } end
        end
    end
    return out
end

-- The community pool without what you shared yourself, so your kills aren't counted twice.
-- A mob is only adjusted when the pool has at least as many kills as you shared (otherwise
-- your upload can't be in it yet).
function GP:CommunityMobs(src)
    if not src then return {} end
    local cache = self.mineInPool
    if cache and cache.src == src then return cache.mobs end
    local mine = self.MySharedMobs and self:MySharedMobs(src.time) or nil
    local mobs = src.mobs or {}
    if mine then
        local adjusted = {}
        for npc, m in pairs(mobs) do
            local my = mine[npc]
            if my and (m.kills or 0) >= (my.kills or 0) then
                local left = minus(m, my)
                if left.kills > 0 then adjusted[npc] = left end
            else
                adjusted[npc] = m
            end
        end
        mobs = adjusted
    end
    self.mineInPool = { src = src, mobs = mobs }
    return mobs
end

-- Own data plus anything imported from friends.
function GP:MergedMobs()
    if self.mergedHeld then return self.mergedHeld end
    local out = {}
    local function add(npc, m, own)
        local o = out[npc]
        if not o then
            o = { kills = 0, money = 0, gathered = 0, pp = 0, ppMoney = 0, tIntervals = 0, tSeconds = 0,
                  zones = {}, items = {}, gather = {}, ppItems = {}, own = 0 }
            out[npc] = o
        end
        merge(o, m)
        if own then o.own = o.own + (m.kills or 0) end
    end
    for npc, m in pairs(self.db.mobs) do add(npc, m, true) end
    if self.db.settings.useShared then
        for uid, src in pairs(self.db.shared) do
            local mobs = uid == "community" and self:CommunityMobs(src) or src.mobs or {}
            for npc, m in pairs(mobs) do add(npc, m) end
        end
        if self.community and not self.db.shared.community then
            for npc, m in pairs(self:CommunityMobs(self.community)) do add(npc, m) end
        end
    end
    if self.db.settings.useEstimates then
        for npc, est in pairs(self:Estimates()) do
            local o = out[npc]
            if o then
                o.est = est
                o.name = o.name or est.name
                o.minL, o.maxL = o.minL or est.minL, o.maxL or est.maxL
                if est.zone and not next(o.zones) then o.zones[est.zone] = 0 end
            else
                -- Nobody has killed it: one shared, read-only record per estimate, made once, so
                -- tooltips that merge often don't build ~2000 tables each time.
                if not est.shell then
                    est.shell = { kills = 0, money = 0, gathered = 0, pp = 0, ppMoney = 0, tIntervals = 0, tSeconds = 0,
                                  zones = est.zone and { [est.zone] = 0 } or {}, items = {}, gather = {}, ppItems = {}, own = 0,
                                  est = est, name = est.name, minL = est.minL, maxL = est.maxL }
                end
                out[npc] = est.shell
            end
        end
    end
    return out
end

function GP:PlayerHasGathering()
    if not GetProfessions then return true end
    local ok, a, b = pcall(GetProfessions)
    if not ok then return true end
    for _, idx in ipairs({ a, b }) do
        if idx then
            local line = select(7, GetProfessionInfo(idx))
            if line and GATHER_LINES[line] then return true end
        end
    end
    return false
end

function GP:PlayerIsRogue()
    local _, class = UnitClass("player")
    return class == "ROGUE"
end

-- The zone with the most kills; a mob only known from the estimates has its zone at 0 kills.
local function topZone(zones)
    local best, n = nil, -1
    for z, c in pairs(zones) do if c > n then best, n = z, c end end
    return best or "?"
end

-- Value one bucket of drops (corpse loot, gather or pickpocket) over `n` tries.
local function valueBucket(self, bucket, n, kph, lines, kind)
    local est, safe = 0, 0
    for id, e in pairs(bucket) do
        local _, ah, vendor, listed = self:ItemValue(id)
        local chance = e.k / n
        local lo, hi = GP.Wilson(e.k, n)
        local perDrop = e.q / math.max(1, e.k)
        local units = chance * perDrop           -- expected units per kill
        local unitsSafe = lo * perDrop

        local function perHour(u)
            local y = u * kph
            if not ah then return y * vendor, false end
            local cap = listed and math.max(5, listed / 4) or math.huge
            local atAH = math.min(y, cap)
            return atAH * ah + (y - atAH) * vendor, y > cap
        end
        local vh, thin = perHour(units)
        local vs = perHour(unitsSafe)
        -- Worth more crafted? (e.g. cook the meat instead of selling it raw)
        local craft, craftName = self:CraftValue(id)
        local rawUnit = math.max(ah or 0, vendor)
        local crafted = false
        if craft and craft > rawUnit and self.db.settings.valueAsCrafted then
            vh, vs, thin, crafted = units * kph * craft, unitsSafe * kph * craft, false, true
        end
        est, safe = est + vh, safe + vs
        lines[#lines + 1] = {
            id = id, kind = kind, chance = chance, lo = lo, hi = hi, perDrop = perDrop,
            perHour = vh, thin = thin, priced = ah ~= nil or crafted, vendor = vendor, unit = rawUnit,
            craft = (craft and craft > rawUnit) and craft or nil, craftName = craftName, crafted = crafted,
        }
    end
    return est, safe
end

function GP:Evaluate(npc, m)
    local s = self.db.settings
    local K = math.max(1, m.kills)
    local measured = m.tIntervals >= MIN_TIMED and m.tSeconds > 0
    -- Not timed yet: the estimate from how close together the mob stands (Haulwise Data), scaled
    -- by your own "kills per hour" setting (40 = as estimated), else that setting.
    local estKph = m.est and m.est.kph and m.est.kph * (s.defaultKph or 40) / 40
    local kph = measured and (3600 * m.tIntervals / m.tSeconds) or estKph or s.defaultKph

    local lines = {}
    local items, tries, money = m.items, K, m.money
    local gather, gathered = m.gather, m.gathered
    if m.est then
        local estItems, estSkin = estimateDrops(m.est)
        items, tries = blend(m.items, m.kills, PRIOR_KILLS, estItems)
        money = m.money + PRIOR_KILLS * (m.est.coins or 0)
        if next(estSkin) then gather, gathered = blend(m.gather, m.gathered, PRIOR_KILLS, estSkin) end
    end
    local est, safe = valueBucket(self, items, tries, kph, lines, "drop")
    local coins = (money / tries) * kph
    est, safe = est + coins, safe + coins

    if s.includeGather and gathered > 0 and self:PlayerHasGathering() then
        local e2, s2 = valueBucket(self, gather, gathered, kph, lines, "gather")
        est, safe = est + e2, safe + s2
    end
    if s.includePickpocket and m.pp > 0 and self:PlayerIsRogue() then
        local e3, s3 = valueBucket(self, m.ppItems, m.pp, kph, lines, "pickpocket")
        local ppCoins = (m.ppMoney / m.pp) * kph
        est, safe = est + e3 + ppCoins, safe + s3 + ppCoins
    end
    table.sort(lines, function(a, b) return a.perHour > b.perHour end)

    local unpriced = 0
    for _, l in ipairs(lines) do if not l.priced and l.vendor == 0 then unpriced = unpriced + 1 end end

    return {
        npc = npc, name = m.name or (L["NPC #"] .. npc), zone = topZone(m.zones),
        minL = m.minL, maxL = m.maxL, kills = m.kills, own = m.own or m.kills, kph = kph, measured = measured,
        perKill = est / kph, est = est, safe = safe, coinsPerKill = money / tries,
        estimated = m.est ~= nil, estOnly = m.est ~= nil and m.kills == 0,
        lines = lines, unpriced = unpriced,
    }
end

-- How far to trust a number built on this many kills: a word and its colour.
function GP.Confidence(kills)
    kills = kills or 0
    if kills < 10 then return L["rough guess"], "|cffff6b5b" end
    if kills < 30 then return L["getting there"], "|cffff9944" end
    if kills < 100 then return L["good"], "|cffffffff" end
    return L["solid"], "|cff5fd35f"
end

-- What other players have shared about one zone: mobs and kills (yours not counted).
function GP:CommunityInZone(zone)
    local mobs, kills = 0, 0
    if not zone then return 0, 0 end
    local seen = {}
    local function count(src)
        for npc, m in pairs(src and src.mobs or {}) do
            local n = m.zones and m.zones[zone]
            if n and n > 0 then
                if not seen[npc] then seen[npc] = true; mobs = mobs + 1 end
                kills = kills + n
            end
        end
    end
    for uid, src in pairs(self.db.shared or {}) do
        count(uid == "community" and { mobs = self:CommunityMobs(src) } or src)
    end
    if self.community and not (self.db.shared and self.db.shared.community) then count({ mobs = self:CommunityMobs(self.community) }) end
    return mobs, kills
end

-- The zone you're in, as the key kills are recorded under ("#1434", see Zones.lua).
function GP:CurrentZone()
    local z = GP.ZoneKey and GP.ZoneKey() or GP.Safe(GetRealZoneText and GetRealZoneText())
    return (z and z ~= "" and z ~= "?") and z or nil
end

-- The zone the Farm tab is limited to: nil (all), the one you're in, or one you clicked.
function GP:FarmZoneFilter()
    local z = self.db.settings.farmZone
    if z == "here" then return self:CurrentZone() end
    return z
end

function GP:Rank(zone)
    local s = self.db.settings
    local level = UnitLevel("player") or 60
    local rows = {}
    for npc, m in pairs(self:MergedMobs()) do
        if (m.kills > 0 or m.est) and (not zone or (m.zones and m.zones[zone])) then
            local tooHigh = s.levelWindow and m.minL and m.minL > level + 2
            -- Mobs nobody has killed, far below you: the estimate assumes ~40 kills an hour and
            -- would put level 1 kobolds on top for a level 38. Ones with real kills still show.
            -- With one zone picked, show its low mobs anyway: you asked about that zone.
            local tooLow = s.levelWindow and not zone and m.kills == 0 and m.maxL and m.maxL < level - 10
            if not tooHigh and not tooLow then rows[#rows + 1] = self:Evaluate(npc, m) end
        end
    end
    local key = s.sortBy == "est" and "est" or "safe"
    table.sort(rows, function(a, b)
        if a[key] ~= b[key] then return a[key] > b[key] end
        return a.npc < b.npc
    end)
    return rows
end

-- An icon for a mob: its beast family (wolf, spider, raptor...) or creature type (humanoid,
-- elemental, undead...), from Haulwise Data. nil when the mob isn't in it.
local FAMILY_ICON = {
    [1] = "Ability_Hunter_Pet_Wolf", [2] = "Ability_Hunter_Pet_Cat", [3] = "Ability_Hunter_Pet_Spider",
    [4] = "Ability_Hunter_Pet_Bear", [5] = "Ability_Hunter_Pet_Boar", [6] = "Ability_Hunter_Pet_Crocolisk",
    [7] = "Ability_Hunter_Pet_Vulture", [8] = "Ability_Hunter_Pet_Crab", [9] = "Ability_Hunter_Pet_Gorilla",
    [11] = "Ability_Hunter_Pet_Raptor", [12] = "Ability_Hunter_Pet_TallStrider", [15] = "Spell_Shadow_SummonFelHunter",
    [16] = "Spell_Shadow_SummonVoidWalker", [17] = "Spell_Shadow_SummonSuccubus", [20] = "Ability_Hunter_Pet_Scorpid",
    [21] = "Ability_Hunter_Pet_Turtle", [23] = "Spell_Shadow_SummonImp", [24] = "Ability_Hunter_Pet_Bat",
    [25] = "Ability_Hunter_Pet_Hyena", [26] = "Ability_Hunter_Pet_Owl", [27] = "Ability_Hunter_Pet_WindSerpent",
}
local TYPE_ICON = {
    [1] = "Ability_Hunter_BeastTaming", [2] = "INV_Misc_Head_Dragon_01", [3] = "Spell_Shadow_SummonFelHunter",
    [4] = "Spell_Frost_SummonWaterElemental", [5] = "Spell_Nature_Earthquake", [6] = "Spell_Shadow_RaiseDead",
    [7] = "INV_Misc_Head_Human_01", [8] = "Spell_Nature_Polymorph", [9] = "INV_Misc_Gear_01",
}
-- The mob's model (creature display id) for a real portrait, from Haulwise Data.
function GP.MobDisplay(npc)
    local e = type(HaulwiseData) == "table" and HaulwiseData.estimates and HaulwiseData.estimates[tonumber(npc) or 0]
    local d = e and tonumber(e[10])
    return d and d > 0 and d or nil
end

function GP.MobIcon(npc)
    local e = type(HaulwiseData) == "table" and HaulwiseData.estimates and HaulwiseData.estimates[tonumber(npc) or 0]
    if not e then return nil end
    local name = FAMILY_ICON[e[9] or 0] or TYPE_ICON[e[8] or 0]
    return name and ("Interface\\Icons\\" .. name) or nil
end

-- Mobs with real kills (yours or shared) outside `zone`: what "This zone only" hides.
function GP:FarmHiddenElsewhere(zone)
    if not zone then return 0 end
    local n = 0
    for _, m in pairs(self:MergedMobs()) do
        if (m.kills or 0) > 0 and not (m.zones and m.zones[zone]) then n = n + 1 end
    end
    return n
end

-- Zones ranked by the best gold per hour you can make there.
function GP:ZoneRows()
    local key = self.db.settings.sortBy == "est" and "est" or "safe"
    local here = self:CurrentZone()
    local byZone = {}
    for _, r in ipairs(self:Rank()) do
        local z = byZone[r.zone]
        if not z then
            z = { zone = r.zone, mobs = 0, kills = 0, list = {}, here = r.zone == here }
            byZone[r.zone] = z
        end
        z.mobs, z.kills = z.mobs + 1, z.kills + r.kills
        z.list[#z.list + 1] = r
        if r.minL then z.minL = math.min(z.minL or r.minL, r.minL) end
        if r.maxL then z.maxL = math.max(z.maxL or r.maxL, r.maxL) end
    end
    local rows = {}
    for _, z in pairs(byZone) do
        -- Rank() is already sorted, so the first mob is the zone's best.
        local b = z.list[1]
        z.bestName, z.est, z.safe = b.name, b.est, b.safe
        rows[#rows + 1] = z
    end
    table.sort(rows, function(a, b)
        if a[key] ~= b[key] then return a[key] > b[key] end
        return a.zone < b.zone
    end)
    return rows
end

-- Best sources for one item, for the item tooltip.
-- Work that asks about many items at once (the Recipes tab) holds one merged table and an
-- item -> mobs index for the whole run, instead of rebuilding every mob once per item.
function GP:WithMergedMobs(fn)
    if self.mergedHeld then return fn() end
    self.mergedHeld = self:MergedMobs()
    local idx = {}
    for npc, m in pairs(self.mergedHeld) do
        if m.kills > 0 then
            for id in pairs(m.items) do
                local l = idx[id]
                if not l then l = {}; idx[id] = l end
                l[#l + 1] = npc
            end
        end
    end
    self.mergedItemIndex = idx
    local ok, a = pcall(fn)
    self.mergedHeld, self.mergedItemIndex = nil, nil
    if not ok then error(a, 0) end
    return a
end

function GP:SourcesFor(itemID, max)
    local out = {}
    local function add(npc, m)
        local e = m.items[itemID]
        if e and m.kills > 0 then
            out[#out + 1] = { name = m.name or (L["NPC #"] .. npc), chance = e.k / m.kills, kills = m.kills,
                              lo = (GP.Wilson(e.k, m.kills)) }
        end
    end
    if self.mergedItemIndex then
        local merged = self.mergedHeld
        for _, npc in ipairs(self.mergedItemIndex[itemID] or {}) do add(npc, merged[npc]) end
    else
        for npc, m in pairs(self:MergedMobs()) do add(npc, m) end
    end
    table.sort(out, function(a, b) return a.lo > b.lo end)
    for i = #out, (max or 3) + 1, -1 do out[i] = nil end
    return out
end
