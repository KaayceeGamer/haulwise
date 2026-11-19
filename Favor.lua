-- Haulwise: Forever's supply crates and crafting orders, priced.
-- * Waylaid Crate: its description lists two to five ways to fill it ("20 Peacebloom", "10
--   Briarthorn"...). The tooltip prices each way at what the materials cost you (what you'd get
--   selling the ones you have, what buying the rest costs), marks the cheapest, and says what
--   one Merchant's Favor costs that way.
-- * Sealed crate: how much Merchant's Favor it gives.
-- * Craftsman's Writ: what the ordered item costs to buy or to craft yourself.
-- Item names are matched in English; other client languages simply don't get these lines.
local _, GP = ...
local L = GP.L

-- Merchant's Favor per sealed crate, white quality; green pays double. Artisan isn't known yet.
local FAVOR = { Apprentice = 5, Journeyman = 10, Expert = 15 }

local function itemID(name)
    if not name or name == "" then return nil end
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if get then
        local ok, id = pcall(get, name)
        if ok and type(id) == "number" then return id end
    end
    for id, n in pairs(GP.db.names or {}) do if n == name then return id end end
    return nil
end
GP.ItemIDForName = itemID

local function count(id)
    local get = (C_Item and C_Item.GetItemCount) or GetItemCount
    local ok, n = pcall(get, id, true)
    return ok and (GP.Safe(n) or 0) or 0
end

-- "20 Peacebloom", "20x Peacebloom", "Peacebloom x20", "Peacebloom (20)", "Peacebloom: 20".
local function parseBundle(text)
    text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^[%-•*]%s*", ""):gsub("^or%s+", "")
    local n, name = text:match("(%d+)%s*[xX]?%s+(%a.*)$")
    if not n then name, n = text:match("^(.-)%s*[xX]%s*(%d+)$") end
    if not n then name, n = text:match("^(.-)%s*%((%d+)%)$") end
    if not n then name, n = text:match("^(.-):%s*(%d+)$") end
    if not n then return nil end
    name = name:gsub("[%.%s]+$", "")
    local id = itemID(name)
    if id then return id, tonumber(n) end
end

-- Every bundle a crate's tooltip lists, as { id, n }, from the tooltip lines after the name.
function GP.CrateBundles(lines)
    local out, seen = {}, {}
    for i = 2, #lines do
        local text = lines[i]
        if type(text) == "string" and text ~= "" then
            for part in (text .. ","):gmatch("([^,;\n]+)[,;\n]") do
                for piece in (part .. " or "):gmatch("(.-)%s+or%s+") do
                    local id, n = parseBundle(piece)
                    if id and not seen[id] then seen[id] = true; out[#out + 1] = { id = id, n = n } end
                end
            end
        end
    end
    return out
end

-- What filling with one bundle costs you: the ones you have at what they'd sell for, the rest
-- at the cheapest place to buy them. Nil when there's no price for what you'd have to buy.
function GP:BundleCost(id, n)
    local have = math.min(n, count(id))
    local sellValue = self:ItemValue(id) or 0
    local cost = have * sellValue
    local buy = n - have
    if buy > 0 then
        local unit = self:BuyCost(id)
        if not unit then return nil, have end
        cost = cost + unit * buy
    end
    return cost, have
end

-- Favor for a crate from its name ("Waylaid Crate: Journeyman Parts", "Sealed Expert Crate")
-- and quality (2 = green: double). Nil when unknown.
function GP.CrateFavor(name, quality)
    local tier = name and (name:match("Waylaid Crate: (%a+)") or name:match("Sealed (%a+) Crate"))
    local base = tier and FAVOR[tier]
    if not base then return nil end
    return (quality or 1) >= 2 and base * 2 or base
end

local function lineTexts(info)
    local out = {}
    for i, l in ipairs(info and info.lines or {}) do out[i] = GP.Safe(l.leftText) or "" end
    return out
end

if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, info)
    if not GP.db or tooltip ~= GameTooltip then return end
    local id = info and GP.Safe(info.id)
    if not id then return end
    local name, quality = GP.ItemInfo(id)
    if not name then return end
    local ok, err = pcall(function()
        if name:find("^Waylaid Crate") then
            local bundles = GP.CrateBundles(lineTexts(info))
            if #bundles == 0 then return end
            local favor = GP.CrateFavor(name, quality)
            tooltip:AddLine(" ")
            tooltip:AddLine(L["|cffffd700Haulwise|r  fill it with one of these:"])
            local best
            for _, b in ipairs(bundles) do
                b.cost, b.have = GP:BundleCost(b.id, b.n)
                if b.cost and (not best or b.cost < best.cost) then best = b end
            end
            for _, b in ipairs(bundles) do
                local right = b.cost and GP.Coins(b.cost, true) or L["|cffff9944no price|r"]
                if b.have >= b.n then right = right .. L["  |cff5fd35fyou have them|r"] end
                local left = string.format("  %s %d %s", b == best and "|cff5fd35f>|r" or " ", b.n, GP.ItemInfo(b.id) or "?")
                tooltip:AddDoubleLine(left, right, 0.9, 0.9, 0.9, 1, 1, 1)
            end
            if best and favor then
                tooltip:AddDoubleLine(string.format(L["  %d Merchant's Favor"], favor),
                    string.format(L["%s per Favor"], GP.Coins(best.cost / favor, true)), 0.53, 0.8, 1, 0.53, 0.8, 1)
            end
        elseif name:find("^Sealed %a+ Crate") then
            local favor = GP.CrateFavor(name, quality)
            if favor then
                tooltip:AddLine(" ")
                tooltip:AddLine(string.format(L["|cffffd700Haulwise|r  %d Merchant's Favor at your trading camp"], favor))
            end
        elseif name:find("^Craftsman's Writ: ") then
            local wanted = itemID(name:match("^Craftsman's Writ: (.+)$"))
            if not wanted then return end
            tooltip:AddLine(" ")
            tooltip:AddLine(string.format(L["|cffffd700Haulwise|r  order for %s"], GP.ItemInfo(wanted) or "?"))
            local have = count(wanted)
            if have > 0 then tooltip:AddDoubleLine(L["  You have"], tostring(have), 0.8, 0.8, 0.8, 0.37, 0.83, 0.37) end
            local buy, where = GP:BuyCost(wanted)
            if buy then tooltip:AddDoubleLine(L["  Buy one"], GP.Coins(buy) .. " " .. (where == "vendor" and L["vendor"] or "AH"), 0.8, 0.8, 0.8, 1, 1, 1) end
            local craft = GP.CraftCostFor and GP:CraftCostFor(wanted)
            if craft then tooltip:AddDoubleLine(L["  Craft one yourself"], GP.Coins(craft), 0.8, 0.8, 0.8, 1, 1, 1) end
            if not buy and not craft then tooltip:AddLine(L["  No price yet: scan the AH, or open the profession that makes it."], 1, 0.6, 0.3, true) end
            tooltip:AddLine(L["  The quest says how many it wants and who gets them."], 0.6, 0.6, 0.6)
        end
    end)
    if not ok then GP.ReportError("crate tooltip", err) end
end)
