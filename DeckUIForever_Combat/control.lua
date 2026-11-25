local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Loss of control: stunned, feared, silenced
-------------------------------------------------------------------
-- C_LossOfControl lists what holds you right now: per entry the icon,
-- the word for it ("Stunned"), its start and length, and a priority. The
-- one with the highest priority shows as an icon with the word beside it
-- and the time running on the icon. While ours is on, Blizzard's own
-- alert in the middle of the screen is faded, not removed.
--
-- Most of an entry may be secret (the priority never is): icon and word
-- go to the texture and the text as they come, the time to a cooldown
-- frame, which counts it down itself - nothing is read.
-------------------------------------------------------------------
local ICON = 44

local holder = ns.Holder("DeckUIForeverLossOfControl", "Loss of control", ICON + 150, ICON,
    { "CENTER", UIParent, "CENTER", 0, 110 })
holder:Hide()

local shade = holder:CreateTexture(nil, "BACKGROUND")
shade:SetPoint("TOPLEFT", -1, 1)
shade:SetSize(ICON + 2, ICON + 2)
shade:SetColorTexture(0, 0, 0, 0.9)

local icon = holder:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT")
icon:SetSize(ICON, ICON)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local cooldown = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
cooldown:SetAllPoints(icon)
cooldown:SetDrawEdge(false)
if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(false) end

local word = holder:CreateFontString(nil, "OVERLAY")
word:SetFont(D.FONT, 18, "OUTLINE")
word:SetPoint("LEFT", icon, "RIGHT", 8, 0)
word:SetTextColor(1, 0.35, 0.3)

local preview = false
local faded = false
local seen = { events = 0, shown = 0 }
local ev = CreateFrame("Frame")

local function On() return DeckUIForeverCombatDB.lossOfControl and true or false end

-- Blizzard's alert sets its own alpha whenever it comes up and while it
-- fades (owner's screenshot 2026-11-25: "Asleep" stood there twice, ours
-- and theirs), so one SetAlpha(0) does not last: a post-hook holds it at 0
-- while ours is on, and its OnShow is answered the same way.
local hooked = false
local function FadeBlizzard(on)
    local frame = _G.LossOfControlFrame
    if not on and not faded then return end
    faded = on
    if not frame then return end
    if on and not hooked then
        hooked = true
        hooksecurefunc(frame, "SetAlpha", function(self, alpha)
            if faded and alpha ~= 0 then self:SetAlpha(0) end
        end)
        frame:HookScript("OnShow", function(self)
            if faded then self:SetAlpha(0) end
        end)
    end
    frame:SetAlpha(on and 0 or 1)
end

-- the entry that weighs most, or nil
local function Worst()
    local api = C_LossOfControl
    if not (api and api.GetActiveLossOfControlDataCount and api.GetActiveLossOfControlData) then return nil end
    local ok, count = pcall(api.GetActiveLossOfControlDataCount)
    if not ok or ns.Secret(count) or type(count) ~= "number" then return nil end
    local best
    for i = 1, count do
        local got, data = pcall(api.GetActiveLossOfControlData, i)
        if got and type(data) == "table" then
            local priority = data.priority
            if ns.Secret(priority) or type(priority) ~= "number" then priority = 0 end
            if not best or priority > best.priority then best = { data = data, priority = priority, index = i } end
        end
    end
    if best then return best.data, best.index end
end

-- The time on the icon. The entry's start and length are secret for an
-- addon in a fight, and SetCooldown refuses them (owner's screenshot
-- 2026-11-25: the icon and "Asleep", no time). The game hands out a
-- duration object for the same entry, which a cooldown frame takes unread;
-- the plain numbers are the second way.
local timeBy = "none yet"
local function ShowTime(data, index)
    local api = C_LossOfControl
    if index and api.GetActiveLossOfControlDuration and cooldown.SetCooldownFromDurationObject then
        local got, object = pcall(api.GetActiveLossOfControlDuration, "player", index)
        if got and object ~= nil and pcall(cooldown.SetCooldownFromDurationObject, cooldown, object) then
            timeBy = "duration object"
            return true
        end
    end
    if data.startTime ~= nil and data.duration ~= nil
        and pcall(cooldown.SetCooldown, cooldown, data.startTime, data.duration) then
        timeBy = "start and length"
        return true
    end
    timeBy = "no way worked"
    return false
end

local function Update()
    if preview then return end
    local data, index
    if On() then data, index = Worst() end
    if not data then
        holder:Hide()
        return
    end
    seen.shown = seen.shown + 1
    icon:SetTexture(data.iconTexture)
    word:SetText(data.displayText)
    -- no length: it lasts until it is taken off, nothing to count
    cooldown:SetShown(ShowTime(data, index))
    holder:Show()
end

ev:SetScript("OnEvent", function()
    seen.events = seen.events + 1
    Update()
end)

local function Apply()
    local on = On()
    FadeBlizzard(on)
    if on then
        for _, event in ipairs({ "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "PLAYER_CONTROL_LOST",
            "PLAYER_CONTROL_GAINED", "PLAYER_ENTERING_WORLD" }) do
            pcall(ev.RegisterEvent, ev, event)
        end
    else
        ev:UnregisterAllEvents()
    end
    Update()
end

local function Preview(state)
    preview = state and On() or false
    if preview then
        icon:SetTexture("Interface\\Icons\\Spell_Frost_Stun")
        word:SetText("Stunned")
        cooldown:Hide()
        holder:Show()
    else
        Update()
    end
end

ns.pieces.control = {
    key = "Loss of control",
    Init = function() D.MakeMovable(holder, "Loss of control", DeckUIForeverCombatDB) end,
    Apply = Apply,
    Preview = Preview,
    Print = function()
        local count = C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount
            and select(2, pcall(C_LossOfControl.GetActiveLossOfControlDataCount))
        print(("  loss of control: option %s, C_LossOfControl %s, active now %s, events %d, shown %d, Blizzard's faded %s, time by %s"):format(
            tostring(DeckUIForeverCombatDB.lossOfControl), C_LossOfControl and "yes" or "no",
            ns.Secret(count) and "hidden by the game" or tostring(count), seen.events, seen.shown, tostring(faded), timeBy))
    end,
}
