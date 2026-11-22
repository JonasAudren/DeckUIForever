local D = DeckUIForever

-------------------------------------------------------------------
-- Totem timers (GitHub issue 2, 2026-11-21)
-------------------------------------------------------------------
-- A shaman's standing totems as a small row of icons, each with the
-- time it has left: fire, earth, water, air, always in that place, so
-- an element is found without looking. A slot without a totem shows
-- nothing. Option totemTimers (off), shamans only, movable ("Totem
-- timers", Screen page). It lives in the hub, not in Bars: the reporter
-- plays with another action bar addon.
--
-- The game tells it all: GetTotemInfo(slot) gives the totem, its start,
-- its length and its icon, PLAYER_TOTEM_UPDATE fires when one is set,
-- replaced, recalled, destroyed or runs out. Slots: 1 fire, 2 earth,
-- 3 water, 4 air. Nothing of Blizzard's Forever UI calls these (its
-- TotemFrame is not loaded for this game), so every call is guarded and
-- /df totems prints what the game answers.
--
-- The numbers may be secret (the API's documentation allows it). Then
-- the icon, the cooldown sweep and the game's own countdown numbers are
-- fed without us reading anything; with plain numbers we write the time
-- ourselves ("1:42", seconds alone under a minute).
--
-- The owner plays a priest: untested with real totems.
-------------------------------------------------------------------
local SIZE, GAP, TEXT_H = 34, 6, 14
local ELEMENTS = {
    { name = "Fire",  color = { 0.95, 0.45, 0.20 }, sample = "Interface\\Icons\\Spell_Fire_SearingTotem" },
    { name = "Earth", color = { 0.60, 0.80, 0.30 }, sample = "Interface\\Icons\\Spell_Nature_StoneSkinTotem" },
    { name = "Water", color = { 0.30, 0.65, 1.00 }, sample = "Interface\\Icons\\INV_Spear_04" },
    { name = "Air",   color = { 0.75, 0.62, 0.95 }, sample = "Interface\\Icons\\Spell_Nature_Windfury" },
}

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local row = CreateFrame("Frame", "DeckUIForeverTotemTimers", UIParent)
row:SetSize(#ELEMENTS * SIZE + (#ELEMENTS - 1) * GAP, SIZE + TEXT_H)
row.defaultPoint = { "CENTER", UIParent, "CENTER", 0, -170 }
row:SetPoint(unpack(row.defaultPoint))
row:Hide()

local buttons = {}
local preview = false
local active = false

local function Button(slot)
    local element = ELEMENTS[slot]
    local b = CreateFrame("Frame", nil, row)
    b:SetSize(SIZE, SIZE)
    b:SetPoint("TOPLEFT", (slot - 1) * (SIZE + GAP), 0)
    b.slot = slot

    local shade = b:CreateTexture(nil, "BACKGROUND")
    shade:SetPoint("TOPLEFT", -1, 1)
    shade:SetPoint("BOTTOMRIGHT", 1, -1)
    shade:SetColorTexture(0, 0, 0, 0.8)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- the sweep: dark over the part of the time that is gone
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    b.cooldown:SetDrawEdge(false)
    if b.cooldown.SetReverse then b.cooldown:SetReverse(false) end
    if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(true) end

    -- a line in the element's colour under the icon
    local line = b:CreateTexture(nil, "OVERLAY")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(2)
    line:SetColorTexture(element.color[1], element.color[2], element.color[3], 1)

    b.time = b:CreateFontString(nil, "OVERLAY")
    b.time:SetFont(D.FONT, 12, "OUTLINE")
    b.time:SetPoint("TOP", b, "BOTTOM", 0, -2)

    b:Hide()
    return b
end

local function TimeText(left)
    if left >= 60 then
        return ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
    end
    return ("%d"):format(math.ceil(left))
end

local function SetTime(b, left)
    b.time:SetText(TimeText(left))
    if left < 10 then
        b.time:SetTextColor(1, 0.35, 0.3)
    else
        b.time:SetTextColor(1, 1, 1)
    end
end

-- haveTotem, name, start, duration, icon - or nothing where the game has no answer
local function Read(slot)
    if not GetTotemInfo then return end
    local ok, have, name, start, duration, icon = pcall(GetTotemInfo, slot)
    if not ok then return end
    return have, name, start, duration, icon
end

local function ShowSample(b)
    b.secret, b.ends = false, nil
    b.icon:SetTexture(ELEMENTS[b.slot].sample)
    b.cooldown:Hide()
    b.time:SetText("1:42")
    b.time:SetTextColor(1, 1, 1)
    b:SetAlpha(1)
    b:Show()
end

local function Paint(b)
    local have, _, start, duration, icon = Read(b.slot)
    if Secret(have) or Secret(start) or Secret(duration) then
        -- nothing to read: hand everything on as it comes
        b.secret, b.ends = true, nil
        b.icon:SetTexture(icon)
        b.time:SetText("")
        local object = GetTotemDuration and select(2, pcall(GetTotemDuration, b.slot))
        if object and b.cooldown.SetCooldownFromDurationObject
            and pcall(b.cooldown.SetCooldownFromDurationObject, b.cooldown, object) then
            if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(false) end
            b.cooldown:Show()
        else
            b.cooldown:Hide()
        end
        if b.SetAlphaFromBoolean then
            b:SetAlphaFromBoolean(have, 1, 0)
        else
            b:SetAlpha(1)
        end
        b:Show()
        return
    end
    b.secret = false
    if have and type(start) == "number" and type(duration) == "number" and duration > 0 then
        b.ends = start + duration
        b.icon:SetTexture(icon)
        if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(true) end
        b.cooldown:SetCooldown(start, duration)
        b.cooldown:Show()
        b:SetAlpha(1)
        SetTime(b, math.max(0, b.ends - GetTime()))
        b:Show()
    elseif preview then
        ShowSample(b)
    else
        b.ends = nil
        b:Hide()
    end
end

local function PaintAll()
    for _, b in ipairs(buttons) do Paint(b) end
end

-- the written time, ten times a second; a totem whose time is up goes
-- at once, the game's event may come a moment later
local since = 0
row:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.1 then return end
    since = 0
    local now = GetTime()
    for _, b in ipairs(buttons) do
        if b.ends and b:IsShown() then
            local left = b.ends - now
            if left <= 0 then
                Paint(b)
            else
                SetTime(b, left)
            end
        end
    end
end)

local ev = CreateFrame("Frame")

local function IsShaman()
    local _, class = UnitClass("player")
    return class == "SHAMAN"
end
D.TotemTimersAvailable = IsShaman

function D.ApplyTotemTimers()
    local on = DeckUIForeverDB.totemTimers and IsShaman() and true or false
    active = on
    if on then
        if #buttons == 0 then
            for slot = 1, #ELEMENTS do buttons[slot] = Button(slot) end
        end
        pcall(ev.RegisterEvent, ev, "PLAYER_TOTEM_UPDATE")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        row:Show()
        PaintAll()
    else
        pcall(ev.UnregisterEvent, ev, "PLAYER_TOTEM_UPDATE")
        ev:UnregisterEvent("PLAYER_ENTERING_WORLD")
        row:Hide()
    end
end

ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        D.MakeMovable(row, "Totem timers", DeckUIForeverDB)
        D.OnUnlock(function(state, only)
            if only and not only["Totem timers"] then state = false end
            preview = state and true or false
            if active then PaintAll() end
        end)
        D.ApplyTotemTimers()
    elseif active then
        PaintAll()
    end
end)

-- /df totems
local function Report(v)
    if Secret(v) then return "hidden by the game" end
    return tostring(v)
end

function D.PrintTotems()
    print(("DeckUIForever totem timers: option %s, shaman %s, running %s"):format(
        tostring(DeckUIForeverDB.totemTimers), tostring(IsShaman()), tostring(active)))
    print(("  the game offers: GetTotemInfo %s, GetTotemTimeLeft %s, GetTotemDuration %s"):format(
        GetTotemInfo and "yes" or "no", GetTotemTimeLeft and "yes" or "no", GetTotemDuration and "yes" or "no"))
    for slot, element in ipairs(ELEMENTS) do
        local have, name, start, duration, icon = Read(slot)
        local b = buttons[slot]
        print(("  %d %s: totem %s, name %s, start %s, length %s, icon %s, shown %s"):format(slot, element.name,
            Report(have), Report(name), Report(start), Report(duration), Report(icon),
            tostring(b and b:IsShown() or false)))
    end
end
