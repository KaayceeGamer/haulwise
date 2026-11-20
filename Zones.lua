-- Haulwise: zones by number, not by name. A German client calls Stranglethorn Vale
-- "Schlingendorntal", so names split the same zone in the shared data. Kills are now recorded
-- under the zone's map number ("#1434"), and every name is shown in your own language.
-- Older data recorded under a name is moved over to the number when your client knows that
-- name; names from other languages stay until their owner shares again with this version.
local _, GP = ...

local ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
local DUNGEON = (Enum and Enum.UIMapType and Enum.UIMapType.Dungeon) or 4
local SCAN_TO = 3000

local function mapInfo(id)
    if not (C_Map and C_Map.GetMapInfo and id) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, id)
    return ok and info or nil
end

-- The map number of the zone you're in: the zone (or dungeon) map, not a city district or a
-- cave map inside it. Nil when the game can't say.
function GP.ZoneMapID()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    id = ok and GP.Safe(id) or nil
    for _ = 1, 6 do
        local info = mapInfo(id)
        if not info then return nil end
        if info.mapType == ZONE or info.mapType == DUNGEON then return id end
        if (info.mapType or 0) < ZONE then return nil end
        id = info.parentMapID
    end
end

-- The key kills are recorded under: "#1434", or the zone's name if there's no map number.
function GP.ZoneKey()
    local id = GP.ZoneMapID()
    local name = GP.Safe(GetRealZoneText and GetRealZoneText())
    if id then
        if name and name ~= "" and GP.db then
            GP.db.zoneIds = GP.db.zoneIds or {}
            GP.db.zoneIds[name] = id
        end
        return "#" .. id
    end
    return (name and name ~= "") and name or "?"
end

local names = {}
-- A zone key as a name in your language.
function GP.ZoneName(key)
    if type(key) ~= "string" then return "?" end
    local id = tonumber(key:match("^#(%d+)$"))
    if not id then return key end
    local n = names[id]
    if not n then
        -- Only names that were found are cached: the map data may just not be loaded yet.
        local info = mapInfo(id)
        n = info and info.name
        if n then names[id] = n end
    end
    return n or key
end

-- Zone names your client knows, to their map numbers: the zones you've been in first, then
-- every zone map whose name is unique.
local index
local function zoneIndex()
    if index then return index end
    index = {}
    local dupes = {}
    for id = 1, SCAN_TO do
        local info = mapInfo(id)
        if info and info.name and info.name ~= "" and (info.mapType == ZONE or info.mapType == DUNGEON) then
            if index[info.name] and index[info.name] ~= id then dupes[info.name] = true else index[info.name] = id end
        end
    end
    for name in pairs(dupes) do index[name] = nil end
    for name, id in pairs(GP.db and GP.db.zoneIds or {}) do index[name] = id end
    return index
end

-- Moves kills recorded under a zone name to its map number, in place. Returns how many moved.
function GP:NormalizeZones(mobs)
    if not (C_Map and C_Map.GetMapInfo) then return 0 end
    local idx, moved = zoneIndex(), 0
    for _, m in pairs(mobs or {}) do
        local z = m.zones
        if z then
            local move = {}
            for name in pairs(z) do
                if type(name) == "string" and not name:find("^#") and idx[name] then move[#move + 1] = name end
            end
            for _, name in ipairs(move) do
                local key = "#" .. idx[name]
                z[key] = (z[key] or 0) + z[name]
                z[name] = nil
                moved = moved + 1
            end
        end
    end
    return moved
end

-- Everything Haulwise holds: your kills, friends' imports and the community data.
function GP:NormalizeAllZones()
    index = nil
    self:NormalizeZones(self.db.mobs)
    for _, src in pairs(self.db.shared or {}) do self:NormalizeZones(src.mobs) end
    if self.community then self:NormalizeZones(self.community.mobs) end
    self.mineInPool = nil
end

GP:On("PLAYER_ENTERING_WORLD", function()
    if GP.zonesNormalized then return end
    GP.zonesNormalized = true
    GP:NormalizeAllZones()
end)
