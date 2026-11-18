-- Haulwise: which quest reward to pick. When a quest offers a choice, Haulwise marks one:
-- the biggest gear upgrade for you (Pawn or Haulwise weights, like the Upgrade Advisor), and when
-- none of them is an upgrade, the one worth the most (vendor, auction house or disenchanting).
-- A profession tool you need and don't have (a Mining Pick when you mine) comes first.
local _, GP = ...
local L = GP.L

-- Tools a profession can't work without, and the items that count as having one.
local TOOLS = {
    [2901] = { prof = "Mining", any = { 2901, 9465, 20723 } },        -- Mining Pick (Digmaster 5000, Brann's Trusty Pick)
    [7005] = { prof = "Skinning", any = { 7005, 12709, 19901 } },     -- Skinning Knife (Finkle's Skinner, Zulian Slicer)
    [5956] = { prof = "Blacksmithing", any = { 5956 } },             -- Blacksmith Hammer
    [6219] = { prof = "Engineering", any = { 6219 } },               -- Arclight Spanner
}

local function owned(id)
    local get = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not get then return false end
    local ok, n = pcall(get, id, true)
    return ok and (GP.Safe(n) or 0) > 0
end

-- The profession this reward is a missing tool for, or nil.
local function missingTool(id, profs)
    local t = TOOLS[id]
    if not t or not profs[t.prof] then return nil end
    for _, have in ipairs(t.any) do if owned(have) then return nil end end
    return t.prof
end

-- Returns pick = { index, link, kind = "upgrade"|"value", gain, slotName, value, src }, or nil.
function GP:QuestRewardPick()
    local n = GetNumQuestChoices and GetNumQuestChoices() or 0
    if n < 2 then return nil end
    local who = GP.MeForGear and GP.MeForGear()
    local profs = GP.MyProfessions and GP:MyProfessions() or {}
    local tool, bestUp, bestVal
    for i = 1, n do
        local link = GetQuestItemLink and GetQuestItemLink("choice", i)
        if not link then return nil, true end -- not loaded yet: try again in a moment
        local info = GP.LinkInfo(link)
        if not info.name then return nil, true end
        local _, _, count = GetQuestItemInfo("choice", i)
        count = GP.Safe(count) or 1
        local up = who and self.db.settings.upgradeAdvisor and GP:CompareGear(link, who)
        if up and not up.atLevel and (not bestUp or up.gain > bestUp.gain) then
            bestUp = { index = i, link = link, kind = "upgrade", gain = up.gain, slotName = up.slotName }
        end
        local id = tonumber(link:match("item:(%d+)"))
        local prof = not tool and missingTool(id, profs)
        if prof then tool = { index = i, link = link, kind = "tool", prof = prof } end
        local unit, src = self:BagValue(id, link, info.bindType == 1)
        local value = (unit or 0) * count
        if not bestVal or value > bestVal.value then
            bestVal = { index = i, link = link, kind = "value", value = value, src = src }
        end
    end
    return tool or bestUp or bestVal
end

local function rewardButton(i)
    local f = QuestInfoRewardsFrame
    if f and f.RewardButtons and f.RewardButtons[i] then return f.RewardButtons[i] end
    return _G["QuestInfoRewardsFrameQuestInfoItem" .. i] or _G["QuestInfoItem" .. i]
end

local mark
local function hideMark() if mark then mark:Hide() end end

local function why(p)
    if p.kind == "tool" then
        return string.format(L["you need it for %s and don't have one"], L[p.prof])
    end
    if p.kind == "upgrade" then
        return string.format(L["upgrade +%.0f%% (%s)"], p.gain * 100, p.slotName or "?")
    end
    local how = p.src == "DE" and L["disenchant"] or p.src == "AH" and L["auction house"] or L["vendor"]
    return string.format(L["worth most: %s (%s)"], GP.Coins(p.value, true), how)
end

local lastNoted
local function show(tries)
    hideMark()
    if not GP.db or not GP.db.settings.questPick then return end
    local p, retry = GP:QuestRewardPick()
    if retry and (tries or 0) < 5 then
        C_Timer.After(0.3, function() show((tries or 0) + 1) end)
        return
    end
    if not p then return end
    local b = rewardButton(p.index)
    if b and b.IsShown and b:IsShown() then
        if not mark then
            -- A thick gold frame, a soft gold wash over the whole reward, a green tick on the
            -- icon and a slow pulse: it should be the first thing you see in the window.
            mark = CreateFrame("Frame", "HaulwiseQuestPick", UIParent, "BackdropTemplate")
            mark:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 3 })
            mark:SetBackdropBorderColor(1, 0.85, 0.1, 1)
            mark:EnableMouse(false)
            mark.wash = mark:CreateTexture(nil, "ARTWORK")
            mark.wash:SetTexture("Interface\\Buttons\\WHITE8x8")
            mark.wash:SetPoint("TOPLEFT", 3, -3)
            mark.wash:SetPoint("BOTTOMRIGHT", -3, 3)
            mark.wash:SetVertexColor(1, 0.82, 0, 0.22)
            if mark.wash.SetBlendMode then mark.wash:SetBlendMode("ADD") end
            mark.tick = mark:CreateTexture(nil, "OVERLAY")
            mark.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            mark.tick:SetSize(22, 22)
            mark.tick:SetPoint("CENTER", mark, "TOPLEFT", 4, -4)
            mark.label = mark:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
            mark.label:SetJustifyH("LEFT")
            if mark.label.SetWordWrap then mark.label:SetWordWrap(false) end
            local pulse = mark.CreateAnimationGroup and mark:CreateAnimationGroup()
            if pulse then
                local a = pulse:CreateAnimation("Alpha")
                a:SetFromAlpha(1)
                a:SetToAlpha(0.55)
                a:SetDuration(0.7)
                pulse:SetLooping("BOUNCE")
                mark.pulse = pulse
            end
        end
        mark:SetParent(b)
        mark:SetFrameLevel(b:GetFrameLevel() + 5)
        mark:ClearAllPoints()
        mark:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
        mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
        -- The label goes after "Choose your reward:", where there is always room, so it never
        -- covers the game's text. Without that line it sits above the reward as before.
        mark.label:ClearAllPoints()
        local info = GP.LinkInfo(p.link)
        mark.label:SetText(string.format(L["Haulwise pick: %s"], info.name or "?"))
        local choose = QuestInfoRewardsFrame and QuestInfoRewardsFrame.ItemChooseText
        if choose and choose.IsShown and choose:IsShown() and choose.GetStringWidth then
            local w = GP.Safe((choose.GetUnboundedStringWidth and choose:GetUnboundedStringWidth()) or choose:GetStringWidth()) or 0
            mark.label:SetPoint("LEFT", choose, "LEFT", w + 8, 0)
            -- Long item names are cut with "..." rather than running off the page.
            local room = GP.Safe(QuestInfoRewardsFrame.GetWidth and QuestInfoRewardsFrame:GetWidth())
            if room and room - w - 20 > 60 then mark.label:SetWidth(room - w - 20) end
        else
            mark.label:SetPoint("BOTTOMLEFT", mark, "TOPLEFT", 2, 4)
        end
        mark:Show()
        if mark.pulse and not mark.pulse:IsPlaying() then mark.pulse:Play() end
    end
    -- Also in chat, once per quest: the mark can't be missed there, and it says why.
    local key = (GetTitleText and GetTitleText() or "") .. p.link
    if key ~= lastNoted then
        lastNoted = key
        GP.Print(string.format(L["Pick %s: %s"], p.link, why(p)))
    end
end
GP.ShowQuestPick = show

GP:On("QUEST_COMPLETE", function() C_Timer.After(0, function() show(0) end) end)
GP:On("QUEST_DETAIL", function() C_Timer.After(0, function() show(0) end) end)
GP:On("QUEST_ITEM_UPDATE", function() if mark and mark:IsShown() then show(0) end end)
GP:On("QUEST_FINISHED", hideMark)
