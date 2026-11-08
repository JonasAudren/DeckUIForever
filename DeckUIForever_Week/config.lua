local ADDON, ns = ...
local D = DeckUIForever

-- Moved to D.Flow 2026-10-02: the three paragraphs became tooltips and
-- one line. Texts shortened in the menu review of 2026-11-07.
D.RegisterModule("Week", {
    title = "Week",
    build = function(c)
        local f = D.Flow(c)

        f:Hint("Every character in one table: raid lockouts, Legacy and PvP renown, today's dailies, reputation, currencies and weekly quests. Click a character for details.")

        f:Label("This week")
        f:Button("Open the week overview", function() ns.Toggle() end,
            "Also /week, a key binding, or Shift-click on the minimap button.")
        f:Checkbox("Button in the dock", function() return DeckUIForeverWeekDB end, "showButton",
            function() ns.UpdateButton() end,
            "A round button in DeckUIForever's dock that opens the overview, with the week's unlocked vault slots in its corner. The dock itself is on the Screen page.")
        f:Gap(4)
        f:Hint("Each character saves its week while you play it. Right click a weekly quest to hide it, a character to forget it.")
    end,
})
