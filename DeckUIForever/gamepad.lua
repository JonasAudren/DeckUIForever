local D = DeckUIForever

-------------------------------------------------------------------
-- The D-pad in DeckUIForever's windows (2026-11-07)
-------------------------------------------------------------------
-- In Blizzard's gamepad interface style (the Steam Deck) every window
-- of the game is handed to GamepadMode.FrameControlsManager when it
-- opens: Smart Navigation collects the window's buttons, the D-pad moves
-- a cursor between them, A clicks, B closes, LT and RT jump between the
-- open windows. Blizzard built the manager to take frames that announce
-- themselves - "by manually calling FrameShown on their OnShow event"
-- (FrameControlsManager.lua) - and FrameShown and FrameHidden are
-- wrapped for insecure callers: allowed out of combat, refused with the
-- "interface action blocked" message in combat. So our windows announce
-- themselves out of combat only; what opened or closed during combat is
-- caught up on when it ends. In combat the trackpad serves, as before.
--
-- Nothing of the input is ours. The bindings, the cursor and the click
-- (MouseDown and MouseUp on the button, so OnClick runs as it does for
-- the mouse) are Blizzard's; Smart Navigation finds Buttons, CheckButtons
-- and EditBoxes on its own, inside scroll frames too (the right stick
-- scrolls). Ours is which windows take part, what B closes (the window's
-- own close button, so a window closes the way it always has), a gold
-- outline on the window that holds the cursor, and the LT/RT glyphs on
-- the windows left and right of it - all of them optional callbacks the
-- manager looks for on the frame (FocusGamepad, ShowLeftJumpHint ...).
-- Sliders are not buttons to Smart Navigation; they stay the trackpad's.
--
-- D.GamepadWindow(frame, opts) after the frame's own OnShow/OnHide are
-- set (SetScript replaces hooks). opts.close: the close button, or a
-- function; opts.popup: a dialog that returns the cursor to the window
-- it came from; opts.evict: Blizzard's frames behind ours (the combined
-- bag, the bank frame), parked unseen by the module and otherwise a
-- second, empty stop for LT and RT.
-------------------------------------------------------------------
local GOLD = { 1, 0.82, 0 }

local tracked    = {}   -- frame -> opts: every window that takes part
local registered = {}   -- frame -> true while Blizzard's manager holds it

local function Manager()
    return GamepadMode and GamepadMode.FrameControlsManager or nil
end

local function GamepadStyle()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
end

local function Wanted()
    return DeckUIForeverDB and DeckUIForeverDB.gamepadNav ~= false and Manager() ~= nil and GamepadStyle()
end

-- the manager refuses insecure callers under the combat restriction
local function Blocked()
    if InCombatLockdown() then return true end
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
        and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Combat then
        return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)
    end
    return false
end

-------------------------------------------------------------------
-- Announcing and withdrawing
-------------------------------------------------------------------
local function Announce(frame)
    if registered[frame] or Blocked() then return end
    local m, opts = Manager(), tracked[frame]
    if not m then return end
    if opts.popup then
        m:HandlePopupShown(frame)
    else
        m:FrameShown(frame)
    end
    registered[frame] = true
    for _, other in ipairs(opts.evict or {}) do
        if other then m:FrameHidden(other) end
    end
end

local function Withdraw(frame)
    if not registered[frame] or Blocked() then return end
    local m = Manager()
    if m then
        if tracked[frame].popup then m:HandlePopupHide(frame) else m:FrameHidden(frame) end
    end
    registered[frame] = nil
end

-- Every window to the state it should be in: announced while shown and
-- wanted, withdrawn otherwise. When combat ends, when the interface
-- style changes and when the option is switched.
local function Sync()
    if Blocked() then return end
    for frame in pairs(tracked) do
        if Wanted() and frame:IsShown() then Announce(frame) else Withdraw(frame) end
    end
end
D.SyncGamepadWindows = Sync

-------------------------------------------------------------------
-- What the manager asks a frame for
-------------------------------------------------------------------
-- a gold line around the window that holds the cursor
local function Outline(frame)
    local o = CreateFrame("Frame", nil, frame)
    o:SetAllPoints()
    o:SetFrameLevel(frame:GetFrameLevel() + 20)
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = o:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
    o:Hide()
    return o
end

-- Blizzard's glyph of a controller button (InputIconTextureFrameTemplate,
-- which draws the right picture for the pad in use); without the
-- template, the button's short name in our font
local NAMES = { [GAMEPAD_TRIGGER_LEFT or "PADLTRIGGER"] = "LT", [GAMEPAD_TRIGGER_RIGHT or "PADRTRIGGER"] = "RT" }

local function Glyph(parent, key)
    local ok, icon = pcall(CreateFrame, "Frame", nil, parent, "InputIconTextureFrameTemplate")
    if ok and icon and icon.SetInputKey then
        icon:SetInputKey(key)
        icon:SetSize(22, 22)
        return icon
    end
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(22, 22)
    D.FlatBox(f, 0.9, 0.3)
    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(D.FONT, 11, "OUTLINE")
    t:SetPoint("CENTER")
    t:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    t:SetText(NAMES[key] or "?")
    return f
end

-- the hints hang above the window's top edge: LT at the left corner, RT
-- at the right, the "focus the windows" button (Back/View) in the middle
local function Hint(frame, key, point, relPoint, x)
    local h = Glyph(frame, key)
    h:SetFrameLevel(frame:GetFrameLevel() + 21)
    h:SetPoint(point, frame, relPoint, x, 2)
    h:Hide()
    return h
end

local function Prepare(frame, opts)
    frame.DeckPadFocus = Outline(frame)
    frame.DeckPadHints = {
        left  = Hint(frame, GAMEPAD_TRIGGER_LEFT or "PADLTRIGGER", "BOTTOMLEFT", "TOPLEFT", 4),
        right = Hint(frame, GAMEPAD_TRIGGER_RIGHT or "PADRTRIGGER", "BOTTOMRIGHT", "TOPRIGHT", -4),
        focus = Hint(frame, GAMEPAD_MENU_LEFT or "PADBACK", "BOTTOM", "TOP", 0),
    }

    -- the manager calls these through securecallfunction; the frame is
    -- the first argument
    frame.FocusGamepad   = function(self) self.DeckPadFocus:Show() end
    frame.UnfocusGamepad = function(self) self.DeckPadFocus:Hide() end
    frame.ShowLeftJumpHint   = function(self) self.DeckPadHints.left:Show() end
    frame.HideLeftJumpHint   = function(self) self.DeckPadHints.left:Hide() end
    frame.ShowRightJumpHint  = function(self) self.DeckPadHints.right:Show() end
    frame.HideRightJumpHint  = function(self) self.DeckPadHints.right:Hide() end
    frame.ShowFocusJumpHint  = function(self) self.DeckPadHints.focus:Show() end
    frame.HideFocusJumpHint  = function(self) self.DeckPadHints.focus:Hide() end

    -- B: the window closes the way it always has. Returning true tells
    -- Smart Navigation not to look for a close button of its own.
    frame.SmartNavigationCloseHandler = function(self)
        local close = tracked[self] and tracked[self].close
        if type(close) == "function" then
            close(self)
        elseif close and close.Click then
            close:Click()
        else
            self:Hide()
        end
        return true
    end
end

-------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------
function D.GamepadWindow(frame, opts)
    if tracked[frame] then return end
    tracked[frame] = opts or {}
    Prepare(frame, tracked[frame])
    frame:HookScript("OnShow", function(self)
        if Wanted() then Announce(self) end
    end)
    frame:HookScript("OnHide", function(self)
        self.DeckPadFocus:Hide()
        for _, h in pairs(self.DeckPadHints) do h:Hide() end
        Withdraw(self)
    end)
    if frame:IsShown() and Wanted() then Announce(frame) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
-- the style switch resets the manager's list; a frame later it is settled
pcall(ev.RegisterEvent, ev, "INPUT_DEVICE_INTERFACE_TRANSITION")
ev:SetScript("OnEvent", function(_, event)
    if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        wipe(registered)
        C_Timer.After(0, Sync)
    else
        Sync()
    end
end)

-- /df gamepad: who takes part, and what Blizzard holds
function D.PrintGamepad()
    local m = Manager()
    print(("DeckUIForever gamepad: interface style %s, Blizzard's window manager %s, option %s, combat %s"):format(
        GamepadStyle() and "gamepad" or "keyboard", m and "found" or "missing",
        (DeckUIForeverDB and DeckUIForeverDB.gamepadNav ~= false) and "on" or "off", Blocked() and "yes" or "no"))
    for frame, opts in pairs(tracked) do
        print(("  %s: %s, %s%s"):format(frame:GetName() or "unnamed", frame:IsShown() and "shown" or "hidden",
            registered[frame] and "announced" or "not announced", opts.popup and ", popup" or ""))
    end
    if m and m.GetShownFrameCount then
        local focused = m.focusedFrame
        print(("  Blizzard holds %d window(s); focused: %s"):format(m:GetShownFrameCount(),
            focused and (focused:GetName() or "unnamed") or "none"))
    end
end
