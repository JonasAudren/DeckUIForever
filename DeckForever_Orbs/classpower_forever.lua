local _, ns = ...

-------------------------------------------------------------------
-- Class resources in World of Warcraft: Forever (DECKFOREVER_BERICHT.md, phase 2)
-------------------------------------------------------------------
-- Loaded before oUF: oUF's ClassPower element (libs/oUF/elements/
-- classpower.lua, the lines marked "DeckUI: Mists") asks ns.MistsClassPower
-- for its rules instead of retail's when it is set, and reads combo points
-- through ns.MistsComboPoints. The hook names are the Mists port's: the
-- oUF copy here is DeckUI's patched one, kept identical so a library
-- update is carried over once for both addons - so this file answers to
-- those names although it is Forever's.
--
-- Forever has Classic's resources. Rogues and cat druids build combo
-- points, and those sit on the target (game rule SingleTargetComboPoints;
-- Blizzard_UnitFrame/Camelot/TargetBoundComboPointBar.lua reads
-- GetComboPoints(unit, "target") and listens to PLAYER_TARGET_CHANGED and
-- COMBO_TARGET_CHANGED, 1.60.1). Nothing else: no holy power, chi, runes,
-- shadow orbs, soul shards as a power, no eclipse - the other seven
-- classes show no resource dots. Not yet tested in game (2026-11-05).
-------------------------------------------------------------------
local PT = Enum.PowerType

-- combo points belong to the target
function ns.MistsComboPoints(unit)
    return GetComboPoints(unit == "vehicle" and "vehicle" or "player", "target") or 0
end

function ns.MistsComboPointsMax(unit)
    local max = UnitPowerMax(unit, PT.ComboPoints)
    return (max and max > 0) and max or 5
end

-- Generic: the number oUF's own getters hand back; combo for the two
-- classes that have them. A class without a resource returns only the
-- updaters, so GetPowerInfo stays nil and oUF keeps the element hidden.
function ns.MistsClassPower(class, GetGeneric, GetGenericMax, GetGenericColor, GetCombo, GetComboMax)
    local function Color(element, powerType)
        return element.__owner.colors.power[powerType]
    end
    local function Combo()
        return GetCombo, GetComboMax, Color
    end

    if class == "ROGUE" then
        return Combo, function() return "COMBO_POINTS", PT.ComboPoints end
    elseif class == "DRUID" then
        -- only in cat form, where the druid runs on energy (oUF re-asks
        -- on UPDATE_SHAPESHIFT_FORM and UNIT_DISPLAYPOWER)
        return Combo, function()
            if UnitPowerType("player") == PT.Energy then return "COMBO_POINTS", PT.ComboPoints end
        end
    end
    return function() return GetGeneric, GetGenericMax, Color end
end

-- Combo points moved to another target keep their count, so no power
-- event fires (Blizzard's own comment); oUF's Mists path listens to
-- PLAYER_TARGET_CHANGED, this adds the second event. ns.oUF is set once
-- oUF has loaded, after this file - it is read at event time.
local ev = CreateFrame("Frame")
if not C_EventUtils or C_EventUtils.IsEventValid("COMBO_TARGET_CHANGED") then
    ev:RegisterEvent("COMBO_TARGET_CHANGED")
end
ev:SetScript("OnEvent", function()
    local oUF = ns.oUF
    for _, object in next, oUF and oUF.objects or {} do
        local element = object.ClassPower
        if element and element.ForceUpdate then element:ForceUpdate() end
    end
end)
