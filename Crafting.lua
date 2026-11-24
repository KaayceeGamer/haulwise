-- Haulwise: crafting profit from the professions you actually have.
--
-- Open a profession window once and Haulwise remembers every recipe in it: learned ones become
-- the Craft tab (cost of reagents vs what the result sells for), unlearned ones feed the
-- Recipes tab (is this pattern worth buying or farming?). Reagent costs use the cheapest of
-- the AH and any vendor you've visited, so thread, salt and vials are priced right.
local _, GP = ...
local L = GP.L

local BASIC = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1

-- Recipe item subclasses (item class 9) per profession, for spotting patterns on the AH.
GP.RECIPE_SUBCLASS = {
    ["Leatherworking"] = 1, ["Tailoring"] = 2, ["Engineering"] = 3, ["Blacksmithing"] = 4,
    ["Cooking"] = 5, ["Alchemy"] = 6, ["First Aid"] = 7, ["Enchanting"] = 8, ["Fishing"] = 9,
    ["Jewelcrafting"] = 10, ["Inscription"] = 11,
}

-- Professions are stored under their English name whatever the game's language, so recipes,
-- disenchanting and alts line up across clients; L[name] shows them in your language.
local PROF_BY_LINE = {
    [171] = "Alchemy", [164] = "Blacksmithing", [185] = "Cooking", [333] = "Enchanting", [202] = "Engineering",
    [129] = "First Aid", [356] = "Fishing", [182] = "Herbalism", [773] = "Inscription", [755] = "Jewelcrafting",
    [165] = "Leatherworking", [186] = "Mining", [393] = "Skinning", [197] = "Tailoring",
}
local PROF_BY_NAME = {
    -- German
    ["Alchemie"] = "Alchemy", ["Schmiedekunst"] = "Blacksmithing", ["Kochkunst"] = "Cooking",
    ["Verzauberkunst"] = "Enchanting", ["Ingenieurskunst"] = "Engineering", ["Erste Hilfe"] = "First Aid",
    ["Angeln"] = "Fishing", ["Kräuterkunde"] = "Herbalism", ["Inschriftenkunde"] = "Inscription",
    ["Juwelierskunst"] = "Jewelcrafting", ["Juwelenschleifen"] = "Jewelcrafting", ["Lederverarbeitung"] = "Leatherworking",
    ["Bergbau"] = "Mining", ["Kürschnerei"] = "Skinning", ["Schneiderei"] = "Tailoring",
    -- French
    ["Alchimie"] = "Alchemy", ["Forge"] = "Blacksmithing", ["Cuisine"] = "Cooking", ["Enchantement"] = "Enchanting",
    ["Ingénierie"] = "Engineering", ["Secourisme"] = "First Aid", ["Pêche"] = "Fishing", ["Herboristerie"] = "Herbalism",
    ["Calligraphie"] = "Inscription", ["Joaillerie"] = "Jewelcrafting", ["Travail du cuir"] = "Leatherworking",
    ["Minage"] = "Mining", ["Dépeçage"] = "Skinning", ["Couture"] = "Tailoring",
}
GP.PROF_BY_LINE = PROF_BY_LINE

function GP.ProfKey(name, skillLine)
    if skillLine and PROF_BY_LINE[skillLine] then return PROF_BY_LINE[skillLine] end
    if not name then return nil end
    return PROF_BY_NAME[name] or name
end

-- Data saved by a German or French client before 0.7.0 used the local names: move it over once.
function GP:NormalizeProfessions()
    for _, c in pairs(self.db.chars or {}) do
        if c.profs then
            local fixed = {}
            for name, p in pairs(c.profs) do
                local k = GP.ProfKey(name)
                if not fixed[k] or (p.t or 0) > (fixed[k].t or 0) then fixed[k] = p end
            end
            c.profs = fixed
        end
        for _, rec in pairs(c.recipes or {}) do if rec.prof then rec.prof = GP.ProfKey(rec.prof) end end
    end
    for _, e in pairs(self.db.sources or {}) do
        for _, t in pairs(e.trainer or {}) do if t.prof then t.prof = GP.ProfKey(t.prof) end end
    end
end
GP:On("PLAYER_LOGIN", function() if GP.db then GP:NormalizeProfessions() end end)

function GP:CharKey()
    return (UnitName("player") or "?") .. "-" .. GP.RealmName()
end

-- A record of this character saved under another key (the realm was "" or "?" then): fold it
-- into this one. Per profession, the newer reading wins; bags, bank and the rest come from
-- whichever record was used last.
local PER_PROF = { "recipes", "services" }
local function invalidateLater() if GP.InvalidateCraftIndex then GP.InvalidateCraftIndex() end end
local function newest(c)
    local t = 0
    for _, v in pairs(c.seen or {}) do if type(v) == "number" and v > t then t = v end end
    for _, p in pairs(c.profs or {}) do if (p.t or 0) > t then t = p.t end end
    return t
end
function GP:MergeCharRecords()
    local name = UnitName and UnitName("player")
    local realm = GP.RealmName()
    if not name or realm == "?" then return end -- only once the realm is known
    local key = name .. "-" .. realm
    local chars = self.db.chars
    for _, oldKey in ipairs({ name .. "-", name .. "-?" }) do
        local old = chars[oldKey]
        if old and oldKey ~= key then
            local cur = chars[key]
            if not cur then
                chars[key] = old
            else
                cur.profs, cur.recipes, cur.services = cur.profs or {}, cur.recipes or {}, cur.services or {}
                for prof, p in pairs(old.profs or {}) do
                    local mine = cur.profs[prof]
                    if not mine or (p.t or 0) > (mine.t or 0) then
                        cur.profs[prof] = p
                        for _, book in ipairs(PER_PROF) do
                            for k, rec in pairs(cur[book]) do if rec.prof == prof then cur[book][k] = nil end end
                            for k, rec in pairs(old[book] or {}) do if rec.prof == prof then cur[book][k] = rec end end
                        end
                    end
                end
                if newest(old) > newest(cur) then
                    for k, v in pairs(old) do
                        if k ~= "profs" and k ~= "recipes" and k ~= "services" and k ~= "shopping" then cur[k] = v end
                    end
                end
                for id, n in pairs(old.shopping or {}) do
                    cur.shopping = cur.shopping or {}
                    cur.shopping[id] = math.max(cur.shopping[id] or 0, n)
                end
            end
            chars[key].realm = realm
            chars[oldKey] = nil
        end
    end
end
GP:On("PLAYER_ENTERING_WORLD", function() if GP.db then GP:MergeCharRecords(); invalidateLater() end end)

function GP:Char()
    local key = self:CharKey()
    local c = self.db.chars[key]
    if not c then c = { profs = {}, recipes = {} }; self.db.chars[key] = c end
    c.services = c.services or {}
    return c
end

-- Recipes that make no item (enchants) live apart, in char.services: everything that prices a
-- result skips them, but the Recipes tab, Skill up and the shopping list use them too.
function GP:RecipeByKey(key)
    local c = self:Char()
    return c.recipes[key] or c.services[key]
end

local function packReagents(list)
    local parts = {}
    for _, r in ipairs(list) do parts[#parts + 1] = r[1] .. ":" .. r[2] end
    return table.concat(parts, "/")
end

function GP.UnpackReagents(s)
    local out = {}
    for id, q in (s or ""):gmatch("(%d+):([%d%.]+)") do out[#out + 1] = { tonumber(id), tonumber(q) } end
    return out
end

local index -- [reagentID] = { recipeKey, ... }, rebuilt when recipes change
local function invalidate() index = nil; GP.recipeRowsCache = nil end
GP.InvalidateCraftIndex = invalidate

-- Reading the profession window -------------------------------------------------------

-- The profession a recipe belongs to, when the game says (nil when it can't).
local function recipeProf(rid)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineForRecipe) then return nil end
    local ok, id, name, parent = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, rid)
    if not ok or not (id or name) then return nil end
    return GP.ProfKey(name, parent or id)
end

local function readModern(char)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetBaseProfessionInfo) then return false end
    if C_TradeSkillUI.IsTradeSkillLinked and C_TradeSkillUI.IsTradeSkillLinked() then return true end
    if C_TradeSkillUI.IsTradeSkillGuild and C_TradeSkillUI.IsTradeSkillGuild() then return true end
    local base = C_TradeSkillUI.GetBaseProfessionInfo()
    local prof = base and GP.ProfKey(base.professionName, base.parentProfessionID or base.professionID)
    if not prof or prof == "" then return false end
    char.profs[prof] = { rank = base.skillLevel, max = base.maxSkillLevel, t = time() }
    local n = 0
    for _, rid in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
        -- The game can list other professions' recipes too (Tailoring's while Cooking is open):
        -- each recipe is filed under its own profession, and only the open one's are read.
        local own = recipeProf(rid)
        if own and own ~= prof then
            local old = char.recipes["r" .. rid] or char.services["r" .. rid]
            if old and old.prof == prof then old.prof = own end -- filed wrong by an older Haulwise
            rid = nil
        end
        local info = rid and C_TradeSkillUI.GetRecipeInfo(rid)
        local sch = rid and C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(rid, false)
        if info and info.learned and prof == "Enchanting" and not (sch and sch.outputItemID) then
            GP:NoteKnownEnchant(info.name)
        end
        if info and sch and not sch.outputItemID and info.name then
            local reagents = {}
            for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
                if slot.reagentType == BASIC or slot.required then
                    local r = slot.reagents and slot.reagents[1]
                    if r and r.itemID then reagents[#reagents + 1] = { r.itemID, slot.quantityRequired or 1 } end
                end
            end
            char.services = char.services or {}
            char.services["r" .. rid] = {
                n = info.name, prof = prof, r = packReagents(reagents), icon = info.icon,
                learned = info.learned and true or false, d = info.learned and info.relativeDifficulty or nil,
                src = (not info.learned and C_TradeSkillUI.GetRecipeSourceText) and C_TradeSkillUI.GetRecipeSourceText(rid) or nil,
            }
        end
        if info and sch and sch.outputItemID then
            local reagents = {}
            for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
                if slot.reagentType == BASIC or slot.required then
                    local r = slot.reagents and slot.reagents[1]
                    if r and r.itemID then reagents[#reagents + 1] = { r.itemID, slot.quantityRequired or 1 } end
                end
            end
            local src
            if not info.learned and C_TradeSkillUI.GetRecipeSourceText then
                src = C_TradeSkillUI.GetRecipeSourceText(rid)
            end
            char.recipes["r" .. rid] = {
                n = info.name, prof = prof, out = sch.outputItemID,
                oq = ((sch.quantityMin or 1) + (sch.quantityMax or sch.quantityMin or 1)) / 2,
                r = packReagents(reagents), learned = info.learned and true or false, src = src,
                d = info.learned and info.relativeDifficulty or nil,
            }
            n = n + 1
        end
    end
    return n > 0
end

local CLASSIC_DIFFICULTY = { optimal = 0, medium = 1, easy = 2, trivial = 3 }

local function readClassic(char)
    if not (GetNumTradeSkills and GetTradeSkillLine) then return false end
    local prof, rank, max = GetTradeSkillLine()
    if not prof or prof == "UNKNOWN" then return false end
    prof = GP.ProfKey(prof)
    char.profs[prof] = { rank = rank, max = max, t = time() }
    for i = 1, GetNumTradeSkills() do
        local name, kind = GetTradeSkillInfo(i)
        if name and kind ~= "header" and kind ~= "subheader" then
            local out = tonumber((GetTradeSkillItemLink(i) or ""):match("item:(%d+)"))
            if out then
                local reagents = {}
                for j = 1, GetTradeSkillNumReagents(i) do
                    local _, _, count = GetTradeSkillReagentInfo(i, j)
                    local rid = tonumber((GetTradeSkillReagentItemLink(i, j) or ""):match("item:(%d+)"))
                    if rid then reagents[#reagents + 1] = { rid, count or 1 } end
                end
                local lo, hi = GetTradeSkillNumMade(i)
                char.recipes[prof .. ":" .. name] = {
                    n = name, prof = prof, out = out, oq = ((lo or 1) + (hi or lo or 1)) / 2,
                    r = packReagents(reagents), learned = true, d = CLASSIC_DIFFICULTY[kind],
                }
            else
                if prof == "Enchanting" then GP:NoteKnownEnchant(name) end
                local reagents = {}
                for j = 1, GetTradeSkillNumReagents(i) do
                    local _, _, count = GetTradeSkillReagentInfo(i, j)
                    local rid = tonumber((GetTradeSkillReagentItemLink(i, j) or ""):match("item:(%d+)"))
                    if rid then reagents[#reagents + 1] = { rid, count or 1 } end
                end
                char.services = char.services or {}
                char.services[prof .. ":" .. name] = {
                    n = name, prof = prof, r = packReagents(reagents), learned = true, d = CLASSIC_DIFFICULTY[kind],
                    icon = GetTradeSkillIcon and GetTradeSkillIcon(i) or nil,
                }
            end
        end
    end
    return true
end

local function readProfession()
    local char = GP:Char()
    local ok = readModern(char)
    if not ok then readClassic(char) end
    invalidate()
    if GP.RefreshUI then GP:RefreshUI() end
end

for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do
    GP:On(ev, function() C_Timer.After(0.3, readProfession) end)
end

-- /haul prof: what the game says about the open profession window, and what's saved per profession.
function GP:DebugProf()
    local P = GP.Print
    local T = C_TradeSkillUI
    P(string.format("modern: GetAllRecipeIDs %s, GetBaseProfessionInfo %s, GetTradeSkillLineForRecipe %s",
        tostring(T and T.GetAllRecipeIDs ~= nil), tostring(T and T.GetBaseProfessionInfo ~= nil),
        tostring(T and T.GetTradeSkillLineForRecipe ~= nil)))
    if T and T.GetBaseProfessionInfo then
        local ok, b = pcall(T.GetBaseProfessionInfo)
        if ok and b then
            P(string.format("base: %s (id %s, parent %s) %s/%s", tostring(b.professionName), tostring(b.professionID),
                tostring(b.parentProfessionID), tostring(b.skillLevel), tostring(b.maxSkillLevel)))
        end
        local ids = T.GetAllRecipeIDs and T.GetAllRecipeIDs() or {}
        P("recipe ids: " .. #ids)
        for i = 1, math.min(3, #ids) do
            local info = T.GetRecipeInfo and T.GetRecipeInfo(ids[i])
            local line = ""
            if T.GetTradeSkillLineForRecipe then
                local ok2, id, name, parent = pcall(T.GetTradeSkillLineForRecipe, ids[i])
                line = ok2 and string.format(" line %s %s %s", tostring(id), tostring(name), tostring(parent)) or " line error"
            end
            P(string.format("  %d %s%s", ids[i], tostring(info and info.name), line))
        end
    end
    if GetTradeSkillLine then
        local name, rank, max = GetTradeSkillLine()
        P(string.format("classic: %s %s/%s, %s recipes", tostring(name), tostring(rank), tostring(max),
            tostring(GetNumTradeSkills and GetNumTradeSkills())))
        local shown = 0
        for i = 1, (GetNumTradeSkills and GetNumTradeSkills() or 0) do
            local n, kind = GetTradeSkillInfo(i)
            if kind ~= "header" and kind ~= "subheader" and shown < 3 then shown = shown + 1; P("  " .. tostring(n) .. " " .. tostring(kind)) end
        end
    end
    local per = {}
    local c = self:Char()
    for key, rec in pairs(c.recipes) do
        local k = (rec.prof or "?") .. (key:find(":") and " (by name)" or " (by id)")
        per[k] = (per[k] or 0) + 1
    end
    for k, n in pairs(per) do P(string.format("saved %s: %d", k, n)) end
    P("this character: " .. self:CharKey())
    for key, ch in pairs(self.db.chars) do
        P(string.format("  char %s: %s, %s %s", key, tostring(ch.short), tostring(ch.realm), tostring(ch.faction)))
    end
end

-- Your professions: from opened windows, plus the profession list in case you never opened one.
function GP:MyProfessions()
    local out = {}
    for name, p in pairs(self:Char().profs) do out[GP.ProfKey(name)] = p end
    if GetProfessions then
        local ok, a, b, _, fish, cook = pcall(GetProfessions)
        if ok then
            for _, idx in ipairs({ a, b, fish, cook }) do
                local name, _, rank, max, _, _, line = GetProfessionInfo(idx)
                name = GP.ProfKey(name, line)
                if name and not out[name] then out[name] = { rank = rank, max = max } end
            end
        end
    end
    return out
end

-- Profit ---------------------------------------------------------------------------------

local function farmedItems()
    local set = {}
    for _, m in pairs(GP:MergedMobs()) do
        for id in pairs(m.items) do set[id] = true end
        for id in pairs(m.gather) do set[id] = true end
    end
    return set
end

function GP:EvalRecipe(key, rec, farmed)
    local cost, missing, usesFarm = 0, {}, false
    local reagents = GP.UnpackReagents(rec.r)
    for _, r in ipairs(reagents) do
        local unit, where = self:BuyCost(r[1])
        if unit then cost = cost + unit * r[2] else missing[#missing + 1] = r[1] end
        if farmed and farmed[r[1]] then usesFarm = true end
    end
    local value, ah, vendor, listed = self:ItemValue(rec.out)
    local sell = (rec.oq or 1) * value
    local market, days = self:MarketValue(rec.out)
    return {
        key = key, name = rec.n, prof = rec.prof, out = rec.out, outQty = rec.oq or 1,
        reagents = reagents, cost = cost, sell = sell, profit = sell - cost,
        margin = cost > 0 and (sell - cost) / cost or nil, listed = listed, priced = ah ~= nil,
        missing = missing, usesFarm = usesFarm, learned = rec.learned, src = rec.src,
        trend = self.Trend and self:Trend(rec.out) or nil,
        perDay = (self:SellSpeed(rec.out)),
    }
end

-- An enchant (or another recipe that makes no item): what its reagents cost.
function GP:EvalService(key, rec)
    local cost, missing = 0, {}
    local reagents = GP.UnpackReagents(rec.r)
    for _, r in ipairs(reagents) do
        local unit = self:BuyCost(r[1])
        if unit then cost = cost + unit * r[2] else missing[#missing + 1] = r[1] end
    end
    return { key = key, name = rec.n, prof = rec.prof, service = true, icon = rec.icon, outQty = 1,
             reagents = reagents, cost = cost, sell = 0, missing = missing, learned = rec.learned, src = rec.src }
end

function GP:CraftRows()
    local rows, farmed = {}, farmedItems()
    for key, rec in pairs(self:Char().recipes) do
        if rec.learned then
            local r = self:EvalRecipe(key, rec, farmed)
            -- What it could earn a day: profit per craft times how many sell a day (the whole
            -- market; you'll share it with other sellers).
            if r.profit > 0 and r.perDay and #r.missing == 0 then r.profitDay = r.profit * r.perDay / r.outQty end
            if r.priced or r.sell > 0 then rows[#rows + 1] = r end
        end
    end
    table.sort(rows, function(a, b)
        local am, bm = #a.missing > 0, #b.missing > 0
        if am ~= bm then return bm end
        if (a.profitDay or 0) ~= (b.profitDay or 0) then return (a.profitDay or 0) > (b.profitDay or 0) end
        return a.profit > b.profit
    end)
    return rows
end

-- Vendor flips: crafts whose result a vendor buys for more than the mats cost on the AH.
-- For every recipe you or an alt (same realm and faction) know: what a vendor pays for the
-- result, what the mats cost now (a mat you can craft yourself counts at the cheaper of buying
-- it and crafting it), and the most you can pay for the main mat and still come out ahead.
function GP:VendorFlipRows()
    local realm = GP.RealmName()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local me = self:CharKey()
    local recipes, byOut = {}, {}
    for key, c in pairs(self.db.chars or {}) do
        if key == me or (c.realm == realm and (not c.faction or c.faction == faction)) then
            for rkey, rec in pairs(c.recipes or {}) do
                if rec.learned and rec.out then
                    local who = key == me and L["you"] or (c.short or key)
                    recipes[#recipes + 1] = { rkey = rkey, rec = rec, who = who, mine = key == me }
                    if not byOut[rec.out] then byOut[rec.out] = rec end
                end
            end
        end
    end
    -- What one unit of a mat costs you: buy it, or craft it from its own mats (one level down).
    local function matCost(id, depth)
        local buy, where = self:BuyCost(id)
        local rec = depth < 2 and byOut[id]
        if rec then
            local total, ok = 0, true
            for _, r in ipairs(GP.UnpackReagents(rec.r)) do
                local c = matCost(r[1], depth + 1)
                if not c then ok = false; break end
                total = total + c * r[2]
            end
            if ok then
                local craft = total / (rec.oq or 1)
                if not buy or craft < buy then return craft, "craft" end
            end
        end
        return buy, where
    end
    local rows, seen = {}, {}
    for _, e in ipairs(recipes) do
        local rec = e.rec
        local vendor = self:VendorSell(rec.out) * (rec.oq or 1)
        local dedupe = rec.out .. "|" .. (rec.r or "")
        if vendor > 0 and not (seen[dedupe] and not e.mine) then
            seen[dedupe] = true
            local cost, missing, main, mainCost = 0, false, nil, -1
            local reagents = GP.UnpackReagents(rec.r)
            for _, r in ipairs(reagents) do
                local unit, where = matCost(r[1], 0)
                if not unit then missing = true; break end
                cost = cost + unit * r[2]
                -- The main mat: the one bought on the AH that costs the most in this craft.
                if where == "AH" and unit * r[2] > mainCost then main, mainCost = r, unit * r[2] end
            end
            if not missing then
                local r = { key = e.rkey, name = rec.n, prof = rec.prof, out = rec.out, outQty = rec.oq or 1, who = e.who,
                            vendor = vendor, cost = cost, profit = vendor - cost, reagents = reagents }
                if main then
                    local others = cost - mainCost
                    r.mat, r.matQty = main[1], main[2]
                    r.matNow = mainCost / main[2]
                    r.below = (vendor - others) / main[2]
                    local p = self.db.prices[main[1]]
                    r.listed = p and p.q
                end
                -- Worth showing: profitable now, or a main mat that could be bought cheaply enough.
                -- A limit far under today's price (less than 60% of it) never happens: left out.
                if r.profit > 0 or (r.below and r.below > 0 and r.below >= 0.6 * (r.matNow or 0)) then rows[#rows + 1] = r end
            end
        end
    end
    table.sort(rows, function(a, b) return a.profit > b.profit end)
    return rows
end

-- Skill-ups: learned recipes that still give skill (orange 0, yellow 1, green 2), by what each
-- skill point costs: reagents minus what the result sells for, divided by the chance of a point.
-- The chances are rough (the game doesn't tell addons the exact ones).
local SKILL_CHANCE = { [0] = 1.0, [1] = 0.75, [2] = 0.25 }
GP.SKILL_CHANCE = SKILL_CHANCE

function GP:SkillRows()
    local rows = {}
    for key, rec in pairs(self:Char().recipes) do
        local chance = rec.learned and rec.d and SKILL_CHANCE[rec.d]
        if chance then
            local r = self:EvalRecipe(key, rec)
            r.d, r.chance = rec.d, chance
            r.priced = #r.missing == 0
            r.back = r.sell
            if r.priced then r.perPoint = (r.cost - r.back) / chance end
            rows[#rows + 1] = r
        end
    end
    -- Enchants give skill too (most of Enchanting's), and nothing back but the enchant.
    for key, rec in pairs(self:Char().services) do
        local chance = rec.learned and rec.d and SKILL_CHANCE[rec.d]
        if chance then
            local r = self:EvalService(key, rec)
            r.d, r.chance = rec.d, chance
            r.priced = #r.missing == 0
            r.back = 0
            if r.priced then r.perPoint = r.cost / chance end
            rows[#rows + 1] = r
        end
    end
    table.sort(rows, function(a, b)
        if (a.perPoint ~= nil) ~= (b.perPoint ~= nil) then return a.perPoint ~= nil end
        if a.perPoint and a.perPoint ~= b.perPoint then return a.perPoint < b.perPoint end
        if a.d ~= b.d then return a.d < b.d end
        return (a.name or "") < (b.name or "")
    end)
    return rows
end

-- Recipes you don't know yet: from the profession window (unlearned) and from the AH.
local function stripPrefix(name)
    return (name or ""):gsub("^[^:]+:%s*", ""):lower()
end

-- Recipes are costly to work out (sources, vendors, drops for every one), so the window keeps
-- the rows for 20 seconds; a profession scan, an AH scan, a vendor or a setting starts over.
function GP:RecipeRowsCached()
    local s = self.db.settings
    local key = tostring(s.recipesShowAll) .. "|" .. tostring(self.db.priceScanTime)
    local c = self.recipeRowsCache
    if c and c.key == key and GetTime() - c.t < 20 then return c.rows end
    local rows = self:RecipeRows()
    self.recipeRowsCache = { key = key, t = GetTime(), rows = rows }
    return rows
end

function GP:RecipeRows()
    return self:WithMergedMobs(function() return self:RecipeRowsUncached() end)
end

for _, ev in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "TRAINER_SHOW", "TRAINER_CLOSED" }) do
    GP:On(ev, function() GP.recipeRowsCache = nil end)
end

function GP:RecipeRowsUncached()
    local rows, byName, farmed = {}, {}, farmedItems()
    for key, rec in pairs(self:Char().recipes) do
        if not rec.learned then
            local r = self:EvalRecipe(key, rec, farmed)
            r.kind = "recipe"
            -- Nobody sells the result on the AH (bound gear, or not scanned): "profit" would just be
            -- minus the reagents, hundreds of gold for epics. Say there's no price instead.
            if not r.priced then r.noSale, r.reagentCost, r.profit = true, r.cost, nil end
            rows[#rows + 1] = r
            byName[(rec.n or ""):lower()] = r
        end
    end
    for key, rec in pairs(self:Char().services) do
        if not rec.learned then
            local r = self:EvalService(key, rec)
            r.kind, r.noSale, r.reagentCost = "recipe", true, r.cost
            rows[#rows + 1] = r
            byName[(rec.n or ""):lower()] = r
        end
    end
    -- Recipe items on the AH for professions you have.
    local mySub = {}
    for name in pairs(self:MyProfessions()) do
        local sub = GP.RECIPE_SUBCLASS[name]
        if sub then mySub[sub] = name end
    end
    local known = {}
    for _, rec in pairs(self:Char().recipes) do if rec.learned then known[(rec.n or ""):lower()] = true end end
    for _, rec in pairs(self:Char().services) do if rec.learned then known[(rec.n or ""):lower()] = true end end
    for id, p in pairs(self.db.prices) do
        if p.k == 9 and mySub[p.sk] and p.n then
            local base = stripPrefix(p.n)
            if not known[base] then
                local r = byName[base]
                if r then
                    r.itemID, r.buyPrice = id, p.p
                else
                    rows[#rows + 1] = { kind = "ahonly", name = p.n, prof = mySub[p.sk], itemID = id, buyPrice = p.p,
                                        profit = nil, priced = false, missing = {} }
                end
            end
        end
    end
    -- Where to get each one (trainers, vendors, drops, AH), and the cheapest way to learn it.
    for _, r in ipairs(rows) do
        if self.RecipeSources then
            local srcs, cheapest, itemID = self:RecipeSources(r.name, r.itemID)
            r.sources, r.itemID = srcs, r.itemID or itemID
            -- The pattern item's drops and vendors from Haulwise Data, for ones you haven't seen.
            local ds = r.itemID and self.ItemSourcesFromData and self:ItemSourcesFromData(r.itemID)
            if ds then
                local have = {}
                for _, s in ipairs(r.sources) do if s.who then have[s.who] = true end end
                for i, d in ipairs(ds.drops or {}) do
                    if i > 3 then break end
                    if not have[d.name] then r.sources[#r.sources + 1] = { kind = "Drop", who = d.name, zone = d.zone, fromData = true } end
                end
                if (ds.world or 0) > 0 then r.sources[#r.sources + 1] = { kind = "World", fromData = true } end
            end
            -- Warcraft Wiki: how it's learned (when nothing better is known) and its exact skill.
            local w = GP.WikiRecipe and GP.WikiRecipe(r.name)
            if w then
                local kinds = {}
                for _, s in ipairs(r.sources) do kinds[s.kind] = true end
                local wantKind = ({ T = "Trainer", V = "Vendor", D = "Drop" })[w.how]
                if w.how and not (wantKind and kinds[wantKind]) and not (w.how == "D" and kinds.World) then
                    r.sources[#r.sources + 1] = { kind = "Wiki", how = w.how }
                end
                r.wikiSkill = w.skill
                if w.how == "T" then r.wikiTrainer = true end
            end
            if cheapest and (not r.buyPrice or cheapest < r.buyPrice) then r.learnCost = cheapest else r.learnCost = r.buyPrice end
        else
            r.learnCost = r.buyPrice
        end
        if r.learnCost and r.profit and r.profit > 0 and #(r.missing or {}) == 0 then r.payback = math.ceil(r.learnCost / r.profit) end
        r.skill, r.skillExact = self:RecipeSkill(r)
        -- The wiki's skill beats a guess from the item's level.
        if r.wikiSkill and not r.skillExact then r.skill, r.skillExact = r.wikiSkill, true end
        local p = self:MyProfessions()[r.prof or ""]
        r.myRank = p and p.rank
    end
    -- Recipes far above your skill (more than 30 points) are hidden unless you ask for them.
    if not self.db.settings.recipesShowAll then
        local keep = {}
        for _, r in ipairs(rows) do
            if not (r.skill and r.myRank and r.skill > r.myRank + 30) then keep[#keep + 1] = r end
        end
        rows = keep
    end
    table.sort(rows, function(a, b)
        local ap = (#(a.missing or {}) == 0 and a.profit) or -math.huge
        local bp = (#(b.missing or {}) == 0 and b.profit) or -math.huge
        if ap ~= bp then return ap > bp end
        return (a.name or "") < (b.name or "")
    end)
    return rows
end

-- The skill a recipe needs: from a trainer you (or anyone sharing) saw, from the recipe item's
-- tooltip ("Requires Tailoring (250)"), or, as a rough guess, from the level the crafted gear
-- needs. Returns skill, exact (false for the guess).
local skillPattern
local function tooltipSkill(itemID)
    if not (itemID and C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local cache = GP.db.recipeSkill
    if cache[itemID] then return cache[itemID] end
    if not skillPattern then
        local fmt = ITEM_MIN_SKILL or "Requires %s (%d)"
        local escaped = fmt:gsub("([%(%)%.%-%+%[%]])", "%%%1")
        skillPattern = "^" .. escaped:gsub("%%s", ".-"):gsub("%%d", "(%%d+)") .. "$"
    end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or not data or not data.lines then return nil end
    for _, line in ipairs(data.lines) do
        local n = line.leftText and line.leftText:match(skillPattern)
        if n then cache[itemID] = tonumber(n); return cache[itemID] end
    end
end

function GP:RecipeSkill(r)
    local best
    for _, s in ipairs(r.sources or {}) do
        if s.skill and s.skill > 0 and (not best or s.skill < best) then best = s.skill end
    end
    if best then return best, true end
    local t = tooltipSkill(r.itemID)
    if t then return t, true end
    if r.out then
        local link = select(2, ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(r.out))
        if not link then
            -- Not loaded yet: ask the game once per item, and look again when that item arrives.
            GP.recipeWaiting = GP.recipeWaiting or {}
            if GP.recipeWaiting[r.out] == nil then
                GP.recipeWaiting[r.out] = true
                if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, r.out) end
            end
            return nil
        end
        local info = GP.LinkInfo(link)
        if info.minLevel and info.minLevel > 1 and (info.classID == 2 or info.classID == 4) then
            return math.min(300, math.max(1, info.minLevel * 5)), false
        end
        -- Bags and other non-gear: from the item level, roughly (Runecloth Bag 55 -> ~245).
        local ilvl = select(4, ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(r.out))
        if ilvl and ilvl > 6 and info.classID ~= 0 then
            return math.min(300, math.max(1, ilvl * 5 - 30)), false
        end
    end
end

-- Recipes whose result wasn't loaded: redraw once one of *those* items has arrived (the event
-- fires for every item the game loads, all the time), at most every 3 seconds, and only while
-- the Recipes tab is on screen.
GP:On("GET_ITEM_INFO_RECEIVED", function(itemID)
    local w = GP.recipeWaiting
    if not (w and w[itemID]) then return end
    w[itemID] = false   -- asked and answered: never asked again this session
    if GP.recipeRedrawQueued then return end
    GP.recipeRedrawQueued = true
    C_Timer.After(3, function()
        GP.recipeRedrawQueued = false
        GP.recipeRowsCache = nil
        if GP.db and GP.db.settings.tab == "recipes" and GP.RefreshUI then GP:RefreshUI() end
    end)
end)

-- Best value per unit of a reagent if you craft it instead of selling it raw (for the Farm tab).
-- What one of an item costs you to craft (cheapest recipe you know that makes it), or nil.
function GP:CraftCostFor(itemID)
    local best
    for key, rec in pairs(self:Char().recipes) do
        if rec.learned and rec.out == itemID then
            local r = self:EvalRecipe(key, rec)
            if #r.missing == 0 then
                local per = r.cost / math.max(1, r.outQty)
                if not best or per < best then best = per end
            end
        end
    end
    return best
end

function GP:CraftValue(itemID)
    if not index then
        index = {}
        for key, rec in pairs(self:Char().recipes) do
            if rec.learned then
                for _, r in ipairs(GP.UnpackReagents(rec.r)) do
                    index[r[1]] = index[r[1]] or {}
                    table.insert(index[r[1]], key)
                end
            end
        end
    end
    local best, bestName
    for _, key in ipairs(index[itemID] or {}) do
        local rec = self:Char().recipes[key]
        local ah = rec and select(2, self:ItemValue(rec.out))
        if rec and ah then
            local others, need, ok = 0, 1, true
            for _, r in ipairs(GP.UnpackReagents(rec.r)) do
                if r[1] == itemID then need = r[2]
                else
                    local c = self:BuyCost(r[1])
                    if not c then ok = false break end
                    others = others + c * r[2]
                end
            end
            if ok then
                local per = ((rec.oq or 1) * ah - others) / need
                if not best or per > best then best, bestName = per, rec.n end
            end
        end
    end
    return best, bestName
end
