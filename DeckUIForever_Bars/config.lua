local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverBarsDB end
local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

-- The Bars page: which of the eight bars are ours, their rows, the look.
-- Everything here is live (ns.ApplyBars, out of combat); Move below
-- drags the bars and the leave-vehicle button. Texts shortened in the
-- menu review of 2026-11-07.
D.RegisterModule("Bars", {
    title = "Bars",
    build = function(c)
        local f = D.Flow(c)
        c.widgets = c.widgets or {}
        f:Hint("Each bar you tick replaces Blizzard's: square slots in Final Fantasy's hotbar look, your keys in the corner. Fill the bars and bind keys as always.")

        local apply = function() ns.ApplyBars() end
        f:Label("Look")
        f:Slider("Size (this device)", 0.6, 1.6, 0.05, pct, ns.DeviceDB, "barScale", function(v)
            ns.DeviceDB().barScale = v
            apply()
        end)
        f:Slider("Opacity", 0.1, 1, 0.05, pct, db, "barAlpha", function(v)
            DeckUIForeverBarsDB.barAlpha = v
            ns.ApplyBarAlpha()
        end, "How see-through the bars are.")
        f:Checkbox("Bar numbers", db, "barNumbers", ns.ApplyBarNumbers,
            "A small number at the left end of each bar.")
        f:Checkbox("Recast timer", db, "cdNumbers", ns.ApplyCooldownNumbers,
            "The seconds left on a cooldown, large in the middle of the slot, as Final Fantasy shows them.")
        f:Checkbox("Hide the keys", db, "hideKeys", function()
            ns.ApplyKeys()
            ns.ApplyStanceBar()
            ns.ApplyPetBar()
        end, "No key names in the slots. The keys still work.")

        f:Gap(4)
        f:Label("The bars")
        local names = {}
        for _, per in ipairs(ns.BAR_LAYOUTS) do
            names[per] = per == 12 and "one row" or per == 1 and "one column" or (per .. " per row")
        end
        for n = 1, 8 do
            local bar = function() return ns.BarSettings(n) end
            f:Checkbox("Action Bar " .. n, bar, "shown", apply,
                n == 1 and "The main bar with its pages: stances, forms, vehicles."
                or ("Blizzard's Action Bar " .. n .. ", as Edit Mode numbers it."))
            f:Cycles({ label = "Layout", values = ns.BAR_LAYOUTS, names = names,
                       get = function() return ns.BarSettings(n).perRow end,
                       set = function(v) ns.BarSettings(n).perRow = v; apply() end })
        end

        f:Gap(4)
        f:Label("Other bars")
        f:Checkbox("Stance bar", db, "stanceBar", ns.ApplyStanceBar,
            "Forms, stances and stealth as a row of slots in place of Blizzard's stance bar. Shows only while you have forms.")
        f:Checkbox("Pet bar", db, "petBar", ns.ApplyPetBar,
            "Your pet's commands in place of Blizzard's pet bar. Right click toggles autocast.")
        f:Checkbox("Totem bar in the same look", db, "totemBar", function(v)
            if v then ns.ApplyTotemBar() end
            D.NeedReload("bars:totemBar", not v)
        end, "Shamans: Blizzard's totem bar keeps its place and gets the slot look. Switching it off needs a reload.")
    end,
})

-- the page's Move drags the bars and the leave-vehicle button
D.PAGE_FRAMES.Bars = { "Bar 1", "Bar 2", "Bar 3", "Bar 4", "Bar 5", "Bar 6", "Bar 7", "Bar 8",
                       "Stance bar", "Pet bar", "Leave vehicle" }
D.PAGE_RESET.Bars = { db = "DeckUIForeverBarsDB" }

-- /df bars adds our lines after the hub's layout report
D.PrintModuleBars = ns.PrintBars
