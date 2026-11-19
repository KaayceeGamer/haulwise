-- Haulwise: what an item is for, and where to get it, in its tooltip.
-- * Quests that need it (from Haulwise Data, built from QuestieDB): quests in your log first,
--   then ones you can still do. Done quests and the other faction's are left out.
-- * Crafts that use it: your recipes and your alts', plus recipes other players have shared.
-- * Who sells it and which mobs drop it (Haulwise Data), when your own kills don't say already.
-- Bags also keep items a quest in your log needs (see GP:QuestKeepReason).
local _, GP = ...
local L = GP.L

local MAX_QUESTS, MAX_CRAFTS, MAX_NAMES = 3, 4, 3

local function data() return type(HaulwiseData) == "table" and HaulwiseData or nil end

-- Quest IDs in your quest log right now.
local logCache, logTime = nil, 0
local function questLog()
    if logCache and GetTime() - logTime < 2 then return logCache end
    logCache, logTime = {}, GetTime()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local ok, info = pcall(C_QuestLog.GetInfo, i)
            if ok and info and info.questID and not info.isHeader then logCache[info.questID] = true end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, GetNumQuestLogEntries() do
            local _, _, _, isHeader, _, _, _, qid = GetQuestLogTitle(i)
            if qid and not isHeader then logCache[qid] = true end
        end
    end
    return logCache
end
GP.ForgetQuestLog = function() logCache = nil end

local function questDone(qid)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, qid)
        return ok and done
    end
    return false
end

local function myFaction()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end

-- Quests that need an item and you can still do: { id, name, level, active }, active first.
-- Quests far below your level are left out unless they're in your log.
function GP:QuestsNeeding(itemID)
    local d = data()
    local ids = d and d.questItems and d.questItems[itemID]
    if not ids then return {} end
    local log, fac, level = questLog(), myFaction(), UnitLevel("player") or 1
    local out = {}
    for _, qid in ipairs(ids) do
        local q = d.quests[qid]
        if q then
            local active = log[qid]
            local ok = active or ((q[4] == "" or not fac or q[4] == fac) and not questDone(qid)
                and (q[2] == 0 or q[2] >= level - 8) and (q[3] or 0) <= level + 10)
            if ok then
                local deliver = q[5] == itemID and (q[6] or 0) > 0 and d.sourceNpcs and d.sourceNpcs[q[6]] or nil
                out[#out + 1] = { id = qid, name = q[1], level = q[2], active = active and true or false,
                                  to = deliver and deliver[1], toZone = deliver and (deliver[2] or 0) > 0 and GP.ZoneName("#" .. deliver[2]) or nil }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.active ~= b.active then return a.active end
        return (a.level or 0) < (b.level or 0)
    end)
    -- The same quest from several quest givers (city donations, both factions): once.
    local seen, unique = {}, {}
    for _, q in ipairs(out) do
        if not seen[q.name] then seen[q.name] = true; unique[#unique + 1] = q end
    end
    return unique
end

-- Why bags should keep an item: a quest in your log needs it. Nil otherwise.
function GP:QuestKeepReason(itemID)
    local d = data()
    local ids = d and d.questItems and d.questItems[itemID]
    if not ids then return nil end
    local log = questLog()
    for _, qid in ipairs(ids) do if log[qid] then return L["for a quest"] end end
    return nil
end

-- Recipes that use an item: yours, your alts' and shared ones. { name, prof, who } with who
-- "you", an alt's name, or nil for a shared recipe nobody of yours knows.
local useIndex, useTime = nil, 0
local function buildUses()
    if useIndex and GetTime() - useTime < 30 then return useIndex end
    useIndex, useTime = {}, GetTime()
    local me = GP.CharKey and GP:CharKey()
    local function add(itemID, entry)
        local list = useIndex[itemID]
        if not list then list = {}; useIndex[itemID] = list end
        for _, e in ipairs(list) do
            if e.out == entry.out then
                if entry.who == "you" or (e.who == nil and entry.who) then e.who = entry.who end
                return
            end
        end
        list[#list + 1] = entry
    end
    for key, c in pairs(GP.db.chars or {}) do
        local who = key == me and "you" or (key:match("^([^%-]+)") or key)
        for _, rec in pairs(c.recipes or {}) do
            if rec.learned and rec.out then
                for _, r in ipairs(GP.UnpackReagents(rec.r)) do
                    add(r[1], { out = rec.out, name = rec.n, prof = rec.prof, who = who })
                end
            end
        end
    end
    for _, craft in pairs(GP.SharedCrafts and GP:SharedCrafts() or {}) do
        for _, r in ipairs(craft.reagents or {}) do
            add(r[1], { out = craft.out, prof = craft.prof })
        end
    end
    return useIndex
end
GP.ForgetUses = function() useIndex = nil end

function GP:CraftsUsing(itemID)
    local list = buildUses()[itemID] or {}
    table.sort(list, function(a, b)
        local wa, wb = a.who == "you" and 0 or a.who and 1 or 2, b.who == "you" and 0 or b.who and 1 or 2
        if wa ~= wb then return wa < wb end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

-- Who sells an item and which mobs drop it: { vendors = {{name, zone}}, drops = {{name, zone}}, world = n }.
function GP:ItemSourcesFromData(itemID)
    local d = data()
    local s = d and d.sources and d.sources[itemID]
    if not s then return nil end
    local function names(ids)
        local out = {}
        for _, nid in ipairs(ids or {}) do
            local n = d.sourceNpcs and d.sourceNpcs[nid]
            if n then out[#out + 1] = { name = n[1], zone = (n[2] or 0) > 0 and GP.ZoneName("#" .. n[2]) or nil } end
        end
        return out
    end
    return { vendors = names(s[1]), drops = names(s[2]), world = s[3] or 0 }
end

local function nameList(list, max)
    local parts = {}
    for i, e in ipairs(list) do
        if i > max then break end
        parts[#parts + 1] = e.zone and (e.name .. " (" .. e.zone .. ")") or e.name
    end
    local text = table.concat(parts, ", ")
    if #list > max then text = text .. string.format(L[" +%d more"], #list - max) end
    return text
end

if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, info)
    if not GP.db or tooltip ~= GameTooltip or not GP.db.settings.tooltipUses then return end
    local id = info and GP.Safe(info.id)
    if not id then return end
    local ok, err = pcall(function()
        local quests = GP:QuestsNeeding(id)
        local crafts = GP:CraftsUsing(id)
        local src = GP:ItemSourcesFromData(id)
        local last = GP.lastTipSources
        local ownDrops
        if last and last.id == id then ownDrops = last.n > 0 else ownDrops = #GP:SourcesFor(id, 1) > 0 end
        local hasSrc = src and (#src.vendors > 0 or (not ownDrops and (#src.drops > 0 or src.world > 0)))
        if #quests == 0 and #crafts == 0 and not hasSrc then return end
        tooltip:AddLine(" ")
        if #quests > 0 or #crafts > 0 then tooltip:AddLine(L["|cffffd700Haulwise|r  used for:"]) end
        for i, q in ipairs(quests) do
            if i > MAX_QUESTS then
                tooltip:AddLine(string.format(L["  and %d more quests"], #quests - MAX_QUESTS), 0.6, 0.6, 0.6)
                break
            end
            local lvl = (q.level or 0) > 0 and string.format(" (%d)", q.level) or ""
            tooltip:AddDoubleLine(L["  Quest: "] .. q.name .. lvl, q.active and L["|cff5fd35fin your log|r"] or "",
                1, 0.82, 0.25, 1, 1, 1)
            if q.to then
                tooltip:AddLine("    " .. string.format(L["Bring it to %s"], q.toZone and (q.to .. " (" .. q.toZone .. ")") or q.to), 0.8, 0.8, 0.8)
            end
        end
        for i, c in ipairs(crafts) do
            if i > MAX_CRAFTS then
                tooltip:AddLine(string.format(L["  and %d more crafts"], #crafts - MAX_CRAFTS), 0.6, 0.6, 0.6)
                break
            end
            local name = c.name or GP.ItemInfo(c.out) or "?"
            local who = c.who == "you" and L["|cff5fd35fyou|r"] or c.who or L["|cff8f8b80shared recipe|r"]
            tooltip:AddDoubleLine("  " .. (c.prof and (L[c.prof] .. ": ") or "") .. name, who, 0.53, 0.8, 1, 1, 1, 1)
        end
        if hasSrc then
            tooltip:AddLine(L["|cffffd700Haulwise|r  get it:"])
            if #src.vendors > 0 then
                local price = GP.db.vendorBuy and GP.db.vendorBuy[id]
                tooltip:AddDoubleLine(L["  Sold by "] .. nameList(src.vendors, 2), price and GP.Coins(price) or "",
                    0.8, 0.8, 0.8, 1, 1, 1)
            end
            if not ownDrops then
                if #src.drops > 0 then
                    tooltip:AddLine(L["  Drops from "] .. nameList(src.drops, MAX_NAMES), 0.8, 0.8, 0.8, true)
                elseif src.world > 0 then
                    tooltip:AddLine(string.format(L["  World drop: %d kinds of mobs drop it"], src.world), 0.8, 0.8, 0.8)
                end
            end
        end
    end)
    if not ok then GP.ReportError("uses tooltip", err) end
end)

GP:On("QUEST_LOG_UPDATE", function() logCache = nil end)
GP:On("QUEST_ACCEPTED", function() logCache = nil end)
GP:On("QUEST_TURNED_IN", function() logCache = nil end)
