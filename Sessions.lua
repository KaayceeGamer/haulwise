-- Sessions: pause, instances, and a history of your farm runs.
--
-- Pause stops the clock and the session's totals: what you loot while paused (a mailbox run, a
-- trip to a vendor) still teaches Haulwise drop rates, but stays out of your gold per hour.
-- Entering a dungeon or raid sets your open-world session aside and starts one for the instance;
-- leaving saves that one and picks the open-world session up where it was.
-- A /reload or a short logout carries on the same session; one that's been idle for 30 minutes
-- is saved and a new one starts. Saved sessions show on the Farm tab under Sessions.
local _, GP = ...
local L = GP.L

local KEEP = 300            -- saved sessions kept
local MIN_SECONDS = 3 * 60  -- shorter sessions aren't worth saving
local RESUME_WITHIN = 30 * 60

function GP.SessionSeconds(s)
    s = s or GP.session
    if not s then return 0 end
    return (s.secs or 0) + (s.since and math.max(0, time() - s.since) or 0)
end

function GP.SessionPaused() return GP.session and not GP.session.since end

-- Loot and kills go into the session only while it runs.
function GP:SessionLoot(value, money, items)
    local s = self.session
    if not s or not s.since then return end
    s.value = s.value + (value or 0)
    s.money = s.money + (money or 0)
    s.last = time()
    if items then
        s.items = s.items or {}
        for id, qty in pairs(items) do s.items[id] = (s.items[id] or 0) + qty end
    end
end

function GP:SessionKill(npc, zone)
    local s = self.session
    if not s or not s.since then return end
    s.kills = s.kills + 1
    s.last = time()
    s.mobs = s.mobs or {}
    s.mobs[npc] = (s.mobs[npc] or 0) + 1
    if zone then
        s.zones = s.zones or {}
        s.zones[zone] = (s.zones[zone] or 0) + 1
    end
end

function GP:PauseSession()
    local s = self.session
    if not s or not s.since then return end
    s.secs = GP.SessionSeconds(s)
    s.since = nil
    if self.RefreshUI then self:RefreshUI() end
    if self.RefreshHUD then self:RefreshHUD() end
end

function GP:ResumeSession()
    local s = self.session
    if not s or s.since then return end
    s.since = time()
    if self.RefreshUI then self:RefreshUI() end
    if self.RefreshHUD then self:RefreshHUD() end
end

function GP:ToggleSessionPause()
    if GP.SessionPaused() then self:ResumeSession() else self:PauseSession() end
end

local function top(t, n, by)
    local list = {}
    for k, v in pairs(t or {}) do list[#list + 1] = { k, v, by and by(k, v) or v } end
    table.sort(list, function(a, b) return a[3] > b[3] end)
    local out = {}
    for i = 1, math.min(n, #list) do out[i] = { list[i][1], list[i][2] } end
    return out
end

-- Put a finished session in the history (when it's long enough and earned something).
function GP:SaveSession(s)
    if not s then return false end
    local secs = GP.SessionSeconds(s)
    local earned = (s.value or 0) + (s.sales or 0)
    if secs < MIN_SECONDS or (earned <= 0 and (s.kills or 0) == 0) then return false end
    self.db.sessions = self.db.sessions or {}
    local zone = top(s.zones, 1)[1]
    local rec = {
        t = s.start, secs = math.floor(secs), value = math.floor(s.value or 0), sales = math.floor(s.sales or 0),
        kills = s.kills or 0, char = UnitName and UnitName("player") or "?", zone = zone and zone[1], inst = s.instance,
        mobs = top(s.mobs, 5),
        items = top(s.items, 5, function(id, qty) return qty * (GP:ItemValue(id) or 0) end),
    }
    table.insert(self.db.sessions, 1, rec)
    while #self.db.sessions > KEEP do table.remove(self.db.sessions) end
    if self.ForgetRows then self:ForgetRows() end
    return true
end

-- Save this session and start a new one.
function GP:StartNewSession()
    local saved = self:SaveSession(self.session)
    self.session = GP.NewSession()
    if self.RefreshUI then self:RefreshUI() end
    if self.RefreshHUD then self:RefreshHUD() end
    return saved
end

-- At login: the session from before a /reload or a short logout carries on.
function GP:RestoreSession()
    local old = self.db.currentSession
    self.db.currentSession = nil
    if old and old.start and (time() - (old.left or 0)) < RESUME_WITHIN then
        old.since = old.wasRunning and time() or nil
        old.wasRunning, old.left = nil, nil
        return old
    end
    if old then self:SaveSession(old) end
    return GP.NewSession()
end

GP:On("PLAYER_LOGOUT", function()
    local s = GP.session
    if not s then return end
    -- An instance session is saved; the open-world one set aside is what carries on.
    if GP.sessionAside then
        GP:SaveSession(s)
        s = GP.sessionAside
    end
    local running = s.since ~= nil
    s.secs = GP.SessionSeconds(s)
    s.since = nil
    s.wasRunning, s.left = running, time()
    GP.db.currentSession = s
end)

-- Dungeons and raids get a session of their own.
local function checkInstance()
    if not GP.session or not IsInInstance then return end
    local inside, kind = IsInInstance()
    local dungeon = inside and (kind == "party" or kind == "raid" or kind == "scenario")
    if dungeon and not GP.sessionAside then
        local outside = GP.session
        GP:PauseSession()
        GP.sessionAside = outside
        GP.session = GP.NewSession()
        GP.session.instance = (GetInstanceInfo and GetInstanceInfo()) or L["Dungeon"]
        GP.Print(string.format(L["Your open-world session is set aside while you're in %s. It picks up again when you leave."], GP.session.instance))
    elseif not dungeon and GP.sessionAside then
        GP:SaveSession(GP.session)
        GP.session = GP.sessionAside
        GP.sessionAside = nil
        GP:ResumeSession()
    end
    if GP.RefreshUI then GP:RefreshUI() end
end
GP:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, checkInstance) end)
GP:On("ZONE_CHANGED_NEW_AREA", checkInstance)

-- The Sessions view on the Farm tab: newest first.
function GP:SessionRows()
    local rows = {}
    for i, r in ipairs(self.db.sessions or {}) do
        local earned = (r.value or 0) + (r.sales or 0)
        rows[#rows + 1] = {
            i = i, rec = r, t = r.t or 0, secs = r.secs or 0, earned = earned, kills = r.kills or 0,
            perHour = (r.secs or 0) > 0 and earned / r.secs * 3600 or 0,
            where = r.inst or (r.zone and GP.ZoneName(r.zone)) or "?", char = r.char or "?",
            best = r.mobs and r.mobs[1] and r.mobs[1][1],
        }
    end
    return rows
end

function GP:DeleteSession(i)
    if self.db.sessions and self.db.sessions[i] then table.remove(self.db.sessions, i) end
    if self.ForgetRows then self:ForgetRows() end
end
