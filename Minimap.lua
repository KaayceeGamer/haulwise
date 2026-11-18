-- Haulwise: minimap button. Left-click opens the window, right-click the settings, Shift-click
-- the HUD; drag it around the minimap. With a data broker display (Titan Panel, ElvUI, Bazooka...)
-- Haulwise also shows up there as a launcher.
local _, GP = ...
local L = GP.L

local ICON = "Interface\\AddOns\\Haulwise\\Media\\minimap"
local button

function GP:MinimapTooltip(tt)
    local C = GP.Coins
    tt:AddLine("Haulwise", 1, 0.82, 0.25)
    local s = self.session
    if s then
        local mins = math.max(1, (time() - s.start) / 60)
        tt:AddDoubleLine(L["This session"], string.format(L["%s/h (%d kills)"], C(s.value / mins * 60, true), s.kills), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    local ok, t = pcall(self.Totals, self)
    if ok and t then
        tt:AddDoubleLine(L["Gold"], C(t.gold, true), 0.8, 0.8, 0.8, 1, 1, 1)
        tt:AddDoubleLine(L["Bags at best value"], C(t.best, true), 0.8, 0.8, 0.8, 1, 1, 1)
        local free, total = self:FreeSlots(), self:TotalSlots()
        tt:AddDoubleLine(L["Free bag slots"], string.format("%d/%d", free, total), 0.8, 0.8, 0.8,
            free == 0 and 1 or 0.37, free == 0 and 0.42 or 0.83, free == 0 and 0.36 or 0.37)
    end
    local mine = self.upgrades and #self.upgrades.mine or 0
    if mine > 0 then tt:AddLine(string.format(L["%d gear upgrades in your bags"], mine), 0.37, 0.83, 0.37) end
    tt:AddLine(" ")
    tt:AddLine(L["Click: open Haulwise"], 0.6, 0.6, 0.6)
    tt:AddLine(L["Right-click: settings"], 0.6, 0.6, 0.6)
    tt:AddLine(L["Shift-click: show or hide the HUD"], 0.6, 0.6, 0.6)
end

function GP:LauncherClick(btn)
    if btn == "RightButton" then
        self:ToggleSettings()
    elseif IsShiftKeyDown and IsShiftKeyDown() then
        self:ToggleHUD()
    else
        self:ToggleUI()
    end
end

-- Round minimaps: a circle. Square ones (ElvUI and others): along the edge of the square.
local function place()
    local a = math.rad(GP.db.settings.minimapAngle or 205)
    local x, y = math.cos(a), math.sin(a)
    local r = (Minimap:GetWidth() / 2) + 6
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
        r = (Minimap:GetWidth() / 2) - 4
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

local function dragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local atan2 = math.atan2 or atan2
    GP.db.settings.minimapAngle = math.deg(atan2(py - my, px - mx)) % 360
    place()
end

local function build()
    if button or not Minimap then return end
    button = CreateFrame("Button", "HaulwiseMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    button.icon = icon
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, btn) GP:LauncherClick(btn) end)
    button:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -6) end)
    button:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -5) end)
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", dragUpdate)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
        icon:SetPoint("TOPLEFT", 7, -5)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GP:MinimapTooltip(GameTooltip)
        GameTooltip:AddLine(L["Drag: move this button"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    place()
end

function GP:UpdateMinimapButton()
    if self.db.settings.minimap ~= false then
        build()
        if button then place(); button:Show() end
    elseif button then
        button:Hide()
    end
end

-- Data broker launcher, only when another addon brought LibDataBroker along.
local function registerBroker()
    local stub = _G.LibStub
    local ldb = stub and stub("LibDataBroker-1.1", true)
    if not ldb or GP.broker then return end
    GP.broker = ldb:NewDataObject("Haulwise", {
        type = "launcher",
        label = "Haulwise",
        icon = ICON,
        OnClick = function(_, btn) GP:LauncherClick(btn) end,
        OnTooltipShow = function(tt) GP:MinimapTooltip(tt) end,
    })
end

GP:On("PLAYER_LOGIN", function()
    GP:UpdateMinimapButton()
    registerBroker()
end)
