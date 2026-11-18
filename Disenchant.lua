-- Haulwise: what your disenchants actually gave. When you cast Disenchant, the item being
-- disenchanted is the locked piece of gear in your bags; the loot window that follows is what it
-- turned into. Kept per item and per kind of item (quality, level band, armour or weapon), so the
-- tooltip can show both "this exact item" and "items like it".
local _, GP = ...

local DE_SPELL = 13262
local pending

function GP.DisenchantSpellName()
    local name
    if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(DE_SPELL) end
    if not name and GetSpellInfo then name = GetSpellInfo(DE_SPELL) end
    return name or "Disenchant"
end

local function isDisenchant(spellID)
    spellID = GP.Safe(spellID)
    if spellID == DE_SPELL then return true end
    if not spellID then return false end
    local n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfo and GetSpellInfo(spellID))
    return n ~= nil and n == GP.DisenchantSpellName()
end

-- "2:30:a" = green, required level 30-34, armour.
function GP.DisenchantBucket(info)
    if not info or not info.quality then return nil end
    local lvl = info.minLevel or 0
    return string.format("%d:%d:%s", info.quality, math.floor(lvl / 5) * 5, info.classID == 2 and "w" or "a")
end

local function lockedGear()
    for _, bag in ipairs(GP.BagIDs()) do
        for slot = 1, GP.NumSlots(bag) do
            local it = GP.SlotInfo(bag, slot)
            if it and it.isLocked and it.hyperlink then
                local info = GP.LinkInfo(it.hyperlink)
                if info.classID == 2 or info.classID == 4 then return it.itemID, it.hyperlink, info end
            end
        end
    end
end

-- The item can lock a moment after the cast starts, so we listen for the cast (sent/start),
-- for the bag slot that locks while it runs, and look once more when the cast finishes.
local casting
local function remember(bag, slot)
    local it = GP.SlotInfo(bag, slot)
    if not (it and it.hyperlink) then return end
    local info = GP.LinkInfo(it.hyperlink)
    if info.classID == 2 or info.classID == 4 then
        pending = { id = it.itemID, link = it.hyperlink, info = info, t = GetTime() }
    end
end
local function castBegins(unit, spellID)
    if unit ~= "player" or not isDisenchant(spellID) then return end
    casting = GetTime()
    if GP.deTarget then remember(GP.deTarget.bag, GP.deTarget.slot) end
    if not pending or GetTime() - pending.t > 12 then
        local id, link, info = lockedGear()
        if id then pending = { id = id, link = link, info = info, t = GetTime() } end
    end
end
GP:On("UNIT_SPELLCAST_SENT", function(unit, _, _, spellID) castBegins(unit, spellID) end)
GP:On("UNIT_SPELLCAST_START", function(unit, _, spellID) castBegins(unit, spellID) end)
GP:On("ITEM_LOCK_CHANGED", function(bag, slot)
    if casting and GetTime() - casting < 6 and slot then
        local it = GP.SlotInfo(bag, slot)
        if it and it.isLocked then remember(bag, slot) end
    end
end)
GP:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or not isDisenchant(spellID) then return end
    if not pending then
        local id, link, info = lockedGear()
        if id then pending = { id = id, link = link, info = info, t = GetTime() } end
    end
    if pending then pending.t = GetTime() end
    casting = nil
end)
local function stop(unit)
    if unit == "player" and casting then casting = nil; pending = nil end
end
GP:On("UNIT_SPELLCAST_INTERRUPTED", stop)
GP:On("UNIT_SPELLCAST_FAILED", stop)

local function add(entry, out)
    entry.n = (entry.n or 0) + 1
    entry.out = entry.out or {}
    for id, qty in pairs(out) do entry.out[id] = (entry.out[id] or 0) + qty end
end

-- Record a disenchant result: out = { [materialID] = quantity }.
function GP:RecordDisenchant(itemID, info, out)
    if not next(out) then return end
    local db = self.db
    db.deLog = db.deLog or {}
    db.deBuckets = db.deBuckets or {}
    db.deLog[itemID] = db.deLog[itemID] or {}
    add(db.deLog[itemID], out)
    local b = GP.DisenchantBucket(info)
    if b then
        db.deBuckets[b] = db.deBuckets[b] or {}
        add(db.deBuckets[b], out)
    end
end

local function onLoot()
    local p = pending
    if not p or GetTime() - p.t > 12 then return end
    local out, names = {}, {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then
            local _, name, qty = GetLootSlotInfo(slot)
            qty = GP.Safe(qty) or 1
            out[id] = (out[id] or 0) + qty
            names[#names + 1] = qty .. "x " .. (GP.Safe(name) or link)
        end
    end
    if not next(out) then return end
    pending = nil
    GP:RecordDisenchant(p.id, p.info, out)
    if GP.db.settings.tooltipDisenchant ~= false then
        GP.Print(string.format(GP.L["Disenchanted %s: %s (saved for the tooltip)"], p.link, table.concat(names, ", ")))
    end
end
GP:On("LOOT_READY", onLoot)
GP:On("LOOT_OPENED", onLoot)

-- For the tooltip: what this item gave, and what items like it gave. Each is
-- { n = times, list = { { id, total }, ... } sorted by total } or nil.
local function summary(entry)
    if not entry or not entry.n then return nil end
    local list = {}
    for id, q in pairs(entry.out or {}) do list[#list + 1] = { id, q } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    return { n = entry.n, list = list }
end

function GP:DisenchantHistory(itemID, info)
    local db = self.db
    local mine = summary(db.deLog and db.deLog[itemID])
    local b = GP.DisenchantBucket(info)
    local similar = summary(b and db.deBuckets and db.deBuckets[b])
    return mine, similar
end
