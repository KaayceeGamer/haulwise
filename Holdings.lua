-- Haulwise: what every one of your characters owns, and where (bags, bank, equipped, mail, AH).
-- Each character is read while you play it; bank, mail and auctions are read when you open them.
local _, GP = ...

local BANK = (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or -1
local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
local NUM_BAGS = NUM_BAG_SLOTS or 4
local LOCATIONS = { "bags", "bank", "equipped", "mail", "ah" }
GP.LOCATIONS = LOCATIONS
GP.LOCATION_LABEL = { bags = "Bags", bank = "Bank", equipped = "Equipped", mail = "Mail", ah = "Auction" }

local bankOpen = false

function GP.BagIDs()
    local ids = {}
    for b = 0, NUM_BAGS do ids[#ids + 1] = b end
    if C_Container and C_Container.GetContainerNumSlots and REAGENT_BAG > NUM_BAGS then
        local ok, n = pcall(C_Container.GetContainerNumSlots, REAGENT_BAG)
        if ok and n and n > 0 then ids[#ids + 1] = REAGENT_BAG end
    end
    return ids
end

local function bankIDs()
    local ids = { BANK }
    local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAGS) + 1
    for b = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do ids[#ids + 1] = b end
    if Enum and Enum.BagIndex then
        for i = 1, 6 do
            local tab = Enum.BagIndex["CharacterBankTab_" .. i]
            if tab then ids[#ids + 1] = tab end
        end
    end
    return ids
end

local function slotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok then return info end
    end
end

local function numSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        if ok then return n or 0 end
    end
    return 0
end
GP.NumSlots = numSlots
GP.SlotInfo = slotInfo

local function countBags(ids)
    local counts = {}
    for _, bag in ipairs(ids) do
        for slot = 1, numSlots(bag) do
            local info = slotInfo(bag, slot)
            if info and info.itemID then counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1) end
        end
    end
    return counts
end

local function readBasics(c)
    local _, classFile = UnitClass("player")
    c.short = UnitName("player")
    c.realm = GetRealmName and GetRealmName() or "?"
    c.faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    c.class, c.classFile = UnitClass("player"), classFile
    c.level = UnitLevel("player")
    c.gold = GetMoney and GetMoney() or 0
    c.profs = c.profs or {}
    for name, p in pairs(GP:MyProfessions()) do c.profs[name] = p end
    if GP.CurrentSpec then c.spec = GP:CurrentSpec() end
    if GP.PawnVisibleScales then c.pawnScales = GP:PawnVisibleScales() or c.pawnScales end
    c.seen = c.seen or {}
    c.seen.login = time()
end

local function readEquipped(c)
    c.equipped = {}
    c.equippedLinks = {}
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            if id then c.equipped[id] = (c.equipped[id] or 0) + 1 end
            c.equippedLinks[slot] = link
        end
    end
    c.seen.equipped = time()
end

local function readBags(c)
    c.bags = countBags(GP.BagIDs())
    c.seen.bags = time()
    c.freeSlots = GP.FreeSlots and GP:FreeSlots() or nil
end

local function readBank(c)
    if not bankOpen then return end
    c.bank = countBags(bankIDs())
    c.seen.bank = time()
end

local function readMail(c)
    if not GetInboxNumItems then return end
    local items, gold = {}, 0
    for i = 1, GetInboxNumItems() do
        local money = select(5, GetInboxHeaderInfo(i))
        gold = gold + (money or 0)
        for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
            local _, itemID, _, count = GetInboxItem(i, a)
            if itemID then items[itemID] = (items[itemID] or 0) + (count or 1) end
        end
    end
    c.mail, c.mailGold = items, gold
    c.seen.mail = time()
end

local function readAuctions(c)
    if not (C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions) then return end
    local items = {}
    for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
        local a = C_AuctionHouse.GetOwnedAuctionInfo(i)
        if a and a.itemKey and a.itemKey.itemID and a.status ~= 1 then
            items[a.itemKey.itemID] = (items[a.itemKey.itemID] or 0) + (a.quantity or 1)
        end
    end
    c.ah = items
    c.seen.ah = time()
end

-- Debounced refresh: game events often fire in bursts.
local pending = {}
local function schedule(what)
    if pending[what] then return end
    pending[what] = true
    C_Timer.After(1, function()
        pending[what] = nil
        local c = GP:Char()
        if what == "bags" then readBags(c); readBasics(c)
        elseif what == "bank" then readBank(c)
        elseif what == "equipped" then readEquipped(c)
        elseif what == "mail" then readMail(c)
        elseif what == "ah" then readAuctions(c) end
        if GP.OnHoldingsChanged then GP:OnHoldingsChanged(what) end
    end)
end
GP.ScheduleHoldings = schedule

GP:On("PLAYER_ENTERING_WORLD", function()
    local c = GP:Char()
    readBasics(c)
    readEquipped(c)
    readBags(c)
end)
GP:On("BAG_UPDATE_DELAYED", function() schedule("bags"); if bankOpen then schedule("bank") end end)
GP:On("PLAYER_MONEY", function() GP:Char().gold = GetMoney() end)
GP:On("PLAYER_LEVEL_UP", function() schedule("bags") end)
GP:On("PLAYER_EQUIPMENT_CHANGED", function() schedule("equipped") end)
GP:On("BANKFRAME_OPENED", function() bankOpen = true; schedule("bank") end)
GP:On("BANKFRAME_CLOSED", function() bankOpen = false end)
GP:On("PLAYERBANKSLOTS_CHANGED", function() schedule("bank") end)
GP:On("MAIL_INBOX_UPDATE", function() schedule("mail") end)
GP:On("OWNED_AUCTIONS_UPDATED", function() schedule("ah") end)
GP:On("AUCTION_HOUSE_SHOW", function()
    if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then pcall(C_AuctionHouse.QueryOwnedAuctions, {}) end
end)

-- Your other characters that can trade items with this one (same realm and faction).
function GP:Alts()
    local me, out = self:CharKey(), {}
    local realm = GetRealmName and GetRealmName() or "?"
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    for key, c in pairs(self.db.chars) do
        if key ~= me and c.short and c.realm == realm and c.faction == faction then
            c.key = key
            out[#out + 1] = c
        end
    end
    table.sort(out, function(a, b) return (a.level or 0) > (b.level or 0) end)
    return out
end

function GP:ForgetCharacter(key)
    if key ~= self:CharKey() then self.db.chars[key] = nil end
end

-- Holdings rows for the window: one per item, with where it is.
function GP:HoldingsRows(charFilter, locFilter)
    local realm = GetRealmName and GetRealmName() or "?"
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    local byId = {}
    for key, c in pairs(self.db.chars) do
        if c.realm == realm and c.faction == faction and (not charFilter or charFilter == key) then
            for _, loc in ipairs(LOCATIONS) do
                if not locFilter or locFilter == loc then
                    for id, n in pairs(c[loc] or {}) do
                        local r = byId[id]
                        if not r then r = { id = id, count = 0, sellable = 0, where = {} }; byId[id] = r end
                        r.count = r.count + n
                        -- Gear you wear isn't for sale until you take it off: it has no value here.
                        if loc ~= "equipped" then r.sellable = r.sellable + n end
                        table.insert(r.where, { char = c.short or key, classFile = c.classFile, loc = loc, n = n })
                    end
                end
            end
        end
    end
    local rows, total = {}, 0
    for id, r in pairs(byId) do
        r.unit = self:ItemValue(id) or 0
        r.value = r.unit * r.sellable
        r.worn = r.sellable == 0
        total = total + r.value
        rows[#rows + 1] = r
    end
    table.sort(rows, function(a, b)
        if a.worn ~= b.worn then return not a.worn end
        if a.value ~= b.value then return a.value > b.value end
        return a.id < b.id
    end)
    return rows, total
end

function GP:HoldingsGold()
    local realm = GetRealmName and GetRealmName() or "?"
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    local gold, mail = 0, 0
    for _, c in pairs(self.db.chars) do
        if c.realm == realm and c.faction == faction then
            gold, mail = gold + (c.gold or 0), mail + (c.mailGold or 0)
        end
    end
    return gold, mail
end

-- Send to alts (at the mailbox) ------------------------------------------------------------

local sendFrame
local function attachToMail(row)
    if not (SendMailNameEditBox and ClickSendMailItemButton) then return end
    if MailFrameTab_OnClick and not (SendMailFrame and SendMailFrame:IsShown()) then pcall(MailFrameTab_OnClick, nil, 2) end
    local current = SendMailNameEditBox:GetText() or ""
    local hasItems = false
    for i = 1, (ATTACHMENTS_MAX_SEND or 12) do if HasSendMailItem and HasSendMailItem(i) then hasItems = true end end
    if hasItems and current ~= "" and current ~= row.alt then
        GP.Print("This mail already has items for " .. current .. ". Send or clear it first.")
        return
    end
    local free
    for i = 1, (ATTACHMENTS_MAX_SEND or 12) do
        if not (HasSendMailItem and HasSendMailItem(i)) then free = i; break end
    end
    if not free then GP.Print("The mail is full. Send it first."); return end
    SendMailNameEditBox:SetText(row.alt)
    C_Container.PickupContainerItem(row.bag, row.slot)
    ClickSendMailItemButton(free)
end

GP.AttachToMail = attachToMail

-- Crafting mats for your crafters: reagents in your bags that one of your alts' recipes use and
-- yours don't. Each goes to the alt with the highest skill in the profession that uses it.
function GP:MatsForCrafters()
    local mine = {}
    for _, rec in pairs(self:Char().recipes or {}) do
        if rec.learned then for _, r in ipairs(GP.UnpackReagents(rec.r)) do mine[r[1]] = true end end
    end
    local altFor = {}
    for _, c in ipairs(self:Alts()) do
        for _, rec in pairs(c.recipes or {}) do
            if rec.learned then
                local rank = (c.profs and c.profs[rec.prof] and c.profs[rec.prof].rank) or 0
                for _, r in ipairs(GP.UnpackReagents(rec.r)) do
                    local cur = altFor[r[1]]
                    if not mine[r[1]] and (not cur or rank > cur.rank) then
                        altFor[r[1]] = { alt = c.short, prof = rec.prof, rank = rank }
                    end
                end
            end
        end
    end
    local groups, byAlt = {}, {}
    for _, bag in ipairs(GP.BagIDs()) do
        for slot = 1, numSlots(bag) do
            local it = slotInfo(bag, slot)
            local who = it and it.itemID and altFor[it.itemID]
            if who and not it.isBound and not self.db.keep[it.itemID] then
                local g = byAlt[who.alt]
                if not g then
                    g = { alt = who.alt, profs = {}, items = {}, stacks = 0 }
                    byAlt[who.alt] = g
                    groups[#groups + 1] = g
                end
                g.profs[who.prof] = true
                g.items[#g.items + 1] = { bag = bag, slot = slot, id = it.itemID, count = it.stackCount or 1 }
                g.stacks = g.stacks + 1
            end
        end
    end
    table.sort(groups, function(a, b) return a.stacks > b.stacks end)
    return groups
end

-- One click: address the mail to the alt and attach as many of their mats as fit.
function GP:AttachMats(g)
    if not (SendMailNameEditBox and ClickSendMailItemButton) then return end
    if MailFrameTab_OnClick and not (SendMailFrame and SendMailFrame:IsShown()) then pcall(MailFrameTab_OnClick, nil, 2) end
    local current = SendMailNameEditBox:GetText() or ""
    local used = 0
    for i = 1, (ATTACHMENTS_MAX_SEND or 12) do if HasSendMailItem and HasSendMailItem(i) then used = used + 1 end end
    if used > 0 and current ~= "" and current ~= g.alt then
        GP.Print("This mail already has items for " .. current .. ". Send or clear it first.")
        return
    end
    SendMailNameEditBox:SetText(g.alt)
    local attached = 0
    for _, it in ipairs(g.items) do
        local free
        for i = 1, (ATTACHMENTS_MAX_SEND or 12) do
            if not (HasSendMailItem and HasSendMailItem(i)) then free = i; break end
        end
        if not free then break end
        local info = slotInfo(it.bag, it.slot)
        if info and info.itemID == it.id then
            C_Container.PickupContainerItem(it.bag, it.slot)
            ClickSendMailItemButton(free)
            attached = attached + 1
        end
    end
    local left = #g.items - attached
    GP.Print(string.format("Attached %d stack%s for %s.%s Press Send.", attached, attached == 1 and "" or "s", g.alt,
        left > 0 and string.format(" %d more after this mail.", left) or ""))
end

function GP:ShowSendToAlts()
    local list = {}
    if self.db.settings.sendToAltsAtMailbox and self.AltUpgradesInBags then
        for _, r in ipairs(self:AltUpgradesInBags()) do list[#list + 1] = r end
    end
    if self.db.settings.matsToCrafters then
        for _, g in ipairs(self:MatsForCrafters()) do list[#list + 1] = { mats = g, id = g.items[1].id } end
    end
    if #list == 0 then if sendFrame then sendFrame:Hide() end return end
    if not sendFrame then
        sendFrame = GP.Panel("HaulwiseSendToAlts", 300, 60, "Send to alts")
        sendFrame.rows = {}
    end
    local f = sendFrame
    f:ClearAllPoints()
    if MailFrame and MailFrame:IsShown() then f:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 6, 0) else f:SetPoint("CENTER") end
    for _, r in ipairs(f.rows) do r:Hide() end
    for i, item in ipairs(list) do
        local r = f.rows[i]
        if not r then
            r = GP.ItemRow(f, 276)
            r:SetPoint("TOPLEFT", 12, -34 - (i - 1) * 24)
            f.rows[i] = r
        end
        if item.mats then
            local g = item.mats
            local profs = {}
            for p in pairs(g.profs) do profs[#profs + 1] = p end
            r:SetItem(item.id, nil, string.format("|cffff9944%s|r  %d stack%s", g.alt, g.stacks, g.stacks == 1 and "" or "s"))
            r.name:SetText("Mats for " .. table.concat(profs, ", "))
            r.link = nil
            r:SetScript("OnClick", function() GP:AttachMats(g) end)
            r.tip = function(t)
                t:AddLine(string.format("Crafting mats for %s", g.alt), 1, 0.82, 0.25)
                t:AddLine("Reagents your alt's recipes use and yours don't.", 0.8, 0.8, 0.8, true)
                for i, it in ipairs(g.items) do
                    if i > 12 then t:AddLine(string.format("...and %d more", #g.items - 12), 0.6, 0.6, 0.6); break end
                    t:AddLine(string.format("|T%s:14|t %s x%d", GP.ItemIcon(it.id), GP.ItemInfo(it.id) or "?", it.count), 1, 1, 1)
                end
                t:AddLine("Click: address the mail and attach them (12 per mail).", 0.6, 0.6, 0.6, true)
            end
        else
            r:SetItem(item.id, item.link,
                string.format("|cffff9944%s|r  %s", item.alt, item.gain and string.format("+%.0f%%", item.gain * 100) or ""))
            r:SetScript("OnClick", function() attachToMail(item) end)
            r.tip = function(t)
                t:SetHyperlink(item.link)
                t:AddLine(" ")
                t:AddLine(string.format("|cffffd040Haulwise|r: upgrade for %s%s. Click to attach.", item.alt,
                    item.atLevel and (" at level " .. item.atLevel) or ""), 1, 1, 1, true)
            end
        end
        r:Show()
    end
    f:SetHeight(46 + #list * 24)
    f:Show()
end

GP:On("MAIL_SHOW", function()
    local s = GP.db.settings
    if s.sendToAltsAtMailbox or s.matsToCrafters then C_Timer.After(0.5, function() GP:ShowSendToAlts() end) end
end)
GP:On("BAG_UPDATE_DELAYED", function()
    if sendFrame and sendFrame:IsShown() then C_Timer.After(0.2, function() GP:ShowSendToAlts() end) end
end)
GP:On("MAIL_CLOSED", function() if sendFrame then sendFrame:Hide() end end)
