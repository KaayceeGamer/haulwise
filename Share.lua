-- Haulwise: share drop data with friends as a copy/paste string.
-- Each player's data is stored under their own id, so importing the same friend twice
-- replaces their old numbers instead of counting their kills twice.
local _, GP = ...
local L = GP.L

local function clean(s)
    return (tostring(s or ""):gsub("[,;:/~|\n\r]", " "))
end

-- A text field the server will accept: 1-80 characters, no < >. Records with a field that
-- isn't are left out of the export, so one odd name can't make the whole upload fail.
local function okText(...)
    for i = 1, select("#", ...) do
        local t = clean(select(i, ...)):match("^%s*(.-)%s*$")
        if t == "" or #t > 80 or t:find("[<>]") then return false end
    end
    return true
end

local function packCounts(t)
    local parts = {}
    for id, e in pairs(t or {}) do parts[#parts + 1] = string.format("%d:%d:%d", id, e.k, e.q) end
    return table.concat(parts, "/")
end

local function packZones(t)
    local parts = {}
    for z, n in pairs(t or {}) do parts[#parts + 1] = clean(z) .. ":" .. n end
    return table.concat(parts, "/")
end

function GP:ExportString()
    local build = GetBuildInfo and select(1, GetBuildInfo()) or ""
    local out = { string.format("CF2,%s,%s,%d,%s", self.db.uid, clean(UnitName("player")), time(), clean(build)) }
    for npc, m in pairs(self.db.mobs) do
        if (m.kills or 0) > 0 then
            out[#out + 1] = table.concat({
                npc, okText(m.name) and clean(m.name) or "?", m.minL or 0, m.maxL or 0, m.kills, m.money, m.gathered, m.pp, m.ppMoney,
                m.tIntervals, m.tSeconds, packZones(m.zones), packCounts(m.items), packCounts(m.gather),
                packCounts(m.ppItems),
            }, ",")
        end
    end
    -- What you've seen at trainers and vendors (type T and V), vendor prices for reagents (B)
    -- and which item teaches which recipe (R). Only things you saw yourself.
    for key, e in pairs(self.db.sources or {}) do
        for npc, t in pairs(e.trainer or {}) do
            if okText(key, npc, t.zone, t.prof) then out[#out + 1] = table.concat({ "T", clean(key), clean(npc), clean(t.zone), math.floor(t.cost or 0), t.skill or 0, clean(t.prof) }, ",") end
        end
        for npc, v in pairs(e.vendor or {}) do
            if okText(key, npc, v.zone) then out[#out + 1] = table.concat({ "V", clean(key), clean(npc), clean(v.zone), math.floor(v.price or 0), v.limited and 1 or 0, v.item or 0 }, ",") end
        end
    end
    for id, price in pairs(self.db.vendorBuy or {}) do
        out[#out + 1] = string.format("B,%d,%d", id, math.floor(price + 0.5))
    end
    for key, id in pairs(self.db.recipeItems or {}) do
        if okText(key) then out[#out + 1] = table.concat({ "R", clean(key), id }, ",") end
    end
    -- Recipes your characters know (C): what they make, how many, and from what. Lets everyone's
    -- tooltips say what an item is used for.
    local crafted = {}
    for _, c in pairs(self.db.chars or {}) do
        for _, rec in pairs(c.recipes or {}) do
            if rec.learned and rec.out and not crafted[rec.out] and rec.r and rec.r ~= "" and okText(rec.prof) then
                local parts = {}
                for _, r in ipairs(GP.UnpackReagents(rec.r)) do parts[#parts + 1] = string.format("%d:%d", r[1], r[2]) end
                if #parts > 0 and #parts <= 12 then
                    crafted[rec.out] = true
                    out[#out + 1] = string.format("C,%d,%d,%s,%s", rec.out, math.max(1, math.floor(rec.oq or 1)), clean(rec.prof), table.concat(parts, "/"))
                end
            end
        end
    end
    -- Where trainers and vendors you opened stand (P), so everyone's waypoints get better.
    for id, p in pairs(self.db.places or {}) do
        if okText(p.n) and p.m and p.x and p.y then
            out[#out + 1] = table.concat({ "P", id, clean(p.n), p.k or "V", clean(p.p or ""), p.f or "", p.m,
                string.format("%.2f", p.x), string.format("%.2f", p.y) }, ",")
        end
    end
    -- Prices from your last auction house scan (A), if it's at most 3 days old.
    if self.SharedPriceRecord then
        local ok, rec = pcall(self.SharedPriceRecord, self)
        if ok and rec then out[#out + 1] = rec end
    end
    return table.concat(out, ";")
end

local function num(s, max)
    local n = tonumber(s)
    if not n or n < 0 or n ~= n or n > (max or 1e9) then error(L["bad number"]) end
    return math.floor(n)
end

local function unpackCounts(s)
    local t = {}
    for part in (s or ""):gmatch("[^/]+") do
        local id, k, q = part:match("^(%d+):(%d+):(%d+)$")
        if not id then error(L["bad item"]) end
        t[num(id)] = { k = num(k), q = num(q) }
    end
    return t
end

local function unpackZones(s)
    local t = {}
    for part in (s or ""):gmatch("[^/]+") do
        local z, n = part:match("^(.-):(%d+)$")
        if z then t[z] = num(n) end
    end
    return t
end

local function split(s, sep)
    local out = {}
    for piece in (s .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = piece end
    return out
end

-- Parses an export string. Returns a source table { label, time, build, contributors, mobs }
-- and its uid, or raises an error.
function GP:ParseExport(str)
    str = (str or ""):gsub("%s+$", ""):gsub("^%s+", "")
    local records = split(str, ";")
    local head = split(records[1], ",")
    if (head[1] ~= "CF1" and head[1] ~= "CF2") or not head[2] then error(L["not a Haulwise string"]) end
    local uid, label, when = head[2], head[3], num(head[4], 4e9)
    local mobs, n = {}, 0
    local sources, vendorBuy, recipeItems, places, crafts = {}, {}, {}, {}, {}
    local prices, allPrices, nAll
    local function src(key)
        local e = sources[key]
        if not e then e = { trainer = {}, vendor = {} }; sources[key] = e end
        return e
    end
    for i = 2, #records do
        local f = split(records[i], ",")
        local kind = f[1]
        if kind == "T" then
            if #f < 6 then error(L["record "] .. i .. L[" is cut short"]) end
            src(f[2]).trainer[f[3]] = { zone = f[4], cost = num(f[5], 1e9), skill = num(f[6], 1000), prof = f[7] }
        elseif kind == "V" then
            if #f < 7 then error(L["record "] .. i .. L[" is cut short"]) end
            src(f[2]).vendor[f[3]] = { zone = f[4], price = num(f[5], 1e9), limited = f[6] == "1", item = num(f[7], 1e7) }
        elseif kind == "B" then
            vendorBuy[num(f[2], 1e7)] = num(f[3], 1e9)
        elseif kind == "R" then
            recipeItems[f[2]] = num(f[3], 1e7)
        elseif kind == "P" then
            local x, y = tonumber(f[8]), tonumber(f[9])
            if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                places[num(f[2], 1e7)] = { n = f[3], k = f[4], p = f[5] ~= "" and f[5] or nil, f = f[6], m = num(f[7], 1e5), x = x, y = y }
            end
        elseif kind == "C" then
            -- One odd recipe is skipped, not the whole string.
            pcall(function()
                local out, reagents = num(f[2], 1e7), {}
                for id, n in (f[5] or ""):gmatch("(%d+):(%d+)") do reagents[#reagents + 1] = { num(id, 1e7), num(n, 200) } end
                if out > 0 and #reagents > 0 then
                    crafts[out] = { out = out, qty = math.max(1, num(f[3], 100)), prof = f[4] ~= "" and f[4] or nil, reagents = reagents }
                end
            end)
        elseif kind == "A" then
            prices = GP.ParsePriceRecord and GP.ParsePriceRecord(f) or prices
        elseif kind == "M" then
            if GP.ParseMedianRecord then allPrices, nAll = GP.ParseMedianRecord(f) end
        elseif kind and kind:match("^%u$") then
            -- A record type from a newer Haulwise: skip it.
        else
            if #f < 15 then error(L["record "] .. i .. L[" is cut short"]) end
            local npc = num(f[1], 1e7)
            local m = {
                name = f[2] ~= "" and f[2] or nil,
                minL = num(f[3], 200), maxL = num(f[4], 200), kills = num(f[5], 1e7),
                money = num(f[6], 1e15), gathered = num(f[7], 1e7), pp = num(f[8], 1e7), ppMoney = num(f[9], 1e15),
                tIntervals = num(f[10], 1e7), tSeconds = num(f[11], 1e12),
                zones = unpackZones(f[12]), items = unpackCounts(f[13]),
                gather = unpackCounts(f[14]), ppItems = unpackCounts(f[15]),
            }
            if m.minL == 0 then m.minL = nil end
            if m.maxL == 0 then m.maxL = nil end
            mobs[npc] = m
            n = n + 1
        end
    end
    return uid, { label = label, time = when, build = head[5], contributors = tonumber(head[6]), mobs = mobs, n = n,
                  sources = sources, vendorBuy = vendorBuy, recipeItems = recipeItems, places = places, crafts = crafts,
                  prices = prices, allPrices = allPrices, nAll = nAll }
end

-- Returns ok, message.
function GP:ImportString(str)
    self.recipeRowsCache = nil
    if self.ForgetRows then self:ForgetRows() end
    local ok, result = pcall(function()
        local uid, src = self:ParseExport(str)
        if uid == self.db.uid then error(L["that is your own data"]) end
        -- Prices for one realm from the website: stored apart, they aren't anyone's drop data.
        if uid == "prices" then return self:StoreRealmPrices(src) end
        if self.NormalizeZones then self:NormalizeZones(src.mobs) end
        self.mineInPool = nil
        if uid == "community" then
            -- A fresher community download than the one bundled with the addon.
            if self.community and (self.community.time or 0) >= (src.time or 0) then
                error(L["you already have this or newer community data"])
            end
            self.db.shared.community = src
            self.community = nil
            return string.format(L["Community data updated: %d mobs from %d players."], src.n, src.contributors or 0)
        end
        self.db.shared[uid] = src
        return string.format(L["Imported %d mobs from %s."], src.n, src.label ~= "" and src.label or L["a friend"])
    end)
    if self.RefreshUI then self:RefreshUI() end
    return ok, ok and result or (L["Import failed: "] .. tostring(result):gsub("^.-:%d+: ", ""))
end

-- Community data shipped inside the addon (Data.lua, rebuilt daily from everyone's uploads).
-- Kept in memory only; a newer string pasted with /haul import replaces it.
function GP:LoadBundledCommunity()
    if type(Haulwise_Community) ~= "string" or Haulwise_Community == "" then return end
    local ok, uid, src = pcall(self.ParseExport, self, Haulwise_Community)
    if not ok or uid ~= "community" then return end
    -- The text itself (over a megabyte) isn't needed once parsed: let the game free it.
    Haulwise_Community = nil
    local saved = self.db.shared.community
    if saved and (saved.time or 0) >= (src.time or 0) then return end
    self.db.shared.community = nil
    self.community = src
end

-- Recipes other players shared (community data and friends' imports), by the item they make.
function GP:SharedCrafts()
    local out = {}
    for _, src in pairs(self.db.shared or {}) do
        for id, c in pairs(src.crafts or {}) do out[id] = out[id] or c end
    end
    if self.community then
        for id, c in pairs(self.community.crafts or {}) do out[id] = out[id] or c end
    end
    return out
end

function GP:CommunityInfo()
    return self.db.shared.community or self.community
end

-- Copy/paste window ------------------------------------------------------------------

local box
local function getBox()
    if box then return box end
    box = CreateFrame("Frame", "HaulwiseShareFrame", UIParent, "BackdropTemplate")
    box:SetSize(520, 280)
    box:SetPoint("CENTER")
    box:SetFrameStrata("DIALOG")
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(0.06, 0.06, 0.07, 0.97)
    box:SetBackdropBorderColor(0.55, 0.45, 0.2, 1)
    box:EnableMouse(true)
    box:SetMovable(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving)
    box:SetScript("OnDragStop", box.StopMovingOrSizing)

    box.title = box:CreateFontString(nil, "OVERLAY", "HaulwiseFontGold")
    box.title:SetPoint("TOPLEFT", 12, -10)

    local close = CreateFrame("Button", nil, box, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -32, 66)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(460)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function() box:Hide() end)
    scroll:SetScrollChild(edit)
    box.edit = edit

    box.action = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    box.action:SetSize(110, 24)
    box.action:SetPoint("BOTTOMRIGHT", -12, 12)

    box.status = box:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    box.status:SetPoint("BOTTOMLEFT", 12, 12)
    box.status:SetPoint("RIGHT", box.action, "LEFT", -8, 0)
    box.status:SetJustifyH("LEFT")
    return box
end

function GP:OwnKills()
    local n = 0
    for _, m in pairs(self.db.mobs) do n = n + (m.kills or 0) end
    return n
end

function GP:UnsharedKills()
    return math.max(0, self:OwnKills() - (self.db.sharedKills or 0))
end

-- Sharing is manual: addons can't reach the internet. Every 100 unshared kills, say so once in chat.
function GP:MaybeNudgeShare()
    if not self.db.settings.shareReminder then return end
    local own, new = self:OwnKills(), self:UnsharedKills()
    if new >= 100 and own - (self.db.shareNudgedAt or 0) >= 100 then
        self.db.shareNudgedAt = own
        self.Print(string.format(L["You have |cffffffff%d kills|r that aren't shared yet. Press |cffffd040Share data|r in the Haulwise window (or type /haul export) and paste it on |cffffffff%s|r. It takes 10 seconds and gives everyone better drop rates, prices and NPC spots."], new, GP.SITE_URL)
            .. " " .. L["|cff8f8b80Only game stats go along (kills, loot, prices you've seen with your realm, recipes you know, where NPCs stand), no names. Nothing leaves your PC unless you paste it. Turn this reminder off in /haul settings.|r"])
    end
end

-- At login, once a day: if you have something worth sharing (25+ new kills, or an AH scan from the
-- last 3 days that you haven't shared), say so in one line, with how much the others have shared.
-- Waits 10 seconds so it lands after the login chatter. Off with the share reminder setting.
function GP:LoginShareMessage()
    if not self.db.settings.shareReminder then return nil end
    local today = GP.Day()
    if self.db.loginNudgeDay == today then return nil end
    local new = self:UnsharedKills()
    local lastShare = self.db.exportSnaps and self.db.exportSnaps[1] and self.db.exportSnaps[1].t or 0
    local scan = self.db.priceScanTime
    local prices = scan and time() - scan <= 3 * 86400 and scan > lastShare
    if new < 25 and not prices then return nil end
    self.db.loginNudgeDay = today
    local what
    if new >= 25 and prices then
        what = string.format(L["%s and your latest AH prices aren't shared yet."], GP.Plural(new, "kill", "kills"))
    elseif new >= 25 then
        what = string.format(L["%s aren't shared yet."], GP.Plural(new, "kill", "kills"))
    else
        what = L["Your latest AH prices aren't shared yet."]
    end
    local msg = what .. " " .. string.format(L["Type |cffffd040/haul export|r and paste it on |cffffffff%s|r: better drop rates and prices for everyone."], GP.SITE_URL)
    local com = self:CommunityInfo()
    if com and com.mobs and (com.contributors or 0) > 0 then
        local kills = 0
        for _, m in pairs(com.mobs) do kills = kills + (m.kills or 0) end
        if kills > 0 then
            msg = msg .. " " .. string.format(L["|cff8f8b80So far %s from %s.|r"], GP.Plural(kills, "kill", "kills"), GP.Plural(com.contributors, "player", "players"))
        end
    end
    return msg
end

GP:On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
    if not isLogin or isReload then return end
    C_Timer.After(10, function()
        local ok, msg = pcall(GP.LoginShareMessage, GP)
        if ok and msg then GP.Print(msg) end
    end)
end)

-- What you shared, kept so the community data (which includes your upload once it's pooled)
-- doesn't count your own kills twice. Only the mob records; the last two exports.
function GP:SnapshotExport(str)
    local keep = {}
    for rec in (str .. ";"):gmatch("([^;]*);") do
        if not rec:match("^%u,") then keep[#keep + 1] = rec end
    end
    local snaps = self.db.exportSnaps or {}
    table.insert(snaps, 1, { t = time(), s = table.concat(keep, ";") })
    while #snaps > 2 do table.remove(snaps) end
    self.db.exportSnaps = snaps
    self.mineInPool = nil
end

-- Your share of a community pool, so it can be taken out again: the newest export made before
-- the pool was built, as parsed mobs. Nil if you hadn't shared by then.
function GP:MySharedMobs(poolTime)
    for _, snap in ipairs(self.db.exportSnaps or {}) do
        if snap.t <= (poolTime or 0) then
            local ok, _, src = pcall(self.ParseExport, self, snap.s)
            if not (ok and src) then return nil end
            if self.NormalizeZones then self:NormalizeZones(src.mobs) end
            return src.mobs
        end
    end
end

function GP:ShowExport()
    local b = getBox()
    b.title:SetText(L["Share your data: press Ctrl+C, then paste it on the Haulwise website"])
    self.db.sharedKills = self:OwnKills()
    local export = self:ExportString()
    pcall(self.SnapshotExport, self, export)
    b.edit:SetText(export)
    b.edit:HighlightText()
    b.edit:SetFocus()
    -- What sharing adds: your kills next to what the pool already has from everyone else.
    local mobs, kills = 0, 0
    for _, m in pairs(self.db.mobs) do if (m.kills or 0) > 0 then mobs, kills = mobs + 1, kills + m.kills end end
    local pool, poolKills = self:CommunityInfo(), 0
    for _, m in pairs(pool and self:CommunityMobs(pool) or {}) do poolKills = poolKills + (m.kills or 0) end
    local gain = string.format(L["You bring |cffffffff%s|r on %s."], GP.Plural(kills, "kill"), GP.Plural(mobs, "mob"))
    if pool and poolKills > 0 then
        gain = gain .. " " .. string.format(L["The pool has %s from other players: together everyone's numbers get surer."], GP.Plural(poolKills, "kill"))
    end
    b.status:SetText(gain .. "\n" .. string.format(L["1. Ctrl+C   2. Open |cffffffff%s|r   3. Paste it there. |cff8f8b80Nothing is sent by itself.|r"], GP.SITE_URL))
    b.action:SetText(L["Close"])
    b.action:SetScript("OnClick", function() b:Hide() end)
    b:Show()
end

-- A ready-to-paste bug report: version, game build, and the last errors Haulwise noted.
function GP:ErrorReport(max)
    local errs = self.db.errors or {}
    if #errs == 0 then return nil end
    local lines = {}
    local build = GetBuildInfo and select(1, GetBuildInfo()) or "?"
    lines[1] = string.format("Haulwise %s, game %s, %s:", GP.VERSION or "?", build, GP.Plural(#errs, "error"))
    for i = #errs, math.max(1, #errs - (max or 5) + 1), -1 do
        local e = errs[i]
        lines[#lines + 1] = string.format("[%s] %s%s (%s, v%s): %s", date("%d %b %H:%M", e.t or 0), e.where or "?",
            (e.n or 1) > 1 and (" x" .. e.n) or "", e.where == "lua" and "game" or "event", e.v or "?", (e.msg or ""):gsub("||", "|"))
    end
    return table.concat(lines, "\n")
end

function GP:ShowFeedback()
    local b = getBox()
    local report = self:ErrorReport(5)
    b.title:SetText(report and L["Feedback: Haulwise noted errors. Copy everything below with Ctrl+C"]
        or L["Feedback, bugs and ideas: copy a link with Ctrl+C"])
    b.edit:SetText(L["Report a bug or suggest an idea (GitHub issues):\n"] .. GP.ISSUES_URL ..
        L["\n\nOr leave a comment on the Haulwise page on CurseForge.\n\nShare your data and get the newest community data:\n"] .. GP.SITE_URL ..
        L["\n\nWhen reporting a bug, tell us what you did and what you expected. Haulwise version: "] .. (GP.VERSION or "?") .. "." ..
        (report and (L["\n\n--- Paste this into your report ---\n"] .. report) or L["\n\nNo Haulwise errors noted so far."]))
    if report then b.edit:HighlightText() end
    b.edit:SetCursorPosition(0)
    b.edit:SetFocus()
    b.status:SetText("")
    b.action:SetText(L["Close"])
    b.action:SetScript("OnClick", function() b:Hide() end)
    b:Show()
end

function GP:ShowImport()
    local b = getBox()
    b.title:SetText(L["Import: paste a friend's string or the latest community data"])
    b.edit:SetText("")
    b.edit:SetFocus()
    b.status:SetText("")
    b.action:SetText(L["Import"])
    b.action:SetScript("OnClick", function()
        local ok, msg = GP:ImportString(b.edit:GetText())
        b.status:SetText((ok and "|cff55ff55" or "|cffff5555") .. msg .. "|r")
    end)
    b:Show()
end
