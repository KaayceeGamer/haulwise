-- Haulwise: bags. Values every item, knows what must never be thrown away, and when your bags are
-- full offers the cheapest item to swap for better loot (or to delete to make room).
local _, GP = ...
local L = GP.L

local TOOLS = {}
for _, id in ipairs({
    6948,                                         -- Hearthstone
    7005, 2901, 5956,                             -- Skinning Knife, Mining Pick, Blacksmith Hammer
    6218, 6339, 11130, 11145, 16207,              -- Runed enchanting rods
    5060, 6219, 10498, 9149,                      -- Thieves' Tools, Arclight Spanner, Gyromatic Micro-Adjustor, Philosopher's Stone
    6256, 6365, 6366, 6367, 12225, 19022, 19970,  -- Fishing poles
}) do TOOLS[id] = true end

-- Class spell reagents: Light Feather (Slow Fall), runes, powders, candles, seeds, shards...
local CLASS_REAGENTS = {}
for _, id in ipairs({
    17056, 17020, 17031, 17032,                   -- Light Feather, Arcane Powder, Runes of Teleportation and Portals
    17028, 17029, 17033, 17030,                   -- Holy Candle, Sacred Candle, Symbol of Divinity, Ankh
    17034, 17035, 17036, 17037, 17038, 17021, 17026, -- druid seeds, Wild Berries, Wild Thornroot
    6265, 5565, 16583,                            -- Soul Shard, Infernal Stone, Demonic Figurine
    5140, 5530, 2928, 8923, 8924, 8925,           -- Flash and Blinding Powder, poison reagents
    17057, 17058, 21177,                          -- Shiny Fish Scales, Fish Oil, Symbol of Kings
}) do CLASS_REAGENTS[id] = true end

local CLASS_QUEST, CLASS_PROJECTILE, CLASS_QUIVER, CLASS_CONTAINER = 12, 6, 11, 1
-- Crafting materials are never offered, whatever they're worth: gems (3), reagents (5),
-- trade goods (7: dust, essences, shards, cloth, leather, ore, herbs...) and recipes (9).
local CRAFTING = { [3] = L["gem"], [5] = L["reagent"], [7] = L["crafting material"], [9] = L["recipe"] }

local function family(bag)
    if not (C_Container and C_Container.GetContainerNumFreeSlots) then return 0, 0 end
    local ok, free, fam = pcall(C_Container.GetContainerNumFreeSlots, bag)
    if not ok then return 0, 0 end
    return free or 0, fam or 0
end

local function isGeneral(bag)
    local reagentBag = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    if bag == reagentBag and bag > (NUM_BAG_SLOTS or 4) then return false end
    local _, fam = family(bag)
    return fam == 0
end

function GP:FreeSlots()
    local free = 0
    for _, bag in ipairs(GP.BagIDs()) do
        if isGeneral(bag) then free = free + (family(bag)) end
    end
    return free
end

function GP:TotalSlots()
    local n = 0
    for _, bag in ipairs(GP.BagIDs()) do if isGeneral(bag) then n = n + GP.NumSlots(bag) end end
    return n
end

-- Reagents for your professions (learned and not-yet-learned recipes you've seen).
local reagentSet, reagentStamp
function GP:IsKeptReagent(id)
    local c = self:Char()
    local stamp = 0
    for _ in pairs(c.recipes) do stamp = stamp + 1 end
    if not reagentSet or reagentStamp ~= stamp then
        reagentSet, reagentStamp = {}, stamp
        for _, rec in pairs(c.recipes) do
            for _, r in ipairs(GP.UnpackReagents(rec.r)) do reagentSet[r[1]] = rec.prof or true end
        end
    end
    return reagentSet[id]
end

local function isQuest(bag, slot, info)
    if info and info.classID == CLASS_QUEST then return true end
    if C_Container and C_Container.GetContainerItemQuestInfo then
        local ok, q = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
        if ok and q and (q.isQuestItem or q.questID) then return true end
    end
    return false
end

-- Why an item must never be offered for deletion (nil = it may be).
function GP:ProtectReason(bag, slot, it, info)
    local s = self.db.settings
    if self.db.keep[it.itemID] then return "kept" end
    if TOOLS[it.itemID] then return "tool" end
    if info.classID == CLASS_PROJECTILE or info.classID == CLASS_QUIVER then return "ammo" end
    if info.classID == CLASS_CONTAINER then return "bag" end
    if isQuest(bag, slot, info) then return "quest" end
    if CRAFTING[info.classID or -1] then return CRAFTING[info.classID] end
    if CLASS_REAGENTS[it.itemID] or (info.classID == 15 and info.subclassID == 1) then return L["class reagent"] end
    if GP.DE_MATS and GP.DE_MATS[it.itemID] then return L["crafting material"] end
    if not isGeneral(bag) then return L["special bag"] end
    if (it.quality or info.quality or 0) >= 4 then return "epic" end
    if s.protectReagents and self:IsKeptReagent(it.itemID) then return "reagent" end
    local up = self.IsUpgradeItem and self:IsUpgradeItem(it.itemID)
    if up then return L["upgrade for "] .. up end
    return nil
end

-- Every item in your bags, valued. Returns list of rows, and totals.
function GP:BagItems()
    local rows, vendorTotal, bestTotal = {}, 0, 0
    for _, bag in ipairs(GP.BagIDs()) do
        for slot = 1, GP.NumSlots(bag) do
            local it = GP.SlotInfo(bag, slot)
            if it and it.itemID then
                local info = GP.LinkInfo(it.hyperlink or it.itemID)
                local count = it.stackCount or 1
                local unit, src, d = self:BagValue(it.itemID, it.hyperlink, it.isBound)
                local row = {
                    bag = bag, slot = slot, id = it.itemID, link = it.hyperlink, count = count, quality = it.quality or info.quality,
                    unit = unit, total = unit * count, src = src, d = d, bound = it.isBound, info = info,
                }
                row.protect = self:ProtectReason(bag, slot, it, info)
                if row.total <= 0 and not row.protect then row.protect = it.hasNoValue and L["no value"] or nil end
                vendorTotal = vendorTotal + (d.vendor or 0) * count
                bestTotal = bestTotal + row.total
                rows[#rows + 1] = row
            end
        end
    end
    return rows, vendorTotal, bestTotal
end

-- "Disenchant for mats" (Bags tab): gear you can disenchant yourself is disenchanted even when
-- selling pays more, because you want the dust and essences to level Enchanting.
function GP.CanDisenchantMyself(d)
    if not (d and d.deOutcomes and d.deWho) then return false end
    for _, n in ipairs(d.deWho) do if n == UnitName("player") then return true end end
    return false
end

-- Not when selling pays more than 3 times what the mats are worth: that's gold thrown away
-- (an 88s ring for 13s of dust). Gear whose mats have no price yet still counts.
local MATS_MAX_RATIO = 3
function GP:MatsDisenchant(r)
    if not self.db.settings.deForMats or r.protect or r.src == "DE" then return false end
    if not GP.CanDisenchantMyself(r.d) then return false end
    local de = r.d.de
    if de and de > 0 and (r.unit or 0) > de * MATS_MAX_RATIO then return false end
    return true
end

-- What to do with an item that isn't protected: the move that gets the most for it.
function GP:BagAdvice(r)
    if self:MatsDisenchant(r) then
        local loss = r.total - (r.d.de or 0) * (r.count or 1)
        local text = L["|cffc48cffdisenchant for mats|r"]
        if r.d.de and loss > 0 then text = text .. "|cff8a8880" .. string.format(L[" (%s less than selling)"], GP.Coins(loss, true)) .. "|r" end
        return text
    end
    if r.src == "DE" then
        local who = r.d and r.d.deWho or {}
        for _, n in ipairs(who) do if n == UnitName("player") then return L["|cffc48cffdisenchant|r"] end end
        return L["|cffc48cffsend to "] .. (who[1] or L["an enchanter"]) .. L[" to disenchant|r"]
    elseif r.src == "AH" then
        return L["|cffffd040sell on the AH|r"]
    end
    return L["|cffaaaaaasell to a vendor|r"]
end

-- Items that may go, cheapest first.
function GP:DeleteCandidates()
    local items = self:BagItems()
    local out = {}
    for _, r in ipairs(items) do if not r.protect then out[#out + 1] = r end end
    table.sort(out, function(a, b)
        if a.total ~= b.total then return a.total < b.total end
        return (a.quality or 0) < (b.quality or 0)
    end)
    return out
end

-- Delete one bag item (from a click). Re-checks that the slot still holds the same thing.
function GP:DeleteBagItem(row)
    local it = GP.SlotInfo(row.bag, row.slot)
    if not it or it.hyperlink ~= row.link then GP.Print(L["That item moved. Try again."]); return false end
    if CursorHasItem and CursorHasItem() then ClearCursor() end
    C_Container.PickupContainerItem(row.bag, row.slot)
    if DeleteCursorItem then DeleteCursorItem() end
    if CursorHasItem and CursorHasItem() then
        -- The game wants you to confirm this one yourself: the item stays on your cursor.
        GP.Print(L["Confirm the delete in the game's dialog, or right-click to put it back."])
        return false
    end
    return true
end

-- Selling junk at a vendor ------------------------------------------------------------------------

GP.atMerchant = false
function GP:JunkValue()
    local total, n = 0, 0
    for _, r in ipairs(self:BagItems()) do
        if r.quality == 0 and not r.protect and (r.d.vendor or 0) > 0 then total, n = total + r.d.vendor * r.count, n + 1 end
    end
    return total, n
end

function GP:SellJunk()
    if not self.atMerchant then return end
    local sold, money = 0, 0
    for _, r in ipairs(self:BagItems()) do
        if r.quality == 0 and not r.protect and (r.d.vendor or 0) > 0 and sold < 12 then
            C_Container.UseContainerItem(r.bag, r.slot)
            sold, money = sold + 1, money + r.d.vendor * r.count
        end
    end
    if sold > 0 then GP.Print(string.format(L["Sold %d grey items for %s."], sold, GP.Coins(money))) end
end
GP:On("MERCHANT_SHOW", function() GP.atMerchant = true; if GP.RefreshHUD then GP:RefreshHUD() end end)
GP:On("MERCHANT_CLOSED", function() GP.atMerchant = false; if GP.RefreshHUD then GP:RefreshHUD() end end)

-- Full bags while looting: offer a swap ------------------------------------------------------------

local function fitsOnStack(id, info)
    if (info.maxStack or 1) <= 1 then return false end
    for _, bag in ipairs(GP.BagIDs()) do
        for slot = 1, GP.NumSlots(bag) do
            local it = GP.SlotInfo(bag, slot)
            if it and it.itemID == id and (it.stackCount or 1) < info.maxStack then return true end
        end
    end
    return false
end

-- The best thing in this loot window that won't fit, with why it matters.
function GP:LootNeedingRoom()
    local best
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then
            local _, _, qty, _, _, locked, isQuestItem = GetLootSlotInfo(slot)
            local info = GP.LinkInfo(link)
            if not locked and not fitsOnStack(id, info) then
                local unit, src, d = self:BagValue(id, link, info.bindType == 1)
                local r = { lootSlot = slot, id = id, link = link, count = qty or 1, unit = unit, total = unit * (qty or 1), src = src, d = d,
                            quality = info.quality, prio = 0 }
                if isQuestItem then r.kind, r.prio = "quest", 4
                else
                    local mineUp = self.CompareGear and self.MeForGear and self:CompareGear(link, self.MeForGear())
                    if mineUp then r.kind, r.prio, r.gain = "upgrade", 3, mineUp.gain
                    elseif self.db.settings.protectReagents and self:IsKeptReagent(id) then r.kind, r.prio = "reagent", 1 end
                end
                if not best or r.prio > best.prio or (r.prio == best.prio and r.total > best.total) then best = r end
            end
        end
    end
    return best
end

local lastAuto = 0
local lootOpen = false
GP:On("LOOT_READY", function() lootOpen = true end)
GP:On("LOOT_OPENED", function()
    lootOpen = true
    if not GP.db.settings.swapPopups then return end
    C_Timer.After(0.05, function()
        if GP:FreeSlots() > 0 then return end
        local loot = GP:LootNeedingRoom()
        if loot and GP.ShowSwapPopup then GP:ShowSwapPopup(loot) end
    end)
end)
GP:On("LOOT_CLOSED", function()
    lootOpen = false
    if GP.HideSwapPopup then GP:HideSwapPopup() end
end)

-- "Inventory is full" outside a loot window (crafting, quest rewards, buying, mail...)
GP:On("UI_ERROR_MESSAGE", function(_, msg)
    msg = GP.Safe(msg)
    if not msg or not GP.db.settings.makeRoomPopup then return end
    if msg ~= ERR_INV_FULL and msg ~= ERR_BAG_FULL then return end
    -- With auto loot the error comes before the loot window opens, so wait a moment: if it's a
    -- loot window after all, the swap card handles it and Make room stays away.
    if lootOpen or (LootFrame and LootFrame:IsShown()) then return end
    if GetTime() - lastAuto < 10 then return end
    lastAuto = GetTime()
    C_Timer.After(0.4, function()
        if lootOpen or (LootFrame and LootFrame:IsShown()) or (GP.SwapPopupShown and GP:SwapPopupShown()) then return end
        if GP.ShowMakeRoom then GP:ShowMakeRoom(true) end
    end)
end)

-- Totals for the HUD and Bags tab: what you'd have if you sold everything.
function GP:Totals()
    local items, vendor, best = self:BagItems()
    local t = { gold = GetMoney and GetMoney() or 0, vendor = vendor, best = best, bySrc = { V = 0, AH = 0, DE = 0 }, top = {} }
    for _, r in ipairs(items) do
        t.bySrc[r.src] = (t.bySrc[r.src] or 0) + r.total
        t.top[#t.top + 1] = r
    end
    table.sort(t.top, function(a, b) return a.total > b.total end)
    for i = #t.top, 11, -1 do t.top[i] = nil end
    local c = self:Char()
    t.bank, t.bankSeen = 0, c.seen and c.seen.bank
    for id, n in pairs(c.bank or {}) do t.bank = t.bank + (self:ItemValue(id) or 0) * n end
    t.mailGold = c.mailGold or 0
    t.guaranteed = t.gold + t.vendor
    t.total = t.gold + t.best + t.bank + t.mailGold
    if self.HoldingsRows then
        local _, allItems = self:HoldingsRows()
        local allGold, allMail = self:HoldingsGold()
        t.account = allGold + allMail + allItems
    end
    return t
end

function GP:AddTotalsTooltip(tt)
    local t = self:Totals()
    local C = GP.Coins
    tt:AddLine(L["|cffffd040Haulwise|r: what you're worth"])
    tt:AddDoubleLine(L["Gold"], C(t.gold), 0.8, 0.8, 0.8, 1, 1, 1)
    tt:AddDoubleLine(L["Bags at vendor (guaranteed)"], C(t.vendor), 0.8, 0.8, 0.8, 1, 1, 1)
    tt:AddDoubleLine(L["Bags at best value"], C(t.best), 0.8, 0.8, 0.8, 1, 1, 1)
    tt:AddDoubleLine(L["    from auction house"], C(t.bySrc.AH or 0), 0.6, 0.6, 0.6, 0.7, 0.7, 0.7)
    if (t.bySrc.DE or 0) > 0 then tt:AddDoubleLine(L["    from disenchanting"], C(t.bySrc.DE), 0.6, 0.6, 0.6, 0.7, 0.7, 0.7) end
    tt:AddDoubleLine(L["    from vendor"], C(t.bySrc.V or 0), 0.6, 0.6, 0.6, 0.7, 0.7, 0.7)
    tt:AddDoubleLine(L["    gain over vendor"], "|cff5fd35f+" .. C(t.best - t.vendor) .. "|r", 0.6, 0.6, 0.6)
    if t.bankSeen then
        tt:AddDoubleLine(L["Bank"], C(t.bank), 0.8, 0.8, 0.8, 1, 1, 1)
    else
        tt:AddDoubleLine(L["Bank"], L["|cff999999open your bank once|r"], 0.8, 0.8, 0.8)
    end
    if t.mailGold > 0 then tt:AddDoubleLine(L["Gold in mail"], C(t.mailGold), 0.8, 0.8, 0.8, 1, 1, 1) end
    tt:AddLine(" ")
    tt:AddDoubleLine(L["Total (this character)"], C(t.total), 1, 0.82, 0.25, 1, 0.82, 0.25)
    tt:AddDoubleLine(L["Guaranteed (gold + vendor)"], C(t.guaranteed), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
    if t.account and t.account > t.total then tt:AddDoubleLine(L["All your characters"], C(t.account), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8) end
    if #t.top > 0 then
        tt:AddLine(" ")
        tt:AddLine(L["Most valuable in your bags"], 1, 0.82, 0.25)
        for _, r in ipairs(t.top) do
            local name, quality = GP.ItemInfo(r.id)
            local col = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
            tt:AddDoubleLine(string.format("  |T%s:14|t %s%s|r%s", GP.ItemIcon(r.id), col and col.hex or "", name or "?",
                r.count > 1 and (" x" .. r.count) or ""), C(r.total, true) .. " " .. GP.SourceTag(r.src, r.d))
        end
    end
    return t
end
