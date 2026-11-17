-- Part 2: AH history, deals, crafting, recipes, market, every UI tab.
local GP = GPT
local MEAT, MEDLEATHER, THREAD, BELT, ROAST, BARBELT, PATTERN, THICK, MITHRIL, HIDE =
      2673, 2319, 2321, 4249, 9001, 4264, 5973, 4304, 3860, 4235
W.items[MEDLEATHER] = { name = "Medium Leather", sell = 15, k = 7 }
W.items[THREAD] = { name = "Fine Thread", sell = 25, k = 7 }
W.items[BELT] = { name = "Dark Leather Belt", sell = 1200, k = 4 }
W.items[ROAST] = { name = "Roasted Coyote", sell = 10, k = 0 }
W.items[BARBELT] = { name = "Barbaric Belt", sell = 2000, k = 4 }
W.items[PATTERN] = { name = "Pattern: Barbaric Belt", sell = 500, k = 9, sk = 1 }
W.items[THICK] = { name = "Thick Leather", sell = 75, k = 7 }
W.items[MITHRIL] = { name = "Mithril Bar", sell = 2500, k = 7 }
W.items[HIDE] = { name = "Heavy Hide", sell = 50, k = 7 }

-- Vendor sells thread for 1s.
W.merchant = { { id = THREAD, price = 100, qty = 1 } }
fire("MERCHANT_SHOW")
assert(GP.db.vendorBuy[THREAD] == 100, "vendor price not stored")

-- Profession window opened.
W.prof = { professionName = "Leatherworking", skillLevel = 175, maxSkillLevel = 225 }
W.recipes = {
  [1] = { name = "Dark Leather Belt", learned = true, out = BELT, reagents = { { MEDLEATHER, 5 }, { THREAD, 2 } } },
  [2] = { name = "Barbaric Belt", learned = false, out = BARBELT, reagents = { { THICK, 6 }, { THREAD, 2 } }, src = "Drop: Elemental Slave|nAH" },
}
fire("TRADE_SKILL_SHOW")
W.prof = { professionName = "Cooking", skillLevel = 255, maxSkillLevel = 300 }
W.recipes = { [3] = { name = "Roasted Coyote", learned = true, out = ROAST, reagents = { { MEAT, 1 } }, qmin = 1, qmax = 1 } }
fire("TRADE_SKILL_SHOW")
local ch = GP:Char()
local n = 0 for _ in pairs(ch.recipes) do n = n + 1 end
assert(n == 3, "recipes stored: " .. n)

-- 21 days of scans. Thick Leather around 930c, cheaper on Tuesdays; belts rising.
local base = W.clock
for d = 20, 0, -1 do
  W.clock = base - d * 86400
  local wd = os.date("*t", GP.Day(W.clock) * 86400 + 43200).wday
  local tues = (wd == 3) and 0.8 or 1
  local beltp = 8000 + (20 - d) * 200
  local lists = {
    [THICK] = { { 930 * tues, 300 }, { 1000 * tues, 400 } },
    [MEDLEATHER] = { { 300, 500 } },
    [BELT] = { { beltp, 10 }, { beltp * 1.1, 4 } },
    [ROAST] = { { 1500, 50 } },
    [MEAT] = { { 697, 50 }, { 720, 72 } },
    [BARBELT] = { { 9000, 6 } },
    [PATTERN] = { { 21000, 2 } },
    [MITHRIL] = { { 3000, 40 } },
    [HIDE] = { { 200, 100 } },
  }
  if d == 0 then
    table.insert(lists[THICK], 1, { 410, 18 })        -- under market
    table.insert(lists[MITHRIL], 1, { 1800, 4 })      -- vendor flip (vendor pays 25s)
  end
  GP.db.priceScanTime = 0
  GP._test.finishPrices(lists)
end
W.clock = base

print("--- Deals")
for _, r in ipairs(GP:Deals()) do
  print(string.format("  %-14s %-6s units=%d buy=%.0f target=%.0f profit=%.0f roi=%.0f%% days=%s",
    W.items[r.id].name, r.kind, r.units, r.buy, r.target, r.profit, r.roi * 100, tostring(r.days)))
end
local deals = GP:Deals()
assert(#deals == 2, "expected 2 deals, got " .. #deals)

print("--- Craft")
for _, r in ipairs(GP:CraftRows()) do
  print(string.format("  %-18s cost=%.0f sell=%.0f profit=%.0f farm=%s trend=%s", r.name, r.cost, r.sell, r.profit, tostring(r.usesFarm), tostring(r.trend and math.floor(r.trend*100))))
end
print("--- Recipes")
for _, r in ipairs(GP:RecipeRows()) do
  print(string.format("  %-18s kind=%s profit=%s buy=%s payback=%s", r.name, r.kind, tostring(r.profit and math.floor(r.profit)), tostring(r.buyPrice), tostring(r.payback)))
end
print("--- Market")
for _, r in ipairs(GP:MarketRows()) do
  print(string.format("  %-18s %-14s change=%+.0f%% tip=%s", W.items[r.id].name, r.why, r.change * 100, r.tip))
end
local p, need = GP:WeekdayPattern()
print("weekday:", p and p.flat and "flat" or p and (p.cheapest .. " / " .. p.dearest .. string.format(" spread %.0f%%", p.spread * 100)) or ("need " .. need))
local cv, cn = GP:CraftValue(MEAT)
print("meat craft value", cv, cn)

-- Every tab renders.
for _, tab in ipairs({ "farm", "craft", "deals", "recipes", "market" }) do
  GP.db.settings.tab = tab
  GP:RefreshUI()
  print(tab, "hero:", HaulwiseFrame.hero.text)
end
GP.db.settings.valueAsCrafted = true
GP.db.settings.tab = "farm"
GP:RefreshUI()
print("farm w/ crafted:", HaulwiseFrame.hero.text)
print("PART 2 PASSED")

-- Part 3: community data bundled in Data.lua.
local fh = assert(io.open(DIR .. "/tests/community_export.txt"))
Haulwise_Community = fh:read("*a"); fh:close()
local before = GP:MergedMobs()[113].kills
GP:LoadBundledCommunity()
assert(GP.community and (GP.community.contributors or 0) > 0, "community not loaded")
local after = GP:MergedMobs()[113].kills
print("coyote kills mine+friend:", before, " with community:", after)
assert(after == before + 5000, "community not merged")
-- An older community string pasted by hand is refused; a newer one replaces the bundled one.
local ok1 = GP:ImportString(Haulwise_Community)
assert(not ok1, "same community data imported twice")
local newer = Haulwise_Community:gsub("^CF2,community,Community,(%d+)", function(t) return "CF2,community,Community," .. (t + 1) end)
local ok2, msg2 = GP:ImportString(newer)
print(ok2, msg2)
assert(ok2 and GP.community == nil and GP.db.shared.community, "newer community data not stored")
assert(GP:MergedMobs()[113].kills == after, "community counted twice")
GP.db.settings.tab = "farm"; GP:RefreshUI()
print("footer:", HaulwiseFrame.footer.text)
-- Export header now carries the game build.
print("export head:", GP:ExportString():match("^[^;]+"))
print("ALL TESTS PASSED (with community)")
local out = assert(io.open(DIR .. "/tests/addon_export.txt", "w")); out:write(GP:ExportString()); out:close()
