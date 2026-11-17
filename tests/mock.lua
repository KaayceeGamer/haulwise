-- Minimal WoW API mock for running Haulwise outside the game.
W = { t = 1000, clock = 1700000000, units = {}, loot = {}, canLoot = {}, inGroup = false,
      level = 40, class = "ROGUE", profs = { 393 }, items = {}, events = {}, frames = {} }

local function mockObj()
    local o = { scripts = {}, shown = false, checked = false, text = "" }
    return setmetatable(o, { __index = function(t, k)
        return function(self, ...)
            if k == "SetScript" then local a, b = ...; self.scripts[a] = b; return end
            if k == "GetScript" then return self.scripts[...] end
            if k == "RegisterEvent" then W.events[...] = self; return end
            if k == "Show" then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end; return end
            if k == "Hide" then self.shown = false; return end
            if k == "SetShown" then if ... then self:Show() else self:Hide() end; return end
            if k == "IsShown" then return self.shown end
            if k == "SetChecked" then self.checked = ...; return end
            if k == "GetChecked" then return self.checked end
            if k == "SetText" then self.text = ...; return end
            if k == "GetText" then return self.text end
            if k == "CreateFontString" or k == "CreateTexture" then return mockObj() end
            if k == "GetStringWidth" or k == "GetWidth" then return 100 end
            if k == "GetHeight" then return 560 end
            if k == "GetFrameLevel" then return 1 end
            return nil
        end
    end })
end

function CreateFrame(kind, name) local f = mockObj(); if name then _G[name] = f; W.frames[name] = f end; return f end
UIParent = mockObj()
GameTooltip = mockObj()
UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}
GOLD_AMOUNT, SILVER_AMOUNT, COPPER_AMOUNT = "%d Gold", "%d Silver", "%d Copper"
ITEM_QUALITY_COLORS = { [1] = { hex = "|cffffffff" } }
Enum = { LootSlotType = { None = 0, Item = 1, Money = 2 } }
C_Timer = { NewTicker = function() end, After = function(_, fn) fn() end }
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end io.write(table.concat(t, " "), "\n") end

function strsplit(sep, s)
    local out = {}
    for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
    return unpack(out)
end
function GetTime() return W.t end
time = function() return W.clock end
function IsInGroup() return W.inGroup end
function GetRealZoneText() return W.zone or "Mulgore" end

local function U(unit) return W.units[unit] end
function UnitExists(u) return U(u) ~= nil end
function UnitGUID(u) return U(u) and U(u).guid or (u == "player" and "Player-1-0001" or nil) end
function UnitIsPlayer(u) return false end
function UnitName(u) return U(u) and U(u).name or "Me" end
function UnitLevel(u) if u == "player" then return W.level end return U(u) and U(u).level end
function UnitIsDead(u) return U(u) and U(u).dead or false end
function UnitAffectingCombat(u) if u == "player" then return W.inCombat end return U(u) and U(u).combat end
function UnitIsTapDenied(u) return U(u) and U(u).tapDenied or false end
function UnitClass(u) return "Rogue", W.class end
function CanLootUnit(guid) return W.canLoot[guid] end
function IsFishingLoot() return false end
C_NamePlate = { GetNamePlates = function() return {} end }
C_Spell = { GetSpellName = function(id) return ({ [921] = "Pick Pocket", [8613] = "Skinning" })[id] end }
function GetProfessions() return 1, nil end
function GetProfessionInfo(i) return "Skinning", 0, 1, 300, 0, 0, W.profs[i] end

function GetNumLootItems() return #W.loot end
function GetLootSlotType(i) return W.loot[i].money and 2 or 1 end
function GetLootSlotLink(i) local id = W.loot[i].id; return id and ("|Hitem:" .. id .. "::|h[x]|h") end
function GetLootSlotInfo(i) local l = W.loot[i]; return nil, l.text, l.q or 1, nil, nil, false, l.quest or false end
function GetLootSourceInfo(i) return unpack(W.loot[i].src) end

local function idOf(x) if type(x) == "number" then return x end return tonumber(tostring(x):match("item:(%d+)")) end
C_Item = { GetItemInfo = function(x)
    local id = idOf(x)
    local it = W.items[id]
    if not it then return nil end
    return it.name, "|Hitem:" .. id .. "::|h[" .. it.name .. "]|h", it.quality or 1, it.ilvl or 1, it.minLevel or 1, nil, nil,
        it.maxStack or 20, it.equipLoc or "", 0, it.sell, it.k, it.sk, it.bind or 0
end, RequestLoadItemDataByID = function() end,
  GetItemStats = function(link) local id = idOf(link); return W.stats and W.stats[id] end }

function fire(event, ...)
    local f = W.events[event]
    if f then f.scripts.OnEvent(f, event, ...) end
end

date = os.date
function GetRealmName() return "Testrealm" end
C_Item.GetItemInfoInstant = function(id) local it = W.items[id] or {}; return id, nil, nil, nil, nil, it.k, it.sk end
W.merchant = {}
function GetMerchantNumItems() return #W.merchant end
function GetMerchantItemID(i) return W.merchant[i].id end
function GetMerchantItemInfo(i) local m = W.merchant[i]; return m.name or "x", 0, m.price, m.qty, m.stock or -1 end
W.recipes = {}
C_TradeSkillUI = {
  GetBaseProfessionInfo = function() return W.prof end,
  GetAllRecipeIDs = function() local t = {} for id in pairs(W.recipes) do t[#t+1] = id end table.sort(t) return t end,
  GetRecipeInfo = function(id) local r = W.recipes[id]; return { name = r.name, learned = r.learned } end,
  GetRecipeSchematic = function(id) local r = W.recipes[id]
    local slots = {}
    for _, g in ipairs(r.reagents) do slots[#slots+1] = { reagentType = 1, quantityRequired = g[2], reagents = { { itemID = g[1] } } } end
    return { outputItemID = r.out, quantityMin = r.qmin or 1, quantityMax = r.qmax or 1, reagentSlotSchematics = slots } end,
  GetRecipeSourceText = function(id) return W.recipes[id].src end,
}

W.bags = {}
W.equipped = {}
W.cursor = nil
W.deleted = {}
W.looted = {}
function LINK(id) return "|cffffffff|Hitem:" .. id .. "::|h[" .. W.items[id].name .. "]|h|r" end
C_Container = {
  GetContainerNumSlots = function(b) return W.bags[b] and W.bags[b].size or 0 end,
  GetContainerNumFreeSlots = function(b)
    local bg = W.bags[b]; if not bg then return 0, 0 end
    local used = 0 for _ in pairs(bg.slots) do used = used + 1 end
    return bg.size - used, bg.family or 0 end,
  GetContainerItemInfo = function(b, s)
    local bg = W.bags[b]; local it = bg and bg.slots[s]; if not it then return nil end
    local def = W.items[it.id]
    return { itemID = it.id, stackCount = it.count or 1, quality = def.quality or 1, hyperlink = LINK(it.id), isBound = it.bound or false }
  end,
  GetContainerItemQuestInfo = function(b, s) local it = W.bags[b].slots[s]; return { isQuestItem = it and it.quest or false } end,
  PickupContainerItem = function(b, s) W.cursor = { b, s } end,
  UseContainerItem = function(b, s) W.bags[b].slots[s] = nil end,
}
function CursorHasItem() return W.cursor ~= nil end
function ClearCursor() W.cursor = nil end
function DeleteCursorItem() local c = W.cursor; W.bags[c[1]].slots[c[2]] = nil; W.deleted[#W.deleted+1] = c; W.cursor = nil end
function LootSlot(i) W.looted[#W.looted+1] = i end
function GetInventoryItemLink(_, slot) local id = W.equipped[slot]; return id and LINK(id) end
function UnitFactionGroup() return "Horde" end
function GetMoney() return 123456 end
function InCombatLockdown() return false end
function IsShiftKeyDown() return W.shift end
function GetTalentTabInfo(i) return "Tree" .. i, "icon", (i == 3 and 21 or 0), "file" end
NUM_BAG_SLOTS = 4
ERR_INV_FULL = "Inventory is full."
function CreateFont(name) local f = CreateFrame("Frame", name); return f end
W.trainer = {}
function GetNumTrainerServices() return #W.trainer end
function GetTrainerServiceInfo(i) return W.trainer[i].name, "", W.trainer[i].cat or "available" end
function GetTrainerServiceSkillReq(i) return W.trainer[i].prof, W.trainer[i].skill, true end
function GetTrainerServiceCost(i) return W.trainer[i].cost end
W.filters = { available = true, unavailable = false, used = false }
function GetTrainerServiceTypeFilter(f) return W.filters[f] end
function SetTrainerServiceTypeFilter(f, v) W.filters[f] = (v == 1) end
