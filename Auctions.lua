-- Haulwise: your own auctions. At the auction house a small panel lists what you have up for
-- sale and which of your auctions someone has undercut. Click a row to search for it (that also
-- gets the newest listings); undercut ones get a Cancel button so you can post them again at
-- the price the sell helper suggests. Cancelling is always your click: Haulwise never cancels
-- or posts by itself.
local _, GP = ...
local L = GP.L

local MAX_ROWS = 8
local W = 290
local panel, rows = nil, {}
local live = {} -- [itemID] = { t, cheapest other unit price } from the newest search results

local function isCommodity(a)
    if C_AuctionHouse and C_AuctionHouse.GetItemKeyInfo and a.itemKey then
        local ok, info = pcall(C_AuctionHouse.GetItemKeyInfo, a.itemKey)
        if ok and info and info.isCommodity ~= nil then return info.isCommodity end
    end
    return (a.quantity or 1) > 1
end

-- Your price per unit. Commodities list a unit price; other items the price of the auction.
local function unitPrice(a, commodity)
    local b = a.buyoutAmount or a.bidAmount
    if not b then return nil end
    if commodity then return b end
    return b / math.max(1, a.quantity or 1)
end

-- The cheapest listing that isn't yours, from search results the game has sent.
local function readLive(id, itemKey)
    if not C_AuctionHouse then return end
    local best
    local okC, nC = pcall(C_AuctionHouse.GetNumCommoditySearchResults, id)
    if okC and nC and nC > 0 then
        for i = 1, math.min(nC, 30) do
            local ok, r = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, id, i)
            if ok and r and r.unitPrice then
                local mine = r.containsOwnerItem and (r.numOwnerItems or 0) >= (r.quantity or 1)
                if not mine then best = r.unitPrice; break end
            end
        end
    elseif itemKey then
        local okI, nI = pcall(C_AuctionHouse.GetNumItemSearchResults, itemKey)
        for i = 1, math.min((okI and nI) or 0, 30) do
            local ok, r = pcall(C_AuctionHouse.GetItemSearchResultInfo, itemKey, i)
            if ok and r and r.buyoutAmount and not r.containsOwnerItem then
                local u = r.buyoutAmount / math.max(1, r.quantity or 1)
                if not best or u < best then best = u end
            end
        end
    end
    if best then live[id] = { t = time(), u = best } end
end

-- Your active auctions: { auctionID, id, qty, unit, commodity, cheapest, from, undercut, left }.
function GP:MyAuctions()
    local out = {}
    if not (C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions) then return out end
    local ok, n = pcall(C_AuctionHouse.GetNumOwnedAuctions)
    for i = 1, (ok and n) or 0 do
        local okA, a = pcall(C_AuctionHouse.GetOwnedAuctionInfo, i)
        local id = okA and a and a.itemKey and a.itemKey.itemID
        if id and a.status ~= 1 then -- 1 = sold, waiting for the mail
            local commodity = isCommodity(a)
            local unit = unitPrice(a, commodity)
            local r = { auctionID = a.auctionID, id = id, qty = a.quantity or 1, unit = unit, commodity = commodity,
                        left = a.timeLeftSeconds, link = a.itemLink, itemKey = a.itemKey }
            local l = live[id]
            if l and time() - l.t < 600 then
                r.cheapest, r.from = l.u, "live"
            else
                local cheap = self:Cheapest(id)
                if cheap[1] then r.cheapest, r.from = cheap[1].u, "scan" end
            end
            -- Undercut: someone lists it for less than you (a copper of rounding is fine).
            r.undercut = unit and r.cheapest and r.cheapest < unit - 0.5 or false
            out[#out + 1] = r
        end
    end
    table.sort(out, function(a, b)
        if a.undercut ~= b.undercut then return a.undercut end
        return (GP.ItemInfo(a.id) or "") < (GP.ItemInfo(b.id) or "")
    end)
    return out
end

local function build()
    panel = CreateFrame("Frame", "HaulwiseMyAuctions", AuctionHouseFrame or UIParent, "BackdropTemplate")
    panel:SetSize(W, 60)
    panel:SetBackdrop(GP.FLAT)
    panel:SetBackdropColor(0.055, 0.058, 0.07, 0.96)
    panel:SetBackdropBorderColor(0.5, 0.4, 0.18, 1)
    local accent = GP.Tex(panel, "ARTWORK", GP.GOLD[1], GP.GOLD[2], GP.GOLD[3])
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
    panel.title:SetPoint("TOPLEFT", 10, -8)
    panel.note = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    panel.note:SetPoint("BOTTOMLEFT", 10, 8)
    panel.note:SetPoint("RIGHT", -10, 0)
    panel.note:SetJustifyH("LEFT")
    panel:Hide()
end

local function rowFor(i)
    local row = rows[i]
    if row then return row end
    row = GP.ItemRow(panel, W - 20)
    row.cancel = GP.FlatButton(panel, L["Cancel"], 54, 18)
    row.cancel:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    rows[i] = row
    return row
end

-- Posting again after a cancel ------------------------------------------------------------------
-- Cancel remembers the item; once it's back in your bags (straight away, or from the mailbox),
-- the panel offers to post it again at the price the sell helper would pick right then. The box
-- shows quantity, price and deposit first: nothing is posted without your click.

local function findInBags(id)
    if not (C_Container and C_Container.GetContainerNumSlots) then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == id and not info.isLocked then return bag, slot, info.stackCount or 1 end
        end
    end
end

function GP:RememberRepost(a)
    self.db.repost = self.db.repost or {}
    self.db.repost[a.id] = { qty = a.qty or 1, commodity = a.commodity and true or nil, t = time() }
end

function GP:RepostList()
    local out = {}
    for id, e in pairs(self.db.repost or {}) do
        if type(e) ~= "table" or time() - (e.t or 0) > 3 * 86400 then
            self.db.repost[id] = nil
        else
            local bag, slot, n = findInBags(id)
            out[#out + 1] = { id = id, e = e, bag = bag, slot = slot, n = n }
        end
    end
    table.sort(out, function(a, b) return (a.bag and 1 or 0) > (b.bag and 1 or 0) end)
    return out
end

local DURATION = 2   -- the middle one (24 hours on most auction houses)

function GP:Repost(r)
    if not (r.bag and ItemLocation and ItemLocation.CreateFromBagAndSlot) then return end
    local advice = self:SellAdvice(r.id, nil, r.e.commodity)
    local unit = advice.price
    if not unit or unit <= 0 then return self.Print(L["No price to post at yet: search the AH for it first."]) end
    local loc = ItemLocation:CreateFromBagAndSlot(r.bag, r.slot)
    local have = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(r.id)) or GetItemCount and GetItemCount(r.id) or r.n
    local qty = r.e.commodity and math.max(1, math.min(r.e.qty or 1, have or 1)) or (r.n or 1)
    local deposit
    if r.e.commodity and C_AuctionHouse.CalculateCommodityDeposit then
        local ok, d = pcall(C_AuctionHouse.CalculateCommodityDeposit, r.id, DURATION, qty); deposit = ok and d or nil
    elseif C_AuctionHouse.CalculateItemDeposit then
        local ok, d = pcall(C_AuctionHouse.CalculateItemDeposit, loc, DURATION, qty); deposit = ok and d or nil
    end
    local text = string.format(L["Post %d %s at %s each (%s in all)?"], qty, GP.ItemInfo(r.id) or "?", GP.Coins(unit), GP.Coins(unit * qty))
    if deposit then text = text .. "\n" .. string.format(L["Deposit: %s"], GP.Coins(deposit)) end
    GP._showBuyConfirm(text, { go = function()
        local ok
        if r.e.commodity then
            ok = pcall(C_AuctionHouse.PostCommodity, loc, DURATION, qty, unit)
        else
            -- The whole stack's price: if the game wanted it per item, this errs on the high side.
            ok = pcall(C_AuctionHouse.PostItem, loc, DURATION, qty, nil, unit * qty)
        end
        if ok then
            self.db.repost[r.id] = nil
        else
            GP.Print(L["Couldn't post it here. Post it on the Sell tab."])
        end
        GP:UpdateMyAuctions()
    end }, L["Post"])
end

function GP:UpdateMyAuctions()
    if not (self.db and self.db.settings.sellHelper and self.ahOpen and AuctionHouseFrame) then
        if panel then panel:Hide() end
        return
    end
    local list = self:MyAuctions()
    local reposts = self:RepostList()
    if #list == 0 and #reposts == 0 then if panel then panel:Hide() end return end
    if not panel then build() end
    local under = 0
    for _, a in ipairs(list) do if a.undercut then under = under + 1 end end
    panel.title:SetText(under > 0 and string.format(L["Your auctions: |cffff9944%d undercut|r"], under)
        or (#list > 0 and L["Your auctions: |cff5fd35fall cheapest|r"] or L["Your auctions"]))
    for _, r in ipairs(rows) do r:Hide(); r.cancel:Hide() end
    local y = -28
    for i, a in ipairs(list) do
        if i > MAX_ROWS then break end
        local row = rowFor(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 10, y)
        local status
        if a.undercut then
            status = "|cffff9944" .. GP.Coins(a.cheapest, true) .. "|r"
            row.right:SetPoint("RIGHT", -60, 0)
        else
            status = a.cheapest and L["|cff5fd35fcheapest|r"] or L["|cff8a8880no price yet|r"]
            row.right:SetPoint("RIGHT", -2, 0)
        end
        row:SetItem(a.id, a.link, status, a.qty)
        row.tip = function(t)
            if a.link then t:SetHyperlink(a.link) else t:SetItemByID(a.id) end
            t:AddLine(" ")
            t:AddDoubleLine(L["|cffffd040Haulwise|r  your price"], a.unit and (GP.Coins(a.unit) .. (a.commodity and L[" each"] or "")) or "?")
            if a.cheapest then
                t:AddDoubleLine(a.undercut and L["Cheaper listing"] or L["Cheapest listing"], GP.Coins(a.cheapest)
                    .. (a.from == "live" and L["  (just now)"] or L["  (last scan)"]))
            end
            local advice = GP:SellAdvice(a.id, nil, a.commodity)
            if a.undercut and advice.price then t:AddDoubleLine(L["Post again at"], GP.Coins(advice.price)) end
            t:AddLine(L["Click: search the AH for the newest listings."], 0.6, 0.6, 0.6)
            if a.undercut then t:AddLine(L["Cancel gives the item back (by mail if your AH mails it), but the deposit is lost."], 1, 0.6, 0.3, true) end
        end
        row:SetScript("OnClick", function() GP:SearchAH(a.id) end)
        row:Show()
        if a.undercut and a.auctionID and C_AuctionHouse.CancelAuction then
            row.cancel:SetLabel(L["Cancel"])
            row.cancel:SetScript("OnClick", function()
                local ok = pcall(C_AuctionHouse.CancelAuction, a.auctionID)
                if not ok then
                    GP.Print(L["Couldn't cancel it here. Cancel it on the Auctions tab."])
                else
                    GP:RememberRepost(a)
                    GP.Print(string.format(L["Cancelled %s. When it's back in your bags, post it again from this panel."], GP.ItemInfo(a.id) or "?"))
                end
            end)
            row.cancel:Show()
        end
        y = y - 22
    end
    -- Cancelled ones to post again.
    local shown = math.min(#list, MAX_ROWS)
    for k, r in ipairs(reposts) do
        if shown + k > MAX_ROWS + 3 then break end
        local row = rowFor(shown + k)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 10, y)
        local advice = self:SellAdvice(r.id, nil, r.e.commodity)
        if r.bag then
            row.right:SetPoint("RIGHT", -60, 0)
            row:SetItem(r.id, nil, advice.price and ("|cff5fd35f" .. GP.Coins(advice.price, true) .. "|r") or L["|cff8a8880no price yet|r"], r.n)
            row.cancel:SetLabel(L["Post"])
            row.cancel:SetScript("OnClick", function() GP:Repost(r) end)
            row.cancel:Show()
        else
            row.right:SetPoint("RIGHT", -2, 0)
            row:SetItem(r.id, nil, L["|cff8a8880in your mailbox|r"], r.e.qty)
        end
        row.tip = function(t)
            t:SetItemByID(r.id)
            t:AddLine(" ")
            t:AddLine(L["You cancelled this. Post it again at the price the sell helper picks now."], 1, 1, 1, true)
            if advice.price then t:AddDoubleLine(L["Post again at"], GP.Coins(advice.price)) end
            if not r.bag then t:AddLine(L["Take it from your mailbox first."], 1, 0.6, 0.3, true) end
        end
        row:SetScript("OnClick", function() GP:SearchAH(r.id) end)
        row:Show()
        y = y - 22
    end
    local more = #list - MAX_ROWS
    panel.note:SetText(more > 0 and string.format(L["and %d more on the Auctions tab"], more)
        or L["Click an auction to check the newest price."])
    panel:SetHeight(-y + 44)
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMRIGHT", 4, 0)
    panel:Show()
end

local pending
local function refresh()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function() pending = nil; GP:UpdateMyAuctions() end)
end

GP:On("OWNED_AUCTIONS_UPDATED", refresh)
GP:On("AUCTION_HOUSE_SHOW", refresh)
GP:On("AUCTION_CANCELED", function()
    if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then pcall(C_AuctionHouse.QueryOwnedAuctions, {}) end
end)
GP:On("AUCTION_HOUSE_CLOSED", function() if panel then panel:Hide() end end)
GP:On("BAG_UPDATE_DELAYED", function() if GP.ahOpen and GP.db and next(GP.db.repost or {}) then refresh() end end)
GP:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(id)
    id = GP.Safe(id)
    if id then readLive(id); refresh() end
end)
GP:On("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey)
    local id = itemKey and GP.Safe(itemKey.itemID)
    if id then readLive(id, itemKey); refresh() end
end)
