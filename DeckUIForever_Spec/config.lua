local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverSpecDB end

-- Moved to D.Flow 2026-10-02: the hint became the checkbox's tooltip.
D.RegisterModule("Spec", {
    title = "Spec",
    build = function(c)
        local f = D.Flow(c)
        f:Label("Talent group switcher")
        f:Checkbox("Show the talent group bar", db, "showBar", ns.SetBarShown, ns.HINT)

        -- an equipment set per talent group (core.lua)
        if ns.GroupSet then
            f:Gap(8)
            f:Label("Gear per talent group")
            local function Def(group)
                local values = {}
                local names = setmetatable({ NONE = "none" }, { __index = function(_, k) return k end })
                return {
                    label = group == 1 and "Primary" or "Secondary",
                    values = values, names = names,
                    tip = "The equipment set to put on when you switch to this talent group. Sets are made in the character panel's equipment manager. Per character.",
                    -- the list is read anew on every click: sets come and go
                    get = function() ns.SetNames(values) return ns.GroupSet(group) or "NONE" end,
                    set = function(v) ns.GroupSet(group, v) end,
                }
            end
            f:Cycles(Def(1), Def(2))
        end
    end,
})
