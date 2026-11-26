local ADDON, ns = ...
local D = DeckUIForever
local oUF = ns.oUF

-------------------------------------------------------------------
-- Deck Heal: healing with the controller, no mouse and no target change
-------------------------------------------------------------------
-- Owner 2026-11-11, after the question how the HoT window could serve a
-- healer on the Deck better ("bauen als Option und Unterfenster von HoTs:
-- DeckHeal oder so ... alles muss ausschaltbar sein"). The HoT window's
-- click to cast needs the trackpad; this is the same idea for the pad.
--
-- A key of the player's choice (the binding "Deck Heal: healing layer", a
-- CLICK binding in the hub's Bindings.xml - on the Deck a back paddle that
-- Steam Input sends as a keyboard key) switches a layer on while it is
-- held: the D-pad then picks a party member and the four face buttons
-- cast four spells on the picked member. The target is never touched.
-- Letting go hands every key back.
--
-- Who the D-pad picks goes by role (owner 2026-11-16, after his first
-- instance on the Deck: "nur L druecken der Tank ... L + Dpad links Heiler
-- und oben rechts unten die DDs in der Reihenfolge 1 2 3"): the layer
-- starts on the tank (on you in a group without one), left is the healer,
-- up, right, down the damage dealers in the HoT window's order (you, then
-- party1-4). The direction of the picked member pressed again goes back
-- to the tank. The restricted environment cannot read roles, so Assign
-- works the five places out in plain code and ApplyPicks writes them into
-- the buttons out of a fight; a role or roster change in a fight lands
-- after it. A group without roles: you, then party1-3 on up, right, down
-- and party4 on left - what it was before.
--
-- All of it is secure code, so it works in a fight:
--   DeckHealLayer    SecureHandlerClickTemplate, what the binding clicks.
--                    Its snippet lays the eight pad keys on our buttons as
--                    priority override bindings (key down) and clears them
--                    (key up; with padHealToggle each press switches).
--   DeckHealPick1-4  SecureHandlerClickTemplate: the snippet writes the
--                    member's token into the four cast buttons' `unit`.
--   DeckHealCast1-4  SecureActionButtonTemplate, type spell. The spell is
--                    set by us out of a fight only (ApplySpells); the unit
--                    changes in the restricted environment alone.
-- None of them is a child of the HoT window, so the window is not
-- protected by this and the layer runs with the window off as well.
--
-- What shows is ours and unprotected, driven from the snippets through
-- CallMethod: a small bar (the picked member's name, the four spells with
-- their keys; padHealBar, movable "Deck Heal") and a gold frame around
-- the picked member's line in the HoT window (padHealFrame; made out of a
-- fight as a child of the line, alpha only afterwards - the line may be
-- protected by the click-to-cast mode).
--
-- Keys, all off or harmless until padHeal is ticked: padHeal (the layer
-- itself; off, nothing is even created), padHealToggle (press to switch
-- instead of hold), padHealSpells (up to four names or IDs between commas,
-- eight with padHealR; empty: ns.HotLayerSpells picks), padHealBar, padHealFrame,
-- padHealCockpit, padHealFeedback, padHealRound (all on; see their sections),
-- padHealAim (on: the game's aiming at friends runs while the key is held),
-- padHealModifier (on: in the gamepad style the friend-targeting button,
-- L, is the layer's key - see `hold` below).
-- /orbs deckheal prints what the layer saw.
--
-- A second set of four (padHealR, on since 1.5.3 - as padHealSecond it was
-- off, and the owner's first instance had no second set; owner 2026-11-12 after the
-- first Deck test: "die restlichen Heilungen auch noch drauf bekommen",
-- R as the switch). Eight cast buttons instead of four; while the layer is
-- on, the other shoulder button (R, Blizzard's enemy-target modifier)
-- clicks DeckHealShift, a SecureHandlerClickTemplate whose snippet lays
-- A, X, Y, B on the casts 5-8 while it is held and back on 1-4 when it
-- is let go. The bindings are the layer's, so letting go of L clears them
-- all; every start of the layer is the first set. Without L, R is the
-- game's as ever.
--
-- UNTESTED IN GAME, and three things only the game answers: whether
-- Forever lets a secure handler set bindings in a fight, whether a
-- priority override binding beats Blizzard's gamepad action bar, and
-- whether the binding's key-up reaches the handler (if not: padHealToggle).
-------------------------------------------------------------------
local SLOTS = 4         -- the face buttons, and the spells of one set
local SETS = 2          -- with padHealR: a second set while R is held
local BINDING = "CLICK DeckHealLayer:LeftButton"
local ICON, NAME_W, PAD, GAP = 26, 92, 6, 8
local AURA, HOTS_MAX = 20, 3   -- the cockpit's aura icons: your HoTs on the picked member, one debuff to remove
local COCKPIT_W = 10 + (AURA + 4) + HOTS_MAX * (AURA + 2)
local BAR_W = PAD + NAME_W + SLOTS * (ICON + GAP) + PAD - GAP + 4
local ROUND_KEY, TEST_ROUND = "PADRSTICK", "6"   -- the round's key while the layer is on: the right stick's click
local GOLD = { 1, 0.82, 0.3 }
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- the D-pad directions: up, right, down the damage dealers 1-3, left the
-- healer (Assign); glyph is Blizzard's name for the key's picture
local PICKS = {
    { key = "PADDUP",    glyph = GAMEPAD_DPAD_TOP,    what = "damage 1" },
    { key = "PADDRIGHT", glyph = GAMEPAD_DPAD_RIGHT,  what = "damage 2" },
    { key = "PADDDOWN",  glyph = GAMEPAD_DPAD_BOTTOM, what = "damage 3" },
    { key = "PADDLEFT",  glyph = GAMEPAD_DPAD_LEFT,   what = "healer" },
}
-- the face buttons in the order of the spells: bottom, left, top, right
-- (A, X, Y, B on the Deck); glyph is Blizzard's name for the key's picture
local CASTS = {
    { key = "PAD1", glyph = GAMEPAD_FACE_BOTTOM, short = "A" },
    { key = "PAD3", glyph = GAMEPAD_FACE_LEFT,   short = "X" },
    { key = "PAD4", glyph = GAMEPAD_FACE_TOP,    short = "Y" },
    { key = "PAD2", glyph = GAMEPAD_FACE_RIGHT,  short = "B" },
}
local UNITS = { "player", "party1", "party2", "party3", "party4" }

local function Secret(v) return issecretvalue and issecretvalue(v) or false end
local function Opt(key) return DeckUIForeverOrbsDB[key] and true or false end
local function Wanted(key) return DeckUIForeverOrbsDB[key] ~= false end   -- a switch that is on by default

local layer            -- DeckHealLayer, made the first time the option is on
local picks, casts = {}, {}
local spells = {}      -- what the four buttons cast: { name, id, icon }
local unknown = {}     -- what of padHealSpells the game did not know
local seen = { down = 0, up = 0, picks = 0, casts = 0 }   -- for /orbs deckheal
local previewing = false
-- who the layer starts on and who each direction picks (Assign)
local assigned = { home = "player" }

-- The friend-targeting button as the layer's key (padHealModifier, on;
-- owner's first Deck test 2026-11-12: no key of his own bound, he held L -
-- Blizzard's friendly target modifier - used the D-pad and found "die Heal
-- Tasten gehen nicht": under that modifier A/X/Y/B are Blizzard's target
-- self / pet / assist / marker). The modifier is a plain binding
-- (GAMEPADLEFTTARGETMODIFIER in Blizzard_Gamepad/Bindings.xml), so a
-- priority override on its key clicks our layer instead and Blizzard's
-- friendly targeting bar never opens while Deck Heal is on. `hold` owns
-- that override: the layer's own ClearBindings must not take it away.
local hold = CreateFrame("Frame")
local holdKeys = {}
-- the keyboard's stand-ins while the hub's Deck test runs (D.DeckTestOn)
local TEST_HOLD = "TAB"
local TEST_PICKS = { "UP", "RIGHT", "DOWN", "LEFT" }
local TEST_CASTS = { "1", "2", "3", "4" }
local TEST_SHIFT = "5"

local function GamepadStyle()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
end

local function FriendKeys()
    local ok, swapped = pcall(C_CVar.GetCVarBool, "GamepadSwapTargetModifiers")
    swapped = ok and swapped and true or false
    local a, b = GetBindingKey(swapped and "GAMEPADRIGHTTARGETMODIFIER" or "GAMEPADLEFTTARGETMODIFIER")
    if not a then a = swapped and "PADRSHOULDER" or "PADLSHOULDER" end
    return a, b
end

-- the button that switches to the second set while the layer is on: the
-- other target modifier (R; L with the modifiers swapped)
local function ShiftKeys()
    local ok, swapped = pcall(C_CVar.GetCVarBool, "GamepadSwapTargetModifiers")
    swapped = ok and swapped and true or false
    local a, b = GetBindingKey(swapped and "GAMEPADLEFTTARGETMODIFIER" or "GAMEPADRIGHTTARGETMODIFIER")
    if not a then a = swapped and "PADLSHOULDER" or "PADRSHOULDER" end
    return a, b
end

-- out of a fight only
local function ApplyHold(on)
    ClearOverrideBindings(hold)
    wipe(holdKeys)
    if not on then return end
    local keys = {}
    if Wanted("padHealModifier") and GamepadStyle() then keys = { FriendKeys() } end
    -- the hub's Deck test at the PC: Tab stands in for the button
    if D.DeckTestOn and D.DeckTestOn() then keys[#keys + 1] = TEST_HOLD end
    for _, key in ipairs(keys) do
        SetOverrideBindingClick(hold, true, key, "DeckHealLayer", "LeftButton")
        holdKeys[#holdKeys + 1] = key
    end
end

function ns.PadHealActive()
    return layer and layer:GetAttribute("active") and true or false
end

-------------------------------------------------------------------
-- The game's own aiming at friends while the layer's key is held
-------------------------------------------------------------------
-- Owner 2026-11-16: "wenn man nur L oder R drueckt und mit dem rechten
-- Stick dreht auch Targets aufgeschaltet werden (aber nur wenn es nichts
-- kaputt macht)". Blizzard's target modifiers do that through the engine
-- (Blizzard_GamepadTargeting/TargetLogic.lua, BeginTargeting/EndTargeting:
-- C_GamepadTargeting.SetFilter + Enable while held, Disable on release);
-- R still is Blizzard's, but L clicks our layer since padHealModifier, so
-- the friendly half was lost. The three calls are plain functions in the
-- API docs (GamepadTargetingDocumentation.lua: no protected flag), so we
-- make them ourselves from LayerChanged. Nothing of Blizzard's state is
-- touched, and with the enemy modifier already held we stay out. Not
-- copied: the tap that targets the nearest friend (EndTargeting).
-- padHealAim (on) switches it off.
local aiming = false
local function Aim(on)
    if on == aiming then return end
    local T = C_GamepadTargeting
    local filters = Enum and Enum.GamepadTargetingFilters
    if not (T and T.SetFilter and T.Enable and T.Disable and filters and filters.Friendly) then return end
    if not on then
        aiming = false
        seen.aimOff = pcall(T.Disable)
        return
    end
    if not (Wanted("padHealAim") and GamepadStyle()) then return end
    if GamepadMode and GamepadMode.IsTargetingModifierDown and GamepadTargetingState
        and GamepadMode.IsTargetingModifierDown(GamepadTargetingState.HOSTILE) then return end
    local ok, err = pcall(function()
        T.SetFilter(filters.Friendly)
        T.Enable()
    end)
    aiming = ok
    seen.aims = (seen.aims or 0) + (ok and 1 or 0)
    seen.aimError = not ok and tostring(err) or nil
end

-------------------------------------------------------------------
-- Who the D-pad picks: tank first, healer left, damage up, right, down
-------------------------------------------------------------------
-- home (the member the layer starts on) and the four directions' members;
-- nil while a role is kept from us - the last answer then stands
local function Assign()
    local list, tank, healer = {}, nil, nil
    for _, unit in ipairs(UNITS) do
        if unit == "player" or UnitExists(unit) then
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
            if Secret(role) then return nil end
            if role == "TANK" and not tank then tank = unit end
            list[#list + 1] = { unit = unit, role = role }
        end
    end
    local home = tank or "player"
    for _, m in ipairs(list) do
        if m.role == "HEALER" and m.unit ~= home and not healer then healer = m.unit end
    end
    local others = {}
    for _, m in ipairs(list) do
        if m.unit ~= home and m.unit ~= healer then others[#others + 1] = m.unit end
    end
    if not healer then
        if home ~= "player" then
            -- nobody carries the healer's role: whoever holds this pad heals
            healer = "player"
            for i, unit in ipairs(others) do
                if unit == "player" then table.remove(others, i) break end
            end
        else
            healer = table.remove(others, 4)   -- no roles at all: the fourth member
        end
    end
    return home, { others[1], others[2], others[3], healer }
end

-- the buttons' members change out of a fight only (ns.OutOfCombat keeps
-- the last call)
local function ApplyPicks()
    if not layer then return end
    ns.OutOfCombat("padHealPicks", function()
        local home, units = Assign()
        if home then
            assigned.home = home
            for i = 1, #PICKS do assigned[i] = units[i] end
        end
        layer:SetAttribute("home", assigned.home)
        for i, b in ipairs(picks) do b:SetAttribute("pickunit", assigned[i]) end
        if ns.PartyHealRefresh then ns.PartyHealRefresh() end
    end)
end

-- for the HoT window's key pictures: the D-pad key that picks this member
-- while Deck Heal is on; false for a member without one (the one the layer
-- starts on), nil while Deck Heal is off
function ns.PadHealGlyph(unit)
    if not (layer and Opt("padHeal")) then return nil end
    for i, def in ipairs(PICKS) do
        if assigned[i] == unit then return def.glyph or def.key end
    end
    return false
end

-------------------------------------------------------------------
-- The bar: who is picked, which key casts what
-------------------------------------------------------------------
local bar = CreateFrame("Frame", "DeckOrbsDeckHeal", UIParent)
bar:SetSize(BAR_W, ICON + 2 * PAD)
bar.defaultPoint = { "CENTER", UIParent, "CENTER", 0, -170 }
bar:SetPoint(unpack(bar.defaultPoint))
bar:SetFrameStrata("MEDIUM")
bar:Hide()

do
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0.03, 0.03, 0.04, 0.72)
    local top = bar:CreateTexture(nil, "BORDER")   -- the dock's gold line
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    top:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
end

bar.name = bar:CreateFontString(nil, "OVERLAY")
bar.name:SetFont(ns.FONT, 12, "OUTLINE")
bar.name:SetJustifyH("LEFT")
bar.name:SetWordWrap(false)
bar.name:SetPoint("LEFT", PAD, 0)
bar.name:SetWidth(NAME_W)
bar.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
-- with the second set: which four are on the buttons right now
bar.page = bar:CreateFontString(nil, "OVERLAY")
bar.page:SetFont(ns.FONT, 9, "OUTLINE")
bar.page:SetJustifyH("LEFT")
bar.page:SetPoint("BOTTOMLEFT", PAD, 4)
bar.page:SetWidth(NAME_W)
bar.page:Hide()

bar.slots = {}
for i, def in ipairs(CASTS) do
    local s = CreateFrame("Frame", nil, bar)
    s:SetSize(ICON, ICON)
    s:SetPoint("LEFT", bar, "LEFT", PAD + NAME_W + 4 + (i - 1) * (ICON + GAP), 0)
    s.rim = ns.IconRim(s, 0.35, 0.33, 0.3, 1)
    s.icon = ns.RoundIcon(s:CreateTexture(nil, "ARTWORK"))
    s.icon:SetAllPoints(s)
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- the key's picture on the icon's lower right corner; without
    -- Blizzard's template (or its key names) the letter in our font
    local ok, g = pcall(CreateFrame, "Frame", nil, s, "InputIconTextureFrameTemplate")
    if ok and g and g.SetInputKey and def.glyph then
        g:SetInputKey(def.glyph)
    else
        g = CreateFrame("Frame", nil, s)
        local t = g:CreateFontString(nil, "OVERLAY")
        t:SetFont(ns.FONT, 11, "OUTLINE")
        t:SetPoint("CENTER")
        t:SetTextColor(1, 1, 1)
        t:SetText(def.short)
    end
    g:SetSize(16, 16)
    g:SetPoint("CENTER", s, "BOTTOMRIGHT", -2, 3)
    g:SetFrameLevel(s:GetFrameLevel() + 3)
    -- the spell's cooldown as a closing circle with the time (padHealFeedback)
    local cd = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
    cd:SetAllPoints(s)
    cd:EnableMouse(false)
    cd:SetSwipeTexture(D.MASK)
    cd:SetSwipeColor(0, 0, 0, 0.8)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetHideCountdownNumbers(false)
    cd:SetFrameLevel(s:GetFrameLevel() + 1)
    if cd.SetCountdownFont and ns.CountdownFont then cd:SetCountdownFont(ns.CountdownFont(ICON)) end
    s.cd = cd
    bar.slots[i] = s
end

-------------------------------------------------------------------
-- The cockpit: the picked member's health, your HoTs, a debuff to remove
-------------------------------------------------------------------
-- Owner 2026-11-16 (picked from a list of ideas: "bau 1, 2 und 3"): what
-- the eye needs in a fight sits at the bar in the middle of the screen, so
-- it need not go to the HoT window at the edge. padHealCockpit (on). A
-- thin capsule under the name (fed secrets and all), and after the four
-- spells two of the engine's aura containers on the picked member's token
-- - one debuff you can remove (red rim), then your HoTs with their clocks.
-- Ours and unprotected: made the first time the bar shows, moved to
-- another token (SetUnit) in a fight too.
local function Cockpit()
    if bar.health then return true end
    if not (ns.PillBar and ns.AuraIconButton and ns.HotLayerIDs and ns.FLOW) then return false end
    local hb = ns.PillBar(bar, NAME_W, 5)
    hb:SetStatusBarColor(0.3, 0.82, 0.3)
    hb:Hide()
    bar.health = hb
    local function Container(x, width, group, filter, options)
        local ok, auras = pcall(CreateFrame, "AuraContainer", nil, bar, "CustomAuraContainerTemplate")
        if not (ok and auras) then return nil end
        auras:SetSize(width, AURA)
        auras:SetPoint("LEFT", bar, "LEFT", x, 0)
        auras:SetUnit("player")
        auras:SetFlowLayoutAnchorPoint("LEFT")
        auras:SetFlowLayoutAxis(ns.FLOW.Horizontal)
        auras:SetFlowLayoutMaximumLineSize(width)
        auras:SetFlowLayoutGrowthDirection(1, -1)
        options.layout = { elementSpacing = 2 }
        auras:AddAuraGroup(group, filter, options)
        auras:Hide()
        return auras
    end
    local x = BAR_W - PAD + 10
    bar.dispel = Container(x, AURA, "dispel", ns.HOT_DISPEL_FILTER or "HARMFUL|RAID", {
        maxFrameCount = 1,
        candidateFilters = { excludeSpellIDs = {} },
        initializeFrame = function(button)
            button:SetSize(AURA, AURA)
            ns.IconRim(button, 0.95, 0.2, 0.2, 1)
            ns.AuraIconButton(button, AURA)
        end,
    })
    bar.hots = Container(x + AURA + 4, HOTS_MAX * (AURA + 2), "hots", "HELPFUL|PLAYER", {
        maxFrameCount = HOTS_MAX,
        candidateFilters = { includeSpellIDs = ns.HotLayerIDs() },
        initializeFrame = function(button)
            button:SetSize(AURA, AURA)
            ns.AuraIconButton(button, AURA)
        end,
    })
    return true
end

local function CockpitUnit(unit)
    if bar.cockpitUnit == unit then return end
    bar.cockpitUnit = unit
    for _, auras in ipairs({ bar.dispel, bar.hots }) do
        pcall(auras.SetUnit, auras, unit)
        pcall(auras.UpdateAllAuras, auras)
    end
end

local function PaintHealth(unit)
    local hb = bar.health
    if not hb or not hb:IsShown() then return end
    hb:SetMinMaxValues(0, UnitHealthMax(unit))
    hb:SetValue(UnitHealth(unit))
end

-- a new rank or a talent change: the HoT container's spell IDs follow
local function CockpitSpells()
    if bar.hots and ns.HotLayerIDs then
        pcall(bar.hots.SetAuraGroupCandidateFilters, bar.hots, "hots", { includeSpellIDs = ns.HotLayerIDs() })
        pcall(bar.hots.UpdateAllAuras, bar.hots)
    end
end

-------------------------------------------------------------------
-- The four icons say whether the spell would go through
-------------------------------------------------------------------
-- padHealFeedback (on): the cooldown as a closing circle (LibActionButton's
-- way, as the HoT window: C_Spell.GetSpellCooldown for the flags, the
-- duration object into the clock, never the global cooldown), grey while
-- the mana is short or the spell cannot be cast, red while the picked
-- member is out of its range. A secret answer changes nothing.

local cdDirty = true
local function SlotCooldown(s, spell)
    local cd = s.cd
    if not (spell and C_Spell and C_Spell.GetSpellCooldown) then cd:Clear() return end
    local id = spell.cast or spell.id
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    if not ok or Secret(info) or type(info) ~= "table" then cd:Clear() return end
    local gcd, active = info.isOnGCD, info.isActive
    if not Secret(gcd) and gcd then cd:Clear() return end
    if not Secret(active) then
        if active == false then cd:Clear() return end
        if active == nil then
            local d = info.duration
            if Secret(d) or not d or d <= 1.5 then cd:Clear() return end
        end
    end
    if C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
        local ok2, object = pcall(C_Spell.GetSpellCooldownDuration, id)
        if not (ok2 and object and pcall(cd.SetCooldownFromDurationObject, cd, object)) then cd:Clear() end
        return
    end
    local start, d = info.startTime, info.duration
    if Secret(start) or Secret(d) or not start or not d or d <= 0 then cd:Clear() return end
    cd:SetCooldown(start, d)
end

local function Feedback(unit, page)
    local on = Wanted("padHealFeedback")
    local dirty = cdDirty
    cdDirty = false
    for i, s in ipairs(bar.slots) do
        local spell = spells[(page - 1) * SLOTS + i]
        local r, g, b, grey = 1, 1, 1, not spell
        if dirty then SlotCooldown(s, on and spell or nil) end
        if on and spell and C_Spell then
            local id = spell.cast or spell.id
            if C_Spell.IsSpellUsable then
                local ok, usable, noMana = pcall(C_Spell.IsSpellUsable, id)
                if ok and not Secret(usable) and not Secret(noMana) and (noMana or usable == false) then
                    grey, r, g, b = true, 0.55, 0.55, 0.6
                end
            end
            if C_Spell.IsSpellInRange and unit ~= "player" then
                local ok, near = pcall(C_Spell.IsSpellInRange, id, unit)
                if ok and not Secret(near) and near == false then r, g, b = 1, 0.25, 0.25 end
            end
        end
        s.icon:SetDesaturated(grey)
        s.icon:SetVertexColor(r, g, b)
    end
end

-------------------------------------------------------------------
-- The round out of a fight: the next buff or resurrection on one key
-------------------------------------------------------------------
-- padHealRound (on). DeckHealRound is a SecureActionButton whose spell and
-- unit we set out of a fight to what ns.HotRoundNext says is needed next;
-- the layer's snippet binds the right stick's click to it, out of a fight
-- only, and at the start of a fight the spell is taken off. A small tag
-- above the bar says what the next press does.
local round, roundNow

-- a frame of its own, only anchored to the bar: the bar may stay hidden
-- while the party row shows the keys (ns.PartyHealShowsKeys)
local tag = CreateFrame("Frame", nil, UIParent)
tag:SetFrameStrata("MEDIUM")
tag:SetSize(BAR_W, 20)
tag:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
tag:Hide()
do
    local bg = tag:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(tag)
    bg:SetColorTexture(0.03, 0.03, 0.04, 0.72)
    tag.icon = tag:CreateTexture(nil, "ARTWORK")
    tag.icon:SetSize(16, 16)
    tag.icon:SetPoint("LEFT", PAD + 20, 0)
    tag.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local ok, g = pcall(CreateFrame, "Frame", nil, tag, "InputIconTextureFrameTemplate")
    if ok and g and g.SetInputKey and GAMEPAD_STICK_RIGHT_PRESS then
        g:SetInputKey(GAMEPAD_STICK_RIGHT_PRESS)
        g:SetSize(16, 16)
        g:SetPoint("LEFT", PAD, 0)
    else
        local t = tag:CreateFontString(nil, "OVERLAY")
        t:SetFont(ns.FONT, 10, "OUTLINE")
        t:SetPoint("LEFT", PAD, 0)
        t:SetText("R3")
    end
    tag.text = tag:CreateFontString(nil, "OVERLAY")
    tag.text:SetFont(ns.FONT, 10, "OUTLINE")
    tag.text:SetJustifyH("LEFT")
    tag.text:SetWordWrap(false)
    tag.text:SetPoint("LEFT", tag.icon, "RIGHT", 4, 0)
    tag.text:SetPoint("RIGHT", -PAD, 0)
end

local function PaintTag()
    local show = roundNow and Wanted("padHealRound") and not InCombatLockdown()
        and layer and layer:GetAttribute("active") and true or false
    if show then
        tag.icon:SetTexture(roundNow.icon or 134400)
        local who = roundNow.unit == "player" and "You" or UnitName(roundNow.unit) or roundNow.unit
        tag.text:SetText(("%s: %s"):format(roundNow.name, who))
        local dead = roundNow.what == "dead"
        tag.text:SetTextColor(dead and 1 or GOLD[1], dead and 0.4 or GOLD[2], dead and 0.4 or GOLD[3])
    end
    tag:SetShown(show)
end

-- out of a fight only; a fight's start clears the button (ClearRound)
local function ApplyRound()
    if not round or InCombatLockdown() then return end
    local now = Opt("padHeal") and Wanted("padHealRound") and ns.HotRoundNext and ns.HotRoundNext() or nil
    local spell = now and (now.cast or now.name) or nil
    if round:GetAttribute("spell") ~= spell or round:GetAttribute("unit") ~= (now and now.unit or "player") then
        round:SetAttribute("unit", now and now.unit or "player")
        round:SetAttribute("spell", spell)
    end
    roundNow = now
    PaintTag()
end

local function ClearRound()
    if round and not InCombatLockdown() then round:SetAttribute("spell", nil) end
    roundNow = nil
    PaintTag()
end

local function PaintBar(unit)
    local name
    if previewing and not (layer and layer:GetAttribute("active")) then
        name = "Deck Heal"
    elseif unit == "player" then
        name = "You"
    else
        name = UnitName(unit) or unit
    end
    bar.name:SetText(name)
    local second = DeckUIForeverOrbsDB.padHealR and true or false
    local page = second and layer and layer:GetAttribute("page") or 1
    -- the cockpit: health under the name, the auras after the spells
    local live = layer and layer:GetAttribute("active") and true or false
    local cockpit = Wanted("padHealCockpit") and Cockpit()
    bar:SetWidth(BAR_W + (cockpit and COCKPIT_W or 0))
    if bar.health then
        local shown = cockpit and live or false
        bar.health:SetShown(shown)
        if bar.dispel then bar.dispel:SetShown(shown) end
        if bar.hots then bar.hots:SetShown(shown) end
        if shown then
            CockpitUnit(unit)
            bar.health:ClearAllPoints()
            bar.health:SetPoint("LEFT", PAD, second and 0 or -6)
            PaintHealth(unit)
        end
    end
    local lifted = cockpit and live
    bar.name:ClearAllPoints()
    bar.name:SetPoint("LEFT", PAD, lifted and (second and 10 or 5) or (second and 5 or 0))
    bar.page:ClearAllPoints()
    bar.page:SetPoint("BOTTOMLEFT", PAD, lifted and 2 or 4)
    bar.page:SetShown(second)
    if second then
        bar.page:SetText(page == 2 and "second set" or "hold R: second set")
        bar.page:SetTextColor(page == 2 and GOLD[1] or 0.6, page == 2 and GOLD[2] or 0.6, page == 2 and GOLD[3] or 0.6)
    end
    for i, s in ipairs(bar.slots) do
        local spell = spells[(page - 1) * SLOTS + i]
        s.icon:SetTexture(spell and spell.icon or 134400)
        s:SetAlpha(spell and 1 or 0.35)
    end
    cdDirty = true
    Feedback(unit, page)
    PaintTag()
end

-- while the bar shows: health, mana and range five times a second
local sinceTick = 0
bar:SetScript("OnUpdate", function(_, dt)
    sinceTick = sinceTick + dt
    if sinceTick < 0.2 then return end
    sinceTick = 0
    if not (layer and layer:GetAttribute("active")) then return end
    local unit = layer:GetAttribute("unit") or "player"
    PaintHealth(unit)
    Feedback(unit, DeckUIForeverOrbsDB.padHealR and layer:GetAttribute("page") or 1)
end)

-- everything of ours that shows the layer's state; nothing protected, so
-- the snippets may call it in a fight
local function Refresh()
    local active = layer and layer:GetAttribute("active") and true or false
    local unit = active and layer:GetAttribute("unit") or "player"
    -- the party row shows the keys on its own icons: no bar then
    local onRows = ns.PartyHealShowsKeys and ns.PartyHealShowsKeys() or false
    local show = previewing or (active and Wanted("padHealBar") and not onRows)
    if show then PaintBar(unit) end
    bar:SetShown(show)
    -- the gold frame, the D-pad pictures and the keys on the party rows (partyheal.lua)
    if ns.PartyHealRefresh then ns.PartyHealRefresh() end
end

-- for partyheal.lua's key pictures on the picked row's icons (owner
-- 2026-11-26: "haeng die Zauber-Icons an die Gruppenzeile"): while the
-- layer is on, the picked token, the set in force, every spell of both
-- sets, the face buttons' definitions and how many a set holds
function ns.PadHealKeys()
    if not (layer and layer:GetAttribute("active")) then return nil end
    local page = DeckUIForeverOrbsDB.padHealR and layer:GetAttribute("page") or 1
    return layer:GetAttribute("unit") or "player", page, spells, CASTS, SLOTS
end

-- what the buttons cast, whether the layer is on or not
function ns.PadHealSpellList()
    return spells
end

-- for partyheal.lua's gold frame: the unit token the layer is on, nil
-- while it is off or the frame is not wanted
function ns.PadHealPicked()
    if not (layer and layer:GetAttribute("active") and Wanted("padHealFrame")) then return nil end
    return layer:GetAttribute("unit") or "player"
end

-------------------------------------------------------------------
-- The secure part
-------------------------------------------------------------------
-- A held shoulder, trigger or paddle may count as Ctrl, Shift or Alt, and
-- with L and R both held two of them at once (owner 2026-11-16: "mit L + R
-- sollten weitere dazu kommen, das passiert aber nicht"), so every key of
-- the layer is bound plain and under every modifier combination. A snippet
-- may not define a function: this writes the lines out for it.
local MODS = { "", "CTRL-", "SHIFT-", "ALT-", "ALT-CTRL-", "ALT-SHIFT-", "CTRL-SHIFT-", "ALT-CTRL-SHIFT-" }
local function BindAll(owner, key, name)
    local lines = {}
    for _, mod in ipairs(MODS) do
        lines[#lines + 1] = ("%s:SetBindingClick(true, %q .. %s, %s)"):format(owner, mod, key, name)
    end
    return table.concat(lines, "\n") .. "\n"
end

-- the binding's key: down lays the pad keys on our buttons, up clears
-- them; with `toggle` every press switches. `enabled` is the option.
local LAYER_CLICK = [[
    if not self:GetAttribute("enabled") then return end
    local was = self:GetAttribute("active") and true or false
    local on
    if self:GetAttribute("toggle") then
        if not down then return end
        on = not was
    else
        on = down and true or false
    end
    if on == was then return end
    self:SetAttribute("active", on)
    if on then
        -- the member the layer starts on: the tank, or you
        local home = self:GetAttribute("home") or "player"
        if UnitExists and not UnitExists(home) then home = "player" end
        self:SetAttribute("unit", home)
        self:SetAttribute("page", 1)
        for i = 5, 8 do
            self:GetFrameRef("cast" .. i):SetAttribute("unit", home)
        end
        -- the second set's switch (R), where the option gave it a key
        local sn = self:GetFrameRef("shift"):GetName()
        for i = 1, 2 do
            local sk = self:GetAttribute("shiftkey" .. i)
            if sk then
]] .. BindAll("self", "sk", "sn") .. [[
            end
        end
        -- the round's key (the right stick's click), out of a fight only
        local rk = self:GetAttribute("roundkey")
        if rk and not (PlayerInCombat and PlayerInCombat()) then
            local rn = self:GetFrameRef("round"):GetName()
]] .. BindAll("self", "rk", "rn") .. [[
            if self:GetAttribute("test") then
                self:SetBindingClick(true, self:GetAttribute("roundtest"), rn)
            end
        end
        for i = 1, 4 do
            local cast = self:GetFrameRef("cast" .. i)
            cast:SetAttribute("unit", home)
            -- the plain key and the key with a modifier: a held shoulder or
            -- paddle may count as Ctrl, Shift or Alt
            local ck, cn = self:GetAttribute("castkey" .. i), cast:GetName()
            local pk, pn = self:GetAttribute("pickkey" .. i), self:GetFrameRef("pick" .. i):GetName()
]] .. BindAll("self", "ck", "cn") .. BindAll("self", "pk", "pn") .. [[
            if self:GetAttribute("test") then
                self:SetBindingClick(true, self:GetAttribute("casttest" .. i), cn)
                self:SetBindingClick(true, self:GetAttribute("picktest" .. i), pn)
            end
        end
    else
        self:ClearBindings()
    end
    self:CallMethod("LayerChanged", down and true or false)
]]

-- a D-pad direction: its member becomes the casts' unit; the direction of
-- the picked member again goes back to the one the layer starts on; a
-- direction without a member, or whose member is not there, picks nobody
local PICK_CLICK = [[
    local layer = self:GetFrameRef("layer")
    if not layer:GetAttribute("active") then return end
    local unit = self:GetAttribute("pickunit")
    if not unit then return end
    if layer:GetAttribute("unit") == unit then
        unit = layer:GetAttribute("home") or "player"
        if UnitExists and not UnitExists(unit) then unit = "player" end
    elseif UnitExists and not UnitExists(unit) then
        return
    end
    layer:SetAttribute("unit", unit)
    for i = 1, 8 do
        layer:GetFrameRef("cast" .. i):SetAttribute("unit", unit)
    end
    self:CallMethod("Picked")
]]

-- R while the layer is on: down lays the face buttons on the casts 5-8,
-- up back on 1-4. The bindings stay the layer's own.
local SHIFT_CLICK = [[
    local layer = self:GetFrameRef("layer")
    if not layer:GetAttribute("active") then return end
    local page = down and 2 or 1
    if layer:GetAttribute("page") == page then return end
    layer:SetAttribute("page", page)
    for i = 1, 4 do
        local ck = layer:GetAttribute("castkey" .. i)
        local cn = layer:GetFrameRef("cast" .. ((page - 1) * 4 + i)):GetName()
]] .. BindAll("layer", "ck", "cn") .. [[
        if layer:GetAttribute("test") then
            layer:SetBindingClick(true, layer:GetAttribute("casttest" .. i), cn)
        end
    end
    self:CallMethod("PageChanged")
]]

-- out of a fight only
local function Setup()
    layer = CreateFrame("Button", "DeckHealLayer", UIParent, "SecureHandlerClickTemplate")
    layer:RegisterForClicks("AnyDown", "AnyUp")
    layer:SetAttribute("unit", "player")
    layer:SetAttribute("active", false)
    function layer:LayerChanged(down)
        if down then seen.down = seen.down + 1 else seen.up = seen.up + 1 end
        -- what A and D-pad up really run now: ours, or did the game's win?
        if self:GetAttribute("active") then
            seen.face = GetBindingAction(CASTS[1].key, true)
            seen.dpad = GetBindingAction(PICKS[1].key, true)
        end
        Aim(self:GetAttribute("active") and true or false)
        Refresh()
    end
    -- eight cast buttons: 1-4 the first set, 5-8 the second (padHealR)
    for i = 1, SLOTS * SETS do
        local b = CreateFrame("Button", "DeckHealCast" .. i, UIParent, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyDown", "AnyUp")   -- the template keeps the one the key-down setting wants
        b:SetAttribute("type", "spell")
        b:SetAttribute("unit", "player")
        b:HookScript("PostClick", function() seen.casts = seen.casts + 1 end)
        casts[i] = b
        layer:SetFrameRef("cast" .. i, b)
    end
    for i, def in ipairs(CASTS) do
        layer:SetAttribute("castkey" .. i, def.key)
        layer:SetAttribute("casttest" .. i, TEST_CASTS[i])
        layer:SetAttribute("picktest" .. i, TEST_PICKS[i])
    end
    local shift = CreateFrame("Button", "DeckHealShift", UIParent, "SecureHandlerClickTemplate")
    shift:RegisterForClicks("AnyDown", "AnyUp")
    shift:SetFrameRef("layer", layer)
    shift:SetAttribute("_onclick", SHIFT_CLICK)
    function shift:PageChanged()
        seen.shifts = (seen.shifts or 0) + 1
        Refresh()
    end
    layer:SetFrameRef("shift", shift)
    layer:SetAttribute("page", 1)
    round = CreateFrame("Button", "DeckHealRound", UIParent, "SecureActionButtonTemplate")
    round:RegisterForClicks("AnyDown", "AnyUp")
    round:SetAttribute("type", "spell")
    round:SetAttribute("unit", "player")
    round:HookScript("PostClick", function() seen.rounds = (seen.rounds or 0) + 1 end)
    layer:SetFrameRef("round", round)
    layer:SetAttribute("roundtest", TEST_ROUND)
    for i, def in ipairs(PICKS) do
        local b = CreateFrame("Button", "DeckHealPick" .. i, UIParent, "SecureHandlerClickTemplate")
        b:RegisterForClicks("AnyDown")
        b:SetFrameRef("layer", layer)
        b:SetAttribute("_onclick", PICK_CLICK)
        function b:Picked()
            seen.picks = seen.picks + 1
            Refresh()
        end
        picks[i] = b
        layer:SetFrameRef("pick" .. i, b)
        layer:SetAttribute("pickkey" .. i, def.key)
    end
    layer:SetAttribute("_onclick", LAYER_CLICK)
end

-------------------------------------------------------------------
-- The four spells
-------------------------------------------------------------------
-- the player's own list (padHealSpells: names or IDs between commas; a
-- name resolves only for a spell the character has), else the class's
local function ReadSpells()
    wipe(spells)
    wipe(unknown)
    local max = SLOTS * (Opt("padHealR") and SETS or 1)
    local text = DeckUIForeverOrbsDB.padHealSpells
    if type(text) == "string" and strtrim(text) ~= "" then
        for token in text:gmatch("[^,;\n]+") do
            token = strtrim(token)
            if token ~= "" then
                local id = tonumber(token)
                local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id or token)
                if info and info.name and #spells < max then
                    -- a name casts its highest rank; an ID is the rank the player picked
                    spells[#spells + 1] = { name = info.name, id = info.spellID, icon = info.iconID,
                        cast = id or (ns.HotTopRank and ns.HotTopRank(info.name, info.spellID)) }
                elseif not (info and info.name) then
                    unknown[#unknown + 1] = token
                end
            end
        end
    end
    -- the class's own, and after a list of the player's what is still free:
    -- four names of his leave the second set to the class's spells
    if ns.HotLayerSpells then
        local have = {}
        for _, spell in ipairs(spells) do have[spell.name] = true end
        for _, spell in ipairs(ns.HotLayerSpells(max)) do
            if #spells < max and not have[spell.name] then spells[#spells + 1] = spell end
        end
    end
end

-- the buttons' spells may change out of a fight only; a spell learnt in
-- one reaches its button after it (ns.OutOfCombat keeps the last call)
local function ApplySpells()
    if not layer then return end
    ns.OutOfCombat("padHealSpells", function()
        ReadSpells()
        for i, b in ipairs(casts) do
            b:SetAttribute("spell", spells[i] and (spells[i].cast or spells[i].name) or nil)
        end
        CockpitSpells()
        Refresh()
    end)
end

-------------------------------------------------------------------
-- Switching
-------------------------------------------------------------------
-- every switch of the page ends here. A change drops a layer that is on
-- (out of a fight, where our own hand may clear the bindings).
function ns.ApplyPadHeal()
    ns.OutOfCombat("padHeal", function()
        local on = Opt("padHeal")
        if on and not layer then Setup() end
        ApplyHold(on)
        if not layer then
            Refresh()
            return
        end
        layer:SetAttribute("enabled", on)
        layer:SetAttribute("toggle", Opt("padHealToggle"))
        local test = D.DeckTestOn and D.DeckTestOn() or false
        layer:SetAttribute("test", test)
        -- the second set's switch: R, and "5" while the hub's Deck test runs
        local k1, k2
        if on and Opt("padHealR") then
            if GamepadStyle() then k1, k2 = ShiftKeys() end
            if test then
                if not k1 then k1 = TEST_SHIFT else k2 = TEST_SHIFT end
            end
        end
        layer:SetAttribute("shiftkey1", k1)
        layer:SetAttribute("shiftkey2", k2)
        layer:SetAttribute("roundkey", on and Wanted("padHealRound") and ROUND_KEY or nil)
        if on then ApplyRound() else ClearRound() end
        layer:SetAttribute("page", 1)
        layer:SetAttribute("active", false)
        Aim(false)
        ApplyPicks()
        layer:SetAttribute("unit", assigned.home)
        ClearOverrideBindings(layer)
        ApplySpells()
        Refresh()
    end)
end

-- the key the layer is bound to, for the page; nil when none
function ns.PadHealKey()
    local list = {}
    local function Add(key)
        if key then list[#list + 1] = GetBindingText and GetBindingText(key) or key end
    end
    for _, key in ipairs(holdKeys) do Add(key) end
    Add((GetBindingKey(BINDING)))
    return #list > 0 and table.concat(list, ", ") or nil
end

local watch = CreateFrame("Frame")
-- the round looks twice a second for what is needed next, out of a fight
local sinceRound = 0
watch:SetScript("OnUpdate", function(_, dt)
    sinceRound = sinceRound + dt
    if sinceRound < 0.5 then return end
    sinceRound = 0
    if round and DeckUIForeverOrbsDB and DeckUIForeverOrbsDB.padHeal and not InCombatLockdown() then ApplyRound() end
end)
watch:SetScript("OnEvent", function(_, event)
    if not (DeckUIForeverOrbsDB and DeckUIForeverOrbsDB.padHeal) then return end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        ApplyPicks()   -- in a fight: after it
        Refresh()      -- the picked token may be someone else now
    elseif event == "PLAYER_REGEN_DISABLED" then
        ClearRound()   -- the last moment before the lockdown
    elseif event == "PLAYER_REGEN_ENABLED" then
        ApplyRound()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        cdDirty = true
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" or event == "PLAYER_ENTERING_WORLD" then
        -- the friend-targeting button is ours in the gamepad style only
        C_Timer.After(0.5, ns.ApplyPadHeal)
    else
        ApplySpells()
    end
end)

oUF:Factory(function()
    D.MakeMovable(bar, "Deck Heal", DeckUIForeverOrbsDB)
    for _, e in ipairs({ "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
                         "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
                         "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELL_UPDATE_COOLDOWN",
                         "INPUT_DEVICE_INTERFACE_TRANSITION" }) do
        if not C_EventUtils or C_EventUtils.IsEventValid(e) then watch:RegisterEvent(e) end
    end
    ns.ApplyPadHeal()
    D.OnUnlock(function(state, only)
        if only and not only["Deck Heal"] then state = false end
        previewing = state and Opt("padHeal") or false
        if previewing then ReadSpells() end
        Refresh()
    end)
end)

-- /orbs deckheal
function ns.PadHealDebug()
    print(("DeckUIForever Deck Heal: %s, %s, key %s, layer %s, in combat: %s."):format(
        Opt("padHeal") and "on" or "off", Opt("padHealToggle") and "press to switch" or "hold",
        tostring(ns.PadHealKey() or "not bound"),
        layer and (layer:GetAttribute("active") and "active" or "idle") or "not made",
        tostring(InCombatLockdown())))
    print(("  seen since login: key down %d, key up %d, picks %d, casts %d; picked now: %s"):format(
        seen.down, seen.up, seen.picks, seen.casts, layer and tostring(layer:GetAttribute("unit")) or "-"))
    print(("  friend-targeting button as the key: %s, gamepad style: %s"):format(
        Wanted("padHealModifier") and "on" or "off", tostring(GamepadStyle())))
    print(("  aiming at friends with the layer's key: %s, game has it: %s, switched on %d times, now %s%s"):format(
        Wanted("padHealAim") and "on" or "off", tostring(C_GamepadTargeting ~= nil), seen.aims or 0,
        aiming and "on" or "off", seen.aimError and (", last error: " .. seen.aimError) or ""))
    for _, key in ipairs(holdKeys) do
        print(("    %s runs: %s"):format(key, tostring(GetBindingAction(key, true))))
    end
    print(("  while the layer was last on, A ran: %s, D-pad up ran: %s"):format(
        tostring(seen.face or "-"), tostring(seen.dpad or "-")))
    print(("  bar %s, gold frame on the party row %s, keys on the party row %s (rows show them all: %s)"):format(
        Wanted("padHealBar") and "on" or "off", Wanted("padHealFrame") and "on" or "off",
        Wanted("padHealRows") and "on" or "off",
        tostring(ns.PartyHealShowsKeys and ns.PartyHealShowsKeys() or false)))
    print(("  cockpit %s, icon feedback %s, round %s (key %s, pressed %d times): next %s"):format(
        Wanted("padHealCockpit") and "on" or "off", Wanted("padHealFeedback") and "on" or "off",
        Wanted("padHealRound") and "on" or "off", tostring(layer and layer:GetAttribute("roundkey") or "-"),
        seen.rounds or 0,
        roundNow and (roundNow.name .. " on " .. roundNow.unit) or "nothing"))
    local second = Opt("padHealR")
    print(("  second set with R: %s, switch keys %s %s, switched %d times, set now: %s"):format(
        second and "on" or "off", tostring(layer and layer:GetAttribute("shiftkey1") or "-"),
        tostring(layer and layer:GetAttribute("shiftkey2") or ""), seen.shifts or 0,
        tostring(layer and layer:GetAttribute("page") or "-")))
    for set = 1, second and SETS or 1 do
        for i, def in ipairs(CASTS) do
            local n = (set - 1) * SLOTS + i
            local spell = spells[n]
            print(("  %s%s (%s): %s%s"):format(set == 2 and "R + " or "", def.short, def.key,
                spell and spell.name or "nothing",
                casts[n] and (", button casts " .. tostring(casts[n]:GetAttribute("spell")) ..
                    " on " .. tostring(casts[n]:GetAttribute("unit"))) or ""))
        end
    end
    local function Who(unit)
        if not unit then return "nobody" end
        local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
        return ("%s, %s, role %s"):format(unit, UnitExists(unit) and (UnitName(unit) or "?") or "not there",
            Secret(role) and "secret" or tostring(role))
    end
    print("  the layer starts on (tank, else you): " .. Who(assigned.home))
    for i, def in ipairs(PICKS) do
        print(("  %s (%s): %s%s"):format(def.key, def.what, Who(assigned[i]),
            picks[i] and (", button picks " .. tostring(picks[i]:GetAttribute("pickunit"))) or ""))
    end
    if #unknown > 0 then
        print("  your own list, not known to the game: " .. table.concat(unknown, ", "))
    end
end
