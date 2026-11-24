-- Haulwise: which reagents in your bags and bank are still worth keeping for your professions.
-- An item is worth keeping when a recipe you or an alt know still gives skill with it (orange,
-- yellow or green), when crafting it makes a profit, or when it goes into a recipe you can learn
-- within the next 25 points. It's done with when every recipe of yours that uses it has gone grey.
-- Items no known recipe uses are left alone: Haulwise can't tell what they're for.
-- Shown in a panel next to the bank (with what's safe to sell from bags and bank), and as one
-- line in item tooltips.
local _, GP = ...
local L = GP.L

local SOON = 25 -- skill points ahead: reagents for recipes you can learn this soon are kept
local MAX_CRAFTS = 10 -- per recipe: its colour changes as you skill up, so further than this is a guess
local DIFF_COLOR = { [0] = "|cffff8040", [1] = "|cffffff00", [2] = "|cff40c040" }

local function sameSide(c)
    local realm = GP.RealmName()
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    return c.realm == realm and c.faction == faction
end

-- [itemID] = { skill = {...}, profit = {...}, soon = {...}, grey = n }, rebuilt at most once a minute.
local index, indexTime = nil, 0
function GP:ForgetReagentUses() index = nil end

local function better(a, b) -- the best recipe to name: yours first, then the most skill per craft
    if not b then return true end
    if a.mine ~= b.mine then return a.mine end
    return (a.d or 9) < (b.d or 9)
end

local function buildIndex()
    if index and GetTime() - indexTime < 60 then return index end
    index, indexTime = {}, GetTime()
    local me = GP:CharKey()
    local function entry(id)
        local e = index[id]
        if not e then e = { grey = 0 }; index[id] = e end
        return e
    end
    local myName = UnitName and UnitName("player")
    local makers = {} -- every recipe that makes an item: { out, name, reagents }
    for key, c in pairs(GP.db.chars or {}) do
        -- An old record of this same character under another key isn't an alt: skip it.
        local stale = key ~= me and c.short and c.short == myName
        if not stale and (key == me or sameSide(c)) then
            local mine = key == me
            local who = (not mine) and (c.short or key:match("^([^%-]+)") or key) or nil
            for _, rec in pairs(c.recipes or {}) do
                if rec.out then makers[#makers + 1] = { out = rec.out, name = rec.n, reagents = GP.UnpackReagents(rec.r) } end
            end
            for _, book in ipairs({ c.recipes or {}, c.services or {} }) do
                for _, rec in pairs(book) do
                    if rec.learned then
                        local gives = rec.d and GP.SKILL_CHANCE[rec.d]
                        for _, r in ipairs(GP.UnpackReagents(rec.r)) do
                            local e = entry(r[1])
                            if gives then
                                local cand = { name = rec.n, prof = rec.prof, d = rec.d, mine = mine, who = who }
                                if better(cand, e.skill) then e.skill = cand end
                            elseif rec.d == 3 then
                                e.grey = e.grey + 1
                            end
                        end
                    end
                end
            end
        end
    end
    -- Crafts that make money (yours), and recipes you can learn soon.
    for _, r in ipairs(GP:CraftRows()) do
        if r.profit and r.profit > 0 and #r.missing == 0 then
            for _, rg in ipairs(r.reagents or {}) do
                local e = entry(rg[1])
                if not e.profit or r.profit > e.profit.each then e.profit = { name = r.name, each = r.profit } end
            end
        end
    end
    local ok, rows = pcall(GP.RecipeRowsCached, GP)
    for _, r in ipairs(ok and rows or {}) do
        if r.kind == "recipe" and r.skill and r.myRank and r.skill <= r.myRank + SOON then
            for _, rg in ipairs(r.reagents or {}) do
                local e = entry(rg[1])
                if not e.soon or r.skill < e.soon.skill then e.soon = { name = r.name, prof = r.prof, skill = r.skill } end
            end
        end
    end
    -- Recipes other players shared, for a profession you're still levelling: a reagent a recipe
    -- above your skill uses isn't done with (Mageweave for a tailor at 155). Its skill is the wiki's.
    local profs = GP:MyProfessions()
    for _, craft in pairs(GP.SharedCrafts and GP:SharedCrafts() or {}) do
        local p = craft.prof and profs[craft.prof]
        local name = p and GP.ItemInfo(craft.out)
        local w = name and GP.WikiRecipe and GP.WikiRecipe(name)
        if w and p.rank and w.skill > p.rank then
            for _, rg in ipairs(craft.reagents or {}) do
                local e = entry(rg[1])
                if w.skill <= p.rank + SOON then
                    if not e.soon or w.skill < e.soon.skill then e.soon = { name = name, prof = craft.prof, skill = w.skill } end
                else
                    e.later = true
                end
            end
        end
    end
    -- Mats for mats: Silk Cloth only goes into Bolt of Silk Cloth (grey), but the bolts go into
    -- recipes that still give skill, so the cloth is kept too. Two steps deep.
    local function goal(e)
        if not e then return nil end
        if e.skill then return e.skill.name, e.skill.d end
        if e.profit then return e.profit.name end
        if e.soon then return e.soon.name end
        if e.chain then return e.chain.final, e.chain.d end
    end
    for _ = 1, 2 do
        for _, x in ipairs(makers) do
            local final, d = goal(index[x.out])
            if final then
                for _, rg in ipairs(x.reagents) do
                    local e = entry(rg[1])
                    if rg[1] ~= x.out and not (e.skill or e.profit or e.soon or e.chain) then
                        e.chain = { via = x.name, final = final, d = d }
                    end
                end
            end
        end
    end
    return index
end

-- What to do with an item for your professions: { keep = bool, why = "skill"|"profit"|"soon"|"done",
-- text } or nil when no recipe of yours or your alts' uses it.
function GP:ReagentVerdict(id)
    local e = id and buildIndex()[id]
    if not e then return nil end
    if e.skill then
        local s = e.skill
        local text = string.format(L["skill up %s: %s"], L[s.prof or ""] or "", (DIFF_COLOR[s.d] or "") .. (s.name or "?") .. "|r")
        local short = (DIFF_COLOR[s.d] or "") .. (s.name or "?") .. "|r"
        if s.who then
            text = text .. string.format(L[" (%s)"], "|cffff9944" .. s.who .. "|r")
            short = short .. " |cffff9944" .. s.who .. "|r"
        end
        return { keep = true, why = "skill", text = text, short = short, who = s.who, d = s.d }
    end
    if e.profit then
        return { keep = true, why = "profit", text = string.format(L["craft %s for profit: +%s each"], e.profit.name or "?", GP.Coins(e.profit.each, true)),
                 short = (e.profit.name or "?") .. " |cff5fd35f+" .. GP.Coins(e.profit.each, true) .. "|r" }
    end
    if e.soon then
        return { keep = true, why = "soon", text = string.format(L["for %s at %s %d"], e.soon.name or "?", L[e.soon.prof or ""] or "", e.soon.skill),
                 short = "|cff8a8880" .. string.format(L["%s at %d"], e.soon.name or "?", e.soon.skill) .. "|r" }
    end
    if e.chain then
        local c = e.chain
        return { keep = true, why = "chain", text = string.format(L["makes %s for %s"], c.via or "?", (DIFF_COLOR[c.d] or "") .. (c.final or "?") .. "|r"),
                 short = "|cff8a8880" .. (c.via or "?") .. " >|r " .. (DIFF_COLOR[c.d] or "") .. (c.final or "?") .. "|r" }
    end
    if e.grey > 0 and not e.later then
        if self.QuestKeepReason and self:QuestKeepReason(id) then return nil end
        return { keep = false, why = "done", text = L["no recipe of yours gives skill with it anymore"] }
    end
    return nil
end

-- What's in this character's bags and bank, split into what to keep and what you're done with,
-- plus what you can craft right now for skill.
function GP:StashReport()
    local c = self:Char()
    local have, where = {}, {}
    for _, loc in ipairs({ "bags", "bank" }) do
        for id, n in pairs(c[loc] or {}) do
            have[id] = (have[id] or 0) + n
            local here = loc == "bags" and L["in your bags"] or L["in your bank"]
            where[id] = (where[id] and where[id] ~= here) and L["in your bags and bank"] or here
        end
    end
    local keep, done, doneValue = {}, {}, 0
    for id, n in pairs(have) do
        local v = self:ReagentVerdict(id)
        if v then
            local row = { id = id, count = n, where = where[id], v = v }
            if v.keep then
                keep[#keep + 1] = row
            else
                local unit, ah = self:ItemValue(id)
                row.unit, row.ah = unit or 0, ah
                row.total = row.unit * n
                doneValue = doneValue + row.total
                done[#done + 1] = row
            end
        end
    end
    local order = { skill = 1, chain = 2, profit = 3, soon = 4 }
    table.sort(keep, function(a, b)
        if a.v.why ~= b.v.why then return order[a.v.why] < order[b.v.why] end
        if (a.v.d or 9) ~= (b.v.d or 9) then return (a.v.d or 9) < (b.v.d or 9) end
        return a.id < b.id
    end)
    table.sort(done, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.id < b.id
    end)

    -- Crafts for skill you can make from what you have, orange first; mats used once are gone.
    local left = {}
    for id, n in pairs(have) do left[id] = n end
    local recipes = {}
    for _, book in ipairs({ c.recipes or {}, c.services or {} }) do
        for _, rec in pairs(book) do
            local chance = rec.learned and rec.d and GP.SKILL_CHANCE[rec.d]
            if chance then recipes[#recipes + 1] = { rec = rec, chance = chance } end
        end
    end
    table.sort(recipes, function(a, b)
        if a.rec.d ~= b.rec.d then return a.rec.d < b.rec.d end
        return (a.rec.n or "") < (b.rec.n or "")
    end)
    local crafts = {}
    for _, x in ipairs(recipes) do
        local reagents = GP.UnpackReagents(x.rec.r)
        local times = math.huge
        for _, r in ipairs(reagents) do times = math.min(times, math.floor((left[r[1]] or 0) / r[2])) end
        local canMake = times
        times = math.min(times, MAX_CRAFTS)
        if #reagents > 0 and times > 0 and times < math.huge then
            for _, r in ipairs(reagents) do left[r[1]] = left[r[1]] - times * r[2] end
            crafts[#crafts + 1] = { name = x.rec.n, prof = x.rec.prof, d = x.rec.d, times = times,
                                    points = times * x.chance, icon = x.rec.icon, out = x.rec.out, canMake = canMake }
        end
    end
    return { keep = keep, done = done, doneValue = doneValue, crafts = crafts, bankSeen = c.seen and c.seen.bank }
end

-- Safe to sell: everything in your bags (and the bank, while it's open) that nothing of yours
-- needs. The Bags tab's rules decide what's protected (quest items, upgrades, things you use,
-- epics, crafting materials Haulwise can't place); profession reagents you're done with are
-- offered too. Stacks of one item are one row; gear is one row per piece.
function GP:CleanupItems(withBank)
    local bags = {}
    for _, b in ipairs(GP.BagIDs()) do bags[#bags + 1] = { b, L["in your bags"] } end
    if withBank and GP.BankIDs then
        for _, b in ipairs(GP.BankIDs()) do bags[#bags + 1] = { b, L["in your bank"] } end
    end
    local groups, list = {}, {}
    for _, x in ipairs(bags) do
        local bag, where = x[1], x[2]
        for slot = 1, GP.NumSlots(bag) do
            local it = GP.SlotInfo(bag, slot)
            if it and it.itemID then
                local info = GP.LinkInfo(it.hyperlink or it.itemID)
                local v = self:ReagentVerdict(it.itemID)
                local sell, why = false, nil
                if v and v.why == "done" then
                    sell, why = true, v.text
                elseif not (v and v.keep) and not self:ProtectReason(bag, slot, it, info) then
                    sell = true
                end
                if sell then
                    local gear = info.classID == 2 or info.classID == 4
                    local key = gear and (bag .. ":" .. slot) or it.itemID
                    local g = groups[key]
                    if not g then
                        local unit, src, d = self:BagValue(it.itemID, it.hyperlink, it.isBound)
                        g = { id = it.itemID, link = it.hyperlink, count = 0, unit = unit or 0, src = src, d = d,
                              why = why, where = where, quality = it.quality or info.quality }
                        groups[key] = g
                        list[#list + 1] = g
                    elseif g.where ~= where then
                        g.where = L["in your bags and bank"]
                    end
                    g.count = g.count + (it.stackCount or 1)
                end
            end
        end
    end
    local out, total = {}, 0
    for _, g in ipairs(list) do
        g.total = g.unit * g.count
        if g.total > 0 then
            g.advice = self:BagAdvice(g)
            total = total + g.total
            out[#out + 1] = g
        end
    end
    table.sort(out, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.id < b.id
    end)
    return out, total
end

-- The panel ----------------------------------------------------------------------------------

local panel
local WIDTH = 440
local INNER = WIDTH - 24 - 22 -- minus the margins and the scroll bar
local MAX_LIST = 460          -- tallest the list gets before it scrolls

local function header(f, i, text)
    local h = f.heads[i]
    if not h then
        h = f.child:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGold")
        h:SetJustifyH("LEFT")
        h:SetWidth(INNER)
        h:SetWordWrap(false)
        f.heads[i] = h
    end
    h:SetText(text)
    h:Show()
    return h
end

local function row(f, i)
    local r = f.rows[i]
    if not r then
        r = GP.ItemRow(f.child, INNER)
        f.rows[i] = r
    end
    r:Show()
    return r
end

local function grey(t) return "|cff8a8880" .. t .. "|r" end

local function build()
    panel = GP.Panel("HaulwiseStash", WIDTH, 120, L["Bags and bank: keep or sell"])
    panel.rows, panel.heads = {}, {}
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(INNER, 10)
    scroll:SetScrollChild(child)
    panel.scroll, panel.child = scroll, child
    panel.note = panel:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    panel.note:SetJustifyH("LEFT")
    panel.note:SetWidth(WIDTH - 24)
    panel.note:SetTextColor(0.55, 0.54, 0.5)
    panel.note:SetPoint("BOTTOMLEFT", 12, 10)
    panel.note:SetText(L["Colours are from the last time each profession window was open: open it again after skilling up."])
end

function GP:ShowStash()
    local rep = self:StashReport()
    local bankOpen = GP.IsBankOpen and GP.IsBankOpen()
    local sell, sellTotal = self:CleanupItems(bankOpen)
    if #rep.keep == 0 and #rep.crafts == 0 and #sell == 0 then
        if panel then panel:Hide() end
        return false
    end
    if not panel then build() end
    local f = panel
    for _, r in ipairs(f.rows) do r:Hide() end
    for _, h in ipairs(f.heads) do h:Hide() end
    local y, nr, nh = 0, 0, 0
    local function addHead(text)
        nh = nh + 1
        local h = header(f, nh, text)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, y - 4)
        y = y - 22
    end
    local function addRow()
        nr = nr + 1
        local r = row(f, nr)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, y)
        r:SetScript("OnClick", nil)
        r.tip = nil
        r.right:SetWidth(0)
        r.right:SetWordWrap(false)
        y = y - 22
        return r
    end

    -- Suggestions first: what to craft now.
    if #rep.crafts > 0 then
        local points = 0
        for _, x in ipairs(rep.crafts) do points = points + x.points end
        addHead(string.format(L["Craft now: about %d skill points from what you have"], math.floor(points + 0.5)))
        for _, x in ipairs(rep.crafts) do
            local r = addRow()
            if x.out then r:SetItem(x.out, nil, nil) else r.icon:SetTexture(x.icon or 136244) end
            r.name:SetText((DIFF_COLOR[x.d] or "") .. (x.name or "?") .. "|r |cffaaaaaax" .. x.times .. "|r")
            r.right:SetText(grey(string.format(L["~%d points"], math.max(1, math.floor(x.points + 0.5)))))
            r.tip = function(t)
                t:AddLine(x.name or "?", 1, 0.82, 0.25)
                t:AddLine(string.format(L["%s: you have the mats for %d. Orange always gives a point, yellow mostly, green now and then."],
                    L[x.prof or ""] or "", x.canMake), 0.8, 0.8, 0.8, true)
                if x.canMake > x.times then
                    t:AddLine(string.format(L["Counted as %d: the colour changes as you skill up, so look again after those."], x.times), 0.6, 0.6, 0.6, true)
                end
            end
        end
    end
    if #rep.keep > 0 then
        addHead(string.format(L["Keep (%d)"], #rep.keep))
        for _, k in ipairs(rep.keep) do
            local r = addRow()
            r:SetItem(k.id, nil, nil, k.count)
            r.right:SetText(k.v.short or k.v.text)
            r.right:SetWidth(220)
            r.tip = function(t)
                t:SetItemByID(k.id)
                t:AddLine(" ")
                t:AddLine(L["|cffffd700Haulwise|r keep: "] .. k.v.text, 1, 1, 1, true)
                t:AddLine(k.count .. " " .. k.where, 0.6, 0.6, 0.6)
            end
        end
    end
    if #sell > 0 then
        addHead(string.format(bankOpen and L["Safe to sell from bags and bank (%d): worth %s"] or L["Safe to sell from your bags (%d): worth %s"],
            #sell, GP.Coins(sellTotal, true)))
        for _, k in ipairs(sell) do
            local r = addRow()
            r:SetItem(k.id, k.link, nil, k.count)
            r.right:SetText(GP.Coins(k.total, true) .. "  " .. (k.advice or ""))
            r.right:SetWidth(230)
            r.tip = function(t)
                if k.link then t:SetHyperlink(k.link) else t:SetItemByID(k.id) end
                t:AddLine(" ")
                if k.why then
                    t:AddLine(L["|cffffd700Haulwise|r: every recipe of yours that uses it has gone grey, so it gives no more skill."], 1, 1, 1, true)
                else
                    t:AddLine(L["|cffffd700Haulwise|r: nothing of yours needs it. It isn't for a quest, an upgrade, something you use or a recipe you know."], 1, 1, 1, true)
                end
                t:AddLine(k.count .. " " .. k.where, 0.6, 0.6, 0.6)
            end
        end
    end
    if not bankOpen then
        addHead(grey(L["Open the bank to check what's in it too."]))
    end
    -- The list scrolls once it's taller than MAX_LIST; the note stays under it.
    local listH = -y + 4
    f.child:SetHeight(listH)
    local shown = math.min(listH, MAX_LIST)
    f.scroll:SetHeight(shown)
    local noteH = f.note:GetStringHeight() or 24
    f:SetHeight(32 + shown + 8 + noteH + 12)
    if listH <= MAX_LIST and f.scroll.SetVerticalScroll then f.scroll:SetVerticalScroll(0) end
    if not f:IsShown() then
        f:ClearAllPoints()
        local pos = GP.db.positions and GP.db.positions.HaulwiseStash
        if pos then
            f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        elseif BankFrame and BankFrame:IsShown() then
            f:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT", 6, 0)
        else
            f:SetPoint("LEFT", UIParent, "LEFT", 40, 60)
        end
    end
    f:Show()
    return true
end

function GP:ToggleStash()
    if panel and panel:IsShown() then panel:Hide(); return end
    if not self:ShowStash() then GP.Print(L["No reagents for your recipes in your bags or bank. Open your profession windows so Haulwise knows your recipes."]) end
end

GP:On("BANKFRAME_OPENED", function()
    if GP.db.settings.stashAtBank then C_Timer.After(1.5, function() GP:ShowStash() end) end
end)
GP:On("BANKFRAME_CLOSED", function() if panel then panel:Hide() end end)
GP:On("BAG_UPDATE_DELAYED", function()
    if panel and panel:IsShown() then C_Timer.After(1.2, function() GP:ForgetReagentUses(); GP:ShowStash() end) end
end)
GP:On("TRADE_SKILL_LIST_UPDATE", function() index = nil end)

-- One line in item tooltips: keep it for a profession, or done with it.
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, info)
        if not GP.db or tooltip ~= GameTooltip or not GP.db.settings.tooltipUses then return end
        local id = info and GP.Safe(info.id)
        if not id then return end
        local ok, v = pcall(GP.ReagentVerdict, GP, id)
        if not ok then GP.ReportError("reagent tooltip", v); return end
        if not v then return end
        if v.keep then
            tooltip:AddLine(L["|cffffd700Haulwise|r keep: "] .. v.text, 1, 1, 1, true)
        else
            tooltip:AddLine(L["|cffffd700Haulwise|r done with it: "] .. "|cffaaaaaa" .. v.text .. "|r", 1, 1, 1, true)
        end
    end)
end
