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
