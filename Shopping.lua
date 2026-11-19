-- Haulwise: shopping list for crafting. Pick crafts in the Craft tab (click a row), set how many,
-- and see every reagent you need, what you already have (bags + bank, and on your alts), what's
-- left to buy and where it's cheapest. Click a reagent to search the AH for it.
local _, GP = ...
local L = GP.L

local W = 460
local panel
local recipeRows, reagentRows = {}, {}

local function list() local c = GP:Char(); c.shopping = c.shopping or {}; return c.shopping end

local function countHere(id)
    local get = (C_Item and C_Item.GetItemCount) or GetItemCount
    local ok, n = pcall(get, id, true)
    return ok and n or 0
end

local function countOnAlts(id)
    local n = 0
    for _, c in ipairs(GP:Alts()) do
        for _, loc in ipairs({ "bags", "bank", "mail" }) do n = n + ((c[loc] and c[loc][id]) or 0) end
    end
    return n
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
    local need, crafts, sell = {}, {}, 0
    for key, qty in pairs(list()) do
        local rec = self:Char().recipes[key]
        if rec then
            crafts[#crafts + 1] = { key = key, rec = rec, qty = qty }
            for _, r in ipairs(GP.UnpackReagents(rec.r)) do need[r[1]] = (need[r[1]] or 0) + r[2] * qty end
            sell = sell + (self:ItemValue(rec.out) or 0) * (rec.oq or 1) * qty
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
        reagents[#reagents + 1] = { id = id, need = n, have = have, alts = countOnAlts(id), buy = buy, unit = unit, where = where, cost = cost }
    end
    table.sort(reagents, function(a, b)
        if (a.buy > 0) ~= (b.buy > 0) then return a.buy > 0 end
        return (a.cost or 0) > (b.cost or 0)
    end)
    return crafts, reagents, total, sell, unpriced, used
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
    local crafts, reagents, total, sell, unpriced, used = self:ShoppingTotals()
    for _, r in ipairs(recipeRows) do r:Hide() end
    for _, r in ipairs(reagentRows) do r:Hide() end
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
            row = GP.ItemRow(panel, W - 24)
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
        else
            buyText = string.format(L["buy |cffffffff%d|r  |cffff9944no price|r"], g.buy)
        end
        row:SetItem(g.id, nil, string.format("|cff8a8880%g · %d ·|r %s", g.need, g.have, buyText))
        row.link = nil
        row.tip = function(t)
            t:SetItemByID(g.id)
            t:AddLine(" ")
            t:AddDoubleLine(L["Need"], tostring(g.need), 0.7, 0.7, 0.7, 1, 1, 1)
            t:AddDoubleLine(L["You have (bags + bank)"], tostring(g.have), 0.7, 0.7, 0.7, 1, 1, 1)
            if g.alts > 0 then t:AddDoubleLine(L["On your alts"], tostring(g.alts), 0.7, 0.7, 0.7, 1, 0.6, 0.27) end
            if g.unit then t:AddDoubleLine(L["Cheapest"], GP.Coins(g.unit) .. L[" each at "] .. (g.where == "vendor" and L["a vendor"] or L["the AH"]), 0.7, 0.7, 0.7, 1, 1, 1) end
            t:AddLine(g.where == "vendor" and L["Buy it from a trade goods vendor."] or L["Click: search the AH."], 0.6, 0.6, 0.6)
        end
        row:SetScript("OnClick", function()
            if g.where == "vendor" then
                GP.Print(string.format(L["Buy %d %s from a vendor (%s each)."], g.buy, GP.ItemInfo(g.id) or "?", GP.Coins(g.unit or 0)))
            else
                GP:SearchAH(g.id)
            end
        end)
        row:Show()
        y = y - 22
    end
    local profit = sell - (used or total)
    local text = string.format(L["To buy: |cffffffff%s|r   ·   Results sell for %s   ·   %s"], GP.Coins(total, true), GP.Coins(sell, true),
        (profit >= 0 and L["|cff5fd35fprofit "] or L["|cffff6b5bloss "]) .. GP.Coins(math.abs(profit), true) .. "|r")
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
