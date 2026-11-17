-- Haulwise: what disenchanting gives, by quality and item level (classic-era rules, which WoW
-- Forever follows). Written for Haulwise from the public game rules.
-- Each band: { minLevel, maxLevel, { { itemID, chance, minCount, maxCount }, ... } }
-- Armor and weapons differ only for green items: weapons give essence more often than dust.
local _, GP = ...

local DUST = { strange = 10940, soul = 11083, vision = 11137, dream = 11176, illusion = 16204 }
local ESS = {
    lMagic = 10938, gMagic = 10939, lAstral = 10998, gAstral = 11082, lMystic = 11134, gMystic = 11135,
    lNether = 11174, gNether = 11175, lEternal = 16202, gEternal = 16203,
}
local SHARD = {
    sGlimmer = 10978, lGlimmer = 11084, sGlow = 11138, lGlow = 11139, sRadiant = 11177, lRadiant = 11178,
    sBrilliant = 14343, lBrilliant = 14344, nexus = 20725,
}

-- Green items: dust, essence, shard, with the dust chance listed first (armor).
local green = {
    { 5, 15,  { { DUST.strange, 0.80, 1, 2 }, { ESS.lMagic, 0.20, 1, 2 } } },
    { 16, 20, { { DUST.strange, 0.75, 2, 3 }, { ESS.gMagic, 0.20, 1, 2 }, { SHARD.sGlimmer, 0.05, 1, 1 } } },
    { 21, 25, { { DUST.strange, 0.75, 4, 6 }, { ESS.lAstral, 0.15, 1, 2 }, { SHARD.sGlimmer, 0.10, 1, 1 } } },
    { 26, 30, { { DUST.soul, 0.75, 1, 2 },    { ESS.gAstral, 0.20, 1, 2 }, { SHARD.lGlimmer, 0.05, 1, 1 } } },
    { 31, 35, { { DUST.soul, 0.75, 2, 5 },    { ESS.lMystic, 0.20, 1, 2 }, { SHARD.sGlow, 0.05, 1, 1 } } },
    { 36, 40, { { DUST.vision, 0.75, 1, 2 },  { ESS.gMystic, 0.20, 1, 2 }, { SHARD.lGlow, 0.05, 1, 1 } } },
    { 41, 45, { { DUST.vision, 0.75, 2, 5 },  { ESS.lNether, 0.20, 1, 2 }, { SHARD.sRadiant, 0.05, 1, 1 } } },
    { 46, 50, { { DUST.dream, 0.75, 1, 2 },   { ESS.gNether, 0.20, 1, 2 }, { SHARD.lRadiant, 0.05, 1, 1 } } },
    { 51, 55, { { DUST.dream, 0.75, 2, 5 },   { ESS.lEternal, 0.20, 1, 2 }, { SHARD.sBrilliant, 0.05, 1, 1 } } },
    { 56, 60, { { DUST.illusion, 0.75, 1, 2 }, { ESS.gEternal, 0.20, 1, 2 }, { SHARD.lBrilliant, 0.05, 1, 1 } } },
    { 61, 65, { { DUST.illusion, 0.75, 2, 5 }, { ESS.gEternal, 0.20, 2, 3 }, { SHARD.lBrilliant, 0.05, 1, 1 } } },
}

local blue = {
    { 11, 25, { { SHARD.sGlimmer, 1.00, 1, 1 } } },
    { 26, 30, { { SHARD.lGlimmer, 1.00, 1, 1 } } },
    { 31, 35, { { SHARD.sGlow, 1.00, 1, 1 } } },
    { 36, 40, { { SHARD.lGlow, 1.00, 1, 1 } } },
    { 41, 45, { { SHARD.sRadiant, 1.00, 1, 1 } } },
    { 46, 50, { { SHARD.lRadiant, 1.00, 1, 1 } } },
    { 51, 55, { { SHARD.sBrilliant, 0.995, 1, 1 }, { SHARD.nexus, 0.005, 1, 1 } } },
    { 56, 70, { { SHARD.lBrilliant, 0.995, 1, 1 }, { SHARD.nexus, 0.005, 1, 1 } } },
}

local purple = {
    { 40, 45, { { SHARD.sRadiant, 1.00, 2, 4 } } },
    { 46, 50, { { SHARD.lRadiant, 1.00, 2, 4 } } },
    { 51, 55, { { SHARD.sBrilliant, 1.00, 2, 4 } } },
    { 56, 60, { { SHARD.nexus, 1.00, 1, 1 } } },
    { 61, 99, { { SHARD.nexus, 1.00, 1, 2 } } },
}

-- Enchanting skill needed to disenchant, by item level.
local SKILL = {
    { 20, 1 }, { 25, 25 }, { 30, 50 }, { 35, 75 }, { 40, 100 }, { 45, 125 }, { 50, 150 },
    { 55, 175 }, { 60, 200 }, { 99, 225 },
}

GP.DE = { green = green, blue = blue, purple = purple, skill = SKILL }
GP.DE_MATS = {}
for _, group in ipairs({ DUST, ESS, SHARD }) do for _, id in pairs(group) do GP.DE_MATS[id] = true end end

-- Outcomes for an item: list of { id, chance, min, max }, or nil if it can't be disenchanted.
function GP.DisenchantOutcomes(quality, itemLevel, isWeapon)
    local tbl = (quality == 2 and green) or (quality == 3 and blue) or (quality == 4 and purple)
    if not tbl or not itemLevel then return nil end
    for _, band in ipairs(tbl) do
        if itemLevel >= band[1] and itemLevel <= band[2] then
            local out = {}
            for i, o in ipairs(band[3]) do out[i] = { o[1], o[2], o[3], o[4] } end
            if quality == 2 and isWeapon and #out >= 2 then
                -- Weapons: dust and essence chances swap places.
                out[1][2], out[2][2] = out[2][2], out[1][2]
            end
            return out
        end
    end
    return nil
end

function GP.DisenchantSkill(itemLevel)
    for _, s in ipairs(SKILL) do if itemLevel <= s[1] then return s[2] end end
    return 225
end
