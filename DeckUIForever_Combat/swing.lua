local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The swing timer
-------------------------------------------------------------------
-- The game says when you swing: PLAYER_SWING(swingDuration, swingType)
-- fires with every auto attack, with the time until the next one and
-- the weapon (Enum.PlayerSwingType: 0 main hand, 1 off hand, 2 ranged).
-- A bar per weapon fills over that time and goes when it is over and no
-- new swing came. With swingRange the game also tells whether the target
-- is in the weapon's reach (C_SwingTimer.EnableRangeCheck +
-- PLAYER_SWING_RANGE_UPDATE): the bar turns red while it is not.
--
-- The duration's unit is not documented: seconds are expected (a swing
-- lasts 1.5 to 4), a number above 60 is taken as milliseconds. A secret
-- duration cannot be counted down - then nothing shows, and /df combat
-- says so.
-------------------------------------------------------------------
local W, H, GAP = 180, 8, 3
local TYPES = {
    [0] = { name = "Main hand", color = { 0.95, 0.85, 0.55 } },
    [1] = { name = "Off hand",  color = { 0.70, 0.75, 0.85 } },
    [2] = { name = "Ranged",    color = { 0.95, 0.60, 0.30 } },
}
local RED = { 0.9, 0.25, 0.2 }

local holder = ns.Holder("DeckUIForeverSwingTimer", "Swing timer", W, 3 * H + 2 * GAP,
    { "CENTER", UIParent, "CENTER", 0, -210 })
local bars = {}
local preview = false
local seen = { swings = 0, secret = 0, last = nil, lastType = nil }
local ev = CreateFrame("Frame")

local function On() return DeckUIForeverCombatDB.swingTimer and true or false end

local function Colour(bar)
    local c = (bar.outOfRange and DeckUIForeverCombatDB.swingRange) and RED or TYPES[bar.swingType].color
    bar:SetStatusBarColor(c[1], c[2], c[3])
end

-- the bars that run, from the top down
local function Layout()
    local y = 0
    for t = 0, 2 do
        local bar = bars[t]
        if bar and bar:IsShown() then
            bar:ClearAllPoints()
            bar:SetPoint("TOP", holder, "TOP", 0, -y)
            y = y + H + GAP
        end
    end
end

local function Bar(swingType)
    local bar = bars[swingType]
    if bar then return bar end
    bar = ns.Bar(holder, W, H)
    bar.swingType = swingType
    bar:Hide()
    bars[swingType] = bar
    Colour(bar)
    return bar
end

local function Start(swingType, duration)
    local bar = Bar(swingType)
    bar.start, bar.duration = GetTime(), duration
    bar:SetMinMaxValues(0, duration)
    bar:SetValue(0)
    bar:Show()
    Layout()
end

holder:SetScript("OnUpdate", function()
    if preview then return end
    local now = GetTime()
    local gone = false
    for _, bar in pairs(bars) do
        if bar:IsShown() and bar.start then
            local passed = now - bar.start
            if passed >= bar.duration + 0.25 then
                -- no new swing came: the fight is over, or the target is away
                bar.start = nil
                bar:Hide()
                gone = true
            else
                bar:SetValue(math.min(passed, bar.duration))
                bar.right:SetText(ns.TimeText(math.max(0, bar.duration - passed)))
            end
        end
    end
    if gone then Layout() end
end)

local function SetRangeChecks(on)
    if not (C_SwingTimer and C_SwingTimer.EnableRangeCheck) then return end
    for t = 0, 2 do pcall(C_SwingTimer.EnableRangeCheck, t, on and true or false) end
end

ev:SetScript("OnEvent", function(_, event, a, b, c)
    if event == "PLAYER_SWING" then
        -- swingDuration, swingType
        seen.swings = seen.swings + 1
        if ns.Secret(a) or ns.Secret(b) then
            seen.secret = seen.secret + 1
            return
        end
        if type(a) ~= "number" or not TYPES[b] or a <= 0 then return end
        if a > 60 then a = a / 1000 end
        seen.last, seen.lastType = a, b
        if not preview then Start(b, a) end
    elseif event == "PLAYER_SWING_RANGE_UPDATE" then
        -- swingType, isInRange, checksRange
        if ns.Secret(a) or ns.Secret(b) or ns.Secret(c) or not TYPES[a] then return end
        local bar = Bar(a)
        bar.outOfRange = (c and b == false) and true or false
        Colour(bar)
    else
        -- the fight is over: nothing left to wait for
        for _, bar in pairs(bars) do
            if not preview then bar.start = nil; bar:Hide() end
        end
    end
end)

local function Apply()
    local on = On()
    if on then
        pcall(ev.RegisterEvent, ev, "PLAYER_SWING")
        pcall(ev.RegisterEvent, ev, "PLAYER_SWING_RANGE_UPDATE")
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        SetRangeChecks(DeckUIForeverCombatDB.swingRange)
        holder:Show()
    else
        ev:UnregisterAllEvents()
        SetRangeChecks(false)
        holder:Hide()
    end
    for _, bar in pairs(bars) do Colour(bar) end
end

local function Preview(state)
    preview = state and On() or false
    for t = 0, 2 do
        local bar = Bar(t)
        if preview then
            bar.start = nil
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0.35 + t * 0.2)
            bar.left:SetText(TYPES[t].name)
            bar.right:SetText("1.4")
            bar:Show()
        else
            bar.left:SetText("")
            bar:Hide()
        end
    end
    Layout()
end

ns.pieces.swing = {
    key = "Swing timer",
    Init = function() D.MakeMovable(holder, "Swing timer", DeckUIForeverCombatDB) end,
    Apply = Apply,
    Preview = Preview,
    Print = function()
        print(("  swing timer: option %s, range %s, C_SwingTimer %s, swings seen %d (hidden by the game %d), last %s s type %s"):format(
            tostring(DeckUIForeverCombatDB.swingTimer), tostring(DeckUIForeverCombatDB.swingRange),
            C_SwingTimer and "yes" or "no", seen.swings, seen.secret, tostring(seen.last), tostring(seen.lastType)))
    end,
}
