-- Haulwise: deals, trends and weekday patterns from your AH scans.
local _, GP = ...
local L = GP.L

local WEEKDAYS = CALENDAR_WEEKDAY_NAMES or { L["Sunday"], L["Monday"], L["Tuesday"], L["Wednesday"], L["Thursday"], L["Friday"], L["Saturday"] }
local GEAR = { [2] = true, [4] = true } -- weapons, armor: random stats per listing

local function weekday(day)
    local t = date("*t", day * 86400 + 43200)
    return t and t.wday or 1
end

-- 7-day trend: median of the last 3 days vs the median a week before. nil until 4+ days.
-- Without enough of your own scans: TSM's market value against its 60-day historical price for
-- your realm (a second value, "TSM").
local function tsmTrend(id)
    if not GP.TSMValue then return nil end
    local now, hist = GP.TSMValue("DBMarket", id), GP.TSMValue("DBHistorical", id)
    if now and hist and hist > 0 then return now / hist - 1, "TSM" end
end

function GP:Trend(id)
    local own, from = self:OwnTrend(id)
    if own then return own end
    return tsmTrend(id)
end

function GP:OwnTrend(id)
    local h = self:History(id)
    if #h < 4 then return nil end
    local today, recent, prior = GP.Day(), {}, {}
    for _, e in ipairs(h) do
        if e.d > today - 3 then recent[#recent + 1] = e.p
        elseif e.d <= today - 6 and e.d > today - 14 then prior[#prior + 1] = e.p end
    end
    if #recent == 0 or #prior == 0 then return nil end
    local r, p = GP.Median(recent), GP.Median(prior)
    if not p or p <= 0 then return nil end
    return r / p - 1
end

-- Days until the first trends can show (0 = now), and the oldest scan day counted.
function GP:TrendDaysLeft()
    local today, oldest = GP.Day(), nil
    for d in pairs(self.db.scanDays or {}) do
        if d > today - 14 and (not oldest or d < oldest) then oldest = d end
    end
    if not oldest then return nil, nil end
    return math.max(0, oldest + 6 - today), oldest
end

-- Deals ------------------------------------------------------------------------------------

-- Deals: listings on your AH you can buy for a profit. Five kinds:
--   flip    listed below what a vendor pays (no risk)
--   under   30%+ below its usual price, resold at what it really sells for
--   de      gear listed below what disenchanting it gives (you or an alt can disenchant it)
--   craft   a mat listed below the most a vendor flip can pay for it (see Craft > Vendor flips)
-- A resale deal is only counted for as many as sell in about 3 days, and not at all when it
-- would take more than two weeks to sell.
local MAX_SELL_DAYS = 14

function GP:Deals()
    local s = self.db.settings
    local rows = {}
    -- Craft mats: the highest "buy below" per mat among the vendor flips you can craft.
    local craftLimit = {}
    if self.VendorFlipRows then
        for _, r in ipairs(self:VendorFlipRows()) do
            if r.mat and r.below and r.below > 0 and (not craftLimit[r.mat] or r.below > craftLimit[r.mat].below) then
                craftLimit[r.mat] = r
            end
        end
    end
    for id, p in pairs(self.db.prices) do
        local gear = GEAR[p.k or 0]
        local cheap = self:Cheapest(id)
        local vendor = p.s or 0
        local candidates = {}

        -- Vendor flips: listed below what a vendor pays. Zero risk.
        local fUnits, fCost, fProfit = 0, 0, 0
        for _, l in ipairs(cheap) do
            if vendor > 0 and l.u < vendor then
                fUnits, fCost, fProfit = fUnits + l.c, fCost + l.u * l.c, fProfit + (vendor - l.u) * l.c
            end
        end
        if fProfit > 0 then candidates[#candidates + 1] = { kind = "flip", units = fUnits, cost = fCost, profit = fProfit, target = vendor } end

        -- Disenchant flips: gear for less than its expected disenchant value (90%, for bad luck).
        if gear and s.useDisenchant ~= false then
            local de = self:DisenchantValue(id)
            if de and de > 0 then
                local dUnits, dCost, dProfit = 0, 0, 0
                for _, l in ipairs(cheap) do
                    if l.u < de * 0.9 and dUnits < 20 then
                        local take = math.min(l.c, 20 - dUnits)
                        dUnits, dCost, dProfit = dUnits + take, dCost + l.u * take, dProfit + (de - l.u) * take
                    end
                end
                if dProfit > 0 then candidates[#candidates + 1] = { kind = "de", units = dUnits, cost = dCost, profit = dProfit, target = de } end
            end
        end

        -- Craft mats under a vendor flip's limit.
        local cl = craftLimit[id]
        if cl then
            local cUnits, cCost, cProfit = 0, 0, 0
            for _, l in ipairs(cheap) do
                if l.u < cl.below and cUnits < 200 then
                    local take = math.min(l.c, 200 - cUnits)
                    cUnits, cCost, cProfit = cUnits + take, cCost + l.u * take, cProfit + (cl.below - l.u) * take
                end
            end
            if cProfit > 0 then
                candidates[#candidates + 1] = { kind = "craft", units = cUnits, cost = cCost, profit = cProfit, target = cl.below,
                                                craft = cl.out, craftName = cl.name, matQty = cl.matQty }
            end
        end

        -- Under market: resold at what it really sells for.
        if s.dealsGear or not gear then
            local market, days, from = self:MarketValue(id)
            -- TSM's value is one price for every "of the ..." version of a piece of gear: no use.
            if gear and from == "TSM" then market = nil end
            -- What it actually sells for (TSM's region sale average) when that's lower.
            if market and from == "TSM" then
                local sale = GP.TSMValue and GP.TSMValue("DBRegionSaleAvg", id)
                if sale and sale < market then market = sale end
            end
            local maxUnits = math.max(1, math.min(200, math.floor((p.q or 1) * 0.25)))
            local perDay, speedDays = self:SellSpeed(id)
            if perDay and (speedDays or 0) >= 1 then maxUnits = math.min(maxUnits, math.ceil(perDay * 3)) end
            local unsold = (perDay == 0 and (speedDays or 0) >= 2) or (perDay and perDay > 0 and 1 / perDay > MAX_SELL_DAYS)
            local trusted = (days or 0) >= 3 or ((p.q or 0) >= 20 and not gear)
            local target = market
            if market and (days or 0) < 3 then
                for _, l in ipairs(cheap) do
                    if l.u > market * 0.70 then target = math.min(market, l.u); break end
                end
            end
            local uUnits, uCost, uProfit = 0, 0, 0
            if target and target > 0 and trusted and not unsold and maxUnits > 0 then
                for _, l in ipairs(cheap) do
                    if l.u <= target * 0.70 and uUnits < maxUnits then
                        local take = math.min(l.c, maxUnits - uUnits)
                        uUnits, uCost = uUnits + take, uCost + l.u * take
                        uProfit = uProfit + (target * 0.95 - l.u) * take
                    end
                end
                -- Too good to be true on thin evidence: a few scans, or a rare item's TSM value.
                local roi = uCost > 0 and uProfit / uCost or 0
                if ((days or 0) < 3 and roi > 3) or (from == "TSM" and roi > 4 and (perDay or 0) < 1) then uUnits, uCost, uProfit = 0, 0, 0 end
            end
            if uProfit > 0 then
                local sellDays = perDay and perDay > 0 and uUnits / perDay or nil
                candidates[#candidates + 1] = { kind = "under", units = uUnits, cost = uCost, profit = uProfit, target = target, days = days,
                                                from = from, sellDays = sellDays, vendorSafe = fProfit > 0 }
            end
        end

        local row
        for _, c in ipairs(candidates) do if not row or c.profit > row.profit then row = c end end
        if row and row.profit >= (s.minProfit or 0) then
            row.id = id
            row.buy = row.cost / math.max(1, row.units)
            row.roi = row.cost > 0 and row.profit / row.cost or 0
            row.isRecipe = p.k == 9
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b) return a.profit > b.profit end)
    return rows
end

-- Market tab ---------------------------------------------------------------------------------

-- The usual price of an item: your own scans' median when they cover a week, else TSM's 60-day
-- price for your realm, else your scans' median from 3+ days. Returns price, where from.
function GP:UsualPrice(id)
    local h = self:History(id)
    local today, vals = GP.Day(), {}
    for _, e in ipairs(h) do if e.d > today - 14 then vals[#vals + 1] = e.p end end
    if #vals >= 7 then return GP.Median(vals), "scan" end
    local tsm = GP.TSMValue and GP.TSMValue("DBHistorical", id)
    if tsm then return tsm, "TSM" end
    if #vals >= 3 then return GP.Median(vals), "scan" end
    return nil
end

-- The price now: your scan when it's under 2 days old, else TSM's lowest listing at its last
-- update, else your older scan.
function GP:PriceNow(id)
    local p = self.db.prices[id]
    if p and p.p and time() - (p.t or 0) < 2 * 86400 then return p.p, "scan" end
    local tsm = GP.TSMValue and GP.TSMValue("DBMinBuyout", id)
    if tsm then return tsm, "TSM" end
    if p and p.p then return p.p, "scan" end
end

-- What you have to sell (bags, bank, mail; not what you wear or already list), all characters.
local function holdings(self)
    local have = {}
    local rows = self.HoldingsRows and self:HoldingsRows() or {}
    for _, r in ipairs(rows) do
        local n = 0
        for _, w in ipairs(r.where) do
            if w.loc ~= "equipped" and w.loc ~= "ah" then n = n + w.n end
        end
        if n > 0 then have[r.id] = n end
    end
    return have
end

-- Market: for what you farm, gather, craft, use and hold, the price now against the usual one,
-- with what to do about it: sell what's dear now, stock up on reagents that are cheap, farm or
-- craft what's in demand, hold what's cheap. Plus the biggest movers you don't deal in.
function GP:MarketRows()
    local why = {}
    for _, m in pairs(self:MergedMobs()) do
        for id in pairs(m.items) do why[id] = "you farm this" end
        for id in pairs(m.gather) do why[id] = "you gather this" end
    end
    for _, rec in pairs(self:Char().recipes) do
        if rec.learned then
            why[rec.out] = why[rec.out] or "you craft this"
            for _, r in ipairs(GP.UnpackReagents(rec.r)) do why[r[1]] = why[r[1]] or "your reagent" end
        end
    end
    local have = holdings(self)

    -- What you deal in, plus anything on the AH that trades for at least 50 silver a day (a big
    -- mover is only worth showing if it does): checking every one of thousands is what's slow.
    local candidates = {}
    for id in pairs(why) do candidates[id] = true end
    for id in pairs(have) do candidates[id] = true end
    for id, p in pairs(self.db.prices) do
        if not candidates[id] and p.p then
            local per = self:SellSpeed(id)
            if per and p.p * per >= 5000 then candidates[id] = true end
        end
    end

    local rows, movers = {}, {}
    for id in pairs(candidates) do
        local name, quality, _, vendorPrice, bind = GP.ItemInfo(id)
        local junk = quality == 0 or bind == 1
        if not junk then
            local now, nowFrom = self:PriceNow(id)
            local usual, usualFrom = self:UsualPrice(id)
            if now and usual and usual >= 10 then
                local change = now / usual - 1
                local per = self:SellSpeed(id)
                local n = have[id]
                -- A vendor pays more than the AH: that's no market for it.
                local vendorBetter = (vendorPrice or 0) >= now * 0.95
                local r = { id = id, now = now, usual = usual, change = change, per = per, have = n, why = why[id],
                            tsm = nowFrom == "TSM" or usualFrom == "TSM" }
                local w = r.why
                local sells = per == nil or per >= 0.3
                if vendorBetter then r.tip = "Vendor it"
                elseif n and change >= 0.15 and sells then r.tip = "Sell now"
                elseif w == "your reagent" and change <= -0.15 then r.tip = "Stock up"
                elseif n and change <= -0.15 then r.tip = "Hold"
                elseif w == "your reagent" and change >= 0.15 then r.tip = "Buy later"
                elseif (w == "you farm this" or w == "you gather this") and change >= 0.15 and sells then r.tip = "Farm now"
                elseif w == "you craft this" and change >= 0.15 and sells then r.tip = "Craft now"
                else r.tip = "Steady" end
                if n then
                    r.worth = n * now * 0.95
                    r.gain = n * (now - usual) * 0.95
                end
                if n or (w and math.abs(change) >= 0.10) then
                    if not (vendorBetter and not n) then rows[#rows + 1] = r end
                elseif not vendorBetter and math.abs(change) >= 0.30 and usual * (per or 0) >= 10000 then
                    r.why = "big mover"
                    if change <= -0.30 then r.tip = "Buy" end
                    movers[#movers + 1] = r
                end
            end
        end
    end
    local ORDER = { ["Sell now"] = 1, ["Farm now"] = 2, ["Craft now"] = 3, ["Stock up"] = 4, ["Buy"] = 5,
                    ["Hold"] = 6, ["Buy later"] = 7, ["Steady"] = 8, ["Vendor it"] = 9 }
    table.sort(rows, function(a, b)
        local oa, ob = ORDER[a.tip] or 9, ORDER[b.tip] or 9
        if oa ~= ob then return oa < ob end
        if (a.gain or 0) ~= (b.gain or 0) then return (a.gain or 0) > (b.gain or 0) end
        return math.abs(a.change) > math.abs(b.change)
    end)
    table.sort(movers, function(a, b) return math.abs(a.change) * a.usual * (a.per or 0) > math.abs(b.change) * b.usual * (b.per or 0) end)
    for i = 1, math.min(15, #movers) do rows[#rows + 1] = movers[i] end
    return rows
end

-- Which weekday is the AH cheapest / dearest? Averages every item's price relative to its own
-- average, so expensive items don't drown out cheap ones. Needs two weeks of scans.
function GP:WeekdayPattern()
    local days = 0
    for _ in pairs(self.db.scanDays or {}) do days = days + 1 end
    if days < 14 then return nil, 14 - days end
    local sum, cnt = { 0, 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0, 0, 0 }
    for id in pairs(self.db.history) do
        local h = self:History(id)
        if #h >= 10 then
            local mean = 0
            for _, e in ipairs(h) do mean = mean + e.p end
            mean = mean / #h
            if mean > 0 then
                for _, e in ipairs(h) do
                    local w = weekday(e.d)
                    sum[w], cnt[w] = sum[w] + e.p / mean, cnt[w] + 1
                end
            end
        end
    end
    local avg, lo, hi = {}, nil, nil
    for w = 1, 7 do
        avg[w] = cnt[w] > 0 and sum[w] / cnt[w] or nil
        if avg[w] then
            if not lo or avg[w] < avg[lo] then lo = w end
            if not hi or avg[w] > avg[hi] then hi = w end
        end
    end
    if not lo then return nil, 0 end
    if avg[hi] - avg[lo] < 0.05 then return { flat = true } end
    return { avg = avg, cheapest = GP.L[WEEKDAYS[lo]], dearest = GP.L[WEEKDAYS[hi]],
             spread = avg[hi] - avg[lo] }
end
