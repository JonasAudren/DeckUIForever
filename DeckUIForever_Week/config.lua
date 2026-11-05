local ADDON, ns = ...
local D = DeckUIForever

-- Moved to D.Flow 2026-10-02: the three paragraphs became tooltips and one line.
D.RegisterModule("Week", {
    title = "Week",
    build = function(c)
        local f = D.Flow(c)

        f:Hint("Every character in one table: raid lockouts, the Legacy and PvP renown, today's dailies, reputation, currencies and weekly quests. Click a character for the details.")

        f:Label("This week")
        f:Button("Open the week overview", function() ns.Toggle() end,
            "Also /week, a key binding (Keybindings > AddOns > DeckUIForever) or Shift-click on the minimap button.")
        f:Checkbox("Button on screen", function() return DeckUIForeverWeekDB end, "showButton",
            function() ns.UpdateButton() end,
            "A small round button that opens the overview. Drag it to move it.")
        f:Gap(4)
        f:Hint("Each character saves its week while you play it; the others show what they had when last seen. Right click a weekly quest to hide it, a character to forget it.")
    end,
})
