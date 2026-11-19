-- Haulwise: craft queue. The shopping list is the queue: the crafts you picked on the Craft tab,
-- and how many. When you open a profession, a panel beside it lists the queued crafts for that
-- profession and how many you can make right now. Click one and Haulwise picks that recipe and
-- the count in the profession window; you press Create. Each finished craft comes off the queue.
-- Addons can't press Create for you in Forever, so that click stays yours.
local _, GP = ...
local L = GP.L

local W = 280
local MAX_ROWS = 10
local panel, rows = nil, {}

local function list() local c = GP:Char(); c.shopping = c.shopping or {}; return c.shopping end

local function countHere(id)
    local get = (C_Item and C_Item.GetItemCount) or GetItemCount
    local ok, n = pcall(get, id, true)
    return ok and (GP.Safe(n) or 0) or 0
end

-- How many of a recipe your bags and bank have the reagents for.
function GP:CanMake(rec)
    local most
    for _, r in ipairs(GP.UnpackReagents(rec.r)) do
        local n = math.floor(countHere(r[1]) / math.max(1, r[2]))
        if not most or n < most then most = n end
    end
    return most or 0
end

-- The profession window that's open, and its profession (the English name Haulwise stores).
local function openProfession()
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and ProfessionsFrame and ProfessionsFrame:IsShown() then
        local ok, base = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        if ok and base then return ProfessionsFrame, GP.ProfKey(base.professionName, base.parentProfessionID or base.professionID) end
    end
    if TradeSkillFrame and TradeSkillFrame:IsShown() and GetTradeSkillLine then
        local prof = GetTradeSkillLine()
        if prof and prof ~= "UNKNOWN" then return TradeSkillFrame, GP.ProfKey(prof) end
    end
end

-- Queued crafts for one profession (or all): { key, rec, qty, can }.
function GP:QueuedCrafts(prof)
    local out = {}
    for key, qty in pairs(list()) do
        local rec = self:Char().recipes[key]
        if rec and (not prof or rec.prof == prof) then
            out[#out + 1] = { key = key, rec = rec, qty = qty, can = self:CanMake(rec) }
        end
    end
    table.sort(out, function(a, b)
        if (a.can > 0) ~= (b.can > 0) then return a.can > 0 end
        return (a.rec.n or "") < (b.rec.n or "")
    end)
    return out
end

-- Pick the recipe and the count in the game's profession window.
function GP:SelectCraft(key, n)
    local rec = self:Char().recipes[key]
    if not rec then return false end
    local done = false
    local rid = tonumber(key:match("^r(%d+)$"))
    if rid and C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        done = pcall(C_TradeSkillUI.OpenRecipe, rid)
        pcall(function()
            local box = ProfessionsFrame.CraftingPage.CreateMultipleInputBox
            if box and box.SetValue then box:SetValue(n) end
        end)
    elseif GetNumTradeSkills and SelectTradeSkill then
        for i = 1, GetNumTradeSkills() do
            local name, kind = GetTradeSkillInfo(i)
            if name == rec.n and kind ~= "header" then
                SelectTradeSkill(i)
                if TradeSkillFrame_SetSelection then pcall(TradeSkillFrame_SetSelection, i) end
                if TradeSkillInputBox and TradeSkillInputBox.SetNumber then pcall(TradeSkillInputBox.SetNumber, TradeSkillInputBox, n) end
                if TradeSkillFrame_Update then pcall(TradeSkillFrame_Update) end
                done = true
                break
            end
        end
    end
    if done then
        GP.Print(string.format(L["%s is ready: press Create (%d)."], rec.n or "?", n))
    else
        GP.Print(string.format(L["Find %s in the profession window and make %d."], rec.n or "?", n))
    end
    return done
end

-- One craft finished: take it off the queue. Modern recipes are keyed by their spell ID;
-- classic ones by name.
function GP:CraftDone(spellID, spellName)
    local l = list()
    local key = spellID and ("r" .. spellID)
    if not (key and l[key]) then
        key = nil
        for k in pairs(l) do
            local rec = self:Char().recipes[k]
            if rec and spellName and rec.n == spellName then key = k; break end
        end
    end
    if not key then return false end
    l[key] = l[key] - 1
    if l[key] <= 0 then
        l[key] = nil
        local rec = self:Char().recipes[key]
        GP.Print(string.format(L["Done: %s is off your queue."], rec and rec.n or "?"))
    end
    return true
end

-- Fill the queue with your best crafts: profit after reagents, at most what sells in about 2
-- days (once the scans know how fast it sells), never something nobody has been buying.
function GP:QueueBest(n)
    local added = 0
    for _, r in ipairs(self:CraftRows()) do
        if added >= (n or 5) then break end
        if #r.missing == 0 and r.profit > 0 then
            local per, days, label = self:SellSpeed(r.out)
            if label ~= "none" then
                local qty = 1
                if per and (days or 0) >= 1 then qty = math.max(1, math.min(10, math.floor(per * 2 / math.max(1, r.outQty)))) end
                local l = list()
                l[r.key] = math.max(l[r.key] or 0, qty)
                added = added + 1
            end
        end
    end
    if added == 0 then
        GP.Print(L["Nothing profitable to queue right now: scan the AH so Haulwise knows the prices."])
    else
        GP.Print(string.format(L["Queued your %s. Open the profession to make them."], GP.Plural(added, "best craft", "best crafts")))
        if self.ShowShopping then self:ShowShopping() end
    end
    return added
end

local function build(parent)
    panel = CreateFrame("Frame", "HaulwiseCraftQueue", parent or UIParent, "BackdropTemplate")
    panel:SetSize(W, 60)
    panel:SetBackdrop(GP.FLAT)
    panel:SetBackdropColor(0.055, 0.058, 0.07, 0.96)
    panel:SetBackdropBorderColor(0.5, 0.4, 0.18, 1)
    local accent = GP.Tex(panel, "ARTWORK", GP.GOLD[1], GP.GOLD[2], GP.GOLD[3])
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
    panel.title:SetPoint("TOPLEFT", 10, -8)
    panel.title:SetText(L["Haulwise craft queue"])
    panel.note = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    panel.note:SetPoint("BOTTOMLEFT", 10, 8)
    panel.note:SetPoint("RIGHT", -10, 0)
    panel.note:SetJustifyH("LEFT")
    panel:Hide()
end

function GP:UpdateCraftQueue()
    local frame, prof = openProfession()
    if not frame then if panel then panel:Hide() end return end
    local queued = self:QueuedCrafts(prof)
    if #queued == 0 then if panel then panel:Hide() end return end
    if not panel then build(frame) end
    panel:SetParent(frame)
    for _, r in ipairs(rows) do r:Hide() end
    local y = -28
    for i, q in ipairs(queued) do
        if i > MAX_ROWS then break end
        local row = rows[i]
        if not row then row = GP.ItemRow(panel, W - 20); rows[i] = row end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 10, y)
        local right = q.can > 0 and string.format(L["|cff5fd35fcan make %d|r"], math.min(q.can, q.qty)) or L["|cffff9944need mats|r"]
        row:SetItem(q.rec.out, nil, right, q.qty)
        row.tip = function(t)
            t:SetItemByID(q.rec.out)
            t:AddLine(" ")
            t:AddDoubleLine(L["|cffffd040Haulwise|r  queued"], tostring(q.qty))
            t:AddDoubleLine(L["You have mats for"], tostring(q.can))
            t:AddLine(q.can > 0 and L["Click: pick it in the profession window, then press Create."]
                or L["The shopping list shows what to buy."], 0.6, 0.6, 0.6, true)
        end
        row:SetScript("OnClick", function()
            if q.can > 0 then GP:SelectCraft(q.key, math.min(q.can, q.qty)) elseif GP.ShowShopping then GP:ShowShopping() end
        end)
        row:Show()
        y = y - 22
    end
    panel.note:SetText(#queued > MAX_ROWS and string.format(L["and %d more in the shopping list"], #queued - MAX_ROWS)
        or L["Click a craft to pick it. Finished crafts come off the queue."])
    panel:SetHeight(-y + 30)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, -40)
    panel:Show()
end

local pending
local function refresh()
    if pending then return end
    pending = true
    C_Timer.After(0.4, function() pending = nil; GP:UpdateCraftQueue() end)
end
GP.RefreshCraftQueue = refresh

for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "BAG_UPDATE_DELAYED" }) do GP:On(ev, refresh) end
GP:On("TRADE_SKILL_CLOSE", function() if panel then panel:Hide() end end)
GP:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" then return end
    spellID = GP.Safe(spellID)
    if not spellID or not next(list()) then return end
    local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfo and GetSpellInfo(spellID))
    if GP:CraftDone(spellID, name) then
        refresh()
        if GP.RefreshShopping then GP:RefreshShopping() end
    end
end)
