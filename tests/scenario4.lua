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
  GetWorldPosFromMapPos = function(m, v) return 0, { x = m * 10 + v.x, y = v.y } end,
  GetMapInfo = function(m) return { name = "Map " .. m } end,
  SetUserWaypoint = function(p) wp = p end,
}
GP:Char().profs = { Tailoring = { rank = 150, max = 150 } }
ok(GP:FindTrainer("Tailoring") and wp and wp.m == 1453, "waypoint to the nearest Alliance tailoring trainer (Stormwind)")
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
W.quest = { 4865 }
ok(GP:QuestRewardPick() == nil, "nothing to choose with one reward")

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
print("NEW FEATURES PASSED")
