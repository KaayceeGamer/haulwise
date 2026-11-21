-- Enchant requests heard in trade chat: an estimate of what an enchanter could earn here.
--
-- While you're in a city, Haulwise reads the trade (and services) channel for messages that ask
-- for an enchanter ("LF enchanter crusader", "WTB +15 agi 2h, tip 5g") and counts them per
-- enchant. It also counts how long you've been listening, so "requests per hour" means something.
-- Names are only kept in memory for a few minutes, to count one player once; nothing about who
-- asked is saved. It's an estimate: many requests go by whisper, some are filled by others, and
-- the wording in chat is guessed at.
local GP = Haulwise
local L = GP.L

local KEEP_DAYS = 14
local MAX_ENTRIES = 3000
local SAME_ASK = 15 * 60      -- the same player asking for the same enchant again within this counts once
local LISTEN_GAP = 5 * 60     -- trade messages further apart than this: you weren't in a city

-- Enchant names -------------------------------------------------------------------------------

local TIERS = { minor = true, lesser = true, inferior = true, greater = true, superior = true,
                major = true, mighty = true, excellent = true }
local SLOT_WORDS = {
    ["2h weapon"] = { "2h weapon", "2h", "2 hand", "2hander", "2 hander", "two hand", "two handed", "2handed", "2 handed", "twohand" },
    ["weapon"] = { "weapon", "wep", "weap", "1h", "one hand" },
    ["bracer"] = { "bracer", "bracers", "wrist", "wrists" },
    ["boots"] = { "boots", "boot", "feet" },
    ["chest"] = { "chest" },
    ["cloak"] = { "cloak", "cape" },
    ["gloves"] = { "gloves", "glove", "hands" },
    ["shield"] = { "shield" },
    ["off-hand"] = { "off hand", "offhand" },
    ["necklace"] = { "necklace", "neck" },
}
local SHORT = {
    agi = "agility", str = "strength", stam = "stamina", sta = "stamina", int = "intellect", intel = "intellect",
    spi = "spirit", spr = "spirit", def = "defense", hp = "health", sp = "spell power",
    mp5 = "mana regeneration", fr = "fire resistance",
    crus = "crusader", ["crusader's"] = "crusader", runspeed = "speed",
}

local catalog       -- [enchant name lower] = family key
local families      -- [family key] = { slot, base, label, names = { full names } }
local effects       -- [base effect] = { [slot] = family key }
local function build()
    -- Built once Haulwise Data's recipe list is there (or again if it came later).
    if catalog and (next(catalog) or not (HaulwiseData and HaulwiseData.wikiRecipes)) then return end
    catalog, families, effects = {}, {}, {}
    local wiki = HaulwiseData and HaulwiseData.wikiRecipes or {}
    for name, v in pairs(wiki) do
        local slot, eff = name:match("^enchant (.-)%s*%-%s*(.+)$")
        if slot and SLOT_WORDS[slot] then
            local words = {}
            for w in eff:gmatch("%S+") do if not TIERS[w] then words[#words + 1] = w end end
            local base = #words > 0 and table.concat(words, " ") or eff
            base = base:gsub("^grand ", "")
            local key = slot .. "|" .. base
            local fam = families[key]
            if not fam then
                local function cap(s) return (s:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)) end
                fam = { slot = slot, base = base, label = cap(slot) .. ": " .. cap(base), names = {}, skill = nil }
                families[key] = fam
            end
            fam.names[#fam.names + 1] = name
            local skill = tonumber(v:match("^(%d+)"))
            if skill and (not fam.skill or skill < fam.skill) then fam.skill = skill end
            catalog[name] = key
            effects[base] = effects[base] or {}
            effects[base][slot] = key
        end
    end
end
GP.EnchantFamilies = function() build(); return families end

local function unknownFamily(slot)
    local key = (slot or "?") .. "|?"
    if not families[key] then
        local label = slot and string.format(L["%s (which one not said)"], (slot:gsub("^%l", string.upper)))
            or L["Enchanter wanted (not said for what)"]
        families[key] = { slot = slot, base = "?", label = label, names = {}, vague = true }
    end
    return key
end

-- Reading a message ---------------------------------------------------------------------------

local SUPPLY = { "wts", "lfw", "lf work", "looking for work", "selling", "can do", "offering", "your mats",
                 "ur mats", "your own mats", "ymmt", "tips appreciated", "tips welcome", "for tips",
                 "enchanter here", "enchanting service", "enchanting services", "free enchant", "free enchants",
                 "pst for", "w me for", "whisper me for", "all enchants", "most enchants", "can enchant" }
local DEMAND = { "lf", "lfm", "looking for", "wtb", "need", "needing", "anyone", "any enchanter", "can someone",
                 "can anyone", "who can", "someone", "buying", "pay", "paying", "tip", "will tip" }

-- Enchants people name without saying "enchant": "LF crusader", "anyone fiery weapon?".
local SIGNATURE = { "crusader", "fiery weapon", "lifestealing", "icy chill", "unholy weapon", "demonslaying",
                    "minor speed", "run speed", "spell power", "healing power" }
local MATS = { "dust", "essence", "essences", "shard", "shards", "rod", "mats", "vellum", "leveling", "levelling" }

local function padded(text)
    text = " " .. text:lower():gsub("[%[%]%(%)%.,!%?:;/\"]", " "):gsub("%+", " "):gsub("%s+", " ") .. " "
    for short, long in pairs(SHORT) do text = text:gsub(" " .. short:gsub("%-", "%%-") .. " ", " " .. long .. " ") end
    return text
end
local function has(text, word) return text:find(" " .. word:gsub("([%-%.%+%*%?%^%$%%])", "%%%1") .. " ", 1, false) ~= nil end
local function hasAny(text, list) for _, w in ipairs(list) do if has(text, w) then return true end end end

-- What a message asks for. Returns "demand"/"supply"/nil, the enchant families named, and the
-- gold offered (when a number of gold is in it).
function GP.ReadEnchantMessage(msg)
    if type(msg) ~= "string" or msg == "" then return end
    build()
    local lower = msg:lower()
    lower = lower:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- Links: |Henchant:..|h[Enchanting: Enchant Bracer - Minor Health]|h, or a spell link.
    local named = {}
    for inner in lower:gmatch("|h%[(.-)%]|h") do named[#named + 1] = inner end
    -- Linked items ("WTB [Crusader's Gloves]") aren't enchants: only enchant links are read.
    lower = lower:gsub("|h[^|%[]*|h%[(.-)%]|h", function(n)
        return catalog[(n:gsub("^enchanting: ", ""))] and (" " .. n .. " ") or " "
    end):gsub("|", " ")
    if lower:find("formula") or lower:find("recipe") then return end   -- buying/selling the formula itself
    local text = padded(lower)
    if not (lower:find("ench") or lower:find("chanter") or #named > 0 or hasAny(text, SIGNATURE)) then return end
    local kind
    if hasAny(text, SUPPLY) and not has(text, "wtb") then
        -- Only an enchanter advertising counts, not someone selling "Crusader's Gloves".
        if not (lower:find("ench") or lower:find("chanter")) then return end
        kind = "supply"
    elseif hasAny(text, DEMAND) or lower:find("%?") then kind = "demand" end
    if not kind then return end

    local fams, seen = {}, {}
    local function add(key) if key and not seen[key] then seen[key] = true; fams[#fams + 1] = key end end
    for _, n in ipairs(named) do add(catalog[(n:gsub("^enchanting: ", ""))]) end
    if #fams == 0 then
        local slots = {}
        for slot, words in pairs(SLOT_WORDS) do
            for _, w in ipairs(words) do if has(text, w) then slots[slot] = true; break end end
        end
        if slots["2h weapon"] then slots["weapon"] = nil end
        for base, bySlot in pairs(effects) do
            if has(text, base) then
                local hit
                for slot in pairs(slots) do if bySlot[slot] then add(bySlot[slot]); hit = true end end
                if not hit then
                    -- No slot said: the one slot it exists on, or a one-hand weapon over a 2h one.
                    local only, n = nil, 0
                    for slot, key in pairs(bySlot) do only = key; n = n + 1 end
                    if n == 1 then add(only); hit = true
                    elseif bySlot["weapon"] and n == 2 and bySlot["2h weapon"] then add(bySlot["weapon"]); hit = true end
                end
                if hit then for slot in pairs(slots) do if bySlot[slot] then slots[slot] = nil end end end
            end
        end
        -- A slot with no enchant named: "LF enchanter, bracers".
        if #fams == 0 then
            local slot
            for s in pairs(slots) do slot = s; break end
            -- "WTB strange dust for enchanting": buying mats, not an enchanter.
            if not slot and hasAny(text, MATS) and (kind == "demand" or has(text, "wts") or has(text, "selling")) then return end
            add(unknownFamily(slot))
        end
    end
    local g = tonumber(lower:match("(%d+)%s*g%f[%A]")) or tonumber(lower:match("(%d+)%s*gold"))
    if g and (g <= 0 or g > 5000) then g = nil end
    return kind, fams, g and g * 10000 or nil
end

-- Listening -----------------------------------------------------------------------------------

local TRADE = { "trade", "handel", "commerce", "services", "dienstleistungen", "comercio" }
local function isTrade(channelName, zoneChannelID, baseName)
    if zoneChannelID == 2 or zoneChannelID == 42 then return true end
    local n = ((baseName ~= "" and baseName) or channelName or ""):lower()
    for _, w in ipairs(TRADE) do if n:find(w, 1, true) then return true end end
end

local recent = {}       -- ["name|family"] = time: memory only, to count each player once
local lastHeard

local function prune(s, now)
    local cut = now - KEEP_DAYS * 86400
    local keep = {}
    for _, e in ipairs(s.list) do if e[1] >= cut then keep[#keep + 1] = e end end
    while #keep > MAX_ENTRIES do table.remove(keep, 1) end
    s.list = keep
    local today = math.floor(now / 86400)
    for _, t in ipairs({ s.listen, s.supply }) do
        for day in pairs(t) do if day < today - KEEP_DAYS then t[day] = nil end end
    end
end

local prunedNow = {}
local function store()
    local db = GP.db
    db.enchantDemand = db.enchantDemand or {}
    local key = GP.RealmKey()
    -- Right after login the game may not know your realm or faction yet: an empty, unsaved list.
    if not key then return { list = {}, listen = {}, supply = {} } end
    local s = db.enchantDemand[key]
    if not s then s = { list = {}, listen = {}, supply = {} }; db.enchantDemand[key] = s end
    if not prunedNow[key] then prunedNow[key] = true; prune(s, time()) end
    return s
end

function GP:HearTrade(msg, who, now)
    if not (self.db and self.db.settings.hearTrade) then return end
    now = now or time()
    local s = store()
    local day = math.floor(now / 86400)
    if lastHeard and now - lastHeard <= LISTEN_GAP and now > lastHeard then
        s.listen[day] = (s.listen[day] or 0) + (now - lastHeard)
    end
    lastHeard = now
    local kind, fams, gold = GP.ReadEnchantMessage(msg)
    if not kind then return end
    who = who or "?"
    for k, t in pairs(recent) do if now - t > SAME_ASK then recent[k] = nil end end
    if kind == "supply" then
        local k = who .. "|supply"
        if not recent[k] then s.supply[day] = (s.supply[day] or 0) + 1 end
        recent[k] = now
        return kind
    end
    for _, fam in ipairs(fams) do
        local k = who .. "|" .. fam
        if not recent[k] then
            s.list[#s.list + 1] = { now, fam, gold }
        elseif gold then
            -- Asked again, now with a price: keep the price on the first ask.
            for i = #s.list, 1, -1 do
                local e = s.list[i]
                if e[2] == fam and not e[3] and now - e[1] <= SAME_ASK then e[3] = gold; break end
            end
        end
        recent[k] = now
    end
    if #s.list % 50 == 0 then prune(s, now) end
    self.enchantRowsCache = nil
    return kind, fams, gold
end

GP:On("CHAT_MSG_CHANNEL", function(text, sender, _, channelName, _, _, zoneChannelID, _, baseName)
    if not isTrade(channelName, zoneChannelID, baseName) then return end
    -- Chat text can be a value addons may not read (in instances); then there's nothing to count.
    if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then return end
    local me = UnitName and UnitName("player")
    if sender and me and (sender == me or sender:match("^([^%-]+)") == me) then return end
    pcall(GP.HearTrade, GP, text, sender)
end)

-- The view ------------------------------------------------------------------------------------

local function median(t)
    if #t == 0 then return nil end
    table.sort(t)
    local m = math.floor((#t + 1) / 2)
    return #t % 2 == 1 and t[m] or math.floor((t[m] + t[m + 1]) / 2)
end

-- Requests over the last 7 days, per enchant, and the hours spent hearing trade in them.
function GP:EnchantDemand(days, now)
    build()
    days = days or 7
    now = now or time()
    local s = store()
    local today = math.floor(now / 86400)
    local hours, supply = 0, 0
    for d = today - days + 1, today do
        hours = hours + (s.listen[d] or 0) / 3600
        supply = supply + (s.supply[d] or 0)
    end
    local known = {}
    for _, c in pairs(self.db.chars or {}) do
        for n in pairs(c.enchants or {}) do known[n] = true end
    end
    local by, total = {}, 0
    local cut = now - days * 86400
    for _, e in ipairs(s.list) do
        if e[1] >= cut then
            local r = by[e[2]]
            if not r then
                local fam = families[e[2]] or { label = e[2], names = {}, vague = true }
                r = { key = e[2], label = fam.label, n = 0, offers = {}, vague = fam.vague, names = fam.names, skill = fam.skill }
                for _, n in ipairs(fam.names) do if known[n] then r.known = true end end
                by[e[2]] = r
            end
            r.n = r.n + 1
            total = total + 1
            if e[3] then r.offers[#r.offers + 1] = e[3] end
            r.last = math.max(r.last or 0, e[1])
        end
    end
    local rows = {}
    for _, r in pairs(by) do
        r.perHour = hours >= 0.25 and r.n / hours or nil
        r.offer = median(r.offers)
        r.perHourGold = (r.perHour and r.offer) and r.perHour * r.offer or nil
        rows[#rows + 1] = r
    end
    table.sort(rows, function(a, b)
        if (a.vague or false) ~= (b.vague or false) then return not a.vague end
        if a.n ~= b.n then return a.n > b.n end
        return a.label < b.label
    end)
    return rows, { hours = hours, total = total, supply = supply, days = days }
end

function GP:EnchantRowsCached()
    local c = self.enchantRowsCache
    if c and GetTime() - c.t < 10 then return c.rows, c.info end
    local rows, info = self:EnchantDemand(7)
    self.enchantRowsCache = { t = GetTime(), rows = rows, info = info }
    return rows, info
end

-- The enchants each character knows, from the Enchanting window (enchants make no item, so the
-- recipe reader leaves them out).
function GP:NoteKnownEnchant(name)
    if not name then return end
    local c = self:Char()
    c.enchants = c.enchants or {}
    c.enchants[name:lower()] = true
end
