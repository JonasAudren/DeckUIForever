local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The pet bar: a hunter's or warlock's pet commands in the hotbar look
-------------------------------------------------------------------
-- Owner's wish (2026-11-05): Blizzard's PetActionBar was the last bar in
-- Blizzard's look. Here a row of ten square slots like the action bars,
-- Blizzard's bar parked while this is on (DeckUIForeverBarsDB.petBar).
--
-- The buttons are SecureActionButtons of type "pet" with the slot's index
-- as "action": a left click casts the pet action from secure code, in
-- combat too. A right click toggles autocast (TogglePetAutocast is not
-- protected; Blizzard's own button calls it from plain Lua). What the
-- buttons show is read on the pet bar events, as Blizzard's
-- PetActionBarMixin reads it, and drawn only: icon, active command
-- (lit), usable, cooldown, autocast as a small corner mark - gold while
-- it is on, grey while it is allowed but off.
--
-- Keys stay Blizzard's: BONUSACTIONBUTTON1-10 press Blizzard's hidden
-- buttons in Blizzard's own code; ours show the key and mirror the
-- pushed state. The row shows while the player has a pet and no vehicle,
-- possess or override bar is up (a state driver, secure).
-------------------------------------------------------------------
local MAX = NUM_PET_ACTION_SLOTS or 10
local SIZE, GAP = 36, 3

local function Plain(v)
    return not issecretvalue or not issecretvalue(v)
end

local row = CreateFrame("Frame", "DeckUIForeverPetBar", UIParent)
row:SetSize(MAX * (SIZE + GAP) - GAP, SIZE)
row.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 175 }
row:SetPoint(unpack(row.defaultPoint))
row:Hide()

local buttons = {}
for i = 1, MAX do
    local b = CreateFrame("CheckButton", "DeckUIForeverPetButton" .. i, row, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:SetPoint("LEFT", row, "LEFT", (i - 1) * (SIZE + GAP), 0)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetAttribute("type1", "pet")
    b:SetAttribute("action", i)
    b.index = i
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    ns.StyleSlot(b)
    b.hotkey = ns.KeyText(b)

    -- the autocast mark: a small square in the top right corner
    local auto = b:CreateTexture(nil, "OVERLAY", nil, 7)
    auto:SetSize(7, 7)
    auto:SetPoint("TOPRIGHT", -2, -2)
    auto:SetTexture("Interface\\Buttons\\WHITE8x8")
    auto:Hide()
    b.auto = auto

    b:HookScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down then TogglePetAutocast(self.index) end
        -- a CheckButton ticks itself on click; the pet says what is true
        local _, _, _, isActive = GetPetActionInfo(self.index)
        self:SetChecked(Plain(isActive) and isActive and true or false)
    end)
    -- drag with the pickup modifier rearranges the commands, as on
    -- Blizzard's bar; a plain drag leaves the slot alone
    b:HookScript("OnDragStart", function(self)
        if IsModifiedClick("PICKUPACTION") then PickupPetAction(self.index) end
    end)
    b:HookScript("OnReceiveDrag", function(self)
        if GetCursorInfo() == "petaction" then PickupPetAction(self.index) end
    end)
    b:HookScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetPetAction(self.index)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", GameTooltip_Hide)

    -- a key press reaches Blizzard's hidden button; its pushed state is ours
    local native = _G["PetActionButton" .. i]
    if native then
        hooksecurefunc(native, "SetButtonState", function(_, state) ns.ShowPushed(b, state == "PUSHED") end)
    end
    buttons[i] = b
end

local function Paint()
    for i, b in ipairs(buttons) do
        local name, texture, isToken, isActive, autoAllowed, autoEnabled = GetPetActionInfo(i)
        if isToken then texture = _G[texture] end
        b.icon:SetTexture(texture)
        b.icon:SetShown(texture ~= nil)
        if Plain(isActive) then b:SetChecked(isActive and true or false) end
        if Plain(autoAllowed) and Plain(autoEnabled) then
            b.auto:SetShown(autoAllowed and true or false)
            if autoEnabled then b.auto:SetVertexColor(0.9, 0.75, 0.2, 1) else b.auto:SetVertexColor(0.5, 0.5, 0.5, 0.8) end
        end
        if texture then
            local usable = GetPetActionSlotUsable(i)
            if Plain(usable) then
                if usable then b.icon:SetVertexColor(1, 1, 1) else b.icon:SetVertexColor(0.4, 0.4, 0.4) end
            end
        end
        b.hotkey:SetText(ns.KeyLabel("BONUSACTIONBUTTON" .. i))
    end
end

local function Cooldowns()
    for i, b in ipairs(buttons) do
        local start, duration, enable = GetPetActionCooldown(i)
        if start and duration then CooldownFrame_Set(b.cooldown, start, duration, enable) end
    end
end

local pending = false
local blizzardHidden = false

-- the row's visibility, scale and Blizzard's bar: out of combat only
function ns.ApplyPetBar()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local on = DeckUIForeverBarsDB.petBar and true or false
    row:SetScale(ns.DeviceDB().barScale or 1)
    row:SetAlpha(DeckUIForeverBarsDB.barAlpha or 1)
    RegisterStateDriver(row, "visibility",
        on and "[pet,nopetbattle,novehicleui,nooverridebar,nopossessbar] show; hide" or "hide")
    if on ~= blizzardHidden then
        ns.SetBlizzardBarHidden("PetActionButton1", on)
        blizzardHidden = on
    end
    Paint()
    Cooldowns()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, arg1)
    if not DeckUIForeverBarsDB then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then ns.ApplyPetBar() end
    elseif event == "PET_BAR_UPDATE_COOLDOWN" then
        Cooldowns()
    elseif event == "UNIT_AURA" or event == "UNIT_FLAGS" then
        if arg1 == "pet" then Paint() end
    else
        Paint()
    end
end)

function ns.InitPetBar()
    for _, e in ipairs({ "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "PET_BAR_UPDATE_USABLE", "PET_UI_UPDATE",
                         "UNIT_PET", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_FARSIGHT_FOCUS_CHANGED",
                         "PLAYER_TARGET_CHANGED", "UPDATE_VEHICLE_ACTIONBAR", "PLAYER_MOUNT_DISPLAY_CHANGED",
                         "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS" }) do
        ev:RegisterEvent(e)
    end
    ev:RegisterUnitEvent("UNIT_AURA", "pet")
    ev:RegisterUnitEvent("UNIT_FLAGS", "pet")
    D.MakeMovable(row, "Pet bar", DeckUIForeverBarsDB)
    table.insert(ns.extraRows, row)
    ns.ApplyPetBar()
end

-- /df bars
function ns.PrintPetBar()
    print(("  pet bar: option %s, pet %s, has bar %s, shown %s, pending %s"):format(
        tostring(DeckUIForeverBarsDB.petBar), tostring(UnitExists("pet")), tostring(PetHasActionBar()),
        tostring(row:IsShown()), tostring(pending)))
end
