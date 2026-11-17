-- Haulwise: the HUD. A small box that stays on screen until you close it: gold per hour this
-- session, bag space and worth, the cheapest thing you could throw away, upgrades waiting, and
-- "Sell junk" at vendors. Drag to move (unless locked); /haul hud brings it back.
local _, GP = ...

local hud
local W = 300

local function line(parent, y)
    local l = parent:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    l:SetPoint("TOPLEFT", 10, y)
    l:SetPoint("RIGHT", -10, 0)
    l:SetJustifyH("LEFT")
    l:SetWordWrap(false)
    return l
end

local function build()
    hud = GP.Panel("HaulwiseHUD", W, 132, "")
    hud:SetFrameStrata("MEDIUM")
    local logo = hud:CreateTexture(nil, "ARTWORK")
    logo:SetSize(16, 16)
    logo:SetPoint("TOPLEFT", 8, -6)
    logo:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    hud.title:ClearAllPoints()
    hud.title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    hud.title:SetText("Haulwise")
    hud.close:SetScript("OnClick", function() GP.db.settings.hudShown = false; hud:Hide() end)

    hud.open = CreateFrame("Button", nil, hud)
    hud.open:SetSize(18, 18)
    hud.open:SetPoint("RIGHT", hud.close, "LEFT", 2, 0)
    hud.open:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    hud.open:SetScript("OnClick", function() GP:ToggleUI() end)
    hud.open:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Open the Haulwise window"); GameTooltip:Show() end)
    hud.open:SetScript("OnLeave", function() GameTooltip:Hide() end)

    hud.gear = GP.IconButton(hud, "Interface\\Buttons\\UI-OptionsButton", "Settings", 14)
    hud.lock = CreateFrame("Button", nil, hud)
    hud.lock:SetSize(14, 14)
    hud.lock:SetPoint("RIGHT", hud.open, "LEFT", -2, 0)
    hud.gear:SetPoint("RIGHT", hud.lock, "LEFT", -4, 0)
    hud.gear:SetScript("OnClick", function() GP:ToggleSettings() end)
    hud.lock:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
    hud.lock:SetScript("OnClick", function()
        GP.db.settings.hudLocked = not GP.db.settings.hudLocked
        GP:RefreshHUD()
    end)
    hud.lock:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Lock / unlock position"); GameTooltip:Show() end)
    hud.lock:SetScript("OnLeave", function() GameTooltip:Hide() end)

    hud.session = line(hud, -34)

    -- Worth block: hover for the full breakdown.
    hud.worth = CreateFrame("Button", nil, hud)
    hud.worth:SetPoint("TOPLEFT", 6, -48)
    hud.worth:SetPoint("RIGHT", -6, 0)
    hud.worth:SetHeight(58)
    local hl = GP.Tex(hud.worth, "HIGHLIGHT", 1, 0.82, 0.25, 0.06)
    hl:SetAllPoints()
    local function pair(y)
        local l = hud.worth:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
        l:SetPoint("TOPLEFT", 4, y)
        local r = hud.worth:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
        r:SetPoint("TOPRIGHT", -4, y)
        r:SetJustifyH("RIGHT")
        return l, r
    end
    hud.goldL, hud.goldR = pair(-2)
    hud.bagsL, hud.bagsR = pair(-16)
    hud.totalL, hud.totalR = pair(-34)
    hud.totalL:SetFontObject("HaulwiseFontGold")
    hud.totalR:SetFontObject("HaulwiseFontGold")
    hud.worth:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GP:AddTotalsTooltip(GameTooltip)
        GameTooltip:Show()
    end)
    hud.worth:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hud.worth:SetScript("OnClick", function() GP.db.settings.tab = "bags"; GP:ShowUI() end)

    local sep = GP.Tex(hud, "BORDER", 1, 1, 1, 0.06)
    sep:SetPoint("TOPLEFT", 10, -106)
    sep:SetPoint("TOPRIGHT", -10, -106)
    sep:SetHeight(1)

    hud.cheapLabel = hud:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    hud.cheapLabel:SetPoint("TOPLEFT", 10, -112)
    hud.cheapLabel:SetText("CHEAPEST TO THROW AWAY")
    hud.cheap = GP.ItemRow(hud, W - 96)
    hud.cheap:SetPoint("TOPLEFT", 10, -124)
    hud.cheapRows = { hud.cheap }
    hud.sizing = false
    hud.room = GP.FlatButton(hud, "Make room", 74, 20)
    hud.room:SetPoint("TOPRIGHT", -10, -125)
    hud.room:SetScript("OnClick", function() GP:ShowMakeRoom() end)

    hud.upgrades = CreateFrame("Button", nil, hud)
    hud.upgrades:SetPoint("TOPLEFT", 10, -150)
    hud.upgrades:SetSize(W - 20, 16)
    hud.upText = hud.upgrades:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    hud.upText:SetPoint("LEFT")
    hud.upgrades:SetScript("OnClick", function() GP.db.settings.tab = "gear"; GP:ShowUI() end)

    hud.junk = GP.FlatButton(hud, "", W - 20, 20)
    hud.junk:SetScript("OnClick", function() GP:SellJunk(); C_Timer.After(0.5, function() GP:RefreshHUD() end) end)

    GP.MakeScalable(hud, "hudScale")
    -- Drag the corner: wider shows longer names, taller lists more of the cheapest items.
    GP.MakeResizable(hud, "HaulwiseHUD", 240, 150, 700, 480, function()
        if hud.sizing then hud.userHeight = hud:GetHeight() end
        GP:RefreshHUD()
    end)
    local saved = GP.db.sizes.HaulwiseHUD
    hud.userHeight = saved and saved[2] or 160

    local acc = 0
    hud:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc > 5 then acc = 0; GP:RefreshHUD(true) end
    end)
end

function GP:RefreshHUD(sessionOnly)
    if not hud or not hud:IsShown() then return end
    local s = self.session
    local mins = math.max(1, (time() - s.start) / 60)
    hud.session:SetText(string.format("Session  %s|cff8a8880/h   %s · %d kills|r",
        GP.Coins(s.value / mins * 60, true), GP.Coins(s.value, true), s.kills))
    if sessionOnly then return end

    local locked = self.db.settings.hudLocked
    hud:SetMovable(not locked)
    hud.lock:SetNormalTexture(locked and "Interface\\Buttons\\LockButton-Locked-Up" or "Interface\\Buttons\\LockButton-Unlocked-Up")

    local free, total = self:FreeSlots(), self:TotalSlots()
    local t = self:Totals()
    hud.goldL:SetText("Gold")
    hud.goldR:SetText(GP.Coins(t.gold, true))
    hud.bagsL:SetText(string.format("Bags  %s%d free|r|cff8a8880/%d|r", free == 0 and "|cffff6b5b" or (free <= 3 and "|cffff9944" or "|cff5fd35f"), free, total))
    hud.bagsR:SetText(string.format("%s |cff8a8880(vendor %s)|r", GP.Coins(t.best, true), GP.Coins(t.vendor, true)))
    hud.totalL:SetText("Total")
    hud.totalR:SetText(GP.Coins(t.total, true))

    -- Cheapest items: as many as fit. Drag the HUD taller to see more.
    local cands = self:DeleteCandidates()
    local w = hud:GetWidth()
    local extras = 0
    local mine, alts = #self.upgrades.mine, #self.upgrades.alts
    if mine + alts > 0 then extras = extras + 18 end
    local junk, nJunk = self:JunkValue()
    if self.atMerchant and nJunk > 0 then extras = extras + 26 end
    local wanted = hud.userHeight or 160
    local fit = math.max(1, math.min(12, math.floor((wanted - 124 - extras - 12) / 24)))
    local shown = math.min(fit, math.max(1, #cands))
    for i = 1, 12 do
        local row = hud.cheapRows[i]
        local c = cands[i]
        if i <= fit and c then
            if not row then
                row = GP.ItemRow(hud, 100)
                row:SetPoint("TOPLEFT", 10, -124 - (i - 1) * 24)
                hud.cheapRows[i] = row
            end
            row:SetWidth(i == 1 and (w - 96) or (w - 20))
            row:SetItem(c.id, c.link, GP.ValueText(c.total, c.src, c.d), c.count)
            row.tip = function(t)
                t:SetHyperlink(c.link)
                GP.AddValueLines(t, c.unit, c.src, c.d, c.count)
                t:AddLine("Shift-click to always keep it.", 0.6, 0.6, 0.6)
            end
            row:SetScript("OnClick", function()
                if IsShiftKeyDown and IsShiftKeyDown() then GP.db.keep[c.id] = true; GP:RefreshHUD() end
            end)
            row:Show()
        elseif row then
            row:Hide()
        end
    end
    if cands[1] then
        hud.room:Show()
        hud.cheapLabel:SetText(fit > 1 and "CHEAPEST TO THROW AWAY" or "CHEAPEST TO THROW AWAY  (drag down for more)")
    else
        hud.room:Hide()
        hud.cheapLabel:SetText("NOTHING SAFE TO THROW AWAY")
    end

    local h = 124 + shown * 24 + 4
    if mine + alts > 0 then
        local parts = {}
        if mine > 0 then parts[#parts + 1] = string.format("|cff5fd35f%d upgrade%s for you|r", mine, mine > 1 and "s" or "") end
        if alts > 0 then parts[#parts + 1] = string.format("|cffff9944%d for alts|r", alts) end
        hud.upText:SetText(table.concat(parts, "  ·  ") .. " |cff8a8880(click)|r")
        hud.upgrades:ClearAllPoints()
        hud.upgrades:SetPoint("TOPLEFT", 10, -h)
        hud.upgrades:SetWidth(w - 20)
        hud.upgrades:Show()
        h = h + 18
    else
        hud.upgrades:Hide()
    end
    if self.atMerchant and nJunk > 0 then
        hud.junk:ClearAllPoints()
        hud.junk:SetPoint("TOPLEFT", 10, -h - 2)
        hud.junk:SetWidth(w - 20)
        hud.junk:SetLabel(string.format("Sell %d grey item%s for %s", nJunk, nJunk > 1 and "s" or "", GP.Coins(junk, true)))
        hud.junk:Show()
        h = h + 26
    else
        hud.junk:Hide()
    end
    -- While you drag, the box follows your mouse; afterwards it snaps to whole rows.
    if not hud.sizing then hud:SetHeight(h + 12) end
end

function GP:ShowHUD()
    if not hud then build() end
    self.db.settings.hudShown = true
    hud:RestorePosition({ "TOPRIGHT", UIParent, "TOPRIGHT", -220, -200 })
    hud:Show()
    self:RefreshHUD()
end

function GP:ToggleHUD()
    if hud and hud:IsShown() then self.db.settings.hudShown = false; hud:Hide() else self:ShowHUD() end
end

-- Refresh after bag changes, a little after the burst of events settles.
local pending
local function soon()
    if pending then return end
    pending = true
    C_Timer.After(0.8, function() pending = nil; GP:RefreshHUD() end)
end
GP:On("BAG_UPDATE_DELAYED", soon)
GP:On("PLAYER_MONEY", soon)
GP:On("PLAYER_ENTERING_WORLD", function()
    if GP.db.settings.hudShown then C_Timer.After(1, function() GP:ShowHUD() end) end
    if GP.db.settings.winShown then C_Timer.After(1, function() GP:ShowUI() end) end
end)
