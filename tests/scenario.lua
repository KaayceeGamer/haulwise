-- Simulated farming session. Run via run.py.
math.randomseed(7)
local GP = {}
for line in io.lines(DIR .. "/Haulwise.toc") do
    local f = line:match("^(%w+)%.lua$")
    if f then
    local chunk = assert(loadfile(DIR .. "/" .. f .. ".lua"))
    chunk("Haulwise", GP)
    end
end
fire("ADDON_LOADED", "Haulwise")
assert(GP.db, "db not set")

local MEAT, CLAW, LEATHER, GREY = 2673, 5635, 4234, 4865
W.items[MEAT] = { name = "Coyote Meat", sell = 4 }
W.items[CLAW] = { name = "Sharp Claw", sell = 35 }
W.items[LEATHER] = { name = "Light Leather", sell = 15 }
W.items[GREY] = { name = "Ruined Pelt", sell = 20 }

local n = 0
local function kill(npc, name, level, drops, opts)
    opts = opts or {}
    n = n + 1
    local guid = string.format("Creature-0-1-1-1-%d-%08X", npc, n)
    -- fighting it
    W.inCombat = true
    W.units.target = { guid = guid, name = name, level = level, dead = false, combat = true }
    GP._test.scanUnit("target")
    W.t = W.t + (opts.fight or 20); W.clock = W.clock + (opts.fight or 20)
    W.inCombat = false
    W.units.target.dead = true
    W.units.target.combat = false
    GP._test.scanUnit("target")
    local hasLoot = #drops > 0
    W.canLoot[guid] = hasLoot
    W.t = W.t + 3
    GP._test.scanAll()
    if hasLoot and not opts.skipLoot then
        W.loot = {}
        for _, d in ipairs(drops) do
            if d.money then
                W.loot[#W.loot + 1] = { money = true, src = { guid, d.money } }
            else
                W.loot[#W.loot + 1] = { id = d.id, src = { guid, d.q or 1 } }
            end
        end
        fire("LOOT_OPENED")
        if opts.reopen then fire("LOOT_OPENED") end -- bags full, reopened
        if opts.skin then
            W.loot = { { id = LEATHER, src = { guid, 1 } } }
            fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 8613)
            fire("LOOT_OPENED")
        end
    end
    W.t = W.t + (opts.gap or 25); W.clock = W.clock + (opts.gap or 25)
    W.units.target = nil
end

-- 300 coyotes: meat 39%, claw 1%, ~20% empty, a few not looted (must NOT count).
local expectedKills = 0
for i = 1, 300 do
    local drops = {}
    if math.random() < 0.39 then drops[#drops + 1] = { id = MEAT } end
    if math.random() < 0.01 then drops[#drops + 1] = { id = CLAW } end
    if math.random() < 0.6 then drops[#drops + 1] = { money = math.random(20, 60) } end
    local skip = (#drops > 0 and i % 25 == 0)
    if not skip then expectedKills = expectedKills + 1 end
    kill(113, "Coyote", 10, drops, { skipLoot = skip, reopen = (i % 40 == 0), skin = true })
end

-- 60 Elemental Slaves, slower, valuable drop.
for i = 1, 60 do
    local drops = { { money = 400 } }
    if math.random() < 0.13 then drops[#drops + 1] = { id = 7067 } end
    kill(2359, "Elemental Slave", 33, drops, { fight = 30, gap = 40 })
end
W.items[7067] = { name = "Elemental Earth", sell = 100 }

-- Prices: Coyote Meat thin market (122 listed), Sharp Claw has a 1c troll listing plus normal ones.
GP._test.finishPrices({
    [MEAT] = { { 697, 50 }, { 720, 72 } },
    [CLAW] = { { 0.5, 1 }, { 30, 200 }, { 35, 500 } },
    [LEATHER] = { { 150, 2000 } },
    [7067] = { { 202, 300 }, { 250, 900 } },
})

local m = GP.db.mobs[113]
print(string.format("Coyote kills recorded=%d expected=%d empty=%d gathered=%d", m.kills, expectedKills, m.empty, m.gathered))
assert(m.kills == expectedKills, "kill count wrong")
assert(m.gathered == expectedKills - m.empty, "skinning count wrong")
print(string.format("Meat drops k=%d (%.1f%%), timed kph from %d intervals over %ds",
    m.items[MEAT].k, 100 * m.items[MEAT].k / m.kills, m.tIntervals, m.tSeconds))

local function show()
    for i, r in ipairs(GP:Rank()) do
        print(string.format("%d. %-16s kills=%d kph=%.0f%s perKill=%.1fc est=%.0fc/h safe=%.0fc/h", i, r.name, r.kills, r.kph,
            r.measured and "" or "(default)", r.perKill, r.est, r.safe))
        for _, l in ipairs(r.lines) do
            print(string.format("     %-6d %-10s %5.1f%% [%4.1f-%4.1f]  %7.0fc/h %s %s", l.id, l.kind, l.chance * 100, l.lo * 100,
                l.hi * 100, l.perHour, l.thin and "THIN" or "", l.priced and "" or "vendor"))
        end
    end
end
show()

-- Pickpocket: rogue picks a living target.
local guid = "Creature-0-1-1-1-113-FFFF0001"
W.units.target = { guid = guid, name = "Coyote", level = 10, dead = false }
W.loot = { { money = true, src = { guid, 15 } } }
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 921)
fire("LOOT_OPENED")
assert(GP.db.mobs[113].pp == 1 and GP.db.mobs[113].ppMoney == 15, "pickpocket not recorded")
assert(GP.db.mobs[113].kills == expectedKills, "pickpocket counted as a kill")
print("pickpocket ok")

-- Group: nothing recorded.
W.inGroup = true
local before = GP.db.mobs[113].kills
kill(113, "Coyote", 10, { { id = MEAT } })
assert(GP.db.mobs[113].kills == before, "recorded in group")
W.inGroup = false
print("group filter ok")

-- Export / import round trip as a friend.
local s = GP:ExportString()
print("export length", #s)
local myUid = GP.db.uid
GP.db.uid = "friend00"
local ok, msg = GP:ImportString(s)
print(ok, msg)
assert(ok)
local ok2 = GP:ImportString(s) -- importing again must replace, not double
GP.db.uid = myUid
local merged = GP:MergedMobs()[113]
assert(merged.kills == 2 * GP.db.mobs[113].kills, "merge wrong: " .. merged.kills)
print("import ok, merged kills", merged.kills)
local bad, bmsg = GP:ImportString("hello")
assert(not bad); print(bmsg)
local bad2, bmsg2 = GP:ImportString("CF1,x,y,1;12,a,b")
assert(not bad2); print(bmsg2)

-- UI smoke test with mocks.
GP:ToggleUI()
GP:RefreshUI()
print("best line:", HaulwiseFrame.hero.text)
print("footer:", HaulwiseFrame.footer.text)
print("session:", HaulwiseFrame.sessTop.text, HaulwiseFrame.sessBottom.text)
SlashCmdList.HAULWISE("kph 55")
SlashCmdList.HAULWISE("help")
print("PART 1 PASSED")
GPT = GP
