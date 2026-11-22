local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Breath, fatigue, feign death: the mirror timers
-------------------------------------------------------------------
-- The game runs up to three of these at once and names them BREATH,
-- EXHAUSTION and FEIGNDEATH. MIRROR_TIMER_START(name, value, max, scale,
-- paused, label) starts one, MIRROR_TIMER_STOP(name) ends it,
-- MIRROR_TIMER_PAUSE(name, paused) holds it; GetMirrorTimerProgress(name)
-- is where it stands, in milliseconds like value and max. A bar per
-- timer shows the label and the seconds left. While ours are on,
-- Blizzard's own bars are faded, not removed: off, they are back.
-------------------------------------------------------------------
local W, H, GAP = 180, 12, 4
local MAX = 3
local COLORS = {
    BREATH     = { 0.25, 0.60, 1.00 },
    EXHAUSTION = { 0.95, 0.80, 0.25 },
    FEIGNDEATH = { 0.95, 0.60, 0.30 },
}
local OTHER = { 0.75, 0.75, 0.80 }

local holder = ns.Holder("DeckUIForeverMirrorTimers", "Breath timers", W, MAX * H + (MAX - 1) * GAP,
    { "TOP", UIParent, "TOP", 0, -140 })
local bars, byName = {}, {}
local preview = false
local faded = false
local ev = CreateFrame("Frame")

local function On() return DeckUIForeverCombatDB.mirrorTimers and true or false end

-- Blizzard's bars: the container of the newer UI, or the three old frames
local function FadeBlizzard(on)
    if not on and not faded then return end
    faded = on
    local alpha = on and 0 or 1
    if _G.MirrorTimerContainer then _G.MirrorTimerContainer:SetAlpha(alpha) end
    for i = 1, MAX do
        local frame = _G["MirrorTimer" .. i]
        if frame then frame:SetAlpha(alpha) end
    end
end

local function Layout()
    local y = 0
    for _, bar in ipairs(bars) do
        if bar:IsShown() then
            bar:ClearAllPoints()
            bar:SetPoint("TOP", holder, "TOP", 0, -y)
            y = y + H + GAP
        end
    end
end

local function Free()
    for _, bar in ipairs(bars) do
        if not bar.timer then return bar end
    end
    if #bars >= MAX then return nil end
    local bar = ns.Bar(holder, W, H)
    bar:Hide()
    bars[#bars + 1] = bar
    return bar
end

local function Stop(name)
    local bar = byName[name]
    if not bar then return end
    byName[name] = nil
    bar.timer = nil
    bar:Hide()
    Layout()
end

local function Start(name, max, label)
    if ns.Secret(name) or type(name) ~= "string" or name == "UNKNOWN" then return end
    local bar = byName[name] or Free()
    if not bar then return end
    byName[name] = bar
    bar.timer = name
    local c = COLORS[name] or OTHER
    bar:SetStatusBarColor(c[1], c[2], c[3])
    if not pcall(bar.SetMinMaxValues, bar, 0, max) then bar:SetMinMaxValues(0, 1) end
    bar.left:SetText(label)   -- a FontString takes a secret text too
    bar.right:SetText("")
    bar:Show()
    Layout()
end

holder:SetScript("OnUpdate", function()
    if preview or not GetMirrorTimerProgress then return end
    for name, bar in pairs(byName) do
        local ok, value = pcall(GetMirrorTimerProgress, name)
        if ok then
            pcall(bar.SetValue, bar, value)
            if not ns.Secret(value) and type(value) == "number" then
                bar.right:SetText(ns.TimeText(math.max(0, value / 1000)))
            end
        end
    end
end)

-- the timers that run already (switched on mid-dive, or a /reload)
local function ReadRunning()
    if not GetMirrorTimerInfo then return end
    for i = 1, MAX do
        local ok, name, _, max, _, _, label = pcall(GetMirrorTimerInfo, i)
        if ok then Start(name, max, label) end
    end
end

ev:SetScript("OnEvent", function(_, event, name, _, max, _, _, label)
    if event == "MIRROR_TIMER_START" then
        Start(name, max, label)
    elseif event == "MIRROR_TIMER_STOP" then
        if not ns.Secret(name) then Stop(name) end
    else
        ReadRunning()
    end
end)

local function Apply()
    local on = On()
    FadeBlizzard(on)
    if on then
        pcall(ev.RegisterEvent, ev, "MIRROR_TIMER_START")
        pcall(ev.RegisterEvent, ev, "MIRROR_TIMER_STOP")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        holder:Show()
        ReadRunning()
    else
        ev:UnregisterAllEvents()
        for name in pairs(byName) do Stop(name) end
        holder:Hide()
    end
end

local function Preview(state)
    preview = state and On() or false
    if preview then
        local bar = byName.BREATH or Free()
        if bar then
            bar.sample = true
            local c = COLORS.BREATH
            bar:SetStatusBarColor(c[1], c[2], c[3])
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0.6)
            bar.left:SetText("Breath")
            bar.right:SetText("36")
            bar:Show()
        end
    else
        for _, bar in ipairs(bars) do
            if bar.sample then
                bar.sample = nil
                if not bar.timer then bar:Hide() end
            end
        end
        if On() then ReadRunning() end
    end
    Layout()
end

ns.pieces.mirror = {
    key = "Breath timers",
    Init = function() D.MakeMovable(holder, "Breath timers", DeckUIForeverCombatDB) end,
    Apply = Apply,
    Preview = Preview,
    Print = function()
        local running = {}
        for name in pairs(byName) do running[#running + 1] = name end
        print(("  breath timers: option %s, GetMirrorTimerProgress %s, Blizzard's faded %s, running: %s"):format(
            tostring(DeckUIForeverCombatDB.mirrorTimers), GetMirrorTimerProgress and "yes" or "no",
            tostring(faded), #running > 0 and table.concat(running, ", ") or "none"))
    end,
}
