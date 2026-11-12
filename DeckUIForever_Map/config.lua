local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverMapDB end
local device = function() return ns.DeviceDB() end
local cvars = function() return ns.cvars end

-- D.Slider leaves storing the value to its apply function
local function Store(key, apply)
    return function(v)
        ns.DeviceDB()[key] = v
        apply()
    end
end

local px  = function(v) return tostring(v) end
local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Moved to D.Flow 2026-10-02: explanations as tooltips. The minimap's
-- settings sit on the module's own page since the menu review of
-- 2026-11-07 (the page had been only a hint pointing at two sub-pages);
-- the world map keeps a sub-page.
D.RegisterModule("Map", {
    title = "Map",
    build = function(c)
        local f = D.Flow(c)

        f:Hint("Drag the minimap by its edge to move it; /deckmap reset puts it back. The world map has a page of its own below.")

        f:Label("Minimap (this device)")
        f:Slider("Size", 120, 280, 5, px, device, "minimapSize", Store("minimapSize", ns.ApplyMinimapSize))
        f:Checkbox("Round, like Final Fantasy XIV", db, "round", ns.ApplyShape,
            "A round map in a gold ring with N, E, S and W on it. The zone name above, clock and coordinates below.")
        f:Checkbox("Zone name", db, "zoneText", ns.ApplyTexts)
        f:More()
        f:Checkbox("Level range at zone names", db, "zoneLevels", ns.ApplyZoneLevels,
            "On the minimap and after the last breadcrumb of the world map. Grey for a zone below you, green, yellow, orange and red as it climbs, like quest levels. Blank where the game names no range.")
        f:Checkbox("Clock", db, "clock", ns.ApplyTexts, "Click it for the alarm and the stopwatch.")
        f:Checkbox("Your coordinates", db, "coordinates", ns.ApplyTexts,
            "Blank where the game gives no position.")
        f:Checkbox("Buttons only under the mouse", db, "buttonsOnHover", ns.ApplyHover,
            "Tracking, calendar, addons and zoom appear while the mouse is over the minimap.")
    end,
})

-- The keys the world map page writes, per-device ones included (Defaults
-- matches them against the device tables too). The CVars on that page
-- live in the game's config, not in DeckUIForeverMapDB.
local WORLD_KEYS = { worldMapScale = true, questLogClosed = true, mapControlsOnHover = true }
D.PAGE_FRAMES.Map = { "Minimap" }
D.PAGE_RESET.Map = { db = "DeckUIForeverMapDB", match = function(k) return not WORLD_KEYS[k] end }

D.RegisterModule("MapWorld", {
    title = "World map",
    build = function(c)
        local f = D.Flow(c)

        f:Hint("Drag the world map by the strip along its top edge; /deckmap reset puts it back.")

        f:Label("World map")
        f:Slider("Size (this device)", 0.5, 1.4, 0.05, pct, device, "worldMapScale",
            Store("worldMapScale", ns.ApplyWorldMapScale))
        f:Checkbox("Open without the quest log", db, "questLogClosed", function() end)
        f:More()
        f:Checkbox("Controls only under the mouse", db, "mapControlsOnHover", ns.ApplyMapHover,
            "Breadcrumbs, filter, floor and close buttons appear while the mouse is over the map.")
        f:Checkbox("Fade the map while moving", cvars, "mapFade", function() end,
            "The game's own setting, which has no checkbox in the game's options.")
        -- both CVars are in Forever's exe (probe, 2026-11-05)
        f:Checkbox("Show your coordinates", cvars, "worldMapShowPlayerCoords", function() end)
        f:Checkbox("Show the cursor's coordinates", cvars, "worldMapShowCursorCoords", function() end)
    end,
})
D.PAGE_FRAMES.MapWorld = { "World map" }
D.PAGE_RESET.MapWorld = { db = "DeckUIForeverMapDB", match = function(k) return WORLD_KEYS[k] == true end }
