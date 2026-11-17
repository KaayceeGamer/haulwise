-- Haulwise: popups. Swap (bags full while looting), Make room, and Upgrade found.
local _, GP = ...

local KIND_TITLE = {
    quest = "QUEST ITEM: make room", upgrade = "GEAR UPGRADE: make room", reagent = "REAGENT YOU USE: make room",
    plain = "BAGS FULL: swap?", bad = "NOT WORTH A SWAP",
}

-- Swap and Make room ---------------------------------------------------------------------------
-- Only one of these is ever on screen. The swap card sits right next to the loot window, so your
-- eyes don't have to leave it; Make room is for "Inventory is full" outside a loot window.

local swap, room

-- Next to the loot window if it's open, otherwise where you last dragged it.
local function placeNearLoot(p, default)
    local lf = LootFrame
    if lf and lf.IsShown and lf:IsShown() then
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", lf, "TOPRIGHT", 8, 0)
    else
        p:RestorePosition(default)
    end
end

local function itemLine(parent, sign, color)
    local row = GP.ItemRow(parent, 300)
    row.sign = parent:CreateFontString(nil, "OVERLAY", "HaulwiseFontLarge")
    row.sign:SetPoint("RIGHT", row, "LEFT", -6, 0)
    row.sign:SetText(color .. sign .. "|r")
    return row
end

local function buildSwap()
    swap = GP.Panel("HaulwiseSwap", 350, 150, "")
    swap.take = itemLine(swap, "+", "|cff5fd35f")
    swap.take:SetPoint("TOPLEFT", 30, -36)
    swap.drop = itemLine(swap, "-", "|cffff6b5b")
    swap.drop:SetPoint("TOPLEFT", 30, -62)
    swap.rule = GP.Tex(swap, "ARTWORK", 1, 1, 1, 0.08)
    swap.rule:SetPoint("TOPLEFT", 12, -88)
    swap.rule:SetPoint("TOPRIGHT", -12, -88)
    swap.rule:SetHeight(1)
    swap.verdict = swap:CreateFontString(nil, "OVERLAY", "HaulwiseFont")
    swap.verdict:SetPoint("TOPRIGHT", -14, -94)
    swap.verdict:SetJustifyH("RIGHT")
    swap.note = swap:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    swap.note:SetPoint("TOPLEFT", 14, -96)
    swap.note:SetPoint("RIGHT", swap.verdict, "LEFT", -8, 0)
    swap.note:SetJustifyH("LEFT")
    swap.go = GP.FlatButton(swap, "Swap", 120, 24)
    swap.go:SetPoint("BOTTOMLEFT", 12, 10)
    swap.next = GP.FlatButton(swap, "Other item", 100, 24)
    swap.next:SetPoint("LEFT", swap.go, "RIGHT", 6, 0)
    swap.cancel = GP.FlatButton(swap, "Not now", 90, 24)
    swap.cancel:SetPoint("LEFT", swap.next, "RIGHT", 6, 0)
    swap.cancel:SetScript("OnClick", function() swap:Hide() end)
end

local function drawSwap()
    local s = swap.state
    local loot, cands = s.loot, s.cands
    local bagItem = cands[s.i]
    swap.take:SetItem(loot.id, loot.link, GP.ValueText(loot.total, loot.src, loot.d), loot.count)
    swap.take.tip = function(t) t:SetHyperlink(loot.link); GP.AddValueLines(t, loot.unit, loot.src, loot.d, loot.count) end
    local important = loot.prio and loot.prio > 0
    if not bagItem then
        swap:SetKind("bad")
        swap.title:SetText("Bags full, nothing safe to drop")
        swap.drop:Hide(); swap.drop.sign:Hide()
        swap.verdict:SetText("")
        swap.note:SetText("Everything left is protected: quest items, tools, reagents, upgrades or kept items.")
        swap.go:Hide(); swap.next:Hide()
        return
    end
    swap.drop:Show(); swap.drop.sign:Show(); swap.go:Show()
    swap.next:SetShown(#cands > 1)
    swap.drop:SetItem(bagItem.id, bagItem.link, GP.ValueText(bagItem.total, bagItem.src, bagItem.d), bagItem.count)
    swap.drop.tip = function(t) t:SetHyperlink(bagItem.link); GP.AddValueLines(t, bagItem.unit, bagItem.src, bagItem.d, bagItem.count) end
    local diff = loot.total - bagItem.total
    local worth = important or diff > 0
    local kind = worth and (loot.kind or "plain") or "bad"
    swap:SetKind(kind)
    local titles = {
        plain = "Bags full: swap?", bad = "Bags full: not worth it", quest = "Quest item: make room",
        reagent = "Reagent you use: make room",
        upgrade = loot.gain and string.format("Upgrade +%.0f%%: make room", loot.gain * 100) or "Upgrade: make room",
    }
    swap.title:SetText(titles[kind] or titles.plain)
    if diff >= 0 then
        swap.verdict:SetText("|cff5fd35f+" .. GP.Coins(diff, true) .. "|r")
    else
        swap.verdict:SetText("|cffff6b5b-" .. GP.Coins(-diff, true) .. "|r")
    end
    local why = (not worth) and "You'd lose money." or (important and diff < 0 and "Worth it: you need this." or "Cheapest item in your bags.")
    swap.note:SetText(why .. (#cands > 1 and string.format("  %d/%d", s.i, #cands) or ""))
    swap.go:SetLabel(worth and "Swap" or "Swap anyway")
    swap.go:SetPrimary(worth)
end

function GP:ShowSwapPopup(loot)
    if not swap then buildSwap() end
    if room then room:Hide() end
    swap.state = { loot = loot, cands = self:DeleteCandidates(), i = 1 }
    swap.next:SetScript("OnClick", function()
        local s = swap.state
        if #s.cands > 0 then s.i = s.i % #s.cands + 1 end
        drawSwap()
    end)
    swap.go:SetScript("OnClick", function()
        local s = swap.state
        local bagItem = s.cands[s.i]
        if not bagItem then return end
        if GetLootSlotLink(s.loot.lootSlot) ~= s.loot.link then GP.Print("That loot is gone."); swap:Hide(); return end
        if GP:DeleteBagItem(bagItem) then
            LootSlot(s.loot.lootSlot)
            swap:Hide()
        end
    end)
    drawSwap()
    placeNearLoot(swap, { "TOP", UIParent, "TOP", 0, -140 })
    swap:Show()
end

function GP:HideSwapPopup() if swap then swap:Hide() end end
function GP:SwapPopupShown() return swap and swap:IsShown() end

-- Make room: the three cheapest items at once, each with its own Delete.
local ROOM_ROWS = 3

local function buildRoom()
    room = GP.Panel("HaulwiseMakeRoom", 350, 64 + ROOM_ROWS * 26 + 40, "Make room")
    room:SetKind("room")
    room.free = room:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    room.free:SetPoint("TOPRIGHT", -30, -9)
    room.rows = {}
    for i = 1, ROOM_ROWS do
        local r = GP.ItemRow(room, 250)
        r:SetPoint("TOPLEFT", 12, -36 - (i - 1) * 26)
        r.del = GP.FlatButton(room, "Delete", 70, 22)
        r.del:SetPoint("LEFT", r, "RIGHT", 6, 0)
        room.rows[i] = r
    end
    room.note = room:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    room.note:SetPoint("TOPLEFT", 12, -42 - ROOM_ROWS * 26)
    room.note:SetPoint("RIGHT", -12, 0)
    room.note:SetJustifyH("LEFT")
    room.note:SetText("Cheapest first. Quest items, tools, reagents, upgrades and kept items are never offered.")
    room.done = GP.FlatButton(room, "Done", 80, 22)
    room.done:SetPoint("BOTTOMRIGHT", -12, 10)
    room.done:SetScript("OnClick", function() room:Hide() end)
end

local function drawRoom()
    local cands = GP:DeleteCandidates()
    local free = GP:FreeSlots()
    room.free:SetText(string.format("%s%d free|r", free == 0 and "|cffff6b5b" or "|cff5fd35f", free))
    for i, r in ipairs(room.rows) do
        local it = cands[i]
        if it then
            r:SetItem(it.id, it.link, GP.ValueText(it.total, it.src, it.d), it.count)
            r.tip = function(t) t:SetHyperlink(it.link); GP.AddValueLines(t, it.unit, it.src, it.d, it.count) end
            r.del:SetPrimary(i == 1)
            r.del:SetScript("OnClick", function()
                if GP:DeleteBagItem(it) then C_Timer.After(0.4, function() if room:IsShown() then drawRoom() end end) end
            end)
            r:Show(); r.del:Show()
        else
            r:Hide(); r.del:Hide()
        end
    end
    if #cands == 0 then room.note:SetText("Nothing left that's safe to delete.") end
end

function GP:ShowMakeRoom()
    if self:SwapPopupShown() then return end
    if not room then buildRoom() end
    room:RestorePosition({ "TOP", UIParent, "TOP", 0, -140 })
    drawRoom()
    room:Show()
end

-- Upgrade found -------------------------------------------------------------------------------------

local up
local function buildUp()
    up = GP.Panel("HaulwiseUpgrade", 360, 250, "")
    up.newRow = GP.ItemRow(up, 336)
    up.newRow:SetPoint("TOPLEFT", 12, -36)
    up.oldRow = GP.ItemRow(up, 336)
    up.oldRow:SetPoint("TOPLEFT", 12, -60)
    up.oldRow:SetAlpha(0.6)
    up.lines = {}
    for i = 1, 6 do
        local l = up:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
        l:SetPoint("TOPLEFT", 16, -90 - (i - 1) * 16)
        l:SetPoint("RIGHT", -16, 0)
        l:SetJustifyH("LEFT")
        up.lines[i] = l
    end
    up.based = up:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    up.based:SetPoint("BOTTOMLEFT", 12, 42)
    up.a = GP.FlatButton(up, "Equip", 100, 24)
    up.a:SetPoint("BOTTOMLEFT", 12, 10)
    up.b = GP.FlatButton(up, "Later", 80, 24)
    up.b:SetPoint("LEFT", up.a, "RIGHT", 6, 0)
    up.c = GP.FlatButton(up, "Ignore", 80, 24)
    up.c:SetPoint("LEFT", up.b, "RIGHT", 6, 0)
end

function GP:ShowUpgradePopup(kind, r)
    if not self.db.settings.upgradePopups then return end
    if not up then buildUp() end
    up:RestorePosition({ "TOP", UIParent, "TOP", 0, -140 })
    local forMe = kind == "mine"
    up:SetKind(forMe and "upgrade" or "alt")
    local gain = r.gain and string.format(" +%.0f%%", r.gain * 100) or ""
    up.title:SetText(forMe and ("UPGRADE FOR YOU" .. gain) or ("UPGRADE FOR " .. string.upper(r.alt or "?") .. gain))
    up.newRow:SetItem(r.id, r.link, "|cff5fd35fnew|r")
    up.newRow.tip = nil
    if r.replaces then
        local oid = tonumber(r.replaces:match("item:(%d+)"))
        up.oldRow:SetItem(oid, r.replaces, "|cff8a8880worn now|r")
        up.oldRow:Show()
    else
        up.oldRow:Hide()
    end
    local diff = GP.StatDiff(r.link, r.replaces)
    for i, l in ipairs(up.lines) do
        local d = diff[i]
        if d then
            local delta = d[3] - d[2]
            local col = delta > 0 and "|cff5fd35f+" or (delta < 0 and "|cffff6b5b" or "|cffaaaaaa")
            l:SetText(string.format("%-14s %s  →  %s   %s%s|r", d[1], tostring(d[2]), tostring(d[3]), col, tostring(delta)))
        else
            l:SetText("")
        end
    end
    local spec = r.label or (forMe and self:CurrentSpec() or "their spec")
    local lvl = r.atLevel and string.format("  ·  usable at level %d", r.atLevel) or ""
    up.based:SetText(string.format("Slot: %s  ·  Weights: %s%s", r.slotName or "?", spec, lvl))
    if forMe then
        up.a:SetLabel("Equip"); up.a:Show(); up.a:SetPrimary(true)
        up.a:SetScript("OnClick", function() GP:Equip(r); up:Hide(); GP:ShowNextUpgrade() end)
        up.b:SetLabel("Later")
    else
        up.a:Hide()
        up.b:SetLabel("OK")
    end
    up.b:SetScript("OnClick", function() up:Hide(); GP:ShowNextUpgrade() end)
    up.c:SetScript("OnClick", function() GP:IgnoreUpgrade(r.id); up:Hide(); GP:ShowNextUpgrade() end)
    up:Show()
end
