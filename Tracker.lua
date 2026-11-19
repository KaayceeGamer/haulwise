-- Haulwise: records kills and loot without the combat log.
--
-- WoW Forever runs on the Midnight engine, where the combat log is closed to addons.
-- So a kill is counted only when we can prove what the corpse held:
--   * we opened its loot window (GetLootSourceInfo tells us which corpse each item came from), or
--   * we saw it alive, then dead with loot rights ours (not tap-denied), and CanLootUnit says
--     it has nothing on it (an empty kill).
-- Corpses that had loot but were never looted are left out. Counting them as "no drop"
-- is the classic way addons make drop rates look lower than they are.
local _, GP = ...

local PICK_POCKET = 921
local LOOT_ITEM = (Enum and Enum.LootSlotType and Enum.LootSlotType.Item) or 1
local LOOT_MONEY = (Enum and Enum.LootSlotType and Enum.LootSlotType.Money) or 2

local engaged = {}      -- [guid] = last time seen alive
local deadAt = {}       -- [guid] = first time seen dead
local status = {}       -- [guid] = "pending" | "empty" | "looted"
local corpseItems = {}  -- [guid] = { [itemID] = true } from the first loot window
local gathered = {}     -- [guid] = true once skinned / mined / herbed
local pickpocketed = {} -- [guid] = true
local npcName, npcLevel = {}, {}
local lastCast = { id = nil, name = nil, t = 0 }

local function now() return GetTime() end

local function recording()
    local s = GP.db.settings
    return s.trackInGroup or not IsInGroup()
end

local function zoneName()
    local z = GP.Safe(GetRealZoneText and GetRealZoneText())
    if z and z ~= "" then return z end
    return "?"
end

function GP:Mob(npc)
    local m = self.db.mobs[npc]
    if not m then
        m = {
            name = npcName[npc], kills = 0, empty = 0, money = 0, items = {},
            zones = {}, gathered = 0, gather = {}, pp = 0, ppMoney = 0, ppItems = {},
            tIntervals = 0, tSeconds = 0,
        }
        self.db.mobs[npc] = m
    end
    if not m.name and npcName[npc] then m.name = npcName[npc] end
    local lvl = npcLevel[npc]
    if lvl and lvl > 0 then
        m.minL = math.min(m.minL or lvl, lvl)
        m.maxL = math.max(m.maxL or lvl, lvl)
    end
    return m
end

local function addKill(guid, npc, when)
    local m = GP:Mob(npc)
    m.kills = m.kills + 1
    local z = GP.ZoneKey and GP.ZoneKey() or zoneName()
    m.zones[z] = (m.zones[z] or 0) + 1
    -- Kill speed: time between kills of the same mob, ignoring breaks over 3 minutes.
    local t = time()
    if m.lastKill and t - m.lastKill > 0 and t - m.lastKill < 180 then
        m.tIntervals = m.tIntervals + 1
        m.tSeconds = m.tSeconds + (t - m.lastKill)
    end
    m.lastKill = t
    GP.session.kills = GP.session.kills + 1
    if GP.MaybeNudgeShare then GP:MaybeNudgeShare() end
    return m
end

-- Kill detection ---------------------------------------------------------------

local function scanUnit(unit)
    if not UnitExists(unit) then return end
    local guid = GP.Safe(UnitGUID(unit))
    local npc = GP.NpcFromGUID(guid)
    if not npc or UnitIsPlayer(unit) then return end

    local name = GP.Safe(UnitName(unit))
    if name then npcName[npc] = name end
    local lvl = GP.Safe(UnitLevel(unit))
    if lvl and lvl > 0 then npcLevel[npc] = lvl end

    local dead = GP.Safe(UnitIsDead(unit))
    if dead == false then
        -- Seen alive. We don't require "in combat": a rogue opener can one-shot a low mob
        -- before it ever enters combat, and missing those would hide empty kills.
        engaged[guid] = now()
    elseif dead == true and not deadAt[guid] then
        local tapDenied = GP.Safe(UnitIsTapDenied(unit))
        if engaged[guid] and now() - engaged[guid] < 120 and tapDenied == false then
            deadAt[guid] = now()
            status[guid] = status[guid] or "pending"
        end
    end
end

local function scanAll()
    scanUnit("target")
    scanUnit("mouseover")
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if unit then scanUnit(unit) end
        end
    end

    -- Dead for 2+ seconds and the game says there is nothing on it: an empty kill.
    local t = now()
    for guid, when in pairs(deadAt) do
        if status[guid] == "pending" and t - when >= 2 then
            local hasLoot = GP.Safe(CanLootUnit and CanLootUnit(guid))
            if hasLoot == false and recording() then
                local npc = GP.NpcFromGUID(guid)
                local m = addKill(guid, npc, when)
                m.empty = m.empty + 1
                status[guid] = "empty"
            end
        end
        if t - when > 600 then
            deadAt[guid], engaged[guid] = nil, nil
            if status[guid] == "pending" then status[guid] = nil end
        end
    end
end

-- Loot -------------------------------------------------------------------------

local function itemIDFromLink(link)
    link = GP.Safe(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function moneyFromText(text)
    text = GP.Safe(text)
    if type(text) ~= "string" then return 0 end
    local total = 0
    local function grab(fmt, mult)
        if not fmt then return end
        local pat = fmt:gsub("%%d", "(%%d+)")
        local n = text:match(pat)
        if n then total = total + tonumber(n) * mult end
    end
    grab(GOLD_AMOUNT, 10000)
    grab(SILVER_AMOUNT, 100)
    grab(COPPER_AMOUNT, 1)
    return total
end

local function isGatherCast()
    if now() - lastCast.t > 4 then return false end
    local n = (lastCast.name or ""):lower()
    return n:find("skinning") or n:find("mining") or n:find("herb") or n:find("salvag")
end

local function isPickpocket(guid)
    if now() - lastCast.t < 4 and (lastCast.id == PICK_POCKET or (lastCast.name or ""):lower():find("pick pocket")) then
        return true
    end
    -- A loot window from a living target can only be a pickpocket.
    local tg = GP.Safe(UnitGUID("target"))
    return tg == guid and GP.Safe(UnitIsDead("target")) == false
end

local function bump(tbl, id, qty)
    local e = tbl[id]
    if not e then e = { k = 0, q = 0 }; tbl[id] = e end
    e.k = e.k + 1
    e.q = e.q + qty
end

local function onLootOpened()
    if GP.Safe(IsFishingLoot and IsFishingLoot()) then return end

    -- Group everything in the window by the corpse it came from (AoE loot has many).
    local bySource = {}
    for slot = 1, GetNumLootItems() do
        local kind = GetLootSlotType(slot)
        local id = (kind == LOOT_ITEM) and itemIDFromLink(GetLootSlotLink(slot)) or nil
        local src = { GetLootSourceInfo(slot) }
        local nsrc = math.floor(#src / 2)
        for i = 1, #src, 2 do
            local guid, qty = GP.Safe(src[i]), GP.Safe(src[i + 1]) or 1
            if guid then
                local b = bySource[guid]
                if not b then b = { items = {}, money = 0 }; bySource[guid] = b end
                if kind == LOOT_MONEY then
                    if nsrc == 1 and (qty or 0) <= 1 then
                        local _, text = GetLootSlotInfo(slot)
                        qty = moneyFromText(text)
                    end
                    b.money = b.money + (qty or 0)
                elseif id then
                    b.items[id] = (b.items[id] or 0) + qty
                end
            end
        end
    end

    local rec = recording()
    for guid, b in pairs(bySource) do
        local npc = GP.NpcFromGUID(guid)
        if npc then
            local value = b.money
            for id, qty in pairs(b.items) do value = value + qty * (GP:ItemValue(id) or 0) end

            if isPickpocket(guid) then
                if not pickpocketed[guid] then
                    pickpocketed[guid] = true
                    GP.session.value = GP.session.value + value
                    if rec then
                        local m = GP:Mob(npc)
                        m.pp = m.pp + 1
                        m.ppMoney = m.ppMoney + b.money
                        for id, qty in pairs(b.items) do bump(m.ppItems, id, qty) end
                    end
                end
            elseif status[guid] == "looted" then
                -- Second window on a corpse we already looted: either we reopened it
                -- (bags full, closed it early) or we are skinning / mining / herbing it.
                local seen = corpseItems[guid] or {}
                local new = false
                for id in pairs(b.items) do if not seen[id] then new = true end end
                if (new or isGatherCast()) and not gathered[guid] then
                    gathered[guid] = true
                    GP.session.value = GP.session.value + value
                    if rec then
                        local m = GP:Mob(npc)
                        m.gathered = m.gathered + 1
                        for id, qty in pairs(b.items) do bump(m.gather, id, qty) end
                    end
                end
            elseif rec then
                local m
                if status[guid] == "empty" then
                    -- We called it empty too early; it is a looted kill after all.
                    m = GP:Mob(npc)
                    m.empty = math.max(0, m.empty - 1)
                else
                    m = addKill(guid, npc, deadAt[guid] or now())
                end
                status[guid] = "looted"
                corpseItems[guid] = {}
                m.money = m.money + b.money
                for id, qty in pairs(b.items) do
                    bump(m.items, id, qty)
                    corpseItems[guid][id] = true
                end
                GP.session.value = GP.session.value + value
                GP.session.money = GP.session.money + b.money
            else
                status[guid] = "looted"
                corpseItems[guid] = {}
                for id in pairs(b.items) do corpseItems[guid][id] = true end
                GP.session.value = GP.session.value + value
                GP.session.money = GP.session.money + b.money
            end
        end
    end
    if GP.RefreshUI then GP:RefreshUI() end
end

function GP:OnLoaded()
    self:On("LOOT_OPENED", onLootOpened)
    self:On("PLAYER_TARGET_CHANGED", function() scanUnit("target") end)
    self:On("UPDATE_MOUSEOVER_UNIT", function() scanUnit("mouseover") end)
    self:On("NAME_PLATE_UNIT_ADDED", function(unit) scanUnit(unit) end)
    self:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
        if unit ~= "player" then return end
        spellID = GP.Safe(spellID)
        local name
        if spellID and C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(spellID) end
        lastCast.id, lastCast.name, lastCast.t = spellID, GP.Safe(name), now()
    end)
    C_Timer.NewTicker(0.5, scanAll)
end

-- Exposed for tests.
GP._test = { onLootOpened = onLootOpened, scanAll = scanAll, scanUnit = scanUnit,
             state = { engaged = engaged, deadAt = deadAt, status = status, lastCast = lastCast } }
