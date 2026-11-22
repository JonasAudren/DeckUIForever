local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- DeckUIForever Combat (2026-11-21)
-------------------------------------------------------------------
-- Four small pieces of a fight that the game hands out and nothing of
-- ours showed yet, each on its own switch and movable on its own:
--   swing.lua    the swing timer (C_SwingTimer, PLAYER_SWING)
--   mirror.lua   breath, fatigue and feign death (the mirror timers)
--   control.lua  loss of control: stunned, feared, silenced
--   threat.lua   your threat on the target, in percent
-- What Forever offers was read in game with /df apis on 2026-11-21
-- (1.60.1, build 71037); the combat log is closed to addons there, so
-- everything here comes from the game's own functions and events.
--
-- This file: the settings, the bar every piece draws with, the start.
-- Each piece registers ns.pieces[name] = { Apply = fn, Print = fn }.
-- Untested in game at the time of writing.
-------------------------------------------------------------------
local DEFAULTS = {
    swingTimer    = true,    -- a bar per weapon that fills from swing to swing
    swingRange    = true,    -- ... red while the target is out of its reach
    mirrorTimers  = true,    -- breath, fatigue, feign death in our look, Blizzard's bars faded
    lossOfControl = true,    -- icon, name and time of what took your control, Blizzard's alert faded
    threat        = true,    -- your threat on the target as a bar with the percent
    threatSolo    = false,   -- ... also when you are alone (off: only in a group)
}

ns.pieces = {}
ns.WHITE = "Interface\\Buttons\\WHITE8x8"

function ns.Secret(v) return issecretvalue and issecretvalue(v) or false end

-- A flat bar in the look of the FF frames: a dark edge, a dark track, a
-- plain fill; `bar.left` and `bar.right` are its two texts.
function ns.Bar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(ns.WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 0.9)
    local track = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    track:SetAllPoints()
    track:SetColorTexture(0.1, 0.1, 0.12, 0.85)

    local text = CreateFrame("Frame", nil, bar)
    text:SetAllPoints()
    text:SetFrameLevel(bar:GetFrameLevel() + 2)
    local size = math.max(9, math.min(12, height + 1))
    bar.left = text:CreateFontString(nil, "OVERLAY")
    bar.left:SetFont(D.FONT, size, "OUTLINE")
    bar.left:SetPoint("LEFT", 3, 0)
    bar.right = text:CreateFontString(nil, "OVERLAY")
    bar.right:SetFont(D.FONT, size, "OUTLINE")
    bar.right:SetPoint("RIGHT", -3, 0)
    return bar
end

-- "1:05" from a minute up, "4.2" below ten seconds, else whole seconds
function ns.TimeText(left)
    if left >= 60 then return ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60)) end
    if left < 10 then return ("%.1f"):format(left) end
    return ("%d"):format(left)
end

-- a holder with its default place; `key` is the name it is moved by
function ns.Holder(name, key, width, height, point)
    local holder = CreateFrame("Frame", name, UIParent)
    holder:SetSize(width, height)
    holder.defaultPoint = point
    holder:SetPoint(unpack(point))
    holder.moveKey = key
    return holder
end

-- every piece again: a switch was flipped
function ns.Apply()
    for _, piece in pairs(ns.pieces) do
        if piece.Apply then piece.Apply() end
    end
end

-------------------------------------------------------------------
-- Startup (normal login and load on demand from the menu)
-------------------------------------------------------------------
local ready = false

local function Init()
    if ready then return end
    ready = true
    DeckUIForeverCombatDB = DeckUIForeverCombatDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckUIForeverCombatDB[k] == nil then DeckUIForeverCombatDB[k] = v end
    end
    for _, piece in pairs(ns.pieces) do
        if piece.Init then piece.Init() end
    end
    -- unlocked, every piece shows a sample of itself
    D.OnUnlock(function(state, only)
        for _, piece in pairs(ns.pieces) do
            if piece.Preview then
                piece.Preview(state and (not only or only[piece.key]) and true or false)
            end
        end
    end)
    ns.Apply()
end

local ev = CreateFrame("Frame")
if IsLoggedIn() then
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", Init)
end

-- /df combat
function D.PrintCombat()
    print("DeckUIForever Combat:")
    for _, name in ipairs({ "swing", "mirror", "control", "threat" }) do
        local piece = ns.pieces[name]
        if piece and piece.Print then piece.Print() end
    end
end
