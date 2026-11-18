-- Haulwise: core, saved data, helpers and slash commands.
local ADDON, GP = ...
Haulwise = GP

GP.VERSION = "0.6.3"
GP.SITE_URL = "kaayceegamer.github.io/haulwise"
GP.ISSUES_URL = "github.com/KaayceeGamer/haulwise/issues"

-- Translations: GP.L["English text"] gives the text in the game's language, or the English text
-- itself when there is no translation. Locales/*.lua fill GP.LOCALE_STRINGS for their language.
GP.LOCALE_STRINGS = {}
GP.L = setmetatable({}, { __index = function(_, k) return GP.LOCALE_STRINGS[k] or k end })

local DEFAULTS = {
    version = 1,
    mobs = {},          -- [npcID] = mob record (see Tracker.lua)
    prices = {},        -- [itemID] = { p = unit price, q = listed qty, t = time }
    priceScanTime = 0,
    history = {},       -- [itemID] = "day:price:qty,..." (28 days)
    vendorBuy = {},     -- [itemID] = what a vendor sells one unit for
    chars = {},         -- ["Name-Realm"] = { profs, recipes, class, level, bags, bank, mail, equipped, ... }
    keep = {},          -- [itemID] = true: never offer these for deletion
    ignoredUpgrades = {}, -- [itemID] = true
    positions = {},     -- [frameName] = { point, relPoint, x, y }
    sizes = {},         -- [frameName] = { width, height }
    sources = {},       -- [recipe name] = { trainer = { [npc] = {...} }, vendor = { [npc] = {...} } }
    recipeItems = {},   -- [recipe name] = itemID of the pattern/recipe item
    shared = {},        -- [sourceId] = { label, time, mobs }
    names = {},
    recipeSkill = {},   -- [recipe itemID] = skill it needs, read from its tooltip once
    errors = {},        -- the last few Haulwise errors, for /haul feedback         -- [itemID] = name from AH scans, for items the game hasn't loaded yet
    sharedKills = 0,    -- your kill total the last time you opened Share
    shareNudgedAt = 0,  -- kill total at the last share reminder
    settings = {
        defaultKph = 40,        -- kills/hour when we have not timed a mob yet
        trackInGroup = false,   -- group loot skews drop rates, so solo only by default
        useShared = true,       -- community data + friends' imports
        levelWindow = true,     -- only show mobs you can farm efficiently
        sortBy = "safe",        -- "safe" | "est"
        includeGather = true,   -- skinning / mining / herbalism off corpses
        includePickpocket = true,
        dealsGear = false,      -- gear has random stats per listing, so it's off for deals
        minProfit = 2000,       -- 20 silver: smallest deal worth showing
        valueAsCrafted = false, -- value drops at what they're worth after you craft them
        tab = "farm",
        useDisenchant = true,   -- value items by disenchanting when you or an alt can
        protectReagents = true, -- never offer reagents your professions use
        swapPopups = true,      -- bags full while looting: offer a swap
        makeRoomPopup = true,   -- "Inventory is full" elsewhere: offer Make room
        upgradeAdvisor = true,
        usePawn = true,         -- use Pawn's stat weights when Pawn is installed
        upgradePopups = true,
        sendToAltsAtMailbox = true,
        shareReminder = true,
        ahUpgradeMax = 0,
        sellHelper = true,
        tooltipDisenchant = true,
        recipesShowAll = false,   -- Recipes tab: also show recipes far above your skill -- item tooltips: what it disenchants into, and what yours gave      -- price panel next to the AH sell frame
        matsToCrafters = true,  -- at a mailbox, offer to send crafting mats to the alt who uses them       -- Gear → On the AH: hide listings above this price (0 = any)
        views = {},             -- [tab] = alternative view ("ah", "skill", "zones")   -- nudge in chat every 100 kills that aren't shared yet
        hudShown = true,
        minimap = true,         -- the minimap button
        hudLocked = false,
        winShown = false,
        winScale = 1,
        hudScale = 1,
        font = 1,           -- index into GP.FONTS
        fontSize = 12,
        opacity = 0.96,
    },
}

local function fill(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            fill(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- Event dispatch -------------------------------------------------------------
local frame = CreateFrame("Frame")
GP.frame = frame
local handlers = {}

function GP:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        -- pcall: an event this client doesn't have shouldn't break the addon.
        pcall(frame.RegisterEvent, frame, event)
    end
    table.insert(handlers[event], fn)
end

-- Errors ------------------------------------------------------------------------
-- The last few Haulwise errors are kept (with the version and when), so /haul feedback can show
-- them ready to copy into a bug report. Nothing leaves your PC unless you paste it somewhere.
local MAX_ERRORS = 10
function GP.ReportError(where, err)
    local db = GP.db
    if not db then return end
    db.errors = db.errors or {}
    local msg = tostring(err or "?"):gsub("|", "||"):sub(1, 600)
    local last = db.errors[#db.errors]
    if last and last.msg == msg then
        last.n, last.t = (last.n or 1) + 1, time()
        return
    end
    db.errors[#db.errors + 1] = { t = time(), v = GP.VERSION, where = where, msg = msg, n = 1 }
    while #db.errors > MAX_ERRORS do table.remove(db.errors, 1) end
    if not GP.errorNoted and GP.Print then
        GP.errorNoted = true -- once per session
        GP.Print("Something went wrong inside Haulwise. |cffffd040/haul feedback|r shows the error, ready to paste into a bug report.")
    end
    if GP.debug then print("|cffff5555Haulwise error|r", where, msg) end
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then GP.ReportError(event, err) end
    end
end)

-- Errors outside event handlers (timers, clicks) reach the game's error handler. Note the ones
-- from Haulwise's own files, then pass every error on unchanged (BugSack and the like still work).
do
    local get, set = geterrorhandler, seterrorhandler
    if get and set then
        local previous = get()
        pcall(set, function(msg, ...)
            local text = tostring(msg)
            if text:find("AddOns[/\\]Haulwise[/\\]") or text:find("Interface/AddOns/Haulwise/") then
                pcall(GP.ReportError, "lua", text)
            end
            if previous then return previous(msg, ...) end
        end)
    end
end

-- Helpers --------------------------------------------------------------------

-- Midnight-engine clients can hand addons "secret" values in combat; never do math on those.
local issecret = issecretvalue or function() return false end
function GP.Safe(v)
    if v == nil or issecret(v) then return nil end
    return v
end

function GP.NpcFromGUID(guid)
    guid = GP.Safe(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, npc = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(npc)
end

function GP.Money(copper, short)
    copper = math.floor((copper or 0) + 0.5)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local G, S, C = "|cffffd700g|r", "|cffc7c7cfs|r", "|cffeda55fc|r"
    if g > 0 then
        if short then return string.format("%d%s %02d%s", g, G, s, S) end
        return string.format("%d%s %02d%s %02d%s", g, G, s, S, c, C)
    elseif s > 0 then
        return string.format("%d%s %02d%s", s, S, c, C)
    end
    return string.format("%d%s", c, C)
end

-- 95% Wilson score interval for k successes out of n trials.
function GP.Wilson(k, n)
    if not n or n <= 0 then return 0, 1 end
    local z = 1.96
    local p = k / n
    local d = 1 + z * z / n
    local centre = (p + z * z / (2 * n)) / d
    local half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return math.max(0, centre - half), math.min(1, centre + half)
end

function GP.Print(...)
    print("|cffffd700Haulwise|r", ...)
end

-- Init -----------------------------------------------------------------------
GP:On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    HaulwiseDB = HaulwiseDB or {}
    fill(HaulwiseDB, DEFAULTS)
    if not HaulwiseDB.uid or #HaulwiseDB.uid < 16 then
        -- Random, anonymous id: lets a re-upload replace your earlier one instead of adding to it.
        local parts = {}
        for i = 1, 4 do parts[i] = string.format("%04x", math.random(0, 0xffff)) end
        HaulwiseDB.uid = table.concat(parts)
    end
    GP.db = HaulwiseDB
    GP:LoadBundledCommunity()
    GP.session = { start = time(), value = 0, money = 0, kills = 0 }
    if GP.ApplyFonts then GP.ApplyFonts() end
    if GP.OnLoaded then GP:OnLoaded() end
end)

-- Slash commands -------------------------------------------------------------
SLASH_HAULWISE1 = "/haulwise"
SLASH_HAULWISE2 = "/haul"
SlashCmdList.HAULWISE = function(msg)
    local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
    local s = GP.db.settings
    if cmd == "" then
        GP:ToggleUI()
    elseif cmd == "kph" and tonumber(arg) then
        s.defaultKph = math.max(1, math.min(600, tonumber(arg)))
        GP.Print("Default kills/hour set to " .. s.defaultKph)
    elseif cmd == "group" then
        s.trackInGroup = (arg == "on")
        GP.Print("Recording in groups: " .. (s.trackInGroup and "on" or "off"))
    elseif cmd == "session" then
        GP.session = { start = time(), value = 0, money = 0, kills = 0 }
        GP.Print("Session reset.")
    elseif cmd == "feedback" or cmd == "bug" then
        GP:ShowFeedback()
    elseif cmd == "guide" or cmd == "help" then
        GP:ToggleGuide()
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        GP:ToggleSettings()
    elseif cmd == "hud" then
        GP:ToggleHUD()
    elseif cmd == "minimap" then
        s.minimap = not (s.minimap ~= false)
        GP:UpdateMinimapButton()
        GP.Print(s.minimap and GP.L["Minimap button shown."] or GP.L["Minimap button hidden. /haul minimap brings it back."])
    elseif cmd == "room" then
        GP:ShowMakeRoom()
    elseif cmd == "bags" or cmd == "gear" or cmd == "holdings" then
        s.tab = cmd
        GP:ShowUI()
    elseif cmd == "scan" then
        GP:ScanUpgrades()
        GP.Print(string.format("%d upgrades for you, %d for alts.", #GP.upgrades.mine, #GP.upgrades.alts))
    elseif (cmd == "scale" or cmd == "hudscale") and tonumber(arg) then
        local key = cmd == "scale" and "winScale" or "hudScale"
        s[key] = math.max(0.6, math.min(1.6, tonumber(arg)))
        GP.Print(string.format("%s scale %.2f. /reload or reopen it to apply.", cmd == "scale" and "Window" or "HUD", s[key]))
    elseif cmd == "reset" then
        s.winScale, s.hudScale = 1, 1
        GP.db.positions = {}
        GP.db.sizes = {}
        GP.Print("Window positions reset. /reload to apply.")
    elseif cmd == "export" then
        GP:ShowExport()
    elseif cmd == "import" then
        GP:ShowImport()
    elseif cmd == "debug" then
        GP.debug = not GP.debug
        GP.Print("Debug " .. (GP.debug and "on" or "off"))
    elseif cmd == "wipe" and arg == "yes" then
        GP.db.mobs = {}
        GP.db.shared = {}
        GP.Print("All drop data deleted.")
    else
        GP.Print("/haul  open window   ·   /haul hud  show/hide the HUD   ·   /haul minimap  show/hide the minimap button")
        GP.Print("/haul room  make room   ·   /haul bags | gear | holdings  open that tab")
        GP.Print("/haul scan  check bags for gear upgrades   ·   /haul reset  window positions and sizes")
        GP.Print("/haul settings  font, size, opacity and options. Resize: drag the corner grip. Scale: Ctrl + mouse wheel over a window, the - / + buttons, or /haul scale 1.2 and /haul hudscale 0.9")
        GP.Print("/haul kph <n>  kills/hour to assume for mobs you have not timed")
        GP.Print("/haul group on|off  also record while grouped")
        GP.Print("/haul session  reset the session counter")
        GP.Print("/haul export | import  share data with friends")
        GP.Print("/haul feedback  report a bug or suggest an idea")
        GP.Print("/haul wipe yes  delete all drop data")
    end
    if GP.RefreshUI then GP:RefreshUI() end
end

function Haulwise_OnCompartmentClick()
    GP:ToggleUI()
end
