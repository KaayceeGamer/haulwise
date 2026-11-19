-- Haulwise: Settings window. Appearance (font, text size, scale, background) and every option.
local _, GP = ...
local L = GP.L

local panel

local function heading(parent, text, y)
    local h = parent:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
    h:SetPoint("TOPLEFT", 14, y)
    h:SetText(text)
    local line = GP.Tex(parent, "BORDER", 1, 0.82, 0.25, 0.25)
    line:SetPoint("TOPLEFT", 14, y - 16)
    line:SetPoint("RIGHT", -14, 0)
    line:SetHeight(1)
    return h
end

-- label ............ [-] value [+]
local function stepper(parent, label, y, get, set, fmt, step, lo, hi, tip)
    local l = parent:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    l:SetPoint("TOPLEFT", 18, y)
    l:SetText(label)
    local plus = GP.FlatButton(parent, "+", 20, 18)
    plus:SetPoint("TOPRIGHT", -14, y + 2)
    local val = parent:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    val:SetPoint("RIGHT", plus, "LEFT", -6, 0)
    val:SetWidth(90)
    val:SetJustifyH("CENTER")
    local minus = GP.FlatButton(parent, "-", 20, 18)
    minus:SetPoint("RIGHT", val, "LEFT", -6, 0)
    local function draw() val:SetText(fmt(get())) end
    local function change(d)
        local v = math.floor((get() + d) / step + 0.5) * step
        set(math.max(lo, math.min(hi, v)))
        draw()
    end
    plus:SetScript("OnClick", function() change(step) end)
    minus:SetScript("OnClick", function() change(-step) end)
    if tip then
        for _, w in ipairs({ plus, minus }) do
            w:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(tip, 1, 1, 1, true); GameTooltip:Show() end)
            w:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end
    return draw
end

-- [x] label (two per row)
local function check(parent, label, x, y, key, tip, after)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(170, 18)
    b:SetPoint("TOPLEFT", x, y)
    local box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    box:SetSize(12, 12)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop(GP.FLAT)
    box:SetBackdropColor(0.1, 0.1, 0.1, 1)
    box:SetBackdropBorderColor(0.5, 0.42, 0.2, 1)
    local fill = GP.Tex(box, "ARTWORK", GP.GOLD[1], GP.GOLD[2], GP.GOLD[3])
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    local fs = b:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
    fs:SetText(label)
    local function draw() fill:SetShown(GP.db.settings[key] and true or false) end
    b:SetScript("OnClick", function()
        GP.db.settings[key] = not GP.db.settings[key]
        draw()
        if after then after() end
        if GP.RefreshUI then GP:RefreshUI() end
        if GP.RefreshHUD then GP:RefreshHUD() end
    end)
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(tip, 1, 1, 1, true); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return draw
end

local function setScale(name, key, v)
    GP.db.settings[key] = v
    local f = _G[name]
    if f then f:SetScale(v) end
end

local function build()
    panel = GP.Panel("HaulwiseSettings", 400, 662, L["Haulwise settings"])
    panel:SetFrameStrata("DIALOG")
    local s = GP.db.settings
    local draws = {}
    local function add(d) draws[#draws + 1] = d end
    local pct = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

    local y = -38
    heading(panel, L["Appearance"], y)
    y = y - 26
    -- Font: a button that cycles through the game's fonts, showing each in itself.
    local fl = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    fl:SetPoint("TOPLEFT", 18, y)
    fl:SetText(L["Font"])
    local fontBtn = GP.FlatButton(panel, "", 156, 20)
    fontBtn:SetPoint("TOPRIGHT", -14, y + 3)
    local function drawFont()
        local f = GP.FONTS[s.font or 1] or GP.FONTS[1]
        fontBtn.label:SetFont(f.path, 12, "")
        fontBtn:SetLabel(f.name)
    end
    fontBtn:SetScript("OnClick", function()
        s.font = (s.font or 1) % #GP.FONTS + 1
        GP.ApplyFonts()
        drawFont()
        if GP.RefreshUI then GP:RefreshUI() end
    end)
    add(drawFont)
    y = y - 26
    -- Language: Auto follows the game; the change shows after /reload.
    local ll = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    ll:SetPoint("TOPLEFT", 18, y)
    ll:SetText(L["Language"])
    local langBtn = GP.FlatButton(panel, "", 156, 20)
    langBtn:SetPoint("TOPRIGHT", -14, y + 3)
    local function drawLang()
        local code = s.language or "auto"
        local name = GP.LANGUAGE_NAMES[code] or code
        if code == "auto" then name = L["Auto (game language)"] end
        langBtn:SetLabel(code ~= GP.LANG and code ~= "auto" and (name .. "  |cffff9944/reload|r") or name)
    end
    langBtn:SetScript("OnClick", function()
        local idx = 1
        for i, c in ipairs(GP.LANGUAGES) do if c == (s.language or "auto") then idx = i end end
        s.language = GP.LANGUAGES[idx % #GP.LANGUAGES + 1]
        GP.Print(L["Language: "] .. (GP.LANGUAGE_NAMES[s.language] or s.language) .. ". " .. L["Type /reload to apply."])
        drawLang()
    end)
    langBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Haulwise's language. Auto uses your game's language. Type /reload after changing it."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    langBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    add(drawLang)
    y = y - 26
    add(stepper(panel, L["Text size"], y, function() return s.fontSize or 12 end,
        function(v) s.fontSize = v; GP.ApplyFonts(); if GP.RefreshUI then GP:RefreshUI() end end,
        function(v) return v .. L[" pt"] end, 1, 9, 18))
    y = y - 26
    add(stepper(panel, L["Window size"], y, function() return s.winScale or 1 end,
        function(v) setScale("HaulwiseFrame", "winScale", v) end, pct, 0.05, 0.6, 1.6,
        L["Scales the whole window. Drag the bottom-right corner to change its width and height instead."]))
    y = y - 26
    add(stepper(panel, L["HUD size"], y, function() return s.hudScale or 1 end,
        function(v) setScale("HaulwiseHUD", "hudScale", v) end, pct, 0.05, 0.6, 1.6))
    y = y - 26
    add(stepper(panel, L["Background"], y, function() return s.opacity or 0.96 end,
        function(v) s.opacity = v; GP.ApplyOpacity() end, pct, 0.05, 0.3, 1.0, L["How see-through the windows are."]))
    y = y - 28
    add(check(panel, L["Show the HUD"], 18, y, "hudShown", L["The small box that stays on screen."],
        function() if s.hudShown then GP:ShowHUD() elseif HaulwiseHUD then HaulwiseHUD:Hide() end end))
    add(check(panel, L["Lock HUD position"], 200, y, "hudLocked", L["Stop the HUD from being dragged by accident."]))
    y = y - 22
    add(check(panel, L["Minimap button"], 18, y, "minimap", L["Click: open Haulwise. Right-click: settings. Shift-click: the HUD. Drag it around the minimap."],
        function() GP:UpdateMinimapButton() end))

    y = y - 34
    heading(panel, L["Bags and loot"], y)
    y = y - 26
    add(check(panel, L["Swap popup"], 18, y, "swapPopups", L["Bags full while looting: offer to swap the cheapest item for the loot."]))
    add(check(panel, L["Make room popup"], 200, y, "makeRoomPopup", L["\"Inventory is full\" elsewhere: offer the cheapest items to delete."]))
    y = y - 22
    add(check(panel, L["Disenchant value"], 18, y, "useDisenchant", L["Value gear at what disenchanting gives, when you or an alt can disenchant it."]))
    add(check(panel, L["Protect recipe reagents"], 200, y, "protectReagents", L["Never offer items your known recipes use. Crafting materials are never offered anyway."]))

    y = y - 34
    heading(panel, L["Gear"], y)
    y = y - 26
    add(check(panel, L["Upgrade Advisor"], 18, y, "upgradeAdvisor", L["Check gear you pick up against what you wear."]))
    add(check(panel, L["Upgrade popups"], 200, y, "upgradePopups", L["Show a popup when new loot is an upgrade (once per item)."]))
    y = y - 22
    add(check(panel, L["Send to alts at mailbox"], 18, y, "sendToAltsAtMailbox", L["At a mailbox, list gear that's an upgrade for one of your alts."]))
    add(check(panel, L["Use Pawn's stat weights"], 200, y, "usePawn",
        L["With Pawn installed, judge gear with the Pawn scales you have switched on for each character (log in on an alt once so Haulwise knows its scales). Off: Haulwise's own weights per talent tree."],
        function() GP:ScanUpgrades() end))
    y = y - 22
    add(check(panel, L["Quest reward pick"], 18, y, "questPick", L["When a quest lets you choose a reward, mark the best one: your biggest gear upgrade, or else the one worth the most gold."]))

    y = y - 34
    heading(panel, L["Farming"], y)
    y = y - 26
    add(check(panel, L["Community data"], 18, y, "useShared", L["Add everyone's pooled kills (shipped with Haulwise) and friends' imports to your own."]))
    add(check(panel, L["Record in groups"], 200, y, "trackInGroup", L["Group loot makes drop rates less accurate, so Haulwise records solo kills only unless this is on."]))
    y = y - 22
    add(check(panel, L["Remind me to share"], 18, y, "shareReminder", L["A chat line every 100 kills you haven't shared yet. Sharing is always manual."]))
    y = y - 34
    heading(panel, L["Auction house and mail"], y)
    y = y - 26
    add(check(panel, L["Price help when selling"], 18, y, "sellHelper", L["Next to the AH sell frame: a suggested price from the live listings and your scans, and a warning when a vendor pays more. You still press Post yourself."]))
    y = y - 22
    add(check(panel, L["Disenchant in tooltips"], 18, y, "tooltipDisenchant", L["Item tooltips show what gear disenchants into, at your AH prices, and what your own disenchants gave."]))
    y = y - 22
    add(check(panel, L["Used for in tooltips"], 18, y, "tooltipUses", L["Item tooltips show the quests and crafts that use an item, who sells it and what drops it."]))
    add(check(panel, L["Mats to crafters"], 200, y + 44, "matsToCrafters", L["At a mailbox: offer to send crafting mats in your bags to the alt whose recipes use them."]))

    -- Four buttons of the same width across the bottom, so nothing overlaps.
    local BW, GAP = 86, 6
    local reset = GP.FlatButton(panel, L["Reset windows"], BW, 22)
    reset:SetPoint("BOTTOMLEFT", 14, 12)
    reset:SetScript("OnClick", function()
        GP.db.positions, GP.db.sizes = {}, {}
        s.winScale, s.hudScale = 1, 1
        GP.Print(L["Positions and sizes reset. Type /reload to apply."])
        for _, d in ipairs(draws) do d() end
    end)
    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Put every Haulwise window back in its place, at its normal size."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local guideBtn = GP.FlatButton(panel, L["Guide"], BW, 22)
    guideBtn:SetPoint("LEFT", reset, "RIGHT", GAP, 0)
    guideBtn:SetScript("OnClick", function() GP:ShowGuide(false) end)
    local fbBtn = GP.FlatButton(panel, L["Feedback"], BW, 22)
    fbBtn:SetPoint("LEFT", guideBtn, "RIGHT", GAP, 0)
    fbBtn:SetScript("OnClick", function() GP:ShowFeedback() end)
    local done = GP.FlatButton(panel, L["Close"], BW, 22)
    done:SetPoint("LEFT", fbBtn, "RIGHT", GAP, 0)
    done:SetScript("OnClick", function() panel:Hide() end)

    panel.draws = draws
    panel:SetHeight(-y + 70)
end

function GP:ToggleSettings()
    if not panel then build() end
    if panel:IsShown() then panel:Hide(); return end
    panel:RestorePosition({ "CENTER", UIParent, "CENTER", 0, 40 })
    for _, d in ipairs(panel.draws) do d() end
    panel:Show()
end
