-- Haulwise: shared look. Flat dark panels with a gold edge, item rows with icons, flat buttons.
local _, GP = ...
local L = GP.L

-- Fonts: Haulwise's own font objects, so the font and size can be changed in Settings.
GP.FONTS = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri",        path = "Fonts\\SKURRI.TTF" },
}
-- name, copy-from, size offset from the base size, colour
local FONT_OBJECTS = {
    { "HaulwiseFontSmall",     "GameFontHighlightSmall", -2, { 1, 1, 1 } },
    { "HaulwiseFontSmallGold", "GameFontNormalSmall",    -2, { 1, 0.82, 0 } },
    { "HaulwiseFontSmallGrey", "GameFontDisableSmall",   -2, { 0.5, 0.5, 0.5 } },
    { "HaulwiseFont",          "GameFontHighlight",       0, { 1, 1, 1 } },
    { "HaulwiseFontGold",      "GameFontNormal",          0, { 1, 0.82, 0 } },
    { "HaulwiseFontLarge",     "GameFontNormalLarge",     4, { 1, 0.82, 0 } },
}
for _, o in ipairs(FONT_OBJECTS) do
    local fo = CreateFont(o[1])
    if _G[o[2]] then fo:CopyFontObject(_G[o[2]]) end
    fo:SetTextColor(o[4][1], o[4][2], o[4][3])
end

function GP.ApplyFonts()
    local s = GP.db.settings
    local path = (GP.FONTS[s.font or 1] or GP.FONTS[1]).path
    local base = s.fontSize or 12
    for _, o in ipairs(FONT_OBJECTS) do
        local fo = _G[o[1]]
        if fo then fo:SetFont(path, math.max(8, base + o[3]), "") end
    end
end

-- Every Haulwise panel, so background opacity can be changed in one go.
GP.panels = {}
function GP.ApplyOpacity()
    local a = GP.db.settings.opacity or 0.96
    for _, f in ipairs(GP.panels) do f:SetBackdropColor(0.055, 0.058, 0.07, a) end
end

GP.FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
GP.GOLD = { 1, 0.82, 0.25 }
GP.KIND_COLOR = {
    quest = { 1, 0.82, 0.1 }, upgrade = { 0.35, 0.85, 0.35 }, alt = { 1, 0.6, 0.25 }, reagent = { 0.3, 0.8, 0.75 },
    plain = { 1, 0.82, 0.25 }, bad = { 1, 0.35, 0.3 }, room = { 0.8, 0.55, 0.3 },
}

function GP.Tex(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- A movable panel with a header strip, a title and a close button. Position is remembered.
function GP.Panel(name, w, h, title)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(GP.FLAT)
    f:SetBackdropColor(0.055, 0.058, 0.07, (GP.db and GP.db.settings.opacity) or 0.96)
    f:SetBackdropBorderColor(0.5, 0.4, 0.18, 1)
    table.insert(GP.panels, f)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        if GP.db and name then GP.db.positions[name] = { p, rp, x, y } end
    end)
    local head = GP.Tex(f, "BACKGROUND", 0.09, 0.09, 0.105)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(26)
    f.accent = GP.Tex(f, "ARTWORK", GP.GOLD[1], GP.GOLD[2], GP.GOLD[3])
    f.accent:SetPoint("TOPLEFT", 1, -1)
    f.accent:SetPoint("TOPRIGHT", -1, -1)
    f.accent:SetHeight(2)
    f.title = f:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
    f.title:SetPoint("TOPLEFT", 12, -8)
    f.title:SetText(title or "")
    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)
    f.close:SetScale(0.8)
    f:Hide()
    function f:RestorePosition(defaultPoint)
        local pos = GP.db and name and GP.db.positions[name]
        self:ClearAllPoints()
        if pos then self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else self:SetPoint(unpack(defaultPoint)) end
    end
    function f:SetKind(kind)
        local c = GP.KIND_COLOR[kind] or GP.GOLD
        self.accent:SetColorTexture(c[1], c[2], c[3], 1)
        self.title:SetTextColor(c[1], c[2], c[3])
    end
    return f
end

function GP.FlatButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h or 22)
    b:SetBackdrop(GP.FLAT)
    b:SetBackdropColor(0.14, 0.12, 0.08, 1)
    b:SetBackdropBorderColor(0.42, 0.33, 0.15, 1)
    local hl = GP.Tex(b, "HIGHLIGHT", 1, 0.82, 0.25, 0.10)
    hl:SetAllPoints()
    b.label = b:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGold")
    b.label:SetPoint("CENTER")
    -- Longer translations shrink a little to fit instead of spilling over the edge.
    local function fit(self)
        local fs = self.label
        if not fs.SetTextScale then return end
        fs:SetTextScale(1)
        local sw, room = fs:GetStringWidth() or 0, (self:GetWidth() or 0) - 8
        if sw > room and sw > 0 and room > 0 then fs:SetTextScale(math.max(0.72, room / sw)) end
    end
    b.label:SetText(text)
    fit(b)
    function b:SetLabel(t) self.label:SetText(t); fit(self) end
    function b:SetPrimary(on)
        if on then self:SetBackdropColor(0.16, 0.3, 0.12, 1); self:SetBackdropBorderColor(0.35, 0.7, 0.3, 1)
        else self:SetBackdropColor(0.14, 0.12, 0.08, 1); self:SetBackdropBorderColor(0.42, 0.33, 0.15, 1) end
    end
    return b
end

-- An item line: icon, name, and text on the right. r.tip(tooltip) adds tooltip lines.
function GP.ItemRow(parent, width)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(width, 22)
    local hl = GP.Tex(r, "HIGHLIGHT", 1, 0.82, 0.25, 0.08)
    hl:SetAllPoints()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = r:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.right = r:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    r.right:SetPoint("RIGHT", -2, 0)
    r.right:SetJustifyH("RIGHT")
    r.name:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
    function r:SetItem(id, link, rightText, count)
        self.id, self.link = id, link
        self.icon:SetTexture(GP.ItemIcon(id))
        local name, quality = GP.ItemInfo(id)
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
        local label = (c and c.hex or "|cffffffff") .. (name or (L["item #"] .. id)) .. "|r"
        if count and count > 1 then label = label .. " |cffaaaaaax" .. count .. "|r" end
        self.name:SetText(label)
        self.right:SetText(rightText or "")
    end
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.tip then self.tip(GameTooltip) elseif self.link then GameTooltip:SetHyperlink(self.link) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

-- Value text: "1g 20s V" with the source tag coloured.
function GP.ValueText(total, src, d)
    return GP.Coins(total, true) .. " " .. GP.SourceTag(src, d)
end

-- Tooltip lines explaining a bag value.
function GP.AddValueLines(t, unit, src, d, count)
    count = count or 1
    t:AddLine(" ")
    t:AddDoubleLine(L["|cffffd040Haulwise|r value"], GP.Coins(unit * count) .. " " .. GP.SourceTag(src, d))
    t:AddDoubleLine(L["  Vendor"], GP.Coins((d.vendor or 0) * count), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
    if d.ah then
        local age = d.ahAge and (d.ahAge < 86400 and L["today"] or string.format(L["%dd old"], math.floor(d.ahAge / 86400))) or "?"
        t:AddDoubleLine(L["  Auction (after cut)"], GP.Coins(d.ah * count) .. " " .. GP.AgeColor(d.ahAge) .. age .. "|r", 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
    end
    if d.deOutcomes then
        if d.de then
            t:AddDoubleLine(L["  Disenchant (expected)"], GP.Coins(d.de * count), 0.77, 0.55, 1, 0.77, 0.55, 1)
        end
        for _, o in ipairs(d.deOutcomes) do
            local name = GP.ItemInfo(o[1]) or ("#" .. o[1])
            t:AddDoubleLine(string.format("    %.0f%%  %d-%d %s", o[2] * 100, o[3], o[4], name),
                o.unit and (GP.Coins(o.unit) .. L[" each"]) or L["|cff999999no price|r"], 0.65, 0.65, 0.65, 0.65, 0.65, 0.65)
        end
        if d.deWho and #d.deWho > 0 then t:AddLine(L["    Can disenchant: "] .. table.concat(d.deWho, ", "), 0.65, 0.65, 0.65) end
    end
end

-- Scaling: Ctrl + mouse wheel over the window, or the sliders in Settings. Remembered per window.
function GP.ApplyScale(frame, key)
    local sc = GP.db.settings[key] or 1
    frame:SetScale(sc)
end

function GP.Rescale(frame, key, delta)
    local s = GP.db.settings
    local sc = math.floor(((s[key] or 1) + delta) * 20 + 0.5) / 20
    sc = math.max(0.6, math.min(1.6, sc))
    s[key] = sc
    frame:SetScale(sc)
    return sc
end

function GP.MakeScalable(frame, key)
    GP.ApplyScale(frame, key)
    local old = frame:GetScript("OnMouseWheel")
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        if IsControlKeyDown and IsControlKeyDown() then GP.Rescale(self, key, delta * 0.05)
        elseif old then old(self, delta) end
    end)
end

-- Resizing: drag the grip in the bottom-right corner. Size is remembered per window.
function GP.MakeResizable(frame, key, minW, minH, maxW, maxH, onResize)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(minW, minH, maxW, maxH)
    elseif frame.SetMinResize then frame:SetMinResize(minW, minH); frame:SetMaxResize(maxW, maxH) end
    local saved = GP.db.sizes[key]
    if saved then frame:SetSize(math.max(minW, math.min(maxW, saved[1])), math.max(minH, math.min(maxH, saved[2]))) end
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame.sizing = true; frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if frame.sizing and onResize then onResize() end
        frame.sizing = false
        GP.db.sizes[key] = { frame:GetWidth(), frame:GetHeight() }
        if onResize then onResize() end
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Drag to resize"])
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnSizeChanged", function() if onResize then onResize() end end)
    frame.grip = grip
    return grip
end

function GP.IconButton(parent, texture, tip, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 16, size or 16)
    b:SetNormalTexture(texture)
    b:SetHighlightTexture(texture)
    if b.GetHighlightTexture and b:GetHighlightTexture() then b:GetHighlightTexture():SetAlpha(0.4) end
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(tip); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
