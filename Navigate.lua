-- Haulwise: where is the next trainer, and who sells this recipe? Sets a waypoint (TomTom when
-- installed, otherwise the game's own map pin and arrow).
--
-- Positions come from, in this order:
--   1. your own visits: Haulwise notes where a trainer or vendor stands when you open them
--   2. the Haulwise Data addon (trainers and recipe vendors, from QuestieDB's Forever data)
--   3. QuestieDB itself, when it's installed
-- Your own visits win, so an NPC that moved in WoW Forever is right as soon as you've been there.
local _, GP = ...
local L = GP.L

local arrow, target -- the on-screen arrow and where it points (see "The arrow" below)

local function npcIDFromGUID(guid)
    guid = GP.Safe(guid)
    return guid and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

local function myFaction()
    return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
end

local function playerPos()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    if not x or (x == 0 and y == 0) then return nil end
    return map, x * 100, y * 100
end

-- Your own visits -------------------------------------------------------------------------------

local function remember(kind, prof)
    local id = npcIDFromGUID(UnitGUID and UnitGUID("npc"))
    local map, x, y = playerPos()
    if not (id and map) then return end
    GP.db.places = GP.db.places or {}
    local old = GP.db.places[id] or {}
    GP.db.places[id] = { n = GP.Safe(UnitName("npc")) or old.n, k = kind, p = prof or old.p, f = myFaction(),
                         m = map, x = math.floor(x * 100 + 0.5) / 100, y = math.floor(y * 100 + 0.5) / 100, t = time() }
end

local function trainerProfession()
    if not (GetNumTrainerServices and GetTrainerServiceSkillReq) then return nil end
    local count = {}
    for i = 1, GetNumTrainerServices() do
        local skill = GetTrainerServiceSkillReq(i)
        local p = skill and skill ~= "" and GP.ProfKey(skill)
        if p and GP.RECIPE_SUBCLASS[p] then count[p] = (count[p] or 0) + 1 end
    end
    local best, n = nil, 0
    for p, c in pairs(count) do if c > n then best, n = p, c end end
    return best
end

-- Talking to the NPC the arrow points at: you've arrived.
local function reached()
    if not target then return end
    local id = npcIDFromGUID(UnitGUID and UnitGUID("npc"))
    local name = GP.Safe(UnitName("npc"))
    if (target.npc and id == target.npc) or (name and name == target.name) then
        GP.Print(string.format(L["You've arrived: %s."], target.title))
        if target.tomtom and GP.tomtomUid and TomTom and TomTom.RemoveWaypoint then
            pcall(TomTom.RemoveWaypoint, TomTom, GP.tomtomUid)
            GP.tomtomUid = nil
        end
        target = nil
        if arrow then arrow:Hide() end
    end
end

GP:On("TRAINER_SHOW", function() reached(); C_Timer.After(0.2, function() remember("T", trainerProfession()) end) end)
GP:On("MERCHANT_SHOW", function() reached(); remember("V") end)
GP:On("GOSSIP_SHOW", reached)

-- Where an NPC stands --------------------------------------------------------------------------

local areaToUiMap
local function questieSpawn(id)
    if not (NpcDB and NpcDB.spawns and LibQuestieDB and LibQuestieDB.Support) then return nil end
    local ok, spawns = pcall(NpcDB.spawns, id)
    if not ok or type(spawns) ~= "table" then return nil end
    if not areaToUiMap then
        local zdb = LibQuestieDB.Support.Get("ZoneDB")
        local src = zdb and zdb.private and zdb.private.areaIdToUiMapId
        local fn = type(src) == "string" and loadstring(src)
        areaToUiMap = (fn and fn()) or {}
    end
    for area, pts in pairs(spawns) do
        local map = areaToUiMap[area]
        local p = pts and pts[1]
        if map and map > 0 and p and p[1] and p[1] >= 0 then return map, p[1], p[2] end
    end
end

-- What other players saw (community data and friends' imports).
local function sharedPlace(id)
    for _, src in ipairs(GP:SharedSources()) do
        local p = src.places and src.places[id]
        if p then return p end
    end
end

-- Returns { id, name, sub, faction, map, x, y, from } or nil.
function GP:NpcPlace(id)
    local own = (self.db.places and self.db.places[id]) or sharedPlace(id)
    local data = HaulwiseData and HaulwiseData.npcs and HaulwiseData.npcs[id]
    if own then
        return { id = id, name = own.n or (data and data[1]) or "?", sub = data and data[2], faction = own.f,
                 map = own.m, x = own.x, y = own.y, from = (self.db.places and self.db.places[id]) and "you" or "players" }
    end
    if data and data[4] then
        local p = data[4]
        return { id = id, name = data[1], sub = data[2], faction = data[3], map = p[1], x = p[2], y = p[3], from = "data" }
    end
    local map, x, y = questieSpawn(id)
    if map then
        local name = NpcDB.name and select(2, pcall(NpcDB.name, id))
        local fac = NpcDB.friendlyToFaction and select(2, pcall(NpcDB.friendlyToFaction, id))
        local sub = NpcDB.subName and select(2, pcall(NpcDB.subName, id))
        return { id = id, name = type(name) == "string" and name or "?", sub = type(sub) == "string" and sub or nil,
                 faction = type(fac) == "string" and fac or nil, map = map, x = x, y = y, from = "questie" }
    end
end

function GP.MapName(map)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and info.name or ("map " .. tostring(map))
end

-- Straight-line distance in world units, or a large number on another continent.
local function distance(place, pmap, px, py)
    if not (pmap and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
        return place.map == pmap and 0 or 1e9
    end
    local ok1, c1, w1 = pcall(C_Map.GetWorldPosFromMapPos, pmap, CreateVector2D(px / 100, py / 100))
    local ok2, c2, w2 = pcall(C_Map.GetWorldPosFromMapPos, place.map, CreateVector2D(place.x / 100, place.y / 100))
    if not (ok1 and ok2 and c1 and c2 and w1 and w2) then return place.map == pmap and 0 or 1e9 end
    if c1 ~= c2 then return 1e8 end
    local dx, dy = w1.x - w2.x, w1.y - w2.y
    return math.sqrt(dx * dx + dy * dy)
end

-- The nearest of these NPCs that's friendly to you.
function GP:NearestPlace(ids, accept)
    local me = myFaction()
    local pmap, px, py = playerPos()
    local best, bestD
    for _, id in ipairs(ids) do
        local p = self:NpcPlace(id)
        if p and (not p.faction or p.faction == "" or p.faction:find(me)) and (not accept or accept(p)) then
            local d = distance(p, pmap, px, py)
            if not bestD or d < bestD then best, bestD = p, d end
        end
    end
    return best
end

-- The arrow ---------------------------------------------------------------------------------------
-- WoW Forever's own waypoint is only a pin on the map (the turning arrow is a retail feature), so
-- Haulwise draws its own: it points at the target, says how far, and hides when you get there.
-- Drag it to move it; right-click clears it.
local NEAR = 12 -- yards: "you're there", but the arrow stays until you talk to them

-- World position: x grows to the north, y to the west (the game's world axes).
local function worldPos(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, cont, w = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
    if not ok or not w then return nil end
    local wx, wy
    if w.GetXY then wx, wy = w:GetXY() else wx, wy = w.x, w.y end
    return cont, wx, wy
end

local function clearArrow()
    target = nil
    if arrow then arrow:Hide() end
end
GP.ClearArrow = clearArrow

local since = 0
local function update(self, elapsed)
    since = since + elapsed
    if since < 0.05 then return end
    since = 0
    if not target then self:Hide(); return end
    local pmap, px, py = playerPos()
    local c1, x1, y1
    if pmap then c1, x1, y1 = worldPos(pmap, px, py) end
    if not (c1 and target.cont and c1 == target.cont) then
        self.icon:Hide()
        self.dist:SetText(pmap and L["another continent"] or "")
        return
    end
    -- Which way is east and south in world units? Measured on your own map (its right edge is
    -- east, its bottom edge south), so the arrow doesn't depend on how the game orders its axes.
    local _, ex, ey = worldPos(pmap, 100, 0)
    local _, sx, sy = worldPos(pmap, 0, 100)
    local _, ox, oy = worldPos(pmap, 0, 0)
    local dx, dy = target.wx - x1, target.wy - y1
    local yards = math.sqrt(dx * dx + dy * dy)
    local north, west = dx, dy
    if ex and sx and ox then
        local eX, eY, sX, sY = ex - ox, ey - oy, sx - ox, sy - oy
        local eL, sL = math.sqrt(eX * eX + eY * eY), math.sqrt(sX * sX + sY * sY)
        if eL > 0 and sL > 0 then
            west = -(dx * eX + dy * eY) / eL
            north = -(dx * sX + dy * sY) / sL
        end
    end
    -- Positions can be a few yards off, so close by the arrow keeps pointing and says so.
    -- It goes away when you talk to them (or right-click it).
    local facing = GetPlayerFacing and GetPlayerFacing()
    if facing then
        local atan2 = math.atan2 or atan2
        self.icon:SetRotation(atan2(west, north) - facing)
        self.icon:Show()
    else
        self.icon:Hide()
    end
    local atan2 = math.atan2 or atan2
    -- Compass direction, clockwise from north.
    local deg = (-math.deg(atan2(west, north))) % 360
    local DIRS = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
    local dir = DIRS[math.floor((deg + 22.5) / 45) % 8 + 1]
    if yards <= NEAR then
        self.dist:SetText("|cff5fd35f" .. string.format(L["%d yd: you're there, look around"], yards) .. "|r")
    else
        self.dist:SetText(string.format(L["%d yd"], yards) .. "  ·  " .. L[dir])
    end
    self.where:SetText(string.format(L["%s %.1f, %.1f  (you %.1f, %.1f)"], target.zone, target.x, target.y, px, py))
end

local function buildArrow()
    arrow = CreateFrame("Button", "HaulwiseArrow", UIParent)
    arrow:SetSize(120, 92)
    arrow:SetFrameStrata("MEDIUM")
    arrow:SetMovable(true)
    arrow:SetClampedToScreen(true)
    arrow:RegisterForDrag("LeftButton")
    arrow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    arrow:SetScript("OnDragStart", function(self) self:StartMoving() end)
    arrow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        GP.db.positions.HaulwiseArrow = { p, rp, x, y }
    end)
    arrow:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then clearArrow(); return end
        -- Left-click: the world map, where the game's pin marks the spot.
        if target and target.map then
            if OpenWorldMap then pcall(OpenWorldMap, target.map)
            elseif ToggleWorldMap then pcall(ToggleWorldMap) end
        end
    end)
    arrow:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if target then
            GameTooltip:AddLine(target.title, 1, 0.82, 0.25)
            GameTooltip:AddLine(string.format("%s  %.1f, %.1f", target.zone, target.x, target.y), 1, 1, 1)
            if target.why then GameTooltip:AddLine(target.why, 0.8, 0.8, 0.8, true) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["The arrow points in a straight line, through walls and floors. Indoors, look for a door or stairs; the coordinates show when you're right below or above."], 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Click: show on the world map"], 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L["Drag to move. Right-click to clear."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
    arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
    arrow.icon:SetSize(52, 52)
    arrow.icon:SetPoint("TOP", 0, 0)
    arrow.icon:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow.name = arrow:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGold")
    arrow.name:SetPoint("TOP", arrow.icon, "BOTTOM", 0, 2)
    arrow.name:SetWidth(220)
    arrow.dist = arrow:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmall")
    arrow.dist:SetPoint("TOP", arrow.name, "BOTTOM", 0, -2)
    arrow.where = arrow:CreateFontString(nil, "OVERLAY", "HaulwiseFontSmallGrey")
    arrow.where:SetPoint("TOP", arrow.dist, "BOTTOM", 0, -2)
    arrow:SetScript("OnUpdate", update)
    local pos = GP.db.positions.HaulwiseArrow
    arrow:ClearAllPoints()
    if pos then arrow:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else arrow:SetPoint("TOP", UIParent, "TOP", 0, -140) end
end

function GP:ShowArrow(place, title, why)
    local cont, wx, wy = worldPos(place.map, place.x, place.y)
    if not cont then return false end
    if not arrow then buildArrow() end
    target = { cont = cont, wx = wx, wy = wy, title = title, why = why, map = place.map, x = place.x, y = place.y,
               npc = place.id, name = place.name,
               zone = GP.MapName(place.map) }
    arrow.name:SetText(title)
    arrow:Show()
    return true
end

-- Waypoints --------------------------------------------------------------------------------------

function GP:Waypoint(place, why)
    local title = place.name .. (place.sub and place.sub ~= "" and (" <" .. place.sub .. ">") or "")
    local tomtom = _G.TomTom
    if tomtom and tomtom.AddWaypoint then
        -- One Haulwise waypoint at a time, and TomTom mustn't clear it 10 yards out (positions can be
        -- a few yards off): it goes when you talk to the NPC, like Haulwise's own arrow.
        if GP.tomtomUid and tomtom.RemoveWaypoint then pcall(tomtom.RemoveWaypoint, tomtom, GP.tomtomUid) end
        local ok, uid = pcall(tomtom.AddWaypoint, tomtom, place.map, place.x / 100, place.y / 100,
            { title = title, from = "Haulwise", persistent = false, cleardistance = 0, arrivaldistance = 5 })
        GP.tomtomUid = ok and uid or nil
        target = { npc = place.id, name = place.name, title = title, tomtom = true }
        if arrow then arrow:Hide() end
    else
        -- The game's pin on the map, plus Haulwise's own arrow on screen.
        if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
            local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(place.map, place.x / 100, place.y / 100))
            if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
        end
        self:ShowArrow(place, title, why)
    end
    GP.Print(string.format(L["Waypoint: %s, %s (%.1f, %.1f)%s"], title, GP.MapName(place.map), place.x, place.y, why and ("  " .. why) or ""))
    return true
end

-- Trainers --------------------------------------------------------------------------------------

-- What a trainer can teach up to, from its title: Journeyman 150, Expert 225, Artisan 300.
-- Masters teach a specialization; untitled ones ("Cooking Trainer") are taken as Expert.
local function tierOf(sub)
    local s = (sub or ""):lower()
    if s:find("master") then return 0 end
    if s:find("artisan") then return 300 end
    if s:find("expert") then return 225 end
    if s:find("journeyman") then return 150 end
    return 225
end
GP.TrainerTier = tierOf

function GP:TrainersFor(prof)
    local ids, seen = {}, {}
    for id, p in pairs(self.db.places or {}) do
        if p.k == "T" and p.p == prof then ids[#ids + 1] = id; seen[id] = true end
    end
    for _, src in ipairs(self:SharedSources()) do
        for id, p in pairs(src.places or {}) do
            if p.k == "T" and p.p == prof and not seen[id] then ids[#ids + 1] = id; seen[id] = true end
        end
    end
    for _, id in ipairs(HaulwiseData and HaulwiseData.trainers and HaulwiseData.trainers[prof] or {}) do
        if not seen[id] then ids[#ids + 1] = id end
    end
    return ids
end

-- The nearest trainer that can teach your next rank (or any, if none of those is known).
function GP:FindTrainer(prof)
    if not prof then
        -- The profession that needs training most: at its cap, else the first one.
        for name, p in pairs(self:MyProfessions()) do
            if GP.RECIPE_SUBCLASS[name] and p.rank and p.max and p.rank >= p.max then prof = name; break end
        end
        if not prof then for name in pairs(self:MyProfessions()) do if GP.RECIPE_SUBCLASS[name] then prof = name; break end end end
    end
    if not prof then GP.Print(L["Learn a profession first."]); return false end
    -- At your cap (e.g. 150/150) you need the next rank: Expert. Below it (131/225) any trainer
    -- that teaches up to your cap will do, for the recipes in between.
    local mine = self:MyProfessions()[prof]
    local rank, max = mine and mine.rank or 0, mine and mine.max or 0
    local nextRank = (max < 150 and 150) or (max < 225 and 225) or 300
    local need = (rank >= max) and nextRank or math.max(150, math.min(max, 300))
    local ids = self:TrainersFor(prof)
    local place = self:NearestPlace(ids, function(p) return tierOf(p.sub) >= need end)
        or self:NearestPlace(ids, function(p) return tierOf(p.sub) > 0 end)
    if not place then
        GP.Print(string.format(L["No %s trainer known yet. Install Haulwise Data, or open one once and Haulwise remembers it."], L[prof]))
        return false
    end
    return self:Waypoint(place, string.format(L["(%s trainer)"], L[prof]))
end

-- Recipe vendors ---------------------------------------------------------------------------------

function GP:RecipeVendorIDs(itemID)
    local ids, seen = {}, {}
    local function add(id) if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    for _, id in ipairs(HaulwiseData and HaulwiseData.recipeVendors and HaulwiseData.recipeVendors[itemID] or {}) do add(id) end
    if ItemDB and ItemDB.vendors then
        local ok, vs = pcall(ItemDB.vendors, itemID)
        if ok and type(vs) == "table" then for _, id in ipairs(vs) do add(id) end end
    end
    return ids
end

-- Vendors you've seen selling it (by name), matched to the places you've been.
local function ownVendorIDs(recipeName)
    local key = GP.RecipeKey(recipeName or "")
    local e = key and GP.db.sources[key]
    if not (e and e.vendor and GP.db.places) then return {} end
    local ids = {}
    for npcName in pairs(e.vendor) do
        for id, p in pairs(GP.db.places) do if p.k == "V" and p.n == npcName then ids[#ids + 1] = id end end
    end
    return ids
end

-- Where to go for a recipe row: a vendor that sells it, else a trainer of its profession.
function GP:GoToRecipe(r)
    local ids = ownVendorIDs(r.name)
    for _, id in ipairs(r.itemID and self:RecipeVendorIDs(r.itemID) or {}) do ids[#ids + 1] = id end
    local place = #ids > 0 and self:NearestPlace(ids)
    if place then return self:Waypoint(place, string.format(L["(sells %s)"], r.name or "?")) end
    for _, s in ipairs(r.sources or {}) do
        if s.kind == "Trainer" then return self:FindTrainer(r.prof) end
    end
    if r.src and r.src:lower():find("trainer") then return self:FindTrainer(r.prof) end
    if r.wikiTrainer then return self:FindTrainer(r.prof) end
    return false
end

-- For tooltips: where a click takes you, or nil.
function GP:RecipeDestination(r)
    local ids = ownVendorIDs(r.name)
    for _, id in ipairs(r.itemID and self:RecipeVendorIDs(r.itemID) or {}) do ids[#ids + 1] = id end
    local place = #ids > 0 and self:NearestPlace(ids)
    if place then return place end
end
