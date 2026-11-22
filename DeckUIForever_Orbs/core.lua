local ADDON, ns = ...
local D = DeckUIForever

ns.DISC = D.DISC
ns.FONT = D.FONT

-- oUF's Spawn silences Blizzard's frame of that unit (DisableBlizzard).
-- With showPlayer / showTarget off (layout.lua) Blizzard's frame, or another
-- addon's, is meant to stay - but the buff bar and the party and raid test
-- frames are spawned on "player", the boss test frames on "target", and
-- took it away all the same (module check 2026-11-17). They spawn through
-- this: with the unit's switch off, DisableBlizzard does nothing for the
-- length of that one Spawn.
function ns.SpawnQuiet(unit, name)
    local oUF = ns.oUF
    local db = DeckUIForeverOrbsDB or {}
    local keepBlizzard = (unit == "player" and db.showPlayer == false)
        or (unit == "target" and db.showTarget == false)
    if not keepBlizzard then return oUF:Spawn(unit, name) end
    local disable = oUF.DisableBlizzard
    oUF.DisableBlizzard = function() end
    local ok, frame = pcall(oUF.Spawn, oUF, unit, name)
    oUF.DisableBlizzard = disable
    if not ok then error(frame, 0) end
    return frame
end

-- The countdown numbers a Cooldown frame writes on an aura icon come in a
-- font the client picks from the frame's size, and Forever picks a big
-- one: "50m" filled a 22 px status icon (owner, 2026-11-05). The icons
-- now hand their cooldown a font of our own, sized to the icon - one
-- font object per size, made once.
local countdownFonts = {}
function ns.CountdownFont(size)
    local px = math.max(7, math.floor(size * 0.42 + 0.5))
    local name = "DeckUIForeverOrbsCountdown" .. px
    if not countdownFonts[px] then
        local font = CreateFont(name)
        font:SetFont(ns.FONT, px, "OUTLINE")
        font:SetTextColor(1, 1, 1)
        countdownFonts[px] = font
    end
    return name
end

-- the icon's cooldown writes its numbers in that font (nothing to do
-- where the numbers are hidden, buffs.lua and raid.lua)
function ns.StyleCountdown(button)
    local cd = button.Cooldown
    if cd and cd.SetCountdownFont then
        cd:SetCountdownFont(ns.CountdownFont(button:GetWidth() or 20))
    end
end
-- the aura containers' layout axes
ns.FLOW = AnchorUtil.FlowLayoutAxis

ns.GLOW  = 0
ns.glows = {}

local function AddGlow(bar, mask)
    local glow = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    glow:SetAllPoints(bar:GetStatusBarTexture())
    glow:SetColorTexture(1, 1, 1, ns.GLOW)
    glow:SetBlendMode("ADD")
    glow:AddMaskTexture(mask)
    table.insert(ns.glows, glow)
    return glow
end

function ns.SetGlow(value)
    ns.GLOW = value
    for _, glow in ipairs(ns.glows) do
        glow:SetColorTexture(1, 1, 1, value)
    end
end

-- A round, vertically filling bar with a dark disc behind it: the orb
-- itself sits above its ring, which shows through as the outer band.
local function RoundBar(parent, size, levelOffset, bgShade, bgAlpha)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(size, size)
    bar:SetPoint("CENTER")
    bar:SetFrameLevel(parent:GetFrameLevel() + levelOffset)
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

    local mask = D.RoundMask(bar)
    bar:GetStatusBarTexture():AddMaskTexture(mask)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(bgShade, bgShade, bgShade, bgAlpha)
    bg:AddMaskTexture(mask)

    AddGlow(bar, mask)
    return bar
end

-- Incoming heals on a health bar (GitHub issue 1, 2026-11-17; option
-- healPrediction, off, /reload): a lighter bar that starts where the
-- health's fill ends and is as long as the heals being cast are worth.
-- The game's own number fills it, read the way Blizzard's player frame
-- reads it (Blizzard_UnitFrame/Mainline/UnitFrame.lua in Forever):
-- UnitGetIncomingHeals(unit) on UNIT_HEAL_PREDICTION, handed straight to
-- the bar - it may be secret, a StatusBar takes that. A mask as big as
-- the health bar cuts every piece, so a heal larger than the missing
-- health ends with the bar without any arithmetic. `shape` cuts the
-- texture like the bar's own (a PillBar's caps, the orb's disc).
--
-- Three pieces lie on top of each other, in one colour, so that any of
-- them alone is enough:
-- 1. oUF's (Health.HealingAll, from UnitGetDetailedHealPrediction and the
--    heal prediction calculator) - 1.5.4's only one. The owner saw it in
--    game; a reporter did not, for a Healing Wave on himself (issue 1,
--    2026-11-18). Taking it out on 2026-11-21 lost the owner's piece -
--    keep it.
-- 2. healNative: UnitGetIncomingHeals read directly, as Blizzard does.
-- 3. healEstimate, below.
-- No clipping frame: with all pieces inside one (2026-11-21) the owner
-- saw none of them. `/orbs heals` prints what each source says.
--
-- A fallback for the heal you are casting yourself, where the game
-- reports nothing readable above 0: a second bar in the
-- same place shows our own estimate for the player's cast: the target's
-- name from UNIT_SPELLCAST_SENT, the amount from the numbers in the
-- spell's description ("... for 36 to 47" - the middle of the first
-- range), from UNIT_SPELLCAST_START until the cast ends. The same mask
-- ends it with the bar (the missing health can be secret, the mask
-- needs no number). Where the game does report the heal in a
-- readable number the estimate stays away; where that number is secret
-- both draw on top of each other from the same start. Heals of others
-- come from the game's prediction alone. `/orbs heals` reports each cast.
local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local predicted = {}   -- the health bars that carry a prediction
local sent             -- the last cast sent: { name, guid }
local ownCast          -- the heal being cast: { guid, name, amount, spell }
local healDebug = false
local watcher

-- "heal" in the client's languages; a description without it is no heal
-- (a resurrection has numbers too, and "health" - hence the pattern)
local HEAL_WORDS = { "heal[^t]", "heil", "soign", "sana", "cura", "сцел",
    "치유", "治疗", "治療" }

local function Number(s) return tonumber((s:gsub("[%.,]", ""))) end

local function HealAmount(spellID)
    local text = C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID)
    if text == nil and GetSpellDescription then text = GetSpellDescription(spellID) end
    if Secret(text) or type(text) ~= "string" or text == "" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local low = text:lower()
    local heal = false
    for _, word in ipairs(HEAL_WORDS) do
        if low:find(word) then heal = true break end
    end
    if not heal then return nil end
    local _, last, first = text:find("(%d[%d%.,]*)")
    local a = first and Number(first)
    if not a or a <= 0 then return nil end
    local gap, second = text:match("^(%D-)(%d[%d%.,]*)", last + 1)
    local b = second and #gap <= 8 and Number(second)
    if b and b >= a and b <= a * 2 then return (a + b) / 2 end
    return a
end

local function CastIsOn(unit)
    if not ownCast or not UnitExists(unit) then return false end
    local name = UnitName(unit)
    if Secret(name) or not name then return false end
    if name == ownCast.name then return true end
    local full = GetUnitName and GetUnitName(unit, true)
    if Secret(full) or not full then return false end
    return full == ownCast.name
end

-- the unit a bar stands for: oUF's, or the one a bar of our own was given
local function UnitOf(health)
    return health.healUnit or (health.__owner and health.__owner.unit)
end

local function PaintEstimate(health)
    local bar = health.healEstimate
    local unit = UnitOf(health)
    local amount = 0
    if unit and CastIsOn(unit) then
        amount = ownCast.amount
        local native = UnitGetIncomingHeals and UnitGetIncomingHeals(unit)
        if not Secret(native) and type(native) == "number" and native > 0 then
            amount = 0   -- the game draws this one itself
        end
    end
    if amount <= 0 then bar:Hide() return end
    if health:GetOrientation() == "VERTICAL" then
        bar:SetHeight(health:GetHeight())
    else
        bar:SetWidth(health:GetWidth())
    end
    if not pcall(bar.SetMinMaxValues, bar, 0, UnitHealthMax(unit)) then bar:Hide() return end
    bar:SetValue(amount)
    bar:Show()
end

-- the game's number, as Blizzard's frames read it
local function PaintNative(health)
    local bar = health.healNative
    local unit = UnitOf(health)
    if not unit or not UnitGetIncomingHeals or not UnitExists(unit) then bar:Hide() return end
    local heal = UnitGetIncomingHeals(unit)
    if not Secret(heal) and type(heal) ~= "number" then heal = 0 end
    if health:GetOrientation() == "VERTICAL" then
        bar:SetHeight(health:GetHeight())
    else
        bar:SetWidth(health:GetWidth())
    end
    if not pcall(bar.SetMinMaxValues, bar, 0, UnitHealthMax(unit))
        or not pcall(bar.SetValue, bar, heal) then
        bar:Hide()
        return
    end
    bar:Show()
end

-- the calculator's number, for a bar that is not oUF's (there oUF's own
-- HealingAll is this piece): asked the way oUF asks
local function PaintCalc(health)
    local bar = health.healCalc
    if not bar then return end
    local unit = UnitOf(health)
    if not unit or not UnitExists(unit)
        or not (CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction) then
        bar:Hide()
        return
    end
    health.healValues = health.healValues or CreateUnitHealPredictionCalculator()
    local values = health.healValues
    if health:GetOrientation() == "VERTICAL" then
        bar:SetHeight(health:GetHeight())
    else
        bar:SetWidth(health:GetWidth())
    end
    local ok = pcall(function()
        UnitGetDetailedHealPrediction(unit, "player", values)
        bar:SetMinMaxValues(0, values:GetMaximumHealth())
        bar:SetValue((values:GetIncomingHeals()))
    end)
    bar:SetShown(ok)
end

local function Paint(health)
    if health.healOff then
        health.healNative:Hide()
        health.healEstimate:Hide()
        if health.healCalc then health.healCalc:Hide() end
        return
    end
    PaintNative(health)
    PaintEstimate(health)
    PaintCalc(health)
end
ns.HealPaint = Paint   -- for a bar made with ns.HealPieces

local function PaintAll()
    for _, health in ipairs(predicted) do Paint(health) end
end

-- what the calculator says, the way oUF asked in 1.5.4 (for /orbs heals)
local calculator
local function CalculatorHeals(unit)
    if not (CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction) then return "no calculator" end
    calculator = calculator or CreateUnitHealPredictionCalculator()
    local ok, all = pcall(function()
        UnitGetDetailedHealPrediction(unit, "player", calculator)
        return (calculator:GetIncomingHeals())
    end)
    if not ok then return "error" end
    return all
end

local function Report(v)
    if Secret(v) then return "hidden by the game" end
    return tostring(v)
end

local function ReportCast(spellID)
    print(("DeckUIForever Orbs heals: spell %s, on %s, our estimate %s"):format(Report(spellID),
        ownCast and tostring(ownCast.name) or "-", ownCast and tostring(ownCast.amount) or "none (no heal read)"))
    for _, health in ipairs(predicted) do
        local unit = UnitOf(health)
        if unit and UnitExists(unit) and not health.healOff then
            print(("  %s: the game reports %s (yours alone %s, the calculator %s), its piece %s, our estimate's piece %s"):format(unit,
                Report(UnitGetIncomingHeals and UnitGetIncomingHeals(unit)),
                Report(UnitGetIncomingHeals and UnitGetIncomingHeals(unit, "player")),
                Report(CalculatorHeals(unit)),
                health.healNative:IsShown() and "shown" or "not shown",
                health.healEstimate:IsShown() and "shown" or "not shown"))
        end
    end
end

local function OnCastEvent(_, event, unit, a, b)
    if event == "UNIT_SPELLCAST_SENT" then
        -- unit, target name, cast GUID, spell
        sent = { name = not Secret(a) and a or nil, guid = not Secret(b) and b or nil }
        return
    elseif event == "UNIT_SPELLCAST_START" then
        -- unit, cast GUID, spell
        ownCast = nil
        local amount = not Secret(b) and b and HealAmount(b)
        if amount then
            local guid = not Secret(a) and a or nil
            local name = sent and (not sent.guid or not guid or sent.guid == guid) and sent.name
            if not name or name == "" then
                -- no name came with the cast: the friendly target, or yourself
                local friend = UnitExists("target") and UnitIsFriend("player", "target")
                name = UnitName(not Secret(friend) and friend and "target" or "player")
            end
            if not Secret(name) and name then
                ownCast = { guid = guid, name = name, amount = amount, spell = b }
            end
        end
        if healDebug and C_Timer then
            C_Timer.After(0.3, function() ReportCast(b) end)
        end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        -- a key pressed during the cast fails with a cast of its own
        if ownCast and ownCast.guid and not Secret(a) and a == ownCast.guid then ownCast = nil end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_SUCCEEDED" then
        if ownCast and (not ownCast.guid or Secret(a) or a == ownCast.guid) then ownCast = nil end
    end
    PaintAll()
end

-- everyone: also the heal prediction of units beyond player and target
-- (the HoT window's lines)
local watchingAll = false
local function WatchCasts(everyone)
    if everyone and watcher and not watchingAll then
        watchingAll = true
        pcall(watcher.UnregisterEvent, watcher, "UNIT_HEAL_PREDICTION")
        pcall(watcher.RegisterEvent, watcher, "UNIT_HEAL_PREDICTION")
    end
    if watcher then return end
    watcher = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED" }) do
        pcall(watcher.RegisterUnitEvent, watcher, event, "player")
    end
    for _, event in ipairs({ "UNIT_HEAL_PREDICTION", "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
        pcall(watcher.RegisterUnitEvent, watcher, event, "player", "target")
    end
    pcall(watcher.RegisterEvent, watcher, "PLAYER_ENTERING_WORLD")
    pcall(watcher.RegisterEvent, watcher, "PLAYER_TARGET_CHANGED")
    watcher:SetScript("OnEvent", OnCastEvent)
    if everyone then WatchCasts(true) end
end

-- one lighter bar ahead of the health's fill, as long as the health bar
local function HealBar(parent, health, shape)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(0.6, 1, 0.7, 0.85)   -- nearly solid: pieces on top of each other look like one
    local fill = health:GetStatusBarTexture()
    if health:GetOrientation() == "VERTICAL" then
        bar:SetOrientation("VERTICAL")
        bar:SetPoint("LEFT", health, "LEFT")
        bar:SetPoint("RIGHT", health, "RIGHT")
        bar:SetPoint("BOTTOM", fill, "TOP")
        bar:SetHeight(health:GetHeight())
    else
        bar:SetPoint("TOP", health, "TOP")
        bar:SetPoint("BOTTOM", health, "BOTTOM")
        bar:SetPoint("LEFT", fill, "RIGHT")
        bar:SetWidth(health:GetWidth())
    end
    if shape then shape(bar:GetStatusBarTexture()) end
    return bar
end

function ns.HealPrediction(health, shape)
    if not (DeckUIForeverOrbsDB and DeckUIForeverOrbsDB.healPrediction) then return end
    -- a mask as big as the health bar ends every piece with the bar
    local cut = health:CreateMaskTexture()
    cut:SetTexture("Interface\\Buttons\\WHITE8x8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    cut:SetAllPoints(health)
    local function Piece()
        local piece = HealBar(health, health, shape)
        piece:GetStatusBarTexture():AddMaskTexture(cut)
        return piece
    end

    -- oUF's piece: the one the owner saw working in game
    local bar = Piece()
    health.HealingAll = bar
    health.incomingHealOverflow = 1

    local native = Piece()
    native:Hide()
    health.healNative = native
    local estimate = Piece()
    estimate:Hide()
    health.healEstimate = estimate
    predicted[#predicted + 1] = health
    WatchCasts()
    return bar
end

-- The same pieces on a health bar of our own, not oUF's (the HoT window's
-- lines, option hotHeals, 2026-11-21): `unit` is the bar's unit. The
-- calculator's piece is ours here (healCalc), there is no oUF behind the
-- bar. The caller paints with ns.HealPaint(health) when the health
-- changes and sets health.healOff to take the pieces away.
function ns.HealPieces(health, shape, unit)
    local cut = health:CreateMaskTexture()
    cut:SetTexture("Interface\\Buttons\\WHITE8x8","CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    cut:SetAllPoints(health)
    local function Piece()
        local piece = HealBar(health, health, shape)
        piece:GetStatusBarTexture():AddMaskTexture(cut)
        piece:Hide()
        return piece
    end
    health.healUnit = unit
    health.healCalc = Piece()
    health.healNative = Piece()
    health.healEstimate = Piece()
    predicted[#predicted + 1] = health
    WatchCasts(true)
end

-- /orbs heals: what is set up, and a report for every cast from now on
function ns.HealDebug()
    healDebug = not healDebug
    print(("DeckUIForever Orbs heals: option %s, health bars with a prediction %d"):format(
        (DeckUIForeverOrbsDB and DeckUIForeverOrbsDB.healPrediction) and "on" or "off (Frames - Unit frames)",
        #predicted))
    print(("  the game offers: UnitGetIncomingHeals %s, the heal calculator %s"):format(
        UnitGetIncomingHeals and "yes" or "no", CreateUnitHealPredictionCalculator and "yes" or "no"))
    if healDebug then
        print("  Cast a heal now: every cast prints what the game reports and what we estimate. /orbs heals again stops it.")
    else
        print("  The cast report is off.")
    end
end

function ns.CreateOrb(parent, size) return RoundBar(parent, size, 2, 0.08, 1) end
function ns.CreateRing(parent, size) return RoundBar(parent, size, 1, 0.1, 0.9) end

function ns.CreateCastOverlay(orb, size)
    local bar = CreateFrame("StatusBar", nil, orb)
    bar:SetSize(size, size)
    bar:SetPoint("CENTER", orb, "CENTER")
    bar:SetFrameLevel(orb:GetFrameLevel() + 1)
    bar:SetOrientation("HORIZONTAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(1, 0.85, 0.3, 0.55)

    local mask = D.RoundMask(bar)
    bar:GetStatusBarTexture():AddMaskTexture(mask)

    return bar
end
