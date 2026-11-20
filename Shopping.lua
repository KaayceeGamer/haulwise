-- Haulwise: shopping list for crafting. Pick crafts in the Craft tab (click a row), set how many,
-- and see every reagent you need, what you already have (bags + bank, and on your alts), what's
-- left to buy and where it's cheapest.
--
-- Buying at the AH: a reagent's Buy button searches for it, then shows what the amount you need
-- costs right now; the next click asks you to confirm (with the total, and a warning if it's dear)
-- and buys exactly that many at the cheapest prices. Every purchase is your own click in the
-- confirm box: Haulwise never buys by itself. Vendor reagents get a waypoint to a vendor instead.
local _, GP = ...
local L = GP.L

local W = 520
local panel
local recipeRows, reagentRows = {}, {}

local function list() local c = GP:Char(); c.shopping = c.shopping or {}; return c.shopping end

local function countHere(id)
    local get = (C_Item and C_Item.GetItemCount) or GetItemCount
    local ok, n = pcall(get, id, true)
    return ok and n or 0
end

-- On your alts (same realm and faction): total, and { { name, n } } most first.
local function countOnAlts(id)
    local n, who = 0, {}
    for _, c in ipairs(GP:Alts()) do
        local m = 0
        for _, loc in ipairs({ "bags", "bank", "mail" }) do m = m + ((c[loc] and c[loc][id]) or 0) end
        if m > 0 then n = n + m; who[#who + 1] = { name = c.short or c.key or "?", n = m } end
    end
    table.sort(who, function(a, b) return a.n > b.n end)
    return n, who
end

function GP:AddToShopping(key, n)
    local l = list()
    if not self:Char().recipes[key] then return end
    l[key] = math.max(0, (l[key] or 0) + (n or 1))
    if l[key] == 0 then l[key] = nil end
    self:ShowShopping()
    if GP.RefreshCraftQueue then GP.RefreshCraftQueue() end
end

-- Everything the list needs: per reagent { id, need, have, alts, buy, unit, where, cost }.
function GP:ShoppingTotals()
    local need, crafts, sell, anyAH = {}, {}, 0, false
    for key, qty in pairs(list()) do
        local rec = self:Char().recipes[key]
        if rec then
            crafts[#crafts + 1] = { key = key, rec = rec, qty = qty }
            for _, r in ipairs(GP.UnpackReagents(rec.r)) do need[r[1]] = (need[r[1]] or 0) + r[2] * qty end
            local value, ah = self:ItemValue(rec.out)
            if ah and ah > 0 then anyAH = true end
            sell = sell + (value or 0) * (rec.oq or 1) * qty
        else
            list()[key] = nil
        end
    end
    table.sort(crafts, function(a, b) return (a.rec.n or "") < (b.rec.n or "") end)
    -- total: what you still have to buy. used: what all the reagents are worth, also the ones you
    -- already have (you could sell those instead), so the profit matches the Craft tab.
    local reagents, total, unpriced, used = {}, 0, 0, 0
    for id, n in pairs(need) do
        local have = countHere(id)
        local buy = math.max(0, math.ceil(n - have))
        local unit, where = self:BuyCost(id)
        local cost = unit and unit * buy or nil
        if cost then total = total + cost elseif buy > 0 then unpriced = unpriced + 1 end
        if unit then used = used + unit * n end
        local alts, altList = countOnAlts(id)
        -- Dear today: the AH price is 30%+ over its usual price (two weeks of scans).
        local usual = where == "AH" and self.MarketValue and self:MarketValue(id) or nil
        local dear = usual and unit and usual > 0 and unit > usual * 1.3 or false
        reagents[#reagents + 1] = { id = id, need = n, have = have, alts = alts, altList = altList, buy = buy, unit = unit,
                                    where = where, cost = cost, usual = usual, dear = dear }
    end
    table.sort(reagents, function(a, b)
        if (a.buy > 0) ~= (b.buy > 0) then return a.buy > 0 end
        return (a.cost or 0) > (b.cost or 0)
    end)
    return crafts, reagents, total, sell, unpriced, used, anyAH
end

-- Buying at the AH -----------------------------------------------------------------------------

local buying -- { id, qty, stage = "search" | "ready" | "confirm", commodity, total, auctionID, buyout, got }

local function reagentName(id) return GP.ItemInfo(id) or ("item " .. id) end

function GP:ShopBuyState(id) return buying and buying.id == id and buying or nil end

-- Step 1: ask the AH for the item's listings.
function GP:ShopSearch(id, qty)
    if not self.ahOpen or not (C_AuctionHouse and C_AuctionHouse.SendSearchQuery) then
        self.Print(L["Open the auction house, then press Buy again."])
        return
    end
    local okK, key = pcall(C_AuctionHouse.MakeItemKey, id)
    if not okK or not key then return end
    buying = { id = id, qty = qty, key = key, stage = "search" }
    local order = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
    pcall(C_AuctionHouse.SendSearchQuery, key, { { sortOrder = order, reverseSort = false } }, true)
    self:RefreshShopping()
end

-- Step 2: the listings are in. Work out what the amount you need costs, cheapest first.
local function readCommodity(id)
    local b = buying
    local okN, n = pcall(C_AuctionHouse.GetNumCommoditySearchResults, id)
    local left, total = b.qty, 0
    for i = 1, (okN and n) or 0 do
        local ok, r = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, id, i)
        if ok and r and r.unitPrice then
            local avail = (r.quantity or 0) - ((r.containsOwnerItem and r.numOwnerItems) or 0)
            local take = math.min(left, math.max(0, avail))
            total, left = total + take * r.unitPrice, left - take
            if left <= 0 then break end
        end
    end
    b.commodity, b.got, b.total = true, b.qty - left, total
    b.stage = b.got > 0 and "ready" or "none"
end

local function readItem(key)
    local b = buying
    local okN, n = pcall(C_AuctionHouse.GetNumItemSearchResults, key)
    local best
    for i = 1, (okN and n) or 0 do
        local ok, r = pcall(C_AuctionHouse.GetItemSearchResultInfo, key, i)
        if ok and r and r.buyoutAmount and r.auctionID and not r.containsOwnerItem then
            local q = math.max(1, r.quantity or 1)
            local u = r.buyoutAmount / q
            -- The cheapest per unit among listings no bigger than what you still need.
            if q <= b.qty and (not best or u < best.u) then best = { u = u, r = r, q = q } end
        end
    end
    b.commodity = false
    if best then
        b.auctionID, b.buyout, b.got, b.total, b.stage = best.r.auctionID, best.r.buyoutAmount, best.q, best.r.buyoutAmount, "ready"
    else
        b.stage = "none"
    end
end

GP:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
    if buying and buying.stage == "search" and itemID == buying.id then readCommodity(itemID); GP:RefreshShopping() end
end)
GP:On("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey)
    if buying and buying.stage == "search" and itemKey and itemKey.itemID == buying.id then readItem(buying.key); GP:RefreshShopping() end
end)

-- Step 3: your click, then the confirm box. Its Buy button does the purchase.
StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["HAULWISE_BUY"] = {
    text = "%s", button1 = L["Buy"], button2 = CANCEL or "Cancel",
    OnAccept = function(_, data) if data and data.go then data.go() end end,
    OnCancel = function(_, data) if data and data.cancel then data.cancel() end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function confirmText(b, expected)
    local text = string.format(L["Buy %d %s for %s?"], b.got, reagentName(b.id), GP.Coins(b.total))
    if b.got < b.qty then text = text .. "\n" .. string.format(L["Only %d listed: you need %d."], b.got, b.qty) end
    if expected and expected > 0 and b.total > expected * 1.3 then
        text = text .. "\n|cffff6b5b" .. string.format(L["That's %d%% over the usual price (%s each)."],
            math.floor((b.total / expected - 1) * 100 + 0.5), GP.Coins(expected / b.got)) .. "|r"
    end
    return text
end

function GP:ShopBuy(g)
    local b = buying
    if not (b and b.id == g.id and b.stage == "ready") then return self:ShopSearch(g.id, g.buy) end
    local expected = g.usual and g.usual * b.got or nil
    if b.commodity then
        b.stage = "confirm"
        if not pcall(C_AuctionHouse.StartCommoditiesPurchase, b.id, b.got) then
            buying = nil
            self.Print(L["Couldn't start the purchase. Use the auction house's own Buy button."])
            return self:RefreshShopping()
        end
        -- The price is confirmed by COMMODITY_PRICE_UPDATED below, then the box opens.
        b.expected = expected
    else
        b.stage = "confirm"
        StaticPopup_Show("HAULWISE_BUY", confirmText(b, expected), nil, {
            go = function()
                local ok = pcall(C_AuctionHouse.PlaceBid, b.auctionID, b.buyout)
                if not ok then GP.Print(L["Couldn't buy it. Use the auction house's own Buy button."]) end
                buying = nil
                GP:RefreshShopping()
            end,
            cancel = function() buying = nil; GP:RefreshShopping() end,
        })
    end
    self:RefreshShopping()
end

GP:On("COMMODITY_PRICE_UPDATED", function(unitPrice, totalPrice)
    local b = buying
    if not (b and b.commodity and b.stage == "confirm") then return end
    b.total = totalPrice or b.total
    StaticPopup_Show("HAULWISE_BUY", confirmText(b, b.expected), nil, {
        go = function()
            local ok = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, b.id, b.got)
            if not ok then GP.Print(L["Couldn't buy it. Use the auction house's own Buy button."]) end
            buying = nil
            GP:RefreshShopping()
        end,
        cancel = function()
            pcall(C_AuctionHouse.CancelCommoditiesPurchase)
            buying = nil
            GP:RefreshShopping()
        end,
    })
end)
GP:On("COMMODITY_PRICE_UNAVAILABLE", function()
    if buying and buying.stage == "confirm" then
        buying = nil
        GP.Print(L["The price changed before you bought. Press Buy again."])
        GP:RefreshShopping()
    end
end)
GP:On("AUCTION_HOUSE_CLOSED", function() buying = nil end)

-- Vendor reagents: an arrow to the nearest vendor that sells it (Haulwise Data), if one is known.
function GP:GoToVendorFor(id)
    local s = HaulwiseData and HaulwiseData.sources and HaulwiseData.sources[id]
    local ids = s and s[1] or {}
    local place = #ids > 0 and self.NearestPlace and self:NearestPlace(ids)
    if place and self.Waypoint then return self:Waypoint(place, string.format(L["(sells %s)"], reagentName(id))) end
    return false
end

local function smallButton(parent, text, w)
    local b = GP.FlatButton(parent, text, w or 20, 18)
    return b
end

local function build()
    panel = GP.Panel("HaulwiseShopping", W, 200, L["Shopping list"])
    panel:RestorePosition({ "CENTER", UIParent, "CENTER", 320, 0 })
    panel.cropsHead = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    panel.cropsHead:SetPoint("TOPLEFT", 12, -34)
    panel.cropsHead:SetText(L["Crafts  (click a recipe in the Craft tab to add it)"])
    panel.reagHead = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    panel.total = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    panel.total:SetPoint("BOTTOMLEFT", 12, 14)
    panel.total:SetPoint("RIGHT", -100, 0)
    panel.total:SetJustifyH("LEFT")
    panel.clear = GP.FlatButton(panel, L["Clear"], 70, 20)
    panel.clear:SetPoint("BOTTOMRIGHT", -12, 10)
    panel.clear:SetScript("OnClick", function() GP:Char().shopping = {}; GP:ShowShopping() end)
    panel:SetScript("OnShow", function() GP:RefreshShopping() end)
end

function GP:RefreshShopping()
    if not panel or not panel:IsShown() then return end
    local crafts, reagents, total, sell, unpriced, used, anyAH = self:ShoppingTotals()
    for _, r in ipairs(recipeRows) do r:Hide() end
    for _, r in ipairs(reagentRows) do r:Hide(); if r.buyBtn then r.buyBtn:Hide() end end
    local y = -52
    if #crafts == 0 then
        panel.cropsHead:SetText(L["Empty. Click a recipe in the Craft tab to add it."])
    else
        panel.cropsHead:SetText(L["Crafts"])
    end
    for i, c in ipairs(crafts) do
        local row = recipeRows[i]
        if not row then
            row = GP.ItemRow(panel, W - 110)
            row.minus = smallButton(panel, "-")
            row.plus = smallButton(panel, "+")
            row.five = smallButton(panel, "+5", 28)
            row.del = smallButton(panel, "x")
            row.minus:SetPoint("LEFT", row, "RIGHT", 4, 0)
            row.plus:SetPoint("LEFT", row.minus, "RIGHT", 2, 0)
            row.five:SetPoint("LEFT", row.plus, "RIGHT", 2, 0)
            row.del:SetPoint("LEFT", row.five, "RIGHT", 6, 0)
            recipeRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 12, y)
        row:SetItem(c.rec.out, nil, "|cffffffff×" .. c.qty .. "|r")
        row.link = nil
        row.tip = function(t) t:SetItemByID(c.rec.out) end
        row.minus:SetScript("OnClick", function() GP:AddToShopping(c.key, -1) end)
        row.plus:SetScript("OnClick", function() GP:AddToShopping(c.key, 1) end)
        row.five:SetScript("OnClick", function() GP:AddToShopping(c.key, 5) end)
        row.del:SetScript("OnClick", function() list()[c.key] = nil; GP:ShowShopping() end)
        for _, b in ipairs({ row, row.minus, row.plus, row.five, row.del }) do b:Show() end
        y = y - 24
    end
    y = y - 8
    panel.reagHead:ClearAllPoints()
    panel.reagHead:SetPoint("TOPLEFT", 12, y)
    panel.reagHead:SetText(#reagents > 0 and L["Reagents:  need · have (bags+bank) · to buy · cheapest"] or "")
    y = y - 18
    for i, g in ipairs(reagents) do
        local row = reagentRows[i]
        if not row then
            row = GP.ItemRow(panel, W - 24 - 70)
            row.buyBtn = GP.FlatButton(panel, L["Buy"], 66, 18)
            row.buyBtn:SetPoint("LEFT", row, "RIGHT", 4, 0)
            reagentRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 12, y)
        local buyText
        if g.buy == 0 then
            buyText = L["|cff5fd35fhave all|r"]
        elseif g.cost then
            buyText = string.format(L["buy |cffffffff%d|r  %s %s"], g.buy, GP.Coins(g.cost, true),
                g.where == "vendor" and L["|cff88ccffvendor|r"] or L["|cffffd040AH|r"])
            if g.dear then buyText = buyText .. " " .. L["|cffff9944dear|r"] end
        else
            buyText = string.format(L["buy |cffffffff%d|r  |cffff9944no price|r"], g.buy)
        end
        if g.buy > 0 and g.alts > 0 then
            buyText = buyText .. " " .. string.format(L["|cffff9944%s has %d|r"], g.altList[1].name, g.altList[1].n)
        end
        row:SetItem(g.id, nil, string.format("|cff8a8880%g · %d ·|r %s", g.need, g.have, buyText))
        -- The Buy button: search, then buy at the AH; a waypoint for vendor reagents.
        local b = GP:ShopBuyState(g.id)
        local btn = row.buyBtn
        if g.buy == 0 then
            btn:Hide()
        elseif g.where == "vendor" then
            btn:SetLabel(L["Vendor"])
            btn:SetScript("OnClick", function()
                if not GP:GoToVendorFor(g.id) then
                    GP.Print(string.format(L["Buy %d %s from a vendor (%s each)."], g.buy, GP.ItemInfo(g.id) or "?", GP.Coins(g.unit or 0)))
                end
            end)
            btn:Show()
        else
            if b and b.stage == "search" then btn:SetLabel(L["Looking..."])
            elseif b and b.stage == "ready" then btn:SetLabel(GP.Coins(b.total, true))
            elseif b and b.stage == "none" then btn:SetLabel(L["None listed"])
            elseif b and b.stage == "confirm" then btn:SetLabel(L["Confirm..."])
            else btn:SetLabel(L["Buy"]) end
            btn:SetScript("OnClick", function() GP:ShopBuy(g) end)
            btn:Show()
        end
        row.link = nil
        row.tip = function(t)
            t:SetItemByID(g.id)
            t:AddLine(" ")
            t:AddDoubleLine(L["Need"], tostring(g.need), 0.7, 0.7, 0.7, 1, 1, 1)
            t:AddDoubleLine(L["You have (bags + bank)"], tostring(g.have), 0.7, 0.7, 0.7, 1, 1, 1)
            for _, a in ipairs(g.altList or {}) do t:AddDoubleLine(string.format(L["On %s"], a.name), tostring(a.n), 0.7, 0.7, 0.7, 1, 0.6, 0.27) end
            if g.alts > 0 and g.buy > 0 then t:AddLine(L["Send it over by mail before you buy more."], 1, 0.6, 0.27, true) end
            if g.unit then t:AddDoubleLine(L["Cheapest"], GP.Coins(g.unit) .. L[" each at "] .. (g.where == "vendor" and L["a vendor"] or L["the AH"]), 0.7, 0.7, 0.7, 1, 1, 1) end
            if g.usual then t:AddDoubleLine(L["Usual price"], GP.Coins(g.usual), 0.7, 0.7, 0.7, g.dear and 1 or 1, g.dear and 0.6 or 1, g.dear and 0.27 or 1) end
            if g.dear then t:AddLine(L["Dear today: 30% or more over the usual price. Wait a day if it isn't urgent."], 1, 0.6, 0.27, true) end
            t:AddLine(g.where == "vendor" and L["Vendor: an arrow to the nearest vendor that sells it."] or L["Buy: finds the cheapest listings, then asks you to confirm the total."], 0.6, 0.6, 0.6, true)
            t:AddLine(L["Click the name: search the AH."], 0.6, 0.6, 0.6)
        end
        row:SetScript("OnClick", function() GP:SearchAH(g.id) end)
        row:Show()
        y = y - 22
    end
    local profit = sell - (used or total)
    local text
    if anyAH then
        text = string.format(L["To buy: |cffffffff%s|r   ·   Results sell for %s   ·   %s"], GP.Coins(total, true), GP.Coins(sell, true),
            (profit >= 0 and L["|cff5fd35fprofit "] or L["|cffff6b5bloss "]) .. GP.Coins(math.abs(profit), true) .. "|r")
    else
        -- Tools and skill-ups: nobody sells them on the AH, so profit or loss means nothing.
        text = string.format(L["To buy: |cffffffff%s|r   ·   All reagents: %s   ·   |cff8a8880for use or skill-up, not for sale|r"],
            GP.Coins(total, true), GP.Coins(used or total, true))
    end
    if unpriced > 0 then text = text .. string.format(L["   |cffff9944(%d without price)|r"], unpriced) end
    panel.total:SetText(#crafts > 0 and text or "")
    panel:SetHeight(math.max(120, -y + 44))
end

function GP:ShowShopping()
    if not panel then build() end
    panel:Show()
    self:RefreshShopping()
end

function GP:ToggleShopping()
    if panel and panel:IsShown() then panel:Hide() else self:ShowShopping() end
end

GP:On("BAG_UPDATE_DELAYED", function() if panel and panel:IsShown() then GP:RefreshShopping() end end)
GP:On("AUCTION_HOUSE_SHOW", function() if next(list()) then C_Timer.After(0.3, function() GP:ShowShopping() end) end end)
