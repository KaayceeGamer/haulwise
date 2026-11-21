-- Part 5: AH upgrades, shopping list, sell helper, mats for crafters, skill-ups, bag advice, zones.
local GP = GPT
local function ok(cond, msg) if not cond then if PSEUDO or LOCALE_RUN then print("TEXT-CHECK " .. msg); return end error("FAIL: " .. msg, 2) end print("ok   " .. msg) end

-- Gear on the AH ------------------------------------------------------------------------------
W.class, W.level = "MAGE", 34
W.equipped = { [5] = 7003 }
W.items[7010] = { name = "Fine Silk Robe", sell = 400, quality = 2, k = 4, sk = 1, ilvl = 30, minLevel = 28, equipLoc = "INVTYPE_CHEST", bind = 2 }
W.items[7011] = { name = "Quick Leather Boots", sell = 300, quality = 2, k = 4, sk = 2, ilvl = 30, minLevel = 27, equipLoc = "INVTYPE_FEET", bind = 2 }
W.items[7012] = { name = "Far Future Robe", sell = 400, quality = 3, k = 4, sk = 1, ilvl = 60, minLevel = 55, equipLoc = "INVTYPE_CHEST", bind = 2 }
W.stats[7010] = { ITEM_MOD_INTELLECT_SHORT = 6, RESISTANCE0_NAME = 40 }
W.stats[7011] = { ITEM_MOD_AGILITY_SHORT = 5, RESISTANCE0_NAME = 60 }
W.stats[7012] = { ITEM_MOD_INTELLECT_SHORT = 30, RESISTANCE0_NAME = 90 }
GP.db.chars["Alkhara-Testrealm"].equippedLinks = { [8] = LINK(7006) }
GP.db.chars["Alkhara-Testrealm"].level = 30

GP.db.ahUpgrades = nil
GP:FindAHUpgrades({
  [LINK(7010)] = { id = 7010, price = 20000 },
  [LINK(7011)] = { id = 7011, price = 5000 },
  [LINK(7012)] = { id = 7012, price = 9000 },
})
local rows = GP:AHUpgradeRows()
local mine, alt, far = false, false, false
for _, r in ipairs(rows) do
  if r.id == 7010 and r.forMe then mine = true end
  if r.id == 7011 and r.alt == "Alkhara" then alt = true end
  if r.id == 7012 then far = true end
end
ok(mine, "silk robe on the AH is an upgrade for you")
ok(alt, "leather boots on the AH are an upgrade for the rogue alt")
ok(not far, "gear you can't wear for 20 levels is left out")
ok(rows[1].perGold >= rows[#rows].perGold, "ranked by upgrade per gold")
GP.db.settings.ahUpgradeMax = 10000
local cheap = GP:AHUpgradeRows()
local onlyBoots = #cheap >= 1
for _, r in ipairs(cheap) do if r.price > 10000 then onlyBoots = false end end
ok(onlyBoots, "max price hides the 2g robe")
GP.db.settings.ahUpgradeMax = 0

-- Worn item whose stats the game hasn't sent yet: no fake +100%.
W.items[7020] = { name = "Worn Silk Robe", sell = 300, quality = 2, k = 4, sk = 1, ilvl = 30, minLevel = 25, equipLoc = "INVTYPE_CHEST" }
W.equipped = { [5] = 7020 }
ok(GP:CompareGear(LINK(7010), GP.MeForGear()) == nil, "worn item not loaded yet: no comparison instead of a fake +100%")
W.stats[7020] = { ITEM_MOD_INTELLECT_SHORT = 4, RESISTANCE0_NAME = 30 }
local back = GP:CompareGear(LINK(7010), GP.MeForGear())
ok(back and back.gain < 1, "once it's loaded the real gain shows (not +100%)")
W.equipped = { [5] = 7003 }

-- A full scan with gear listings runs the finder too.
GP.db.ahUpgrades = nil
GP._test.finishPrices({ [2589] = { { 40, 200 } } }, { [LINK(7010)] = { id = 7010, price = 15000 } })
ok(GP.db.ahUpgrades and #GP.db.ahUpgrades.rows >= 1 and GP.db.ahUpgrades.rows[1].id == 7010, "scan finds AH upgrades")

-- Skill-ups -------------------------------------------------------------------------------------
W.items[4305] = { name = "Bolt of Silk Cloth", sell = 200, k = 7 }
W.items[4306] = { name = "Silk Cloth", sell = 40, k = 7 }
W.items[4240] = { name = "Woolen Bag", sell = 150, k = 1 }
W.items[2592] = { name = "Wool Cloth", sell = 33, k = 7 }
GP._test.finishPrices({ [4306] = { { 120, 100 } }, [4305] = { { 500, 20 } }, [2592] = { { 80, 100 } }, [4240] = { { 600, 5 } } })
local rec = GP:Char().recipes
rec.sk1 = { n = "Bolt of Silk Cloth", prof = "Tailoring", out = 4305, oq = 1, r = "4306:4", learned = true, d = 0 }
rec.sk2 = { n = "Woolen Bag", prof = "Tailoring", out = 4240, oq = 1, r = "2592:4", learned = true, d = 2 }
rec.sk3 = { n = "Linen Bag", prof = "Tailoring", out = 4238, oq = 1, r = "2589:3", learned = true, d = 3 }
local skill = GP:SkillRows()
local keys = {}
for _, r in ipairs(skill) do keys[r.key] = r end
ok(keys.sk1 and keys.sk2 and not keys.sk3, "grey recipes give no skill and are left out")
-- Bolt: 480 reagents - 475 back = 5 per point. Bag: (320 - 570) / 0.25 = earns gold.
ok(skill[1].key == "sk2" and skill[1].perPoint < 0, "a green recipe that earns gold beats an orange one that costs")
ok(math.abs(keys.sk1.perPoint - (480 - 500 * 0.95)) < 0.01, "orange: cost per point = reagents minus what the bolt sells for")

-- Shopping list ---------------------------------------------------------------------------------
W.bags = { [0] = { size = 16, slots = { { id = 4306, count = 5 }, { id = 11083, count = 2 } } } }
C_Item.GetItemCount = function(id)
  local n = 0
  for _, b in pairs(W.bags) do for _, s in pairs(b.slots) do if s.id == id then n = n + (s.count or 1) end end end
  return n
end
GP:Char().shopping = {}
GP:AddToShopping("sk1", 3)
local crafts, reagents, total, _, _, used = GP:ShoppingTotals()
ok(#crafts == 1 and crafts[1].qty == 3, "3 bolts on the list")
ok(reagents[1].id == 4306 and reagents[1].need == 12 and reagents[1].have == 5 and reagents[1].buy == 7, "need 12 silk, have 5, buy 7")
ok(total == 7 * 120, "cost of what's left to buy")
ok(used == 12 * 120, "profit counts the silk you already have too, like the Craft tab")
GP:AddToShopping("sk1", -3)
ok(next(GP:Char().shopping) == nil, "minus to zero removes the craft")
GP:ToggleShopping()

-- Sell helper ------------------------------------------------------------------------------------
local a = GP:SellAdvice(4306, nil, true)
ok(a.price == 119, "suggests 1 copper under the cheapest listing")
W.items[4307] = { name = "Vendor Junk", sell = 500, k = 15 }
GP._test.finishPrices({ [4307] = { { 300, 10 } } })
local v = GP:SellAdvice(4307, nil, true)
ok(v.vendorBetter and v.price >= 500 / 0.95, "warns when a vendor pays more, never suggests below vendor")
-- A deep market at 260 (like Fadeleaf: 48 at 2s60, then more): undercut it, not the old "usual".
C_AuctionHouse = C_AuctionHouse or {}
local live = { { 260, 48 }, { 265, 71 }, { 273, 18 } }
C_AuctionHouse.GetNumCommoditySearchResults = function() return #live end
C_AuctionHouse.GetCommoditySearchResultInfo = function(_, i) local l = live[i]; return l and { unitPrice = l[1], quantity = l[2] } end
local f = GP:SellAdvice(4306, nil, true)
ok(f.price == 259, "deep market: 1 copper under it (" .. tostring(f.price) .. ")")
live = { { 100, 2 }, { 255, 30 }, { 260, 40 } }
f = GP:SellAdvice(4306, nil, true)
ok(f.price == 254, "two cheap ones far below the rest: undercut the main market (" .. tostring(f.price) .. ")")
C_AuctionHouse.GetNumCommoditySearchResults, C_AuctionHouse.GetCommoditySearchResultInfo = nil, nil

-- Mats for crafters -----------------------------------------------------------------------------
GP.db.chars["Alkhara-Testrealm"].recipes = {
  e1 = { n = "Enchant Bracer - Stamina", prof = "Enchanting", out = 0, r = "11083:1", learned = true },
}
GP.db.chars["Alkhara-Testrealm"].profs = { Enchanting = { rank = 200 } }
local groups = GP:MatsForCrafters()
ok(#groups == 1 and groups[1].alt == "Alkhara" and groups[1].items[1].id == 11083, "soul dust goes to the enchanter alt")
local silkUsedByMe = true
for _, g in ipairs(groups) do for _, it in ipairs(g.items) do if it.id == 4306 then silkUsedByMe = false end end end
ok(silkUsedByMe, "mats your own recipes use stay with you")
local attached = {}
SendMailNameEditBox = CreateFrame("EditBox")
function HasSendMailItem(i) return attached[i] ~= nil end
function ClickSendMailItemButton(i) attached[i] = W.cursor; W.cursor = nil end
SendMailFrame = CreateFrame("Frame"); SendMailFrame:Show()
GP:AttachMats(groups[1])
ok(attached[1] and SendMailNameEditBox:GetText() == "Alkhara", "one click addresses the mail and attaches the dust")
MailFrame = CreateFrame("Frame"); MailFrame:Show()
GP:ShowSendToAlts()
ok(HaulwiseSendToAlts and HaulwiseSendToAlts.shown, "mailbox panel lists mats for crafters")

-- Bag advice ------------------------------------------------------------------------------------
ok(GP:BagAdvice({ src = "AH" }):find("AH"), "AH items: sell on the AH")
ok(GP:BagAdvice({ src = "V" }):find("vendor"), "vendor items: sell to a vendor")
ok(GP:BagAdvice({ src = "DE", d = { deWho = { "Me" } } }):find("disenchant"), "DE items you can disenchant: disenchant")
ok(GP:BagAdvice({ src = "DE", d = { deWho = { "Alkhara" } } }):find("Alkhara"), "DE items only an alt can do: send to that alt")

-- Zones -----------------------------------------------------------------------------------------
local zones = GP:ZoneRows()
ok(#zones >= 1 and zones[1].bestName, "zones ranked with their best mob")
ok(#GP:Rank("Nowhere") == 0, "zone filter leaves out other zones")
GP.db.settings.farmZone = "here"
ok(GP:FarmZoneFilter() == (W.zone or "Mulgore"), "'This zone only' uses the zone you're in")
GP.db.settings.farmZone = nil

-- Every view draws -------------------------------------------------------------------------------
GP:ShowUI()
for _, v in ipairs({ { "gear", "ah" }, { "craft", "skill" }, { "farm", "zones" }, { "bags" } }) do
  GP.db.settings.tab = v[1]
  GP.db.settings.views[v[1]] = v[2]
  GP:RefreshUI()
  GP:SortBy(({ gear = "price", craft = "point", farm = "est", bags = "total" })[v[1]])
  GP.db.settings.views[v[1]] = nil
end
ok(true, "AH, skill-up, zone and bag views draw and sort")
-- Only one popup at a time ---------------------------------------------------------------------
W.items[17056] = { name = "Light Feather", sell = 7, k = 15, sk = 1 }
W.bags = { [0] = { size = 3, slots = { { id = 17056, count = 2 }, { id = 4865 }, { id = 2589, count = 20 } } } }
local feather
for _, r in ipairs(GP:BagItems()) do if r.id == 17056 then feather = r.protect end end
ok(feather == "class reagent", "Light Feather (Slow Fall) is protected")
if HaulwiseMakeRoom then HaulwiseMakeRoom:Hide() end
W.loot = { { id = 9999, src = { "Creature-0-1-1-1-113-ABC", 1 } } }
fire("LOOT_READY")
fire("UI_ERROR_MESSAGE", 3, ERR_INV_FULL)
fire("LOOT_OPENED")
ok(HaulwiseSwap.shown and not (HaulwiseMakeRoom and HaulwiseMakeRoom.shown), "auto loot into full bags: only the swap card, no Make room")
GP:ShowMakeRoom()
ok(not HaulwiseMakeRoom.shown, "Make room stays away while the swap card is up")
fire("LOOT_CLOSED")
ok(not HaulwiseSwap.shown, "swap card closes with the loot window")
-- Disenchant results are recorded -----------------------------------------------------------------
W.items[11174] = { name = "Lesser Nether Essence", sell = 0, k = 7 }
W.items[11176] = { name = "Dream Dust", sell = 0, k = 7 }
W.bags = { [0] = { size = 4, slots = { { id = 7010, locked = true }, { id = 2589, count = 5 } } } }
fire("UNIT_SPELLCAST_START", "player", "cast-1", 13262)
W.loot = { { id = 11176, q = 3, src = { "Item-1-2-3", 3 } } }
fire("LOOT_OPENED")
local mine, similar = GP:DisenchantHistory(7010, GP.LinkInfo(LINK(7010)))
ok(mine and mine.n == 1 and mine.list[1][1] == 11176 and mine.list[1][2] == 3, "a disenchant you did is remembered: 3 Dream Dust")
ok(similar and similar.n == 1, "and counted for items like it")
W.loot = {}
-- The item locks a moment after the cast starts; auto loot fires LOOT_READY then LOOT_OPENED.
W.bags = { [0] = { size = 4, slots = { { id = 7010 }, { id = 2589, count = 5 } } } }
fire("UNIT_SPELLCAST_SENT", "player", "", "cast-2", 13262)
fire("UNIT_SPELLCAST_START", "player", "cast-2", 13262)
W.bags[0].slots[1].locked = true
fire("ITEM_LOCK_CHANGED", 0, 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 13262)
W.bags[0].slots[1] = nil
W.loot = { { id = 11176, q = 2, text = "Dream Dust", src = { "Item-1-2-4", 2 } } }
fire("LOOT_READY"); fire("LOOT_OPENED")
mine = GP:DisenchantHistory(7010, GP.LinkInfo(LINK(7010)))
ok(mine and mine.n == 2 and mine.list[1][2] == 5, "late item lock still recorded, once (auto loot)")
W.loot = {}

-- Item tooltip: best move and disenchant line ----------------------------------------------------
local calls = {}
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) calls[#calls + 1] = fn end }
Enum.TooltipDataType = { Item = 0, Unit = 1 }
assert(loadfile(DIR .. "/Tooltip.lua"))("Haulwise", GP)
local lines = {}
local tip = { AddLine = function(_, t) lines[#lines + 1] = t end,
              AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " | " .. tostring(r) end,
              GetItem = function() return "Fine Silk Robe", LINK(7010) end }
GameTooltip = tip
GP.db.settings.useDisenchant = true
GP:Char().profs = { Enchanting = { rank = 159 } }
for _, fn in ipairs(calls) do pcall(fn, tip, { id = 7010 }) end
local best, de
for _, l in ipairs(lines) do
  if l:find("best:") then best = l end
  if l:find("Disenchant") then de = l end
end
print("     " .. tostring(best)); print("     " .. tostring(de))
ok(best and de, "tooltip shows the best move and what disenchanting gives")
local gotLine
for _, l in ipairs(lines) do if l:find("You got from 2") then gotLine = l end end
ok(gotLine, "tooltip shows what your own disenchant gave")
-- An empty recipe name (seen in a real export) must not reach the server.
GP.db.recipeItems[""] = 13939
GP.db.recipeItems["stormrider's leather pants"] = 252796
local exp = GP:ExportString()
ok(not exp:find(";R,,") and exp:find("R,stormrider's leather pants,252796", 1, true), "export skips empty recipe names, keeps the rest")
GP.db.recipeItems[""] = nil

-- Errors are kept for bug reports ---------------------------------------------------------------
GP.db.errors = {}
fire("BAG_UPDATE_DELAYED")
GP:On("HAULWISE_TEST_EVENT", function() error("boom in a handler") end)
fire("HAULWISE_TEST_EVENT"); fire("HAULWISE_TEST_EVENT")
ok(#GP.db.errors == 1 and GP.db.errors[1].n == 2 and GP.db.errors[1].msg:find("boom"), "a failing handler is noted once, counted twice")
local report = GP:ErrorReport()
ok(report and report:find("Haulwise " .. GP.VERSION, 1, true) and report:find("boom"), "error report has the version and the error")
GP:ShowFeedback()
ok(HaulwiseShareFrame.edit:GetText():find("Paste this into your report", 1, true), "/haul feedback shows the report ready to copy")
for i = 1, 15 do GP.ReportError("x", "err " .. i) end
ok(#GP.db.errors == 10, "only the last 10 errors are kept")

-- Recipes far above your skill are hidden ----------------------------------------------------------
GP:Char().profs = { Tailoring = { rank = 131, max = 150 } }
GP:Char().recipes.hi = { n = "Belt of the Archmage", prof = "Tailoring", out = 7010, oq = 1, r = "2589:2", learned = false }
GP.db.sources["belt of the archmage"] = { trainer = { ["Trainer Bob"] = { zone = "Stormwind", cost = 50000, skill = 300, prof = "Tailoring" } } }
GP.db.settings.recipesShowAll = false
local found = false
for _, r in ipairs(GP:RecipeRows()) do if r.name == "Belt of the Archmage" then found = true end end
ok(not found, "a 300-skill recipe is hidden for 131 Tailoring")
GP.db.settings.recipesShowAll = true
for _, r in ipairs(GP:RecipeRows()) do if r.name == "Belt of the Archmage" then found = r end end
ok(found and found.skill == 300 and found.skillExact, "shown with its skill when you ask for all")
GP.db.settings.recipesShowAll = false

-- Pawn 2.14: PawnIsInitialized is local, PawnIsReady() says whether it's ready.
local oldInit, oldItem, oldSingle, oldAll = PawnIsInitialized, PawnGetItemData, PawnGetSingleValueFromItem, PawnGetAllScalesEx
PawnIsInitialized = nil
PawnGetItemData = PawnGetItemData or function() return {} end
PawnGetSingleValueFromItem = PawnGetSingleValueFromItem or function() return 1 end
PawnGetAllScalesEx = PawnGetAllScalesEx or function() return {} end
PawnIsReady = function() return true end
ok(GP.PawnLoaded(), "Pawn 2.14 is detected through PawnIsReady()")
PawnIsReady = function() return false end
ok(not GP.PawnLoaded(), "not used while Pawn is still loading")
PawnIsReady = nil
PawnIsInitialized, PawnGetItemData, PawnGetSingleValueFromItem, PawnGetAllScalesEx = oldInit, oldItem, oldSingle, oldAll
-- Disenchant for mats: disenchant gear you can do yourself even when a vendor pays more ----------
local me = UnitName("player")
local row = { src = "V", unit = 2700, total = 2700, count = 1, d = { de = 1300, deOutcomes = { {} }, deWho = { me } } }
GP.db.settings.deForMats = false
ok(not GP:BagAdvice(row):find("mats"), "off: the move that pays most (vendor)")
GP.db.settings.deForMats = true
local adv = GP:BagAdvice(row)
ok(adv:find("for mats") and adv:find("less than selling"), "on: disenchant for mats, and what it costs you")
local pricey = { src = "V", unit = 8827, total = 8827, count = 1, d = { de = 1350, deOutcomes = { {} }, deWho = { me } } }
ok(not GP:MatsDisenchant(pricey), "not when selling pays over 3 times more (88s ring for 13s of dust)")
row.protect = "kept"
ok(not GP:MatsDisenchant(row), "kept items are never disenchanted")
row.protect, row.d.deWho = nil, { "Someone Else" }
ok(not GP:MatsDisenchant(row), "only gear you can disenchant yourself")
GP.db.settings.deForMats = false

-- Profession filter on Craft, Skill up and Recipes -----------------------------------------------
for _, tab in ipairs({ "craft", "recipes" }) do
  GP.db.settings.tab = tab
  for _, pf in ipairs({ "Leatherworking", "Tailoring", false }) do
    GP:Char().profFilter = pf or nil
    GP:RefreshUI()
  end
end
GP.db.settings.views.craft = "skill"; GP.db.settings.tab = "craft"
GP:Char().profFilter = "Tailoring"; GP:RefreshUI()
GP:Char().profFilter = nil; GP.db.settings.views.craft = nil
local n = 0 for _ in pairs(GP.db.errors) do n = n + 1 end
ok(true, "profession filter draws Craft, Skill up and Recipes")

-- Trainers and recipe vendors: nearest one, waypoint ---------------------------------------------
assert(loadfile(DIR .. "/HaulwiseData/Data.lua"))()
local wp
UnitFactionGroup = function() return "Alliance" end
CreateVector2D = function(x, y) return { x = x, y = y } end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
C_Map = {
  GetBestMapForUnit = function() return 1453 end,
  GetPlayerMapPosition = function() return { GetXY = function() return 0.6, 0.6 end } end,
  GetWorldPosFromMapPos = function(m, v) return 0, { x = m * 10000 + v.x * 1000, y = v.y * 1000 } end,
  GetMapInfo = function(m) return { name = "Map " .. m } end,
  SetUserWaypoint = function(p) wp = p end,
}
GP:Char().profs = { Tailoring = { rank = 150, max = 150 } }
ok(GP:FindTrainer("Tailoring") and wp and wp.m == 1453, "waypoint to the nearest Alliance tailoring trainer (Stormwind)")
GetPlayerFacing = function() return 0 end
ok(HaulwiseArrow and HaulwiseArrow.shown, "Haulwise's own arrow shows (the game has no turning arrow)")
HaulwiseArrow.scripts.OnUpdate(HaulwiseArrow, 1)
print("     arrow: " .. tostring(HaulwiseArrow.dist.text))
ok(HaulwiseArrow.dist.text:find("%d+ yd"), "and says how far it is")
-- Direction: a target due west of you, facing north, points left (+90 degrees).
local rot
HaulwiseArrow.icon.SetRotation = function(_, r) rot = r end
GP:ShowArrow({ map = 1453, x = 20, y = 60 }, "West")
HaulwiseArrow.scripts.OnUpdate(HaulwiseArrow, 1)
ok(rot and math.abs(rot - math.pi / 2) < 0.01, "a target to the west points left when you face north")
GetPlayerFacing = function() return math.pi / 2 end
HaulwiseArrow.scripts.OnUpdate(HaulwiseArrow, 1)
ok(math.abs(rot) < 0.01, "and straight ahead when you face west")
GP:ShowArrow({ map = 1453, x = 60, y = 20 }, "North")
GetPlayerFacing = function() return 0 end
HaulwiseArrow.scripts.OnUpdate(HaulwiseArrow, 1)
ok(math.abs(rot) < 0.01, "a target to the north points straight ahead when you face north")
GP:ShowArrow({ map = 1453, x = 53.1, y = 81.3, id = 1346, name = "Georgio Bolero" }, "Trainer")
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return wp.x, wp.y end } end
HaulwiseArrow.scripts.OnUpdate(HaulwiseArrow, 1)
ok(HaulwiseArrow.shown and HaulwiseArrow.dist.text:find("there"), "close by it stays and says you're there")
UnitGUID = function() return "Creature-0-1-2-3-1346-0000" end
fire("GOSSIP_SHOW")
ok(not HaulwiseArrow.shown, "it goes away when you talk to them")
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.6, 0.6 end } end
GP:Char().profs = { Tailoring = { rank = 131, max = 225 } }
GP:FindTrainer("Tailoring")
local below = GP:NearestPlace(GP:TrainersFor("Tailoring"), function(p) return GP.TrainerTier(p.sub) >= 225 end)
ok(below and GP.TrainerTier(below.sub) >= 225, "at 131/225 an Expert (or better) trainer, not a Journeyman")
GP:Char().profs = { Tailoring = { rank = 150, max = 150 } }
local tier = GP.TrainerTier(GP:NearestPlace(GP:TrainersFor("Tailoring"), function(p) return GP.TrainerTier(p.sub) >= 225 end).sub)
ok(tier >= 225, "at 150/150 it looks for an Expert or Artisan")
UnitGUID = function() return "Creature-0-1-2-3-99999-0000" end
UnitName = function(u) return u == "npc" and "Test Vendor" or "Alkhara" end
fire("MERCHANT_SHOW")
ok(GP:NpcPlace(99999) and GP:NpcPlace(99999).from == "you", "a vendor you open is remembered where you stand")
local vid
for id in pairs(HaulwiseData.recipeVendors) do vid = id; break end
local srcs = GP:RecipeSources("Some Recipe", vid)
local hasV = false
for _, s in ipairs(srcs) do if s.kind == "Vendor" and s.npcID then hasV = true end end
print("     recipe " .. vid .. " vendor from data: " .. tostring(hasV))
-- With TomTom: its arrow, not cleared 10 yards out, removed when you talk to the NPC.
local tt = { added = {}, removed = {} }
TomTom = { AddWaypoint = function(_, m, x, y, o) tt.opts = o; tt.added[#tt.added + 1] = m; return "uid" .. #tt.added end,
           RemoveWaypoint = function(_, uid) tt.removed[#tt.removed + 1] = uid end }
GP:Waypoint({ id = 1346, name = "Georgio Bolero", map = 1453, x = 53.2, y = 81.5 })
ok(tt.opts and tt.opts.cleardistance == 0, "TomTom's waypoint isn't cleared before you get there")
GP:Waypoint({ id = 1346, name = "Georgio Bolero", map = 1453, x = 53.2, y = 81.5 })
ok(tt.removed[1] == "uid1", "a new Haulwise waypoint replaces the old one")
UnitGUID = function() return "Creature-0-1-2-3-1346-0000" end
fire("GOSSIP_SHOW")
ok(tt.removed[2] == "uid2", "and it's removed when you talk to them")
TomTom = nil

-- Places go out with Share data and come back from other players.
local exp = GP:ExportString()
ok(exp:find(";P,99999,Test Vendor,V,", 1, true), "Share data includes where the vendors you opened stand")
local _, imported = GP:ParseExport("CF2,abcd1234abcd1234,Friend,1700000000,1.60.1;P,77777,Far Trainer,T,Tailoring,A,1453,10.5,20.25;Z,whatever,from,the,future")
ok(imported.places[77777] and imported.places[77777].x == 10.5 and imported.places[77777].p == "Tailoring", "and are read back from someone else's data (unknown record types skipped)")
GP.db.shared.friend = imported
local found = false
for _, id in ipairs(GP:TrainersFor("Tailoring")) do if id == 77777 then found = true end end
ok(found and GP:NpcPlace(77777).from == "players", "other players' trainers count for Find trainer")
GP.db.shared.friend = nil
UnitName = function() return "Alkhara" end
C_Map = nil

-- Quest reward pick --------------------------------------------------------------------------------
W.quest = { 4865, 7010 }
GetNumQuestChoices = function() return #W.quest end
GetQuestItemLink = function(_, i) return LINK(W.quest[i]) end
GetQuestItemInfo = function(_, i) return W.items[W.quest[i]].name, nil, 1 end
GetTitleText = function() return "A Test Quest" end
local qp = GP:QuestRewardPick()
print("     quest pick: " .. tostring(qp and qp.index) .. " " .. tostring(qp and qp.kind))
ok(qp and qp.index == 2 and qp.kind == "upgrade", "quest reward: the gear upgrade is picked")
W.quest = { 17056, 4865 }
qp = GP:QuestRewardPick()
ok(qp and qp.index == 2 and qp.kind == "value", "no upgrade: the reward worth the most")
fire("QUEST_COMPLETE")
W.items[7005] = { name = "Skinning Knife", sell = 1, k = 2, sk = 7 }
W.quest = { 4865, 7005 }
W.bags = { [0] = { size = 16, slots = {} } }
qp = GP:QuestRewardPick()
ok(qp and qp.index == 2 and qp.kind == "tool" and qp.prof == "Skinning", "a skinner without a Skinning Knife gets the knife")
W.bags = { [0] = { size = 16, slots = { { id = 12709, count = 1 } } } }
qp = GP:QuestRewardPick()
ok(qp and qp.kind ~= "tool", "but not when they already have a skinning tool")
W.quest = { 4865 }
ok(GP:QuestRewardPick() == nil, "nothing to choose with one reward")

-- Sell speed: cheapest listings that are gone in the next scan count as sold ---------------------
GP.db.speed = {}
local T0 = W.clock
local oldP = { [888001] = { c = "100:5/110:5/120:20" }, [888002] = { c = "50:1/60:1" } }
-- 6 hours later: two of the 100s/110s gone (10 units), the 20 stack is still there; 888002 untouched.
GP:UpdateSellSpeed(oldP, T0 - 6 * 3600, { [888001] = { { 120, 20 }, { 130, 5 } }, [888002] = { { 50, 1 }, { 60, 1 } } }, T0)
ok(GP.db.speed[888001] and GP.db.speed[888001]:match("^10%.0:0%.25:"), "listings that vanished between scans count as sold")
ok(GP:SellSpeed(888001) == nil, "but no speed is shown from a quarter of a day")
oldP = { [888001] = { c = "120:20/130:5" }, [888002] = { c = "50:1/60:1" } }
GP:UpdateSellSpeed(oldP, T0 - 6 * 3600, { [888001] = { { 130, 5 } }, [888002] = { { 50, 1 }, { 60, 1 } } }, T0 + 6 * 3600)
local per, days, label = GP:SellSpeed(888001)
ok(per and math.abs(per - 40) < 0.01 and label == "fast", "30 units over 18 hours of scans: ~40 a day, fast")
per, days, label = GP:SellSpeed(888002)
ok(per == 0 and label == "none", "nothing gone: no sales seen")
ok(GP:SellSpeedText(888001, true) == "sells ~40 a day", "speed text: " .. tostring(GP:SellSpeedText(888001, true)))
GP:UpdateSellSpeed(oldP, T0 - 3 * 86400, { [888001] = {} }, T0)
ok(GP.db.speed[888001]:match("^30"), "scans more than 36 hours apart are not compared")
-- A slow seller caps what the Deals tab tells you to buy.
GP.db.speed[888003] = "30.0:3.00:" .. GP.Day()
GP.db.prices[888003] = { p = 100, q = 400, m = 300, t = W.clock, s = 0, c = "100:50/100:50/100:50/300:10/300:10" }
W.items[888003] = { name = "Slow Seller", sell = 0 }
local dealUnits
for _, r in ipairs(GP:Deals()) do if r.id == 888003 then dealUnits = r.units end end
ok(dealUnits == 30, "deals: buy no more than sells in ~3 days (got " .. tostring(dealUnits) .. ")")
GP.db.speed[888003] = "0.0:3.00:" .. GP.Day()
dealUnits = nil
for _, r in ipairs(GP:Deals()) do if r.id == 888003 then dealUnits = r.units end end
ok(dealUnits == nil, "deals: nothing that hasn't sold in days of scans")
GP.db.prices[888003], GP.db.speed = nil, {}

-- Sales log: auction invoices in the mail, each logged once ---------------------------------------
W.inbox = {
  { daysLeft = 29.5, invoice = { "seller", "Light Feather", "Buyer", 2000, 2000, 0, 100, 0, 0, 20 } },
  { daysLeft = 28.0, invoice = { "seller", "Ruined Pelt", "Other", 500, 500, 0, 25, 0, 0, 0 } },
  { daysLeft = 20.0, invoice = { "buyer", "Something", "Seller", 900, 900, 0, 0, 0, 0, 1 } },
}
GetInboxNumItems = function() return #W.inbox end
GetInboxHeaderInfo = function(i) return nil, nil, "Auction House", "x", 0, 0, W.inbox[i].daysLeft end
GetInboxInvoiceInfo = function(i) return unpack(W.inbox[i].invoice) end
GP.db.sales, GP.db.salesSeen = {}, {}
local added, gold = GP:ReadSales()
ok(added == 2 and gold == 1900 + 475, "two seller invoices logged, after the AH cut (" .. tostring(gold) .. ")")
W.clock = W.clock + 600
W.inbox[1].daysLeft = W.inbox[1].daysLeft - 600 / 86400
W.inbox[2].daysLeft = W.inbox[2].daysLeft - 600 / 86400
added = GP:ReadSales()
ok(added == 0, "opening the mailbox again logs nothing twice")
-- The game fills the count in a moment later: still the same sale.
W.inbox[1].invoice[10] = nil
added = GP:ReadSales()
W.inbox[1].invoice[10] = 20
ok(added == 0, "a count that arrives late doesn't log the sale twice")
-- Two identical sales are two sales.
table.insert(W.inbox, { daysLeft = 28.0, invoice = { "seller", "Ruined Pelt", "Other", 500, 500, 0, 25, 0, 0, 1 } })
added = GP:ReadSales()
ok(added == 1, "two identical mails are two sales")
table.remove(W.inbox)
for i = #GP.db.sales, 1, -1 do if GP.db.sales[i].n == "Ruined Pelt" then table.remove(GP.db.sales, i); break end end
local rows = GP:SalesRows(30)
ok(#rows == 2 and rows[1].earned == 1900 and rows[1].count == 20 and rows[2].count == 1, "sales tab: most earned first, with units sold (a count of 0 means one)")
local todayGold = GP:SalesTotal(0)
ok(GP:SalesTotal(6) == 2375, "earned in the last 7 days")
GetInboxNumItems, GetInboxHeaderInfo, GetInboxInvoiceInfo = nil, nil, nil

-- Your auctions: undercut ones first ---------------------------------------------------------------
GP.ahOpen = true
AuctionHouseFrame = AuctionHouseFrame or CreateFrame("Frame")
W.owned = {
  { auctionID = 1, itemKey = { itemID = 4306 }, status = 0, quantity = 10, buyoutAmount = 500 },
  { auctionID = 2, itemKey = { itemID = 17056 }, status = 0, quantity = 5, buyoutAmount = 30 },
  { auctionID = 3, itemKey = { itemID = 4865 }, status = 1, quantity = 1, buyoutAmount = 100 },
}
C_AuctionHouse.GetNumOwnedAuctions = function() return #W.owned end
C_AuctionHouse.GetOwnedAuctionInfo = function(i) return W.owned[i] end
C_AuctionHouse.GetItemKeyInfo = function() return { isCommodity = true } end
local saved4306, saved17056 = GP.db.prices[4306], GP.db.prices[17056]
GP.db.prices[4306] = { p = 450, q = 30, t = W.clock, c = "450:20/500:10" }
GP.db.prices[17056] = { p = 30, q = 10, t = W.clock, c = "30:5/40:5" }
local mine = GP:MyAuctions()
ok(#mine == 2 and mine[1].id == 4306 and mine[1].undercut and mine[1].cheapest == 450, "your auctions: the undercut one first, sold ones left out")
ok(not mine[2].undercut, "the cheapest one isn't undercut")
C_AuctionHouse.GetNumCommoditySearchResults = function() return 2 end
C_AuctionHouse.GetCommoditySearchResultInfo = function(_, i)
  return ({ { unitPrice = 400, quantity = 10, containsOwnerItem = true, numOwnerItems = 10 }, { unitPrice = 520, quantity = 3 } })[i]
end
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 4306)
mine = GP:MyAuctions()
local m4306
for _, a in ipairs(mine) do if a.id == 4306 then m4306 = a end end
ok(m4306 and not m4306.undercut and m4306.from == "live", "a fresh search counts, and your own listings don't undercut you")
GP:UpdateMyAuctions()
C_AuctionHouse.GetNumOwnedAuctions, C_AuctionHouse.GetOwnedAuctionInfo, C_AuctionHouse.GetItemKeyInfo = nil, nil, nil
C_AuctionHouse.GetNumCommoditySearchResults, C_AuctionHouse.GetCommoditySearchResultInfo = nil, nil
GP.db.prices[4306], GP.db.prices[17056] = saved4306, saved17056
GP.ahOpen = false

-- Waylaid crates and writs ------------------------------------------------------------------------
W.items[2447] = { name = "Peacebloom", sell = 1 }
W.items[2449] = { name = "Earthroot", sell = 2 }
W.items[777001] = { name = "Waylaid Crate: Apprentice Herbs", quality = 1 }
W.items[777002] = { name = "Sealed Journeyman Crate", quality = 2 }
W.items[777003] = { name = "Craftsman's Writ: Heavy Quiver" }
W.items[777004] = { name = "Heavy Quiver", sell = 50 }
GP.db.names[2447], GP.db.names[2449], GP.db.names[777004] = "Peacebloom", "Earthroot", "Heavy Quiver"
GP.db.prices[2447] = { p = 10, q = 100, t = W.clock }
GP.db.prices[2449] = { p = 50, q = 100, t = W.clock }
GP.db.prices[777004] = { p = 300, q = 4, t = W.clock }
W.bags = { [0] = { size = 16, slots = { { id = 2449, count = 10 } } } }
local bundles = GP.CrateBundles({ "Waylaid Crate: Apprentice Herbs", "Fill with 20 Peacebloom or 10 Earthroot.", "Requires level 10" })
ok(#bundles == 2 and bundles[1].id == 2447 and bundles[1].n == 20 and bundles[2].n == 10, "crate: reads the ways to fill it")
ok(GP.CrateFavor("Waylaid Crate: Flowering Expert Herbs", 1) == 15 and GP.CrateFavor("x", 1, { "Rewards:", "15 Merchant's Favor" }) == 15
   and GP.CrateFavor("Waylaid Crate: Apprentice Herbs", 1) == 5 and GP.CrateFavor("Sealed Journeyman Crate", 2) == 20 and GP.CrateFavor("Sealed Artisan Crate", 1) == nil,
   "crate favor: by tier, green doubles, unknown tiers say nothing")
calls = {}
assert(loadfile(DIR .. "/Favor.lua"))("Haulwise", GP)
lines = {}
for _, fn in ipairs(calls) do fn(tip, { id = 777001, lines = { { leftText = "Waylaid Crate: Apprentice Herbs" }, { leftText = "20 Peacebloom, 10 Earthroot" } } }) end
local cheapestLine, favorLine
for _, l in ipairs(lines) do
  if l:find("20 Peacebloom") and l:find(">", 1, true) then cheapestLine = l end
  if l:find("Favor") and l:find("|") then favorLine = l end
end
print("     " .. tostring(cheapestLine)); print("     " .. tostring(favorLine))
ok(cheapestLine ~= nil, "crate tooltip marks the cheapest way to fill it (buying 20 Peacebloom beats using your Earthroot)")
ok(favorLine and favorLine:find("5 Merchant", 1, true), "and what one Favor costs that way")
lines = {}
for _, fn in ipairs(calls) do fn(tip, { id = 777003, lines = {} }) end
local buyLine
for _, l in ipairs(lines) do if l:find("Buy one", 1, true) then buyLine = l end end
ok(buyLine ~= nil, "writ tooltip: what the ordered item costs")

-- Craft queue -------------------------------------------------------------------------------------
GP:Char().recipes = {
  r555 = { n = "Bolt of Silk", prof = "Tailoring", out = 4305, oq = 1, r = "4306:4", learned = true },
  ["Tailoring:Linen Thing"] = { n = "Linen Thing", prof = "Tailoring", out = 2996, oq = 1, r = "2589:2", learned = true },
}
W.items[4305] = W.items[4305] or { name = "Bolt of Silk Cloth", sell = 100 }
W.items[2996] = W.items[2996] or { name = "Bolt of Linen Cloth", sell = 25 }
GP:Char().shopping = { r555 = 3, ["Tailoring:Linen Thing"] = 1 }
W.bags = { [0] = { size = 16, slots = { { id = 4306, count = 9 } } } }
local q = GP:QueuedCrafts("Tailoring")
ok(#q == 2 and q[1].key == "r555" and q[1].can == 2, "queue: what you can make now comes first")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 555)
ok(GP:Char().shopping.r555 == 2, "a finished craft comes off the queue")
GP:CraftDone(nil, "Linen Thing")
ok(GP:Char().shopping["Tailoring:Linen Thing"] == nil, "classic recipes are matched by name")
GetNumTradeSkills = function() return 1 end
GetTradeSkillInfo = function() return "Bolt of Silk", "optimal" end
SelectTradeSkill = function(i) W.selected = i end
GP:Char().recipes["Tailoring:Bolt of Silk"] = { n = "Bolt of Silk", prof = "Tailoring", out = 4305, oq = 1, r = "4306:4", learned = true }
ok(GP:SelectCraft("Tailoring:Bolt of Silk", 2) and W.selected == 1, "clicking a queued craft picks it in the profession window")
GetNumTradeSkills, GetTradeSkillInfo, SelectTradeSkill = nil, nil, nil
GP:Char().recipes["Tailoring:Bolt of Silk"] = nil
GP.db.prices[4305] = { p = 1000, q = 50, t = W.clock }
GP.db.prices[4306] = { p = 100, q = 50, t = W.clock }
GP.db.speed = { [4305] = "10.0:2.00:" .. GP.Day() }
GP:Char().shopping = {}
GP:QueueBest(5)
ok(GP:Char().shopping.r555 == 10, "queue best: a profitable craft, as many as sell in ~2 days (got " .. tostring(GP:Char().shopping.r555) .. ")")
GP.db.speed = {}
GP:Char().shopping = {}
GP.db.prices[4306] = saved4306

-- Community pool without your own upload: your kills aren't counted twice ------------------------
do
  local savedMobs, savedShared, savedCommunity, savedSnaps = GP.db.mobs, GP.db.shared, GP.community, GP.db.exportSnaps
  local useShared = GP.db.settings.useShared
  GP.db.settings.useShared = true
  GP.db.mobs = { [5001] = { name = "Test Boar", kills = 100, money = 1000, gathered = 0, pp = 0, ppMoney = 0, tIntervals = 0, tSeconds = 0,
                            zones = { ["Elwynn Forest"] = 100 }, items = { [769] = { k = 40, q = 40 } }, gather = {}, ppItems = {} } }
  GP.db.shared, GP.db.exportSnaps = {}, nil
  GP:SnapshotExport(GP:ExportString())
  GP.db.exportSnaps[1].t = W.clock - 3600
  -- The pool, built after you shared: your 100 kills plus 50 from someone else.
  GP.community = { time = W.clock, contributors = 2, mobs = {
    [5001] = { name = "Test Boar", kills = 150, money = 1500, gathered = 0, pp = 0, ppMoney = 0, tIntervals = 0, tSeconds = 0,
               zones = { ["Elwynn Forest"] = 150 }, items = { [769] = { k = 60, q = 60 } }, gather = {}, ppItems = {} },
    [5002] = { name = "Other Wolf", kills = 20, money = 0, gathered = 0, pp = 0, ppMoney = 0, tIntervals = 0, tSeconds = 0,
               zones = { ["Elwynn Forest"] = 20 }, items = {}, gather = {}, ppItems = {} } } }
  GP.mineInPool = nil
  local merged = GP:MergedMobs()
  ok(merged[5001].kills == 150 and merged[5001].own == 100 and merged[5001].items[769].k == 60,
     "your shared kills aren't counted twice (" .. tostring(merged[5001].kills) .. " kills)")
  local zm, zk = GP:CommunityInZone("Elwynn Forest")
  ok(zm == 2 and zk == 70, "zone line: 2 mobs, 70 kills from others (" .. zm .. ", " .. zk .. ")")
  -- A pool built before you shared still has none of yours.
  GP.db.exportSnaps[1].t = W.clock + 3600
  GP.mineInPool = nil
  ok(GP:MergedMobs()[5001].kills == 250, "a pool from before you shared is added in full")
  local word = GP.Confidence(5)
  ok(word == "rough guess" and GP.Confidence(150) == "solid", "confidence words")
  GP.db.mobs, GP.db.shared, GP.community, GP.db.exportSnaps = savedMobs, savedShared, savedCommunity, savedSnaps
  GP.db.settings.useShared = useShared
  GP.mineInPool = nil
end

-- Zones by map number, names in your own language ----------------------------------------------
do
  local savedMap = C_Map
  C_Map = {
    GetBestMapForUnit = function() return 9001 end,
    GetMapInfo = function(id)
      return ({ [1434] = { name = "Stranglethorn Vale", mapType = 3, parentMapID = 13 },
                [9001] = { name = "Booty Bay Cellar", mapType = 5, parentMapID = 1434 },
                [13] = { name = "Eastern Kingdoms", mapType = 2 } })[id]
    end,
  }
  local realZone = GetRealZoneText
  GetRealZoneText = function() return "Stranglethorn Vale" end
  ok(GP.ZoneKey() == "#1434", "kills are recorded under the zone's map number, not a cave inside it")
  ok(GP.ZoneName("#1434") == "Stranglethorn Vale" and GP.ZoneName("Schlingendorntal") == "Schlingendorntal", "zone numbers show as names")
  local mobs = { [1] = { zones = { ["Stranglethorn Vale"] = 3, ["#1434"] = 2, ["Schlingendorntal"] = 4 } } }
  GP:NormalizeZones(mobs)
  ok(mobs[1].zones["#1434"] == 5 and mobs[1].zones["Stranglethorn Vale"] == nil and mobs[1].zones["Schlingendorntal"] == 4,
     "names your client knows move to the number; other languages stay")
  ok(GP:CurrentZone() == "#1434", "the zone you're in is a number too")
  C_Map, GetRealZoneText = savedMap, realZone
end

-- What an item is for: quests, crafts, who sells it, what drops it ---------------------------------
do
  local savedHD = HaulwiseData
  HaulwiseData = {
    quests = { [100] = { "Wolf Pelts", 30, 25, "A" }, [101] = { "Horde Pelts", 30, 25, "H" }, [102] = { "Old Pelts", 5, 1, "" },
               [103] = { "Done Pelts", 32, 25, "" }, [104] = { "Wolf Pelts", 30, 25, "" },
               [110] = { "Parts for Kravel", 36, 30, "", 5800, 903 } },
    questItems = { [5555] = { 100, 101, 102, 103, 104 }, [5800] = { 110 } },
    sources = { [5555] = { { 900 }, { 901, 902 }, 0 }, [6666] = { {}, {}, 40 } },
    sourceNpcs = { [900] = { "Pelt Trader", 0 }, [901] = { "Grey Wolf", 0 }, [902] = { "Black Wolf", 0 }, [903] = { "Kravel Koalbeard", 0 } },
  }
  local savedLevel, savedFaction = UnitLevel, UnitFactionGroup
  UnitLevel = function() return 30 end
  UnitFactionGroup = function() return "Alliance" end
  C_QuestLog = C_QuestLog or {}
  local savedLog = { C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetInfo, C_QuestLog.IsQuestFlaggedCompleted }
  C_QuestLog.GetNumQuestLogEntries = function() return 1 end
  C_QuestLog.GetInfo = function() return { questID = 100 } end
  C_QuestLog.IsQuestFlaggedCompleted = function(q) return q == 103 end
  GP.ForgetQuestLog()
  local qs = GP:QuestsNeeding(5555)
  ok(#qs == 1 and qs[1].id == 100 and qs[1].active, "quests: yours in the log, not the other faction's, not done or far below you")
  ok(GP:QuestKeepReason(5555) ~= nil and GP:QuestKeepReason(4306) == nil, "bags keep what a quest in your log needs")
  local kq = GP:QuestsNeeding(5800)
  ok(#kq == 1 and kq[1].to == "Kravel Koalbeard", "a quest item to deliver says who to bring it to")
  local src = GP:ItemSourcesFromData(5555)
  ok(src and src.vendors[1].name == "Pelt Trader" and #src.drops == 2, "who sells it and what drops it")
  ok(GP:ItemSourcesFromData(6666).world == 40, "world drops just say how many mobs")
  -- Crafts: your recipes and shared ones.
  GP:Char().recipes = { r555 = { n = "Bolt of Silk", prof = "Tailoring", out = 4305, oq = 1, r = "4306:4", learned = true } }
  local savedCommunity = GP.community
  GP.community = { mobs = {}, crafts = { [7777] = { out = 7777, qty = 1, prof = "Tailoring", reagents = { { 4306, 2 } } } } }
  GP.ForgetUses()
  local cs = GP:CraftsUsing(4306)
  ok(#cs == 2 and cs[1].who == "you" and cs[2].who == nil, "crafts that use it: yours first, then shared recipes")
  -- The export carries your recipes, and an import reads them back.
  local ex = GP:ExportString()
  ok(ex:find("C,4305,1,Tailoring,4306:4", 1, true) ~= nil, "export shares the recipes you know")
  local _, parsed = GP:ParseExport(ex .. ";C,8888,1,Tailoring,bad;C,8889,2,Cooking,2672:1")
  ok(parsed.crafts[4305] and parsed.crafts[8889] and parsed.crafts[8888] == nil, "import reads recipes and skips broken ones")
  -- The tooltip lines.
  calls = {}
  assert(loadfile(DIR .. "/Uses.lua"))("Haulwise", GP)
  lines = {}
  for _, fn in ipairs(calls) do fn(tip, { id = 5555 }) end
  local questLine, soldLine
  for _, l in ipairs(lines) do
    if l:find("Quest: Wolf Pelts", 1, true) then questLine = l end
    if l:find("Sold by Pelt Trader", 1, true) then soldLine = l end
  end
  ok(questLine and questLine:find("in your log", 1, true), "tooltip: the quest, marked in your log")
  ok(soldLine ~= nil, "tooltip: who sells it")
  HaulwiseData, GP.community = savedHD, savedCommunity
  UnitLevel, UnitFactionGroup = savedLevel, savedFaction
  C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetInfo, C_QuestLog.IsQuestFlaggedCompleted = savedLog[1], savedLog[2], savedLog[3]
  GP.ForgetQuestLog(); GP.ForgetUses()
end

-- Estimates: mobs nobody has farmed yet still rank, and real kills take over -----------------------
do
  local savedHD = HaulwiseData
  HaulwiseData = { estimates = { [6001] = { "Test Tiger", 32, 33, 1434, 0, "12202:50:1", "4234:50:1" } } }
  GP.ForgetEstimates()
  W.items[12202] = W.items[12202] or { name = "Tiger Meat", sell = 20 }
  GP.db.prices[12202] = { p = 1000, q = 100, t = W.clock }
  local savedMobs, useEst = GP.db.mobs, GP.db.settings.useEstimates
  GP.db.mobs = {}
  GP.db.settings.useEstimates = true
  local m = GP:MergedMobs()[6001]
  ok(m and m.est and m.kills == 0 and m.zones["#1434"] ~= nil, "an estimate shows up as a mob with no kills, in its zone")
  local r = GP:Evaluate(6001, m)
  ok(r.estOnly and math.abs(r.lines[1].chance - 0.5) < 0.01, "estimate-only: Classic's 50% drop chance")
  -- 30 real kills with the meat dropping 10 times: the estimate counts as 15 kills of evidence.
  GP.db.mobs = { [6001] = { name = "Test Tiger", kills = 30, money = 0, gathered = 0, pp = 0, ppMoney = 0, tIntervals = 0, tSeconds = 0,
                            zones = { ["#1434"] = 30 }, items = { [12202] = { k = 10, q = 10 } }, gather = {}, ppItems = {} } }
  r = GP:Evaluate(6001, GP:MergedMobs()[6001])
  local chance
  for _, l in ipairs(r.lines) do if l.id == 12202 then chance = l.chance end end
  ok(not r.estOnly and r.estimated and math.abs(chance - (10 + 7.5) / 45) < 0.01, "real kills blend with the estimate (" .. tostring(chance) .. ")")
  local found
  for _, row in ipairs(GP:Rank()) do if row.npc == 6001 then found = true end end
  ok(found, "Farm ranks it")
  GP.db.settings.useEstimates = false
  GP.db.mobs = {}
  ok(GP:MergedMobs()[6001] == nil, "estimates can be turned off")
  GP.db.mobs, GP.db.settings.useEstimates = savedMobs, useEst
  HaulwiseData = savedHD
  GP.ForgetEstimates()
end

-- Saved data is packed on logout and unpacked on login ------------------------------------------
GP.db.prices[999001] = { p = 1234, q = 7, m = 1500, t = 1700000000, k = 9, sk = 2, s = 50, c = "1234:3/1300.5:4", n = "Pattern: Odd; Name" }
ok(GP.PackPrice({ c = "2000.00:1/12.50:3" }):find("2000:1/12.5:3", 1, true), "old cheapest-listing text is shortened when saved")
GP.db.names[999002] = ""
GP.db.names[999003] = "Nobody knows me"
GP.db.history[999004] = "1:100:1"
local before = {}
for id, r in pairs(GP.db.prices) do local c = {} for k, v in pairs(r) do c[k] = v end before[id] = c end
fire("PLAYER_LOGOUT")
ok(next(GP.db.prices) == nil and type(GP.db.pricesPacked[999001]) == "string", "prices are saved as short lines on logout")
GP:UnpackSaved()
local same = true
for id, r in pairs(before) do
  for k, v in pairs(r) do if GP.db.prices[id][k] ~= v then same = false; print("   differs", id, k, v, GP.db.prices[id][k]) end end
  for k in pairs(GP.db.prices[id]) do if r[k] == nil then same = false end end
end
ok(same and GP.db.pricesPacked == nil, "and come back exactly the same on login")
ok(GP.db.names[999002] == nil and GP.db.names[999003] == nil, "empty names and names nothing uses are dropped")
ok(GP.db.history[999004] == nil, "history older than 28 days is dropped")
GP.db.prices[999001] = nil

-- Minimap button ---------------------------------------------------------------------------------
Minimap = CreateFrame("Frame", "Minimap")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
Minimap.GetCenter = function() return 500, 400 end
Minimap.GetEffectiveScale = function() return 1 end
GetCursorPosition = function() return 500, 480 end
fire("PLAYER_LOGIN")
local mb = HaulwiseMinimapButton
ok(mb and mb.shown, "minimap button is shown")
local tl = {}
local tt = { AddLine = function(_, t) tl[#tl + 1] = t end, AddDoubleLine = function(_, l, r) tl[#tl + 1] = l .. " " .. r end }
GP:MinimapTooltip(tt)
ok(#tl >= 5 and table.concat(tl, "|"):find("Right%-click"), "minimap tooltip shows gold, bags and what clicks do")
mb.scripts.OnUpdate = nil
mb.scripts.OnDragStart(mb); mb.scripts.OnUpdate(mb); mb.scripts.OnDragStop(mb)
ok(math.abs(GP.db.settings.minimapAngle - 90) < 0.01, "dragging the button saves where it sits")
SlashCmdList.HAULWISE("minimap")
ok(not mb.shown and GP.db.settings.minimap == false, "/haul minimap hides it")
SlashCmdList.HAULWISE("minimap")
ok(mb.shown, "and brings it back")
-- Shared auction house prices ----------------------------------------------------------------
do
  local now = time()
  local savedFaction = UnitFactionGroup
  UnitFactionGroup = function() return "Horde" end
  local savedPrices, savedScan, savedRealm = GP.db.prices, GP.db.priceScanTime, GP.db.scanRealm
  GP.db.prices = {
    [2589] = { p = 120, q = 400, t = now }, [2592] = { p = 300, q = 50, t = now },
    [123456] = { p = 999, q = 3, t = now },   -- nothing Haulwise uses: not shared
  }
  GP.db.vendorBuy[2592] = GP.db.vendorBuy[2592] or 40
  GP.db.mobs[99001] = GP.db.mobs[99001] or { name = "Test Mob", kills = 1, money = 0, gathered = 0, pp = 0, ppMoney = 0, tIntervals = 0, tSeconds = 0, zones = {}, items = { [2589] = { k = 1, q = 1 } }, gather = {}, ppItems = {} }
  GP.db.priceScanTime = now
  GP:NoteScanRealm(now)
  ok(GP.db.scanRealm and GP.db.scanRealm.r == "Testrealm" and GP.db.scanRealm.f == "H", "a scan remembers its realm and faction")
  local rec = GP:SharedPriceRecord()
  print("     price record: " .. tostring(rec))
  ok(rec and rec:find("^A,Testrealm,H,%d+,") and rec:find("2589:120:400") and rec:find("2592:300:50") and not rec:find("123456"),
     "export shares prices of items Haulwise uses, with realm and faction")
  ok(GP:ExportString():find(";A,Testrealm,H,"), "the price record rides in Share data")
  GP.db.priceScanTime = now - 4 * 86400
  ok(GP:SharedPriceRecord() == nil, "a scan older than 3 days isn't shared")
  GP.db.priceScanTime = now

  -- Importing prices for a realm from the website
  local day = GP.Day()
  local okImp, msg = GP:ImportString("CF2,prices,Testrealm," .. now .. ",,3;A,Testrealm,H," .. day .. ",2589:100:3/4306:777:2")
  print("     " .. tostring(msg))
  ok(okImp and GP.db.realmPrices["Testrealm|H"] and GP.db.realmPrices["Testrealm|H"].items[4306].p == 777, "realm prices import")
  ok(GP.db.shared.prices == nil, "realm prices aren't stored as somebody's drop data")
  local okOld = GP:ImportString("CF2,prices,Testrealm," .. now .. ",,3;A,Testrealm,H," .. (day - 2) .. ",2589:1:1")
  ok(not okOld, "older prices for the same realm are refused")

  -- Which price wins
  local p, _, _, src = GP:Price(2589)
  ok(p == 120 and src == "scan", "a fresh own scan always wins")
  p, _, _, src = GP:Price(4306)
  ok(p == 777 and src == "realm", "an item your scan doesn't have: your realm's shared price")
  GP.db.prices[2589].t = now - 5 * 86400
  p, _, _, src = GP:Price(2589)
  ok(p == 100 and src == "realm", "own scan older than 3 days and the shared price is fresher: shared price")
  GP.db.realmPrices["Testrealm|H"].day = day - 6
  p, _, _, src = GP:Price(2589)
  ok(p == 120 and src == "scan", "but not when the shared price is older than your scan")
  GP.db.realmPrices["Testrealm|H"].day = day
  GP.db.realmPrices["Testrealm|H"].items[2589] = nil
  GP.db.realmPrices["Otherrealm|A"] = { day = day, items = { [5555] = { p = 50, n = 1 } } }
  ok(GP:Price(5555) == nil, "another realm's prices are never used")

  -- The median over all realms shipped with the release
  local okC = pcall(function()
    local _, src2 = GP:ParseExport("CF2,community,Community," .. now .. ",1.0,5;M,5555:400:3/6666:80:1")
    GP.community = src2
    GP.db.shared.community = nil
  end)
  p, _, _, src = GP:Price(6666)
  ok(okC and p == 80 and src == "all", "nothing else: the median over all realms")
  local _, _, d = GP:BagValue(6666, nil, false)
  ok(d.ahFrom == "all", "bag values know the price is a rough guess")
  local lines = {}
  local tip = { AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " " .. r end }
  GP.AddValueLines(tip, 80, "AH", { vendor = 0, ah = 76, ahAge = 0, ahFrom = "all" }, 1)
  ok(table.concat(lines, "|"):find("all realms"), "tooltip says it's from all realms")

  GP.db.prices, GP.db.priceScanTime, GP.db.scanRealm = savedPrices, savedScan, savedRealm
  GP.db.realmPrices = {}
  GP.db.mobs[99001] = nil
  GP.community = nil
  UnitFactionGroup = savedFaction
end

-- Login message about sharing: only with something to share, once a day
do
  local saved = { GP.db.sharedKills, GP.db.loginNudgeDay, GP.db.priceScanTime, GP.db.exportSnaps, GP.community }
  GP.db.loginNudgeDay = nil
  GP.db.priceScanTime = nil
  GP.db.sharedKills = GP:OwnKills()
  ok(GP:LoginShareMessage() == nil, "nothing new: no login message")
  GP.db.sharedKills = GP:OwnKills() - 40
  GP.community = { contributors = 7, mobs = { [1] = { kills = 900 }, [2] = { kills = 334 } } }
  local msg = GP:LoginShareMessage()
  print("     " .. tostring(msg))
  ok(msg and msg:find("40 kills aren't shared yet") and msg:find("/haul export") and msg:find("1234 kills from 7 players"), "40 new kills: login message with the pool size")
  ok(GP:LoginShareMessage() == nil, "only once a day")
  GP.db.loginNudgeDay = nil
  GP.db.sharedKills = GP:OwnKills()
  GP.db.priceScanTime = time() - 3600
  GP.db.exportSnaps = { { t = time() - 86400, s = "" } }
  msg = GP:LoginShareMessage()
  ok(msg and msg:find("latest AH prices"), "an unshared fresh scan is reason enough")
  GP.db.loginNudgeDay = nil
  GP.db.settings.shareReminder = false
  ok(GP:LoginShareMessage() == nil, "off with the share reminder setting")
  GP.db.settings.shareReminder = true
  GP.db.sharedKills, GP.db.loginNudgeDay, GP.db.priceScanTime, GP.db.exportSnaps, GP.community = saved[1], saved[2], saved[3], saved[4], saved[5]
end

-- Farm: estimate-only mobs show their zone, and ones far below you are left out
do
  local savedRaw, savedEst, savedLW = HaulwiseData and HaulwiseData.estimates, GP.db.settings.useEstimates, GP.db.settings.levelWindow
  HaulwiseData = HaulwiseData or {}
  HaulwiseData.estimates = {
    [990001] = { "Test Vermin", 1, 2, 1429, 2, "755:30:1", "" },
    [990002] = { "Test Ogre", 35, 37, 1434, 500, "755:30:1", "" },
  }
  GP.ForgetEstimates()
  GP.db.settings.useEstimates, GP.db.settings.levelWindow = true, true
  local savedLevel = UnitLevel
  UnitLevel = function() return 38 end
  local found = {}
  for _, r in ipairs(GP:Rank()) do found[r.npc] = r end
  ok(found[990002] and found[990002].zone == "#1434", "an estimate-only mob has its zone, not ?")
  ok(found[990001] == nil, "estimate-only mobs more than 10 levels below you are hidden")
  GP.db.settings.levelWindow = false
  found = {}
  for _, r in ipairs(GP:Rank()) do found[r.npc] = r end
  ok(found[990001] ~= nil, "unless the level filter is off")
  UnitLevel = savedLevel
  HaulwiseData.estimates = savedRaw
  GP.ForgetEstimates()
  GP.db.settings.useEstimates, GP.db.settings.levelWindow = savedEst, savedLW
end

-- "This zone only" says how many mobs with real kills it hides
do
  local all, inZone = 0, nil
  for _, m in pairs(GP:MergedMobs()) do
    if (m.kills or 0) > 0 then all = all + 1; if not inZone then for z in pairs(m.zones or {}) do inZone = z; break end end end
  end
  local hidden = GP:FarmHiddenElsewhere(inZone)
  ok(all > 0 and hidden < all and hidden >= 0 and GP:FarmHiddenElsewhere(nil) == 0, "counts mobs with kills outside the zone (" .. hidden .. " of " .. all .. ")")
  GP.db.settings.farmZone = "#99999"
  GP.db.settings.tab = "farm"
  local okUI, err = pcall(GP.RefreshUI, GP)
  ok(okUI, "farm with a zone that has no data draws: " .. tostring(err))
  GP.db.settings.farmZone = nil
  local okUI2, err2 = pcall(GP.RefreshUI, GP)
  ok(okUI2, "footer with price sources draws: " .. tostring(err2))
end

-- Market: trends need a scan from 6+ days ago, however many days you scanned
do
  local saved = GP.db.scanDays
  local t = GP.Day()
  GP.db.scanDays = { [t] = true, [t - 1] = true, [t - 2] = true, [t - 3] = true }
  local left, oldest = GP:TrendDaysLeft()
  ok(left == 3 and oldest == t - 3, "4 days in a row: trends in 3 more days")
  GP.db.scanDays = { [t] = true, [t - 7] = true }
  ok(GP:TrendDaysLeft() == 0, "two scans a week apart are enough")
  GP.db.scanDays = {}
  ok(GP:TrendDaysLeft() == nil, "no scans: nothing to count")
  GP.db.scanDays = saved
end

-- Shopping list: buy at the AH (search, read, confirm), alts, dear days, tools
do
  local savedAH, savedOpen, savedPopup = C_AuctionHouse, GP.ahOpen, GP._showBuyConfirm
  local calls, popups = {}, {}
  local listings = { { unitPrice = 100, quantity = 3 }, { unitPrice = 120, quantity = 2, containsOwnerItem = true, numOwnerItems = 2 }, { unitPrice = 150, quantity = 10 } }
  C_AuctionHouse = setmetatable({
    MakeItemKey = function(id) return { itemID = id } end,
    SendSearchQuery = function(key) calls[#calls + 1] = "search " .. key.itemID end,
    GetNumCommoditySearchResults = function() return #listings end,
    GetCommoditySearchResultInfo = function(_, i) return listings[i] end,
    StartCommoditiesPurchase = function(id, q) calls[#calls + 1] = "start " .. id .. "x" .. q end,
    ConfirmCommoditiesPurchase = function(id, q) calls[#calls + 1] = "confirm " .. id .. "x" .. q end,
    CancelCommoditiesPurchase = function() calls[#calls + 1] = "cancel" end,
    GetNumItemSearchResults = function() return 2 end,
    GetItemSearchResultInfo = function(_, i) return ({ { auctionID = 77, buyoutAmount = 5000, quantity = 1 }, { auctionID = 78, buyoutAmount = 3000, quantity = 1 } })[i] end,
    PlaceBid = function(aid, amount) calls[#calls + 1] = "bid " .. aid .. " " .. amount end,
  }, { __index = savedAH })
  GP._showBuyConfirm = function(text, data) popups[#popups + 1] = { text = text, data = data } end
  GP.ahOpen = true
  local g = { id = 4306, buy = 5, usual = 80 }
  GP:ShopBuy(g)
  ok(calls[1] == "search 4306" and GP:ShopBuyState(4306).stage == "search", "Buy first searches")
  fire("COMMODITY_SEARCH_RESULTS_UPDATED", 4306)
  local b = GP:ShopBuyState(4306)
  ok(b.stage == "ready" and b.got == 5 and b.total == 3 * 100 + 2 * 150, "reads the cheapest 5, skipping your own listings")
  GP:ShopBuy(g)
  ok(calls[2] == "start 4306x5", "second click starts the purchase")
  ok(#popups == 0, "no box before the game confirms the price")
  fire("COMMODITY_PRICE_UPDATED", 120, 600)
  print("     " .. tostring(popups[1] and popups[1].text))
  ok(popups[1] and popups[1].text:find("over the usual price"), "the box warns when it's dear")
  ok(#calls == 2, "nothing is bought before you press Buy in the box")
  popups[1].data.go()
  ok(calls[3] == "confirm 4306x5" and GP:ShopBuyState(4306) == nil, "Buy in the box buys exactly that many")
  -- Items that aren't commodities: the cheapest single auction
  local rod = { id = 6338, buy = 1 }
  GP:ShopBuy(rod)
  fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 6338 })
  ok(GP:ShopBuyState(6338).auctionID == 78 and GP:ShopBuyState(6338).total == 3000, "picks the cheapest auction")
  GP:ShopBuy(rod)
  ok(popups[2] and not popups[2].text:find("over the usual"), "asks first")
  popups[2].data.cancel()
  local bid = false
  for _, c in ipairs(calls) do if c:find("^bid") then bid = true end end
  ok(not bid and GP:ShopBuyState(6338) == nil, "cancel buys nothing")
  -- The real box: Haulwise's own frame, never the game's StaticPopup (that taints Escape)
  local realBox = savedPopup
  local okBox = pcall(realBox, "Buy 1 test?", { go = function() end })
  ok(okBox and StaticPopupDialogs == nil or (StaticPopupDialogs and StaticPopupDialogs.HAULWISE_BUY == nil), "own confirm box, no StaticPopup")
  C_AuctionHouse, GP.ahOpen, GP._showBuyConfirm = savedAH, savedOpen, savedPopup
end

-- Session gold per hour counts AH sales collected from the mail too
do
  local saved = GP.session
  GP.session = GP.NewSession()
  GP.session.start = time() - 1800
  GP.session.value, GP.session.sales, GP.session.salesN = 5000, 17000, 5
  local total, perHour = GP.SessionEarned()
  ok(total == 22000 and math.abs(perHour - 44000) < 1, "session: loot + sales, per hour")
  local lines = {}
  local tip = { AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " " .. r end }
  GP.SessionTooltip(tip)
  ok(table.concat(lines, "|"):find("AH sales collected %(5%)"), "session tooltip shows the sales")
  GP.session = saved
end

-- Gear: a level 5 shaman isn't offered mail (level 40) or anything wearable 4+ levels away
do
  W.items[7030] = { name = "Test Mail Hauberk", sell = 300, quality = 2, k = 4, sk = 3, ilvl = 20, minLevel = 1, equipLoc = "INVTYPE_CHEST" }
  W.stats[7030] = { ITEM_MOD_STRENGTH_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 8, RESISTANCE0_NAME = 200 }
  W.items[7031] = { name = "Test Leather Vest", sell = 300, quality = 2, k = 4, sk = 2, ilvl = 20, minLevel = 9, equipLoc = "INVTYPE_CHEST" }
  W.stats[7031] = { ITEM_MOD_STRENGTH_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 8, RESISTANCE0_NAME = 80 }
  local shaman = function(level) return { classFile = "SHAMAN", level = level, spec = "Enhancement", links = {}, me = false } end
  ok(GP:CompareGear(LINK(7030), shaman(5)) == nil, "level 5 shaman: no mail armor (that's level 40)")
  local soon = GP:CompareGear(LINK(7030), shaman(38))
  ok(soon and soon.atLevel == 40, "level 38 shaman: mail shows, at level 40")
  ok(GP:CompareGear(LINK(7031), shaman(5)) == nil, "level 9 leather at level 5: too far ahead")
  local near = GP:CompareGear(LINK(7031), shaman(7))
  ok(near and near.atLevel == 9, "level 9 leather at level 7: shows, at level 9")
end

-- Gear tab label with Pawn scales in use (scalesLabel was called before it was defined)
do
  local up, vs = GP.UsePawn, GP.PawnVisibleScales
  GP.UsePawn = function() return true end
  GP.PawnVisibleScales = function() return { { "\"Wowhead\":MageFrost", "\"Wowhead\":MageFrost" } } end
  local okL, label = pcall(GP.WeightsLabel, GP)
  print("     " .. tostring(label))
  ok(okL and label == "Pawn: MageFrost", "Gear tab label with Pawn scales")
  GP.UsePawn, GP.PawnVisibleScales = up, vs
end

-- Recipes to learn whose result has no AH price: "no AH price", not minus hundreds of gold
do
  GP:Char().recipes.nosale = { n = "Test Bound Belt", prof = "Tailoring", out = 7999, oq = 1, r = "2589:2", learned = false }
  GP.db.settings.recipesShowAll = true
  local row
  for _, r in ipairs(GP:RecipeRows()) do if r.name == "Test Bound Belt" then row = r end end
  ok(row and row.noSale and row.profit == nil and row.payback == nil, "no AH price for the result: no profit, no payback")
  local rows = GP:RecipeRows()
  local seen, okOrder = false, true
  for _, r in ipairs(rows) do
    if r.name == "Test Bound Belt" then seen = true elseif seen and r.profit and #(r.missing or {}) == 0 then okOrder = false end
  end
  ok(seen and okOrder, "and it's ranked below every recipe with a real profit")
  GP:Char().recipes.nosale = nil
  GP.db.settings.recipesShowAll = false
end

-- The same item listed twice on the AH: one row, the cheapest
do
  local saved = GP.db.ahUpgrades
  local l1 = LINK(7010)
  local l2 = l1:gsub("item:7010::", "item:7010:0:")
  GP.db.ahUpgrades = nil
  GP:FindAHUpgrades({ [l1] = { id = 7010, price = 20000 }, [l2] = { id = 7010, price = 15000 } })
  local n, price = 0, nil
  for _, r in ipairs(GP.db.ahUpgrades.rows) do if r.id == 7010 and r.forMe then n = n + 1; price = r.price end end
  ok(n == 1 and price == 15000, "an item listed twice shows once, the cheaper one")
  GP.db.ahUpgrades = saved
end

-- Scan AH button: lights up again by itself when the 15 minutes are up
do
  local savedOpen, savedT = GP.ahOpen, GP.db.priceScanTime
  GP.ahOpen, GP.db.priceScanTime = true, time() - 60
  local okR = pcall(GP.RefreshScanButton, GP)
  ok(okR and not GP:CanScan(), "scan button waits (and schedules its own wake-up) without looping")
  GP.db.priceScanTime = time() - 16 * 60
  local can, why = GP:CanScan()
  ok(can or not tostring(why):find("min"), "after 15 minutes the wait is over (" .. tostring(why) .. ")")
  GP.ahOpen, GP.db.priceScanTime = savedOpen, savedT
end

-- After a reload the AH upgrades aren't loaded yet: keep them instead of dropping them
do
  local saved = GP.db.ahUpgrades
  GP.db.ahUpgrades = { t = time(), rows = { { id = 7999, link = "|cff1eff00|Hitem:7999::|h[Unloaded Robe]|h|r", price = 5000, gain = 0.5, forMe = true, perGold = 1 } } }
  GP:RecheckAHUpgrades(true)
  ok(#GP.db.ahUpgrades.rows == 1, "an upgrade the game hasn't loaded yet stays on the list")
  GP.db.ahUpgrades = saved
end

-- Farm: mobs get an icon for what they are (wolf, spider, humanoid, elemental), not an item
do
  local savedRaw = HaulwiseData and HaulwiseData.estimates
  HaulwiseData = HaulwiseData or {}
  HaulwiseData.estimates = { [990010] = { "Wolf", 7, 8, 1429, 0, "", "", 1, 1, 380 }, [990011] = { "Exile", 38, 39, 1417, 0, "", "", 4, 0 }, [990012] = { "Old", 1, 1, 1, 0, "", "" } }
  ok(GP.MobIcon(990010) == "Interface\\Icons\\Ability_Hunter_Pet_Wolf", "a wolf gets a wolf")
  ok(GP.MobIcon(990011) == "Interface\\Icons\\Spell_Frost_SummonWaterElemental", "an elemental gets an elemental")
  ok(GP.MobIcon(990012) == nil and GP.MobIcon(123) == nil, "unknown: nil (the row falls back to its main item)")
  ok(GP.MobDisplay(990010) == 380 and GP.MobDisplay(990012) == nil, "the model for a real portrait")
  HaulwiseData.estimates = savedRaw
end

-- Kills an hour for mobs nobody has timed: from how close together they stand
do
  local savedRaw, savedEst = HaulwiseData and HaulwiseData.estimates, GP.db.settings.useEstimates
  HaulwiseData = HaulwiseData or {}
  HaulwiseData.estimates = { [990020] = { "Dense Mob", 30, 31, 1417, 100, "2589:50:1", "", 7, 0, 1, 65 }, [990021] = { "Old Mob", 30, 31, 1417, 100, "2589:50:1", "" } }
  GP.ForgetEstimates()
  GP.db.settings.useEstimates = true
  local savedKph = GP.db.settings.defaultKph
  GP.db.settings.defaultKph = 40
  local m = GP:MergedMobs()
  local a, b = GP:Evaluate(990020, m[990020]), GP:Evaluate(990021, m[990021])
  ok(math.abs(a.kph - 65) < 0.01 and b.kph == GP.db.settings.defaultKph, "estimated kills an hour from spawns (65), else the setting")
  GP.db.settings.defaultKph = 80
  ok(math.abs(GP:Evaluate(990020, m[990020]).kph - 130) < 0.01, "your kills-per-hour setting scales it")
  GP.db.settings.defaultKph = savedKph
  HaulwiseData.estimates = savedRaw
  GP.ForgetEstimates()
  GP.db.settings.useEstimates = savedEst
end

print("NEW FEATURES PASSED")
