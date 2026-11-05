local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Blizzard's own action bars, parked while ours show
-------------------------------------------------------------------
-- After DeckUI Cross's input.lua: a bar of Blizzard's is hidden by
-- reparenting it to a hidden frame - the safe, reload-free way. The key
-- bindings keep working: ACTIONBUTTON1 and friends are the client's own
-- commands and use the action slot, not the frame. Nothing is written
-- onto the bar but the parent; its own Show/Hide stay untouched (a
-- visibility state driver on an Edit Mode system was taint in DeckUI,
-- 2026-10-26). Edit Mode hands a bar back to its own containers when it
-- lays them out again (a level-up in combat did it), so a SetParent hook
-- parks it again - at once out of combat, after the fight otherwise.
--
-- Frame names changed over the versions, so a bar is resolved through one
-- of its buttons: the frame under UIParent above ActionButton1 IS Action
-- Bar 1, whatever it is called (MainActionBar in Forever, probe 2026-11-05).
-------------------------------------------------------------------
local hider = CreateFrame("Frame", "DeckUIForeverBarHider", UIParent)
hider:Hide()

function ns.ResolveBar(buttonName)
    local button = _G[buttonName]
    if not button then return nil, buttonName .. " not found" end
    local frame = button
    for _ = 1, 10 do
        local parent = frame:GetParent()
        if not parent then return nil, buttonName .. " has no bar frame" end
        if parent == UIParent or parent == hider then return frame end
        frame = parent
    end
    return nil, buttonName .. ": bar frame too deep"
end

local origParent, parked = {}, {}
local reparkPending = false

local function HideBar(bar)
    if not origParent[bar] then
        origParent[bar] = bar:GetParent()
        hooksecurefunc(bar, "SetParent", function(self, parent)
            if not parked[self] or parent == hider then return end
            if InCombatLockdown() then
                self:SetAlpha(0)
                reparkPending = true
            else
                self:SetParent(hider)
            end
        end)
    end
    parked[bar] = true
    bar:SetParent(hider)
end

local function ShowBar(bar)
    if not origParent[bar] then return end
    parked[bar] = nil
    bar:SetParent(origParent[bar])
    bar:SetAlpha(1)
end

-- hides (or gives back) the bar one of whose buttons is named; false in
-- combat, so the caller tries again after the fight
function ns.SetBlizzardBarHidden(buttonName, state)
    if InCombatLockdown() then return false end
    local bar, why = ns.ResolveBar(buttonName)
    if not bar then
        print("DeckUIForever Bars: " .. why)
        return true
    end
    if state then HideBar(bar) else ShowBar(bar) end
    return true
end

-- a parked bar that Edit Mode gave back in combat goes under cover again
local regen = CreateFrame("Frame")
regen:RegisterEvent("PLAYER_REGEN_ENABLED")
regen:SetScript("OnEvent", function()
    if not reparkPending then return end
    reparkPending = false
    for bar in pairs(parked) do
        if bar:GetParent() ~= hider then bar:SetParent(hider) end
    end
end)

-------------------------------------------------------------------
-- The override bar (vehicles with their own bar, some quests): our
-- Action Bar 1 pages to it, so Blizzard's is faded while bar 1 is ours
-------------------------------------------------------------------
local mouseBefore = {}
local function NoMouse(frame, on)
    if frame.EnableMouse and frame.IsMouseEnabled then
        if not on then
            if mouseBefore[frame] == nil then mouseBefore[frame] = frame:IsMouseEnabled() end
            frame:EnableMouse(false)
        elseif mouseBefore[frame] ~= nil then
            frame:EnableMouse(mouseBefore[frame])
            mouseBefore[frame] = nil
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do NoMouse(child, on) end
end

local overrideHooked, overrideFaded = false, false
function ns.SetOverrideBarFaded(state)
    local override = _G.OverrideActionBar
    if not override then return end
    if not overrideHooked then
        overrideHooked = true
        -- whatever Blizzard sets, a faded bar stays at 0
        hooksecurefunc(override, "SetAlpha", function(self, alpha)
            if overrideFaded and alpha ~= 0 then self:SetAlpha(0) end
        end)
    end
    overrideFaded = state and true or false
    override:SetAlpha(state and 0 or 1)
    NoMouse(override, not state)
end

-------------------------------------------------------------------
-- Leave vehicle / taxi
-------------------------------------------------------------------
-- Blizzard's leave button hangs under the main bar, so it goes out of
-- sight with it. Our own shows exactly when leaving is possible and none
-- of Blizzard's leave buttons can be seen - never twice. VehicleExit and
-- TaxiRequestEarlyLanding are not protected, so a plain button does, in
-- combat too. Movable as "Leave vehicle".
local LEAVE_SIZE = 40

local leave = CreateFrame("Button", "DeckUIForeverBarsLeaveVehicle", UIParent)
leave:SetSize(LEAVE_SIZE, LEAVE_SIZE)
leave.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 220 }
leave:SetPoint(unpack(leave.defaultPoint))
leave:Hide()

leave:SetNormalTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
leave:SetPushedTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down")
leave:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
for _, tex in ipairs({ leave:GetNormalTexture(), leave:GetPushedTexture() }) do
    tex:SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
end

leave:SetScript("OnClick", function()
    if UnitOnTaxi("player") then
        TaxiRequestEarlyLanding()
    else
        VehicleExit()
    end
end)
leave:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(UnitOnTaxi("player") and (TAXI_CANCEL or "Request stop") or (LEAVE_VEHICLE or "Leave vehicle"))
    GameTooltip:Show()
end)
leave:SetScript("OnLeave", GameTooltip_Hide)

local function BlizzardLeaveVisible()
    local main = _G["MainMenuBarVehicleLeaveButton"]
    if main and main:IsVisible() then return true end
    local override = _G["OverrideActionBar"]
    if override and override.LeaveButton and override.LeaveButton:IsVisible()
        and override:GetEffectiveAlpha() > 0 then return true end
    return false
end

local function CanLeave()
    return CanExitVehicle() or UnitOnTaxi("player")
end

-- Polled rather than event-driven: taxis have no clean start event, and
-- Blizzard updates its own button on the same events we would listen to.
local leaveElapsed = 0
local leavePoll = CreateFrame("Frame")
leavePoll:SetScript("OnUpdate", function(_, dt)
    leaveElapsed = leaveElapsed + dt
    if leaveElapsed < 0.2 then return end
    leaveElapsed = 0
    -- while frames are unlocked it stays visible, or it could never be dragged
    leave:SetShown(D.IsUnlocked("Leave vehicle") or (CanLeave() and not BlizzardLeaveVisible()))
end)

function ns.InitLeaveButton()
    D.MakeMovable(leave, "Leave vehicle", DeckUIForeverBarsDB)
end

-- /df bars - what is parked where
function ns.PrintBlizzardBars()
    for n, info in ipairs(ns.BARS) do
        local bar, why = ns.ResolveBar(info.native .. "1")
        if bar then
            local parent = bar:GetParent()
            print(("  Action Bar %d: %s, parent %s, shown %s"):format(n, bar:GetName() or "?",
                parent and parent:GetName() or "?", tostring(bar:IsShown())))
        else
            print("  Action Bar " .. n .. ": " .. why)
        end
    end
    local b = _G["MainMenuBarVehicleLeaveButton"]
    print(("  leave button: Blizzard's visible %s, can leave %s, ours shown %s"):format(
        tostring(b and b:IsVisible()), tostring(CanLeave()), tostring(leave:IsShown())))
end
