-- Haulwise: popups. Swap (bags full while looting), Make room, and Upgrade found.
local _, GP = ...

local KIND_TITLE = {
    quest = "QUEST ITEM: make room", upgrade = "GEAR UPGRADE: make room", reagent = "REAGENT YOU USE: make room",
    plain = "BAGS FULL: swap?", bad = "NOT WORTH A SWAP",
}

-- Swap ------------------------------------------------------------------------------------------

local swap
local function buildSwap()
    swap = GP.Panel("HaulwiseSwap", 360, 168, "")
    swap.lootLabel = swap:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    swap.lootLabel:SetPoint("TOPLEFT", 12, -36)
    swap.lootLabel:SetText("LOOT")
    swap.loot = GP.ItemRow(swap, 336)
    swap.loot:SetPoint("TOPLEFT", 12, -48)
    swap.bagLabel = swap:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    swap.bagLabel:SetPoint("TOPLEFT", 12, -76)
    swap.bagLabel:SetText("DELETE FROM BAGS")
    swap.bag = GP.ItemRow(swap, 336)
    swap.bag:SetPoint("TOPLEFT", 12, -88)
    swap.verdict = swap:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    swap.verdict:SetPoint("TOPLEFT", 12, -116)
    swap.verdict:SetPoint("RIGHT", -12, 0)
    swap.verdict:SetJustifyH("LEFT")
    swap.go = GP.FlatButton(swap, "Swap", 110, 24)
    swap.go:SetPoint("BOTTOMLEFT", 12, 10)
    swap.next = GP.FlatButton(swap, "Next", 80, 24)
    swap.next:SetPoint("LEFT", swap.go, "RIGHT", 6, 0)
    swap.cancel = GP.FlatButton(swap, "Cancel", 80, 24)
    swap.cancel:SetPoint("LEFT", swap.next, "RIGHT", 6, 0)
    swap.cancel:SetScript("OnClick", function() swap:Hide() end)
end

local function drawSwap()
    local s = swap.state
    local loot, cands = s.loot, s.cands
    local bagItem = cands[s.i]
    swap.loot:SetItem(loot.id, loot.link, GP.ValueText(loot.total, loot.src, loot.d), loot.count)
    swap.loot.tip = function(t) t:SetHyperlink(loot.link); GP.AddValueLines(t, loot.unit, loot.src, loot.d, loot.count) end
    local important = loot.prio and loot.prio > 0
    if not bagItem then
        swap:SetKind("bad")
        swap.title:SetText("NOTHING TO SWAP")
        swap.bag:Hide()
        swap.verdict:SetText("Everything in your bags is protected (quest items, tools, reagents, upgrades or kept items).")
        swap.go:Hide(); swap.next:Hide()
        return
    end
    swap.bag:Show(); swap.go:Show(); swap.next:Show()
    swap.bag:SetItem(bagItem.id, bagItem.link, GP.ValueText(bagItem.total, bagItem.src, bagItem.d), bagItem.count)
    swap.bag.tip = function(t) t:SetHyperlink(bagItem.link); GP.AddValueLines(t, bagItem.unit, bagItem.src, bagItem.d, bagItem.count) end
    local diff = loot.total - bagItem.total
    local worth = important or diff > 0
    local kind = worth and (loot.kind or "plain") or "bad"
    swap:SetKind(kind)
    local title = KIND_TITLE[kind]
    if kind == "upgrade" and loot.gain then title = string.format("GEAR UPGRADE +%.0f%%: make room", loot.gain * 100) end
    swap.title:SetText(title)
    if diff >= 0 then
        swap.verdict:SetText(string.format("You gain |cff5fd35f%s|r.  %s", GP.Coins(diff),
            "|cff8a8880" .. s.i .. " of " .. #cands .. " items you could delete|r"))
    else
        swap.verdict:SetText(string.format("You'd lose |cffff6b5b%s|r%s.  |cff8a8880%d of %d|r", GP.Coins(-diff),
            important and " (but you need this)" or "", s.i, #cands))
    end
    swap.go:SetLabel(worth and "Swap" or "Swap anyway")
    swap.go:SetPrimary(worth)
end

function GP:ShowSwapPopup(loot)
    if not swap then buildSwap() end
    swap:RestorePosition({ "TOP", UIParent, "TOP", 0, -140 })
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
    swap:Show()
end

function GP:HideSwapPopup() if swap then swap:Hide() end end

-- Make room ---------------------------------------------------------------------------------------

local room
local function buildRoom()
    room = GP.Panel("HaulwiseMakeRoom", 340, 132, "MAKE ROOM")
    room:SetKind("room")
    room.free = room:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    room.free:SetPoint("TOPRIGHT", -30, -9)
    room.item = GP.ItemRow(room, 316)
    room.item:SetPoint("TOPLEFT", 12, -40)
    room.note = room:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    room.note:SetPoint("TOPLEFT", 12, -68)
    room.note:SetPoint("RIGHT", -12, 0)
    room.note:SetJustifyH("LEFT")
    room.del = GP.FlatButton(room, "Delete", 100, 24)
    room.del:SetPoint("BOTTOMLEFT", 12, 10)
    room.next = GP.FlatButton(room, "Next", 80, 24)
    room.next:SetPoint("LEFT", room.del, "RIGHT", 6, 0)
    room.done = GP.FlatButton(room, "Close", 80, 24)
    room.done:SetPoint("LEFT", room.next, "RIGHT", 6, 0)
    room.done:SetScript("OnClick", function() room:Hide() end)
end

local function drawRoom()
    local s = room.state
    local free = GP:FreeSlots()
    room.free:SetText(string.format("%s%d free|r", free == 0 and "|cffff6b5b" or "|cff5fd35f", free))
    local it = s.cands[s.i]
    if not it then
        room.item:Hide(); room.del:Hide(); room.next:Hide()
        room.note:SetText("Nothing left that's safe to delete.")
        return
    end
    room.item:Show(); room.del:Show(); room.next:Show()
    room.item:SetItem(it.id, it.link, GP.ValueText(it.total, it.src, it.d), it.count)
    room.item.tip = function(t) t:SetHyperlink(it.link); GP.AddValueLines(t, it.unit, it.src, it.d, it.count) end
    room.note:SetText(string.format("Cheapest first: %d of %d. Quest items, tools, reagents, upgrades and kept items are never offered.", s.i, #s.cands))
    room.del:SetPrimary(true)
end

function GP:ShowMakeRoom()
    if not room then buildRoom() end
    room:RestorePosition({ "TOP", UIParent, "TOP", 0, -140 })
    room.state = { cands = self:DeleteCandidates(), i = 1 }
    room.next:SetScript("OnClick", function()
        local s = room.state
        if #s.cands > 0 then s.i = s.i % #s.cands + 1 end
        drawRoom()
    end)
    room.del:SetScript("OnClick", function()
        local it = room.state.cands[room.state.i]
        if it and GP:DeleteBagItem(it) then
            C_Timer.After(0.4, function()
                room.state = { cands = GP:DeleteCandidates(), i = 1 }
                drawRoom()
            end)
        end
    end)
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
