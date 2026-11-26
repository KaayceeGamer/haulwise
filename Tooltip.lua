-- Haulwise: adds drop sources to item tooltips and gold/hour to mob tooltips.
local _, GP = ...
local L = GP.L

if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, info)
    if not GP.db or tooltip ~= GameTooltip then return end
    local id = info and GP.Safe(info.id)
    if not id then return end
    local sources = GP:SourcesFor(id, 3)
    GP.lastTipSources = { id = id, n = #sources } -- so Uses.lua needn't work it out again
    local value, ah = GP:ItemValue(id)
    if #sources == 0 and not ah then return end
    tooltip:AddLine(" ")
    if ah then
        local trend = GP.Trend and GP:Trend(id)
        local right = GP.Coins(ah)
        if trend then right = right .. string.format(trend >= 0 and "  |cff5fd35f+%.0f%%|r" or "  |cffff6b5b%.0f%%|r", trend * 100) end
        tooltip:AddDoubleLine(L["|cffffd700Haulwise|r AH (after cut)"], right, 1, 1, 1, 1, 1, 1)
        local speed = GP:SellSpeedText(id)
        if speed then tooltip:AddDoubleLine(L["  Demand"], speed, 0.8, 0.8, 0.8, 1, 1, 1) end
    end
    local craft, craftName = GP:CraftValue(id)
    if craft and craft > (value or 0) then
        tooltip:AddDoubleLine(L["  Worth more as "] .. (craftName or "?"), GP.Coins(craft) .. L[" each"], 0.53, 0.8, 1, 0.53, 0.8, 1)
    end
    -- Where it drops: the best mob on one line; Shift shows them all (tooltips with other
    -- addons' lines ran off the top of the screen).
    if GP.TooltipFull() then
        for _, s in ipairs(sources) do
            tooltip:AddDoubleLine("  " .. s.name, string.format(L["%.0f%%  (%d kills)"], s.chance * 100, s.kills),
                0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        end
    elseif sources[1] then
        local s = sources[1]
        local more = #sources > 1 and ("|cff8a8880 " .. string.format(L["+%d more (Shift)"], #sources - 1) .. "|r") or ""
        tooltip:AddDoubleLine(L["  Drops from "] .. s.name .. more, string.format(L["%.0f%%  (%d kills)"], s.chance * 100, s.kills),
            0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
    end
end)

-- Shift held: tooltips show every line. Holding or letting go redraws the open tooltip.
function GP.TooltipFull() return IsShiftKeyDown and IsShiftKeyDown() or false end
GP:On("MODIFIER_STATE_CHANGED", function(key)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
    if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then pcall(GameTooltip.RefreshData, GameTooltip) end
end)

-- Gear: sell, auction or disenchant? One line with the best move, then what disenchanting gives
-- and who can do it (or which skill it needs).
local function moveText(src, d, who)
    -- Bright colours only: tooltips sit on all sorts of backgrounds, and grey text drowns.
    if src == "DE" then
        for _, n in ipairs(who or {}) do if n == UnitName("player") then return L["|cffe0c0ffdisenchant|r"] end end
        return L["|cffe0c0ffsend to "] .. ((who and who[1]) or L["an enchanter"]) .. L[" to disenchant|r"]
    elseif src == "AH" then return L["|cffffd040sell on the AH|r"] end
    return L["|cffffffffsell to a vendor|r"]
end

local function whoText(who)
    local out = {}
    for _, n in ipairs(who or {}) do out[#out + 1] = (n == UnitName("player")) and "you" or n end
    return table.concat(out, ", ")
end

local function matList(list, max)
    local parts = {}
    for i, m in ipairs(list) do
        if i > max then break end
        parts[#parts + 1] = string.format("%s x%d", GP.ItemInfo(m[1]) or "?", m[2])
    end
    return table.concat(parts, ", ")
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if not GP.db or tooltip ~= GameTooltip or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    link = GP.Safe(link)
    if not link then return end
    local info = GP.LinkInfo(link)
    if info.classID ~= 2 and info.classID ~= 4 then return end
    if (info.quality or 0) < 2 or (info.quality or 0) > 4 then return end
    local bound = info.bindType == 1
    local id = tonumber(link:match("item:(%d+)"))
    local best, src, d = GP:BagValue(id, link, bound)
    local _, outcomes, who, _, estimate = GP:DisenchantValue(link, bound, info)
    local sellsFor = math.max(best or 0, d.vendor or 0, (select(11, ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(link))) or 0)
    if GP.db.settings.deForMats and src ~= "DE" and GP.CanDisenchantMyself(d) and not (d.de and d.de > 0 and sellsFor > d.de * 3) then
        tooltip:AddDoubleLine(L["|cffffd040Haulwise|r best: "] .. L["|cffe0c0ffdisenchant for mats|r"], d.de and ("~" .. GP.Coins(d.de, true)) or "", 1, 1, 1, 1, 1, 1)
    else
        tooltip:AddDoubleLine(L["|cffffd040Haulwise|r best: "] .. moveText(src, d, d.deWho), GP.Coins(best, true), 1, 1, 1, 1, 1, 1)
    end
    if not outcomes or not GP.db.settings.tooltipDisenchant then return end
    local right = estimate and ("~" .. GP.Coins(estimate, true)) or L["|cffffb060no price yet: scan the AH|r"]
    local left = (who and #who > 0) and (L["  Disenchant |cffffffff("] .. whoText(who) .. ")|r") or L["  Disenchant |cffffb060(learn Enchanting)|r"]
    tooltip:AddDoubleLine(left, right, 0.88, 0.75, 1, 1, 1, 1)
    local sorted = {}
    for i, o in ipairs(outcomes) do sorted[i] = o end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    for _, o in ipairs(sorted) do
        local name = GP.ItemInfo(o[1]) or ("#" .. o[1])
        local qty = o[3] == o[4] and tostring(o[3]) or (o[3] .. "-" .. o[4])
        tooltip:AddDoubleLine(string.format("    %3.0f%%   %s x %s", o[2] * 100, name, qty),
            o.unit and (GP.Coins(o.unit, true) .. L[" each"]) or "", 0.95, 0.95, 0.95, 1, 1, 1)
    end
    local mine, similar = GP:DisenchantHistory(id, info)
    if mine then
        tooltip:AddLine(string.format(L["    You got from %d: %s"], mine.n, matList(mine.list, 3)), 0.45, 1, 0.45, true)
    elseif similar then
        tooltip:AddLine(string.format(L["    Items like this (%d done): %s"], similar.n, matList(similar.list, 3)), 0.45, 1, 0.45, true)
    end
end)

-- Gear: is this an upgrade for you?
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if not GP.db or tooltip ~= GameTooltip or not GP.db.settings.upgradeAdvisor or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    link = GP.Safe(link)
    if not link or not GP.CompareGear then return end
    -- Pawn already marks upgrades in its own tooltip lines; don't say it twice.
    if GP:UsePawn() or not GP.MeForGear then return end
    local r = GP:CompareGear(link, GP.MeForGear())
    if r then
        tooltip:AddLine(string.format(L["|cffffd040Haulwise|r |cff5fd35fupgrade for you +%.0f%%|r%s"], r.gain * 100,
            r.atLevel and (L[" at level "] .. r.atLevel) or ""))
    end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
    if not GP.db or tooltip ~= GameTooltip then return end
    local _, unit = tooltip:GetUnit()
    unit = GP.Safe(unit)
    if not unit then return end
    local npc = GP.NpcFromGUID(UnitGUID(unit))
    local m = npc and GP:MergedMobs()[npc]
    -- From the first kill: with few, the line says how rough it still is.
    if not m or (m.kills < 1 and not m.est) then return end
    local r = GP:Evaluate(npc, m)
    if r.estOnly then
        -- Nobody has shared kills of it yet: Classic's loot tables, said plainly.
        tooltip:AddLine(string.format(L["|cffffd700Haulwise|r ~%s/h  (%s per kill, estimate)"],
            GP.Coins(r.est, true), GP.Coins(r.perKill, true)), 1, 1, 1)
    else
        local word, color = GP.Confidence(r.kills)
        tooltip:AddLine(string.format(L["|cffffd700Haulwise|r %s/h  (%s per kill, %d kills)"],
            GP.Coins(r.est, true), GP.Coins(r.perKill, true), r.kills) .. (r.kills < 30 and ("  " .. color .. word .. "|r") or ""), 1, 1, 1)
    end
end)
