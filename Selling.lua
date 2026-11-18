-- Haulwise: selling help at the auction house. When you put an item in Blizzard's sell frame, a
-- small panel suggests a price from the live listings and your scans, and warns when a vendor
-- would pay more. "Use price" only fills in the price box: you still press Post yourself.
local _, GP = ...
local L = GP.L

local AH_CUT = 0.95
local LOWBALL = 0.8   -- a few listings under 80% of the market price are a bargain, not the market
local panel, current

local function getItemID(loc)
    if not loc then return nil end
    local ok, id = pcall(function() return C_Item.GetItemID(loc) end)
    return ok and id or nil
end

-- The live listings, cheapest first (up to 30), if Blizzard's sell frame search has come back.
local function liveListings(id, loc, commodity)
    local out = {}
    if not C_AuctionHouse then return out end
    if commodity then
        local okN, n = pcall(C_AuctionHouse.GetNumCommoditySearchResults, id)
        for i = 1, math.min(30, (okN and n) or 1) do
            local ok, info = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, id, i)
            if not (ok and info and info.unitPrice) then break end
            out[#out + 1] = { u = info.unitPrice, c = info.quantity or 1 }
        end
    else
        local ok, key = pcall(C_AuctionHouse.GetItemKeyFromItem, loc)
        if ok and key then
            local okN, n = pcall(C_AuctionHouse.GetNumItemSearchResults, key)
            for i = 1, math.min(30, (okN and n) or 1) do
                local ok2, info = pcall(C_AuctionHouse.GetItemSearchResultInfo, key, i)
                if not (ok2 and info and info.buyoutAmount) then break end
                local q = info.quantity or 1
                out[#out + 1] = { u = info.buyoutAmount / math.max(1, q), c = q }
            end
        end
    end
    return out
end

-- Where the market really is: the price at which a handful of units are listed. A few cheap
-- ones under that are someone's bargain (or mistake); undercutting them throws gold away.
local function marketWall(list, need)
    local run = 0
    for _, l in ipairs(list) do
        run = run + (l.c or 1)
        if run >= need then return l.u end
    end
    return list[#list] and list[#list].u
end

-- The suggestion: 1 copper under the market (the cheapest listing, unless only a few units sit
-- far below the rest), and never below what a vendor pays after the AH cut.
function GP:SellAdvice(id, loc, commodity)
    local usual = self:MarketValue(id)
    local list = liveListings(id, loc, commodity)
    if #list == 0 then list = self:Cheapest(id) end
    local cheapest = list[1] and list[1].u
    local vendor = self:VendorSell(id) or 0
    local price, why
    if cheapest then
        local wall = marketWall(list, commodity and 10 or 3) or cheapest
        if cheapest < wall * LOWBALL then
            price, why = wall - 1, L["a few cheap listings sit far below the rest; this undercuts the main market"]
        else
            price, why = cheapest - 1, L["1 copper under the cheapest listing"]
        end
    elseif usual then
        price, why = usual, L["nobody else is selling it: the usual price"]
    end
    if price then price = math.max(1, math.floor(price)) end
    local vendorBetter = price and vendor > 0 and price * AH_CUT < vendor
    if price and vendor > 0 then price = math.max(price, math.ceil(vendor / AH_CUT)) end
    return { price = price, why = why, live = cheapest, usual = usual, vendor = vendor, vendorBetter = vendorBetter }
end

local function sellFrame()
    if not AuctionHouseFrame then return nil end
    for _, f in ipairs({ AuctionHouseFrame.CommoditiesSellFrame, AuctionHouseFrame.ItemSellFrame }) do
        if f and f:IsShown() then return f end
    end
end

local function build()
    panel = CreateFrame("Frame", "HaulwiseSellHelper", AuctionHouseFrame or UIParent, "BackdropTemplate")
    panel:SetSize(250, 128)
    panel:SetBackdrop(GP.FLAT)
    panel:SetBackdropColor(0.055, 0.058, 0.07, 0.96)
    panel:SetBackdropBorderColor(0.5, 0.4, 0.18, 1)
    local accent = GP.Tex(panel, "ARTWORK", GP.GOLD[1], GP.GOLD[2], GP.GOLD[3])
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
    panel.title:SetPoint("TOPLEFT", 10, -8)
    panel.title:SetText(L["Haulwise price"])
    panel.text = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    panel.text:SetPoint("TOPLEFT", 10, -28)
    panel.text:SetPoint("RIGHT", -10, 0)
    panel.text:SetJustifyH("LEFT")
    panel.text:SetSpacing(2)
    panel.use = GP.FlatButton(panel, L["Use price"], 110, 22)
    panel.use:SetPoint("BOTTOMLEFT", 10, 10)
    panel.use:SetScript("OnClick", function()
        local f = sellFrame()
        if not (f and current and current.price) then return end
        local ok = pcall(function() f.PriceInput:SetAmount(current.price) end)
        if not ok then GP.Print(L["Couldn't fill in the price. Type it in: "] .. GP.Coins(current.price)) end
    end)
    panel:Hide()
end

function GP:UpdateSellHelper()
    if not self.db.settings.sellHelper then if panel then panel:Hide() end return end
    local f = sellFrame()
    local loc = f and f.GetItem and f:GetItem()
    local id = getItemID(loc)
    if not id then if panel then panel:Hide() end return end
    if not panel then build() end
    local commodity = f == AuctionHouseFrame.CommoditiesSellFrame
    current = self:SellAdvice(id, loc, commodity)
    local lines = {}
    if current.price then
        lines[#lines + 1] = L["Suggested: |cffffffff"] .. GP.Coins(current.price) .. "|r" .. (commodity and L[" each"] or "")
        lines[#lines + 1] = "|cff8a8880" .. (current.why or "") .. "|r"
    else
        lines[#lines + 1] = L["|cff8a8880No price yet: scan the AH, or wait for the listings to load.|r"]
    end
    if current.live then lines[#lines + 1] = L["Cheapest now: "] .. GP.Coins(current.live) end
    if current.usual then lines[#lines + 1] = L["Usual price: "] .. GP.Coins(current.usual) end
    if current.vendorBetter then
        lines[#lines + 1] = L["|cffff9944A vendor pays more ("] .. GP.Coins(current.vendor) .. L["). Sell it there.|r"]
    end
    panel.text:SetText(table.concat(lines, "\n"))
    panel.use:SetShown(current.price ~= nil and not current.vendorBetter)
    panel:SetHeight(48 + #lines * 15 + (panel.use:IsShown() and 28 or 0))
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, -40)
    panel:Show()
end

local hooked = false
local function hook()
    if hooked or not AuctionHouseFrame then return end
    hooked = true
    for _, f in ipairs({ AuctionHouseFrame.CommoditiesSellFrame, AuctionHouseFrame.ItemSellFrame }) do
        if f and f.SetItem then
            hooksecurefunc(f, "SetItem", function() C_Timer.After(0.1, function() GP:UpdateSellHelper() end) end)
            f:HookScript("OnHide", function() C_Timer.After(0, function() GP:UpdateSellHelper() end) end)
        end
    end
end

GP:On("AUCTION_HOUSE_SHOW", function() hook() end)
GP:On("AUCTION_HOUSE_CLOSED", function() if panel then panel:Hide() end end)
for _, ev in ipairs({ "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED" }) do
    GP:On(ev, function() if panel and panel:IsShown() then GP:UpdateSellHelper() end end)
end
