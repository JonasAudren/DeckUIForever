local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- DeckUIForever Map: a square minimap in DeckUIForever's style and a smaller world map.
-------------------------------------------------------------------
-- minimap.lua and worldmap.lua each register an Init; this file holds
-- what they share: the saved settings (per device, like the other
-- modules), startup and the /map-like slash command.
-------------------------------------------------------------------
ns.inits = {}

function ns.OnInit(fn) ns.inits[#ns.inits + 1] = fn end

-- The Deck's 800 pixels want a smaller minimap and world map than a PC
-- monitor; both are sliders in the Map tab.
local DEVICE_DEFAULTS = {
    deck = { minimapSize = 150, worldMapScale = 0.75 },
    pc   = { minimapSize = 190, worldMapScale = 0.85 },
}

function ns.DeviceDB()
    return D.DeviceDB(DeckUIForeverMapDB, DEVICE_DEFAULTS)
end

-- Shared, not per device
local DEFAULTS = {
    round        = false,   -- FFXIV's round minimap in a ring with N/E/S/W (minimap.lua)
    coordinates  = true,    -- player coordinates under the minimap
    clock        = true,
    zoneText     = true,
    buttonsOnHover = true,  -- addon and Blizzard buttons only while the mouse is over the map
    questLogClosed = true,  -- the world map opens without the quest log beside it
    mapControlsOnHover = true, -- the world map's breadcrumbs and buttons only under the mouse
    zoneLevels   = true,    -- a zone's level range after its name, minimap and world map
}

-------------------------------------------------------------------
-- A zone's level range (owner's wish, 2026-11-07)
-------------------------------------------------------------------
-- C_Map.GetMapLevels names the player levels a map is made for (in the
-- probe of 2026-11-05). 0 or nil means the game knows none - continents,
-- cities, instances - and nothing is shown then. Forever's new zones may
-- lack values while Blizzard still tunes them: ZONE_LEVEL_FALLBACK takes a
-- { min, max } per mapID for those, empty until the game shows a gap.
-- Here in core.lua because minimap.lua and worldmap.lua both read it.
local ZONE_LEVEL_FALLBACK = {
    -- [1436] = { 10, 20 },   -- an example: Westfall
}

local function Plain(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end

function ns.ZoneLevels(mapID)
    if not mapID then return end
    local min, max
    if C_Map.GetMapLevels then
        local ok, a, b = pcall(C_Map.GetMapLevels, mapID)
        if ok and Plain(a) and Plain(b) then min, max = a, b end
    end
    if not (min and max and min > 0 and max > 0) then
        local fb = ZONE_LEVEL_FALLBACK[mapID]
        if not fb then return end
        min, max = fb[1], fb[2]
    end
    if max < min then min, max = max, min end
    return min, max
end

-- The colour the game gives a quest of that level, read at the point of
-- the range nearest the player: yellow while the player is inside the
-- range, green or grey once above it, orange or red while below it.
local function LevelColor(level)
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    if c and c.r then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

-- "10-20" (or "60" for a single level) and its colour, or nothing
function ns.ZoneLevelText(mapID)
    local min, max = ns.ZoneLevels(mapID)
    if not min then return end
    local player = UnitLevel("player") or 1
    local r, g, b = LevelColor(math.max(min, math.min(max, player)))
    local text = min == max and tostring(min) or (min .. "-" .. max)
    return text, r, g, b
end

-- the same, as one coloured string for inline use
function ns.ZoneLevelString(mapID)
    local text, r, g, b = ns.ZoneLevelText(mapID)
    if not text then return end
    return ("|cff%02x%02x%02x%s|r"):format(
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
end

local function Init()
    DeckUIForeverMapDB = DeckUIForeverMapDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckUIForeverMapDB[k] == nil then DeckUIForeverMapDB[k] = v end
    end
    for _, fn in ipairs(ns.inits) do fn() end
end

if IsLoggedIn() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", Init)
end

-- /deckmap opens the Map tab; /deckmap debug prints what the module sees.
-- Not /map: that name is too likely to be taken by something else.
SLASH_DECKMAP1 = "/deckmap"
SlashCmdList.DECKMAP = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "debug" then
        for _, fn in ipairs(ns.debug or {}) do fn() end
    elseif msg == "reset" then
        if ns.ResetPositions then ns.ResetPositions() end
    else
        D.ToggleConfig("Map")
    end
end

ns.debug = {}
function ns.OnDebug(fn) ns.debug[#ns.debug + 1] = fn end
