-- Haulwise: where to get recipes, learned from the game itself as you play.
--   Trainer  when you open a profession trainer: every recipe it teaches, cost and skill needed
--   Vendor   when you open a vendor: every pattern/recipe it sells, price, limited stock
--   Drop     from Haulwise's own kill tracking (and community data): which mobs drop it, how often
--   AH       from your auction house scans
-- Recipes are matched by name: the pattern "Pattern: Red Linen Robe" teaches "Red Linen Robe".
local _, GP = ...

local RECIPE_CLASS = 9

function GP.RecipeKey(name)
    if not name then return nil end
    local key = (name:gsub("^[^:]+:%s*", "")):lower():match("^%s*(.-)%s*$")
    return key ~= "" and key or nil
end

local function where()
    local zone = GP.Safe(GetRealZoneText and GetRealZoneText()) or "?"
    local sub = GP.Safe(GetSubZoneText and GetSubZoneText())
    if sub and sub ~= "" and sub ~= zone then return sub .. ", " .. zone end
    return zone
end

local function npcName()
    return GP.Safe(UnitName("npc")) or GP.Safe(UnitName("target")) or "?"
end

local function entry(key)
    local db = GP.db.sources
    local e = db[key]
    if not e then e = { trainer = {}, vendor = {} }; db[key] = e end
    return e
end

-- Remember which item teaches which recipe (from vendors, bags, loot and AH scans).
function GP:NoteRecipeItem(itemID, name)
    if not itemID or not name then return end
    local key = GP.RecipeKey(name)
    if key then self.db.recipeItems[key] = itemID end
end

-- Trainer ----------------------------------------------------------------------------------------

local function readTrainer()
    if not GetNumTrainerServices then return end
    -- Show everything (available, not yet available, already known) while we read, then restore.
    local saved = {}
    if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
        for _, f in ipairs({ "available", "unavailable", "used" }) do
            saved[f] = GetTrainerServiceTypeFilter(f)
            pcall(SetTrainerServiceTypeFilter, f, 1)
        end
    end
    local trainer, place, n = npcName(), where(), 0
    for i = 1, GetNumTrainerServices() do
        local name, _, category = GetTrainerServiceInfo(i)
        if name and category ~= "header" then
            local skillName, skillLevel = nil, nil
            if GetTrainerServiceSkillReq then skillName, skillLevel = GetTrainerServiceSkillReq(i) end
            if skillName and skillName ~= "" then
                local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
                entry(name:lower()).trainer[trainer] = { zone = place, cost = cost, skill = skillLevel, prof = skillName, t = time() }
                n = n + 1
            end
        end
    end
    if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
        for f, v in pairs(saved) do pcall(SetTrainerServiceTypeFilter, f, v and 1 or 0) end
    end
    if n > 0 and GP.debug then GP.Print(string.format("Noted %d recipes taught by %s.", n, trainer)) end
end
GP:On("TRAINER_SHOW", function() C_Timer.After(0.3, readTrainer) end)

-- Vendor -----------------------------------------------------------------------------------------

GP:On("MERCHANT_SHOW", function()
    C_Timer.After(0.3, function()
        if not (GetMerchantNumItems and GetMerchantItemID) then return end
        local vendor, place = npcName(), where()
        local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        for i = 1, GetMerchantNumItems() do
            local id = GetMerchantItemID(i)
            local classID = id and instant and select(6, instant(id))
            if classID == RECIPE_CLASS then
                local name, price, stock
                if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                    local info = C_MerchantFrame.GetItemInfo(i)
                    if info then name, price, stock = info.name, info.price, info.numAvailable end
                else
                    local n, _, p, _, avail = GetMerchantItemInfo(i)
                    name, price, stock = n, p, avail
                end
                if name then
                    GP:NoteRecipeItem(id, name)
                    entry(GP.RecipeKey(name)).vendor[vendor] = { zone = place, price = price or 0, limited = (stock or -1) >= 0, item = id, t = time() }
                end
            end
        end
    end)
end)

-- Recipe items seen in bags or on the AH ----------------------------------------------------------

GP:On("BAG_UPDATE_DELAYED", function()
    for _, bag in ipairs(GP.BagIDs()) do
        for slot = 1, GP.NumSlots(bag) do
            local it = GP.SlotInfo(bag, slot)
            if it and it.itemID and it.hyperlink then
                local info = GP.LinkInfo(it.hyperlink)
                if info.classID == RECIPE_CLASS then GP:NoteRecipeItem(it.itemID, info.name) end
            end
        end
    end
end)

function GP:OnScanFinished()
    for id, p in pairs(self.db.prices) do
        if p.k == RECIPE_CLASS and p.n then self:NoteRecipeItem(id, p.n) end
    end
end

-- Putting it together ----------------------------------------------------------------------------

-- Shared data sets: community data shipped with Haulwise and friends' imports.
function GP:SharedSources()
    local out = {}
    if self.community then out[#out + 1] = self.community end
    for _, src in pairs(self.db.shared) do out[#out + 1] = src end
    return out
end

-- All known ways to get a recipe: { { kind, text, cost, detail }, ... } cheapest first, and the
-- cheapest known cost to get it (or nil).
function GP:RecipeSources(recipeName, itemID)
    local key = GP.RecipeKey(recipeName)
    local out, cheapest = {}, nil
    local function consider(cost) if cost and cost > 0 and (not cheapest or cost < cheapest) then cheapest = cost end end
    -- Your own sightings, plus the community's and friends' (shared data never overrides yours).
    local entries = { key and self.db.sources[key] }
    if key and self.db.settings.useShared then
        for _, srcData in ipairs(self:SharedSources()) do
            if srcData.sources and srcData.sources[key] then entries[#entries + 1] = srcData.sources[key] end
        end
    end
    local seenT, seenV = {}, {}
    for _, e in ipairs(entries) do
        local copy = { trainer = {}, vendor = {} }
        for npc, t in pairs(e.trainer or {}) do if not seenT[npc] then seenT[npc] = true; copy.trainer[npc] = t end end
        for npc, v in pairs(e.vendor or {}) do if not seenV[npc] then seenV[npc] = true; copy.vendor[npc] = v end end
        e = copy
        for npc, t in pairs(e.trainer) do
            out[#out + 1] = { kind = "Trainer", who = npc, zone = t.zone, cost = t.cost, skill = t.skill }
            consider(t.cost)
        end
        for npc, v in pairs(e.vendor) do
            out[#out + 1] = { kind = "Vendor", who = npc, zone = v.zone, cost = v.price, limited = v.limited }
            consider(v.price)
            if v.item and v.item > 0 then itemID = itemID or v.item end
        end
    end
    itemID = itemID or (key and self.db.recipeItems[key])
    if not itemID and key then
        for _, srcData in ipairs(self:SharedSources()) do
            if srcData.recipeItems and srcData.recipeItems[key] then itemID = srcData.recipeItems[key]; break end
        end
    end
    if itemID then
        for _, s in ipairs(self:SourcesFor(itemID, 3)) do
            out[#out + 1] = { kind = "Drop", who = s.name, chance = s.chance, kills = s.kills }
        end
        local ah = self:Price(itemID)
        if ah then out[#out + 1] = { kind = "AH", cost = ah }; consider(ah) end
    end
    local order = { Trainer = 1, Vendor = 2, AH = 3, Drop = 4 }
    table.sort(out, function(a, b)
        if a.kind ~= b.kind then return order[a.kind] < order[b.kind] end
        return (a.cost or 0) < (b.cost or 0)
    end)
    return out, cheapest, itemID
end

function GP.SourceShort(s)
    if s.kind == "Trainer" then
        return string.format("|cffffd040Trainer|r %s%s", GP.Coins(s.cost or 0, true), s.skill and ("|cff8a8880 · skill " .. s.skill .. "|r") or "")
    elseif s.kind == "Vendor" then
        return string.format("|cff5fd35fVendor|r %s |cff8a8880%s%s|r", GP.Coins(s.cost or 0, true), s.who or "?", s.limited and " (limited)" or "")
    elseif s.kind == "Drop" then
        return string.format("|cffc48cffDrop|r %s |cff8a8880%.1f%%|r", s.who or "?", (s.chance or 0) * 100)
    elseif s.kind == "AH" then
        return "|cff88ccffAH|r " .. GP.Coins(s.cost or 0, true)
    end
    return ""
end

function GP.SourceLong(s)
    if s.kind == "Trainer" then
        return string.format("Trainer: %s, %s", s.who or "?", s.zone or "?"),
            GP.Coins(s.cost or 0) .. (s.skill and ("  (skill " .. s.skill .. ")") or "")
    elseif s.kind == "Vendor" then
        return string.format("Vendor: %s, %s%s", s.who or "?", s.zone or "?", s.limited and "  (limited stock)" or ""), GP.Coins(s.cost or 0)
    elseif s.kind == "Drop" then
        return string.format("Drop: %s", s.who or "?"), string.format("%.1f%% of %d kills", (s.chance or 0) * 100, s.kills or 0)
    elseif s.kind == "AH" then
        return "Auction house", GP.Coins(s.cost or 0)
    end
    return "?", ""
end
