local ADDON, ns = ...
local D = DeckUIForever
local oUF = ns.oUF

-------------------------------------------------------------------
-- The party list as the healer's window
-------------------------------------------------------------------
-- Owner 2026-11-26: "ich will vom HoT-Fenster weg kommen und die Gruppe so
-- umbauen, dass sie zum HoT-Fenster wird" - two windows for one group
-- bothered him, and so did what the HoT window showed only after a fight.
-- Option partyHeal (off, /reload; ns.PartyHealOn in layout.lua): every row
-- of party.lua gets, after the row, one round slot per entry of heals.lua's
-- list - your HoTs and the shield, your heals, your cures, the
-- resurrection. The HoT window (heals.lua, 1.2.0 to 1.5.6) was removed the
-- same day once everything of it lived here; heals.lua is what was left
-- of it, the lists and the lookups.
--
-- Why the window was late and the rows are not. The window laid its lines
-- out in Lua, and with click to cast those lines were protected: in a
-- fight nothing of them could move, so a new member, a new order, a new
-- slot all waited for the end of it. The rows are the buttons of
-- Blizzard's SecureGroupHeader, which adds, removes and sorts members in a
-- fight by itself (tanks, healers, damage - party.lua), and everything
-- here hangs on a row in a fixed place:
--   * a slot's cast button is a SecureActionButton whose parent is the row
--     and whose unit is the row's ("useparent-unit"): whoever the header
--     puts behind the row is who the click heals, with no call of ours;
--   * a HoT is the engine's own aura button (a one-slot
--     CustomAuraContainer, as the HoT window had) over our dimmed icon; the
--     container is not protected and follows the row's unit (SetUnit from
--     an oUF element, in a fight too);
--   * a cure shows only while the member carries a debuff you can remove:
--     the engine's button again, on Blizzard's dispel filter;
--   * the resurrection lights up on a dead member (SetAlphaFromBoolean, so
--     a secret answer goes straight to the engine).
-- What still waits for the end of a fight: a spell learnt in one reaches
-- its button after it, and so does a row the header had to make in one -
-- which Precreate keeps from happening: the five rows are made the first
-- time the list shows out of a fight (the header's startingIndex, set
-- below 1 and back).
--
-- Pets (hotPets, the HoT window's switch, read once; owner the same day:
-- "bau jetzt noch Pets und die Ziel-Zeile ein"): a small line under each
-- row, stepped in - the pet's name, a thin health bar, and its slots at
-- 80% under the member's, in the same columns. The cast buttons are again
-- the row's children: the row's unit with the "unitsuffix" pet, which
-- Blizzard's SecureButton_GetModifiedUnit turns into pet / partypetN. The
-- rows stand further apart for it (ns.PartyHealPetGap, party.lua's
-- RowGap). The line's pieces are ours and come and go with the pet; the
-- buttons stay (a secure button cannot follow a unit we may not name in a
-- macro condition), a click on the empty place does nothing.
--
-- The target line (hotStranger, on): a friendly target outside the group
-- gets a line of its own above the list - name, health, the same slots in
-- the same columns. Its unit is the fixed token "target", so the game
-- itself shows and hides it, in a fight too (a state driver:
-- [@target,help,nodead,noparty,noraid]). Solo the driver cannot tell you
-- from a stranger: the line goes transparent while the target is you.
--
-- Slots come in groups (the row's, its pet's, the target line's): one
-- build, one fill, one paint for all three.
--
-- What the window still did and the rows now do too (owner the same day,
-- after the check of what was left: "schliesse alle Luecken 2 bis 5"): in a
-- raid without icons under the raid tiles the party list stays and lists
-- your raid group (party.lua's Visibility), and a raid member of another
-- group gets the target line (StripShown); hotAllBuffs shows every buff on
-- the row (party.lua's aura group, /reload); a click on a pet's name
-- targets the pet (PetTarget); the hub's "I am a healer" button switches
-- this mode on instead of the HoT window.
--
-- Deck Heal (padheal.lua) needs nothing of the window: its gold frame and
-- the D-pad pictures are drawn on the rows here (ns.PartyHealRefresh).
-- And its bar is not needed either (padHealRows, on; owner the same day:
-- "haeng die Zauber-Icons an die Gruppenzeile"): while the layer is on,
-- the picked row's own icons carry the face buttons' pictures - the key
-- that casts this spell on this member (PaintKeys, matched by the spell's
-- name; the second set's keys while R is held). padheal.lua leaves the
-- bar away as long as every spell of the layer has an icon on the rows
-- (ns.PartyHealShowsKeys); a spell of the player's own list that has none
-- brings the bar back.
--
-- The raid (hotRaid, off, read once; owner the same day: "bau jetzt noch
-- Raid und Manareg ein"): raid.lua's tiles are header buttons too, so
-- each gets the same slots in a line under the tile, as small as it takes
-- to fit the tile's width (RaidSize: 8 to 16 pixels - a wider tile gives
-- bigger icons), and the tiles stand further apart for it
-- (ns.RaidHealGap, raid.lua's VGap). No pets and no Deck Heal there.
--
-- The mana regeneration text (hotRegen) is heals.lua's; it hangs above the
-- party list here, above the raid in a raid (PlaceRegen).
--
-- The HoT window's last two extras (owner the same day: "bau jetzt noch
-- Ablauf-Warnung und Abklingzeiten ein"), on its switches. hotWarn /
-- hotWarnSound / hotWarnAt: a red pulse over a HoT in its last seconds and
-- one sound a second at most - the time is read by name (ns.HotRemaining),
-- so where the game keeps it secret in a fight nothing happens and the
-- engine's gold rim is the warning. hotCooldown: a clock per slot
-- (ns.HotEntryCooldown, asked once per spell when SPELL_UPDATE_COOLDOWN
-- came) - the dark sweep with the time on a heal and on the resurrection,
-- a small number on the top edge of a HoT, none on a cure.
-------------------------------------------------------------------
local ICON = 24
local SPACING = 3
local ROW_GAP = 6                      -- between the row and the first slot
local ROW_W = 230                      -- party.lua's row
local PET_SCALE = 0.8
local PET_SHIFT = 14                   -- the pet's name steps in under its owner
local PET_BLUE = { 0.62, 0.78, 1 }
local HEALTH = { 0.3, 0.82, 0.3 }
local STRIP_H = 20
local MISSING = { 0.9, 0.3, 0.3 }
local GOLD = { 1, 0.82, 0.3 }
local WHITE = "Interface\\Buttons\\WHITE8x8"
local POLL = 0.2
local ROWS = 5
-- while the raid tiles carry the icons, a raid member has them there; else
-- a raid member of another group is a stranger too, as in the HoT window
local function StripShown()
    if ns.RaidHealOn() then return "[@target,help,nodead,noparty,noraid] show; hide" end
    return "[@target,help,nodead,noparty] show; hide"
end

local rows = {}          -- every party row that carries slots
local tiles = {}         -- every raid tile that carries slots
local raidOn             -- hotRaid and the raid frames, read once
local groups = {}        -- every slot group: the rows', their pets', the target line's
local entries = {}       -- heals.lua's list (ns.HotEntries), the same table all session
local ids = {}           -- every aura ID of the list, for the rows' buff icons
local started = false
local pending = false    -- the cast buttons want a look after the fight
local laidFor = 0        -- the slot count the aura icons were placed for
local loadedSize
local cdDirty = true     -- the cooldown clocks want a fresh look: PaintAll takes it
local lastSound = 0
local WARN_GAP = 1       -- seconds between two warning sounds

local function Opt(key) return DeckUIForeverOrbsDB[key] and true or false end
local petsOn             -- hotPets, read once: the lines and the row gap stay for the session
local strip              -- the target line

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local function Size()
    return math.max(14, math.floor(ICON * (ns.DeviceDB().hotScale or 100) / 100 + 0.5))
end
local function Step() return Size() + SPACING end
local function PetSize() return math.max(12, math.floor(Size() * PET_SCALE + 0.5)) end

local function Across() return ns.DeviceDB().partyAcross and true or false end

-- the raid tiles' icons: all of the list in one line as wide as the tile
local function RaidSize()
    local w = ns.DeviceDB().raidW or 96
    local n = math.max(1, #entries)
    return math.max(8, math.min(16, math.floor((w - (n - 1)) / n)))
end

function ns.RaidHealOn()
    if raidOn == nil then
        raidOn = (ns.PartyHealOn() and DeckUIForeverOrbsDB.hotRaid and DeckUIForeverOrbsDB.showRaid) and true or false
    end
    return raidOn
end

local function PlaceRaid(frame, tile, i)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", tile, "BOTTOMLEFT", (i - 1) * (RaidSize() + 1), -2)
end

local function PetsOn()
    if petsOn == nil then petsOn = DeckUIForeverOrbsDB.hotPets and true or false end
    return petsOn
end

-- for party.lua's RowGap: how much further apart the rows stand for the pet lines
function ns.PartyHealPetGap()
    if not (ns.PartyHealOn() and PetsOn()) then return 0 end
    return PetSize() + 2
end

local function Unit(row)
    return row.__unit or row.unit or row:GetAttribute("unit")
end

-- the pet behind a row's token
local function PetUnit(row)
    local unit = row:GetAttribute("unit")
    if unit == "player" then return "pet" end
    local n = type(unit) == "string" and unit:match("^party(%d)$")
    return n and ("partypet" .. n) or nil
end

-- a member's slot i: after the row, or under it side by side
local function PlaceMember(frame, row, i)
    frame:ClearAllPoints()
    if Across() then
        frame:SetPoint("TOPLEFT", row, "BOTTOMLEFT", (i - 1) * Step(), -3)
    else
        frame:SetPoint("LEFT", row, "RIGHT", ROW_GAP + (i - 1) * Step(), 0)
    end
end

-- a pet's slot i: under the member's, centred in its column
local function PlacePet(frame, row, i)
    local inset = (Size() - PetSize()) / 2
    frame:ClearAllPoints()
    if Across() then
        frame:SetPoint("TOPLEFT", row, "BOTTOMLEFT", (i - 1) * Step() + inset, -3 - Size() - 3)
    else
        frame:SetPoint("TOPLEFT", row, "BOTTOMRIGHT", ROW_GAP + (i - 1) * Step() + inset, -2)
    end
end

-- the target line's slot i: always after the line, in the members' columns
local function PlaceStrip(frame, line, i)
    frame:ClearAllPoints()
    frame:SetPoint("LEFT", line, "RIGHT", ROW_GAP + (i - 1) * Step(), 0)
end

-- for party.lua's AuraPoint: how far the row's aura icons step aside
function ns.PartyHealAuraOffset(across)
    local n = #entries
    if n == 0 then return 0, 0 end
    if across then return 0, Size() + 3 + (PetsOn() and (PetSize() + 3) or 0) end
    return ROW_GAP + n * Step(), 0
end

-- for the rows' own buff icons: the HoTs have their slots
function ns.PartyHealIDs()
    return ids
end

-------------------------------------------------------------------
-- The list
-------------------------------------------------------------------
local function ReadList()
    ns.HotRebuild()
    local list, all = ns.HotEntries()
    entries = list
    wipe(ids)
    for id in pairs(all or {}) do ids[id] = true end
end

-------------------------------------------------------------------
-- A slot: our icon below, the engine's aura button above
-------------------------------------------------------------------
local function SetUnit(container, unit)
    if not (container and unit) then return end
    if container:GetUnit() ~= unit then
        pcall(container.SetUnit, container, unit)   -- reads the unit afresh
    else
        pcall(container.UpdateAllAuras, container)
    end
end

-- A group of slots. Its fields:
--   anchor   the frame the places are reckoned from (a row, the target line)
--   owner    the parent of the slots' pictures (plain frames; hidden with it)
--   secure   the parent of the cast buttons (the row, the target line)
--   size     the icon size, a function
--   place    function(frame, anchor, i)
--   unit     function(): the token the containers read
--   click    function(): the token a click heals (for the resurrection's light)
--   allow    function(entry): whether this group shows the entry (nil: all)
--   setup    function(button): the cast button's unit attributes
local function NewGroup(g)
    g.slots, g.casts = {}, {}
    groups[#groups + 1] = g
    return g
end

local function BuildSlot(g, i)
    local size = g.size()
    local s = CreateFrame("Frame", nil, g.owner)
    s.group = g
    s:SetSize(size, size)
    s:SetFrameLevel(g.owner:GetFrameLevel() + 2)
    g.place(s, g.anchor, i)
    s.rim = ns.IconRim(s, 0.35, 0.33, 0.3, 1)
    s.icon = ns.RoundIcon(s:CreateTexture(nil, "ARTWORK"))
    s.icon:SetAllPoints(s)
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local auras = CreateFrame("AuraContainer", nil, s, "CustomAuraContainerTemplate")
    auras:SetAllPoints(s)
    auras:SetUnit(g.unit() or "player")
    auras:AddAuraSlot("hot", "HELPFUL|PLAYER", {
        candidateFilters = { includeSpellIDs = {} },
        initializeFrame = function(button)
            button:SetAllPoints(s)
            ns.AuraIconButton(button, size)
        end,
    })
    s.auras = auras
    -- the resurrection: lit on a dead member only (alpha, Paint)
    local dead = CreateFrame("Frame", nil, s)
    dead:SetAllPoints(s)
    dead:SetFrameLevel(s:GetFrameLevel() + 1)
    ns.IconRim(dead, 0.2, 0.2, 0.2, 1)
    dead.icon = ns.RoundIcon(dead:CreateTexture(nil, "ARTWORK"))
    dead.icon:SetAllPoints(dead)
    dead.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    dead:SetAlpha(0)
    dead:Hide()
    s.dead = dead
    -- the expiry warning (hotWarn): a red glow that pulses over the icon,
    -- above everything of the slot and deaf to the mouse
    local warn = CreateFrame("Frame", nil, s)
    warn:SetAllPoints(s)
    warn:SetFrameLevel(s:GetFrameLevel() + 9)
    local glow = ns.RoundIcon(warn:CreateTexture(nil, "OVERLAY"))
    glow:SetAllPoints(warn)
    glow:SetTexture(WHITE)
    glow:SetVertexColor(1, 0.25, 0.15, 1)
    glow:SetBlendMode("ADD")
    local pulse = warn:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local a = pulse:CreateAnimation("Alpha")
    a:SetFromAlpha(0.05)
    a:SetToAlpha(0.65)
    a:SetDuration(0.35)
    warn:Hide()
    s.warn, s.pulse = warn, pulse
    g.slots[i] = s
    return s
end

local function SetWarn(s, on)
    on = on and true or false
    if (s.warning or false) == on then return end
    s.warning = on
    s.warn:SetShown(on)
    if on then s.pulse:Play() else s.pulse:Stop() end
end

-- a HoT of yours in its last seconds on the unit: the pulse, and a sound
-- the first time. A time the game keeps to itself is no warning.
local function Warn(s, e, unit)
    local blink, sound = Opt("hotWarn"), Opt("hotWarnSound")
    if not (blink or sound) or not (unit and ns.HotRemaining) then
        SetWarn(s, false)
        s.warned = nil
        return
    end
    local left = ns.HotRemaining(unit, e)
    local late = left ~= nil and left > 0 and left <= (tonumber(DeckUIForeverOrbsDB.hotWarnAt) or 3)
    SetWarn(s, late and blink)
    if late and not s.warned and sound and GetTime() - lastSound >= WARN_GAP then
        lastSound = GetTime()
        PlaySound(SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889, "Master")
    end
    s.warned = late or nil
end

-- A cure's slot: a one-slot container on the debuffs you can remove. The
-- engine shows its button only while there is one - in a fight too - and
-- our spell icon rides on that button (heals.lua's CureFrame).
local function CureFrame(s)
    if s.cure then return s.cure end
    local auras = CreateFrame("AuraContainer", nil, s, "CustomAuraContainerTemplate")
    auras:SetAllPoints(s)
    auras:SetUnit(s.group.unit() or "player")
    auras:AddAuraSlot("cure", ns.HOT_DISPEL_FILTER, {
        candidateFilters = { excludeSpellIDs = {} },
        initializeFrame = function(button)
            button:SetAllPoints(s)
            ns.IconRim(button, 0.95, 0.2, 0.2, 1)
            local theirs = ns.RoundIcon(button:CreateTexture(nil, "BACKGROUND"))
            theirs:SetAllPoints(button)
            theirs:SetAlpha(0)
            local icon = ns.RoundIcon(button:CreateTexture(nil, "ARTWORK"))
            icon:SetAllPoints(button)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon:SetTexture(s.entry and s.entry.icon or 134400)
            s.cureIcon = icon   -- ours, not handed over: Assign may change the picture
            button:SetIcon(theirs)
        end,
    })
    s.cure = auras
    return auras
end

-- what the slot shows; nothing protected, so in a fight too
local function Assign(s, e)
    s.entry = e
    cdDirty = true
    SetWarn(s, false)
    s.warned = nil
    s.icon:SetTexture(e.icon or 134400)
    local hot = e.kind == "hot"
    local plain = e.kind == "cast" and not e.need
    s.icon:SetShown(hot or plain)
    s.rim:SetShown(hot or plain)
    s.icon:SetDesaturated(hot)
    if plain then
        s.icon:SetAlpha(0.9)
        s.rim:SetVertexColor(0.2, 0.2, 0.2, 1)
    end
    s.auras:SetShown(hot)
    if hot then
        pcall(s.auras.SetAuraSlotCandidateFilters, s.auras, "hot", { includeSpellIDs = e.ids or {} })
        pcall(s.auras.UpdateAllAuras, s.auras)
    end
    if e.need == "cure" then
        local cure = CureFrame(s)
        cure:Show()
        if s.cureIcon then pcall(s.cureIcon.SetTexture, s.cureIcon, e.icon or 134400) end
        pcall(cure.UpdateAllAuras, cure)
    elseif s.cure then
        s.cure:Hide()
    end
    s.dead.icon:SetTexture(e.icon or 134400)
    s.dead:SetShown(e.need == "dead")
end

local function Allowed(g, e)
    return e ~= nil and (not g.allow or g.allow(e))
end

-- the pictures: a slot keeps its entry's place in the list, so the columns
-- of every group line up; a place the group leaves out stays empty
local function Fill(g)
    for i, e in ipairs(entries) do
        if Allowed(g, e) then
            local s = g.slots[i] or BuildSlot(g, i)
            Assign(s, e)
            s:Show()
        elseif g.slots[i] then
            g.slots[i]:Hide()
        end
    end
    for i, s in pairs(g.slots) do
        if i > #entries then s:Hide() end
    end
end

-------------------------------------------------------------------
-- The cast buttons
-------------------------------------------------------------------
local function CastButton(g, i)
    local size = g.size()
    local b = CreateFrame("Button", nil, g.secure, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown", "AnyUp")   -- the template keeps the one the key-down setting wants
    b:SetAttribute("type", "spell")
    g.setup(b)
    b:SetSize(size, size)
    b:SetFrameLevel(g.secure:GetFrameLevel() + 12)
    g.place(b, g.anchor, i)
    b:SetScript("OnEnter", function(self)
        local e = entries[i]
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(e.cast or e.id)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    g.casts[i] = b
    return b
end

-- out of a fight only
local function Secure(g)
    for i, e in ipairs(entries) do
        if Allowed(g, e) then
            local b = g.casts[i] or CastButton(g, i)
            b:SetAttribute("spell", e.cast or e.name)
            b:Show()
        elseif g.casts[i] then
            g.casts[i]:SetAttribute("spell", nil)
            g.casts[i]:Hide()
        end
    end
    for i, b in pairs(g.casts) do
        if i > #entries then
            b:SetAttribute("spell", nil)
            b:Hide()
        end
    end
end

local function SecureAll()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    for _, g in ipairs(groups) do Secure(g) end
    if ns.PartyHealPetTargets then ns.PartyHealPetTargets() end
end

-- the engine's containers read their unit afresh
local function FollowGroup(g)
    local unit = g.unit()
    if not unit then return end
    for _, s in pairs(g.slots) do
        SetUnit(s.auras, unit)
        SetUnit(s.cure, unit)
    end
end

local function NotDead(e) return e.need ~= "dead" end

-------------------------------------------------------------------
-- Controller pictures and Deck Heal's gold frame, on the row
-------------------------------------------------------------------
local function GamepadStyle()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
end

-- Blizzard's friendly targeting: the D-pad for party1-4, the bottom face
-- button for you (heals.lua's KEYS)
local KEYS = {
    player = GAMEPAD_FACE_BOTTOM or "PAD1",
    party1 = GAMEPAD_DPAD_TOP or "PADDUP",
    party2 = GAMEPAD_DPAD_RIGHT or "PADDRIGHT",
    party3 = GAMEPAD_DPAD_BOTTOM or "PADDDOWN",
    party4 = GAMEPAD_DPAD_LEFT or "PADDLEFT",
}

local function HintsOn()
    if not (DeckUIForeverOrbsDB.hotPadHints ~= false and GamepadStyle()) then return false end
    if IsInRaid() then return false end
    local ok, on = pcall(C_CVar.GetCVarBool, "GamepadUsePartyTargeting")
    return not ok or on ~= false
end

local function FriendlyModifierDown()
    return GamepadMode and GamepadMode.IsTargetingModifierDown and GamepadTargetingState
        and GamepadMode.IsTargetingModifierDown(GamepadTargetingState.FRIENDLY) or false
end

-- Blizzard's picture of the key at the foot of the class icon; nil where
-- the template is missing
local function Glyph(row, key)
    local ok, g = pcall(CreateFrame, "Frame", nil, row, "InputIconTextureFrameTemplate")
    if not (ok and g and g.SetInputKey) then return nil end
    g:SetInputKey(key)
    g.key = key
    g:SetSize(18, 18)
    g:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", -4, -4)
    g:SetFrameLevel(row:GetFrameLevel() + 8)
    g:SetAlpha(0)
    return g
end

local function Ring(row)
    local r = CreateFrame("Frame", nil, row)
    r:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 2)
    r:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, -2)
    r:SetFrameLevel(row:GetFrameLevel() + 9)
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
    return r
end

-------------------------------------------------------------------
-- A name and a thin health bar: the pet line's and the target line's
-------------------------------------------------------------------
local function Label(parent, width, r, g, b)
    local name = parent:CreateFontString(nil, "OVERLAY")
    name:SetFont(ns.FONT, 10, "OUTLINE")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetWidth(width)
    name:SetTextColor(r, g, b)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, 4)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(HEALTH[1], HEALTH[2], HEALTH[3])
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.6)
    return name, bar
end

-- name and health as they come, secret or not
local function PaintLabel(name, bar, unit)
    pcall(name.SetText, name, UnitName(unit))
    pcall(bar.SetMinMaxValues, bar, 0, UnitHealthMax(unit))
    pcall(bar.SetValue, bar, UnitHealth(unit))
end

-------------------------------------------------------------------
-- The pet line under a row
-------------------------------------------------------------------
local function PlacePetLine(row)
    local line = row.DeckPartyHeal.pet
    local across = Across()
    line:ClearAllPoints()
    line:SetSize(ROW_W - PET_SHIFT, PetSize())
    line:SetPoint("TOPLEFT", row, "BOTTOMLEFT", PET_SHIFT, -2)
    -- side by side the pet's slots lie under the member's, where the name
    -- would be: the slots alone then
    line.name:SetShown(not across)
    line.bar:SetShown(not across)
end

local function PetLine(row)
    local h = row.DeckPartyHeal
    local line = CreateFrame("Frame", nil, row)
    line:SetFrameLevel(row:GetFrameLevel() + 1)
    line.name, line.bar = Label(line, 96, PET_BLUE[1], PET_BLUE[2], PET_BLUE[3])
    line.name:SetPoint("TOPLEFT", 0, 0)
    line.bar:SetPoint("BOTTOMLEFT", 0, 1)
    line:Hide()
    h.pet = line
    PlacePetLine(row)
    h.petGroup = NewGroup({
        anchor = row, owner = line, secure = row,
        size = PetSize, place = PlacePet,
        unit = function() return PetUnit(row) end,
        click = function() return PetUnit(row) end,
        allow = NotDead,
        setup = function(b)
            b:SetAttribute("useparent-unit", true)
            b:SetAttribute("unitsuffix", "pet")   -- party2 -> partypet2, player -> pet
        end,
    })
end

-- A click on the pet's name targets it, as the name did in the HoT window:
-- a secure button of the row over the name's place, on the row's pet. Out
-- of a fight only; it stands whether there is a pet or not (see above),
-- and steps aside side by side, where the pet's slots lie in that place.
local function PetTarget(row)
    local h = row.DeckPartyHeal
    if not h.pet then return end
    local b = h.petTarget
    if not b then
        b = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetAttribute("type", "target")
        b:SetAttribute("useparent-unit", true)
        b:SetAttribute("unitsuffix", "pet")
        b:SetFrameLevel(row:GetFrameLevel() + 12)
        b:SetScript("OnEnter", function(self)
            local pet = PetUnit(row)
            if not (pet and UnitExists(pet)) then return end
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit(pet)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        h.petTarget = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", row, "BOTTOMLEFT", PET_SHIFT, -2)
    b:SetSize(96, PetSize())
    b:SetShown(not Across())
end

-------------------------------------------------------------------
-- The target line above the list
-------------------------------------------------------------------
local function StripWanted() return DeckUIForeverOrbsDB.hotStranger ~= false end

local function PaintStrip()
    if not (strip and strip:IsShown()) then return end
    PaintLabel(strip.name, strip.bar, "target")
    -- solo, the driver shows the line for yourself too: transparent then
    strip:SetAlphaFromBoolean(UnitIsUnit("target", "player"), 0, 1)
end

-- out of a fight: the line is the parent of secure buttons
local function BuildStrip()
    if strip or not (ns.partyHolder and StripWanted()) then return end
    strip = CreateFrame("Frame", "DeckOrbsPartyTarget", UIParent)
    strip:SetSize(ROW_W, STRIP_H)
    strip:SetScale(ns.DeviceDB().partyScale or 1)
    strip:SetPoint("BOTTOMLEFT", ns.partyHolder, "TOPLEFT", 0, 8)
    local bg = strip:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(strip)
    bg:SetTexture(WHITE)
    bg:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.55), CreateColor(0, 0, 0, 0))
    strip.name, strip.bar = Label(strip, ROW_W - 12, GOLD[1], GOLD[2], GOLD[3])
    strip.name:SetFont(ns.FONT, 11, "OUTLINE")
    strip.name:SetPoint("TOPLEFT", 6, -2)
    strip.bar:SetPoint("BOTTOMLEFT", 6, 2)
    -- the name targets nothing new, but a click on the line should not fall
    -- through to the world
    strip:EnableMouse(true)
    strip.group = NewGroup({
        anchor = strip, owner = strip, secure = strip,
        size = Size, place = PlaceStrip,
        unit = function() return "target" end,
        click = function() return "target" end,
        allow = NotDead,   -- the driver hides the line for the dead
        setup = function(b) b:SetAttribute("unit", "target") end,
    })
    Fill(strip.group)
    Secure(strip.group)
    RegisterStateDriver(strip, "visibility", StripShown())
end

-- party.lua's ApplyPartyScale, out of a fight
function ns.PartyHealScale(scale)
    if strip then strip:SetScale(scale) end
    if ns.PartyHealPlaceRegen then ns.PartyHealPlaceRegen() end
end

-------------------------------------------------------------------
-- What changes while the rows stand: alpha and colour only
-------------------------------------------------------------------
local function Fighting()
    local v = UnitAffectingCombat("player")
    if Secret(v) then return true end
    return v and true or false
end

-- a HoT that is not running: red in a fight, grey out of it; the
-- resurrection: lit on the dead
local function PaintGroup(g, fighting)
    local click = g.click()
    for _, s in pairs(g.slots) do
        local e = s.entry
        if e and e.kind == "hot" then
            Warn(s, e, click)
            if fighting then
                s.rim:SetVertexColor(MISSING[1], MISSING[2], MISSING[3], 1)
                s.icon:SetAlpha(0.7)
            else
                s.rim:SetVertexColor(0.35, 0.33, 0.3, 1)
                s.icon:SetAlpha(0.45)
            end
        elseif e and e.need == "dead" and click then
            s.dead:SetAlphaFromBoolean(UnitIsDeadOrGhost(click), 1, 0)
        end
    end
end

local function PaintPet(row, fighting)
    local h = row.DeckPartyHeal
    if not h.pet then return end
    local pet = PetUnit(row)
    local there = pet and UnitExists(pet)
    if Secret(there) then there = h.pet:IsShown() end   -- kept from us: as it was
    there = there and true or false
    if there ~= h.pet:IsShown() then
        h.pet:SetShown(there)
        if there then FollowGroup(h.petGroup) end
    end
    if not there then return end
    PaintLabel(h.pet.name, h.pet.bar, pet)
    PaintGroup(h.petGroup, fighting)
end

-- the slot of a spell, by name; nil when the rows have none for it
local function SlotOf(name)
    for i, e in ipairs(entries) do
        if e.name == name then return i end
    end
    return nil
end

local function KeysWanted() return DeckUIForeverOrbsDB.padHealRows ~= false end

-- for padheal.lua: the rows show every key of the layer, the bar may stay away
function ns.PartyHealShowsKeys()
    if not (started and KeysWanted() and ns.PadHealSpellList) then return false end
    local list = ns.PadHealSpellList()
    if #rows == 0 or #list == 0 then return false end
    for _, spell in ipairs(list) do
        if not SlotOf(spell.name) then return false end
    end
    return true
end

-- Blizzard's picture of a face button, or its letter in our font
local function KeyPicture(row, def)
    local ok, g = pcall(CreateFrame, "Frame", nil, row, "InputIconTextureFrameTemplate")
    if ok and g and g.SetInputKey and def.glyph then
        g:SetInputKey(def.glyph)
    else
        g = CreateFrame("Frame", nil, row)
        local t = g:CreateFontString(nil, "OVERLAY")
        t:SetFont(ns.FONT, 11, "OUTLINE")
        t:SetPoint("CENTER")
        t:SetTextColor(1, 1, 1)
        t:SetText(def.short or "?")
    end
    g:SetSize(15, 15)
    g:SetFrameLevel(row:GetFrameLevel() + 14)   -- above the cast button
    g:EnableMouse(false)
    g:SetAlpha(0)
    return g
end

-- the face buttons' pictures on the icons of the picked row; alpha and
-- anchors of plain frames only, so the layer's snippets may ask for it in a fight
local function PaintKeys(row, on, page, spells, defs, per)
    local h = row.DeckPartyHeal
    if not (on or h.keys) then return end
    h.keys = h.keys or {}
    for i, def in ipairs(defs or {}) do
        local spell = on and spells[(page - 1) * per + i] or nil
        local index = spell and SlotOf(spell.name)
        local s = index and h.group.slots[index]
        local g = h.keys[i]
        if s and s:IsShown() then
            if not g then
                g = KeyPicture(row, def)
                h.keys[i] = g
            end
            if g.slot ~= s then
                g.slot = s
                g:ClearAllPoints()
                g:SetPoint("CENTER", s, "BOTTOMRIGHT", -2, 3)
            end
            g:SetAlpha(1)
        elseif g then
            g:SetAlpha(0)
        end
    end
end

local function Paint(row, fighting, hints, lit, picked, keys)
    local h = row.DeckPartyHeal
    local unit = row:GetAttribute("unit")   -- the token the header gave the row: what a click heals
    if not unit then return end
    PaintGroup(h.group, fighting)
    PaintPet(row, fighting)
    h.ring:SetAlpha((picked and picked == unit) and 1 or 0)
    PaintKeys(row, keys ~= nil and keys.unit == unit, keys and keys.page, keys and keys.spells,
        keys and keys.defs or h.keyDefs, keys and keys.per)
    if keys then h.keyDefs = keys.defs end
    -- with Deck Heal on, the D-pad key that picks this member there (by
    -- role; false: none, the layer starts on this member)
    local key = KEYS[unit]
    local heal = key and ns.PadHealGlyph and ns.PadHealGlyph(unit)
    local shown = heal == nil and key or heal
    if hints and shown and not h.glyph and not h.noGlyph then
        h.glyph = Glyph(row, shown)
        h.noGlyph = not h.glyph
    end
    if h.glyph then
        if shown and h.glyph.key ~= shown then
            h.glyph:SetInputKey(shown)
            h.glyph.key = shown
        end
        h.glyph:SetAlpha((hints and shown) and (lit and 1 or 0.45) or 0)
    end
end

-------------------------------------------------------------------
-- Cooldown clocks (hotCooldown)
-------------------------------------------------------------------
local function SlotCooldown(s)
    if s.cd then return s.cd end
    local cd = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
    cd:EnableMouse(false)
    cd:SetSwipeTexture(D.MASK)
    cd:SetSwipeColor(0, 0, 0, 0.8)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetHideCountdownNumbers(false)
    s.cd = cd
    return cd
end

-- laid out once per kind and size: a HoT has the aura's clock on the icon
-- already, so its cooldown is a small number on the top edge; a heal gets
-- the sweep; the resurrection's rides on its picture and fades with it
local function StyleCooldown(s, e)
    local cd = SlotCooldown(s)
    local kind = e.need or e.kind
    if s.cdKind == kind then return cd end
    s.cdKind = kind
    local size = s.group.size()
    local parent = e.need == "dead" and s.dead or s
    cd:SetParent(parent)
    cd:SetFrameLevel(parent:GetFrameLevel() + (parent == s and 8 or 1))
    cd:ClearAllPoints()
    if e.kind == "hot" then
        cd:SetSize(size * 0.7, size * 0.7)
        cd:SetPoint("CENTER", s, "TOP", 0, 0)
        cd:SetDrawSwipe(false)
        if cd.SetCountdownFont then cd:SetCountdownFont(ns.CountdownFont(size * 0.8)) end
    else
        cd:SetAllPoints(s)
        cd:SetDrawSwipe(true)
        if cd.SetCountdownFont then cd:SetCountdownFont(ns.CountdownFont(size)) end
    end
    return cd
end

local function ApplyCooldowns()
    cdDirty = false
    local on = Opt("hotCooldown") and ns.HotEntryCooldown
    local asked = {}
    for _, g in ipairs(groups) do
        for _, s in pairs(g.slots) do
            local e = s.entry
            if not on or not e or e.need == "cure" then
                if s.cd then s.cd:Clear() end
            else
                local answer = asked[e]
                if answer == nil then
                    answer = ns.HotEntryCooldown(e)
                    asked[e] = answer
                end
                local cd = StyleCooldown(s, e)
                if not answer then
                    cd:Clear()
                elseif type(answer) == "table" and answer[1] then
                    cd:SetCooldown(answer[1], answer[2])
                elseif cd.SetCooldownFromDurationObject then
                    pcall(cd.SetCooldownFromDurationObject, cd, answer)
                end
            end
        end
    end
end

-- the switch on the settings page
function ns.PartyHealCooldowns()
    cdDirty = true
end

local function PaintAll()
    if cdDirty then ApplyCooldowns() end
    local fighting, hints = Fighting(), HintsOn()
    local lit = hints and (FriendlyModifierDown() or (ns.PadHealActive and ns.PadHealActive())) or false
    local picked = ns.PadHealPicked and ns.PadHealPicked() or nil
    local keys
    if KeysWanted() and ns.PadHealKeys then
        local unit, page, spells, defs, per = ns.PadHealKeys()
        if unit then keys = { unit = unit, page = page or 1, spells = spells, defs = defs, per = per } end
    end
    for _, row in ipairs(rows) do
        if row:IsShown() then Paint(row, fighting, hints, lit, picked, keys) end
    end
    for _, tile in ipairs(tiles) do
        if tile:IsShown() then PaintGroup(tile.DeckPartyHeal.group, fighting) end
    end
    if ns.HotRegenUpdate then ns.HotRegenUpdate() end
    if strip and strip:IsShown() then
        PaintGroup(strip.group, fighting)
        PaintStrip()
    end
end

-- padheal.lua calls this when its layer or its pick changes
function ns.PartyHealRefresh()
    if started then PaintAll() end
end

-- the containers follow the row's unit: a row that changed hands, or a
-- token someone else stands behind now
local function Follow(row)
    local h = row.DeckPartyHeal
    if not h then return end
    FollowGroup(h.group)
    if h.petGroup then FollowGroup(h.petGroup) end
end

oUF:AddElement("DeckPartyHeal", function(self)
    if not self.DeckPartyHeal then return end
    Follow(self)
    if started then PaintAll() end
end, function(self)
    if self.DeckPartyHeal then return true end
end, function() end)

-------------------------------------------------------------------
-- The five rows, made before a fight can ask for one
-------------------------------------------------------------------
-- The header makes a member's button when the member appears, in a fight
-- too, where our style function may not set up a secure child. Asked for
-- units before its first (startingIndex below 1), it makes the buttons
-- ahead; back at 1 it lays the members out as before and hides the rest.
local function Precreate()
    local header = ns.partyHeader
    if not header or InCombatLockdown() or not header:IsVisible() then return end
    if header:GetAttribute("child" .. ROWS) then return end
    local count = (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) + 1
    header:SetAttribute("startingIndex", count - ROWS + 1)
    header:SetAttribute("startingIndex", 1)
end

-------------------------------------------------------------------
-- Rows, list, events
-------------------------------------------------------------------
-- sizes and places of every piece; the cast buttons are protected
local function Resize()
    for _, g in ipairs(groups) do
        local size = g.size()
        for i, s in pairs(g.slots) do
            s:SetSize(size, size)
            g.place(s, g.anchor, i)
            s.cdKind = nil   -- the clock is laid out for the new size
        end
        cdDirty = true
        for i, b in pairs(g.casts) do
            b:SetSize(size, size)
            g.place(b, g.anchor, i)
        end
    end
    for _, row in ipairs(rows) do
        if row.DeckPartyHeal.pet then
            PlacePetLine(row)
            PetTarget(row)
        end
    end
end

-- every row's pet button, out of a fight (SecureAll, after a row made in one)
function ns.PartyHealPetTargets()
    if InCombatLockdown() then return end
    for _, row in ipairs(rows) do PetTarget(row) end
end

-- a list of another length: the raid's icons change their size with it,
-- the party's aura icons step aside, the raid's tiles keep their distance
local function Relayout()
    if laidFor == #entries then return end
    laidFor = #entries
    ns.OutOfCombat("partyHealResize", Resize)
    if ns.ApplyPartyLayout then ns.ApplyPartyLayout() end
    if ns.RaidHealOn() and ns.ApplyRaidLayout then ns.ApplyRaidLayout() end
end

-- the mana regeneration text (heals.lua's, hotRegen): above the target
-- line of the party list, above the raid in a raid
local function PlaceRegen()
    if not ns.HotRegenAttach then return end
    local dev = ns.DeviceDB()
    if IsInRaid() and ns.RaidHealOn() and ns.raidHolder then
        ns.HotRegenAttach(ns.raidHolder, 0, 2, dev.raidScale or 1)
    elseif ns.partyHolder then
        ns.HotRegenAttach(ns.partyHolder, 0, StripWanted() and (8 + STRIP_H) or 2, dev.partyScale or 1)
    end
end
ns.PartyHealPlaceRegen = function() if started then PlaceRegen() end end

-- the raid's buttons ahead of a fight, as the party's: a header per group
-- (five each), or one for the whole raid
local function PrecreateRaid()
    if not (ns.RaidHealOn() and ns.raidHeaders) or InCombatLockdown() or not IsInRaid() then return end
    local whole = DeckUIForeverOrbsDB.raidSort ~= "group"
    local inGroup, total = {}, GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, total do
        local _, _, subgroup = GetRaidRosterInfo(i)
        if Secret(subgroup) or not subgroup then return end
        inGroup[subgroup] = (inGroup[subgroup] or 0) + 1
    end
    for group, header in ipairs(ns.raidHeaders) do
        local need = whole and (MAX_RAID_MEMBERS or 40) or ROWS
        local count = whole and total or (inGroup[group] or 0)
        if header:IsVisible() and count > 0 and not header:GetAttribute("child" .. need) then
            header:SetAttribute("startingIndex", count - need + 1)
            header:SetAttribute("startingIndex", 1)
        end
    end
end

local function Sync()
    ReadList()
    for _, g in ipairs(groups) do Fill(g) end
    SecureAll()
    Relayout()
    PaintAll()
end

-- the list of your own spells changed on the settings page (hotCustom)
function ns.PartyHealSync()
    if started then Sync() end
end

local driver = CreateFrame("Frame")
local elapsed = 0
local SPEC_EVENTS = { "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }

local function Start()
    if started or not ns.PartyHealOn() then return end
    started = true
    loadedSize = Size()
    ReadList()
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
                         "PLAYER_REGEN_DISABLED", "INPUT_DEVICE_INTERFACE_TRANSITION", "PLAYER_ROLES_ASSIGNED",
                         "PLAYER_TARGET_CHANGED", "UNIT_PET", "SPELL_UPDATE_COOLDOWN",
                         unpack(SPEC_EVENTS) }) do
        if not C_EventUtils or C_EventUtils.IsEventValid(e) then driver:RegisterEvent(e) end
    end
    driver:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pending then SecureAll() end
            Precreate()
            PrecreateRaid()
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
            if event ~= "UNIT_PET" then
                Precreate()
                PrecreateRaid()
                PlaceRegen()
            end
            for _, row in ipairs(rows) do Follow(row) end
            for _, tile in ipairs(tiles) do Follow(tile) end
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            cdDirty = true   -- the next tick asks, once for a burst of events
            return
        elseif event == "PLAYER_TARGET_CHANGED" then
            if strip then FollowGroup(strip.group) end
        elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE"
            or event == "SPELLS_CHANGED" then
            Sync()
            return
        end
        PaintAll()
    end)
    driver:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < POLL then return end
        elapsed = 0
        PaintAll()
    end)
    if GamepadMode and GamepadMode.RegisterTargetModifierStateChanged then
        pcall(GamepadMode.RegisterTargetModifierStateChanged, PaintAll, driver)
    end
end

-- party.lua asks for the list before it makes a row's aura icons
function ns.PartyHealStart() Start() end

-- party.lua's style function: a new row. Its pictures at once; its cast
-- buttons at once out of a fight, else after it.
function ns.PartyHealRow(row)
    if row.DeckPartyHeal then return end
    Start()
    local h = { ring = Ring(row) }
    row.DeckPartyHeal = h
    rows[#rows + 1] = row
    h.group = NewGroup({
        anchor = row, owner = row, secure = row,
        size = Size, place = PlaceMember,
        unit = function() return Unit(row) end,
        click = function() return row:GetAttribute("unit") end,
        setup = function(b) b:SetAttribute("useparent-unit", true) end,
    })
    Fill(h.group)
    if PetsOn() then
        PetLine(row)
        Fill(h.petGroup)
    end
    if InCombatLockdown() then
        pending = true
    else
        Secure(h.group)
        if h.petGroup then
            Secure(h.petGroup)
            PetTarget(row)
        end
    end
end

-- raid.lua's style function: a new tile, the same slots in a line under it
function ns.RaidHealTile(tile)
    if tile.DeckPartyHeal or not ns.RaidHealOn() then return end
    Start()
    local h = {}
    tile.DeckPartyHeal = h
    tiles[#tiles + 1] = tile
    h.group = NewGroup({
        anchor = tile, owner = tile, secure = tile,
        size = RaidSize, place = PlaceRaid,
        unit = function() return Unit(tile) end,
        click = function() return tile:GetAttribute("unit") end,
        setup = function(b) b:SetAttribute("useparent-unit", true) end,
    })
    Fill(h.group)
    if InCombatLockdown() then
        pending = true
    else
        Secure(h.group)
    end
end

-- for raid.lua's VGap: how much further apart the tiles stand
function ns.RaidHealGap()
    if not ns.RaidHealOn() then return 0 end
    Start()
    return RaidSize() + 3
end

-- the icon size (device hotScale), the layout side by side, the raid
-- tile's width: the pieces move out of a fight, the engine's icons keep
-- their size until the reload
function ns.ApplyPartyHealSize()
    if not started then return end
    laidFor = -1
    Relayout()
    D.NeedReload("partyHealScale", Size() ~= loadedSize)
end

oUF:Factory(function()
    if not ns.PartyHealOn() then
        -- the HoT window is gone (2026-11-26): whoever had it on is told once where its icons live now
        if DeckUIForeverOrbsDB.hotTracker and not DeckUIForeverOrbsDB.hotWindowGone then
            DeckUIForeverOrbsDB.hotWindowGone = true
            print("DeckUIForever: the HoT window has moved onto the party list. Switch on \"HoTs, heals and cures on the party list\" under /df, Frames, Group - it needs our party list - or press \"I am a healer\" on the first page.")
        end
        return
    end
    Start()
    local header = ns.partyHeader
    if header then
        header:HookScript("OnShow", function() Precreate() end)
        Precreate()
    end
    ns.OutOfCombat("partyHealStrip", BuildStrip)
    PrecreateRaid()
    PlaceRegen()
    Relayout()
    PaintAll()
end)

-- /orbs hots, while the heals are on the party list
function ns.PartyHealDebug()
    local made = 0
    local header = ns.partyHeader
    while header and header:GetAttribute("child" .. (made + 1)) do made = made + 1 end
    print(("DeckUIForever party heals: %d rows with slots, %d header buttons, %d slots (%d px), pets %s, target line %s, in combat: %s%s."):format(
        #rows, made, #entries, Size(), PetsOn() and "on" or "off",
        strip and (strip:IsShown() and "shown" or "hidden") or (StripWanted() and "not built" or "off"),
        tostring(InCombatLockdown()), pending and ", cast buttons wait for the end of the fight" or ""))
    for i, e in ipairs(entries) do
        print(("  slot %d: %s (%s%s), casts %s"):format(i, tostring(e.name), tostring(e.kind),
            e.need and (", " .. e.need) or "", tostring(e.cast or e.name)))
    end
    local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
    for i, row in ipairs(rows) do
        local h = row.DeckPartyHeal
        print(("  row %d: unit %s, shown %s, %d slots, %d cast buttons; pet %s%s"):format(i,
            tostring(row:GetAttribute("unit")), tostring(row:IsShown()), Count(h.group.slots), Count(h.group.casts),
            tostring(PetUnit(row)), h.pet and (h.pet:IsShown() and " (line shown)" or " (no pet)") or ""))
    end
    print(("  raid: %s, %d tiles with slots, icon %d px"):format(ns.RaidHealOn() and "on" or "off", #tiles, RaidSize()))
    print(("  Deck Heal keys on the rows: %s (option %s)"):format(tostring(ns.PartyHealShowsKeys()),
        KeysWanted() and "on" or "off"))
    print(("  Deck Heal picked: %s; controller pictures: %s"):format(
        tostring(ns.PadHealPicked and ns.PadHealPicked() or nil), tostring(HintsOn())))
end
