-- Haulwise: share drop data with friends as a copy/paste string.
-- Each player's data is stored under their own id, so importing the same friend twice
-- replaces their old numbers instead of counting their kills twice.
local _, GP = ...

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
    return table.concat(out, ";")
end

local function num(s, max)
    local n = tonumber(s)
    if not n or n < 0 or n ~= n or n > (max or 1e9) then error("bad number") end
    return math.floor(n)
end

local function unpackCounts(s)
    local t = {}
    for part in (s or ""):gmatch("[^/]+") do
        local id, k, q = part:match("^(%d+):(%d+):(%d+)$")
        if not id then error("bad item") end
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
    if (head[1] ~= "CF1" and head[1] ~= "CF2") or not head[2] then error("not a Haulwise string") end
    local uid, label, when = head[2], head[3], num(head[4], 4e9)
    local mobs, n = {}, 0
    local sources, vendorBuy, recipeItems = {}, {}, {}
    local function src(key)
        local e = sources[key]
        if not e then e = { trainer = {}, vendor = {} }; sources[key] = e end
        return e
    end
    for i = 2, #records do
        local f = split(records[i], ",")
        local kind = f[1]
        if kind == "T" then
            if #f < 6 then error("record " .. i .. " is cut short") end
            src(f[2]).trainer[f[3]] = { zone = f[4], cost = num(f[5], 1e9), skill = num(f[6], 1000), prof = f[7] }
        elseif kind == "V" then
            if #f < 7 then error("record " .. i .. " is cut short") end
            src(f[2]).vendor[f[3]] = { zone = f[4], price = num(f[5], 1e9), limited = f[6] == "1", item = num(f[7], 1e7) }
        elseif kind == "B" then
            vendorBuy[num(f[2], 1e7)] = num(f[3], 1e9)
        elseif kind == "R" then
            recipeItems[f[2]] = num(f[3], 1e7)
        else
            if #f < 15 then error("record " .. i .. " is cut short") end
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
                  sources = sources, vendorBuy = vendorBuy, recipeItems = recipeItems }
end

-- Returns ok, message.
function GP:ImportString(str)
    local ok, result = pcall(function()
        local uid, src = self:ParseExport(str)
        if uid == self.db.uid then error("that is your own data") end
        if uid == "community" then
            -- A fresher community download than the one bundled with the addon.
            if self.community and (self.community.time or 0) >= (src.time or 0) then
                error("you already have this or newer community data")
            end
            self.db.shared.community = src
            self.community = nil
            return string.format("Community data updated: %d mobs from %d players.", src.n, src.contributors or 0)
        end
        self.db.shared[uid] = src
        return string.format("Imported %d mobs from %s.", src.n, src.label ~= "" and src.label or "a friend")
    end)
    if self.RefreshUI then self:RefreshUI() end
    return ok, ok and result or ("Import failed: " .. tostring(result):gsub("^.-:%d+: ", ""))
end

-- Community data shipped inside the addon (Data.lua, rebuilt weekly from everyone's uploads).
-- Kept in memory only; a newer string pasted with /haul import replaces it.
function GP:LoadBundledCommunity()
    if type(Haulwise_Community) ~= "string" or Haulwise_Community == "" then return end
    local ok, uid, src = pcall(self.ParseExport, self, Haulwise_Community)
    if not ok or uid ~= "community" then return end
    local saved = self.db.shared.community
    if saved and (saved.time or 0) >= (src.time or 0) then return end
    self.db.shared.community = nil
    self.community = src
end

function GP:CommunityInfo()
    return self.db.shared.community or self.community
end

-- Copy/paste window ------------------------------------------------------------------

local box
local function getBox()
    if box then return box end
    box = CreateFrame("Frame", "HaulwiseShareFrame", UIParent, "BackdropTemplate")
    box:SetSize(520, 260)
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
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)
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
    box.status:SetPoint("BOTTOMLEFT", 12, 18)
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
        self.Print(string.format("You have |cffffffff%d kills|r that aren't shared yet. Press |cffffd040Share data|r in the Haulwise window (or type /haul export) and paste it on |cffffffff%s|r. It takes 10 seconds and improves everyone's drop rates. Turn this reminder off in /haul settings.", new, GP.SITE_URL))
    end
end

function GP:ShowExport()
    local b = getBox()
    b.title:SetText("Share your data: press Ctrl+C, then paste it on the Haulwise website")
    self.db.sharedKills = self:OwnKills()
    b.edit:SetText(self:ExportString())
    b.edit:HighlightText()
    b.edit:SetFocus()
    b.status:SetText("Website: |cffffffff" .. GP.SITE_URL .. "|r   " .. "|cff8f8b80Nothing is sent automatically; only what you paste is shared.|r")
    b.action:SetText("Close")
    b.action:SetScript("OnClick", function() b:Hide() end)
    b:Show()
end

-- A ready-to-paste bug report: version, game build, and the last errors Haulwise noted.
function GP:ErrorReport(max)
    local errs = self.db.errors or {}
    if #errs == 0 then return nil end
    local lines = {}
    local build = GetBuildInfo and select(1, GetBuildInfo()) or "?"
    lines[1] = string.format("Haulwise %s, game %s, %d error%s:", GP.VERSION or "?", build, #errs, #errs == 1 and "" or "s")
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
    b.title:SetText(report and "Feedback: Haulwise noted errors. Copy everything below with Ctrl+C"
        or "Feedback, bugs and ideas: copy a link with Ctrl+C")
    b.edit:SetText("Report a bug or suggest an idea (GitHub issues):\n" .. GP.ISSUES_URL ..
        "\n\nOr leave a comment on the Haulwise page on CurseForge.\n\nShare your data and get the newest community data:\n" .. GP.SITE_URL ..
        "\n\nWhen reporting a bug, tell us what you did and what you expected. Haulwise version: " .. (GP.VERSION or "?") .. "." ..
        (report and ("\n\n--- Paste this into your report ---\n" .. report) or "\n\nNo Haulwise errors noted so far."))
    if report then b.edit:HighlightText() end
    b.edit:SetCursorPosition(0)
    b.edit:SetFocus()
    b.status:SetText("")
    b.action:SetText("Close")
    b.action:SetScript("OnClick", function() b:Hide() end)
    b:Show()
end

function GP:ShowImport()
    local b = getBox()
    b.title:SetText("Import: paste a friend's string or the latest community data")
    b.edit:SetText("")
    b.edit:SetFocus()
    b.status:SetText("")
    b.action:SetText("Import")
    b.action:SetScript("OnClick", function()
        local ok, msg = GP:ImportString(b.edit:GetText())
        b.status:SetText((ok and "|cff55ff55" or "|cffff5555") .. msg .. "|r")
    end)
    b:Show()
end
