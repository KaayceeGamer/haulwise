-- Haulwise: Upgrade Advisor. Scores gear with stat weights for your talent tree (DataWeights.lua),
-- compares with what you wear, and does the same for your alts using their stored gear, so
-- Bind-on-Equip loot can be mailed to the character it helps most.
local _, GP = ...

local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local SLOT_NAME = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands",
    "Ring", "Ring", "Trinket", "Trinket", "Back", "Main hand", "Off hand", "Ranged" }
GP.SLOT_NAME = SLOT_NAME

local RANGED_SUB = { [2] = true, [3] = true, [16] = true, [18] = true }

-- Talent tree -----------------------------------------------------------------------------------

local function treesFor(classFile) return GP.WEIGHTS[classFile] or GP.WEIGHTS.WARRIOR end

-- The tree with the most points, or your own choice (Gear tab), or the class's first tree.
function GP:CurrentSpec()
    local c = self.db.chars[self:CharKey()]
    if c and c.specOverride then return c.specOverride end
    local _, classFile = UnitClass("player")
    local trees = treesFor(classFile)
    local best, bestPts = trees[1][1], 0
    if GetTalentTabInfo then
        for i = 1, #trees do
            local r = { pcall(GetTalentTabInfo, i) }
            local pts = (type(r[4]) == "number" and r[4]) or (type(r[6]) == "number" and r[6]) or 0
            if r[1] and pts > bestPts then best, bestPts = trees[i][1], pts end
        end
    end
    return best
end

-- Gear tab button: Pawn's weights -> Haulwise tree 1 -> 2 -> 3 -> back to Pawn.
function GP:CycleSpec()
    local c = self:Char()
    local s = self.db.settings
    local _, classFile = UnitClass("player")
    local trees = treesFor(classFile)
    if self:UsePawn() then
        s.usePawn = false
        c.specOverride = trees[1][1]
    else
        local cur, idx = self:CurrentSpec(), 1
        for i, t in ipairs(trees) do if t[1] == cur then idx = i end end
        if idx == #trees and pawnReady() then
            s.usePawn = true
            c.specOverride = nil
        else
            c.specOverride = trees[idx % #trees + 1][1]
        end
    end
    c.spec = self:CurrentSpec()
    self:ScanUpgrades()
end

function GP:WeightsLabel()
    local scales = self:UsePawn() and self:PawnVisibleScales()
    if scales then return scalesLabel(scales) end
    return self:CurrentSpec() .. " (Haulwise)"
end

local function weightsFor(classFile, spec)
    for _, t in ipairs(treesFor(classFile)) do if t[1] == spec then return t[2] end end
    return treesFor(classFile)[1][2]
end

-- Pawn ------------------------------------------------------------------------------------------
-- If Pawn is installed, Haulwise uses Pawn's own stat weights (the scales Pawn shows for each
-- character), through Pawn's public functions. Haulwise's built-in weights are the fallback.

-- Pawn 2.14 keeps PawnIsInitialized local and exposes PawnIsReady() instead; older versions
-- only have the global.
local function pawnReady()
    if not (PawnGetItemData and PawnGetSingleValueFromItem and PawnGetAllScalesEx) then return false end
    if PawnIsReady then
        local ok, ready = pcall(PawnIsReady)
        return ok and ready and true or false
    end
    return PawnIsInitialized and true or false
end

function GP.PawnLoaded() return pawnReady() and true or false end

function GP:UsePawn()
    return self.db.settings.usePawn and pawnReady() and true or false
end

-- The Pawn scales shown for the character you're playing: { { name, label }, ... }
function GP:PawnVisibleScales()
    if not pawnReady() then return nil end
    local ok, list = pcall(PawnGetAllScalesEx)
    if not ok or not list then return nil end
    local out = {}
    for _, sc in ipairs(list) do
        if sc.IsVisible then out[#out + 1] = { sc.Name, sc.LocalizedName or sc.Name } end
    end
    return #out > 0 and out or nil
end

local pawnItems = {}
local function pawnValue(link, scales)
    if not link then return 0 end
    local item = pawnItems[link]
    if not item then
        local ok, data = pcall(PawnGetItemData, link)
        if not ok or not data then return nil end
        item = data
        pawnItems[link] = item
    end
    local best = 0
    for _, sc in ipairs(scales) do
        local ok, v = pcall(PawnGetSingleValueFromItem, item, sc[1])
        if ok and v and v > best then best = v end
    end
    return best
end

local function pawnScorer(scales)
    return function(link)
        if not link then return 0 end
        return pawnValue(link, scales) or 0
    end
end

local function scalesLabel(scales)
    local names = {}
    for _, sc in ipairs(scales) do names[#names + 1] = (sc[2]:gsub("^\"[^\"]*\":", "")) end
    return "Pawn: " .. table.concat(names, ", ")
end

-- Scoring --------------------------------------------------------------------------------------

local statCache = {}
function GP.ItemStats(link)
    if statCache[link] then return statCache[link] end
    local get = (C_Item and C_Item.GetItemStats) or GetItemStats
    local raw = get and get(link) or nil
    -- Right after login the game can answer with nothing for items it hasn't loaded yet.
    -- Don't remember that: ask again next time, or every item compared with it looks +100%.
    if not raw or next(raw) == nil then
        local id = tonumber(link:match("item:(%d+)"))
        if id and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return nil
    end
    local out = {}
    for k, v in pairs(raw) do
        local s = GP.STAT_KEYS[k]
        if s then out[s] = (out[s] or 0) + v end
    end
    statCache[link] = out
    return out
end

local function score(link, w)
    if not link then return 0 end
    local st = GP.ItemStats(link)
    if not st then return 0 end
    local info = GP.LinkInfo(link)
    local total = 0
    for s, v in pairs(st) do
        local weight = w[s] or 0
        if s == "DPS" and info.classID == 2 then
            if info.subclassID == 19 then weight = w.WAND or 0
            elseif RANGED_SUB[info.subclassID] then weight = w.RDPS or 0 end
        end
        total = total + v * weight
    end
    return total
end
GP.GearScore = score

-- Can this class (at this level) use the item at all?
local function canUse(info, classFile, level)
    if info.classID == 4 then
        local sub = info.subclassID or 0
        if sub == 0 then return true end -- rings, necks, trinkets, cloaks
        local need = GP.ARMOR[classFile] and GP.ARMOR[classFile][sub]
        if not need then return false end
        return true, need > (level or 1) and need or nil
    elseif info.classID == 2 then
        if info.subclassID == 20 then return false end -- fishing poles
        return GP.WEAPONS[classFile] and GP.WEAPONS[classFile][info.subclassID] or false
    end
    return false
end

-- Red text in the tooltip means the game says you can't use it (class, skill, faction...).
local function tooltipBlocked(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or not data or not data.lines then return false end
    for _, line in ipairs(data.lines) do
        local c = line.leftColor
        if c and c.r and c.r > 0.95 and c.g < 0.2 and c.b < 0.2 and line.leftText and not line.leftText:find("%d+ / %d+") then
            local lvl = line.leftText:match("(%d+)")
            -- "Requires Level 40" is a future upgrade, not a blocker.
            if not (lvl and line.leftText:lower():find("level")) then return true end
        end
    end
    return false
end

-- Compare one item with a character's gear. who = { classFile, level, spec, links = {[slot]=link}, me }
function GP:CompareGear(link, who)
    local info = GP.LinkInfo(link)
    local slots = SLOTS[info.equipLoc or ""]
    if not slots then return nil end
    local usable, armorLevel = canUse(info, who.classFile, who.level)
    if not usable then return nil end
    if who.me and not who.skipTooltip and tooltipBlocked(link) then return nil end
    local w = weightsFor(who.classFile, who.spec)
    local sc = who.scorer or function(l) return score(l, w) end
    local new = sc(link)
    if new <= 0 then return nil end

    local links = who.links or {}
    local best
    local candidates = slots
    if info.equipLoc == "INVTYPE_WEAPON" and not ((GP.DUAL_WIELD[who.classFile] or 999) <= (who.level or 1)) then
        candidates = { 16 }
    end
    for _, slot in ipairs(candidates) do
        local old, replaces
        if info.equipLoc == "INVTYPE_2HWEAPON" then
            old = sc(links[16]) + sc(links[17]) * 0.5
            replaces = links[16]
        else
            local mh = links[16] and GP.LinkInfo(links[16])
            if slot == 17 and mh and mh.equipLoc == "INVTYPE_2HWEAPON" then
                old = nil -- wearing a two-hander: an off-hand isn't a straight swap
            else
                old, replaces = sc(links[slot]), links[slot]
                -- Something is worn there but its stats aren't loaded yet: we can't compare.
                if links[slot] and not GP.ItemStats(links[slot]) and not who.scorer then old = nil end
            end
        end
        if old then
            local gain = old > 0 and (new - old) / old or 1
            if new > old * 1.01 and (not best or gain > best.gain) then
                best = { gain = gain, slot = slot, replaces = replaces, new = new, old = old }
            end
        end
    end
    if not best then return nil end
    local atLevel = (info.minLevel and info.minLevel > (who.level or 1)) and info.minLevel or armorLevel
    best.atLevel = atLevel
    best.slotName = SLOT_NAME[best.slot]
    return best
end

local function me()
    local _, classFile = UnitClass("player")
    local links = {}
    for slot = 1, 19 do links[slot] = GetInventoryItemLink("player", slot) end
    local who = { classFile = classFile, level = UnitLevel("player"), spec = GP:CurrentSpec(), links = links, me = true,
                  name = UnitName("player") }
    local scales = GP:UsePawn() and GP:PawnVisibleScales()
    if scales then
        who.scorer, who.label = pawnScorer(scales), scalesLabel(scales)
        GP:Char().pawnScales = scales
    else
        who.label = who.spec .. " (Haulwise)"
    end
    return who
end
GP.MeForGear = me

local function altWho(c)
    local who = { classFile = c.classFile, level = c.level, spec = c.spec or (treesFor(c.classFile)[1][1]),
                  links = c.equippedLinks or {}, me = false, name = c.short }
    if GP:UsePawn() and c.pawnScales then
        who.scorer, who.label = pawnScorer(c.pawnScales), scalesLabel(c.pawnScales)
    else
        who.label = who.spec .. " (Haulwise)"
    end
    return who
end

-- Scan bags ------------------------------------------------------------------------------------

GP.upgrades = { mine = {}, alts = {} }

function GP:ScanUpgrades()
    local mine, alts = {}, {}
    local ignored = self.db.ignoredUpgrades
    pawnItems = {}
    local myself = me()
    local altList = {}
    for _, c in ipairs(self:Alts()) do if c.classFile then altList[#altList + 1] = c end end
    for _, bag in ipairs(GP.BagIDs()) do
        for slot = 1, GP.NumSlots(bag) do
            local it = GP.SlotInfo(bag, slot)
            if it and it.hyperlink and it.itemID and not ignored[it.itemID] then
                local info = GP.LinkInfo(it.hyperlink)
                if SLOTS[info.equipLoc or ""] then
                    if self.db.settings.upgradeAdvisor then
                        local r = self:CompareGear(it.hyperlink, myself)
                        if r then
                            r.id, r.link, r.bag, r.slot, r.who, r.label = it.itemID, it.hyperlink, bag, slot, myself.name, myself.label
                            mine[#mine + 1] = r
                        end
                    end
                    if not it.isBound and info.bindType ~= 1 then
                        for _, c in ipairs(altList) do
                            local aw = altWho(c)
                            local r = self:CompareGear(it.hyperlink, aw)
                            if r then
                                alts[#alts + 1] = { id = it.itemID, link = it.hyperlink, bag = bag, slot = slot, alt = c.short,
                                                    gain = r.gain, atLevel = r.atLevel, slotName = r.slotName, replaces = r.replaces,
                                                    old = r.old, new = r.new, label = aw.label }
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(mine, function(a, b) return a.gain > b.gain end)
    table.sort(alts, function(a, b) return a.gain > b.gain end)
    self.upgrades = { mine = mine, alts = alts }
    if self.RefreshUI then self:RefreshUI() end
    if self.RefreshHUD then self:RefreshHUD() end
    return mine, alts
end

function GP:AltUpgradesInBags() return self.upgrades.alts end

-- Upgrades on the auction house ------------------------------------------------------------------
-- After a full AH scan, every gear listing is checked against what you and your alts wear. The
-- result is ranked by how much upgrade each gold buys, so a cheap +15% beats a pricey +20%.

local CHUNK_LINKS = 150
local MIN_GAIN = 0.03
local LEVEL_AHEAD = 3   -- also show gear you can wear within 3 levels
local PER_SLOT = 3      -- best few listings per character and slot

local function ahWhoList()
    local list = {}
    local mine = me()
    mine.skipTooltip, mine.key = true, "me"
    list[1] = mine
    for _, c in ipairs(GP:Alts()) do
        if c.classFile and c.level then
            local w = altWho(c)
            w.key = c.key
            list[#list + 1] = w
        end
    end
    return list
end

function GP:FindAHUpgrades(gear, done)
    local links = {}
    for link, g in pairs(gear) do links[#links + 1] = { link = link, id = g.id, price = g.price } end
    local whoList = ahWhoList()
    local found, retry, i = {}, {}, 0
    pawnItems = {}
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo

    local function check(l)
        for _, who in ipairs(whoList) do
            local r = self:CompareGear(l.link, who)
            if r and r.gain >= MIN_GAIN and not (r.atLevel and r.atLevel > (who.level or 1) + LEVEL_AHEAD) then
                found[#found + 1] = {
                    link = l.link, id = l.id, price = l.price, gain = r.gain, slot = r.slot, slotName = r.slotName,
                    replaces = r.replaces, atLevel = r.atLevel, forMe = who.me and true or false,
                    alt = not who.me and who.name or nil, label = who.label,
                    perGold = r.gain / math.max(l.price / 10000, 0.01),
                    name = (get(l.link)), replacesName = r.replaces and (get(r.replaces)) or nil,
                }
            end
        end
    end

    local function finishUp()
        -- Gear you can't use (red tooltip lines) only shows up in the tooltip, so check the few
        -- that made it for you here rather than for every listing.
        local keep = {}
        for _, r in ipairs(found) do
            if not (r.forMe and tooltipBlocked(r.link)) then keep[#keep + 1] = r end
        end
        table.sort(keep, function(a, b) return a.perGold > b.perGold end)
        local perKey, rows = {}, {}
        for _, r in ipairs(keep) do
            local k = (r.alt or "me") .. ":" .. (r.slotName or "?")
            perKey[k] = (perKey[k] or 0) + 1
            if perKey[k] <= PER_SLOT and #rows < 200 then rows[#rows + 1] = r end
        end
        self.db.ahUpgrades = { t = time(), rows = rows }
        if #rows > 0 then
            self.Print(string.format("Found |cff5fd35f%d|r gear upgrades on the auction house. See Gear → On the AH.", #rows))
        end
        if done then done(rows) end
        if self.RefreshUI then self:RefreshUI() end
    end

    local function retryPass()
        for _, l in ipairs(retry) do check(l) end
        finishUp()
    end

    local function step()
        local stop = math.min(#links, i + CHUNK_LINKS)
        for k = i + 1, stop do
            local l = links[k]
            if get(l.link) then
                check(l)
            else
                if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(l.id) end
                retry[#retry + 1] = l
            end
        end
        i = stop
        if i < #links then C_Timer.After(0, step)
        elseif #retry > 0 then C_Timer.After(3, retryPass)
        else finishUp() end
    end
    step()
end

-- Gear changes after the scan (you equip something, an alt levels): check the saved rows again
-- against what everyone wears now. At most once every 30 seconds.
local lastRecheck = 0
function GP:RecheckAHUpgrades(force)
    local d = self.db.ahUpgrades
    if not d or not d.rows then return end
    if not force and GetTime() - lastRecheck < 30 then return end
    lastRecheck = GetTime()
    local whoBy = {}
    for _, w in ipairs(ahWhoList()) do whoBy[w.me and "me" or w.name] = w end
    local keep = {}
    for _, r in ipairs(d.rows) do
        local who = whoBy[r.forMe and "me" or r.alt]
        if who then
            local c = self:CompareGear(r.link, who)
            if c and c.gain >= MIN_GAIN then
                r.gain, r.slot, r.slotName, r.replaces, r.atLevel = c.gain, c.slot, c.slotName, c.replaces, c.atLevel
                local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
                r.replacesName = c.replaces and (get(c.replaces)) or r.replacesName
                r.perGold = c.gain / math.max(r.price / 10000, 0.01)
                keep[#keep + 1] = r
            end
        end
    end
    table.sort(keep, function(a, b) return a.perGold > b.perGold end)
    d.rows = keep
end

function GP:AHUpgradeRows()
    local d = self.db.ahUpgrades
    if not d then return {} end
    self:RecheckAHUpgrades()
    local max = self.db.settings.ahUpgradeMax or 0
    local rows = {}
    for _, r in ipairs(d.rows or {}) do
        if max == 0 or r.price <= max then rows[#rows + 1] = r end
    end
    return rows
end

-- Is this bag item gear someone should keep? (protects it from Make room / swaps)
function GP:IsUpgradeItem(itemID)
    for _, r in ipairs(self.upgrades.mine) do if r.id == itemID then return "you" end end
    for _, r in ipairs(self.upgrades.alts) do if r.id == itemID then return r.alt end end
    return nil
end

-- New loot: popup once per item per session --------------------------------------------------

local seenLinks, shownThisSession, baselineDone = {}, {}, false
local queue = {}

local function bagLinks()
    local set = {}
    for _, bag in ipairs(GP.BagIDs()) do
        for slot = 1, GP.NumSlots(bag) do
            local it = GP.SlotInfo(bag, slot)
            if it and it.hyperlink then set[it.hyperlink] = true end
        end
    end
    return set
end

function GP:CheckNewGear()
    local now = bagLinks()
    if not baselineDone then seenLinks, baselineDone = now, true; self:ScanUpgrades(); return end
    local new = {}
    for link in pairs(now) do if not seenLinks[link] then new[link] = true end end
    seenLinks = now
    self:ScanUpgrades()
    for _, r in ipairs(self.upgrades.mine) do
        if new[r.link] and not shownThisSession[r.link] then
            shownThisSession[r.link] = true
            queue[#queue + 1] = { kind = "mine", r = r }
        end
    end
    for _, r in ipairs(self.upgrades.alts) do
        if new[r.link] and not shownThisSession[r.link] then
            shownThisSession[r.link] = true
            queue[#queue + 1] = { kind = "alt", r = r }
        end
    end
    self:ShowNextUpgrade()
end

function GP:ShowNextUpgrade()
    if InCombatLockdown and InCombatLockdown() then return end
    local q = table.remove(queue, 1)
    if q and self.ShowUpgradePopup then self:ShowUpgradePopup(q.kind, q.r) end
end

function GP:Equip(r)
    if InCombatLockdown and InCombatLockdown() then GP.Print("Can't change gear in combat."); return end
    local equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if equip then equip(r.link) end
end

function GP:IgnoreUpgrade(id)
    self.db.ignoredUpgrades[id] = true
    self:ScanUpgrades()
end

-- Stat changes between two items for the popup: { { label, old, new }, ... }
function GP.StatDiff(newLink, oldLink)
    local a, b = GP.ItemStats(newLink) or {}, (oldLink and GP.ItemStats(oldLink)) or {}
    local keys, out = {}, {}
    for k in pairs(a) do keys[k] = true end
    for k in pairs(b) do keys[k] = true end
    for k in pairs(keys) do out[#out + 1] = { GP.STAT_LABEL[k] or k, b[k] or 0, a[k] or 0 } end
    table.sort(out, function(x, y) return math.abs(x[3] - x[2]) > math.abs(y[3] - y[2]) end)
    return out
end

GP:On("BAG_UPDATE_DELAYED", function() C_Timer.After(0.6, function() GP:CheckNewGear() end) end)
GP:On("PLAYER_EQUIPMENT_CHANGED", function() C_Timer.After(0.3, function() GP:ScanUpgrades(); GP:RecheckAHUpgrades(true) end) end)
GP:On("PLAYER_REGEN_ENABLED", function() GP:ShowNextUpgrade() end)
GP:On("PLAYER_LEVEL_UP", function() C_Timer.After(1, function() GP:ScanUpgrades() end) end)
