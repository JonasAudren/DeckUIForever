local ADDON, ns = ...
local D = DeckUIForever

local device = function() return ns.DeviceDB() end
local db = function() return DeckUIForeverQuestsDB end
local nothing = function() end

-- D.Slider leaves storing the value to its apply function
local function Store(key)
    return function(v)
        ns.DeviceDB()[key] = v
        ns.RequestRedraw()
    end
end

-- Moved to D.Flow 2026-10-02: explanations as tooltips, and the journey
-- bar got a show button here (it was only /quests journey). Texts
-- shortened in the menu review of 2026-11-07.
D.RegisterModule("Quests", {
    title = "Quests",
    build = function(c)
        local px  = function(v) return tostring(v) end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        f:Hint("Drag the tracker by its edge to move it. Click a heading to fold its section; the - in the corner folds everything.")

        f:Checkbox("Final Fantasy XIV's task list", db, "xivLayout", function() ns.RequestRedraw() end,
            "No box, everything right-aligned, the objectives in light blue, a tick after the done ones.")

        -- guide.lua, delves.lua and hunt.lua are retail's only (Forever has
        -- no campaigns, delves or hunts); their options go with them
        if ns.ApplyGuide then
            f:Checkbox("Scenario guide: the story at a glance", db, "scenarioGuide", function() ns.ApplyGuide() end,
                "A small banner with the story quest you are on, or the next step and what it needs. Click it to follow the quest. Move it with Move below.")
        end

        f:Label("Tracker (this device)")
        f:Slider("Width", 180, 400, 10, px, device, "width", Store("width"))
        f:Slider("Size", 0.6, 1.4, 0.05, pct, device, "scale", Store("scale"))
        f:Slider("Text size", 9, 16, 1, px, device, "textSize", Store("textSize"))
        f:Slider("Height limit", 150, 900, 10, px, device, "maxHeight", Store("maxHeight"),
            "Taller than this, the tracker scrolls with the mouse wheel.")

        if ns.ShowJourney then
            f:Label("Delves and the hunt")
            f:Checkbox("Take a single power automatically", db, "autoDelvePower", nothing,
                "A treasure or rare that offers just one power needs no choice: it is taken and named in the chat.")
            f:Checkbox("Show Delver's Journey progress", db, "journeyBar", nothing,
                "A bar appears for a few seconds whenever the season renown grows. Move it with Move below.")
            f:Button("Show the journey bar now", function() ns.ShowJourney() end,
                "Shows it with your current progress, to place it. Also /quests journey.")
            f:Checkbox("Star hunt targets an achievement still needs", db, "huntMarks", nothing,
                "On the hunt table a star marks targets still open.")
            f:Gap(4)
            f:Hint("The Nemesis count and the active hunt show in the tracker by themselves.")
        end
    end,
})
