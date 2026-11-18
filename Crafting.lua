-- Haulwise: crafting profit from the professions you actually have.
--
-- Open a profession window once and Haulwise remembers every recipe in it: learned ones become
-- the Craft tab (cost of reagents vs what the result sells for), unlearned ones feed the
-- Recipes tab (is this pattern worth buying or farming?). Reagent costs use the cheapest of
-- the AH and any vendor you've visited, so thread, salt and vials are priced right.
local _, GP = ...

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
    return (UnitName("player") or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "?")
end

function GP:Char()
    local key = self:CharKey()
    local c = self.db.chars[key]
    if not c then c = { profs = {}, recipes = {} }; self.db.chars[key] = c end
    return c
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
local function invalidate() index = nil end
GP.InvalidateCraftIndex = invalidate

-- Reading the profession window -------------------------------------------------------

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
        local info = C_TradeSkillUI.GetRecipeInfo(rid)
        local sch = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(rid, false)
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
    }
end

function GP:CraftRows()
    local rows, farmed = {}, farmedItems()
    for key, rec in pairs(self:Char().recipes) do
        if rec.learned then
            local r = self:EvalRecipe(key, rec, farmed)
            if r.priced or r.sell > 0 then rows[#rows + 1] = r end
        end
    end
    table.sort(rows, function(a, b)
        local am, bm = #a.missing > 0, #b.missing > 0
        if am ~= bm then return bm end
        return a.profit > b.profit
    end)
    return rows
end

-- Skill-ups: learned recipes that still give skill (orange 0, yellow 1, green 2), by what each
-- skill point costs: reagents minus what the result sells for, divided by the chance of a point.
-- The chances are rough (the game doesn't tell addons the exact ones).
local SKILL_CHANCE = { [0] = 1.0, [1] = 0.75, [2] = 0.25 }

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

function GP:RecipeRows()
    local rows, byName, farmed = {}, {}, farmedItems()
    for key, rec in pairs(self:Char().recipes) do
        if not rec.learned then
            local r = self:EvalRecipe(key, rec, farmed)
            r.kind = "recipe"
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
            if cheapest and (not r.buyPrice or cheapest < r.buyPrice) then r.learnCost = cheapest else r.learnCost = r.buyPrice end
        else
            r.learnCost = r.buyPrice
        end
        if r.learnCost and r.profit and r.profit > 0 and #(r.missing or {}) == 0 then r.payback = math.ceil(r.learnCost / r.profit) end
        r.skill, r.skillExact = self:RecipeSkill(r)
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
        local info = GP.LinkInfo(select(2, ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(r.out)) or ("item:" .. r.out))
        if info.minLevel and info.minLevel > 1 and (info.classID == 2 or info.classID == 4) then
            return math.min(300, math.max(1, info.minLevel * 5)), false
        end
    end
end

-- Best value per unit of a reagent if you craft it instead of selling it raw (for the Farm tab).
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
        local _, ah = self:ItemValue(rec.out)
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
