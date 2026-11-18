-- Haulwise: which quest reward to pick. When a quest offers a choice, Haulwise marks one:
-- the biggest gear upgrade for you (Pawn or Haulwise weights, like the Upgrade Advisor), and when
-- none of them is an upgrade, the one worth the most (vendor, auction house or disenchanting).
local _, GP = ...
local L = GP.L

-- Returns pick = { index, link, kind = "upgrade"|"value", gain, slotName, value, src }, or nil.
function GP:QuestRewardPick()
    local n = GetNumQuestChoices and GetNumQuestChoices() or 0
    if n < 2 then return nil end
    local who = GP.MeForGear and GP.MeForGear()
    local bestUp, bestVal
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
        local unit, src = self:BagValue(id, link, info.bindType == 1)
        local value = (unit or 0) * count
        if not bestVal or value > bestVal.value then
            bestVal = { index = i, link = link, kind = "value", value = value, src = src }
        end
    end
    return bestUp or bestVal
end

local function rewardButton(i)
    local f = QuestInfoRewardsFrame
    if f and f.RewardButtons and f.RewardButtons[i] then return f.RewardButtons[i] end
    return _G["QuestInfoRewardsFrameQuestInfoItem" .. i] or _G["QuestInfoItem" .. i]
end

local mark
local function hideMark() if mark then mark:Hide() end end

local function why(p)
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
            mark = CreateFrame("Frame", "HaulwiseQuestPick", UIParent, "BackdropTemplate")
            mark:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
            mark:SetBackdropBorderColor(1, 0.82, 0.25, 1)
            mark:EnableMouse(false)
            mark.label = mark:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGold")
            mark.label:SetPoint("BOTTOMLEFT", mark, "TOPLEFT", 2, 2)
            mark.label:SetJustifyH("LEFT")
        end
        mark:SetParent(b)
        mark:SetFrameLevel(b:GetFrameLevel() + 5)
        mark:ClearAllPoints()
        mark:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
        mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
        mark.label:SetText(L["Haulwise pick"])
        mark:Show()
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
