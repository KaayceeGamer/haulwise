-- Haulwise: adds drop sources to item tooltips and gold/hour to mob tooltips.
local _, GP = ...

if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, info)
    if not GP.db or tooltip ~= GameTooltip then return end
    local id = info and GP.Safe(info.id)
    if not id then return end
    local sources = GP:SourcesFor(id, 3)
    local value, ah = GP:ItemValue(id)
    if #sources == 0 and not ah then return end
    tooltip:AddLine(" ")
    if ah then
        local trend = GP.Trend and GP:Trend(id)
        local right = GP.Coins(ah)
        if trend then right = right .. string.format(trend >= 0 and "  |cff5fd35f+%.0f%%|r" or "  |cffff6b5b%.0f%%|r", trend * 100) end
        tooltip:AddDoubleLine("|cffffd700Haulwise|r AH (after cut)", right, 1, 1, 1, 1, 1, 1)
    end
    local craft, craftName = GP:CraftValue(id)
    if craft and craft > (value or 0) then
        tooltip:AddDoubleLine("  Worth more as " .. (craftName or "?"), GP.Coins(craft) .. " each", 0.53, 0.8, 1, 0.53, 0.8, 1)
    end
    for _, s in ipairs(sources) do
        tooltip:AddDoubleLine("  " .. s.name, string.format("%.0f%%  (%d kills)", s.chance * 100, s.kills),
            0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
    end
end)

-- Gear: sell, auction or disenchant? One line with the best move, then what disenchanting gives
-- and who can do it (or which skill it needs).
local function moveText(src, d, who)
    if src == "DE" then
        for _, n in ipairs(who or {}) do if n == UnitName("player") then return "|cffc48cffdisenchant|r" end end
        return "|cffc48cffsend to " .. ((who and who[1]) or "an enchanter") .. " to disenchant|r"
    elseif src == "AH" then return "|cffffd040sell on the AH|r" end
    return "|cffaaaaaasell to a vendor|r"
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
    local _, outcomes, who, need, estimate = GP:DisenchantValue(link, bound, info)
    tooltip:AddDoubleLine("|cffffd040Haulwise|r best: " .. moveText(src, d, d.deWho), GP.Coins(best, true), 1, 1, 1, 1, 1, 1)
    if outcomes then
        local right = estimate and ("~" .. GP.Coins(estimate, true)) or "|cff999999no price: scan the AH|r"
        local whoText
        if who and #who > 0 then
            whoText = "|cff8a8880" .. table.concat(who, ", ") .. "|r"
        else
            local mine = GP:MyProfessions()["Enchanting"]
            whoText = string.format("|cffff9944needs Enchanting %d%s|r", need or 0,
                mine and mine.rank and string.format(" (you: %d)", mine.rank) or "")
        end
        tooltip:AddDoubleLine("  Disenchant  " .. whoText, right, 0.77, 0.55, 1, 0.77, 0.55, 1)
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
        tooltip:AddLine(string.format("|cffffd040Haulwise|r |cff5fd35fupgrade for you +%.0f%%|r%s", r.gain * 100,
            r.atLevel and (" at level " .. r.atLevel) or ""))
    end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
    if not GP.db or tooltip ~= GameTooltip then return end
    local _, unit = tooltip:GetUnit()
    unit = GP.Safe(unit)
    if not unit then return end
    local npc = GP.NpcFromGUID(UnitGUID(unit))
    local m = npc and GP:MergedMobs()[npc]
    if not m or m.kills < 10 then return end
    local r = GP:Evaluate(npc, m)
    tooltip:AddLine(string.format("|cffffd700Haulwise|r %s/h  (%s per kill, %d kills)",
        GP.Coins(r.est, true), GP.Coins(r.perKill, true), r.kills), 1, 1, 1)
end)
