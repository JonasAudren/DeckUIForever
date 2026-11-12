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
-- held: the D-pad then picks a party member - up, right, down, left =
-- party1-4, the order of Blizzard's own friendly targeting and of the
-- glyphs before the HoT window's names - and the four face buttons cast
-- four spells on the picked member. The target is never touched. The
-- layer starts on you each time; the direction of the picked member
-- pressed again goes back to you. Letting go hands every key back.
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
-- instead of hold), padHealSpells (up to four names or IDs between commas;
-- empty: ns.HotLayerSpells picks), padHealBar, padHealFrame,
-- padHealModifier (on: in the gamepad style the friend-targeting button,
-- L, is the layer's key - see `hold` below).
-- /orbs deckheal prints what the layer saw.
--
-- UNTESTED IN GAME, and three things only the game answers: whether
-- Forever lets a secure handler set bindings in a fight, whether a
-- priority override binding beats Blizzard's gamepad action bar, and
-- whether the binding's key-up reaches the handler (if not: padHealToggle).
-------------------------------------------------------------------
local SLOTS = 4
local BINDING = "CLICK DeckHealLayer:LeftButton"
local ICON, NAME_W, PAD, GAP = 26, 92, 6, 8
local GOLD = { 1, 0.82, 0.3 }
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- the member each D-pad direction picks: Blizzard's friendly targeting order
local PICKS = {
    { key = "PADDUP",    unit = "party1" },
    { key = "PADDRIGHT", unit = "party2" },
    { key = "PADDDOWN",  unit = "party3" },
    { key = "PADDLEFT",  unit = "party4" },
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

local function Opt(key) return DeckUIForeverOrbsDB[key] and true or false end
local function Wanted(key) return DeckUIForeverOrbsDB[key] ~= false end   -- a switch that is on by default

local layer            -- DeckHealLayer, made the first time the option is on
local picks, casts = {}, {}
local spells = {}      -- what the four buttons cast: { name, id, icon }
local unknown = {}     -- what of padHealSpells the game did not know
local rings = {}       -- the gold frames in the HoT window, by unit token
local seen = { down = 0, up = 0, picks = 0, casts = 0 }   -- for /orbs deckheal
local previewing = false

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
-- The bar: who is picked, which key casts what
-------------------------------------------------------------------
local bar = CreateFrame("Frame", "DeckOrbsDeckHeal", UIParent)
bar:SetSize(PAD + NAME_W + SLOTS * (ICON + GAP) + PAD - GAP + 4, ICON + 2 * PAD)
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
    bar.slots[i] = s
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
    for i, s in ipairs(bar.slots) do
        local spell = spells[i]
        s.icon:SetTexture(spell and spell.icon or 134400)
        s.icon:SetDesaturated(not spell)
        s:SetAlpha(spell and 1 or 0.35)
    end
end

-------------------------------------------------------------------
-- The gold frame around the picked member's line in the HoT window
-------------------------------------------------------------------
-- made once per line, out of a fight (Setup runs there): a child of the
-- line that fills it, four thin lines, alpha 0 until its member is picked
local function MakeRings()
    if not ns.HotLine then return end
    for _, unit in ipairs(UNITS) do
        local c = not rings[unit] and ns.HotLine(unit)
        if c then
            local r = CreateFrame("Frame", nil, c)
            r:SetPoint("TOPLEFT", c, "TOPLEFT", -2, 2)
            r:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 2, -2)
            r:SetFrameLevel(c:GetFrameLevel() + 20)
            local function Edge(a, b, horizontal)
                local t = r:CreateTexture(nil, "OVERLAY")
                t:SetTexture(WHITE)
                t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.95)
                t:SetPoint(a)
                t:SetPoint(b)
                if horizontal then t:SetHeight(1) else t:SetWidth(1) end
            end
            Edge("TOPLEFT", "TOPRIGHT", true)
            Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
            Edge("TOPLEFT", "BOTTOMLEFT", false)
            Edge("TOPRIGHT", "BOTTOMRIGHT", false)
            r:SetAlpha(0)
            rings[unit] = r
        end
    end
end

-- everything of ours that shows the layer's state; nothing protected, so
-- the snippets may call it in a fight
local function Refresh()
    local active = layer and layer:GetAttribute("active") and true or false
    local unit = active and layer:GetAttribute("unit") or "player"
    local frame = active and Wanted("padHealFrame")
    for u, r in pairs(rings) do r:SetAlpha((frame and u == unit) and 1 or 0) end
    local show = previewing or (active and Wanted("padHealBar"))
    if show then PaintBar(unit) end
    bar:SetShown(show)
    -- the key pictures before the HoT window's names light up with the layer
    if DeckUIForeverOrbsDB.hotTracker and ns.ApplyHotHints then ns.ApplyHotHints() end
end

-------------------------------------------------------------------
-- The secure part
-------------------------------------------------------------------
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
        self:SetAttribute("unit", "player")
        for i = 1, 4 do
            local cast = self:GetFrameRef("cast" .. i)
            cast:SetAttribute("unit", "player")
            -- the plain key and the key with a modifier: a held shoulder or
            -- paddle may count as Ctrl, Shift or Alt
            local ck, cn = self:GetAttribute("castkey" .. i), cast:GetName()
            local pk, pn = self:GetAttribute("pickkey" .. i), self:GetFrameRef("pick" .. i):GetName()
            self:SetBindingClick(true, ck, cn)
            self:SetBindingClick(true, "CTRL-" .. ck, cn)
            self:SetBindingClick(true, "SHIFT-" .. ck, cn)
            self:SetBindingClick(true, "ALT-" .. ck, cn)
            self:SetBindingClick(true, pk, pn)
            self:SetBindingClick(true, "CTRL-" .. pk, pn)
            self:SetBindingClick(true, "SHIFT-" .. pk, pn)
            self:SetBindingClick(true, "ALT-" .. pk, pn)
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
-- the picked member again goes back to you; a member who is not there is
-- not picked
local PICK_CLICK = [[
    local layer = self:GetFrameRef("layer")
    if not layer:GetAttribute("active") then return end
    local unit = self:GetAttribute("pickunit")
    if layer:GetAttribute("unit") == unit then
        unit = "player"
    elseif UnitExists and not UnitExists(unit) then
        return
    end
    layer:SetAttribute("unit", unit)
    for i = 1, 4 do
        layer:GetFrameRef("cast" .. i):SetAttribute("unit", unit)
    end
    self:CallMethod("Picked")
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
        Refresh()
    end
    for i, def in ipairs(CASTS) do
        local b = CreateFrame("Button", "DeckHealCast" .. i, UIParent, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyDown", "AnyUp")   -- the template keeps the one the key-down setting wants
        b:SetAttribute("type", "spell")
        b:SetAttribute("unit", "player")
        b:HookScript("PostClick", function() seen.casts = seen.casts + 1 end)
        casts[i] = b
        layer:SetFrameRef("cast" .. i, b)
        layer:SetAttribute("castkey" .. i, def.key)
        layer:SetAttribute("casttest" .. i, TEST_CASTS[i])
        layer:SetAttribute("picktest" .. i, TEST_PICKS[i])
    end
    for i, def in ipairs(PICKS) do
        local b = CreateFrame("Button", "DeckHealPick" .. i, UIParent, "SecureHandlerClickTemplate")
        b:RegisterForClicks("AnyDown")
        b:SetAttribute("pickunit", def.unit)
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
    local text = DeckUIForeverOrbsDB.padHealSpells
    if type(text) == "string" and strtrim(text) ~= "" then
        for token in text:gmatch("[^,;\n]+") do
            token = strtrim(token)
            if token ~= "" then
                local id = tonumber(token)
                local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id or token)
                if info and info.name and #spells < SLOTS then
                    -- a name casts its highest rank; an ID is the rank the player picked
                    spells[#spells + 1] = { name = info.name, id = info.spellID, icon = info.iconID,
                        cast = id or (ns.HotTopRank and ns.HotTopRank(info.name, info.spellID)) }
                elseif not (info and info.name) then
                    unknown[#unknown + 1] = token
                end
            end
        end
        if #spells > 0 then return end
    end
    if ns.HotLayerSpells then
        for i, spell in ipairs(ns.HotLayerSpells(SLOTS)) do spells[i] = spell end
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
        if on then MakeRings() end
        layer:SetAttribute("enabled", on)
        layer:SetAttribute("toggle", Opt("padHealToggle"))
        layer:SetAttribute("test", D.DeckTestOn and D.DeckTestOn() or false)
        layer:SetAttribute("active", false)
        layer:SetAttribute("unit", "player")
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
watch:SetScript("OnEvent", function(_, event)
    if not (DeckUIForeverOrbsDB and DeckUIForeverOrbsDB.padHeal) then return end
    if event == "GROUP_ROSTER_UPDATE" then
        Refresh()   -- the picked token may be someone else now
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
                         "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
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
    for _, key in ipairs(holdKeys) do
        print(("    %s runs: %s"):format(key, tostring(GetBindingAction(key, true))))
    end
    print(("  while the layer was last on, A ran: %s, D-pad up ran: %s"):format(
        tostring(seen.face or "-"), tostring(seen.dpad or "-")))
    print(("  bar %s, frame in the HoT window %s (%d lines framed)"):format(
        Wanted("padHealBar") and "on" or "off", Wanted("padHealFrame") and "on" or "off",
        (function() local n = 0 for _ in pairs(rings) do n = n + 1 end return n end)()))
    for i, def in ipairs(CASTS) do
        local spell = spells[i]
        print(("  %s (%s): %s%s"):format(def.short, def.key, spell and spell.name or "nothing",
            casts[i] and (", button casts " .. tostring(casts[i]:GetAttribute("spell")) ..
                " on " .. tostring(casts[i]:GetAttribute("unit"))) or ""))
    end
    for i, def in ipairs(PICKS) do
        print(("  %s: %s, %s"):format(def.key, def.unit,
            UnitExists(def.unit) and (UnitName(def.unit) or "?") or "nobody"))
    end
    if #unknown > 0 then
        print("  your own list, not known to the game: " .. table.concat(unknown, ", "))
    end
end
