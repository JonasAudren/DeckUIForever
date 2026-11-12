local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverPadDB end
local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

-- The Pad page: the look of Blizzard's controller bar. Everything here
-- is live but the empty-slot glyph; the module itself is switched off on
-- the Modules page (a reload). Texts shortened in the menu review of
-- 2026-11-07.
D.RegisterModule("Pad", {
    title = "Pad",
    build = function(c)
        local f = D.Flow(c)
        c.widgets = c.widgets or {}
        f:Hint("Blizzard's controller action bar on the Steam Deck in the look of the Bars module: square slots, the button glyph in the corner. The controls stay Blizzard's.")

        f:Label("Look")
        f:Slider("Slot shade", 0, 0.8, 0.05, pct, db, "slotAlpha", function(v)
            DeckUIForeverPadDB.slotAlpha = v
            ns.Apply()
        end, "How dark an empty slot is.")
        f:Checkbox("Button glyph in every slot", db, "glyphs", function()
            ns.ApplyGlyphs()
        end, "The A, B, X, Y and D-pad glyphs small in the corner of every slot. Off, only what Blizzard shows on the bar you hold.")
        f:More()
        f:Checkbox("Blizzard's glyph in empty slots", db, "emptyGlyph", function(v)
            D.NeedReload("pad:emptyGlyph")
        end, "Blizzard draws a big glyph as the background of an empty slot. On, it stays. Needs a reload.")
        f:Checkbox("Flat panel behind the active bar", db, "focusPanel", function()
            ns.Apply()
        end, "The bar you hold with LT or RT gets a dark panel instead of Blizzard's glow.")
    end,
})

D.PAGE_RESET.Pad = { db = "DeckUIForeverPadDB" }
