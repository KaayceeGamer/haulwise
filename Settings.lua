-- Haulwise: Settings window. Appearance (font, text size, scale, background) and every option.
local _, GP = ...
local L = GP.L

local panel

-- [x] Label
--     What it does, in grey, always visible (no need to hover).
local DESC_W = 420
local function check(parent, label, y, key, desc, after)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", 0, y)
    b:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    local box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    box:SetSize(12, 12)
    box:SetPoint("TOPLEFT", 0, -3)
    box:SetBackdrop(GP.FLAT)
    box:SetBackdropColor(0.1, 0.1, 0.1, 1)
    box:SetBackdropBorderColor(0.5, 0.42, 0.2, 1)
    local fill = GP.Tex(box, "ARTWORK", GP.GOLD[1], GP.GOLD[2], GP.GOLD[3])
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    local fs = b:CreateFontString(nil, "OVERLAY", "HaulwiseFont")
    fs:SetPoint("TOPLEFT", 20, -1)
    fs:SetText(label)
    local d = b:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    d:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
    d:SetWidth(DESC_W)
    d:SetJustifyH("LEFT")
    d:SetTextColor(0.6, 0.58, 0.54)
    d:SetText(desc)
    local h = 18 + (d:GetStringHeight() or 14) + 4
    b:SetHeight(h)
    local hl = GP.Tex(b, "HIGHLIGHT", 1, 0.82, 0.25, 0.05)
    hl:SetAllPoints()
    local function draw() fill:SetShown(GP.db.settings[key] and true or false) end
    b:SetScript("OnClick", function()
        GP.db.settings[key] = not GP.db.settings[key]
        draw()
        if after then after() end
        if GP.RefreshUI then GP:RefreshUI() end
        if GP.RefreshHUD then GP:RefreshHUD() end
    end)
    return draw, h
end

-- Label .............................. [button]  (or a stepper)
local function rowLabel(parent, text, y)
    local l = parent:CreateFontString(nil, "OVERLAY", "HaulwiseFont")
    l:SetPoint("TOPLEFT", 0, y)
    l:SetText(text)
    return l
end

local function setScale(name, key, v)
    GP.db.settings[key] = v
    local f = _G[name]
    if f then f:SetScale(v) end
end

-- The sections, each a page. A check: { label, setting, what it does, run after a change }.
local function sections(s)
    return {
        { L["Look"], "appearance" },
        { L["Bags and loot"], {
            { L["Swap popup"], "swapPopups", L["Bags full while looting: offer to swap the cheapest item for the loot."] },
            { L["Make room popup"], "makeRoomPopup", L["\"Inventory is full\" elsewhere: offer the cheapest items to delete."] },
            { L["Disenchant value"], "useDisenchant", L["Value gear at what disenchanting gives, when you or an alt can disenchant it."] },
            { L["Protect recipe reagents"], "protectReagents", L["Never offer items your known recipes use. Crafting materials are never offered anyway."] },
        } },
        { L["Gear"], {
            { L["Upgrade Advisor"], "upgradeAdvisor", L["Check gear you pick up against what you wear."] },
            { L["Upgrade popups"], "upgradePopups", L["Show a popup when new loot is an upgrade (once per item)."] },
            { L["Send to alts at mailbox"], "sendToAltsAtMailbox", L["At a mailbox, list gear that's an upgrade for one of your alts."] },
            { L["Quest reward pick"], "questPick", L["When a quest lets you choose a reward, mark the best one: your biggest gear upgrade, or else the one worth the most gold."] },
        } },
        { L["Farming"], {
            { L["Community data"], "useShared", L["Add everyone's pooled kills (shipped with Haulwise) and friends' imports to your own."] },
            { L["Loot-table estimates"], "useEstimates", L["Also rank mobs nobody has farmed yet, from Classic's loot tables (Haulwise Data). Real kills take over as they come in."] },
            { L["Record in groups"], "trackInGroup", L["Group loot makes drop rates less accurate, so Haulwise records solo kills only unless this is on."] },
            { L["Remind me to share"], "shareReminder", L["A chat line every 100 kills you haven't shared yet. Sharing is always manual."] },
        } },
        { L["Auction house and mail"], {
            { L["Price help when selling"], "sellHelper", L["Next to the AH sell frame: a suggested price from the live listings and your scans, and a warning when a vendor pays more. You still press Post yourself."] },
            { L["TSM prices"], "useTSM", L["With TradeSkillMaster installed: use its market value (from the TSM desktop app) when your own scan is more than 3 days old. Prices shared for your realm and your fresh scans still come first."] },
            { L["Mats to crafters"], "matsToCrafters", L["At a mailbox: offer to send crafting mats in your bags to the alt whose recipes use them."] },
            { L["Enchant requests"], "hearTrade", L["Counts the enchants people ask for in trade chat while you're in a city. It's an estimate, not sales: many ask by whisper, others answer first, and the words in chat are guessed at. Nothing about who asked is saved."] },
        } },
        { L["Tooltips"], {
            { L["Disenchant in tooltips"], "tooltipDisenchant", L["Item tooltips show what gear disenchants into, at your AH prices, and what your own disenchants gave."] },
            { L["Used for in tooltips"], "tooltipUses", L["Item tooltips show the quests and crafts that use an item, who sells it and what drops it."] },
        } },
    }
end

local function buildAppearance(page, s, add)
    local y = 0
    local function button(label, w)
        local b = GP.FlatButton(page, "", w or 156, 20)
        b:SetPoint("TOPRIGHT", 0, y + 3)
        rowLabel(page, label, y)
        return b
    end
    -- Font: a button that cycles through the game's fonts, showing each in itself.
    local fontBtn = button(L["Font"])
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
    y = y - 28
    -- Language: Auto follows the game; the change shows after /reload.
    local langBtn = button(L["Language"])
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
    y = y - 30
    local pct = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
    local function stepRow(label, get, set, fmt, step, lo, hi)
        rowLabel(page, label, y)
        local plus = GP.FlatButton(page, "+", 22, 20)
        plus:SetPoint("TOPRIGHT", 0, y + 3)
        local val = page:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
        val:SetPoint("RIGHT", plus, "LEFT", -6, 0)
        val:SetWidth(90)
        val:SetJustifyH("CENTER")
        local minus = GP.FlatButton(page, "-", 22, 20)
        minus:SetPoint("RIGHT", val, "LEFT", -6, 0)
        local function draw() val:SetText(fmt(get())) end
        local function change(d)
            local v = math.floor((get() + d) / step + 0.5) * step
            set(math.max(lo, math.min(hi, v)))
            draw()
        end
        plus:SetScript("OnClick", function() change(step) end)
        minus:SetScript("OnClick", function() change(-step) end)
        add(draw)
        y = y - 28
    end
    stepRow(L["Text size"], function() return s.fontSize or 12 end,
        function(v) s.fontSize = v; GP.ApplyFonts(); if GP.RefreshUI then GP:RefreshUI() end end,
        function(v) return v .. L[" pt"] end, 1, 9, 18)
    stepRow(L["Window size"], function() return s.winScale or 1 end,
        function(v) setScale("HaulwiseFrame", "winScale", v) end, pct, 0.05, 0.6, 1.6)
    stepRow(L["HUD size"], function() return s.hudScale or 1 end,
        function(v) setScale("HaulwiseHUD", "hudScale", v) end, pct, 0.05, 0.6, 1.6)
    stepRow(L["Background"], function() return s.opacity or 0.96 end,
        function(v) s.opacity = v; GP.ApplyOpacity() end, pct, 0.05, 0.3, 1.0)
    y = y - 8
    for _, c in ipairs({
        { L["Show the HUD"], "hudShown", L["The small box that stays on screen."],
          function() if s.hudShown then GP:ShowHUD() elseif HaulwiseHUD then HaulwiseHUD:Hide() end end },
        { L["Lock HUD position"], "hudLocked", L["Stop the HUD from being dragged by accident."] },
        { L["Minimap button"], "minimap", L["Click: open Haulwise. Right-click: settings. Shift-click: the HUD. Drag it around the minimap."],
          function() GP:UpdateMinimapButton() end },
    }) do
        local draw, h = check(page, c[1], y, c[2], c[3], c[4])
        add(draw)
        y = y - h - 6
    end
    return -y
end

local W, SIDE = 660, 170
local function build()
    panel = GP.Panel("HaulwiseSettings", W, 470, L["Haulwise settings"])
    panel:SetFrameStrata("DIALOG")
    local s = GP.db.settings
    local draws = {}
    local function add(d) draws[#draws + 1] = d end

    -- Left: the sections, like the main window's tabs but stacked. Right: the page.
    local sideBg = GP.Tex(panel, "BACKGROUND", 0.07, 0.07, 0.08)
    sideBg:SetPoint("TOPLEFT", 1, -27)
    sideBg:SetPoint("BOTTOMLEFT", 1, 46)
    sideBg:SetWidth(SIDE)
    local pages, buttons, tallest = {}, {}, 0
    local function select(i)
        for j, p in ipairs(pages) do
            p:SetShown(i == j)
            local b = buttons[j]
            b.on:SetShown(i == j)
            b.bar:SetShown(i == j)
            if i == j then b.fs:SetTextColor(GP.GOLD[1], GP.GOLD[2], GP.GOLD[3]) else b.fs:SetTextColor(0.7, 0.68, 0.62) end
        end
        panel.section = i
    end
    for i, sec in ipairs(sections(s)) do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(SIDE, 28)
        b:SetPoint("TOPLEFT", 1, -32 - (i - 1) * 30)
        b.on = GP.Tex(b, "BACKGROUND", 1, 0.82, 0.25, 0.10)
        b.on:SetAllPoints()
        b.bar = GP.Tex(b, "ARTWORK", GP.GOLD[1], GP.GOLD[2], GP.GOLD[3])
        b.bar:SetPoint("TOPLEFT")
        b.bar:SetPoint("BOTTOMLEFT")
        b.bar:SetWidth(3)
        local hl = GP.Tex(b, "HIGHLIGHT", 1, 0.82, 0.25, 0.06)
        hl:SetAllPoints()
        b.fs = b:CreateFontString(nil, "OVERLAY", "HaulwiseFont")
        b.fs:SetPoint("LEFT", 14, 0)
        b.fs:SetText(sec[1])
        b:SetScript("OnClick", function() select(i) end)
        buttons[i] = b

        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", SIDE + 20, -40)
        page:SetPoint("TOPRIGHT", -18, -40)
        page:SetHeight(10)
        local h
        if sec[2] == "appearance" then
            h = buildAppearance(page, s, add)
        else
            local y = 0
            for _, c in ipairs(sec[2]) do
                local draw, ch = check(page, c[1], y, c[2], c[3], c[4])
                add(draw)
                y = y - ch - 8
            end
            h = -y
        end
        page:SetHeight(h)
        tallest = math.max(tallest, h, #buttons * 30)
        pages[i] = page
    end

    -- Buttons of the same width across the bottom, so nothing overlaps.
    local BW, GAP = 110, 6
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
    done:SetPoint("BOTTOMRIGHT", -14, 12)
    done:SetScript("OnClick", function() panel:Hide() end)

    panel.draws = draws
    panel.select = select
    panel:SetHeight(math.max(360, tallest + 40 + 60))
    select(1)
end

function GP:ToggleSettings()
    if not panel then build() end
    if panel:IsShown() then panel:Hide(); return end
    panel:RestorePosition({ "CENTER", UIParent, "CENTER", 0, 40 })
    for _, d in ipairs(panel.draws) do d() end
    panel:Show()
end
