-- Haulwise: the HUD. A small box that stays on screen until you close it: gold per hour this
-- session, bag space and worth, the cheapest thing you could throw away, upgrades waiting, and
-- "Sell junk" at vendors. Drag to move (unless locked); /haul hud brings it back.
local _, GP = ...
local L = GP.L

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
    logo:SetTexture("Interface\\AddOns\\Haulwise\\Media\\icon")
    hud.title:ClearAllPoints()
    hud.title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    hud.title:SetText("Haulwise")
    hud.close:SetScript("OnClick", function() GP.db.settings.hudShown = false; hud:Hide() end)

    -- A labelled button, not an icon: this is how most people find the big window.
    hud.open = GP.FlatButton(hud, L["Open Haulwise"], 100, 18)
    hud.open:SetPoint("LEFT", hud.title, "RIGHT", 10, 0)
    hud.open:SetPrimary(true)
    hud.open:SetScript("OnClick", function() GP:ToggleUI() end)
    hud.open:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(L["Open the Haulwise window"]); GameTooltip:AddLine(L["Farm, Bags, Gear, Craft and Auction House."], 0.8, 0.8, 0.8, true); GameTooltip:Show() end)
    hud.open:SetScript("OnLeave", function() GameTooltip:Hide() end)

    hud.gear = GP.IconButton(hud, "Interface\\Buttons\\UI-OptionsButton", L["Settings"], 14)
    hud.lock = CreateFrame("Button", nil, hud)
    hud.lock:SetSize(14, 14)
    hud.lock:SetPoint("RIGHT", hud.close, "LEFT", -2, 0)
    hud.gear:SetPoint("RIGHT", hud.lock, "LEFT", -4, 0)
    hud.gear:SetScript("OnClick", function() GP:ToggleSettings() end)
    hud.lock:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
    hud.lock:SetScript("OnClick", function()
        GP.db.settings.hudLocked = not GP.db.settings.hudLocked
        GP:RefreshHUD()
    end)
    hud.lock:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(L["Lock / unlock position"]); GameTooltip:Show() end)
    hud.lock:SetScript("OnLeave", function() GameTooltip:Hide() end)

    hud.session = line(hud, -34)
    -- Session tools on the right of the session line: pause / resume, and save + start over.
    hud.newSess = GP.IconButton(hud, "Interface\\TimeManager\\ResetButton", "", 16)
    hud.newSess:SetPoint("TOPRIGHT", -8, -31)
    hud.newSess:SetScript("OnClick", function()
        if GP:StartNewSession() then GP.Print(L["Session saved. A new one has started."]) end
    end)
    hud.newSess:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["New session"])
        GameTooltip:AddLine(L["Save this session (when it's 3 minutes or more) and start a new one."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    hud.pause = GP.IconButton(hud, "Interface\\TimeManager\\PauseButton", "", 16)
    hud.pause:SetPoint("RIGHT", hud.newSess, "LEFT", -4, 0)
    hud.pause:SetScript("OnClick", function() GP:ToggleSessionPause() end)
    hud.pause:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(GP.SessionPaused() and L["Resume"] or L["Pause"])
        GameTooltip:AddLine(L["While paused, the clock stops and loot stays out of this session (it still counts for drop rates)."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    hud.session:SetPoint("RIGHT", hud.pause, "LEFT", -6, 0)
    -- Hover the session line for where the gold came from.
    local sb = CreateFrame("Button", nil, hud)
    sb:SetPoint("TOPLEFT", 8, -30)
    sb:SetPoint("RIGHT", hud.pause, "LEFT", -6, 0)
    sb:SetHeight(16)
    sb:SetScript("OnClick", function() GP:ToggleSessionPause() end)
    sb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GP.SessionTooltip(GameTooltip, L["Click to pause or resume. The buttons on the right: pause, and save and start a new session."])
        GameTooltip:Show()
    end)
    sb:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Click: open the Bags tab"], 0.6, 0.6, 0.6)
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
    hud.cheapLabel:SetText(L["CHEAPEST TO THROW AWAY"])
    hud.cheap = GP.ItemRow(hud, W - 96)
    hud.cheap:SetPoint("TOPLEFT", 10, -124)
    hud.cheapRows = { hud.cheap }
    hud.sizing = false
    hud.room = GP.FlatButton(hud, L["Make room"], 74, 20)
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
    local total, perHour, mins = GP.SessionEarned()
    local paused = GP.SessionPaused()
    hud.session:SetText(string.format(L["Session  %s|cff8a8880/h   %s · %d kills · %d min|r"],
        GP.Coins(perHour, true), GP.Coins(total, true), s.kills, mins) .. (paused and ("  |cffff9944" .. L["paused"] .. "|r") or ""))
    hud.pause:SetNormalTexture(paused and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" or "Interface\\TimeManager\\PauseButton")
    hud.pause:SetHighlightTexture(paused and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" or "Interface\\TimeManager\\PauseButton")
    if sessionOnly then return end

    local locked = self.db.settings.hudLocked
    hud:SetMovable(not locked)
    hud.lock:SetNormalTexture(locked and "Interface\\Buttons\\LockButton-Locked-Up" or "Interface\\Buttons\\LockButton-Unlocked-Up")

    local free, total = self:FreeSlots(), self:TotalSlots()
    local t = self:Totals()
    hud.goldL:SetText(L["Gold"])
    hud.goldR:SetText(GP.Coins(t.gold, true))
    hud.bagsL:SetText(string.format(L["Bags  %s%d free|r|cff8a8880/%d|r"], free == 0 and "|cffff6b5b" or (free <= 3 and "|cffff9944" or "|cff5fd35f"), free, total))
    hud.bagsR:SetText(string.format(L["%s |cff8a8880(vendor %s)|r"], GP.Coins(t.best, true), GP.Coins(t.vendor, true)))
    hud.totalL:SetText(L["Total"])
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
                t:AddLine(L["Shift-click to always keep it."], 0.6, 0.6, 0.6)
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
        hud.cheapLabel:SetText(fit > 1 and L["CHEAPEST TO THROW AWAY"] or L["CHEAPEST TO THROW AWAY  (drag down for more)"])
    else
        hud.room:Hide()
        hud.cheapLabel:SetText(L["NOTHING SAFE TO THROW AWAY"])
    end

    local h = 124 + shown * 24 + 4
    if mine + alts > 0 then
        local parts = {}
        if mine > 0 then parts[#parts + 1] = string.format(L["|cff5fd35f%s for you|r"], GP.Plural(mine, "upgrade")) end
        if alts > 0 then parts[#parts + 1] = string.format(L["|cffff9944%d for alts|r"], alts) end
        hud.upText:SetText(table.concat(parts, "  ·  ") .. L[" |cff8a8880(click)|r"])
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
        hud.junk:SetLabel(string.format(L["Sell %s for %s"], GP.Plural(nJunk, "grey item"), GP.Coins(junk, true)))
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
