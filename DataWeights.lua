-- Haulwise: stat weights per class and talent tree, for the Upgrade Advisor.
-- Written for Haulwise: simple, sensible classic-era priorities. Value of one point of each stat,
-- relative to the spec's main stat (1.0). Ratings that are "1%" lines on classic items are
-- weighted per percent. Edit freely: these are starting points, not gospel.
local _, GP = ...

-- Item stat keys (C_Item.GetItemStats) -> short names used below.
GP.STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", RESISTANCE0_NAME = "ARMOR",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP", ITEM_MOD_SPELL_POWER_SHORT = "SP",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT", ITEM_MOD_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT", ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "SCRIT", ITEM_MOD_HIT_SPELL_RATING_SHORT = "SHIT",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKV", ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
}

GP.STAT_LABEL = {
    STR = "Strength", AGI = "Agility", STA = "Stamina", INT = "Intellect", SPI = "Spirit", ARMOR = "Armor",
    DPS = "Weapon DPS", AP = "Attack Power", RAP = "Ranged AP", SP = "Spell Damage", HEAL = "Healing",
    CRIT = "Crit", HIT = "Hit", SCRIT = "Spell Crit", SHIT = "Spell Hit", MP5 = "Mana/5s", DEF = "Defense",
    BLOCK = "Block", BLOCKV = "Block Value", DODGE = "Dodge", PARRY = "Parry",
}

local caster = { SP = 1.0, INT = 0.55, SPI = 0.35, STA = 0.4, SCRIT = 10, SHIT = 12, MP5 = 1.5, ARMOR = 0.003, WAND = 1.2 }
local healer = { HEAL = 1.0, SP = 0.35, INT = 0.7, SPI = 0.5, MP5 = 2.2, STA = 0.35, SCRIT = 8, ARMOR = 0.003, WAND = 0.8 }

-- [classFile] = { { treeName, weights }, ... } in talent-tree order. The first tree is the default.
GP.WEIGHTS = {
    WARRIOR = {
        { "Arms",        { STR = 1.0, AGI = 0.7, STA = 0.35, AP = 0.5, CRIT = 14, HIT = 12, DPS = 3.0, ARMOR = 0.01 } },
        { "Fury",        { STR = 1.0, AGI = 0.7, STA = 0.35, AP = 0.5, CRIT = 15, HIT = 14, DPS = 3.0, ARMOR = 0.01 } },
        { "Protection",  { STA = 1.0, DEF = 1.5, ARMOR = 0.06, AGI = 0.6, STR = 0.5, DODGE = 12, PARRY = 10, BLOCK = 6, BLOCKV = 0.3, DPS = 1.0 } },
    },
    PALADIN = {
        { "Holy",        healer },
        { "Protection",  { STA = 1.0, DEF = 1.2, ARMOR = 0.05, STR = 0.4, SP = 0.5, INT = 0.35, BLOCKV = 0.3, DPS = 0.8 } },
        { "Retribution", { STR = 1.0, AGI = 0.6, STA = 0.35, CRIT = 12, HIT = 10, AP = 0.5, DPS = 3.0, INT = 0.2, ARMOR = 0.008 } },
    },
    HUNTER = {
        { "Beast Mastery", { AGI = 1.0, RAP = 0.45, AP = 0.1, INT = 0.3, STA = 0.35, CRIT = 12, HIT = 12, RDPS = 2.5, DPS = 0.4, ARMOR = 0.005 } },
        { "Marksmanship",  { AGI = 1.0, RAP = 0.45, AP = 0.1, INT = 0.3, STA = 0.35, CRIT = 13, HIT = 13, RDPS = 2.8, DPS = 0.3, ARMOR = 0.005 } },
        { "Survival",      { AGI = 1.1, RAP = 0.45, AP = 0.1, INT = 0.3, STA = 0.4, CRIT = 12, HIT = 12, RDPS = 2.5, DPS = 0.5, ARMOR = 0.005 } },
    },
    ROGUE = {
        { "Assassination", { AGI = 1.0, STR = 0.55, AP = 0.5, STA = 0.3, CRIT = 13, HIT = 14, DPS = 3.0, ARMOR = 0.005 } },
        { "Combat",        { AGI = 1.0, STR = 0.55, AP = 0.5, STA = 0.3, CRIT = 12, HIT = 15, DPS = 3.2, ARMOR = 0.005 } },
        { "Subtlety",      { AGI = 1.0, STR = 0.5, AP = 0.5, STA = 0.35, CRIT = 12, HIT = 13, DPS = 3.0, ARMOR = 0.005 } },
    },
    PRIEST = {
        { "Discipline", healer },
        { "Holy",       healer },
        { "Shadow",     { SP = 1.0, INT = 0.4, SPI = 0.5, STA = 0.45, SHIT = 13, SCRIT = 6, MP5 = 1.0, ARMOR = 0.003, WAND = 1.2 } },
    },
    SHAMAN = {
        { "Elemental",   caster },
        { "Enhancement", { STR = 1.0, AGI = 0.8, AP = 0.5, CRIT = 12, HIT = 12, DPS = 3.0, INT = 0.25, STA = 0.35, ARMOR = 0.008 } },
        { "Restoration", healer },
    },
    MAGE = {
        { "Arcane", caster },
        { "Fire",   caster },
        { "Frost",  caster },
    },
    WARLOCK = {
        { "Affliction",  { SP = 1.0, STA = 0.6, INT = 0.4, SPI = 0.35, SHIT = 13, SCRIT = 6, ARMOR = 0.003, WAND = 1.2 } },
        { "Demonology",  { SP = 1.0, STA = 0.7, INT = 0.4, SPI = 0.3, SHIT = 12, SCRIT = 7, ARMOR = 0.003, WAND = 1.2 } },
        { "Destruction", { SP = 1.0, STA = 0.5, INT = 0.45, SPI = 0.25, SHIT = 13, SCRIT = 10, ARMOR = 0.003, WAND = 1.2 } },
    },
    DRUID = {
        { "Balance",     caster },
        { "Feral",       { AGI = 1.0, STR = 1.0, AP = 0.5, STA = 0.5, ARMOR = 0.02, CRIT = 12, HIT = 12, DEF = 0.6, DODGE = 8 } },
        { "Restoration", healer },
    },
}

-- What each class can wear and wield (item class 4 = armor, 2 = weapon; subclass ids).
-- armor: 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield; [subclass] = level needed
GP.ARMOR = {
    WARRIOR = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 }, PALADIN = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
    HUNTER = { [1] = 1, [2] = 1, [3] = 40 }, SHAMAN = { [1] = 1, [2] = 1, [3] = 40, [6] = 1 },
    ROGUE = { [1] = 1, [2] = 1 }, DRUID = { [1] = 1, [2] = 1 },
    PRIEST = { [1] = 1 }, MAGE = { [1] = 1 }, WARLOCK = { [1] = 1 },
}
-- weapons: 0 1h axe, 1 2h axe, 2 bow, 3 gun, 4 1h mace, 5 2h mace, 6 polearm, 7 1h sword, 8 2h sword,
-- 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand
local function set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
GP.WEAPONS = {
    WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = set(0, 1, 4, 5, 6, 7, 8),
    HUNTER = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE = set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST = set(4, 10, 15, 19),
    SHAMAN = set(0, 1, 4, 5, 10, 13, 15),
    MAGE = set(7, 10, 15, 19),
    WARLOCK = set(7, 10, 15, 19),
    DRUID = set(4, 5, 6, 10, 13, 15),
}
GP.DUAL_WIELD = { WARRIOR = 20, ROGUE = 1, HUNTER = 20, SHAMAN = 40 }
