local ADDON, ns = ...
local D = DeckUIForever
local oUF = ns.oUF

-------------------------------------------------------------------
-- Your HoTs and the buffs on your party: a line per member, round icons
-------------------------------------------------------------------
-- The healer's side of debuffs.lua (owner, 2026-11-06: "an overview in
-- the same style for healers and HoTs"), rebuilt around the party on
-- 2026-11-07 (owner: "targets outside our party only while we target
-- them, but for every party member, me included, all the data in one
-- window - which HoTs and buffs are on them") and, the same evening,
-- made compact (owner, after the first look at the table: "I don't like
-- the look at all, much more compact, maybe no bars but circles that
-- close"). One line per party member, you first, always listed while
-- you are in a party (solo: you alone): the name, then one round icon
-- per heal you keep up on them - a druid's Rejuvenation and Regrowth, a
-- priest's Renew and the shield - with a clock that closes over it as
-- the heal runs out, then the buffs on them as round icons. A friendly
-- target outside the party (a stranger, an NPC, a raid member of another
-- group) gets a line of its own at the end while it is the target and
-- loses it with the next target. DeckUIForeverOrbsDB.hotTracker, off by
-- default, switched without a reload; /orbs hots prints what it sees.
--
-- Built as debuffs.lua is, and for the same reason: no Lua of ours reads
-- an aura. Each heal's icon is Blizzard's own aura widget, a
-- CustomAuraContainer with one slot filtered to that spell's IDs
-- (HELPFUL|PLAYER: yours, on a friend), whose button the engine fills in
-- combat too - the icon, a Cooldown frame of ours driven from the aura's
-- duration (SetDurationCooldown: the dark swipe closes over the icon,
-- the time in the middle), the stack count and a gold rim over the last
-- 30% (AddPandemicRegion). Under it a layer of ours: the same icon with
-- a red rim in a fight ("missing"), dimmed out of it (hotIdle) or not
-- there at all - the slot then stays empty, so the heals line up in
-- columns across the members.
--
-- The party's unit tokens (player, party1-4) are what the containers
-- follow, so the lines are as combat-safe as the party frames: who
-- stands behind party2 is the engine's business, a roster change only
-- re-reads the tokens. The buffs after the heals (hotAllBuffs, off):
-- yours up to a minute, as in 1.2.0 - the raid buffs (half an hour of
-- Fortitude) would fill the line otherwise - or every buff on the member,
-- long ones too. One line, never wrapped: a member's line is as high as
-- an icon, whatever the engine puts in it.
--
-- The list's IDs leave the target frame's buff icons (hotExclude, on, the
-- same trick as debuffs.lua's ns.targetDebuffs: ns.targetBuffs, filled by
-- layout.lua and ffstyle.lua). Those icons show every buff, not only yours,
-- so another druid's Rejuvenation goes from the icons too - hence the
-- switch.
--
-- Gone with the party table (2026-11-07): the focus column, "you when you
-- have no friendly target" (you are always listed), the kept columns of
-- 1.2.0 (a party member never leaves the window, and a stranger's line
-- is meant to go with the target), the rows at the target frame (a table
-- has no frame to hang from), and with the icons the capsules, the
-- names and the width. Seen in game 2026-11-07 (owner: "viel besser").
--
-- Click to cast (hotHealer, off, /reload; owner 2026-11-07: "a healer
-- mode - click the missing icon and the HoT goes on the target"). Every
-- slot gets a SecureActionButton over the icon (type spell, the heal's
-- name - the highest rank - and the line's unit token), the name one
-- that targets the member. Their attributes never change in a fight:
-- each slot's spell and unit are fixed, so the game lets them cast in
-- combat. The price: a secure button protects its parents, so in combat
-- nothing of the window may be moved, sized, shown or hidden by us
-- (Locked). The layout then runs only out of combat - every member's
-- line has a fixed row (party tokens are contiguous, so a member who
-- joins mid-fight lands in the next free row; a stranger's line sits in
-- that same row until the fight ends), the game shows and hides the
-- lines itself through state drivers ([@party2,exists] and
-- [@target,help,nodead,noparty]: a friendly target outside the party -
-- solo, targeting yourself shows you twice, the game cannot tell), and
-- a spell learnt in a fight reaches its button after it. The empty
-- icons always show in this mode, so there is something to click. The
-- tooltip is then the spell's, not the aura's.
--
-- Controller glyphs (hotPadHints, on; owner 2026-11-07, after the look
-- at Blizzard's gamepad targeting: "show the right keys"). In Blizzard's
-- gamepad style the friendly targeting bar (Blizzard_GamepadActionBars/
-- TargetActionBars/FriendlyTargetingActionBar.lua) targets party1-4 with
-- the D-pad - top, right, bottom, left - and you with the bottom face
-- button while the friendly target modifier is held (CVar
-- GamepadUsePartyTargeting; in a raid the D-pad walks Blizzard's raid
-- frames instead). Each line shows that key's picture before the name
-- (InputIconTextureFrameTemplate, as gamepad.lua's LT/RT hints), dim
-- until the modifier is held (GamepadMode.RegisterTargetModifierStateChanged,
-- HoldBindings.lua). Pictures and alpha only, nothing protected: the
-- window itself cannot join Blizzard's window navigation - that takes
-- addon frames out of combat only, and a window that is always shown
-- would count as open and block the HUD's own targeting.
-------------------------------------------------------------------
local ICON, NAME_W, PAD = 22, 64, 4   -- icon size as shipped (hotScale scales it), the name's width, the edges
local SPACING = 2                      -- between the icons
local MAX_OTHER, MAX_ALL = 6, 10       -- buff icons after the heals: yours / every buff
local OTHER_MAX_DURATION = 60
local POLL = 0.25
local GAP = 2                          -- between the lines
local GOLD = { 1, 0.82, 0.3 }
local MISSING = { 0.9, 0.3, 0.3 }

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Ask(v) if Secret(v) then return nil end return v end

-------------------------------------------------------------------
-- What each healer keeps up
-------------------------------------------------------------------
-- id: the buff (its name and icon); known: the spell that tells whether
-- you can cast it, when that is not the same one. Classic's first ranks,
-- as in debuffs.lua; a slot takes every rank of the name. Only druids and
-- priests have HoTs in Classic - a shaman's and a paladin's healing is
-- direct, and Earth Shield, Lifebloom and Prayer of Mending are later
-- expansions' - so the other classes get the buff icons alone. Power Word:
-- Shield is an absorb, not a HoT, but it is what a priest keeps on the tank.
local LISTS = {
    DRUID  = { { id = 774 }, { id = 8936 } },   -- Rejuvenation, Regrowth
    PRIEST = { { id = 139 }, { id = 17 } },     -- Renew, Power Word: Shield
}

local function SpellName(id)
    return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
end

local function SpellIcon(id)
    return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
end

local function Known(id)
    return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
end

local function ListKey()
    return (select(2, UnitClass("player")))
end

-- every spell ID a slot should take: the list's IDs and each spellbook
-- entry of the same name (the ranks the character knows)
local function RankIDs(e, name)
    local ids = { [e.id] = true }
    if e.known then ids[e.known] = true end
    if not (name and C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return ids end
    local bank = Enum.SpellBookSpellBank.Player
    local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
            local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
            if item and item.name == name and (not spellType or item.itemType == spellType) then
                if item.spellID then ids[item.spellID] = true end
                if item.actionID then ids[item.actionID] = true end
            end
        end
    end
    return ids
end

local entries = {}
local allIDs = {}

-- The target frame's buff icons leave out what runs here. A registered
-- container brings its own candidate filters (the orb's maxDuration and
-- its exclusions): ours are merged in, not put in their place, and come
-- out again when the window or the switch goes off.
local function Merged(base, exclude)
    local filters = {}
    for k, v in pairs(base or {}) do filters[k] = v end
    if exclude then
        local ids = {}
        for id in pairs((base and base.excludeSpellIDs) or {}) do ids[id] = true end
        for id in pairs(allIDs) do ids[id] = true end
        filters.excludeSpellIDs = ids
    end
    return filters
end

function ns.ApplyHotExclusion()
    local exclude = DeckUIForeverOrbsDB.hotTracker and DeckUIForeverOrbsDB.hotExclude ~= false
    for _, entry in ipairs(ns.targetBuffs or {}) do
        pcall(entry.container.SetAuraGroupCandidateFilters, entry.container, entry.key, Merged(entry.base, exclude))
    end
end

local function Rebuild()
    wipe(entries)
    allIDs = {}
    for _, e in ipairs(LISTS[ListKey()] or {}) do
        if Known(e.known or e.id) then
            local n = SpellName(e.id)
            if n then
                local ids = RankIDs(e, n)
                for id in pairs(ids) do allIDs[id] = true end
                entries[#entries + 1] = { name = n, icon = SpellIcon(e.id), id = e.id, ids = ids }
            end
        end
    end
    ns.ApplyHotExclusion()
end

-------------------------------------------------------------------
-- The window: a line per party member, one more for a stranger
-------------------------------------------------------------------
local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.FONT, size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- the icon size per device (ns.DeviceDB().hotScale, a percentage of ICON)
local function Size()
    return math.max(10, math.floor(ICON * (ns.DeviceDB().hotScale or 100) / 100 + 0.5))
end
local function Slot() return Size() + SPACING end

local holder = CreateFrame("Frame", "DeckOrbsHots", UIParent)
holder:SetSize(200, 60)
holder.defaultPoint = { "CENTER", UIParent, "CENTER", -260, -120 }   -- the debuffs' mirror image, left of the player
holder:SetPoint(unpack(holder.defaultPoint))
holder:Hide()

-- frameless, as the debuffs: the unit's name in gold, the icons after
-- it. A line keeps its unit token for good: the containers in it are
-- made on that token.
local preview = false
local Update   -- below
local loadedSize   -- the icon size this session loaded: a change back clears the reload flag
local healer = false   -- click to cast (hotHealer), read once at the factory: the buttons stay for the session

-- in the healer mode the window is protected: in a fight nothing of it
-- moves, shows or hides by our hand
local function Locked() return healer and InCombatLockdown() end

-- a secure button: a click casts (type spell) or targets (type target)
-- the line's unit; made and set up out of combat only
local function SecureButton(parent, kind, unit)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown", "AnyUp")   -- the template keeps the one the key-down setting wants
    b:SetAttribute("type", kind)
    b:SetAttribute("unit", unit)
    return b
end

local function Line(parent, unit)
    local c = CreateFrame("Frame", nil, parent)
    c.unit = unit
    c.title = Text(c, 11)
    c.title:SetPoint("LEFT", PAD, 0)
    c.title:SetWidth(NAME_W)
    c.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.slots = {}
    if healer then
        -- the name targets the member; the game shows and hides the line
        local b = SecureButton(c, "target", unit)
        b:SetPoint("LEFT", 0, 0)
        b:SetSize(PAD + NAME_W + 2, Size())
        c.target = b
        if unit == "target" then
            RegisterStateDriver(c, "visibility", "[@target,help,nodead,noparty] show; hide")
        else
            RegisterStateDriver(c, "visibility", ("[@%s,exists] show; hide"):format(unit))
        end
    else
        c:Hide()
    end
    return c
end

-- you first, then the party in the game's order; the stranger's line last,
-- so the table does not shift when a target comes and goes
local PARTY = { "player", "party1", "party2", "party3", "party4" }
local members, stranger, lines = {}, nil, {}

local function MakeLines()
    for i, unit in ipairs(PARTY) do members[i] = Line(holder, unit) end
    stranger = Line(holder, "target")
    for _, c in ipairs(members) do lines[#lines + 1] = c end
    lines[#lines + 1] = stranger
end

-- under one another (the default) or side by side, per device
local function Across() return ns.DeviceDB().hotAcross and true or false end

-------------------------------------------------------------------
-- Controller glyphs: the key that targets the line's member
-------------------------------------------------------------------
local function GamepadStyle()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
end

-- Blizzard's names for the keys (the legend's globals, else the binding names)
local KEYS = {
    player = GAMEPAD_FACE_BOTTOM or "PAD1",
    party1 = GAMEPAD_DPAD_TOP or "PADDUP",
    party2 = GAMEPAD_DPAD_RIGHT or "PADDRIGHT",
    party3 = GAMEPAD_DPAD_BOTTOM or "PADDDOWN",
    party4 = GAMEPAD_DPAD_LEFT or "PADDLEFT",
}
local SHORT = { player = "A", party1 = "^", party2 = ">", party3 = "v", party4 = "<" }
local DIM, LIT = 0.4, 1

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

-- Blizzard's picture of the key (the right one for the pad in use);
-- without the template, the key's short name in our font
local function Glyph(c, key)
    local size = Size()
    local ok, g = pcall(CreateFrame, "Frame", nil, c, "InputIconTextureFrameTemplate")
    if not (ok and g and g.SetInputKey) then
        g = CreateFrame("Frame", nil, c)
        local t = g:CreateFontString(nil, "OVERLAY")
        t:SetFont(ns.FONT, 11, "OUTLINE")
        t:SetPoint("CENTER")
        t:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        t:SetText(SHORT[c.unit] or "?")
    else
        g:SetInputKey(key)
    end
    g:SetSize(size, size)
    g:SetPoint("LEFT", c, "LEFT", PAD, 0)
    g:SetFrameLevel(c:GetFrameLevel() + 12)   -- above the name's button
    g:SetAlpha(0)
    return g
end

-- the name after the glyph while one shows, else at the edge
local function PlaceTitle(c, withGlyph)
    local shift = withGlyph and (Size() + 2) or 0
    c.title:ClearAllPoints()
    c.title:SetPoint("LEFT", PAD + shift, 0)
    c.title:SetWidth(math.max(10, NAME_W - shift))
end

-- alpha only: a glyph is made once and never shown or hidden, so the
-- protected lines of the healer mode are never touched in a fight
local function UpdateHints()
    local on = HintsOn()
    local lit = on and FriendlyModifierDown()
    for _, c in ipairs(members) do
        local key = KEYS[c.unit]
        if on and key and not c.glyph then c.glyph = Glyph(c, key) end
        if c.glyph then c.glyph:SetAlpha(on and (lit and LIT or DIM) or 0) end
        if (c.titleShifted or false) ~= (on and key ~= nil) then
            c.titleShifted = on and key ~= nil
            PlaceTitle(c, c.titleShifted)
        end
    end
end

function ns.ApplyHotHints() UpdateHints() end

-------------------------------------------------------------------
-- Icons: a layer of ours below, the engine's button above
-------------------------------------------------------------------
-- the round icon, the rim and the engine button's pieces are shared with
-- the debuff window's icon mode: ns.RoundIcon, ns.IconRim and
-- ns.AuraIconButton in debuffs.lua (loaded before this file)

-- Out of a fight the empty slots show only when asked for (hotIdle, off;
-- owner 2026-11-06: "turn this off, as an option") or in the unlock
-- preview (force). In a fight the red missing ones always show.
local function Idle() return DeckUIForeverOrbsDB.hotIdle and true or false end

local function SetStatic(s, fighting, force)
    local on = force or fighting or Idle() or healer
    s.icon:SetShown(on)
    s.rim:SetShown(on)
    s.icon:SetDesaturated(true)
    if fighting then
        s.rim:SetVertexColor(MISSING[1], MISSING[2], MISSING[3], 1)
        s.icon:SetAlpha(0.7)
    else
        s.rim:SetVertexColor(0.35, 0.33, 0.3, 1)
        s.icon:SetAlpha(0.4)
    end
end

-- a slot of the line: our static icon under the engine's one-slot container
local function SlotFrame(c, i)
    local s = c.slots[i]
    if s then return s end
    if Locked() then return nil end   -- a new slot's button cannot be set up in a fight
    local size = Size()
    s = CreateFrame("Frame", nil, c)
    s:SetSize(size, size)
    s.rim = ns.IconRim(s, 0.35, 0.33, 0.3, 1)
    s.icon = ns.RoundIcon(s:CreateTexture(nil, "ARTWORK"))
    s.icon:SetAllPoints(s)
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local auras = CreateFrame("AuraContainer", nil, s, "CustomAuraContainerTemplate")
    auras:SetAllPoints(s)
    auras:SetUnit(c.unit)
    auras:AddAuraSlot("hot", "HELPFUL|PLAYER", {
        candidateFilters = { includeSpellIDs = {} },
        initializeFrame = function(button)
            button:SetAllPoints(s)
            ns.AuraIconButton(button, size)
        end,
    })
    s.auras = auras
    if healer then
        -- above the engine's button: the click is ours, so is the tooltip
        local cast = SecureButton(s, "spell", c.unit)
        cast:SetAllPoints(s)
        cast:SetFrameLevel(s:GetFrameLevel() + 10)
        cast:SetScript("OnEnter", function(b)
            if not s.entry then return end
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(s.entry.id)
            GameTooltip:Show()
        end)
        cast:SetScript("OnLeave", GameTooltip_Hide)
        s.cast = cast
    end
    c.slots[i] = s
    return s
end

-- the slot's spell: the name casts the highest rank; in a fight the
-- attribute waits (pendingSpell), FillLine assigns again after it
local function Assign(s, e)
    s.entry = e
    s.icon:SetTexture(e.icon or 134400)
    pcall(s.auras.SetAuraSlotCandidateFilters, s.auras, "hot", { includeSpellIDs = e.ids or {} })
    if s.cast then
        if InCombatLockdown() then
            s.pendingSpell = e.name
        else
            s.cast:SetAttribute("spell", e.name)
            s.pendingSpell = nil
        end
    end
end

-- the buffs on the member, after the heals: yours up to a minute, or every
-- buff (hotAllBuffs); the list's IDs stay out either way, they have their
-- slots (so another druid's Rejuvenation is not shown - the filters
-- cannot tell whose it is)
local function AllBuffs() return DeckUIForeverOrbsDB.hotAllBuffs and true or false end
local function OthersFilter() return AllBuffs() and "HELPFUL" or "HELPFUL|PLAYER" end
local function OthersMax() return AllBuffs() and MAX_ALL or MAX_OTHER end

local function OthersCandidates()
    local f = { excludeSpellIDs = allIDs }
    if not AllBuffs() then f.maxDuration = OTHER_MAX_DURATION end
    return f
end

-- one line of icons, never wrapped: the line size holds every icon of
-- the larger limit, so a switch of the limit needs no new container
local function Others(c)
    if c.others then return c.others end
    local size = Size()
    local auras = CreateFrame("AuraContainer", nil, c, "CustomAuraContainerTemplate")
    auras:SetSize(MAX_ALL * Slot(), size)
    auras:SetUnit(c.unit)
    auras:SetFlowLayoutAnchorPoint("LEFT")
    auras:SetFlowLayoutAxis(ns.FLOW.Horizontal)
    auras:SetFlowLayoutMaximumLineSize(MAX_ALL * Slot())
    auras:SetFlowLayoutGrowthDirection(1, -1)
    auras:AddAuraGroup("others", OthersFilter(), {
        maxFrameCount = OthersMax(),
        candidateFilters = OthersCandidates(),
        layout = { elementSpacing = SPACING },
        initializeFrame = function(button)
            button:SetSize(size, size)
            ns.AuraIconButton(button, size)
        end,
    })
    c.others = auras
    return auras
end

-- the list's IDs may change (a new rank), or the buff switch: the groups follow
local function UpdateOthersFilter()
    for _, c in ipairs(lines) do
        if c.others then
            pcall(c.others.SetAuraGroupFilterString, c.others, "others", OthersFilter())
            pcall(c.others.SetAuraGroupMaxFrameCount, c.others, "others", OthersMax())
            pcall(c.others.SetAuraGroupCandidateFilters, c.others, "others", OthersCandidates())
        end
    end
end

function ns.ApplyHotBuffs()
    UpdateOthersFilter()
    if DeckUIForeverOrbsDB.hotTracker and not preview then Update() end
end

-- the slots follow a size change at once (the engine's pieces hang on
-- the button, the button on the slot); the buff icons were sized when
-- the engine made them and follow at the next reload
function ns.ApplyHotSize()
    local size = Size()
    ns.OutOfCombat("hotSize", function()
        for _, c in ipairs(lines) do
            for _, s in ipairs(c.slots) do s:SetSize(size, size) end
            if c.target then c.target:SetHeight(size) end
            if c.glyph then c.glyph:SetSize(size, size) end
            if c.titleShifted then PlaceTitle(c, true) end
        end
    end)
    D.NeedReload("hotScale", size ~= loadedSize)
    if DeckUIForeverOrbsDB.hotTracker and not preview then Update() end
end

-- the containers follow their unit token, not the unit behind it: a new
-- target, or a party token that changed hands, is read in afresh
local function RefreshUnit(c)
    for _, s in ipairs(c.slots) do pcall(s.auras.UpdateAllAuras, s.auras) end
    if c.others then pcall(c.others.UpdateAllAuras, c.others) end
end

-- the line's width: name, a slot per heal, the buff icons
local function LineWidth(slots)
    return PAD + NAME_W + 4 + slots * Slot() + OthersMax() * Slot() + PAD
end

-- lays the slots out after the name, the buffs after them, and sizes the line
local function Finish(c, shown)
    if Locked() then return end
    local size, slot = Size(), Slot()
    local x = PAD + NAME_W + 4
    for i, s in ipairs(c.slots) do
        if i <= shown then
            s:ClearAllPoints()
            s:SetPoint("LEFT", c, "LEFT", x, 0)
            if not s:IsShown() then
                s:Show()
                -- a slot that comes back reads its unit afresh
                pcall(s.auras.UpdateAllAuras, s.auras)
            end
            x = x + slot
        else
            s:Hide()
        end
    end
    local others = Others(c)
    others:ClearAllPoints()
    others:SetPoint("LEFT", c, "LEFT", x, 0)
    c:SetSize(LineWidth(shown), size)
end

-- a living friend; a secret answer counts as one, as the debuffs count it attackable
local function Friendly(unit)
    if not UnitExists(unit) then return false end
    if Ask(UnitCanAssist("player", unit)) == false then return false end
    return Ask(UnitIsDead(unit)) ~= true
end

local function Fighting()
    return Ask(UnitAffectingCombat("player")) ~= false
end

-- fills a line with the list for its unit
local function FillLine(c)
    local fighting = Fighting()
    for i, e in ipairs(entries) do
        local s = SlotFrame(c, i)
        if not s then break end
        if s.entry ~= e or s.pendingSpell then Assign(s, e) end
        SetStatic(s, fighting)
    end
    c.title:SetText(c.unit == "player" and "You" or UnitName(c.unit))
    c.title:Show()
    Finish(c, #entries)
    if not healer then c:Show() end
end

-- Every member's line has its row - the party tokens are contiguous, so
-- `count` members fill rows 0 to count-1 and the stranger takes row
-- `count` (in the healer mode a member who joins mid-fight lands there
-- too, until the fight ends). Under one another or side by side
-- (hotAcross, per device); the holder is sized to the rows in use.
local function Stack(count, extra)
    if Locked() then return end
    local across, size, w = Across(), Size(), LineWidth(#entries)
    local function Put(c, row)
        c:ClearAllPoints()
        if across then
            c:SetPoint("TOPLEFT", holder, "TOPLEFT", row * (w + GAP), 0)
        else
            c:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -row * (size + GAP))
        end
    end
    for i, c in ipairs(members) do Put(c, i - 1) end
    Put(stranger, count)
    local rows = math.max(count + (extra and 1 or 0), 1)
    if across then
        holder:SetSize(rows * (w + GAP) - GAP, size)
    else
        holder:SetSize(w, rows * (size + GAP) - GAP)
    end
end

-- the target stands in the table already (you or a party member): the
-- GUIDs say so without a secret, where UnitIsUnit may hand one back in a fight
local function InTable(guid)
    for _, unit in ipairs(PARTY) do
        if UnitExists(unit) and UnitGUID(unit) == guid then return true end
    end
    return false
end

-- a friendly target outside the party gets the last line while it lasts
local function StrangerOn()
    if not Friendly("target") then return false end
    local guid = UnitGUID("target")
    return guid ~= nil and not InTable(guid)
end

function Update()
    if preview then return end
    local count = 0
    for _, c in ipairs(members) do
        if UnitExists(c.unit) then
            FillLine(c)
            count = count + 1
        elseif not healer then
            c:Hide()
        end
    end
    local extra = StrangerOn()
    if extra then
        FillLine(stranger)
    elseif not healer then
        stranger:Hide()
    end
    Stack(count, extra)
    if not holder:IsShown() and not Locked() then holder:Show() end
    UpdateHints()
end

function ns.ApplyHotLayout()
    if DeckUIForeverOrbsDB.hotTracker and not preview then Update() end
end

-------------------------------------------------------------------
-- Switching, events, preview
-------------------------------------------------------------------
local driver = CreateFrame("Frame")
local elapsed = 0
local function Tick(_, dt)
    elapsed = elapsed + dt
    if elapsed < POLL then return end
    elapsed = 0
    Update()
end

local SPEC_EVENTS = { "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        RefreshUnit(stranger)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        -- party1 may be someone else now
        for _, c in ipairs(members) do RefreshUnit(c) end
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        -- the style switch: the glyphs come or go with Update
    elseif event ~= "PLAYER_REGEN_ENABLED" and event ~= "PLAYER_REGEN_DISABLED" then
        Rebuild()
        UpdateOthersFilter()
    end
    Update()
end)

local function Sample(c, i, icon, fighting)
    local s = SlotFrame(c, i)
    s.icon:SetTexture(icon)
    s.entry = nil   -- the next real fill assigns the slot again
    SetStatic(s, fighting, true)
end

local function ShowPreview(on)
    preview = on
    if not on then
        if DeckUIForeverOrbsDB.hotTracker then Update() elseif not Locked() then holder:Hide() end
        return
    end
    -- the healer mode's lines are the game's to show and hide: the live
    -- window stays as it is, the overlay lies over it
    if healer then
        if not InCombatLockdown() then holder:Show() end
        return
    end
    for _, c in ipairs(lines) do c:Hide() end
    -- the sample lines only when asked for (hotPreview, off; owner 2026-11-06:
    -- "take the preview out, as an option"): without them the window is
    -- an empty box the height of three lines, enough to drag by its overlay
    if not DeckUIForeverOrbsDB.hotPreview then
        holder:SetSize(LineWidth(2), 3 * (Size() + GAP) - GAP)
        holder:Show()
        return
    end
    local you, mate = members[1], members[2]
    you.title:SetText("You")
    you.title:Show()
    local samples = { 136081, 135953, 136085 }   -- Rejuvenation, Renew, Regrowth
    for i, icon in ipairs(samples) do Sample(you, i, icon, i == 3) end
    Finish(you, #samples)
    you:Show()
    mate.title:SetText("Party member")
    mate.title:Show()
    Sample(mate, 1, 136081, false)
    Finish(mate, 1)
    mate:Show()
    Stack(2, false)
    holder:Show()
end

function ns.SetHotTracker(on)
    DeckUIForeverOrbsDB.hotTracker = on and true or false
    if on then
        for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD",
                             "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "INPUT_DEVICE_INTERFACE_TRANSITION",
                             unpack(SPEC_EVENTS) }) do
            if not C_EventUtils or C_EventUtils.IsEventValid(e) then driver:RegisterEvent(e) end
        end
        driver:SetScript("OnUpdate", Tick)
        Rebuild()
        UpdateOthersFilter()
        Update()
    else
        driver:UnregisterAllEvents()
        driver:SetScript("OnUpdate", nil)
        if not preview then ns.OutOfCombat("hotHolder", function() holder:Hide() end) end
        ns.ApplyHotExclusion()   -- the icons come back
    end
end

oUF:Factory(function()
    D.MakeMovable(holder, "HoTs", DeckUIForeverOrbsDB)
    loadedSize = Size()
    healer = DeckUIForeverOrbsDB.hotHealer and true or false
    MakeLines()
    -- the friendly target modifier lights the glyphs the moment it is held
    if GamepadMode and GamepadMode.RegisterTargetModifierStateChanged then
        pcall(GamepadMode.RegisterTargetModifierStateChanged, function()
            if DeckUIForeverOrbsDB.hotTracker then UpdateHints() end
        end, holder)
    end
    ns.SetHotTracker(DeckUIForeverOrbsDB.hotTracker)
    D.OnUnlock(function(state, only)
        if only and not only["HoTs"] then state = false end
        ShowPreview(state and DeckUIForeverOrbsDB.hotTracker and true or false)
    end)
end)

-- /orbs hots: the class, its list, what you know and which IDs each
-- slot takes, and what every line shows
function ns.HotDebug()
    print(("DeckUIForever HoTs: %s, class %s, %d slots, buffs: %s, %s, icon %d px, click to cast %s, in combat: %s%s."):format(
        DeckUIForeverOrbsDB.hotTracker and "on" or "off", tostring(ListKey()), #entries,
        AllBuffs() and "every buff" or "yours up to a minute", Across() and "side by side" or "stacked",
        Size(), healer and "on" or "off", tostring(UnitAffectingCombat("player")),
        Locked() and " (window locked until it ends)" or ""))
    print(("  controller glyphs: option %s, gamepad style %s, party targeting %s, friendly modifier held %s"):format(
        DeckUIForeverOrbsDB.hotPadHints ~= false and "on" or "off", tostring(GamepadStyle()),
        tostring(HintsOn()), tostring(FriendlyModifierDown())))
    for _, e in ipairs(LISTS[ListKey()] or {}) do
        local name = SpellName(e.id)
        local ids = {}
        for _, entry in ipairs(entries) do
            if entry.id == e.id then
                for id in pairs(entry.ids) do ids[#ids + 1] = id end
            end
        end
        table.sort(ids)
        print(("  %d %s: known %s, slot IDs %s"):format(e.id, tostring(name), tostring(Known(e.known or e.id)),
            #ids > 0 and table.concat(ids, " ") or "-"))
    end
    for _, c in ipairs(lines) do
        local slots = 0
        for _, s in ipairs(c.slots) do if s:IsShown() then slots = slots + 1 end end
        print(("  %s: %s, %s, slots %d%s"):format(c.unit,
            UnitExists(c.unit) and (tostring(UnitName(c.unit)) or "?") or "none",
            c:IsShown() and "shown" or "hidden", slots,
            c == stranger and (", friendly " .. tostring(Friendly("target")) .. ", in the table " ..
                tostring(UnitExists("target") and InTable(UnitGUID("target")))) or ""))
    end
end
