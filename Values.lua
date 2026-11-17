-- Haulwise: what an item in your bags is really worth to you.
--   vendor  what a vendor pays (guaranteed)
--   AH      auction price after the 5% cut, if the price is no older than 14 days and the item
--           isn't soulbound
--   DE      expected disenchant yield (chance x average count x AH price of each material), if you
--           or one of your characters can disenchant it
-- The item is worth the highest of the three. Every value carries its source so the UI can say why.
local _, GP = ...

local AH_CUT = 0.95
local MAX_AGE = 14 * 86400

function GP.LinkInfo(link)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, _, quality, ilvl, minLevel, _, _, maxStack, equipLoc, icon, sellPrice, classID, subclassID, bindType = get(link)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, eff = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok and eff then ilvl = eff end
    end
    return {
        name = name, quality = quality, ilvl = ilvl, minLevel = minLevel, maxStack = maxStack or 1,
        equipLoc = equipLoc, icon = icon, sell = sellPrice or 0, classID = classID, subclassID = subclassID,
        bindType = bindType,
    }
end

-- Price colour by age: green up to 3 days, orange up to 7, red up to 14.
function GP.AgeColor(age)
    if not age then return "|cff999999" end
    if age <= 3 * 86400 then return "|cff5fd35f" elseif age <= 7 * 86400 then return "|cffff9944" end
    return "|cffff6b5b"
end

local function freshAH(id)
    local price, listed, age, src = GP:Price(id)
    if not price then return nil end
    if age and age > MAX_AGE then return nil end
    return price * AH_CUT, age, src, listed
end

-- Characters that can disenchant: { { name, skill, me }, ... }
function GP:Enchanters()
    local out = {}
    local mine = self:MyProfessions()["Enchanting"]
    if mine and mine.rank then out[#out + 1] = { name = UnitName("player"), skill = mine.rank, me = true } end
    if self.Alts then
        for _, alt in ipairs(self:Alts()) do
            local p = alt.profs and alt.profs["Enchanting"]
            if p and p.rank then out[#out + 1] = { name = alt.short, skill = p.rank, me = false } end
        end
    end
    return out
end

-- Expected disenchant value of one item. Returns value, outcomes, who-can-do-it list, or nil.
function GP:DisenchantValue(link, bound, info)
    info = info or GP.LinkInfo(link)
    if not info.quality or (info.classID ~= 2 and info.classID ~= 4) then return nil end
    if info.equipLoc == "INVTYPE_BODY" or info.equipLoc == "INVTYPE_TABARD" then return nil end
    local outcomes = GP.DisenchantOutcomes(info.quality, info.ilvl, info.classID == 2)
    if not outcomes then return nil end

    local need = GP.DisenchantSkill(info.ilvl or 1)
    local who = {}
    for _, e in ipairs(self:Enchanters()) do
        if e.skill >= need and (e.me or not bound) then who[#who + 1] = e.name end
    end
    if #who == 0 then return nil, outcomes, who, need end

    local value, priced = 0, false
    for _, o in ipairs(outcomes) do
        local unit = freshAH(o[1])
        o.unit = unit
        if unit then
            priced = true
            value = value + o[2] * (o[3] + o[4]) / 2 * unit
        end
    end
    if not priced then return nil, outcomes, who, need end
    return value, outcomes, who, need
end

-- Value of ONE unit in your bags. Returns value, source ("V"|"AH"|"DE"), details table.
function GP:BagValue(id, link, bound)
    local info = GP.LinkInfo(link or id)
    local s = self.db.settings
    local best, src = info.sell or 0, "V"
    local d = { vendor = info.sell or 0, info = info }
    if not bound and info.bindType ~= 1 then
        local ah, age, from = freshAH(id)
        d.ah, d.ahAge, d.ahFrom = ah, age, from
        if ah and ah > best then best, src = ah, "AH" end
    end
    if s.useDisenchant and link then
        local de, outcomes, who = self:DisenchantValue(link, bound, info)
        d.de, d.deOutcomes, d.deWho = de, outcomes, who
        if de and de > best then best, src = de, "DE" end
    end
    return best, src, d
end

function GP.SourceTag(src, d)
    if src == "AH" then return GP.AgeColor(d and d.ahAge) .. "AH|r" end
    if src == "DE" then return "|cffc48cffDE|r" end
    return "|cff999999V|r"
end
