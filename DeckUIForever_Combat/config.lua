local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverCombatDB end
local apply = function() ns.Apply() end

D.RegisterModule("Combat", {
    title = "Combat",
    build = function(c)
        local f = D.Flow(c)
        f:Hint("Small pieces for a fight, each on its own switch. Move them with Move below; unlocked, each shows a sample. /df combat prints what the game reports.")
        f:Label("Swing timer")
        f:Checkbox("Swing timer", db, "swingTimer", apply,
            "A thin bar for each weapon - main hand, off hand, ranged - that fills from one auto attack to the next. It shows while you are swinging.")
        f:Checkbox("Red while the target is out of reach", db, "swingRange", apply,
            "The bar of a weapon turns red while your target is too far away for it.")
        f:Label("Breath, fatigue, feign death")
        f:Checkbox("Breath timers", db, "mirrorTimers", apply,
            "The game's timers for breath under water, fatigue and feign death as bars in DeckUIForever's look, with the seconds left. Blizzard's own bars step back.")
        f:Label("Loss of control")
        f:Checkbox("Loss of control alert", db, "lossOfControl", apply,
            "When you are stunned, feared, silenced and the like: the spell's icon with the time running on it and the word beside it. Blizzard's own alert steps back.")
        f:Label("Threat")
        f:Checkbox("Threat on your target", db, "threat", apply,
            "A bar with your threat on the target in percent - at 100 it turns to you. Grey, yellow, orange and red as it rises. Only in a group.")
        f:Checkbox("Also when alone", db, "threatSolo", apply,
            "Shows the threat bar without a group too, for a pet or a guardian fighting beside you.")
    end,
})

D.PAGE_FRAMES.Combat = { "Swing timer", "Breath timers", "Loss of control", "Threat" }
D.PAGE_RESET.Combat = { db = "DeckUIForeverCombatDB" }
