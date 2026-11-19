-- Haulwise: auction house scanning, prices and price history.
--
-- One full-AH snapshot (C_AuctionHouse.ReplicateItems, allowed every 15 minutes) gives, per item:
--   p  = price at the 10th percentile of all listed units (what you can realistically sell at;
--        one troll listing at 1c or one greedy listing at 99g doesn't move it)
--   m  = median unit price, q = units listed, c = the 5 cheapest listings ("unit:count/...")
--   s  = vendor sell price, k/sk = item class/subclass, n = name (recipes only, for matching)
-- Each scan also adds a day to a 28-day history (stored as a compact string per item), which
-- feeds deals, trends and weekday patterns. Auctionator fills gaps if installed.
-- Comparing a scan with the one before it shows which of the cheapest listings are gone: that's
-- how fast an item sells (see Sell speed below).
local _, GP = ...
local L = GP.L

local AH_CUT = 0.95
local THROTTLE = 15 * 60
local CHUNK = 2500
local HISTORY_DAYS = 28
local RECIPE_CLASS = 9

GP.ahOpen = false
local scanning = false

-- Items the game hasn't loaded yet come back without a name. Ask for them, remember names the AH
-- scan gave us, and redraw once the game has sent them.
local waitingNames = false
local function itemInfo(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, _, quality, _, _, _, _, _, _, icon, sellPrice, classID, subclassID, bindType = get(id)
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id); waitingNames = true end
        name = GP.db and GP.db.names and GP.db.names[id]
    end
    return name, quality, icon, sellPrice, bindType, classID, subclassID
end
GP.ItemInfo = itemInfo

function GP.ItemIcon(id)
    local get = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return (get and get(id)) or select(3, itemInfo(id)) or 134400
end

function GP.Day(t) return math.floor((t or time()) / 86400) end

-- History ---------------------------------------------------------------------------

local histCache = {}
function GP:History(id)
    local raw = self.db.history[id]
    if not raw then return {} end
    local c = histCache[id]
    if c and c.raw == raw then return c.list end
    local list = {}
    for d, p, q in raw:gmatch("(%d+):(%d+):(%d+)") do
        list[#list + 1] = { d = tonumber(d), p = tonumber(p), q = tonumber(q) }
    end
    histCache[id] = { raw = raw, list = list }
    return list
end

local function addHistory(db, id, day, p, q)
    local old = db.history[id] or ""
    local parts = {}
    for d, pp, qq in old:gmatch("(%d+):(%d+):(%d+)") do
        d = tonumber(d)
        if d ~= day and d > day - HISTORY_DAYS then parts[#parts + 1] = d .. ":" .. pp .. ":" .. qq end
    end
    parts[#parts + 1] = day .. ":" .. p .. ":" .. q
    db.history[id] = table.concat(parts, ",")
end

-- Saved data --------------------------------------------------------------------------------
-- Prices are saved as one short line per item ("p;q;m;t;k;sk;s;c;name") instead of a table,
-- which keeps the saved file about a third of the size, so logging in and /reload stay quick.
-- In the game they are ordinary tables again; packing happens only on logout and /reload.
local PACK = { "p", "q", "m", "t", "k", "sk", "s", "c" }

function GP.PackPrice(r)
    local out = {}
    for i, f in ipairs(PACK) do out[i] = r[f] ~= nil and tostring(r[f]) or "" end
    out[8] = (out[8]:gsub("%.00:", ":"):gsub("(%.%d)0:", "%1:")) -- "2000.00:1" -> "2000:1"
    out[#out + 1] = r.n or ""
    return table.concat(out, ";")
end

function GP.UnpackPrice(s)
    local parts = {}
    for v in (s .. ";"):gmatch("([^;]*);") do parts[#parts + 1] = v end
    local r = {}
    for i, f in ipairs(PACK) do
        local v = parts[i]
        if v and v ~= "" then r[f] = (f == "c") and v or tonumber(v) end
    end
    local n = table.concat(parts, ";", #PACK + 1)
    if n ~= "" then r.n = n end
    return r
end

function GP:UnpackSaved()
    local db = self.db
    if type(db.pricesPacked) == "table" then
        for id, s in pairs(db.pricesPacked) do
            if type(s) == "string" then db.prices[id] = GP.UnpackPrice(s) end
        end
    end
    db.pricesPacked = nil
    -- Tidy up: history older than we keep, empty entries, and names nothing refers to.
    local oldest = GP.Day() - HISTORY_DAYS
    for id, h in pairs(db.history) do
        local parts = {}
        for d, pp, qq in h:gmatch("(%d+):(%d+):(%d+)") do
            if tonumber(d) > oldest then parts[#parts + 1] = d .. ":" .. pp .. ":" .. qq end
        end
        db.history[id] = #parts > 0 and table.concat(parts, ",") or nil
    end
    for id, n in pairs(db.names) do
        if n == "" or not (db.prices[id] or db.history[id]) then db.names[id] = nil end
    end
    -- Sell speeds nobody has updated for two weeks are stale.
    for id, raw in pairs(db.speed or {}) do
        local d = tonumber(raw:match(":(%d+)$"))
        if not d or d < GP.Day() - 14 then db.speed[id] = nil end
    end
end

function GP:PackSaved()
    local db = self.db
    if not db or not db.prices then return end
    local ok, packed = pcall(function()
        local out = {}
        for id, r in pairs(db.prices) do out[id] = GP.PackPrice(r) end
        return out
    end)
    if ok then db.pricesPacked, db.prices = packed, {} end
end
GP:On("PLAYER_LOGOUT", function() GP:PackSaved() end)

local function median(t)
    if #t == 0 then return nil end
    table.sort(t)
    local n = #t
    if n % 2 == 1 then return t[(n + 1) / 2] end
    return (t[n / 2] + t[n / 2 + 1]) / 2
end
GP.Median = median

-- Market value: median of the daily prices over the last 14 days when we have 3+ days,
-- otherwise the median listing of the latest scan. Returns value, days of history.
function GP:MarketValue(id)
    local h = self:History(id)
    local today, vals = GP.Day(), {}
    for _, e in ipairs(h) do if e.d > today - 14 then vals[#vals + 1] = e.p end end
    if #vals >= 3 then return median(vals), #vals end
    local cur = self.db.prices[id]
    if cur then return cur.m or cur.p, #vals end
    return nil, 0
end

-- Sell speed -----------------------------------------------------------------------------
-- Buyers take the cheapest listings first. So when one of the five cheapest listings from the
-- last scan is gone in this one, it most likely sold. Added up over the last 7 days of scans,
-- that gives the units sold per day. It's an estimate: a cancelled or expired listing looks the
-- same, which is why only scans up to 36 hours apart are compared.
local SPEED_WINDOW, SPEED_MAX_GAP = 7, 1.5

local function listingKey(u, c) return string.format("%.2f:%d", u, c) end

-- old = prices from the previous scan (taken at oldT); lists = this scan's listings per item,
-- cheapest first, as { unit price, count }; t = this scan's time.
function GP:UpdateSellSpeed(old, oldT, lists, t)
    local gap = oldT and oldT > 0 and (t - oldT) / 86400
    if not gap or gap <= 0 or gap > SPEED_MAX_GAP then return end
    local db, day = self.db, GP.Day(t)
    db.speed = db.speed or {}
    for id, o in pairs(old) do
        if o.c and o.c ~= "" then
            local was, top = {}, 0
            for u, c in o.c:gmatch("([%d%.]+):(%d+)") do
                u, c = tonumber(u), tonumber(c)
                was[#was + 1] = { u, c }
                if u > top then top = u end
            end
            local still = {}
            for _, l in ipairs(lists[id] or {}) do
                if l[1] > top + 0.005 then break end
                local k = listingKey(l[1], l[2])
                still[k] = (still[k] or 0) + 1
            end
            local sold = 0
            for _, w in ipairs(was) do
                local k = listingKey(w[1], w[2])
                if (still[k] or 0) > 0 then still[k] = still[k] - 1 else sold = sold + w[2] end
            end
            local s, d = 0, 0
            local raw = db.speed[id]
            if raw then
                local a, b = raw:match("^([%d%.]+):([%d%.]+)")
                s, d = tonumber(a) or 0, tonumber(b) or 0
            end
            s, d = s + sold, d + gap
            if d > SPEED_WINDOW then s, d = s * SPEED_WINDOW / d, SPEED_WINDOW end
            db.speed[id] = string.format("%.1f:%.2f:%d", s, d, day)
        end
    end
end

-- Units sold per day, days of scans it's based on, and "fast" | "steady" | "slow" | "none".
-- Nil until scans cover at least half a day.
function GP:SellSpeed(id)
    local raw = self.db.speed and self.db.speed[id]
    if not raw then return nil end
    local s, d = raw:match("^([%d%.]+):([%d%.]+)")
    s, d = tonumber(s), tonumber(d)
    if not (s and d) or d < 0.5 then return nil, d end
    local per = s / d
    local label = per >= 10 and "fast" or per >= 1 and "steady" or per > 0 and "slow" or "none"
    return per, d, label
end

local SPEED_COLOR = { fast = "|cff5fd35f", steady = "|cffffffff", slow = "|cffffd060", none = "|cffff9944" }
-- "sells ~12 a day", "sells ~1 every 4 days", "no sales seen in 3 days"; coloured by speed.
function GP:SellSpeedText(id, plain)
    local per, days, label = self:SellSpeed(id)
    if not per then return nil end
    local text
    if label == "none" then
        text = string.format(L["no sales seen in %s"], GP.Plural(math.max(1, math.floor(days + 0.5)), "day", "days"))
    elseif per >= 1 then
        text = string.format(L["sells ~%d a day"], math.floor(per + 0.5))
    else
        text = string.format(L["sells ~1 every %s"], GP.Plural(math.max(2, math.floor(1 / per + 0.5)), "day", "days"))
    end
    if plain then return text, label end
    return SPEED_COLOR[label] .. text .. "|r", label
end

-- Current price ------------------------------------------------------------------------

-- Returns unit price (copper), units listed (or nil), age in seconds, source label.
-- Price of one unit: price, units listed, age in seconds, where it's from ("scan", "realm",
-- "Auctionator" or "all"). Your own scan wins while it's at most 3 days old; then prices other
-- players shared for your realm (when fresher), your older scan, Auctionator, and last the median
-- over all realms (see SharedPrices.lua).
local OWN_FRESH = 3 * 86400
function GP:Price(id)
    local p = self.db.prices[id]
    local ownAge = p and p.p and (time() - (p.t or 0))
    if ownAge and ownAge <= OWN_FRESH then return p.p, p.q, ownAge, "scan" end
    local sp, sAge, kind = nil, nil, nil
    if self.SharedPrice then sp, sAge, kind = self:SharedPrice(id, false) end
    if sp and (not ownAge or sAge < ownAge) then return sp, nil, sAge, kind end
    if ownAge then return p.p, p.q, ownAge, "scan" end
    if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "Haulwise", id)
        if ok and price and price > 0 then
            local age
            if Auctionator.API.v1.GetAuctionAgeByItemID then
                local ok2, days = pcall(Auctionator.API.v1.GetAuctionAgeByItemID, "Haulwise", id)
                if ok2 and days then age = days * 86400 end
            end
            return price, nil, age, "Auctionator"
        end
    end
    if self.SharedPrice then
        local ap, aAge, aKind = self:SharedPrice(id)
        if ap then return ap, nil, aAge, aKind end
    end
    return nil
end

function GP:VendorSell(id)
    local p = self.db.prices[id]
    if p and p.s then return p.s end
    local _, _, _, sell = itemInfo(id)
    return sell or 0
end

-- What one unit is worth to you when SELLING: AH price after the 5% cut, or the vendor price,
-- whichever is higher. Bind-on-pickup items can only be vendored.
function GP:ItemValue(id)
    local _, _, _, sellPrice, bindType = itemInfo(id)
    local vendor = sellPrice or self:VendorSell(id)
    if bindType == 1 then return vendor, nil, vendor end
    local price, listed = self:Price(id)
    local ah = price and price * AH_CUT or nil
    return math.max(ah or 0, vendor), ah, vendor, listed
end

-- What one unit COSTS you to get: cheapest of a vendor that sells it and the AH.
function GP:BuyCost(id)
    local v = self.db.vendorBuy[id]
    if not v and self.SharedSources then
        for _, src in ipairs(self:SharedSources()) do
            if src.vendorBuy and src.vendorBuy[id] then v = src.vendorBuy[id]; break end
        end
    end
    local ah = self:Price(id)
    if v and ah then return math.min(v, ah), (v <= ah) and "vendor" or "AH" end
    if v then return v, "vendor" end
    if ah then return ah, "AH" end
    return nil
end

function GP:Cheapest(id)
    local p = self.db.prices[id]
    local out = {}
    if p and p.c then
        for u, c in p.c:gmatch("([%d%.]+):(%d+)") do out[#out + 1] = { u = tonumber(u), c = tonumber(c) } end
    end
    return out
end

-- Full scan ------------------------------------------------------------------------

-- What the scan button's tooltip says while a scan runs: nil when no scan is running.
function GP:ScanStatus()
    if scanning == true then
        return L["Waiting for the auction house to send every listing. This can take up to a minute; you can keep playing."]
    elseif scanning then
        return string.format(L["Reading the listings: %d%% done. Gear upgrades and deals update when it's finished."], math.floor((self.scanProgress or 0) * 100))
    end
end

function GP:CanScan()
    if not (C_AuctionHouse and C_AuctionHouse.ReplicateItems) then return false, L["no AH API"] end
    if not self.ahOpen then return false, L["open the auction house first"] end
    if scanning then return false, L["scanning..."] end
    local wait = THROTTLE - (time() - (self.db.priceScanTime or 0))
    if wait > 0 then return false, string.format(L["next scan in %d min"], math.ceil(wait / 60)) end
    return true
end

-- Gear listings (one link per listing) for the AH upgrade finder in Gear.lua.
local GEAR_CLASS = { [2] = true, [4] = true }
local MAX_GEAR = 30000

local function finish(lists, names, gear)
    local db = GP.db
    local prices, t, day = {}, time(), GP.Day()
    local n = 0
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    for id, list in pairs(lists) do
        table.sort(list, function(a, b) return a[1] < b[1] end)
        local total = 0
        for i = 1, #list do total = total + list[i][2] end
        local function at(frac)
            local target, run = math.max(1, total * frac), 0
            for i = 1, #list do
                run = run + list[i][2]
                if run >= target then return list[i][1] end
            end
            return list[#list][1]
        end
        local cheap = {}
        for i = 1, math.min(5, #list) do
            local u = list[i][1]
            u = (u == math.floor(u)) and string.format("%d", u) or (string.format("%.2f", u):gsub("0+$", ""))
            cheap[#cheap + 1] = u .. ":" .. list[i][2]
        end
        local rec = { p = math.floor(at(0.10) + 0.5), m = math.floor(at(0.50) + 0.5), q = total, t = t,
                      c = table.concat(cheap, "/") }
        local _, _, _, sell = itemInfo(id)
        if sell and sell > 0 then rec.s = sell end
        if instant then
            local _, _, _, _, _, classID, subclassID = instant(id)
            rec.k, rec.sk = classID, subclassID
            if classID == RECIPE_CLASS then rec.n = names[id] or itemInfo(id) end
        end
        prices[id] = rec
        if names[id] then db.names[id] = names[id] end
        addHistory(db, id, day, rec.p, total)
        n = n + 1
    end
    pcall(GP.UpdateSellSpeed, GP, db.prices, db.priceScanTime, lists, t)
    db.prices = prices
    db.priceScanTime = t
    if GP.NoteScanRealm then GP:NoteScanRealm(t) end
    db.scanDays = db.scanDays or {}
    db.scanDays[day] = true
    scanning = false
    GP.Print(string.format(L["Prices updated for %d items."], n))
    if gear and GP.FindAHUpgrades then GP:FindAHUpgrades(gear) end
    if GP.OnScanFinished then GP:OnScanFinished() end
    if GP.RefreshUI then GP:RefreshUI() end
end

local function fail(why)
    scanning = false
    GP.scanProgress = nil
    GP.Print(L["Scan stopped: "] .. tostring(why) .. L[". Nothing was saved; try again."])
    if GP.RefreshUI then GP:RefreshUI() end
end

local function process()
    local total = C_AuctionHouse.GetNumReplicateItems() or 0
    if total == 0 then return fail(L["the auction house sent an empty list"]) end
    local lists, names, i = {}, {}, 0
    local gear, nGear = {}, 0
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local getLink = C_AuctionHouse.GetReplicateItemLink
    local function rows()
        local stop = math.min(total - 1, i + CHUNK - 1)
        for idx = i, stop do
            local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID =
                C_AuctionHouse.GetReplicateItemInfo(idx)
            if itemID and buyout and buyout > 0 and count and count > 0 then
                local l = lists[itemID]
                if not l then l = {}; lists[itemID] = l end
                l[#l + 1] = { buyout / count, count }
                if name and name ~= "" then names[itemID] = name end
                if count == 1 and nGear < MAX_GEAR and getLink and instant then
                    local _, _, _, equipLoc, _, classID = instant(itemID)
                    if GEAR_CLASS[classID] and equipLoc and equipLoc ~= "" then
                        local ok, link = pcall(getLink, idx)
                        if ok and link then
                            local old = gear[link]
                            if not old then nGear = nGear + 1 end
                            if not old or buyout < old.price then gear[link] = { id = itemID, price = buyout } end
                        end
                    end
                end
            end
        end
        i = stop + 1
    end
    -- Each chunk runs in a pcall: one bad row must not leave the scan stuck at "scanning...".
    local function step()
        if not scanning then return end
        local ok, err = pcall(rows)
        if not ok then return fail(err) end
        GP.scanProgress = i / total
        if i < total then
            if GP.RefreshScanButton then GP:RefreshScanButton() end
            C_Timer.After(0, step)
        else
            GP.scanProgress = nil
            local ok2, err2 = pcall(finish, lists, names, gear)
            if not ok2 then fail(err2) end
        end
    end
    step()
end

function GP:ScanAH()
    local ok, why = self:CanScan()
    if not ok then
        local status = self:ScanStatus()
        self.Print(status and (L["Already scanning. "] .. status) or (L["Can't scan: "] .. why .. "."))
        return
    end
    scanning = true
    self.scanProgress = 0
    self.Print(L["Scanning the auction house..."])
    C_AuctionHouse.ReplicateItems()
    -- If the auction house never answers, don't stay stuck: give up after a minute.
    local started = GetTime()
    C_Timer.After(60, function()
        if scanning == true and GetTime() - started >= 59 then
            fail(L["no answer from the auction house within a minute (it allows one full scan every 15 minutes)"])
        end
    end)
    if self.RefreshUI then self:RefreshUI() end
end

-- Put an item in the AH search box (called from a click, so it's a hardware event).
function GP:SearchAH(id)
    local name = itemInfo(id)
    if not name then return end
    if not self.ahOpen then self.Print(L["Open the auction house, then click again: "] .. name); return end
    local bar = AuctionHouseFrame and AuctionHouseFrame.SearchBar
    if bar and bar.SearchBox then
        pcall(function()
            bar.SearchBox:SetText(name)
            if bar.StartSearch then bar:StartSearch() end
        end)
    end
end

GP:On("GET_ITEM_INFO_RECEIVED", function()
    if not waitingNames then return end
    waitingNames = false
    C_Timer.After(0.5, function() if GP.RefreshUI then GP:RefreshUI() end end)
end)

GP:On("AUCTION_HOUSE_SHOW", function() GP.ahOpen = true; if GP.RefreshUI then GP:RefreshUI() end end)
GP:On("AUCTION_HOUSE_CLOSED", function()
    GP.ahOpen = false
    if scanning == true then fail(L["the auction house was closed before it answered"]) end
    if GP.RefreshUI then GP:RefreshUI() end
end)
GP:On("REPLICATE_ITEM_LIST_UPDATE", function()
    -- The event can fire more than once per scan; only process the first.
    if scanning == true then scanning = "processing"; process() end
end)

-- Vendors: remember what they sell reagents for (thread, salt, vials...).
GP:On("MERCHANT_SHOW", function()
    local n = GetMerchantNumItems and GetMerchantNumItems() or 0
    for i = 1, n do
        local id = GetMerchantItemID and GetMerchantItemID(i)
        local price, qty
        if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
            local info = C_MerchantFrame.GetItemInfo(i)
            if info then price, qty = info.price, info.stackCount end
        elseif GetMerchantItemInfo then
            local _, _, p, q = GetMerchantItemInfo(i)
            price, qty = p, q
        end
        if id and price and price > 0 and (qty or 0) > 0 then
            GP.db.vendorBuy[id] = price / qty
        end
    end
end)

GP._test = GP._test or {}
GP._test.finishPrices = function(lists, gear) finish(lists, {}, gear) end
