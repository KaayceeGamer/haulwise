-- Haulwise: main window. Flat dark panel, gold accents, item icons, coin icons and value bars.
local _, GP = ...
local L = GP.L

local W, H = 960, 560
local ROWS, ROW_H, MAX_ROWS = 15, 22, 45
local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local GOLD = { 1, 0.82, 0.25 }
local C = {
    bg = { 0.055, 0.058, 0.07, 0.96 }, header = { 0.09, 0.09, 0.105, 1 }, border = { 0.5, 0.4, 0.18, 1 },
    line = { 1, 1, 1, 0.05 }, zebra = { 1, 1, 1, 0.025 }, hover = { 1, 0.82, 0.25, 0.09 },
    bar = { 1, 0.78, 0.2, 0.16 }, barNeg = { 1, 0.3, 0.25, 0.16 },
}
-- tip: the question each tab answers, shown when you point at it.
local TABS = {
    { key = "farm",    label = L["Farm"],    icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", tip = L["Where do I make the most gold per hour? Mobs and zones ranked from real drops."] },
    { key = "bags",    label = L["Bags"],    icon = "Interface\\Icons\\INV_Misc_Bag_08", tip = L["What is everything in my bags worth, and should I sell, auction or disenchant it?"] },
    { key = "gear",    label = L["Gear"],    icon = "Interface\\Icons\\INV_Chest_Chain", tip = L["Which gear is an upgrade for me or my alts, also for sale on the auction house?"] },
    { key = "craft",   label = L["Craft"],   icon = "Interface\\Icons\\Trade_BlackSmithing", tip = L["What's profitable to craft, and what's the cheapest way to skill up?"] },
    { key = "deals",   label = L["Deals"],   icon = "Interface\\Icons\\INV_Misc_Coin_02", tip = L["What's cheap on the auction house right now, worth buying to resell or vendor?"] },
    { key = "recipes", label = L["Recipes"], icon = "Interface\\Icons\\INV_Scroll_03", tip = L["Which recipes are worth learning, and where do I get them?"] },
    { key = "market",  label = L["Market"],  icon = "Interface\\Icons\\INV_Misc_Note_01", tip = L["How are prices moving, and what have I sold?"] },
    { key = "holdings", label = L["Holdings"], icon = "Interface\\Icons\\INV_Misc_Book_09", tip = L["What do my characters own, in bags, bank, mail and on the auction house?"] },
}

-- Formatting ------------------------------------------------------------------------------

local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:11:11:1:0|t"
local GI, SI, CI = COIN:format("Gold"), COIN:format("Silver"), COIN:format("Copper")

-- Money with coin icons. short = drop copper once there's gold.
function GP.Coins(copper, short)
    local neg = copper and copper < 0
    copper = math.floor(math.abs(copper or 0) + 0.5)
    local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    local out
    if g > 0 then
        out = short and string.format("%d%s %d%s", g, GI, s, SI) or string.format("%d%s %d%s %d%s", g, GI, s, SI, c, CI)
    elseif s > 0 then
        out = string.format("%d%s %d%s", s, SI, c, CI)
    else
        out = string.format("%d%s", c, CI)
    end
    return neg and ("|cffff6b5b-|r" .. out) or out
end
local Coins = GP.Coins

local function pct(x, signed)
    if not x then return "|cff666666–|r" end
    local s = string.format("%s%.0f%%", (signed and x > 0) and "+" or "", x * 100)
    if not signed then return s end
    if x >= 0.05 then return "|cff5fd35f" .. s .. "|r" elseif x <= -0.05 then return "|cffff6b5b" .. s .. "|r" end
    return "|cffaaaaaa" .. s .. "|r"
end

local function grey(s) return "|cff8a8880" .. s .. "|r" end

local function itemName(id)
    local name, quality = GP.ItemInfo(id)
    if not name then return L["item #"] .. id end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    return (c and c.hex or "|cffffffff") .. name .. "|r"
end

local function ago(sec)
    if not sec then return "?" end
    if sec < 3600 then return string.format(L["%d min ago"], math.max(1, math.floor(sec / 60))) end
    if sec < 86400 then return string.format(L["%dh ago"], math.floor(sec / 3600)) end
    return string.format(L["%dd ago"], math.floor(sec / 86400))
end

local function confColor(k)
    if k < 30 then return "|cffff6b5b" elseif k < 100 then return "|cffffd060" end
    return "|cff5fd35f"
end

-- Small widgets -----------------------------------------------------------------------------

local function tex(parent, layer, color)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(unpack(color))
    return t
end

local function tip(owner, fn)
    owner:SetScript("OnEnter", function(self)
        if self.hoverBg then self.hoverBg:Show() end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        fn(GameTooltip, self)
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function(self)
        if self.hoverBg then self.hoverBg:Hide() end
        GameTooltip:Hide()
    end)
end

local function flatButton(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 22)
    b:SetBackdrop(FLAT)
    b:SetBackdropColor(0.14, 0.12, 0.08, 1)
    b:SetBackdropBorderColor(0.42, 0.33, 0.15, 1)
    b.hoverBg = tex(b, "HIGHLIGHT", { 1, 0.82, 0.25, 0.10 })
    b.hoverBg:SetAllPoints()
    b.label = b:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGold")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    function b:SetLabel(t) self.label:SetText(t) end
    function b:SetPrimary(on)
        if on then self:SetBackdropColor(0.16, 0.3, 0.12, 1); self:SetBackdropBorderColor(0.35, 0.7, 0.3, 1)
        else self:SetBackdropColor(0.14, 0.12, 0.08, 1); self:SetBackdropBorderColor(0.42, 0.33, 0.15, 1) end
    end
    return b
end

-- A flat toggle: small square that fills gold when on.
local function toggle(parent, label, get, set, tipText)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    local box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    box:SetSize(12, 12)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop(FLAT)
    box:SetBackdropColor(0.1, 0.1, 0.1, 1)
    box:SetBackdropBorderColor(0.5, 0.42, 0.2, 1)
    local fill = tex(box, "ARTWORK", { GOLD[1], GOLD[2], GOLD[3], 1 })
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    local fs = b:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
    fs:SetText(label)
    b:SetWidth(fs:GetStringWidth() + 26)
    b.sync = function() fill:SetShown(get() and true or false) end
    b:SetScript("OnClick", function() set(not get()); GP:RefreshUI() end)
    tip(b, function(t) t:AddLine(tipText, 1, 1, 1, true) end)
    return b
end

-- Tabs: what each one shows -------------------------------------------------------------------

local S = function() return GP.db.settings end
local TAB = {}

-- A tab can have more than one view (Gear: your bags / the AH). The view is TAB["gear_ah"] etc.
local plural = GP.Plural

local function current()
    local tab = TAB[S().tab] and S().tab or "farm"
    local v = S().views and S().views[tab]
    if v and TAB[tab .. "_" .. v] then return tab .. "_" .. v end
    return tab
end
-- Profession filter (Craft, Skill up, Recipes): one button that cycles All -> each profession.
-- Kept per character, since each has its own professions.
local function profFilter() return GP:Char().profFilter end
local function byProf(rows)
    local p = profFilter()
    if not p then return rows end
    local out = {}
    for _, r in ipairs(rows) do if r.prof == p then out[#out + 1] = r end end
    return out
end
local function profToggle()
    return { kind = "cycle",
        label = function()
            local p = profFilter()
            return L["Profession: "] .. (p and L[p] or L["All"])
        end,
        click = function()
            local list = {}
            for name in pairs(GP:MyProfessions()) do if GP.RECIPE_SUBCLASS[name] then list[#list + 1] = name end end
            table.sort(list)
            local cur, idx = profFilter(), 0
            for i, n in ipairs(list) do if n == cur then idx = i end end
            GP:Char().profFilter = list[idx + 1] -- after the last one: back to All
            GP.scrollToTop = true
        end,
        tip = function() return L["Show one profession, or all of them. Click to switch."] end }
end

local function trainerButton()
    return { kind = "cycle",
        label = function() return L["Find trainer"] end,
        click = function() GP:FindTrainer(profFilter()) end,
        tip = function()
            return L["Set a waypoint to the nearest trainer for your profession (the one picked with Profession, or the one that needs training). It looks for a trainer that teaches your next rank."]
        end }
end

local function pawnToggle()
    return { L["Use Pawn"], nil, L["Compare gear with your Pawn scales instead of Haulwise's own stat weights."],
        function() return GP.PawnLoaded() end,
        get = function() return GP.db.settings.usePawn end,
        set = function(on)
            GP.db.settings.usePawn = on
            if on then GP:Char().specOverride = nil end
            GP:ScanUpgrades()
            GP:RecheckAHUpgrades(true)
        end }
end

local function viewToggle(tab, view, label, tipText)
    return { label, nil, tipText,
        get = function() return S().views and S().views[tab] == view end,
        set = function(on)
            S().views = S().views or {}
            S().views[tab] = on and view or nil
            GP.scrollToTop = true
        end }
end

TAB.farm = {
    cols = {
        { key = "name", title = L["Mob"], w = 196, icon = true },
        { key = "zone", title = L["Zone"], w = 118 },
        { key = "lvl", title = L["Lvl"], w = 50, align = "CENTER" },
        { key = "kills", title = L["Kills"], w = 52, align = "RIGHT" },
        { key = "kph", title = L["Kills/h"], w = 56, align = "RIGHT" },
        { key = "perKill", title = L["Per kill"], w = 86, align = "RIGHT" },
        { key = "est", title = L["Gold/h"], w = 108, align = "RIGHT", bar = true },
        { key = "safe", title = L["Safe/h"], w = 92, align = "RIGHT" },
        { key = "top", title = L["Main earner"], w = 130 },
    },
    rows = function() return GP:Rank(GP:FarmZoneFilter()) end,
    bar = function(r) return r.est end,
    cells = function(r)
        local top = r.lines[1]
        local share = top and r.est > 0 and top.perHour / r.est or 0
        local lv = r.minL and (r.minL == r.maxL and tostring(r.minL) or (r.minL .. "-" .. r.maxL)) or "?"
        local earner = top and (itemName(top.id) .. grey(string.format(" %d%%", share * 100))) or grey("coins")
        if top and top.craft and not top.crafted then earner = earner .. L[" |cff88ccffcraft↑|r"] end
        return {
            name = r.name, icon = GP.MobIcon(r.npc) or (top and GP.ItemIcon(top.id)) or 133784, portrait = GP.MobDisplay(r.npc),
            zone = grey(GP.ZoneName(r.zone)), lvl = lv,
            kills = r.estOnly and grey(L["est."]) or (confColor(r.kills) .. r.kills .. "|r"),
            kph = r.measured and tostring(math.floor(r.kph + 0.5)) or grey("~" .. math.floor(r.kph + 0.5)),
            perKill = Coins(r.perKill), est = ((r.kills < 10 or r.estOnly) and grey("~") or "") .. Coins(r.est, true),
            safe = grey(Coins(r.safe, true)), top = earner,
        }
    end,
    hero = function(rows)
        local b = rows[1]
        local zone = GP:FarmZoneFilter()
        if not b then return zone and (L["No mobs recorded in "] .. GP.ZoneName(zone) .. L[" yet."]) or nil end
        local text = string.format(L["%s  |cffffffff%s|r in %s   %s/h  %s"], zone and L["Best farm here:"] or L["Best farm right now:"],
            b.name, GP.ZoneName(b.zone), Coins(b.est, true), grey(L["(safe "] .. Coins(b.safe, true) .. "/h)"))
        local hidden = zone and GP:FarmHiddenElsewhere(zone) or 0
        local realHere = false
        for _, r in ipairs(rows) do if not r.estOnly then realHere = true; break end end
        if hidden > 0 and (b.estOnly or not realHere) then
            -- Only guesses here, while real data waits elsewhere: say how to see it.
            text = text .. "  " .. string.format(L["|cff5fd35f%s in other zones: untick This zone only|r"], plural(hidden, "mob"))
        elseif b.estOnly then
            text = text .. "  " .. grey(L["estimate: nobody has farmed it yet"])
        elseif b.kills < 30 then
            local word, color = GP.Confidence(b.kills)
            text = text .. "  " .. color .. string.format(L["%s, %s"], word, plural(b.kills, "kill")) .. "|r"
        end
        return text
    end,
    empty = function()
        local zone = GP:FarmZoneFilter()
        if zone then
            local hidden = GP:FarmHiddenElsewhere(zone)
            local more = hidden > 0 and ("\n" .. string.format(L["%s with real kills are in other zones."], plural(hidden, "mob"))) or ""
            return L["Nothing farmed in this zone yet, by you or the players who share.\n\nTurn off |cffffd040This zone only|r to see the best farms everywhere."] .. more
        end
        return L["No kills recorded yet.\n\nGo farm and loot what you kill. Every mob you loot shows up here, with its real drop chances, how fast you kill it and what it's worth at your auction house."]
    end,
    toggles = {
        viewToggle("farm", "zones", L["By zone"], L["Rank zones instead of single mobs: the best gold per hour in each zone."]),
        { L["This zone only"], nil, L["Only show mobs from one zone: the zone you're in, or the one you clicked in By zone."],
          get = function() return S().farmZone ~= nil end,
          set = function(on) S().farmZone = on and "here" or nil; GP.scrollToTop = true end },
        { L["Hide mobs above my level"], "levelWindow", L["Hide mobs more than 2 levels above you, and mobs nobody has killed yet that are more than 10 levels below you."] },
        { L["Community data"], "useShared", L["Add everyone's pooled kills (shipped with the addon) and friends' imports to your own."] },
        { L["Estimates"], "useEstimates", L["Also rank mobs nobody has farmed yet, from Classic's loot tables (Haulwise Data). Real kills take over as they come in."] },
        { L["Skinning/gathering"], "includeGather", L["Count skinning, mining and herbing off corpses."], function() return GP:PlayerHasGathering() end },
        { L["Pickpocket"], "includePickpocket", L["Add the coins and items you pickpocket."], function() return GP:PlayerIsRogue() end },
        { L["Value as crafted"], "valueAsCrafted", L["Value drops at what they're worth after you craft them (e.g. cooked), when that's more than selling raw."] },
    },
    tooltip = function(t, r)
        t:AddLine(r.name, GOLD[1], GOLD[2], GOLD[3])
        t:AddDoubleLine(L["Where"], GP.ZoneName(r.zone), 0.7, 0.7, 0.7, 1, 1, 1)
        local word, color = GP.Confidence(r.kills)
        local others = math.max(0, r.kills - (r.own or r.kills))
        local basis
        if r.estOnly then basis = L["an estimate (classic loot tables)"]
        elseif others > 0 then basis = string.format(L["%d kills (%d yours, %d from other players)"], r.kills, r.own or 0, others)
        else basis = string.format(L["%d kills, all yours"], r.kills) end
        if r.estimated and not r.estOnly then basis = basis .. L[" + an estimate"] end
        t:AddDoubleLine(L["Based on"], basis, 0.7, 0.7, 0.7, 1, 1, 1)
        if r.estOnly then
            t:AddDoubleLine(L["How sure"], L["|cffff9944estimate|r"], 0.7, 0.7, 0.7)
        else
            t:AddDoubleLine(L["How sure"], color .. word .. "|r", 0.7, 0.7, 0.7)
        end
        t:AddDoubleLine(L["Kills per hour"], r.measured and string.format(L["%d (timed)"], r.kph) or string.format(L["~%d (not timed yet)"], r.kph), 0.7, 0.7, 0.7, 1, 1, 1)
        t:AddDoubleLine(L["Coins per kill"], Coins(r.coinsPerKill), 0.7, 0.7, 0.7, 1, 1, 1)
        t:AddLine(" ")
        t:AddDoubleLine(L["Drop  (chance, 95% range)"], L["per hour"], GOLD[1], GOLD[2], GOLD[3], GOLD[1], GOLD[2], GOLD[3])
        for i, l in ipairs(r.lines) do
            if i > 12 then t:AddLine(string.format(L["...and %d more"], #r.lines - 12), 0.6, 0.6, 0.6); break end
            local tag = l.kind == "gather" and L[" |cff88ccff(skin/gather)|r"] or l.kind == "pickpocket" and L[" |cffcc88ff(pickpocket)|r"] or ""
            local right = Coins(l.perHour, true)
            if l.thin then right = right .. L[" |cffff9944thin|r"] end
            if not l.priced then right = right .. (l.vendor > 0 and grey(L[" vendor"]) or L[" |cffff6b5bno price|r"]) end
            t:AddDoubleLine(string.format("|T%s:14|t %s%s %s", GP.ItemIcon(l.id), itemName(l.id), tag,
                grey(string.format("%.0f%% (%.0f-%.0f)", l.chance * 100, l.lo * 100, l.hi * 100))), right)
            if l.craft then
                t:AddLine(string.format(L["      |cff88ccffCraft into %s: %s per unit instead of %s|r"], l.craftName or "?", Coins(l.craft), Coins(l.unit)))
            end
        end
        if r.estOnly then
            t:AddLine(" ")
            t:AddLine(L["Nobody has shared kills of this mob yet, so these are Classic's loot tables. Forever may differ: your kills, and every kill anyone shares, replace the estimate."], 1, 0.6, 0.3, true)
        elseif r.kills < 30 then
            t:AddLine(" ")
            t:AddLine(L["Few kills so far: drop chances can still move a lot. Every kill anyone shares makes this surer."], 1, 0.45, 0.4, true)
        end
    end,
}

-- Sells/day as a short cell: "~12", "<1", or an orange 0 when nothing sold in the scans.
local function demandCell(id)
    local per, _, label = GP:SellSpeed(id)
    if not per then return grey("–") end
    if label == "none" then return "|cffff99440|r" end
    if per < 1 then return "|cffffd060<1|r" end
    return (label == "fast" and "|cff5fd35f~" or "~") .. math.floor(per + 0.5) .. (label == "fast" and "|r" or "")
end

TAB.craft = {
    cols = {
        { key = "name", title = L["Recipe"], w = 230, icon = true },
        { key = "prof", title = L["Profession"], w = 112 },
        { key = "cost", title = L["Reagents"], w = 100, align = "RIGHT" },
        { key = "sell", title = L["Sells for"], w = 100, align = "RIGHT" },
        { key = "profit", title = L["Profit"], w = 112, align = "RIGHT", bar = true },
        { key = "margin", title = L["Margin"], w = 64, align = "RIGHT" },
        { key = "demand", title = L["Sells/day"], w = 64, align = "RIGHT" },
        { key = "trend", title = L["7 days"], w = 64, align = "RIGHT" },
    },
    rows = function() return byProf(GP:CraftRows()) end,
    bar = function(r) return #r.missing > 0 and 0 or r.profit end,
    cells = function(r)
        local name = (r.outQty > 1 and string.format("%s x%g", itemName(r.out), r.outQty) or itemName(r.out))
        if r.usesFarm then name = name .. L[" |cff88ccfffarm|r"] end
        return {
            name = name, icon = GP.ItemIcon(r.out), prof = grey(r.prof and L[r.prof] or ""),
            cost = #r.missing > 0 and L["|cffff9944no price|r"] or Coins(r.cost, true),
            sell = Coins(r.sell, true),
            profit = #r.missing > 0 and "|cffff9944?|r" or Coins(r.profit, true),
            margin = #r.missing > 0 and grey("–") or pct(r.margin, true), demand = demandCell(r.out), trend = pct(r.trend, true),
        }
    end,
    hero = function(rows)
        local b, unpriced = nil, 0
        for _, r in ipairs(rows) do
            if #r.missing > 0 then unpriced = unpriced + 1
            elseif not b or r.profit > b.profit then b = r end
        end
        local tail = unpriced > 0 and grey(string.format(L["   ·   %d need a reagent price: visit a trade goods vendor or scan the AH"], unpriced)) or ""
        if not b or b.profit <= 0 then return unpriced > 0 and grey(string.format(L["%s a reagent price: visit a trade goods vendor (thread, dyes...) or scan the AH."], plural(unpriced, "recipe needs", "recipes need"))) or nil end
        return string.format(L["Best craft:  %s   |cff5fd35f+%s|r each%s"], itemName(b.out), Coins(b.profit, true), tail)
    end,
    empty = L["No recipes yet.\n\nOpen each of your profession windows once. Haulwise reads your recipes and works out what every craft costs and earns at your auction house."],
    click = function(r)
        if IsShiftKeyDown and IsShiftKeyDown() then GP:SearchAH(r.out) else GP:AddToShopping(r.key, 1) end
    end,
    toggles = {
        viewToggle("craft", "skill", L["Skill up"], L["Show the cheapest recipes to raise your professions right now, instead of the most profitable ones."]),
        profToggle(),
        trainerButton(),
        { kind = "cycle", label = function() return L["Queue best 5"] end,
          click = function() GP:QueueBest(5) end,
          tip = function() return L["Put your 5 most profitable crafts in the queue, as many as sell in about 2 days. Open the profession and the queue shows beside it."] end },
    },
    extraTip = L["Your shopping list: reagents for the crafts you picked, what you have and where to buy the rest."],
    extraButton = function(b)
        b:SetLabel(L["Shopping list"])
        b:SetScript("OnClick", function() GP:ToggleShopping() end)
    end,
    tooltip = function(t, r)
        t:SetItemByID(r.out)
        t:AddLine(" ")
        t:AddDoubleLine("|cffffd040Haulwise|r", L["Click: add to shopping list  ·  Shift-click: search AH"], 1, 1, 1, 0.6, 0.6, 0.6)
        for _, rg in ipairs(r.reagents) do
            local unit, where = GP:BuyCost(rg[1])
            t:AddDoubleLine(string.format("  |T%s:14|t %s x%g", GP.ItemIcon(rg[1]), itemName(rg[1]), rg[2]),
                unit and (Coins(unit * rg[2]) .. grey(" " .. where)) or L["|cffff9944no price|r"])
        end
        t:AddDoubleLine(L["Sells for (after AH cut)"], Coins(r.sell), 0.7, 0.7, 0.7)
        t:AddDoubleLine(L["Profit"], Coins(r.profit), 0.7, 0.7, 0.7)
        if r.listed then t:AddDoubleLine(L["On the AH now"], tostring(r.listed), 0.7, 0.7, 0.7) end
        if #r.missing > 0 then t:AddLine(L["Visit a vendor or scan the AH to price the missing reagents."], 1, 0.6, 0.3, true) end
    end,
}

local MIN_STEPS = { 1000, 2000, 5000, 10000, 50000 }
TAB.deals = {
    cols = {
        { key = "name", title = L["Item"], w = 236, icon = true },
        { key = "kind", title = L["Deal"], w = 104 },
        { key = "units", title = L["Units"], w = 50, align = "RIGHT" },
        { key = "buy", title = L["Buy at"], w = 96, align = "RIGHT" },
        { key = "target", title = L["Worth"], w = 96, align = "RIGHT" },
        { key = "profit", title = L["Profit"], w = 112, align = "RIGHT", bar = true },
        { key = "roi", title = "ROI", w = 60, align = "RIGHT" },
        { key = "basis", title = L["Based on"], w = 96 },
    },
    rows = function() return GP:Deals() end,
    bar = function(r) return r.profit end,
    cells = function(r)
        return {
            name = itemName(r.id), icon = GP.ItemIcon(r.id),
            kind = r.kind == "flip" and L["|cff5fd35fVendor flip|r"] or r.vendorSafe and L["|cff5fd35fBelow vendor|r"]
                or (r.isRecipe and L["|cffcc88ffCheap recipe|r"] or L["Below market"]),
            units = tostring(r.units), buy = Coins(r.buy, true), target = Coins(r.target, true),
            profit = Coins(r.profit, true), roi = pct(r.roi),
            basis = r.kind == "flip" and grey(L["vendor price"]) or (r.days and r.days >= 3 and grey(r.days .. L[" days"]) or L["|cffff99441 scan|r"]),
        }
    end,
    hero = function(rows)
        if #rows == 0 then return L["No deals right now.  "] .. grey(L["Scan the AH to find them."]) end
        local sum = 0
        for _, r in ipairs(rows) do sum = sum + r.profit end
        local days = 0
        for _ in pairs(GP.db.scanDays or {}) do days = days + 1 end
        local note = days < 3 and grey(string.format(L["Click a row to search the AH.  Rare items show up after 3 days of scans (%d so far)."], days))
            or grey(L["Click a row to search the AH."])
        return string.format(L["%s worth |cff5fd35f%s|r in total.  %s"], plural(#rows, "deal"), Coins(sum, true), note)
    end,
    empty = L["No deals right now.\n\nScan the auction house (button at the bottom). Deals are listings 30%+ below an item's usual price, and vendor flips: items listed for less than a vendor pays.\n\nThe usual price of rare items (recipes, single listings) needs 3 days of scans, so those show up from day 3."],
    click = function(r) GP:SearchAH(r.id) end,
    toggles = { { L["Include gear"], "dealsGear", L["Weapons and armor have random stats per listing, so prices jump around. Off by default."] } },
    extraTip = L["Hide deals that make less than this."],
    extraButton = function(b)
        local m = S().minProfit or 2000
        b:SetLabel(L["Min profit: "] .. Coins(m, true))
        b:SetScript("OnClick", function()
            local cur = S().minProfit or 2000
            local nxt = MIN_STEPS[1]
            for i, v in ipairs(MIN_STEPS) do if v == cur then nxt = MIN_STEPS[i % #MIN_STEPS + 1] end end
            S().minProfit = nxt
            GP:RefreshUI()
        end)
    end,
    tooltip = function(t, r)
        t:SetItemByID(r.id)
        t:AddLine(" ")
        t:AddLine(L["|cffffd040Haulwise|r  Cheapest listings:"])
        for i, l in ipairs(GP:Cheapest(r.id)) do t:AddDoubleLine("  " .. l.c .. " x", Coins(l.u)) end
        local market, days = GP:MarketValue(r.id)
        if market then t:AddDoubleLine(L["Usual price"], Coins(market) .. grey(days >= 3 and (" (" .. days .. L[" days)"]) or L[" (this scan)"])) end
        local v = GP:VendorSell(r.id)
        if v > 0 then t:AddDoubleLine(L["Vendor pays"], Coins(v)) end
        if r.vendorSafe then t:AddLine(L["No risk: a vendor pays more than these cost, even if they don't resell."], 0.4, 0.9, 0.4, true) end
        if r.kind ~= "flip" and (not r.days or r.days < 3) then
            t:AddLine(L["Based on one scan only: check the price yourself before buying."], 1, 0.6, 0.3, true)
        end
    end,
}

TAB.recipes = {
    cols = {
        { key = "name", title = L["Recipe"], w = 240, icon = true },
        { key = "prof", title = L["Profession"], w = 100 },
        { key = "skill", title = L["Skill"], w = 60, align = "RIGHT" },
        { key = "profit", title = L["Profit per craft"], w = 120, align = "RIGHT", bar = true },
        { key = "get", title = L["How to get it"], w = 290 },
        { key = "pay", title = L["Pays back"], w = 110, align = "RIGHT" },
    },
    rows = function() return byProf(GP:RecipeRows()) end,
    bar = function(r) return (#(r.missing or {}) == 0 and r.profit) or 0 end,
    cells = function(r)
        local parts = {}
        for i, src in ipairs(r.sources or {}) do
            if i > 2 then parts[#parts + 1] = grey("+" .. (#r.sources - 2) .. L[" more"]); break end
            parts[#parts + 1] = GP.SourceShort(src)
        end
        if #parts == 0 and r.buyPrice then parts[1] = L["|cff88ccffAH|r "] .. Coins(r.buyPrice, true) end
        local get = #parts > 0 and table.concat(parts, grey("  ·  ")) or grey(L["not seen yet: visit trainers and vendors"])
        local pay
        if r.payback then pay = (r.payback <= 5 and "|cff5fd35f" or "") .. plural(r.payback, "craft") .. "|r"
        elseif r.kind == "ahonly" then pay = grey(L["open profession"]) end
        return {
            name = r.name or "?", icon = r.out and GP.ItemIcon(r.out) or (r.itemID and GP.ItemIcon(r.itemID)) or 134939,
            prof = grey(r.prof and L[r.prof] or ""),
            skill = r.skill and ((not r.myRank and "|cffffffff") or (r.skill <= r.myRank and "|cff5fd35f")
                or (r.skill <= r.myRank + 30 and "|cffffd040") or "|cffff6b5b") .. (r.skillExact and "" or "~") .. r.skill .. "|r" or grey("?"),
            profit = (r.noSale and grey(L["no AH price"])) or ((r.profit and #(r.missing or {}) == 0) and Coins(r.profit, true)) or grey(L["unknown"]),
            get = get, pay = pay or grey("–"),
        }
    end,
    hero = function(rows)
        -- The quickest payback, whatever the sort; one that takes hundreds of crafts isn't a tip.
        local best
        for _, r in ipairs(rows) do
            if r.payback and r.payback <= 100 and (not best or r.payback < best.payback) then best = r end
        end
        if best then
            return string.format(L["Worth learning:  |cffffffff%s|r   pays for itself after |cff5fd35f%s|r"], best.name, plural(best.payback, "craft"))
        end
        if #rows == 0 then return nil end
        return string.format(L["%s you don't know yet.  %s"], plural(#rows, "recipe"),
            grey(L["Visit trainers and vendors to see where to get them, and scan the AH to see what they earn."]))
    end,
    empty = L["No recipes to suggest yet.\n\nOpen your profession windows once and scan the AH. Recipes you don't know yet are ranked by profit per craft and how fast they pay for themselves."],
    toggles = {
        profToggle(),
        { L["Show recipes far above my skill"], "recipesShowAll", L["Recipes that need 30+ more skill than you have are hidden. Skill comes from trainers, the recipe's tooltip, or (with ~) a guess from the level the crafted gear needs."] },
    },
    click = function(r)
        if IsShiftKeyDown and IsShiftKeyDown() then
            if r.itemID then GP:SearchAH(r.itemID) end
        elseif not GP:GoToRecipe(r) and r.itemID then
            GP:SearchAH(r.itemID)
        end
    end,
    tooltip = function(t, r)
        if r.out then t:SetItemByID(r.out) else t:AddLine(r.name or "?", 1, 1, 1) end
        t:AddLine(" ")
        t:AddLine(L["|cffffd040Haulwise|r: how to get it"], 1, 1, 1)
        if r.sources and #r.sources > 0 then
            for _, src in ipairs(r.sources) do
                local left, right = GP.SourceLong(src)
                t:AddDoubleLine("  " .. left, right, 0.85, 0.85, 0.85, 1, 1, 1)
            end
        else
            t:AddLine(L["  Not seen yet. Open profession trainers and vendors that sell recipes, and Haulwise remembers what they offer."], 0.6, 0.6, 0.6, true)
        end
        if r.src then t:AddLine(r.src, 0.85, 0.85, 0.85, true) end
        if r.learnCost then t:AddDoubleLine(L["Cheapest way to learn it"], Coins(r.learnCost)) end
        if r.profit then t:AddDoubleLine(L["Profit per craft"], Coins(r.profit)) end
        if r.noSale then
            if r.reagentCost and r.reagentCost > 0 then t:AddDoubleLine(L["Reagents cost"], Coins(r.reagentCost)) end
            t:AddLine(L["Nobody sells the result on your AH (it may bind when made), so there's no profit to show."], 0.6, 0.6, 0.6, true)
        end
        if r.buyPrice then t:AddDoubleLine(L["Recipe on AH"], Coins(r.buyPrice)) end
        if r.kind == "ahonly" then t:AddLine(L["Open this profession's window so Haulwise can price what the recipe makes."], 1, 0.6, 0.3, true) end
        t:AddLine(" ")
        local dest = GP:RecipeDestination(r)
        if dest then
            t:AddLine(string.format(L["Click: waypoint to %s (%s)"], dest.name, GP.MapName(dest.map)), 0.6, 0.6, 0.6, true)
        elseif r.prof then
            t:AddLine(string.format(L["Click: waypoint to the nearest %s trainer"], L[r.prof]), 0.6, 0.6, 0.6, true)
        end
        t:AddLine(L["Shift-click: search the AH"], 0.6, 0.6, 0.6)
    end,
}

TAB.market = {
    cols = {
        { key = "name", title = L["Item"], w = 250, icon = true },
        { key = "why", title = "", w = 130 },
        { key = "price", title = L["Price now"], w = 100, align = "RIGHT" },
        { key = "market", title = L["Usual"], w = 100, align = "RIGHT" },
        { key = "change", title = L["7 days"], w = 100, align = "RIGHT", bar = true },
        { key = "tip", title = L["Tip"], w = 110 },
    },
    rows = function() return GP:MarketRows() end,
    bar = function(r) return r.change end,
    cells = function(r)
        local tipColor = (r.tip == "Sell now" or r.tip == "Stock up") and "|cff5fd35f" or (r.tip == "Steady" and "|cff8a8880" or "|cffffd060")
        return {
            name = itemName(r.id), icon = GP.ItemIcon(r.id), why = grey(r.why and L[r.why] or ""),
            price = Coins(r.price, true), market = r.market and grey(Coins(r.market, true)) or grey("–"),
            change = pct(r.change, true), tip = tipColor .. L[r.tip] .. "|r",
        }
    end,
    hero = function()
        local p, need = GP:WeekdayPattern()
        if p and p.flat then return grey(L["No clear weekday pattern on your AH: prices are about the same every day."]) end
        if p then
            return string.format(L["Your AH is cheapest on |cffffffff%s|r and dearest on |cffffffff%s|r (%.0f%% apart): buy on %s, sell on %s."],
                p.cheapest, p.dearest, p.spread * 100, p.cheapest, p.dearest)
        end
        return grey(string.format(L["Weekday pattern: scan on %d more days to see which day your AH is cheapest."], need or 14))
    end,
    toggles = { viewToggle("market", "sales", L["Your sales"], L["What you've sold on the auction house and earned, from the invoices in your mail."]) },
    -- How far along the scans are. A trend compares the last 3 days with 6-13 days ago (see
    -- GP:Trend), so what counts is how old your oldest scan is, not how many days you scanned.
    empty = function()
        local left, oldest = GP:TrendDaysLeft()
        local today = GP.db.scanDays and GP.db.scanDays[GP.Day()]
        local next = today and L["Today's scan is counted: scan again tomorrow."] or L["Scan today to count another day."]
        if not oldest then
            return L["No trends yet: open the auction house and press Scan AH to start."]
        end
        if left > 0 then
            return string.format(L["No trends yet: they compare the last 3 days with the week before, so they need a scan from at least 6 days ago. Your oldest scan is |cffffffff%s|r old.\n\nKeep scanning and trends show up in |cffffffff%s|r: what's rising, what's falling, and when to sell what you farm and craft. %s"],
                plural(GP.Day() - oldest, "day"), plural(left, "day"), next)
        end
        return string.format(L["No trends yet: there's no scan from the last 3 days to compare with. %s"], next)
    end,
    click = function(r) GP:SearchAH(r.id) end,
    tooltip = function(t, r)
        t:SetItemByID(r.id)
        t:AddLine(" ")
        t:AddLine(L["|cffffd040Haulwise|r price history:"])
        local h = GP:History(r.id)
        for i = math.max(1, #h - 9), #h do
            local e = h[i]
            t:AddDoubleLine("  " .. date("%a %d %b", e.d * 86400 + 43200), Coins(e.p) .. grey("  " .. e.q .. L[" listed"]))
        end
    end,
}

-- Market → Your sales: what sold and what it earned, from the mail invoices (Sales.lua).
local function when(t)
    local d = GP.Day() - GP.Day(t)
    if d <= 0 then return L["today"] elseif d == 1 then return L["yesterday"] end
    return string.format(L["%d days ago"], d)
end
TAB.market_sales = {
    cols = {
        { key = "name", title = L["Item"], w = 250, icon = true },
        { key = "count", title = L["Sold"], w = 60, align = "RIGHT" },
        { key = "each", title = L["Each"], w = 100, align = "RIGHT" },
        { key = "earned", title = L["Earned"], w = 120, align = "RIGHT", bar = true },
        { key = "last", title = L["Last sold"], w = 100, align = "RIGHT" },
        { key = "who", title = L["By"], w = 130 },
    },
    rows = function() return GP:SalesRows(30) end,
    bar = function(r) return r.earned end,
    cells = function(r)
        return {
            name = r.id and itemName(r.id) or (r.name or "?"), icon = r.id and GP.ItemIcon(r.id) or 134400,
            count = tostring(r.count), each = Coins(r.each, true), earned = Coins(r.earned, true),
            last = grey(when(r.last)), who = grey(r.who),
        }
    end,
    hero = function()
        local today = GP:SalesTotal(0)
        local week, wn = GP:SalesTotal(6)
        local month = GP:SalesTotal(29)
        return string.format(L["Earned today |cff5fd35f%s|r   ·   last 7 days |cff5fd35f%s|r (%s)   ·   30 days %s"],
            Coins(today, true), Coins(week, true), plural(wn, "item"), Coins(month, true))
    end,
    empty = L["No sales logged yet.\n\nWhen an auction sells, the gold comes by mail. Open a mailbox and Haulwise logs every sale from the invoices: what sold, for how much after the AH cut, and when."],
    click = function(r) if r.id then GP:SearchAH(r.id) end end,
    toggles = { viewToggle("market", "sales", L["Your sales"], L["What you've sold on the auction house and earned, from the invoices in your mail."]) },
    tooltip = function(t, r)
        if r.id then t:SetItemByID(r.id) else t:AddLine(r.name or "?") end
        t:AddLine(" ")
        t:AddLine(L["|cffffd040Haulwise|r  your sales (after the AH cut):"])
        for i, s in ipairs(r.sales) do
            if i > 10 then t:AddLine(grey(string.format(L["  and %d more"], #r.sales - 10))); break end
            t:AddDoubleLine("  " .. date("%a %d %b", s.t) .. grey("  " .. (s.ch or "")), math.max(1, s.c or 1) .. " x  " .. Coins(s.g))
        end
    end,
}

TAB.bags = {
    cols = {
        { key = "name", title = L["Item (cheapest first)"], w = 260, icon = true },
        { key = "count", title = L["Count"], w = 54, align = "RIGHT" },
        { key = "unit", title = L["Each"], w = 96, align = "RIGHT" },
        { key = "total", title = L["Worth"], w = 112, align = "RIGHT", bar = true },
        { key = "src", title = L["From"], w = 52, align = "CENTER" },
        { key = "status", title = L["Best move"], w = 210 },
    },
    rows = function()
        local rows = GP:BagItems()
        table.sort(rows, function(a, b)
            if (a.protect ~= nil) ~= (b.protect ~= nil) then return a.protect == nil end
            if a.total ~= b.total then return a.total < b.total end
            return a.id < b.id
        end)
        return rows
    end,
    bar = function(r) return r.total end,
    cells = function(r)
        local status
        if r.protect then
            status = (r.protect == "kept" and L["|cff88ccffkept (shift-click to release)|r"]) or (L["|cff8a8880protected: "] .. L[r.protect] .. "|r")
        else
            status = GP:BagAdvice(r) .. grey(L["  ·  can go"])
        end
        return {
            name = itemName(r.id), icon = GP.ItemIcon(r.id), count = r.count > 1 and tostring(r.count) or "",
            unit = Coins(r.unit, true), total = Coins(r.total, true), src = GP.SourceTag(r.src, r.d), status = status,
        }
    end,
    hero = function(rows)
        local free, total = GP:FreeSlots(), GP:TotalSlots()
        local t = GP:Totals()
        return string.format(L["%s%d|r/%d free   ·   gold %s + bags %s %s = |cffffffffTotal %s|r   %s"],
            free == 0 and "|cffff6b5b" or "|cff5fd35f", free, total, Coins(t.gold, true), Coins(t.best, true),
            grey(L["(AH "] .. Coins(t.bySrc.AH or 0, true) .. L[", DE "] .. Coins(t.bySrc.DE or 0, true) .. L[", vendor "] .. Coins(t.bySrc.V or 0, true) .. ")"),
            Coins(t.total, true), "")
    end,
    empty = L["Your bags are empty."],
    click = function(r)
        if IsShiftKeyDown and IsShiftKeyDown() then
            if GP.db.keep[r.id] then GP.db.keep[r.id] = nil else GP.db.keep[r.id] = true end
            GP:RefreshUI()
            if GP.RefreshHUD then GP:RefreshHUD() end
        end
    end,
    tooltip = function(t, r)
        t:SetHyperlink(r.link)
        GP.AddValueLines(t, r.unit, r.src, r.d, r.count)
        if r.protect then t:AddLine(L["Never offered for deletion: "] .. L[r.protect], 0.53, 0.8, 1, true) end
        t:AddLine(L["Shift-click: "] .. (GP.db.keep[r.id] and L["stop keeping it"] or L["always keep it"]), 0.6, 0.6, 0.6)
    end,
    toggles = {
        { L["Disenchant value"], "useDisenchant", L["Value green, blue and purple gear at what disenchanting it gives, when you or one of your characters can disenchant it."] },
        { L["Disenchant for mats"], "deForMats", L["Level Enchanting: gear you can disenchant yourself is marked to disenchant (and gets the Disenchant button) even when selling pays more. Off: always the move that makes the most gold."] },
        { L["Protect reagents"], "protectReagents", L["Never offer items your known recipes use. (Crafting materials, dust, essences, shards, cloth, leather, ore, herbs, gems and recipes are never offered at all.)"] },
    },
    extraTip = L["Delete the cheapest items, one click at a time."],
    extraButton = function(b)
        b:SetLabel(L["Make room"])
        b:SetScript("OnClick", function() GP:ShowMakeRoom() end)
    end,
}

TAB.gear = {
    cols = {
        { key = "name", title = L["Item in your bags"], w = 250, icon = true },
        { key = "who", title = L["For"], w = 110 },
        { key = "slot", title = L["Slot"], w = 90 },
        { key = "gain", title = L["Better by"], w = 100, align = "RIGHT", bar = true },
        { key = "replaces", title = L["Replaces"], w = 230 },
        { key = "lvl", title = "", w = 90 },
    },
    rows = function()
        local rows = {}
        for _, r in ipairs(GP.upgrades.mine) do r.forMe = true; rows[#rows + 1] = r end
        for _, r in ipairs(GP.upgrades.alts) do r.forMe = false; rows[#rows + 1] = r end
        return rows
    end,
    bar = function(r) return math.min(r.gain or 0, 2) end,
    cells = function(r)
        local rep = r.replaces and itemName(tonumber(r.replaces:match("item:(%d+)"))) or grey(L["empty slot"])
        return {
            name = (GP.ItemInfo(r.id) and itemName(r.id)) or (r.name and ("|cff1eff00" .. r.name .. "|r")) or itemName(r.id),
            icon = GP.ItemIcon(r.id),
            who = r.forMe and L["|cff5fd35fYou|r"] or ("|cffff9944" .. (r.alt or "?") .. "|r"),
            slot = grey(r.slotName or ""),
            gain = r.replaces and string.format("|cff5fd35f+%.0f%%|r", (r.gain or 0) * 100) or L["|cff5fd35fnew|r"],
            replaces = rep, lvl = r.atLevel and (L["|cffff9944at level "] .. r.atLevel .. "|r") or "",
        }
    end,
    hero = function(rows)
        local mine, alts = #GP.upgrades.mine, #GP.upgrades.alts
        if mine + alts == 0 then return L["No upgrades in your bags.  "] .. grey(L["New gear is checked as you loot it."]) end
        return string.format(L["|cff5fd35f%s|r for you, |cffff9944%d|r for your alts.  %s"], plural(mine, "upgrade"), alts,
            grey(L["Click: equip (you) or attach to mail (alts, at a mailbox)."]))
    end,
    empty = L["No upgrades in your bags.\n\nHaulwise checks every piece of gear you pick up with stat weights for your talent tree, and also for your other characters (log in on each once so Haulwise knows their gear)."],
    click = function(r)
        if r.forMe then GP:Equip(r)
        elseif MailFrame and MailFrame:IsShown() and GP.AttachToMail then GP.AttachToMail(r)
        else GP.Print(L["Open a mailbox to send this to "] .. (r.alt or L["your alt"]) .. ".") end
    end,
    tooltip = function(t, r)
        t:SetHyperlink(r.link)
        t:AddLine(" ")
        t:AddLine(string.format(L["|cffffd040Haulwise|r: %s +%.0f%%"], r.forMe and L["upgrade for you"] or (L["upgrade for "] .. (r.alt or "?")),
            (r.gain or 0) * 100), 1, 1, 1)
        t:AddLine(L["Weights: "] .. (r.label or "?"), 0.6, 0.6, 0.6)
        for i, d in ipairs(GP.StatDiff(r.link, r.replaces)) do
            if i > 8 then break end
            local delta = d[3] - d[2]
            t:AddDoubleLine("  " .. d[1], string.format("%s → %s  %s%+d|r", d[2], d[3], delta >= 0 and "|cff5fd35f" or "|cffff6b5b", delta),
                0.75, 0.75, 0.75, 1, 1, 1)
        end
    end,
    toggles = {
        viewToggle("gear", "ah", L["On the AH"], L["Show gear upgrades for you and your alts that are for sale on the auction house (from your last full scan), ranked by how much upgrade each gold buys."]),
        pawnToggle(),
        { L["Upgrade Advisor"], "upgradeAdvisor", L["Check gear you pick up against what you wear."] },
        { L["Upgrade popups"], "upgradePopups", L["Show a popup when new loot is an upgrade (once per item)."] },
        { L["Send to alts at mailbox"], "sendToAltsAtMailbox", L["At a mailbox, list gear that's an upgrade for one of your alts."] },
    },
    extraTip = L["Which stat weights to use. With Pawn installed, Haulwise uses the Pawn scales you have switched on for this character. Click to switch to Haulwise's own weights per talent tree, and back."],
    extraButton = function(b)
        local label = GP:WeightsLabel()
        if #label > 22 then label = label:sub(1, 21) .. "…" end
        b:SetLabel(label)
        b:SetScript("OnClick", function() GP:CycleSpec() end)
    end,
}

local holdChar, holdLoc
local function locToggle(label, loc)
    return { label, "_loc_" .. (loc or "all"), nil,
             tip = function() return L["Show items in "] .. (loc and L[GP.LOCATION_LABEL[loc]] or L["all places"]) .. "." end,
             get = function() return holdLoc == loc end, set = function() holdLoc = loc end }
end
TAB.holdings = {
    cols = {
        { key = "name", title = L["Item"], w = 260, icon = true },
        { key = "count", title = L["Count"], w = 60, align = "RIGHT" },
        { key = "where", title = L["Where"], w = 400 },
        { key = "value", title = L["Worth"], w = 112, align = "RIGHT", bar = true },
    },
    rows = function() return (GP:HoldingsRows(holdChar, holdLoc)) end,
    bar = function(r) return r.value end,
    cells = function(r)
        local parts = {}
        for i, w in ipairs(r.where) do
            if i > 4 then parts[#parts + 1] = "…"; break end
            local cc = RAID_CLASS_COLORS and w.classFile and RAID_CLASS_COLORS[w.classFile]
            local who = cc and cc.colorStr and ("|c" .. cc.colorStr .. w.char .. "|r") or ("|cffffffff" .. w.char .. "|r")
            parts[#parts + 1] = string.format("%s %s %s", who, grey("· " .. L[GP.LOCATION_LABEL[w.loc]]), w.n)
        end
        return { name = itemName(r.id), icon = GP.ItemIcon(r.id), count = tostring(r.count), where = table.concat(parts, grey("   |   ")),
                 value = r.worn and grey("worn") or Coins(r.value, true) }
    end,
    hero = function()
        local _, items = GP:HoldingsRows(holdChar, holdLoc)
        local gold, mail = GP:HoldingsGold()
        return string.format(L["Gold %s   ·   items worth %s %s   ·   gold in mail %s"],
            Coins(gold, true), Coins(items, true), grey(L["(not counting gear you wear)"]), Coins(mail, true))
    end,
    empty = L["Nothing here yet.\n\nLog in on each character once. Bank, mail and auctions are read when you open them."],
    click = function(r) GP:SearchAH(r.id) end,
    tooltip = function(t, r)
        t:SetItemByID(r.id)
        t:AddLine(" ")
        for _, w in ipairs(r.where) do t:AddDoubleLine("  " .. w.char .. "  " .. L[GP.LOCATION_LABEL[w.loc]], tostring(w.n), 0.8, 0.8, 0.8, 1, 1, 1) end
        t:AddDoubleLine(L["Worth"], r.worn and L["worn, not for sale"] or Coins(r.value))
        if not r.worn and r.sellable < r.count then t:AddLine(L["Only the ones you don't wear are counted."], 0.6, 0.6, 0.6) end
    end,
    toggles = {
        locToggle(L["All"], nil), locToggle(L["Bags"], "bags"), locToggle(L["Bank"], "bank"), locToggle(L["Equipped"], "equipped"),
        locToggle(L["Mail"], "mail"), locToggle(L["Auction"], "ah"),
    },
    extraTip = L["Show one character, or all of them (same realm and faction)."],
    extraButton = function(b)
        local keys = {}
        local realm = GetRealmName and GetRealmName() or "?"
        for key, c in pairs(GP.db.chars) do if c.short and c.realm == realm then keys[#keys + 1] = key end end
        table.sort(keys)
        local label = holdChar and (GP.db.chars[holdChar] and GP.db.chars[holdChar].short or holdChar) or L["All characters"]
        b:SetLabel(label)
        b:SetScript("OnClick", function()
            local idx = 0
            for i, k in ipairs(keys) do if k == holdChar then idx = i end end
            holdChar = keys[idx + 1]
            GP:RefreshUI()
        end)
    end,
}

-- Gear → On the AH: upgrades for sale, from the last full scan.
local AH_MAX_STEPS = { 0, 10000, 50000, 100000, 250000, 500000, 1000000 }
TAB.gear_ah = {
    cols = {
        { key = "name", title = L["For sale on the AH"], w = 250, icon = true },
        { key = "who", title = L["For"], w = 100 },
        { key = "slot", title = L["Slot"], w = 80 },
        { key = "gain", title = L["Better by"], w = 90, align = "RIGHT", bar = true },
        { key = "price", title = L["Price"], w = 100, align = "RIGHT" },
        { key = "value", title = L["Replaces"], w = 170 },
    },
    rows = function() return GP:AHUpgradeRows() end,
    bar = function(r) return math.min(r.gain or 0, 2) end,
    cells = function(r)
        return {
            name = itemName(r.id), icon = GP.ItemIcon(r.id),
            who = r.forMe and L["|cff5fd35fYou|r"] or ("|cffff9944" .. (r.alt or "?") .. "|r"),
            slot = grey(r.slotName or ""), gain = string.format("|cff5fd35f+%.0f%%|r", (r.gain or 0) * 100),
            price = Coins(r.price, true),
            value = (r.atLevel and (L["|cffff9944at level "] .. r.atLevel .. "|r  ") or "")
                .. (r.replaces and grey(GP.ItemInfo(tonumber(r.replaces:match("item:(%d+)")) or 0) or r.replacesName or "?") or L["|cff88ccffempty slot|r"]),
        }
    end,
    hero = function(rows)
        local d = GP.db.ahUpgrades
        if not d then return L["No AH scan with gear yet.  "] .. grey(L["Open the auction house and press Scan AH."]) end
        local b = rows[1]
        if not b then return L["No gear upgrades for sale"] .. ((S().ahUpgradeMax or 0) > 0 and L[" under your max price."] or ".") .. "  " .. grey(L["Scanned "] .. ago(time() - d.t) .. ".") end
        return string.format(L["Best buy:  %s for %s  |cff5fd35f+%.0f%%|r for %s   %s"], itemName(b.id),
            b.forMe and "you" or ("|cffff9944" .. (b.alt or "?") .. "|r"), b.gain * 100, Coins(b.price, true),
            grey(L["·  scanned "] .. ago(time() - d.t) .. L["  ·  click a row to buy it"]))
    end,
    empty = function()
        local text = L["No gear upgrades found on the auction house.\n\nOpen the auction house and press Scan AH. Haulwise checks every piece of gear for sale against what you and your alts wear (log in on each alt once), and ranks them by how much upgrade each gold buys."]
        local d = GP.db.ahUpgrades
        if d and d.listings and d.listings > 0 then
            text = text .. "\n\n" .. string.format(L["Last scan: checked %d of %d gear listings."], d.checked or 0, d.listings)
            if (d.unloaded or 0) > 0 then
                text = text .. " " .. string.format(L["The game didn't send the stats of %d: scan again later and more get checked."], d.unloaded)
            end
        end
        return text
    end,
    -- At the AH: find this exact listing (same suffix) and open the confirm box. Elsewhere: search.
    click = function(r)
        if GP.ahOpen then
            GP:ShopBuy({ id = r.id, buy = 1, link = r.link, usual = r.price, auto = true, onBought = function()
                -- Bought: off the list (from now on it's in your bags, where the Upgrade Advisor sees it).
                local d = GP.db.ahUpgrades
                for i = #(d and d.rows or {}), 1, -1 do if d.rows[i].link == r.link then table.remove(d.rows, i) end end
                GP:RefreshUI()
            end })
        else
            GP:SearchAH(r.id)
            GP.Print(L["Open the auction house, then click it again to buy it."])
        end
    end,
    tooltip = function(t, r)
        t:SetHyperlink(r.link)
        t:AddLine(" ")
        t:AddLine(string.format(L["|cffffd040Haulwise|r: %s +%.0f%% for %s"], r.forMe and L["upgrade for you"] or (L["upgrade for "] .. (r.alt or "?")),
            (r.gain or 0) * 100, Coins(r.price, true)), 1, 1, 1)
        t:AddLine(L["Weights: "] .. (r.label or "?"), 0.6, 0.6, 0.6)
        for i, d in ipairs(GP.StatDiff(r.link, r.replaces)) do
            if i > 8 then break end
            local delta = d[3] - d[2]
            t:AddDoubleLine("  " .. d[1], string.format("%s → %s  %s%+d|r", d[2], d[3], delta >= 0 and "|cff5fd35f" or "|cffff6b5b", delta),
                0.75, 0.75, 0.75, 1, 1, 1)
        end
        t:AddLine(L["Click at the AH: finds this exact listing and asks you to confirm the price. Nothing is bought without your click."], 0.6, 0.6, 0.6, true)
    end,
    toggles = {
        viewToggle("gear", "ah", L["On the AH"], L["Show gear upgrades for you and your alts that are for sale on the auction house (from your last full scan), ranked by how much upgrade each gold buys."]),
        pawnToggle(),
    },
    extraTip = L["Hide listings above this price."],
    extraButton = function(b)
        local m = S().ahUpgradeMax or 0
        b:SetLabel(m == 0 and L["Max price: any"] or (L["Max price: "] .. Coins(m, true)))
        b:SetScript("OnClick", function()
            local idx = 1
            for i, v in ipairs(AH_MAX_STEPS) do if v == m then idx = i end end
            S().ahUpgradeMax = AH_MAX_STEPS[idx % #AH_MAX_STEPS + 1]
            GP:RefreshUI()
        end)
    end,
}

-- Craft → Skill up: the cheapest recipes to raise your profession right now.
TAB.craft_skill = {
    cols = {
        { key = "name", title = L["Recipe"], w = 230, icon = true },
        { key = "prof", title = L["Profession"], w = 104 },
        { key = "color", title = L["Colour"], w = 70 },
        { key = "chance", title = L["Skill-up"], w = 70, align = "RIGHT" },
        { key = "cost", title = L["Reagents"], w = 96, align = "RIGHT" },
        { key = "back", title = L["Sell result"], w = 96, align = "RIGHT" },
        { key = "point", title = L["Per point"], w = 110, align = "RIGHT", bar = true },
    },
    rows = function() return byProf(GP:SkillRows()) end,
    bar = function(r) return r.perPoint and -r.perPoint or 0 end,
    cells = function(r)
        local col = ({ [0] = L["|cffff8040orange|r"], [1] = L["|cffffff00yellow|r"], [2] = L["|cff40c040green|r"] })[r.d] or grey("?")
        return {
            name = itemName(r.out), icon = GP.ItemIcon(r.out), prof = grey(r.prof and L[r.prof] or ""), color = col,
            chance = grey(string.format("~%.0f%%", r.chance * 100)),
            cost = r.priced and Coins(r.cost, true) or L["|cffff9944no price|r"],
            back = Coins(r.back, true),
            point = r.perPoint and (r.perPoint <= 0 and L["|cff5fd35fprofit|r"] or Coins(r.perPoint, true)) or "|cffff9944?|r",
        }
    end,
    hero = function(rows)
        local b
        for _, r in ipairs(rows) do if r.perPoint then b = r; break end end
        local profs = {}
        for name, p in pairs(GP:MyProfessions()) do
            if p.rank and p.max and GP.RECIPE_SUBCLASS[name] then
                profs[#profs + 1] = string.format("%s %d/%d%s", L[name], p.rank, p.max, p.rank >= p.max and L[" |cffff9944(train!)|r"] or "")
            end
        end
        table.sort(profs)
        local tail = #profs > 0 and grey("   ·   " .. table.concat(profs, "  ·  ")) or ""
        if not b then return grey(L["Open your profession windows to see which recipes still give skill."]) .. tail end
        return string.format(L["Cheapest skill-up:  %s   %s per point%s"], itemName(b.out),
            b.perPoint <= 0 and L["|cff5fd35fearns gold|r"] or Coins(b.perPoint, true), tail)
    end,
    empty = L["No recipes that still give skill.\n\nOpen your profession windows: recipe colours (orange, yellow, green) are read from there. Grey recipes no longer give skill, so they're left out. If everything is grey, visit your trainer."],
    click = function(r)
        if IsShiftKeyDown and IsShiftKeyDown() then GP:SearchAH(r.out) else GP:AddToShopping(r.key, 1) end
    end,
    tooltip = function(t, r)
        t:AddLine(r.name or "?", GOLD[1], GOLD[2], GOLD[3])
        t:AddLine(L["Chances are estimates: orange always gives a point, yellow usually, green rarely. The colour is from the last time you opened the profession window."], 0.8, 0.8, 0.8, true)
        t:AddLine(" ")
        t:AddDoubleLine(L["Reagents"], r.priced and Coins(r.cost) or L["no price"], 0.7, 0.7, 0.7, 1, 1, 1)
        t:AddDoubleLine(L["You get back by selling the result"], Coins(r.back), 0.7, 0.7, 0.7, 1, 1, 1)
        if r.perPoint then t:AddDoubleLine(L["Cost per skill point"], Coins(r.perPoint), 0.7, 0.7, 0.7, 1, 1, 1) end
        t:AddLine(" ")
        t:AddLine(L["Click: add to your shopping list.  Shift-click: search the result on the AH."], 0.6, 0.6, 0.6, true)
    end,
    toggles = {
        viewToggle("craft", "skill", L["Skill up"], L["Show the cheapest recipes to raise your professions right now, instead of the most profitable ones."]),
        profToggle(),
        trainerButton(),
        { kind = "cycle", label = function() return L["Queue best 5"] end,
          click = function() GP:QueueBest(5) end,
          tip = function() return L["Put your 5 most profitable crafts in the queue, as many as sell in about 2 days. Open the profession and the queue shows beside it."] end },
    },
    extraTip = L["Your shopping list: reagents for the crafts you picked, what you have and where to buy the rest."],
    extraButton = function(b)
        b:SetLabel(L["Shopping list"])
        b:SetScript("OnClick", function() GP:ToggleShopping() end)
    end,
}

-- Farm → By zone: where to go, not just which mob.
TAB.farm_zones = {
    cols = {
        { key = "name", title = L["Zone"], w = 190 },
        { key = "lvl", title = L["Lvl"], w = 60, align = "CENTER" },
        { key = "mobs", title = L["Mobs"], w = 56, align = "RIGHT" },
        { key = "kills", title = L["Kills"], w = 60, align = "RIGHT" },
        { key = "best", title = L["Best mob"], w = 200 },
        { key = "est", title = L["Gold/h"], w = 110, align = "RIGHT", bar = true },
        { key = "safe", title = L["Safe/h"], w = 96, align = "RIGHT" },
    },
    rows = function() return GP:ZoneRows() end,
    bar = function(r) return r.est end,
    cells = function(r)
        local lv = r.minL and (r.minL == r.maxL and tostring(r.minL) or (r.minL .. "-" .. r.maxL)) or "?"
        return {
            name = (r.here and "|cff5fd35f" or "|cffffffff") .. GP.ZoneName(r.zone) .. "|r" .. (r.here and grey(L["  (you're here)"]) or ""),
            lvl = lv, mobs = tostring(r.mobs), kills = confColor(r.kills) .. r.kills .. "|r",
            best = r.bestName, est = Coins(r.est, true), safe = grey(Coins(r.safe, true)),
        }
    end,
    hero = function(rows)
        local b = rows[1]
        if not b then return nil end
        local here
        for _, r in ipairs(rows) do if r.here then here = r end end
        -- Same figure the zones are ranked by (Rank button), so the best zone is the top row.
        local key = S().sortBy == "est" and "est" or "safe"
        local tail = (here and here ~= b) and grey(string.format(L["   ·   here in %s: %s/h"], here.zone, Coins(here[key], true))) or ""
        local fmt = key == "safe" and L["Best zone:  |cffffffff%s|r   %s/h safe on %s%s"] or L["Best zone:  |cffffffff%s|r   %s/h on %s%s"]
        return string.format(fmt, GP.ZoneName(b.zone), Coins(b[key], true), b.bestName, tail)
    end,
    empty = L["No kills recorded yet.\n\nGo farm and loot what you kill. Zones are ranked by the best gold per hour you can make there."],
    click = function(r)
        S().farmZone = r.zone
        S().views.farm = nil
        GP.scrollToTop = true
        GP:RefreshUI()
    end,
    tooltip = function(t, r)
        t:AddLine(GP.ZoneName(r.zone), GOLD[1], GOLD[2], GOLD[3])
        for i, m in ipairs(r.list) do
            if i > 8 then break end
            t:AddDoubleLine(m.name, Coins(m.est, true) .. "/h", 1, 1, 1, 1, 1, 1)
        end
        t:AddLine(" ")
        t:AddLine(L["Click: show only this zone's mobs."], 0.6, 0.6, 0.6)
    end,
    toggles = {
        viewToggle("farm", "zones", L["By zone"], L["Rank zones instead of single mobs: the best gold per hour in each zone."]),
        { L["Hide mobs above my level"], "levelWindow", L["Hide mobs more than 2 levels above you, and mobs nobody has killed yet that are more than 10 levels below you."] },
        { L["Community data"], "useShared", L["Add everyone's pooled kills (shipped with the addon) and friends' imports to your own."] },
    },
}

-- Sorting by column ---------------------------------------------------------------------------
-- Each tab says how to get a sortable value per column. Missing values always go last.
local function nm(id) return ((GP.ItemInfo(id)) or ""):lower() end
local function topEarner(r) return r.lines[1] and nm(r.lines[1].id) or "" end

TAB.farm.sort = {
    name = function(r) return r.name:lower() end, zone = function(r) return GP.ZoneName(r.zone):lower() end,
    lvl = function(r) return r.minL end, kills = function(r) return r.kills end, kph = function(r) return r.kph end,
    perKill = function(r) return r.perKill end, est = function(r) return r.est end, safe = function(r) return r.safe end,
    top = topEarner,
}
TAB.bags.sort = {
    name = function(r) return nm(r.id) end, count = function(r) return r.count end, unit = function(r) return r.unit end,
    total = function(r) return r.total end, src = function(r) return r.src end, status = function(r) return r.protect or "" end,
}
TAB.gear.sort = {
    name = function(r) return nm(r.id) end, who = function(r) return r.forMe and "" or (r.alt or ""):lower() end,
    slot = function(r) return r.slotName end, gain = function(r) return r.gain end,
    replaces = function(r) return r.replaces and nm(tonumber(r.replaces:match("item:(%d+)"))) or "" end,
    lvl = function(r) return r.atLevel end,
}
TAB.gear_ah.sort = {
    name = function(r) return nm(r.id) end, who = function(r) return r.forMe and "" or (r.alt or ""):lower() end,
    slot = function(r) return r.slotName end, gain = function(r) return r.gain end, price = function(r) return r.price end,
    value = function(r) return r.replaces and (GP.ItemInfo(tonumber(r.replaces:match("item:(%d+)")) or 0) or ""):lower() or "" end,
}
TAB.craft_skill.sort = {
    name = function(r) return nm(r.out) end, prof = function(r) return r.prof end, color = function(r) return r.d end,
    chance = function(r) return r.chance end, cost = function(r) return r.priced and r.cost or nil end,
    back = function(r) return r.back end, point = function(r) return r.perPoint end,
}
TAB.farm_zones.sort = {
    name = function(r) return GP.ZoneName(r.zone):lower() end, lvl = function(r) return r.minL end, mobs = function(r) return r.mobs end,
    kills = function(r) return r.kills end, best = function(r) return r.bestName:lower() end,
    est = function(r) return r.est end, safe = function(r) return r.safe end,
}
local function priced(r) return #(r.missing or {}) == 0 end
TAB.craft.sort = {
    name = function(r) return nm(r.out) end, prof = function(r) return r.prof end,
    cost = function(r) return priced(r) and r.cost or nil end, sell = function(r) return r.sell end,
    profit = function(r) return priced(r) and r.profit or nil end, margin = function(r) return priced(r) and r.margin or nil end,
    demand = function(r) return (GP:SellSpeed(r.out)) end, trend = function(r) return r.trend end,
}
TAB.deals.sort = {
    name = function(r) return nm(r.id) end, kind = function(r) return r.kind end, units = function(r) return r.units end,
    buy = function(r) return r.buy end, target = function(r) return r.target end, profit = function(r) return r.profit end,
    roi = function(r) return r.roi end, basis = function(r) return r.days end,
}
TAB.recipes.sort = {
    name = function(r) return (r.name or ""):lower() end, prof = function(r) return r.prof end,
    skill = function(r) return r.skill end,
    profit = function(r) return priced(r) and r.profit or nil end, get = function(r) return r.learnCost end,
    pay = function(r) return r.payback end,
}
TAB.market.sort = {
    name = function(r) return nm(r.id) end, why = function(r) return r.why end, price = function(r) return r.price end,
    market = function(r) return r.market end, change = function(r) return r.change end, tip = function(r) return r.tip end,
}
TAB.market_sales.sort = {
    name = function(r) return (r.id and nm(r.id)) or (r.name or ""):lower() end, count = function(r) return r.count end,
    each = function(r) return r.each end, earned = function(r) return r.earned end,
    last = function(r) return r.last end, who = function(r) return r.who:lower() end,
}
TAB.holdings.sort = {
    name = function(r) return nm(r.id) end, count = function(r) return r.count end,
    where = function(r) return #r.where end, value = function(r) return r.worn and -1 or r.value end,
}

function GP:SortBy(key)
    local s = self.db.settings
    s.sorts = s.sorts or {}
    local tab = current()
    local cur = s.sorts[tab]
    if cur and cur.key == key then
        cur.desc = not cur.desc
    else
        -- Numbers start biggest first, words start at A.
        local t = TAB[tab]
        local sample
        for _, r in ipairs(t.rows()) do sample = t.sort[key](r); if sample ~= nil then break end end
        s.sorts[tab] = { key = key, desc = type(sample) == "number" }
    end
    self.scrollToTop = true
    self:RefreshUI()
end

function GP:ApplySort(t, rows)
    local cur = self.db.settings.sorts and self.db.settings.sorts[current()]
    if not (cur and t.sort and t.sort[cur.key]) then return end
    local get = t.sort[cur.key]
    local keyed = {}
    for i, r in ipairs(rows) do
        local v = get(r)
        if type(v) == "boolean" then v = v and 1 or 0 end
        keyed[i] = { r = r, v = v, i = i }
    end
    table.sort(keyed, function(a, b)
        if a.v == nil or b.v == nil then
            if (a.v == nil) ~= (b.v == nil) then return b.v == nil end
            return a.i < b.i
        end
        if type(a.v) ~= type(b.v) then a.v, b.v = tostring(a.v), tostring(b.v) end
        if a.v ~= b.v then
            if cur.desc then return a.v > b.v else return a.v < b.v end
        end
        return a.i < b.i
    end)
    for i, k in ipairs(keyed) do rows[i] = k.r end
end

-- Window -------------------------------------------------------------------------------------

local f, rows, offset, data = nil, {}, 0, {}
local tabButtons, toggleBar = {}, {}
local updateDisenchant -- defined below RefreshUI's helpers


local function makeRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 12, -(176 + (i - 1) * ROW_H))
    row:SetPoint("RIGHT", -16, 0)
    if i % 2 == 0 then tex(row, "BACKGROUND", C.zebra):SetAllPoints() end
    row.hoverBg = tex(row, "BACKGROUND", C.hover)
    row.hoverBg:SetAllPoints()
    row.hoverBg:Hide()
    row.bar = tex(row, "BORDER", C.bar)
    row.bar:SetHeight(ROW_H - 6)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.cells = {}
    for c = 1, 9 do
        local fs = row:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
        fs:SetWordWrap(false)
        row.cells[c] = fs
    end
    row:SetScript("OnEnter", function(self)
        self.hoverBg:Show()
        local t = TAB[current()]
        if self.data and t.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            t.tooltip(GameTooltip, self.data)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self) self.hoverBg:Hide(); GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        local t = TAB[current()]
        if self.data and t.click then t.click(self.data) end
    end)
    return row
end

local function layoutColumns()
    local t = TAB[current()]
    local x = 4
    -- Columns stretch with the window: every column grows (or shrinks) by the same factor.
    local sum = 0
    for _, col in ipairs(t.cols) do sum = sum + col.w end
    local factor = math.max(0.6, ((f:GetWidth() or W) - 44) / sum)
    for _, col in ipairs(t.cols) do col.ww = math.floor(col.w * factor) end
    for c = 1, #f.headers do f.headers[c]:Hide(); f.headerBtns[c]:Hide() end
    local sort = S().sorts and S().sorts[current()]
    for i, col in ipairs(t.cols) do
        local h = f.headers[i]
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + x + (col.icon and 24 or 0), -158)
        h:SetWidth(col.ww - 8 - (col.icon and 24 or 0))
        h:SetJustifyH(col.align or "LEFT")
        local title = L[col.title]
        if sort and sort.key == col.key then
            title = title .. (sort.desc and " |TInterface\\Buttons\\Arrow-Down-Up:10:10:0:-2|t" or " |TInterface\\Buttons\\Arrow-Up-Up:10:10:0:2|t")
            h:SetTextColor(1, 0.9, 0.5)
        else
            h:SetTextColor(0.85, 0.7, 0.35)
        end
        h:SetText(title)
        h:Show()
        local b = f.headerBtns[i]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + x, -155)
        b:SetWidth(col.ww - 4)
        b.key = (t.sort and t.sort[col.key]) and col.key or nil
        b:SetShown(b.key ~= nil)
        col.x = x
        x = x + col.ww
    end
    for _, row in ipairs(rows) do
        row.barCol = nil
        for c = 1, 9 do
            local fs, col = row.cells[c], t.cols[c]
            fs:ClearAllPoints()
            if col then
                local pad = col.icon and 24 or 0
                fs:SetPoint("LEFT", row, "LEFT", col.x + pad, 0)
                fs:SetWidth(col.ww - 8 - pad)
                fs:SetJustifyH(col.align or "LEFT")
                fs:Show()
                if col.icon then row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", row, "LEFT", col.x, 0) end
                if col.bar then row.barCol = col end
            else
                fs:Hide()
            end
        end
    end
end

local function build()
    f = CreateFrame("Frame", "HaulwiseFrame", UIParent, "BackdropTemplate")
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetBackdrop(FLAT)
    f:SetBackdropColor(0.055, 0.058, 0.07, GP.db.settings.opacity or 0.96)
    table.insert(GP.panels, f)
    f:SetBackdropBorderColor(unpack(C.border))
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        GP.db.positions.HaulwiseFrame = { p, rp, x, y }
    end)
    -- Not in UISpecialFrames: Escape doesn't close it. It stays until you press X.
    f:Hide()

    -- Header strip
    local head = tex(f, "BACKGROUND", C.header)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(56)
    local headLine = tex(f, "BORDER", { 0.5, 0.4, 0.18, 0.6 })
    headLine:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
    headLine:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
    headLine:SetHeight(1)

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetSize(36, 36)
    logo:SetPoint("TOPLEFT", 12, -10)
    logo:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = f:CreateFontString(nil, "OVERLAY", "HaulwiseFontLarge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -1)
    title:SetText("Haulwise")
    title:SetTextColor(unpack(GOLD))
    f.who = f:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    f.who:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    f.who:SetTextColor(0.7, 0.68, 0.62)

    -- Session pill (right side of header)
    local pill = CreateFrame("Frame", nil, f, "BackdropTemplate")
    pill:SetSize(310, 34)
    pill:SetPoint("TOPRIGHT", -96, -11)
    pill:SetBackdrop(FLAT)
    pill:SetBackdropColor(0.13, 0.11, 0.07, 1)
    pill:SetBackdropBorderColor(0.42, 0.33, 0.15, 1)
    f.sessTop = pill:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
    f.sessTop:SetPoint("TOPRIGHT", -10, -4)
    f.sessBottom = pill:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    f.sessBottom:SetPoint("BOTTOMRIGHT", -10, 4)
    local sessLabel = pill:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    sessLabel:SetPoint("LEFT", 10, 0)
    sessLabel:SetText(L["THIS\nSESSION"])
    sessLabel:SetJustifyH("LEFT")
    pill:EnableMouse(true)
    pill:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GP.SessionTooltip(GameTooltip)
        GameTooltip:Show()
    end)
    pill:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() GP.db.settings.winShown = false; f:Hide() end)
    f:HookScript("OnHide", function() updateDisenchant(false) end)

    -- Tabs
    local x = 12
    for _, t in ipairs(TABS) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(110, 30)
        b:SetPoint("TOPLEFT", x, -62)
        b.bg = tex(b, "BACKGROUND", { 1, 1, 1, 0.05 })
        b.bg:SetAllPoints()
        b.under = tex(b, "ARTWORK", { GOLD[1], GOLD[2], GOLD[3], 1 })
        b.under:SetPoint("BOTTOMLEFT")
        b.under:SetPoint("BOTTOMRIGHT")
        b.under:SetHeight(2)
        b.ic = b:CreateTexture(nil, "ARTWORK")
        b.ic:SetSize(16, 16)
        b.ic:SetPoint("LEFT", 10, 0)
        b.ic:SetTexture(t.icon)
        b.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.fs = b:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
        b.fs:SetPoint("LEFT", b.ic, "RIGHT", 7, 0)
        b.fs:SetText(L[t.label])
        local hl = tex(b, "HIGHLIGHT", { 1, 0.82, 0.25, 0.08 })
        hl:SetAllPoints()
        b:SetScript("OnClick", function() S().tab = t.key; offset = 0; GP:RefreshUI() end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(L[t.label], GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(L[t.tip], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b.key = t.key
        tabButtons[#tabButtons + 1] = b
        x = x + 114
    end
    local tabLine = tex(f, "BORDER", C.line)
    tabLine:SetPoint("TOPLEFT", 12, -92)
    tabLine:SetPoint("TOPRIGHT", -12, -92)
    tabLine:SetHeight(1)

    -- Hero line: the single best thing on this tab, with a gold accent bar.
    local heroBg = tex(f, "BACKGROUND", { 1, 0.82, 0.25, 0.06 })
    heroBg:SetPoint("TOPLEFT", 12, -100)
    heroBg:SetPoint("TOPRIGHT", -12, -100)
    heroBg:SetHeight(26)
    local accent = tex(f, "ARTWORK", { GOLD[1], GOLD[2], GOLD[3], 1 })
    accent:SetPoint("TOPLEFT", heroBg, "TOPLEFT")
    accent:SetSize(3, 26)
    f.hero = f:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
    f.hero:SetPoint("LEFT", heroBg, "LEFT", 12, 0)
    f.hero:SetPoint("RIGHT", heroBg, "RIGHT", -8, 0)
    f.hero:SetJustifyH("LEFT")
    f.hero:SetWordWrap(false)

    -- Toggle bar + right-side control
    f.toggleRow = CreateFrame("Frame", nil, f)
    f.toggleRow:SetPoint("TOPLEFT", 12, -132)
    f.toggleRow:SetSize(760, 20)
    f.extra = flatButton(f, "", 140)
    f.extra:SetPoint("TOPRIGHT", -12, -131)

    -- Column headers
    f.headers, f.headerBtns = {}, {}
    for i = 1, 9 do
        local h = f:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGold")
        h:SetTextColor(0.85, 0.7, 0.35)
        f.headers[i] = h
        -- Click a column title to sort by it; click again to flip the order.
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(18)
        local hl = tex(b, "HIGHLIGHT", { 1, 0.82, 0.25, 0.08 })
        hl:SetAllPoints()
        b:SetScript("OnClick", function(self)
            if self.key then GP:SortBy(self.key) end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["Click to sort, click again to reverse"], 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.headerBtns[i] = b
    end
    local colLine = tex(f, "BORDER", C.line)
    colLine:SetPoint("TOPLEFT", 12, -173)
    colLine:SetPoint("TOPRIGHT", -12, -173)
    colLine:SetHeight(1)

    for i = 1, MAX_ROWS do rows[i] = makeRow(f, i) end

    -- Slim scroll indicator
    f.track = tex(f, "BACKGROUND", { 1, 1, 1, 0.04 })
    f.track:SetPoint("TOPRIGHT", -8, -176)
    f.track:SetSize(3, ROWS * ROW_H)
    f.thumb = tex(f, "ARTWORK", { GOLD[1], GOLD[2], GOLD[3], 0.6 })
    f.thumb:SetWidth(3)

    f.empty = f:CreateFontString(nil, "OVERLAY", "HaulwiseFont")
    f.empty:SetPoint("TOP", 0, -230)
    f.empty:SetWidth(560)
    f.empty:SetTextColor(0.65, 0.63, 0.58)
    f.empty:SetSpacing(3)

    -- Start here: three steps for a new player, over the list until they press Got it.
    f.start = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.start:SetPoint("TOP", 0, -190)
    f.start:SetSize(620, 300)
    f.start:SetBackdrop(FLAT)
    f.start:SetBackdropColor(0.07, 0.075, 0.09, 0.98)
    f.start:SetBackdropBorderColor(0.5, 0.4, 0.18, 1)
    f.start:SetFrameLevel(f:GetFrameLevel() + 20)
    f.start:EnableMouse(true)
    local st = f.start:CreateFontString(nil, "OVERLAY", "HaulwiseFontLarge")
    st:SetPoint("TOPLEFT", 20, -18)
    st:SetText(L["Start here: four steps and Haulwise knows your gold"])
    local steps = {
        { L["1.  Scan the auction house"], L["Open the AH and press Scan AH (bottom right). Now every item has a price."] },
        { L["2.  Open your professions"], L["Open each profession window once, so Craft knows your recipes. Log in on your alts once too: Gear and Holdings then cover them."] },
        { L["3.  Look in Bags"], L["See what everything you carry is worth, and the best move for each item: sell, auction, disenchant or keep."] },
        { L["4.  Go farm"], L["Kill and loot as usual. Farm ranks mobs by real gold per hour, and Share data makes everyone's numbers better."] },
    }
    local y = -52
    for _, step in ipairs(steps) do
        local h = f.start:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
        h:SetPoint("TOPLEFT", 20, y)
        h:SetText(step[1])
        local d = f.start:CreateFontString(nil, "OVERLAY", "HaulwiseFont")
        d:SetPoint("TOPLEFT", 40, y - 18)
        d:SetWidth(560)
        d:SetJustifyH("LEFT")
        d:SetText(step[2])
        y = y - 54
    end
    local ok = flatButton(f.start, L["Got it"], 110)
    ok:SetPoint("BOTTOMRIGHT", -16, 14)
    ok:SetPrimary(true)
    ok:SetScript("OnClick", function() GP.db.startDone = true; f.start:Hide(); GP:RefreshUI() end)
    local more = flatButton(f.start, L["Open the guide"], 120)
    more:SetPoint("RIGHT", ok, "LEFT", -8, 0)
    more:SetScript("OnClick", function() if GP.ToggleGuide then GP:ToggleGuide() end end)
    GP.startCard = f.start
    -- Someone who already scanned and farmed a bit doesn't need it (/haul start brings it back).
    if not GP.db.startDone and (GP.db.priceScanTime or 0) > 0 and GP:OwnKills() >= 50 then GP.db.startDone = true end
    f.start:SetShown(not GP.db.startDone)

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, math.min(#data - ROWS, offset - delta * 3))
        GP:DrawRows()
    end)

    -- The scroll bar can be dragged, or clicked to jump. A wider, invisible grip sits over the
    -- slim track; the thumb widens while the mouse is on it.
    local grip = CreateFrame("Frame", nil, f)
    grip:SetPoint("TOP", f.track, "TOP")
    grip:SetPoint("BOTTOM", f.track, "BOTTOM")
    grip:SetWidth(16)
    grip:SetFrameLevel(f:GetFrameLevel() + 30)
    grip:EnableMouse(true)
    f.grip = grip
    local function scrollToCursor()
        if #data <= ROWS then return end
        local _, cy = GetCursorPosition()
        cy = cy / grip:GetEffectiveScale()
        local top, h, th = f.track:GetTop(), f.track:GetHeight(), f.thumb:GetHeight()
        if not top then return end
        local frac = math.max(0, math.min(1, (top - cy - th / 2) / math.max(1, h - th)))
        local new = math.floor(frac * (#data - ROWS) + 0.5)
        if new ~= offset then offset = new; GP:DrawRows() end
    end
    local function stopDrag(self)
        self:SetScript("OnUpdate", nil)
        if not self:IsMouseOver() then f.thumb:SetWidth(3) end
    end
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        scrollToCursor()
        self:SetScript("OnUpdate", function(s)
            if not IsMouseButtonDown("LeftButton") then stopDrag(s) else scrollToCursor() end
        end)
    end)
    grip:SetScript("OnMouseUp", stopDrag)
    grip:SetScript("OnEnter", function() f.thumb:SetWidth(6) end)
    grip:SetScript("OnLeave", function(self) if not self:GetScript("OnUpdate") then f.thumb:SetWidth(3) end end)
    grip:EnableMouseWheel(true)
    grip:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, math.min(#data - ROWS, offset - delta * 3))
        GP:DrawRows()
    end)

    -- Footer strip
    local foot = tex(f, "BACKGROUND", C.header)
    foot:SetPoint("BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", -1, 1)
    foot:SetHeight(40)
    local footLine = tex(f, "BORDER", { 0.5, 0.4, 0.18, 0.6 })
    footLine:SetPoint("BOTTOMLEFT", foot, "TOPLEFT")
    footLine:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
    footLine:SetHeight(1)
    f.footer = f:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    f.footer:SetPoint("BOTTOMLEFT", 14, 22)
    f.footer:SetPoint("RIGHT", -330, 0)
    f.footer:SetJustifyH("LEFT")
    f.footer:SetWordWrap(false)
    f.footer:SetTextColor(0.65, 0.63, 0.58)
    -- Second line: how fresh the community data is, and what you haven't shared. Click to import.
    f.comm = CreateFrame("Button", nil, f)
    f.comm:SetPoint("BOTTOMLEFT", 14, 6)
    f.comm:SetPoint("RIGHT", f, "RIGHT", -330, 0)
    f.comm:SetHeight(14)
    f.comm.text = f.comm:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    f.comm.text:SetAllPoints()
    f.comm.text:SetJustifyH("LEFT")
    f.comm.text:SetWordWrap(false)
    f.comm:SetScript("OnClick", function() GP:ShowImport() end)
    f.comm:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Community data"], 1, 0.82, 0.25)
        local com = GP:CommunityInfo()
        if com then
            GameTooltip:AddLine(string.format(L["Drop rates, recipe sources and vendor prices pooled from %s, as of %s."],
                plural(com.contributors or 0, "player"), date("%d %b %Y", com.time or 0)), 1, 1, 1, true)
        else
            GameTooltip:AddLine(L["None loaded yet."], 1, 1, 1, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["The pool is rebuilt every hour. To get it now: press \"Copy community data\" on "] .. GP.SITE_URL .. L[", then click here and paste it (Ctrl+V)."], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["Haulwise gets a fresh copy every day through CurseForge too."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f.comm:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.scan = flatButton(f, L["Scan AH"], 110)
    f.scan:SetPoint("BOTTOMRIGHT", -12, 9)
    f.scan:SetScript("OnClick", function() GP:ScanAH() end)
    tip(f.scan, function(t)
        local status = GP:ScanStatus()
        if status then
            t:AddLine(L["Scanning the auction house"], 1, 0.82, 0.25)
            t:AddLine(status, 1, 1, 1, true)
            return
        end
        local ok, why = GP:CanScan()
        if ok then
            t:AddLine(L["Scan every auction"], 1, 0.82, 0.25)
            t:AddLine(L["Reads all listings at once (the game allows one full scan every 15 minutes)."], 1, 1, 1, true)
        else
            t:AddLine(L["Can't scan right now"], 1, 0.82, 0.25)
            t:AddLine((why:gsub("^%l", string.upper)) .. ".", 1, 1, 1, true)
        end
    end)
    f.import = flatButton(f, L["Import"], 84)
    f.import:SetPoint("RIGHT", f.scan, "LEFT", -6, 0)
    f.import:SetScript("OnClick", function() GP:ShowImport() end)
    f.export = flatButton(f, L["Share data"], 100)
    f.export:SetPoint("RIGHT", f.import, "LEFT", -6, 0)
    f.export:SetScript("OnClick", function() GP:ShowExport() end)
    tip(f.export, function(t)
        t:AddLine(L["Share your data"], 1, 0.82, 0.25)
        t:AddLine(L["Your kills and loot, plus the trainer and vendor recipes and reagent prices you've seen. No names, no account."], 0.8, 0.8, 0.8, true)
        t:AddLine(L["Haulwise can't reach the internet, so sharing is manual: copy the text and paste it on "] .. GP.SITE_URL .. L[". The pool is rebuilt every hour: press Import and paste the community data from the same page to get it right away, or get it with the next daily update."], 1, 1, 1, true)
        local new = GP:UnsharedKills()
        if new > 0 then t:AddLine(new .. L[" kills not shared yet."], 0.37, 0.83, 0.37) end
    end)

    GP.MakeScalable(f, "winScale")
    local gear = GP.IconButton(f, "Interface\\Buttons\\UI-OptionsButton", L["Settings"], 18)
    gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -19)
    gear:SetScript("OnClick", function() GP:ToggleSettings() end)
    local help = GP.IconButton(f, "Interface\\FriendsFrame\\InformationIcon", L["Guide"], 18)
    help:SetPoint("RIGHT", gear, "LEFT", -8, 0)
    help:SetScript("OnClick", function() GP:ToggleGuide() end)
    local relayoutPending
    GP.MakeResizable(f, "HaulwiseFrame", 760, 400, 1800, 1200, function()
        ROWS = math.max(4, math.min(MAX_ROWS, math.floor((f:GetHeight() - 176 - 50) / ROW_H)))
        if relayoutPending then return end
        relayoutPending = true
        C_Timer.After(0.05, function() relayoutPending = nil; GP:RefreshUI() end)
    end)
    ROWS = math.max(4, math.min(MAX_ROWS, math.floor((f:GetHeight() - 176 - 50) / ROW_H)))

    local acc = 0
    f:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc > 5 then acc = 0; GP:DrawSession() end
    end)
    f:SetScript("OnShow", function() GP:RefreshUI() end)
end

function GP:DrawSession()
    if not f then return end
    local s = self.session
    local total, perHour, mins = GP.SessionEarned()
    f.sessTop:SetText(Coins(perHour, true) .. L[" |cffaaaaaa/ hour|r"])
    if (s.sales or 0) > 0 then
        f.sessBottom:SetText(string.format(L["loot %s + sales %s  ·  %d min"], Coins(s.value, true), Coins(s.sales, true), mins))
    else
        f.sessBottom:SetText(string.format(L["%s in %d min  ·  %d kills"], Coins(total, true), mins, s.kills))
    end
end

-- The session box's tooltip: where this session's gold came from.
function GP.SessionTooltip(t)
    local s = GP.session
    local total, perHour, mins = GP.SessionEarned()
    t:AddLine(L["This session"], 1, 0.82, 0.25)
    t:AddDoubleLine(L["Loot from kills (worth)"], GP.Coins(s.value or 0), 0.7, 0.7, 0.7, 1, 1, 1)
    t:AddDoubleLine(string.format(L["AH sales collected (%d)"], s.salesN or 0), GP.Coins(s.sales or 0), 0.7, 0.7, 0.7, 1, 1, 1)
    t:AddDoubleLine(L["Earned"], GP.Coins(total) .. "  ·  " .. GP.Coins(perHour, true) .. L["/h"], 0.7, 0.7, 0.7, 1, 0.82, 0.25)
    if GetMoney and s.gold0 then
        local d = GetMoney() - s.gold0
        t:AddDoubleLine(L["Gold in your bags"], (d < 0 and "|cffff6b5b-" or "|cff5fd35f+") .. GP.Coins(math.abs(d)) .. "|r", 0.7, 0.7, 0.7, 1, 1, 1)
    end
    t:AddDoubleLine(L["Kills"], tostring(s.kills or 0), 0.7, 0.7, 0.7, 1, 1, 1)
    t:AddLine(string.format(L["%d min. Sales count when you open the mailbox. Gold in your bags also counts vendors, quests and what you spent. /haul session starts over."], mins), 0.6, 0.6, 0.6, true)
end

function GP:DrawRows()
    local t = TAB[current()]
    local maxBar = 0
    for _, r in ipairs(data) do maxBar = math.max(maxBar, math.abs(t.bar and t.bar(r) or 0)) end
    for i = 1, MAX_ROWS do
        local row, r = rows[i], i <= ROWS and data[i + offset] or nil
        row.data = r
        if r then
            local cells = t.cells(r)
            for c, col in ipairs(t.cols) do row.cells[c]:SetText(cells[col.key] or "") end
            if t.cols[1].icon then
                -- A mob's real portrait, drawn by the game from its model, when there is one.
                local drawn = false
                if cells.portrait and row.portrait == cells.portrait then
                    drawn = true   -- already drawn on this row: portraits cost a render each
                elseif cells.portrait and SetPortraitTextureFromCreatureDisplayID then
                    drawn = pcall(SetPortraitTextureFromCreatureDisplayID, row.icon, cells.portrait)
                    if drawn then row.icon:SetTexCoord(0, 1, 0, 1); row.portrait = cells.portrait end
                end
                if not drawn then
                    row.portrait = nil
                    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    row.icon:SetTexture(cells.icon or 134400)
                end
                row.icon:Show()
            else
                row.icon:Hide()
            end
            local bc = row.barCol
            local v = t.bar and t.bar(r) or 0
            if bc and maxBar > 0 and v ~= 0 then
                row.bar:ClearAllPoints()
                row.bar:SetPoint("RIGHT", row, "LEFT", bc.x + bc.ww - 4, 0)
                row.bar:SetWidth(math.max(2, (bc.ww - 8) * math.abs(v) / maxBar))
                row.bar:SetColorTexture(unpack(v < 0 and C.barNeg or C.bar))
                row.bar:Show()
            else
                row.bar:Hide()
            end
            row:Show()
        else
            row:Hide()
        end
    end
    f.track:SetHeight(ROWS * ROW_H)
    if #data > ROWS then
        local h = ROWS * ROW_H
        local th = math.max(20, h * ROWS / #data)
        f.thumb:SetHeight(th)
        f.thumb:ClearAllPoints()
        f.thumb:SetPoint("TOP", f.track, "TOP", 0, -(h - th) * offset / (#data - ROWS))
        f.thumb:Show(); f.track:Show()
        if f.grip then f.grip:Show() end
    else
        f.thumb:Hide(); f.track:Hide()
        if f.grip then f.grip:Hide() end
    end
end

local function buildToggles(t)
    for _, b in ipairs(toggleBar) do b:Hide() end
    local x = 0
    for i, spec in ipairs(t.toggles or {}) do
        if spec[4] and not spec[4]() then
            -- Not relevant for this character (e.g. pickpocket on a mage): don't show it.
        else
        local key = spec[2]
        local b = toggleBar[current() .. i]
        if not b and spec.kind == "cycle" then
            b = GP.FlatButton(f.toggleRow, "", 120, 18)
            b.sync = function()
                b.label:SetText(spec.label())
                b:SetWidth(math.max(90, (b.label:GetStringWidth() or 80) + 22))
                b:SetLabel(spec.label())
            end
            b:SetScript("OnClick", function() spec.click(); GP:RefreshUI() end)
            tip(b, function(tt) tt:AddLine(spec.tip(), 1, 1, 1, true) end)
            toggleBar[current() .. i] = b
            toggleBar[#toggleBar + 1] = b
        end
        if not b then
            local get = spec.get or function() return S()[key] end
            local set = spec.set or function(v) S()[key] = v end
            b = toggle(f.toggleRow, L[spec[1]], get, set, spec.tip and spec.tip() or (spec[3] and L[spec[3]]))
            toggleBar[current() .. i] = b
            toggleBar[#toggleBar + 1] = b
        end
        b:ClearAllPoints()
        b:SetPoint("LEFT", f.toggleRow, "LEFT", x, 0)
        b.sync()
        b:Show()
        x = x + b:GetWidth() + 14
        end
    end
end

-- Disenchant button (Bags tab). A secure button can't live inside the window (that would block
-- opening and closing it in combat), so it sits on UIParent, lined up with the window, and only
-- appears out of combat.
local deButton
local function disenchantName() return GP.DisenchantSpellName() end

function GP:DisenchantCandidate()
    local name = disenchantName()
    if not name then return nil end
    -- Where disenchanting pays most: the biggest gain first. "For mats": the one that costs the
    -- least gold compared with selling, so the Gold you'd lose stays small.
    local best, bestScore
    for _, r in ipairs(self:BagItems()) do
        if not r.protect and GP.CanDisenchantMyself(r.d) then
            local score
            if r.src == "DE" then
                score = 1e12 + r.total
            elseif GP:MatsDisenchant(r) then
                score = -(r.total - (r.d.de or 0) * (r.count or 1))
            end
            if score and (not bestScore or score > bestScore) then best, bestScore = r, score end
        end
    end
    return best, name
end

updateDisenchant = function(show)
    if InCombatLockdown and InCombatLockdown() then return end
    local cand, spell = nil, nil
    if show then cand, spell = GP:DisenchantCandidate() end
    if not cand then if deButton then deButton:Hide() end return end
    if not deButton then
        deButton = CreateFrame("Button", "HaulwiseDisenchantButton", UIParent, "SecureActionButtonTemplate,BackdropTemplate")
        deButton:SetSize(170, 22)
        deButton:SetFrameStrata("HIGH")
        deButton:SetBackdrop(FLAT)
        deButton:SetBackdropColor(0.16, 0.1, 0.2, 1)
        deButton:SetBackdropBorderColor(0.6, 0.45, 0.8, 1)
        deButton:RegisterForClicks("AnyUp", "AnyDown")
        deButton.label = deButton:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
        deButton.label:SetPoint("LEFT", 8, 0)
        deButton.label:SetPoint("RIGHT", -8, 0)
        deButton.label:SetWordWrap(false)
        deButton:SetAttribute("type", "macro")
        deButton:SetScript("PreClick", function(self) GP.deTarget = self.target end)
        deButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if self.link then GameTooltip:SetHyperlink(self.link) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Disenchanting this gives more than selling it. Click to disenchant."], 0.77, 0.55, 1, true)
            GameTooltip:Show()
        end)
        deButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    deButton:SetAttribute("macrotext", string.format("/cast %s\n/use %d %d", spell, cand.bag, cand.slot))
    deButton.link = cand.link
    deButton.target = { bag = cand.bag, slot = cand.slot }
    deButton.label:SetText(L["|cffc48cffDisenchant|r "] .. itemName(cand.id))
    deButton:ClearAllPoints()
    deButton:SetPoint("RIGHT", f.extra, "LEFT", -6, 0)
    -- Above the window, or the window takes the clicks.
    deButton:SetFrameStrata(f:GetFrameStrata())
    deButton:SetFrameLevel(f:GetFrameLevel() + 50)
    deButton:Show()
end

GP:On("PLAYER_REGEN_DISABLED", function()
    if deButton then deButton:Hide(); deButton:ClearAllPoints() end
end)
GP:On("PLAYER_REGEN_ENABLED", function() if f and f:IsShown() then GP:RefreshUI() end end)

function GP:RefreshUI()
    if not f or not f:IsShown() then updateDisenchant(false); return end
    local key = current()
    local t = TAB[key]
    updateDisenchant(key == "bags")

    for _, b in ipairs(tabButtons) do
        local on = b.key == S().tab
        b.under:SetShown(on)
        b.bg:SetShown(on)
        b.fs:SetTextColor(on and GOLD[1] or 0.62, on and GOLD[2] or 0.6, on and GOLD[3] or 0.55)
        b.ic:SetDesaturated(not on)
    end

    buildToggles(t)
    if key == "farm" or key == "farm_zones" then
        f.extra:SetLabel(S().sortBy == "safe" and L["Rank: Safe"] or L["Rank: Expected"])
        f.extra:SetScript("OnClick", function() S().sortBy = S().sortBy == "safe" and "est" or "safe"; GP:RefreshUI() end)
        tip(f.extra, function(tt)
            tt:AddLine(L["Safe ranks by the low end of each drop chance, so a lucky streak can't put a mob on top. Expected ranks by the average."], 1, 1, 1, true)
        end)
        f.extra:Show()
    elseif t.extraButton then
        t.extraButton(f.extra)
        tip(f.extra, function(tt) tt:AddLine(L[t.extraTip or ""], 1, 1, 1, true) end)
        f.extra:Show()
    else
        f.extra:Hide()
    end

    data = t.rows()
    GP:ApplySort(t, data)
    if self.scrollToTop then offset, self.scrollToTop = 0, nil end
    offset = math.max(0, math.min(offset, #data - ROWS))
    layoutColumns()
    local emptyText = type(t.empty) == "function" and t.empty() or L[t.empty or ""]
    f.empty:SetText(emptyText)
    f.empty:SetShown(#data == 0)
    if #data == 0 then
        for i, h in ipairs(f.headers) do h:Hide(); f.headerBtns[i]:Hide() end
    end
    f.hero:SetText(t.hero(data) or grey(L["Nothing to suggest yet."]))

    local profs = {}
    for name, p in pairs(self:MyProfessions()) do
        profs[#profs + 1] = string.format("%s %s", L[name], p.rank and grey(tostring(p.rank)) or "")
    end
    table.sort(profs)
    f.who:SetText(string.format(L["Level %d %s   %s"], UnitLevel("player") or 0, UnitClass("player") or "",
        #profs > 0 and grey("·  ") .. table.concat(profs, grey("  ·  ")) or ""))

    local nPrices = 0
    for _ in pairs(self.db.prices) do nPrices = nPrices + 1 end
    -- Where prices come from: your scan, prices shared for your realm, Auctionator, or all realms.
    local priceText
    local key = GP.RealmKey and GP.RealmKey()
    local realm = key and self.db.realmPrices and self.db.realmPrices[key]
    local realmNote = realm and realm.day and grey(string.format(L["  ·  + realm prices %s"], date("%d %b", realm.day * 86400 + 43200))) or ""
    if nPrices > 0 then
        local age = time() - (self.db.priceScanTime or 0)
        local scanned = ago(age)
        if age > 3 * 86400 then scanned = "|cffff9944" .. scanned .. "|r" end
        priceText = string.format(L["|cffffffff%d|r prices  ·  scanned %s"], nPrices, scanned) .. realmNote
    elseif realm then
        local n = 0
        for _ in pairs(realm.items or {}) do n = n + 1 end
        priceText = string.format(L["|cffffffff%d|r prices shared for your realm  ·  %s"], n, date("%d %b", (realm.day or 0) * 86400 + 43200))
    elseif Auctionator and Auctionator.API then
        priceText = L["Prices from Auctionator"]
    elseif self:CommunityInfo() and self:CommunityInfo().allPrices then
        priceText = L["|cffff9944Prices from all realms (rough): press Scan AH at the auction house for yours.|r"]
    else
        priceText = L["|cffff9944No AH prices yet: open the auction house and press Scan AH.|r"]
    end
    local days = 0
    for _ in pairs(self.db.scanDays or {}) do days = days + 1 end
    local ownKills, nFriends = 0, 0
    for _, m in pairs(self.db.mobs) do ownKills = ownKills + (m.kills or 0) end
    for uid in pairs(self.db.shared) do if uid ~= "community" then nFriends = nFriends + 1 end end
    local extra = ""
    if nFriends > 0 and S().useShared then extra = string.format(L[" + %d friends"], nFriends) end
    f.footer:SetText(string.format(L["%s  ·  %s of history  ·  %d of your kills%s"], priceText, plural(days, "day"), ownKills, extra))
    local com = self:CommunityInfo()
    local line
    if com and com.time and com.time > 0 then
        local age = (time() - com.time) / 86400
        line = string.format(L["%sCommunity data from %s|r  ·  %s"], age > 14 and "|cffff9944" or "|cff88ccff",
            date("%d %b", com.time), plural(com.contributors or 0, "player"))
        if age > 14 then line = line .. L["  ·  |cffff9944old: click to get the newest|r"] end
    else
        line = L["|cffff9944No community data yet: click to import it|r"]
    end
    if not S().useShared then line = line .. grey(L["  (turned off on the Farm tab)"]) end
    local here = self:CurrentZone()
    if here and S().useShared then
        local zm, zk = self:CommunityInZone(here)
        if zm > 0 then line = line .. string.format(L["  ·  in %s: |cffffffff%s|r from others"], GP.ZoneName(here), string.format(L["%s, %s"], plural(zm, "mob"), plural(zk, "kill"))) end
    end
    local unshared = self:UnsharedKills()
    if unshared > 0 then line = line .. string.format(L["  ·  |cffffd040%d of your kills not shared yet|r"], unshared) end
    f.comm.text:SetText(line)
    -- The Share button lights up and shows the count once there's a good batch to share.
    if f.export then
        local due = unshared >= 100
        f.export:SetLabel(due and string.format(L["Share data (%d)"], unshared) or L["Share data"])
        f.export:SetPrimary(due)
    end

    self:RefreshScanButton()

    self:DrawSession()
    self:DrawRows()
end

local scanWake
function GP:RefreshScanButton()
    if not (f and f.scan) then return end
    local canScan = self:CanScan()
    -- Greyed out while the game's 15-minute wait runs: light it up again by itself when it ends
    -- (nothing else redraws the button just because time passed).
    local wait = (GP.SCAN_THROTTLE or 900) - (time() - (self.db.priceScanTime or 0))
    if not canScan and wait > 0 and not scanWake then
        scanWake = true
        local due = time() + wait
        C_Timer.After(wait + 1, function()
            scanWake = nil
            if time() >= due then GP:RefreshScanButton() end
        end)
    end
    f.scan.label:SetTextColor(canScan and GOLD[1] or 0.5, canScan and GOLD[2] or 0.5, canScan and GOLD[3] or 0.5)
    local p = self.scanProgress
    f.scan:SetLabel(not p and L["Scan AH"] or (p == 0 and L["Waiting for AH..."] or string.format(L["Scanning %d%%"], math.floor(p * 100))))
end

local function place()
    local pos = GP.db.positions.HaulwiseFrame
    f:ClearAllPoints()
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER") end
end

function GP:ShowUI()
    if not f then build(); place() end
    self.db.settings.winShown = true
    f:Show()
    self:RefreshUI()
end

function GP:ToggleUI()
    if f and f:IsShown() then f:Hide() else self:ShowUI() end
end
