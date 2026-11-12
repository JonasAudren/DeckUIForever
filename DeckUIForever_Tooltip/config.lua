local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverTooltipDB end
local device = function() return ns.DeviceDB() end
local nothing = function() end

-- Moved to D.Flow 2026-10-02: explanations as tooltips. The extra lines
-- had a sub-page of their own from 2026-10-28; since the menu review of
-- 2026-11-07 they sit on this page again (a hint and five checkboxes
-- were not worth a page), and the module's reset covers every key.
D.RegisterModule("Tooltip", {
    title = "Tooltip",
    build = function(c)
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        f:Label("Place and size (this device)")
        f:Checkbox("At its own place", db, "fixedAnchor", nothing,
            "Tooltips of buttons and frames stay beside them. All others appear at the Tooltip frame, which Move below places.")
        f:Slider("Size", 0.6, 1.4, 0.05, pct, device, "scale", function(v)
            ns.DeviceDB().scale = v
            ns.ApplyScale()
        end)

        f:Label("Content")
        f:Checkbox("Players in their class colour", db, "classColors", nothing,
            "Name and edge in the class colour.")
        f:Checkbox("Item level of players", db, "playerInfo", nothing,
            "Shows a moment later, never in combat.")
        f:More()
        f:Checkbox("Whom the unit is targeting", db, "targetLine", nothing)
        f:Checkbox("IDs while Shift is held", db, "ids", nothing, "Item, spell and NPC IDs.")

        f:MoreSection("Extra lines")
        f:Checkbox("Items that start a quest: the quest", db, "questItems", nothing)
        f:Checkbox("Profession spells: unspent knowledge", db, "knowledge", nothing,
            "Only where a profession has specialization trees.")
        f:Checkbox("Reputation items: your standing", db, "reputation", nothing,
            "The faction and how far you are with it.")
        f:Checkbox("Transmog ensembles: what you have", db, "ensembles", nothing,
            "How many of the set's looks you have collected.")
        f:Checkbox("Items: auction price", db, "ahPrice", nothing,
            "The cheapest buyout from your last auction house scan, and a stack's whole value.")
    end,
})
D.PAGE_RESET.Tooltip = { db = "DeckUIForeverTooltipDB" }
