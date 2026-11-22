-- /haul perf: how much memory Haulwise uses, and how long its heaviest work takes, so slow
-- spots (like the Recipes tab that stuttered) can be found from a player's own game.
local _, GP = ...
local L = GP.L

local function ms(fn)
    local clock = debugprofilestop or function() return (os and os.clock and os.clock() or 0) * 1000 end
    local t0 = clock()
    local ok, n = pcall(fn)
    local took = clock() - t0
    local count = ok and type(n) == "table" and #n or nil
    return took, ok, count
end

local function size(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- Memory in KB for an addon, or nil where the game doesn't tell.
local function memory(name)
    local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    if not get then return nil end
    local ok, kb = pcall(get, name)
    return ok and kb or nil
end

function GP:Perf()
    local P = GP.Print
    P(L["Performance:"])
    -- Memory as the game counts it includes garbage Lua hasn't swept up yet; sweep first, so
    -- the number is what Haulwise really keeps.
    if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
    local before = memory("Haulwise")
    if collectgarbage then collectgarbage("collect") end
    if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
    local a, b = memory("Haulwise"), memory("HaulwiseData")
    if a then
        P(string.format(L["  memory: Haulwise %.1f MB, Haulwise Data %.1f MB, together %.1f MB"], a / 1024, (b or 0) / 1024, (a + (b or 0)) / 1024)
            .. (before and before > a + 512 and string.format(L["  (%.1f MB before Lua swept up its garbage)"], before / 1024) or ""))
    end
    local db = self.db
    P(string.format(L["  saved: %d mobs, %d prices, %d price histories, %d names, %d sales, %d characters"],
        size(db.mobs), size(db.prices), size(db.history), size(db.names), #(db.sales or {}), size(db.chars)))

    -- Each list worked out from scratch (caches skipped), slowest first.
    self.recipeRowsCache, self.enchantRowsCache = nil, nil
    local jobs = {
        { L["Farm"], function() return self:Rank() end },
        { L["Zones"], function() return self:ZoneRows() end },
        { L["Bags"], function() return self:BagItems() end },
        { L["Gear on the AH"], function() return self:AHUpgradeRows() end },
        { L["Craft"], function() return self:CraftRows() end },
        { L["Skill up"], function() return self:SkillRows() end },
        { L["Recipes"], function() return self:RecipeRows() end },
        { L["Deals"], function() return self:Deals() end },
        { L["Market"], function() return self:MarketRows() end },
        { L["Your sales"], function() return self:SalesRows(30) end },
        { L["Holdings"], function() return self:HoldingsRows() end },
        { L["Enchant requests"], function() return self:EnchantDemand(7) end },
    }
    local out = {}
    for _, j in ipairs(jobs) do
        local took, ok, n = ms(j[2])
        out[#out + 1] = { name = j[1], took = took, ok = ok, n = n }
    end
    table.sort(out, function(x, y) return x.took > y.took end)
    for _, r in ipairs(out) do
        local color = r.took > 100 and "|cffff6b5b" or (r.took > 30 and "|cffffd060" or "|cff5fd35f")
        P(string.format("  %s%5.0f ms|r  %s%s%s", color, r.took, r.name,
            r.n and string.format(L[" (%d rows)"], r.n) or "", r.ok and "" or " |cffff6b5b" .. L["error"] .. "|r"))
    end
    P(L["  Red is slow enough to notice. Paste this in a bug report if something stutters."])
end
