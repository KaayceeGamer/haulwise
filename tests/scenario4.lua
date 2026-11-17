-- Part 5: AH upgrades, shopping list, sell helper, mats for crafters, skill-ups, bag advice, zones.
local GP = GPT
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end print("ok   " .. msg) end

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
local crafts, reagents, total = GP:ShoppingTotals()
ok(#crafts == 1 and crafts[1].qty == 3, "3 bolts on the list")
ok(reagents[1].id == 4306 and reagents[1].need == 12 and reagents[1].have == 5 and reagents[1].buy == 7, "need 12 silk, have 5, buy 7")
ok(total == 7 * 120, "cost of what's left to buy")
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
print("NEW FEATURES PASSED")
