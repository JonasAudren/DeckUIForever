local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverBagsDB end
local device = function() return ns.DeviceDB() end

-- D.Slider leaves storing the value to its apply function
local function Relayout(key)
    return function(v)
        ns.DeviceDB()[key] = v
        ns.RequestLayout()
        ns.FlushAll()
    end
end

local function Refresh()
    ns.RequestRefresh()
    ns.FlushAll()
end

-- Moved to D.Flow 2026-10-02: explanations as tooltips; the one line
-- people need before they look for it - how to open things - stays.
-- Texts shortened in the menu review of 2026-11-07.
D.RegisterModule("Bags", {
    title = "Bags",
    build = function(c)
        local count = function(v) return tostring(v) end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        f:Hint("B, the bag bar and /bags open the bags; a banker opens the bank. Drag a window by its edge to move it. The squares beside the title are your bag slots: drag a bag onto one to swap it.")

        f:Label("Size (this device)")
        local tall = "More columns make the window wider and shorter."
        f:Slider("Bag columns", 6, 24, 1, count, device, "columns", Relayout("columns"), tall)
        f:Slider("Bank columns", 7, 24, 1, count, device, "bankColumns", Relayout("bankColumns"), tall)
        f:Slider("Size", 0.6, 1.4, 0.05, pct, device, "scale", Relayout("scale"))

        f:Label("Items")
        f:Checkbox("Sort into categories", db, "categories", ns.SetCategoryView,
            "New, equipment, consumables, trade goods, quest items, other, junk. The bank keeps its tabs.")
        f:Checkbox("Keyring in the bag window", db, "keyring", function() ns.RequestLayout(); ns.FlushAll() end,
            "Your keys as a section of their own. Off, the keyring is only Blizzard's button on the bag bar.")
        f:Checkbox("Item level on gear", db, "itemLevel", Refresh)
        f:Checkbox("Coin on junk (grey items)", db, "markJunk", Refresh)

        f:MoreSection("Auction prices")
        local gold = function(v) return v .. "g" end
        f:Checkbox("Value of the window in its footer", db, "ahValue", Refresh,
            "What everything in the window would sell for at the auction house, from your last scan there.")
        f:Checkbox("Gold coin on valuable items", db, "markValuable", Refresh)
        f:Slider("Valuable from", 10, 1000, 10, gold, db, "valuableGold", function(v)
            DeckUIForeverBagsDB.valuableGold = v
            Refresh()
        end, "A stack counts as valuable from this value on.")
        f:Gap(4)
        f:Hint("Drop an item on the row above the gold to count it there like a currency; right-click it to stop.")
    end,
})
