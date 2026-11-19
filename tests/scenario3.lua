-- Part 4: bags, values, disenchant, swaps, make room, upgrade advisor, holdings, HUD.
local GP = GPT
local function ok(cond, msg) if not cond then if PSEUDO or LOCALE_RUN then print("TEXT-CHECK " .. msg); return end error("FAIL: " .. msg, 2) end print("ok   " .. msg) end

-- Items (classID 4 armor, 2 weapon, 12 quest, 15 misc, 7 trade goods)
W.items[6948]  = { name = "Hearthstone", sell = 0, k = 15 }
W.items[4865]  = { name = "Ruined Pelt", sell = 20, quality = 0, k = 15 }
W.items[2589]  = { name = "Linen Cloth", sell = 13, k = 7, maxStack = 20 }
W.items[5000]  = { name = "Coyote Quest Part", sell = 0, k = 12 }
W.items[7001]  = { name = "Green Bracers", sell = 300, quality = 2, k = 4, sk = 2, ilvl = 28, equipLoc = "INVTYPE_WRIST", bind = 2 }
W.items[7002]  = { name = "Robe of the Owl", sell = 900, quality = 2, k = 4, sk = 1, ilvl = 33, equipLoc = "INVTYPE_ROBE", bind = 2 }
W.items[7003]  = { name = "Old Cloth Robe", sell = 50, quality = 1, k = 4, sk = 1, ilvl = 20, equipLoc = "INVTYPE_CHEST" }
W.items[7004]  = { name = "Agile Leather Boots", sell = 700, quality = 2, k = 4, sk = 2, ilvl = 34, equipLoc = "INVTYPE_FEET", bind = 2 }
W.items[7005]  = { name = "Skinning Knife", sell = 10, k = 2, sk = 15 }
W.items[7006]  = { name = "Worn Boots", sell = 5, k = 4, sk = 2, equipLoc = "INVTYPE_FEET" }
W.items[11083] = { name = "Soul Dust", sell = 0, k = 7 }
W.items[11082] = { name = "Greater Astral Essence", sell = 0, k = 7 }
W.items[11084] = { name = "Large Glimmering Shard", sell = 0, k = 7 }
W.items[9999]  = { name = "Shiny Loot Ring", sell = 5000, quality = 2, k = 4, sk = 0, equipLoc = "INVTYPE_FINGER", bind = 2 }
W.stats = {
  [7002] = { ITEM_MOD_INTELLECT_SHORT = 8, ITEM_MOD_SPIRIT_SHORT = 5, ITEM_MOD_STAMINA_SHORT = 4, RESISTANCE0_NAME = 60 },
  [7003] = { ITEM_MOD_INTELLECT_SHORT = 2, RESISTANCE0_NAME = 30 },
  [7004] = { ITEM_MOD_AGILITY_SHORT = 7, ITEM_MOD_STAMINA_SHORT = 3, RESISTANCE0_NAME = 80 },
  [7006] = { RESISTANCE0_NAME = 40 },
  [7001] = { ITEM_MOD_STRENGTH_SHORT = 3 },
}

-- Me: level 34 mage, Tailoring (recipe uses linen). Alt: level 30 rogue with Enchanting 200.
W.class = "MAGE"
W.level = 34
W.equipped = { [5] = 7003 }
GP:Char().recipes["r99"] = { n = "Linen Bag", prof = "Tailoring", out = 4238, oq = 1, r = "2589:3", learned = true }
GP.db.chars["Alkhara-Testrealm"] = { short = "Alkhara", realm = "Testrealm", faction = "Horde", class = "Rogue", classFile = "ROGUE",
  level = 30, spec = "Combat", profs = { Enchanting = { rank = 200 } }, equippedLinks = { [8] = LINK(7006) },
  bags = { [2589] = 40 }, bank = { [11083] = 12 }, gold = 50000 }

-- Prices: DE materials, meat; scan freshly.
GP.db.priceScanTime = 0
GP._test.finishPrices({
  [11083] = { { 4000, 50 } }, [11082] = { { 6000, 20 } }, [11084] = { { 9000, 10 } },
  [2673] = { { 697, 50 } }, [2589] = { { 40, 200 } },
})

-- Bags: one 16-slot backpack, completely full.
local slots = {
  { id = 6948 }, { id = 4865 }, { id = 2589, count = 20 }, { id = 5000, quest = true }, { id = 7001 }, { id = 7002 },
  { id = 7004 }, { id = 7005 }, { id = 2673, count = 3 }, { id = 11083, count = 2 },
}
W.bags = { [0] = { size = #slots, slots = {} } }
for i, s in ipairs(slots) do W.bags[0].slots[i] = s end

GP:ScanUpgrades()
ok(#GP.upgrades.mine == 1 and GP.upgrades.mine[1].id == 7002, "Robe of the Owl is an upgrade for the mage")
ok(#GP.upgrades.alts >= 1 and GP.upgrades.alts[1].alt == "Alkhara" and GP.upgrades.alts[1].id == 7004, "leather boots are an upgrade for the rogue alt")
print(string.format("     robe +%.0f%% over %s, boots +%.0f%% for Alkhara", GP.upgrades.mine[1].gain * 100,
  GP.upgrades.mine[1].slotName, GP.upgrades.alts[1].gain * 100))

-- Disenchant value of the green bracers (ilvl 28: soul dust 75% 1-2, greater astral 20%, large glimmering 5%)
local de, outcomes, who = GP:DisenchantValue(LINK(7001), false)
local expect = (0.75 * 1.5 * 4000 + 0.20 * 1.5 * 6000 + 0.05 * 1 * 9000) * 0.95
ok(de and math.abs(de - expect) < 1, string.format("DE value of green bracers = %s (expected %.0f)", tostring(de and math.floor(de)), expect))
ok(who[1] == "Alkhara", "alt Alkhara can disenchant it")
local v, src = GP:BagValue(7001, LINK(7001), false)
ok(src == "DE" and v > 300, "bag value of bracers uses DE (" .. math.floor(v) .. "c) over vendor 300c")
local v2, src2 = GP:BagValue(7001, LINK(7001), true)
ok(src2 == "V", "soulbound bracers: the alt can't disenchant them, so vendor value")

-- Protection and candidates
local items = GP:BagItems()
local reasons = {}
for _, r in ipairs(items) do reasons[r.id] = r.protect or "-" end
ok(reasons[6948] == "tool", "hearthstone protected")
ok(reasons[5000] == "quest", "quest item protected")
ok(reasons[11083] == "crafting material", "soul dust (enchanting) protected")
ok(reasons[2589] == "crafting material", "linen (crafting material) protected")
ok(reasons[11083] == nil or reasons[11083] == "crafting material", "soul dust never offered")
ok(reasons[7002] == "upgrade for you", "robe protected as your upgrade")
ok(reasons[7004] == "upgrade for Alkhara", "boots protected as the alt's upgrade")
ok(reasons[7005] == "tool", "skinning knife protected")
local cands = GP:DeleteCandidates()
local order = {}
for _, c in ipairs(cands) do order[#order + 1] = W.items[c.id].name .. "=" .. math.floor(c.total) end
print("     delete order: " .. table.concat(order, ", "))
ok(cands[1].id == 4865, "cheapest deletable item is the grey pelt")
ok(GP:FreeSlots() == 0, "bags are full")

-- Loot window with a ring worth 50s while bags are full -> swap popup -> Swap
W.loot = { { id = 9999, src = { "Creature-0-1-1-1-113-ABC", 1 } } }
fire("LOOT_OPENED")
ok(HaulwiseSwap and HaulwiseSwap.shown, "swap popup shown")
print("     popup: " .. tostring(HaulwiseSwap.title.text) .. " | " .. tostring(HaulwiseSwap.verdict.text))
HaulwiseSwap.go.scripts.OnClick()
ok(#W.deleted == 1 and W.deleted[1][2] == 2 and W.looted[1] == 1, "swap deleted the pelt and looted the ring")

-- Make room
GP:ShowMakeRoom()
ok(HaulwiseMakeRoom.shown, "make room popup shown")
print("     make room: " .. tostring(HaulwiseMakeRoom.rows[1].name.text) .. " " .. tostring(HaulwiseMakeRoom.rows[1].right.text))
HaulwiseMakeRoom:Hide()

-- Keep list via shift-click in Bags tab
GP.db.keep[2673] = true
local kept
for _, r in ipairs(GP:BagItems()) do if r.id == 2673 then kept = r.protect end end
ok(kept == "kept", "shift-click keep list protects Coyote Meat")

-- Holdings
fire("PLAYER_ENTERING_WORLD")
local rows, total = GP:HoldingsRows()
ok(#rows > 0 and total > 0, string.format("holdings: %d items worth %dc across characters", #rows, math.floor(total)))
local linen
for _, r in ipairs(rows) do if r.id == 2589 then linen = r end end
ok(linen and linen.count == 60, "linen counted in my bags (20) and the alt's bags (40)")

-- HUD and every tab render
GP:ShowHUD()
print("     HUD: gold " .. tostring(HaulwiseHUD.goldR.text) .. " | bags " .. tostring(HaulwiseHUD.bagsL.text) .. " " .. tostring(HaulwiseHUD.bagsR.text) .. " | total " .. tostring(HaulwiseHUD.totalR.text))
for _, tab in ipairs({ "farm", "bags", "gear", "craft", "deals", "recipes", "market", "holdings" }) do
  GP.db.settings.tab = tab
  GP:ShowUI()
  print(string.format("     %-9s %s", tab, tostring(HaulwiseFrame.hero.text):sub(1, 110)))
end
ok(GP.db.settings.winShown and GP.db.settings.hudShown, "window and HUD remember they're open")
print("ALL TESTS PASSED (bags, gear, holdings)")
-- Scaling
GP.Rescale(HaulwiseHUD, "hudScale", 0.1)
GP.Rescale(HaulwiseFrame, "winScale", -0.2)
ok(math.abs(GP.db.settings.hudScale - 1.1) < 0.001 and math.abs(GP.db.settings.winScale - 0.8) < 0.001, "HUD and window scale saved")
local t = GP:Totals()
ok(t.total == t.gold + t.best + t.bank + t.mailGold, string.format("totals: gold %d + bags %d = %d", t.gold, math.floor(t.best), math.floor(t.total)))
GameTooltip.lines = 0
GP:AddTotalsTooltip(GameTooltip)
print("SCALE AND TOTALS PASSED")
-- Equipped gear has no value in Holdings
W.equipped = { [5] = 7003 }
GP.db.chars[GP:CharKey()].equipped = { [7003] = 1 }
local hr = GP:HoldingsRows(nil, "equipped")
ok(#hr >= 1 and hr[1].value == 0 and hr[1].worn, "equipped robe is listed but worth nothing")
print("EQUIPPED PASSED")
-- Settings window
GP:ToggleSettings()
ok(HaulwiseSettings.shown, "settings window opens")
GP.db.settings.fontSize = 14; GP.ApplyFonts()
GP.db.settings.opacity = 0.7; GP.ApplyOpacity()
GP.Rescale(HaulwiseFrame, "winScale", 0.05)
print("SETTINGS PASSED")
-- Pawn: its weights decide. Here Pawn rates the old robe higher than the new one -> no upgrade.
PawnIsInitialized = true
function PawnGetAllScalesEx() return { { Name = '"Classic":MAGE3', LocalizedName = "Frost", IsVisible = true },
                                       { Name = '"Classic":MAGE1', LocalizedName = "Arcane", IsVisible = false } } end
function PawnGetItemData(link) return { id = tonumber(link:match("item:(%d+)")) } end
W.pawn = { [7002] = 20, [7003] = 35 }
function PawnGetSingleValueFromItem(item, scale) return W.pawn[item.id] or 0 end
W.bags[0].slots[6] = { id = 7002 }
GP:ScanUpgrades()
local robeUp = false
for _, r in ipairs(GP.upgrades.mine) do if r.id == 7002 then robeUp = true end end
ok(not robeUp, "with Pawn weights saying the old robe is better, the robe is not an upgrade")
W.pawn[7002] = 50
GP:ScanUpgrades()
local found
for _, r in ipairs(GP.upgrades.mine) do if r.id == 7002 then found = r end end
ok(found and math.abs(found.gain - (50 - 35) / 35) < 0.001 and found.label == "Pawn: Frost", string.format("Pawn value 50 vs 35: +%.0f%% (%s)", found and found.gain * 100 or 0, found and found.label or "?"))
GP.db.settings.usePawn = false
GP:ScanUpgrades()
ok(GP.upgrades.mine[1] and GP.upgrades.mine[1].label:find("Haulwise"), "Pawn switched off: Haulwise's own weights")
GP.db.settings.usePawn = true
GP:CycleSpec()
ok(not GP.db.settings.usePawn, "Gear button cycles from Pawn to Haulwise weights")
print("PAWN PASSED")
-- Sorting by clicking a column title
GP.db.settings.tab = "bags"; GP:ShowUI()
GP:SortBy("total")
local first = HaulwiseFrame.hero and GP.db.settings.sorts.bags
ok(first.key == "total" and first.desc == true, "first click sorts by worth, biggest first")
GP:SortBy("total")
ok(GP.db.settings.sorts.bags.desc == false, "second click reverses")
GP:SortBy("name")
ok(GP.db.settings.sorts.bags.key == "name" and GP.db.settings.sorts.bags.desc == false, "names sort A to Z")
local rowsB = GP:BagItems()
for _, tabName in ipairs({ "farm", "craft", "deals", "recipes", "market", "holdings", "gear" }) do
  GP.db.settings.tab = tabName
  GP:RefreshUI()
  local keys = {}
  for k in pairs(GP.db.settings.sorts) do keys[#keys+1] = k end
end
GP.db.settings.tab = "craft"
GP.db.settings.sorts.craft = { key = "profit", desc = true }
GP:RefreshUI()
print("     craft hero: " .. tostring(HaulwiseFrame.hero.text):sub(1, 120))
print("SORT PASSED")
-- Recipe sources learned in game
W.units.npc = { name = "Darianna" }
W.zone = "Darnassus"
W.trainer = { { name = "Barbaric Belt", prof = "Leatherworking", skill = 200, cost = 15000 }, { name = "Defensive Stance", cost = 10 } }
fire("TRAINER_SHOW")
ok(GP.db.sources["barbaric belt"] and GP.db.sources["barbaric belt"].trainer["Darianna"].cost == 15000, "trainer recipe noted with cost")
ok(GP.db.sources["defensive stance"] == nil, "class skills are not recipes")
ok(W.filters.unavailable == false, "trainer filters restored")
W.units.npc = { name = "Bale" }
W.merchant = { { id = 5973, name = "Pattern: Barbaric Belt", price = 9000, qty = 1, stock = 1 } }
fire("MERCHANT_SHOW")
ok(GP.db.sources["barbaric belt"].vendor["Bale"].price == 9000 and GP.db.sources["barbaric belt"].vendor["Bale"].limited, "vendor pattern noted (limited stock)")
local recs = GP:RecipeRows()
local bb
for _, r in ipairs(recs) do if r.name == "Barbaric Belt" then bb = r end end
ok(bb and #bb.sources >= 2, "Barbaric Belt has " .. (bb and #bb.sources or 0) .. " sources")
for _, src in ipairs(bb.sources) do print("     " .. src.kind .. ": " .. tostring(GP.SourceLong(src))) end
ok(bb.learnCost == 9000, "cheapest way to learn: vendor 90s")
print("     payback: " .. tostring(bb.payback) .. " crafts, profit " .. tostring(bb.profit and math.floor(bb.profit)))
GP.db.settings.tab = "recipes"; GP:RefreshUI()
print("     recipes hero: " .. tostring(HaulwiseFrame.hero.text):sub(1, 120))
print("SOURCES PASSED")
-- Community sources (from the server export) show up for recipes you never saw yourself
local srcs, cheapest = GP:RecipeSources("Bolt of Silk Cloth")
ok(#srcs >= 1 and srcs[1].kind == "Trainer" and srcs[1].who == "Darianna" and cheapest == 500, "community trainer source used for Bolt of Silk Cloth")
local s2, c2, item2 = GP:RecipeSources("Red Linen Robe")
ok(item2 == 6271 and c2 == 9000, "community vendor and recipe item used for Red Linen Robe")
GP.db.vendorBuy[2321] = nil
ok(GP:BuyCost(2321) == 100, "community vendor price used for Fine Thread")
local exp = GP:ExportString()
ok(exp:find("^CF2,") and exp:find(";T,barbaric belt,Darianna,") and exp:find(";V,barbaric belt,Bale,"), "your own trainer and vendor sightings are exported")
print("COMMUNITY SOURCES PASSED")
GP:ShowGuide(true)
ok(HaulwiseGuide.shown, "guide opens with What's new")
SlashCmdList.HAULWISE("guide")
print("GUIDE PASSED")

-- Sharing reminders and the unshared-kill counter
local printed = {}
local oldPrint = GP.Print
GP.Print = function(m) printed[#printed + 1] = m end
GP.db.mobs = {}
GP:Mob(1).kills = 150
GP.db.mobs[1].name = "Test Mob"
GP.db.sharedKills, GP.db.shareNudgedAt = 0, 0
ok(GP:UnsharedKills() == 150, "150 kills not shared yet")
GP:MaybeNudgeShare()
ok(#printed == 1 and printed[1]:find("150 kills") and printed[1]:find("no names"), "reminder printed after 100+ unshared kills, with what gets shared")
GP:MaybeNudgeShare()
ok(#printed == 1, "reminder not repeated before 100 more kills")
GP:ShowExport()
ok(GP:UnsharedKills() == 0, "opening Share data marks them as shared")
GP.db.mobs[1].kills = 400
GP.db.settings.shareReminder = false
GP:MaybeNudgeShare()
ok(#printed == 1, "reminder off in settings")
GP.db.settings.shareReminder = true
GP:MaybeNudgeShare()
ok(#printed == 2, "reminder again after 100 more")
SlashCmdList.HAULWISE("feedback")
ok(HaulwiseShareFrame and HaulwiseShareFrame.shown ~= false, "feedback window opens")
GP.Print = oldPrint
print("SHARING PASSED")

-- Things you use again and again are never offered to sell or throw away
local spells = { [8001] = "Rest", [8002] = "Food", [8003] = "Learning", [8004] = "Equip use" }
GetItemSpell = function(id) return spells[id] end
ok(GP.UsableKeepReason(8001, { classID = 15, subclassID = 4, maxStack = 1 }) == "item you use", "sleeping bag (misc, Use:) is kept")
ok(GP.UsableKeepReason(8002, { classID = 0, subclassID = 5, maxStack = 20 }) == nil, "a stack of food may still go")
ok(GP.UsableKeepReason(8003, { classID = 0, subclassID = 8, maxStack = 1 }) == "item you use", "a single reusable consumable is kept")
ok(GP.UsableKeepReason(8004, { classID = 4, subclassID = 0, maxStack = 1 }) == nil, "gear with a Use: is left to the gear rules")
ok(GP.UsableKeepReason(4865, { classID = 15, subclassID = 0, maxStack = 1 }) == nil, "plain junk without Use: may go")
ok(GP.UsableKeepReason(8005, { classID = 15, subclassID = 5, maxStack = 1 }) == "mount", "mount item is kept")
GetItemSpell = nil
