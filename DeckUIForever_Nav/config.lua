local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverNavDB end
local device = function() return ns.DeviceDB() end
local nothing = function() end

-- Moved to D.Flow 2026-10-02: explanations as tooltips; the /way line
-- stays. Texts shortened in the menu review of 2026-11-07.
D.RegisterModule("Nav", {
    title = "Nav",
    build = function(c)
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        f:Hint("The navigation target is the one Blizzard follows, so the diamond in the world, the map and the compass agree.")

        f:Label("Compass and target")
        f:Checkbox("Compass bar at the top", db, "compass", nothing,
            "Hidden in instances, where the game gives no position. Move it with Move below.")
        f:More()
        f:Checkbox("Party members on the compass", db, "party", nothing)
        if C_VignetteInfo then
            f:Checkbox("Rares and treasures on the compass", db, "vignettes", nothing)
        end
        f:Basic()
        f:Checkbox("Target with arrow, distance and arrival time", db, "panel", nothing,
            "Move it with Move below.")
        f:More()
        if ns.ApplyBeacon then
            f:Checkbox("Beacon in the world", db, "beacon", function() ns.ApplyBeacon() end,
                "Name, distance and arrival time at the target's marker in the world, in place of Blizzard's diamond.")
        end
        f:Slider("Size (this device)", 0.6, 1.4, 0.05, pct, device, "scale", function(v)
            ns.DeviceDB().scale = v
            ns.ApplyScale()
        end)

        f:Label("Waypoints")
        f:Hint("Key bindings (Keybindings > AddOns > DeckUIForever) step through your tracked quests, nearest first.")
        f:Button("Waypoint list", function() ns.ToggleWaypoints() end,
            "Click a waypoint to head there, right click to remove it, double click to rename it. Add one with Ctrl-click on the world map or /way 45.2 67.8 name.")
        f:More()
        f:Checkbox("Route: walk the waypoints in order", db, "routeMode", function() end,
            "On, the next waypoint follows when you arrive, round and round. Off, a reached waypoint is removed and the nearest one follows.")
        f:Hint("/way 45.2 67.8 name adds a waypoint, /way clear removes them all. With TomTom installed, use /dway.")
    end,
})
