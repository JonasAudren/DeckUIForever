local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The stance bar: forms, stances, auras, stealth - in the hotbar look
-------------------------------------------------------------------
-- After DeckUI Cross's stance.lua (round buttons at the crosses), here
-- as a row of square slots like the action bars (owner's wish,
-- 2026-11-05: "complete the bars"). Blizzard's StanceBar is parked while
-- this is on (DeckUIForeverBarsDB.stanceBar).
--
-- The buttons are SecureActionButtons casting the form's spell (type
-- "spell", spell = 4th return of GetShapeshiftFormInfo), so a click casts
-- from untainted secure code, in combat too. What they show (icon, active
-- form, usable, cooldown) is read on the stance events and drawn only.
-- Attributes, the number of buttons and the row's width change only out
-- of combat; the set of forms changes with talents, out of combat too.
--
-- Keys stay Blizzard's: SHAPESHIFTBUTTON1-10 run StanceBar:Select in
-- Blizzard's own code, which does not care whether its bar is visible.
-- Ours show the key in the corner and light up on UPDATE_SHAPESHIFT_FORM.
-------------------------------------------------------------------
local MAX = NUM_STANCE_SLOTS or 10
local SIZE, GAP = 36, 3

local function Plain(v)
    return not issecretvalue or not issecretvalue(v)
end

local row = CreateFrame("Frame", "DeckUIForeverStanceBar", UIParent)
row:SetSize(SIZE, SIZE)
row.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", -260, 130 }
row:SetPoint(unpack(row.defaultPoint))
row:Hide()

local buttons = {}
for i = 1, MAX do
    local b = CreateFrame("CheckButton", "DeckUIForeverStanceButton" .. i, row, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    -- down and up, like LibActionButton: Blizzard's secure handler decides
    -- by ActionButtonUseKeyDown which of the two a key press acts on
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("type", "spell")
    b.index = i
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    ns.StyleSlot(b)
    b.hotkey = ns.KeyText(b)

    -- a key press shows no pushed state of its own; hold our glow a moment
    b:HookScript("PreClick", function(self)
        self.DeckPushed:Show()
        C_Timer.After(0.18, function() self.DeckPushed:Hide() end)
    end)
    -- a CheckButton ticks itself on click; the form says what is true
    b:HookScript("PostClick", function(self)
        self:SetChecked(self.index == GetShapeshiftForm())
    end)
    b:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetShapeshift(self.index)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", GameTooltip_Hide)
    buttons[i] = b
end

local pending = false
local count = 0

local function Paint()
    local form = GetShapeshiftForm()
    for i = 1, count do
        local b = buttons[i]
        local icon, _, castable = GetShapeshiftFormInfo(i)
        b.icon:SetTexture(icon)
        if Plain(castable) then b.icon:SetDesaturated(not castable) end
        b:SetChecked(i == form)
        -- possibly secret: handed to the cooldown as they are, never compared
        local start, duration, enable = GetShapeshiftFormCooldown(i)
        if start and duration then CooldownFrame_Set(b.cooldown, start, duration, enable) end
        b.hotkey:SetText(ns.KeyLabel("SHAPESHIFTBUTTON" .. i))
    end
end

local blizzardHidden = false

-- the row's buttons, attributes and width: out of combat only
function ns.ApplyStanceBar()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local on = DeckUIForeverBarsDB.stanceBar
    count = on and math.min(GetNumShapeshiftForms() or 0, MAX) or 0
    for i, b in ipairs(buttons) do
        if i <= count then
            local _, _, _, spellID = GetShapeshiftFormInfo(i)
            b:SetAttribute("spell", spellID)
            b:ClearAllPoints()
            b:SetPoint("LEFT", row, "LEFT", (i - 1) * (SIZE + GAP), 0)
            b:Show()
        else
            b:SetAttribute("spell", nil)
            b:Hide()
        end
    end
    row:SetWidth(math.max(1, count * (SIZE + GAP) - GAP))
    row:SetScale(ns.DeviceDB().barScale or 1)
    row:SetAlpha(DeckUIForeverBarsDB.barAlpha or 1)
    -- in a vehicle or a pet battle the bars show other things; so does the row
    RegisterStateDriver(row, "visibility",
        count > 0 and "[petbattle][vehicleui][overridebar][possessbar] hide; show" or "hide")
    if on ~= blizzardHidden then
        ns.SetBlizzardBarHidden("StanceButton1", on and true or false)
        blizzardHidden = on and true or false
    end
    Paint()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if not DeckUIForeverBarsDB then return end
    if event == "UPDATE_SHAPESHIFT_FORMS" or event == "PLAYER_ENTERING_WORLD"
        or (event == "PLAYER_REGEN_ENABLED" and pending) then
        ns.ApplyStanceBar()
    elseif event == "PLAYER_REGEN_ENABLED" then
        return
    else
        Paint()
    end
end)

function ns.InitStanceBar()
    for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE",
                         "UPDATE_SHAPESHIFT_COOLDOWN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
                         "UPDATE_BINDINGS" }) do
        ev:RegisterEvent(e)
    end
    D.MakeMovable(row, "Stance bar", DeckUIForeverBarsDB)
    table.insert(ns.extraRows, row)
    ns.ApplyStanceBar()
end

-- /df bars
function ns.PrintStanceBar()
    print(("  stance bar: option %s, forms %d, shown %d, form %d, pending %s"):format(
        tostring(DeckUIForeverBarsDB.stanceBar), GetNumShapeshiftForms() or 0, count,
        GetShapeshiftForm() or 0, tostring(pending)))
end
