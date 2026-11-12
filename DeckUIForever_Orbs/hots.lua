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
-- close"). One line per party member, always listed while you are in a
-- party (solo: you alone), in the game's own group order - in a raid the
-- five of your raid group in raid order, you at your place in it (owner
-- 2026-11-08: "ich bin an erster Stelle, ich will in meiner Gruppenstelle
-- sein"), in a party you first, then party1-4: the name, then one round icon
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
-- highest rank by its spell ID, ns.HotTopRank - and the line's unit token), the name one
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
-- solo, that shows you twice when you target yourself, so the line
-- goes transparent for you or a member, alpha being free in a fight), and
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
--
-- The extensions of 2026-11-10 (owner: "den HoT-Monitor erweitern, aber
-- alles immer als Option"), every one a switch that is off by default:
--   hotHealth    a health capsule under each name (ns.PillBar, a StatusBar fed straight
--                from UnitHealth - the values may be secret in a fight)
--   hotStatus    Dead / Ghost / Offline written over the dimmed icons
--   hotRange     a member out of range is dimmed (UnitInRange into
--                SetAlphaFromBoolean, as oUF's range element)
--   hotDispel    up to two debuffs you can remove, between the name and
--                the heals (an aura group with Blizzard's dispel filter)
--   hotBuffSlots your castable buffs (BUFFS) as slots that show only while
--                the buff is missing. Looked up by name, anyone's cast
--                counts; a lookup that finds nothing proves nothing (the
--                game may hide the aura), so the unit's whole buff list
--                is read too and only a list in the clear says missing
--                (BuffState, 2026-11-12); else the last answer stands
--   hotCastSlots your direct heals, dispels and resurrection (CASTS) as
--                plain buttons - only with click to cast, there is no
--                aura to show
--   hotCustom    a list of your own, spell names or IDs separated by
--                commas: each gets a slot like a HoT (yours, with the clock)
--   hotPets      a line per pet of the party (pet, partypet1-4); /reload
--   hotRaid      in a raid a line for every raid member instead of your
--                group, a column per raid group, four columns to a band,
--                without the buff icons; /reload
--   hotWarn, hotWarnSound, hotWarnAt   a HoT in its last seconds blinks
--                and may play a sound - read by name, so only where the
--                game hands out the times (in a fight they may be secret:
--                then nothing blinks; to be seen in game)
-- All of it untested in game at the time of writing.
-------------------------------------------------------------------
local ICON, NAME_W, PAD = 22, 64, 4   -- icon size as shipped (hotScale scales it), the name's width, the edges
local SPACING = 2                      -- between the icons
local MAX_OTHER, MAX_ALL = 6, 10       -- buff icons after the heals: yours / every buff
local OTHER_MAX_DURATION = 60
local POLL = 0.25
local GAP = 2                          -- between the lines
local GOLD = { 1, 0.82, 0.3 }
local MISSING = { 0.9, 0.3, 0.3 }
local DISPEL_MAX = 2                   -- debuffs you can remove, per line
local RAID_COLS, COL_GAP, BAND_GAP = 4, 8, 8   -- the raid table: groups per band, the gaps
local FAR = 0.4                        -- a line out of range
local WARN_GAP = 1                     -- seconds between two warning sounds
local WHITE = "Interface\\Buttons\\WHITE8x8"
-- a pet's line is smaller than a member's and steps in under its owner's
-- (owner 2026-11-10: "kleiner und leicht versetzt, nicht so groß wie ein Spieler")
local PET_SCALE = 0.8
local PET_SHIFT = 12
local PET ={ 0.72, 0.78, 0.86 }       -- and wears a pale blue instead of the members' gold
local HEALTH_H = 5                    -- the health capsule under the name
local HEALTH_LIFT = 3                  -- the name moves up by this to make room for it
local HEALTH = { 0.3, 0.82, 0.3 }      -- the FF frames' health green

-- debuffs only you can dispel: Blizzard's own filter name where it has one (as raid.lua)
local DISPEL_FILTER = "HARMFUL|" .. (AuraUtil and AuraUtil.AuraFilters
    and AuraUtil.AuraFilters.RaidPlayerDispellable or "RAID")

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Ask(v) if Secret(v) then return nil end return v end

local function Opt(key) return DeckUIForeverOrbsDB[key] and true or false end

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

-- hotBuffSlots: the buffs you can put on someone else, shown while they
-- are missing. also: the group version, whose aura has a name of its own.
-- Paladins are left out on purpose - one blessing per paladin and member,
-- so five of the six would always read as missing; the list of your own
-- (hotCustom) takes the one you hand out.
local BUFFS = {
    PRIEST = { { id = 1243, also = { 21562 } },    -- Power Word: Fortitude, Prayer of Fortitude
               { id = 14752, also = { 27681 } },   -- Divine Spirit, Prayer of Spirit
               { id = 976, also = { 27683 } } },   -- Shadow Protection, Prayer of Shadow Protection
    DRUID  = { { id = 1126, also = { 21849 } },    -- Mark of the Wild, Gift of the Wild
               { id = 467 } },                     -- Thorns
    MAGE   = { { id = 1459, also = { 23028 } } },  -- Arcane Intellect, Arcane Brilliance
}

-- hotCastSlots: what a click casts on the member and leaves no aura to
-- watch - the direct heals, the dispels, the resurrection. First ranks;
-- the name casts the highest one you know. need says when the button is
-- there at all (owner 2026-11-10: "Debuff-Knöpfe nur wenn man wirklich
-- etwas debuffen kann und Resurrect nur bei Toten"): "cure" while the
-- member carries a debuff you can remove (types: the kinds this spell
-- takes), "dead" while the member is dead. The heals are always there.
local MAGIC, CURSE, DISEASE, POISON = "Magic", "Curse", "Disease", "Poison"
local function Cure(id, ...) return { id = id, need = "cure", types = { ... } } end
local function Res(id) return { id = id, need = "dead" } end
local CASTS = {
    PRIEST  = { { id = 2050 }, { id = 2054 }, { id = 2060 }, { id = 2061 },   -- Lesser Heal, Heal, Greater Heal, Flash Heal
                Cure(527, MAGIC), Cure(528, DISEASE), Cure(552, DISEASE),     -- Dispel Magic, Cure Disease, Abolish Disease
                Res(2006) },                                                  -- Resurrection
    DRUID   = { { id = 5185 },                                                -- Healing Touch
                Cure(2782, CURSE), Cure(8946, POISON), Cure(2893, POISON),    -- Remove Curse, Cure Poison, Abolish Poison
                Res(20484) },                                                 -- Rebirth
    PALADIN = { { id = 635 }, { id = 19750 },                                 -- Holy Light, Flash of Light
                Cure(4987, MAGIC, POISON, DISEASE), Cure(1152, POISON, DISEASE),   -- Cleanse, Purify
                { id = 633, layer = false }, Res(7328) },                     -- Lay on Hands (never a Deck Heal default), Redemption
    SHAMAN  = { { id = 331 }, { id = 8004 }, { id = 1064 },                   -- Healing Wave, Lesser Healing Wave, Chain Heal
                Cure(526, POISON), Cure(2870, DISEASE), Res(2008) },          -- Cure Poison, Cure Disease, Ancestral Spirit
    MAGE    = { Cure(475, CURSE) },                                           -- Remove Lesser Curse
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

-- The spell ID of the highest rank of `name` the character has, or
-- `fallback`. A button that casts by name got a lower rank on Forever
-- (owner 2026-11-11), so the buttons cast this ID instead. Highest: the
-- rank number of the subtext ("Rank 4"), then the level it is learnt at,
-- then the later spellbook entry (the book lists ranks upwards).
function ns.HotTopRank(name, fallback)
    if not (name and C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return fallback end
    local bank = Enum.SpellBookSpellBank.Player
    local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    local best, bestRank, bestLevel
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
            local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
            local id = item and item.name == name and (not spellType or item.itemType == spellType)
                and not item.isPassive and not item.isOffSpec and item.spellID
            if id then
                local sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
                local rank = tonumber(type(sub) == "string" and sub:match("%d+") or nil) or 0
                local level = C_Spell and C_Spell.GetSpellLevelLearned and C_Spell.GetSpellLevelLearned(id) or 0
                if not best or rank > bestRank or (rank == bestRank and level >= bestLevel) then
                    best, bestRank, bestLevel = id, rank, level
                end
            end
        end
    end
    return best or fallback
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

local healer = false   -- click to cast (hotHealer), read once at the factory: the buttons stay for the session
local customUnknown = {}   -- what of hotCustom the game did not know, for /orbs hots

-- the list of your own: names or IDs between commas. A name resolves only
-- for a spell the character has; an ID must be one you know.
local function CustomList(seen)
    wipe(customUnknown)
    local text = DeckUIForeverOrbsDB.hotCustom
    if type(text) ~= "string" then return end
    for token in text:gmatch("[^,;\n]+") do
        token = strtrim(token)
        if token ~= "" then
            local id = tonumber(token)
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id or token)
            if info and info.spellID and info.name and (not id or Known(id)) then
                if not seen[info.name] then
                    seen[info.name] = true
                    local e = { id = info.spellID }
                    local ids = RankIDs(e, info.name)
                    for k in pairs(ids) do allIDs[k] = true end
                    entries[#entries + 1] = { kind = "hot", name = info.name, id = info.spellID, ids = ids,
                                              icon = info.iconID or SpellIcon(info.spellID), custom = true }
                end
            else
                customUnknown[#customUnknown + 1] = token
            end
        end
    end
end

-- The slots of a line, in this order: your HoTs, the list of your own,
-- your buffs while missing, your direct casts. kind says how a slot
-- behaves (hot: the engine's aura button; buff: our icon while the buff
-- is missing; cast: a plain button).
local function Rebuild()
    wipe(entries)
    allIDs = {}
    local seen = {}
    for _, e in ipairs(LISTS[ListKey()] or {}) do
        if Known(e.known or e.id) then
            local n = SpellName(e.id)
            if n and not seen[n] then
                seen[n] = true
                local ids = RankIDs(e, n)
                for id in pairs(ids) do allIDs[id] = true end
                entries[#entries + 1] = { kind = "hot", name = n, icon = SpellIcon(e.id), id = e.id, ids = ids }
            end
        end
    end
    CustomList(seen)
    if Opt("hotBuffSlots") then
        for _, e in ipairs(BUFFS[ListKey()] or {}) do
            local n = Known(e.id) and SpellName(e.id)
            if n and not seen[n] then
                seen[n] = true
                local names = { n }
                for _, other in ipairs(e.also or {}) do
                    local o = SpellName(other)
                    if o then names[#names + 1] = o end
                end
                entries[#entries + 1] = { kind = "buff", name = n, icon = SpellIcon(e.id), id = e.id, names = names }
            end
        end
    end
    if healer and Opt("hotCastSlots") then
        for _, e in ipairs(CASTS[ListKey()] or {}) do
            local n = Known(e.id) and SpellName(e.id)
            if n and not seen[n] then
                seen[n] = true
                entries[#entries + 1] = { kind = "cast", name = n, icon = SpellIcon(e.id), id = e.id,
                                          need = e.need, types = e.types }
            end
        end
    end
    for _, e in ipairs(entries) do e.cast = ns.HotTopRank(e.name, e.id) end
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
local cdDirty = true   -- the slots' cooldown clocks (hotCooldown) want a fresh look: Update takes it
local Update   -- below
local loadedSize   -- the icon size this session loaded: a change back clears the reload flag
local petsOn, raidOn = false, false   -- hotPets / hotRaid, read once at the factory: their lines are made there

-- every raid member instead of your group: the option, and you are in a raid
local function RaidMode() return raidOn and IsInRaid() and true or false end

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

-- the healer mode's driver for the target line: a living friend that is
-- not in the party (solo, targeting yourself shows you twice: the
-- restricted environment cannot compare units)
-- with the raid table every raid member has a line already, so the target
-- line is for someone outside the raid
local function StrangerShown()
    return raidOn and "[@target,help,nodead,noparty,noraid] show; hide"
        or "[@target,help,nodead,noparty] show; hide"
end

-- kind: "member" (player, party1-4), "pet", "raid" (raid1-40) or "stranger"
local function Line(parent, unit, kind)
    local c = CreateFrame("Frame", nil, parent)
    c.unit = unit
    c.kind = kind
    if kind == "pet" then c:SetScale(PET_SCALE) end   -- Stack's Put reckons with it
    -- the health bar (hotHealth), in the FF look since 2026-11-10 (owner:
    -- "den Health Bar etwas anpassen in FFO-Stil"): a thin glossy capsule
    -- under the name, as FFXIV's party list - ffstyle.lua's PillBar, with
    -- the name lifted above it (PlaceTitle). Ours, never protected.
    local hb = ns.PillBar(c, NAME_W, HEALTH_H)
    hb:SetPoint("BOTTOMLEFT", PAD, 1)
    hb:SetFrameLevel(c:GetFrameLevel() + 1)
    hb:SetStatusBarColor(HEALTH[1], HEALTH[2], HEALTH[3])
    hb:Hide()
    -- the look before it, kept as an option (hotHealthBlock, owner the same
    -- day: "so wie es davor aussah als Option"): a flat bar behind the
    -- whole name. Both are made; UpdateHealth shows the one asked for.
    local block = CreateFrame("StatusBar", nil, c)
    block:SetPoint("LEFT", 0, 0)
    block:SetSize(PAD + NAME_W + 2, Size())
    block:SetFrameLevel(c:GetFrameLevel() + 1)
    block:SetStatusBarTexture(WHITE)
    block:SetStatusBarColor(0.2, 0.62, 0.3, 0.6)
    local bg = block:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(block)
    bg:SetColorTexture(0, 0, 0, 0.45)
    block:Hide()
    c.healthBlock = block
    c.health = hb
    -- the name on a layer of its own, above the bar
    local text = CreateFrame("Frame", nil, c)
    text:SetAllPoints(c)
    text:SetFrameLevel(c:GetFrameLevel() + 3)
    c.title = Text(text, 11)
    c.title:SetPoint("LEFT", PAD, 0)
    c.title:SetWidth(NAME_W)
    c.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    -- Dead / Ghost / Offline over the icons (hotStatus): above every slot,
    -- and no mouse, so a click still reaches the button underneath
    local over = CreateFrame("Frame", nil, c)
    over:SetAllPoints(c)
    over:SetFrameLevel(c:GetFrameLevel() + 30)
    c.status = Text(over, 11)
    c.status:SetPoint("LEFT", PAD + NAME_W + 6, 0)
    c.slots = {}
    if healer then
        -- the name targets the member; the game shows and hides the line
        local b = SecureButton(c, "target", unit)
        b:SetPoint("LEFT", 0, 0)
        b:SetSize(PAD + NAME_W + 2, Size())
        c.target = b
        if kind == "stranger" then
            if DeckUIForeverOrbsDB.hotStranger ~= false then RegisterStateDriver(c, "visibility", StrangerShown()) end
        elseif kind == "raid" then
            RegisterStateDriver(c, "visibility", ("[@%s,exists] show; hide"):format(unit))
        else
            -- with the raid table the party's lines step aside in a raid
            RegisterStateDriver(c, "visibility", ("%s[@%s,exists] show; hide"):format(
                raidOn and "[group:raid] hide; " or "", unit))
        end
    else
        c:Hide()
    end
    return c
end

-- you first, then the party in the game's order; the stranger's line last,
-- so the table does not shift when a target comes and goes
local PARTY = { "player", "party1", "party2", "party3", "party4" }
local PETS = { "pet", "partypet1", "partypet2", "partypet3", "partypet4" }
local members, pets, raid, stranger, lines = {}, {}, {}, nil, {}
local byUnit = {}

local function MakeLines()
    for i, unit in ipairs(PARTY) do members[i] = Line(holder, unit, "member") end
    if petsOn then
        for i, unit in ipairs(PETS) do pets[i] = Line(holder, unit, "pet") end
    end
    if raidOn then
        for i = 1, (MAX_RAID_MEMBERS or 40) do raid[i] = Line(holder, "raid" .. i, "raid") end
    end
    stranger = Line(holder, "target", "stranger")
    for _, list in ipairs({ members, pets, raid }) do
        for _, c in ipairs(list) do lines[#lines + 1] = c end
    end
    lines[#lines + 1] = stranger
    for _, c in ipairs(lines) do byUnit[c.unit] = c end
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
    c.title:SetPoint("LEFT", PAD + shift, c.lifted and HEALTH_LIFT or 0)
    c.title:SetWidth(math.max(10, NAME_W - shift))
    -- the health bars start after the glyph too (owner's Deck test
    -- 2026-11-12: the key's picture lay on the bar); ours, never protected
    c.health:ClearAllPoints()
    c.health:SetPoint("BOTTOMLEFT", PAD + shift, 1)
    c.health:SetWidth(math.max(10, NAME_W - shift))
    c.healthBlock:ClearAllPoints()
    c.healthBlock:SetPoint("LEFT", shift > 0 and (PAD + shift - 2) or 0, 0)
    c.healthBlock:SetWidth(shift > 0 and math.max(10, NAME_W - shift + 4) or (PAD + NAME_W + 2))
end

-- alpha only: a glyph is made once and never shown or hidden, so the
-- protected lines of the healer mode are never touched in a fight
local function UpdateHints()
    local on = HintsOn()
    local lit = on and (FriendlyModifierDown() or (ns.PadHealActive and ns.PadHealActive()))
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
    local kind = not force and s.entry and s.entry.kind or "hot"
    if kind == "cast" then
        -- a button, nothing to watch: in colour. A heal is always there;
        -- a cure's icon rides on the engine's button (CureFrame) and a
        -- resurrection's on the secure button (Assign), so ours stays away
        local on = not s.entry.need
        s.icon:SetShown(on)
        s.rim:SetShown(on)
        s.icon:SetDesaturated(false)
        s.icon:SetAlpha(0.9)
        s.rim:SetVertexColor(0.2, 0.2, 0.2, 1)
        return
    elseif kind == "buff" then
        -- only while the buff is missing: then in colour with a red rim
        local on = s.missing and true or false
        s.icon:SetShown(on)
        s.rim:SetShown(on)
        s.icon:SetDesaturated(false)
        s.icon:SetAlpha(0.85)
        s.rim:SetVertexColor(MISSING[1], MISSING[2], MISSING[3], 1)
        return
    end
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
    s.unit = c.unit
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
            GameTooltip:SetSpellByID(s.entry.cast or s.entry.id)
            GameTooltip:Show()
        end)
        cast:SetScript("OnLeave", GameTooltip_Hide)
        s.cast = cast
    end
    -- the expiry warning (hotWarn): a red glow of ours that pulses over
    -- the icon, above everything of the slot and deaf to the mouse
    local warn = CreateFrame("Frame", nil, s)
    warn:SetAllPoints(s)
    warn:SetFrameLevel(s:GetFrameLevel() + 14)
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
    c.slots[i] = s
    return s
end

local function SetWarn(s, on)
    on = on and true or false
    if (s.warning or false) == on then return end
    s.warning = on
    s.warn:SetShown(on)
    if on then s.pulse:Play() else s.pulse:Stop() end
end

-- A cure's slot (need "cure"): a one-slot container on the debuffs you can
-- remove. The engine shows its button only while there is one - in a fight
-- too, where no call of ours may read a debuff - and our spell icon rides
-- on that button. The engine's own icon (the debuff's) is handed over
-- unseen. The secure button above stays: a click on the empty place still
-- casts, the game then says there is nothing to remove.
local function CureFrame(s)
    if s.cure then return s.cure end
    local auras = CreateFrame("AuraContainer", nil, s, "CustomAuraContainerTemplate")
    auras:SetAllPoints(s)
    auras:SetUnit(s.unit)
    auras:AddAuraSlot("cure", DISPEL_FILTER, {
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

-- a resurrection's slot (need "dead"): the secure button itself comes and
-- goes with the member's death (a state driver, so in a fight too) and
-- carries the icon. Out of combat only.
local function DeadOnly(s, e)
    local dead = e.need == "dead"
    if dead and not s.castIcon then
        s.castRim = ns.IconRim(s.cast, 0.2, 0.2, 0.2, 1)
        s.castIcon = ns.RoundIcon(s.cast:CreateTexture(nil, "ARTWORK"))
        s.castIcon:SetAllPoints(s.cast)
        s.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if s.castIcon then
        s.castIcon:SetTexture(e.icon or 134400)
        s.castIcon:SetShown(dead)
        s.castRim:SetShown(dead)
    end
    if dead == (s.deadOnly or false) then return end
    s.deadOnly = dead
    if dead then
        RegisterStateDriver(s.cast, "visibility", "[@" .. s.unit .. ",dead] show; hide")
    else
        UnregisterStateDriver(s.cast, "visibility")
        s.cast:Show()
    end
end

-- the slot's spell: the ID of the highest rank (e.cast, ns.HotTopRank),
-- the name where there is none; in a fight the attribute waits
-- (pendingSpell), FillLine assigns again after it
local function Assign(s, e)
    -- a list read again (Rebuild makes new entries) keeps the buff's last
    -- answer: in a fight it may be the only one there is
    local old = s.entry
    if not (old and old.kind == "buff" and e.kind == "buff" and old.name == e.name) then s.missing = nil end
    s.entry = e
    cdDirty = true
    SetWarn(s, false)
    s.icon:SetTexture(e.icon or 134400)
    if e.need == "cure" then
        local cure = CureFrame(s)
        cure:SetAlpha(1)
        cure:Show()
        if s.cureIcon then pcall(s.cureIcon.SetTexture, s.cureIcon, e.icon or 134400) end
        pcall(cure.UpdateAllAuras, cure)
    elseif s.cure then
        s.cure:Hide()
    end
    -- only a HoT's slot shows the engine's aura button (the container is
    -- ours and not protected, so this may happen in a fight)
    s.auras:SetShown(e.kind == "hot")
    if e.kind == "hot" then
        pcall(s.auras.SetAuraSlotCandidateFilters, s.auras, "hot", { includeSpellIDs = e.ids or {} })
        pcall(s.auras.UpdateAllAuras, s.auras)
    end
    if s.cast then
        if InCombatLockdown() then
            s.pendingSpell = e.cast or e.name
        else
            s.cast:SetAttribute("spell", e.cast or e.name)
            DeadOnly(s, e)
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

-- the debuffs on the member that you can remove (hotDispel), between the
-- name and the heals: the engine's icons again, with a red rim
local function DispelOn() return Opt("hotDispel") end
local function DispelWidth() return DispelOn() and (DISPEL_MAX * Slot() + 2) or 0 end

local function Dispels(c)
    if c.dispels then return c.dispels end
    local size = Size()
    local auras = CreateFrame("AuraContainer", nil, c, "CustomAuraContainerTemplate")
    auras:SetSize(DISPEL_MAX * Slot(), size)
    auras:SetUnit(c.unit)
    auras:SetFlowLayoutAnchorPoint("LEFT")
    auras:SetFlowLayoutAxis(ns.FLOW.Horizontal)
    auras:SetFlowLayoutMaximumLineSize(DISPEL_MAX * Slot())
    auras:SetFlowLayoutGrowthDirection(1, -1)
    auras:AddAuraGroup("dispel", DISPEL_FILTER, {
        maxFrameCount = DISPEL_MAX,
        candidateFilters = { excludeSpellIDs = {} },
        layout = { elementSpacing = SPACING },
        initializeFrame = function(button)
            button:SetSize(size, size)
            ns.IconRim(button, 0.95, 0.2, 0.2, 1)
            ns.AuraIconButton(button, size)
        end,
    })
    c.dispels = auras
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
            for _, s in ipairs(c.slots) do
                s:SetSize(size, size)
                s.cdKind = nil   -- the cooldown clock is laid out for the new size
            end
            cdDirty = true
            if c.target then c.target:SetHeight(size) end
            c.healthBlock:SetHeight(size)
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
    for _, s in ipairs(c.slots) do
        s.missing = nil   -- someone else stands behind the token: the buffs are looked up afresh
        pcall(s.auras.UpdateAllAuras, s.auras)
        if s.cure then pcall(s.cure.UpdateAllAuras, s.cure) end
    end
    if c.others then pcall(c.others.UpdateAllAuras, c.others) end
    if c.dispels then pcall(c.dispels.UpdateAllAuras, c.dispels) end
end

-- the line's width: name, the debuffs to remove, a slot per heal, the buff
-- icons (the raid table goes without those: forty lines want to be narrow)
local function LineWidth(slots)
    return PAD + NAME_W + 4 + DispelWidth() + slots * Slot() + (RaidMode() and 0 or OthersMax() * Slot()) + PAD
end

-- lays the slots out after the name, the buffs after them, and sizes the line
local function Finish(c, shown)
    if Locked() then return end
    local size, slot = Size(), Slot()
    local x = PAD + NAME_W + 4
    -- A pet's line is scaled down and stepped in (PET_SCALE, PET_SHIFT),
    -- but its icons stay in the members' columns (owner 2026-11-10: "die
    -- Zauber der Pets bitte wieder einordnen"): At turns a member's offset
    -- into the pet line's own, so that a piece `width` wide sits centred
    -- where a member's does (width 0: left edges meet).
    local k = c.kind == "pet" and PET_SCALE or 1
    local shift = (c.kind == "pet" and not Across()) and PET_SHIFT or 0
    local function At(at, width)
        return (at + width / 2 - shift) / k - width / 2
    end
    if DispelOn() then
        local dispels = Dispels(c)
        dispels:ClearAllPoints()
        dispels:SetPoint("LEFT", c, "LEFT", At(x, 0), 0)
        if not dispels:IsShown() then
            dispels:Show()
            pcall(dispels.UpdateAllAuras, dispels)
        end
        x = x + DispelWidth()
    elseif c.dispels then
        c.dispels:Hide()
    end
    for i, s in ipairs(c.slots) do
        if i <= shown then
            s:ClearAllPoints()
            s:SetPoint("LEFT", c, "LEFT", At(x, size), 0)
            if not s:IsShown() then
                s:Show()
                -- a slot that comes back reads its unit afresh
                pcall(s.auras.UpdateAllAuras, s.auras)
                if s.cure then pcall(s.cure.UpdateAllAuras, s.cure) end
            end
            x = x + slot
        else
            s:Hide()
        end
    end
    if RaidMode() then
        if c.others then c.others:Hide() end
    else
        local others = Others(c)
        others:ClearAllPoints()
        others:SetPoint("LEFT", c, "LEFT", At(x, 0), 0)
        if not others:IsShown() then
            others:Show()
            pcall(others.UpdateAllAuras, others)
        end
    end
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

-- the health bar behind the name: the numbers go to the bar as they come,
-- secret or not
local function UpdateHealth(c)
    local on = Opt("hotHealth")
    local block = Opt("hotHealthBlock")
    local hb, other = c.health, c.healthBlock
    if block then hb, other = other, hb end
    other:Hide()
    local lift = on and not block
    if lift ~= (c.lifted or false) then
        -- the name sits above the capsule, and back in the middle without it
        c.lifted = lift
        PlaceTitle(c, c.titleShifted)
    end
    if not on or not UnitExists(c.unit) then
        hb:Hide()
        return
    end
    hb:SetMinMaxValues(0, UnitHealthMax(c.unit))
    hb:SetValue(UnitHealth(c.unit))
    hb:Show()
end

-- Dead / Ghost / Offline, nil while all is well (or the game will not say)
local function Status(c)
    if c.kind == "stranger" or not Opt("hotStatus") then return nil end
    local unit = c.unit
    if c.kind ~= "pet" and Ask(UnitIsConnected(unit)) == false then
        return PLAYER_OFFLINE or "Offline", 0.6, 0.6, 0.6
    end
    if Ask(UnitIsGhost(unit)) == true then return "Ghost", 0.6, 0.6, 0.6 end
    if Ask(UnitIsDead(unit)) == true then return DEAD or "Dead", 0.9, 0.3, 0.3 end
    return nil
end

-- out of range the line is dimmed (hotRange). The answer may be secret:
-- the engine takes it as it is. You yourself stay lit, and the target
-- line's alpha belongs to Update. The pets are dimmed too (owner
-- 2026-11-10: "Reichweite für Begleiter"); where the game says it did not
-- measure (checked false, readable), the line stays lit.
local function UpdateRange(c)
    if c.kind == "stranger" then return end
    if not Opt("hotRange") or c.unit == "player" then
        if c.ranged then
            c.ranged = nil
            c:SetAlpha(1)
        end
        return
    end
    c.ranged = true
    local ok, inRange, checked = pcall(UnitInRange, c.unit)
    if not ok or (not Secret(checked) and not checked) then
        c:SetAlpha(1)
    elseif c.SetAlphaFromBoolean then
        c:SetAlphaFromBoolean(inRange, 1, FAR)
    elseif Secret(inRange) or Secret(checked) then
        c:SetAlpha(1)
    else
        c:SetAlpha((checked and not inRange) and FAR or 1)
    end
end

-- Is the buff of this slot on the unit? "there", "missing", or nil when
-- the game will not say. Anyone's cast counts.
--
-- Until 1.5.0 the lookup by name alone decided, and out of a fight
-- "nothing found" counted as missing. But the lookup also finds nothing
-- for an aura the game keeps secret (GetAuraDataBySpellName:
-- RequiresNonSecretAura) - so a buff that was there read as missing, and
-- in a fight the answer of before the fight stood, right or wrong (owner
-- 2026-11-12: "erkennt nicht richtig ob Buffs auf den Spielern sind", both
-- ways, always). Now nothing found is checked against the unit's whole
-- buff list: an entry whose name is kept from us could be the buff, so
-- the answer is "don't know"; only a list read to its end, every name in
-- the clear and none of them ours, says missing - in a fight too, where
-- that list must also hold at least one buff (an empty answer there may
-- be the game's silence).
-- the second and third value are for /orbs hots: how many buffs were read
-- in the clear and how many were kept from us
local function BuffState(unit, e)
    for _, name in ipairs(e.names) do
        local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, "HELPFUL")
        if ok and data ~= nil and not Secret(data) then return "there", 0, 0 end
    end
    if not C_UnitAuras.GetAuraDataByIndex then return nil, 0, 0 end
    local read, hidden = 0, 0
    for i = 1, 40 do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok then return nil, read, hidden end
        if data == nil then break end
        local name = not Secret(data) and data.name
        if Secret(data) or Secret(name) or name == nil then
            hidden = hidden + 1
        else
            read = read + 1
            for _, n in ipairs(e.names) do
                if n == name then return "there", read, hidden end
            end
        end
    end
    if hidden > 0 then return nil, read, hidden end
    if read == 0 and InCombatLockdown() then return nil, read, hidden end
    return "missing", read, hidden
end

-- Is the buff of this slot missing on the unit? While the game will not
-- say (BuffState nil), the last answer for this same person stands; for
-- someone new behind the token there is none, and no icon. Never for the
-- dead, the far away, or an NPC you target.
local function BuffMissing(c, e, last)
    local unit = c.unit
    if Ask(UnitIsDeadOrGhost(unit)) == true then return false end
    if Ask(UnitIsVisible(unit)) == false then return false end
    if c.kind == "stranger" and Ask(UnitIsPlayer(unit)) ~= true then return false end
    -- never on a pet's line: in Forever a pet is no target for these buffs
    -- (owner 2026-11-10: "Buff wird beim Pet angezeigt, obwohl es invalid
    -- target ist"). C_Spell.IsSpellInRange was tried first to tell - nil
    -- for a spell that cannot go on the unit - and still let the icon
    -- through in the owner's test, so the pets are left out as a whole.
    if c.kind == "pet" then return false end
    local state = BuffState(unit, e)
    if state == "there" then return false end
    if state == "missing" then return true end
    return last or false
end

-- the seconds your HoT has left on the unit, nil when it is not there or
-- the game keeps the time to itself
local function Remaining(unit, e)
    local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, e.name, "HELPFUL|PLAYER")
    if not ok or Secret(data) or data == nil then return nil end
    local expires, duration = Ask(data.expirationTime), Ask(data.duration)
    if not expires or not duration or duration <= 0 then return nil end
    return expires - GetTime()
end

local lastSound = 0
local function Warn(c, s, e)
    if e.kind ~= "hot" or not (Opt("hotWarn") or Opt("hotWarnSound")) then
        SetWarn(s, false)
        s.warned = nil
        return
    end
    local left = Remaining(c.unit, e)
    local late = left ~= nil and left > 0 and left <= (tonumber(DeckUIForeverOrbsDB.hotWarnAt) or 3)
    SetWarn(s, late and Opt("hotWarn"))
    if late and not s.warned and Opt("hotWarnSound") and GetTime() - lastSound >= WARN_GAP then
        lastSound = GetTime()
        PlaySound(SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889, "Master")
    end
    s.warned = late or nil
end

-- The kinds of debuff on the unit (Magic, Curse, ...), false when the game
-- will not say. Out of a fight the list is the truth; in one a debuff may
-- be kept from us, and nothing found would not mean nothing there.
local function DebuffTypes(unit)
    if InCombatLockdown() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
    local found = {}
    for i = 1, 40 do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
        if not ok or Secret(data) then return false end
        if data == nil then break end
        local kind = data.dispelName
        if Secret(kind) then return false end
        if kind then found[kind] = true end
    end
    return found
end

-- fills a line with the list for its unit
local function FillLine(c)
    local fighting = Fighting()
    local status, r, g, b = Status(c)
    local types   -- the unit's debuff kinds, read once per line and only when a cure asks
    for i, e in ipairs(entries) do
        local s = SlotFrame(c, i)
        if not s then break end
        if s.entry ~= e or s.pendingSpell then Assign(s, e) end
        if e.kind == "buff" then
            -- the last answer is one person's: someone else behind the
            -- token (or a GUID kept from us) starts without one
            local guid = Ask(UnitGUID(c.unit))
            if guid ~= s.missingFor then s.missing = nil end
            s.missingFor = guid
            s.missing = BuffMissing(c, e, s.missing)
        end
        if e.need == "cure" and s.cure then
            -- the engine shows the button for any debuff you can remove;
            -- where the kinds can be read, a spell for another kind steps back
            if types == nil then types = DebuffTypes(c.unit) end
            local fits = not types
            if types then
                for _, kind in ipairs(e.types or {}) do
                    if types[kind] then fits = true break end
                end
            end
            s.cure:SetAlpha(fits and 1 or 0)
        end
        SetStatic(s, fighting)
        Warn(c, s, e)
    end
    -- alpha is free in a fight, so a dead member's icons step back at once
    -- (not the resurrection: that is the one to press)
    for _, s in ipairs(c.slots) do
        local res = s.entry and s.entry.need == "dead"
        s:SetAlpha((status and not res) and 0.25 or 1)
    end
    c.status:SetText(status or "")
    if status then c.status:SetTextColor(r, g, b) end
    c.title:SetText(c.unit == "player" and "You" or UnitName(c.unit))
    if status then
        c.title:SetTextColor(0.6, 0.6, 0.6)
    elseif c.kind == "pet" then
        c.title:SetTextColor(PET[1], PET[2], PET[3])
    else
        c.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    end
    c.title:Show()
    UpdateHealth(c)
    UpdateRange(c)
    Finish(c, #entries)
    if not healer then c:Show() end
end

-- Which row each member takes: the order of the game's own group frames.
-- In a raid the five of your raid group stand in raid order - the
-- GetRaidRosterInfo order the raid frames (CompactRaidGroup_UpdateUnits)
-- and the raid window use - so you sit at your place in the group, not
-- always on top (owner 2026-11-08: "ich bin an erster Stelle, ich will in
-- meiner Gruppenstelle sein"); UnitInRaid gives each token's raid index.
-- In a party you first, then party1-4, as Blizzard's compact party frames
-- sort them (CRFSort_Group). The present members fill rows 0 to count-1;
-- the ones that are gone line up behind them, from row `count` on - the
-- stranger's row (in the healer mode a member who joins mid-fight lands
-- there too, until the fight ends). UnitInRaid may hand back a secret in
-- a fight: then the last order stands.
--
-- Before that order comes the role (owner 2026-11-12: "die Reihenfolge
-- soll immer Tank, Healer, DD sein"): tanks, then healers, then everyone
-- else, the group order within a role. The role is the group's own
-- (UnitGroupRolesAssigned: the dungeon finder's, or what the leader set);
-- a member without one counts as damage, so a group without roles keeps
-- the plain group order. A secret role leaves the last order standing.
local ROLE_RANK = { TANK = 1, HEALER = 2 }
local function RoleRank(unit)
    if not UnitGroupRolesAssigned then return 3 end
    local role = UnitGroupRolesAssigned(unit)
    if Secret(role) then return nil end
    return ROLE_RANK[role] or 3
end

local lastRows = {}
local function Rows()
    local present, gone, raid = {}, {}, IsInRaid()
    for i, c in ipairs(members) do
        if UnitExists(c.unit) then
            local key = i
            if raid then
                local id = UnitInRaid(c.unit)
                if Secret(id) then return lastRows end
                key = id or (40 + i)
            end
            local rank = RoleRank(c.unit)
            if not rank then return lastRows end
            key = rank * 100 + key
            present[#present + 1] = { c = c, key = key }
        else
            gone[#gone + 1] = c
        end
    end
    table.sort(present, function(a, b) return a.key < b.key end)
    local rows = {}
    for row, p in ipairs(present) do rows[p.c] = row - 1 end
    for j, c in ipairs(gone) do rows[c] = #present + j - 1 end
    lastRows = rows
    return rows
end

-- Every line to its row (Rows; the stranger takes row `count`), under one
-- another or side by side (hotAcross, per device); the holder is sized to
-- the rows in use.
--
-- The pets (hotPets) stand right under their owner (owner 2026-11-10:
-- "klar zum Hunter oder Hexer zuordnen"), smaller, stepped in and pale blue.
-- The raid table (hotRaid, in a raid): a column per raid group in use,
-- its members under one another in raid order, four columns to a band,
-- the target line under the last band. A secret raid roster in a fight
-- leaves the table as it stands.
local function Stack(count, extra)
    if Locked() then return end
    local across, size, w = Across(), Size(), LineWidth(#entries)
    local step = size + GAP
    if RaidMode() then
        local groups, order = {}, {}
        for i, c in ipairs(raid) do
            if UnitExists(c.unit) then
                local _, _, g = GetRaidRosterInfo(i)
                if Secret(g) then return end
                g = g or 1
                if not groups[g] then
                    groups[g] = {}
                    order[#order + 1] = g
                end
                -- tank, healer, damage within the group, raid order within a role
                local rank = RoleRank(c.unit)
                if not rank then return end
                c.sortKey = rank * 100 + i
                table.insert(groups[g], c)
            end
        end
        for _, list in pairs(groups) do
            table.sort(list, function(a, b) return a.sortKey < b.sortKey end)
        end
        table.sort(order)
        local bandH = 5 * step + BAND_GAP
        for k, g in ipairs(order) do
            local col, band = (k - 1) % RAID_COLS, math.floor((k - 1) / RAID_COLS)
            for pos, c in ipairs(groups[g]) do
                c.row = (k - 1) * 5 + pos - 1
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", holder, "TOPLEFT", col * (w + COL_GAP), -(band * bandH + (pos - 1) * step))
            end
        end
        local bands = math.max(1, math.ceil(#order / RAID_COLS))
        local cols = math.max(1, math.min(#order, RAID_COLS))
        stranger.row = count
        stranger:ClearAllPoints()
        stranger:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -bands * bandH)
        holder:SetSize(cols * (w + COL_GAP) - COL_GAP, bands * bandH - BAND_GAP + (extra and (step + BAND_GAP) or 0))
        return
    end
    -- at: where the line starts, in the holder's pixels; hands back where
    -- the next one starts. A pet's line is scaled down (PET_SCALE, set in
    -- Line), so it takes less room, its offsets are divided by the scale
    -- (a frame's offsets are in its own scale), and under one another it
    -- steps in by PET_SHIFT.
    local function Put(c, row, at)
        local pet = c.kind == "pet"
        local scale = pet and PET_SCALE or 1
        c.row = row
        c:ClearAllPoints()
        if across then
            c:SetPoint("TOPLEFT", holder, "TOPLEFT", at / scale, 0)
            return at + (w + GAP) * scale
        end
        c:SetPoint("TOPLEFT", holder, "TOPLEFT", (pet and PET_SHIFT or 0) / scale, -at / scale)
        return at + step * scale
    end
    -- the members in their order, each one's pet in the row right after
    -- its owner (pets[i] is members[i]'s: pet and player, partypetN and
    -- partyN); a member or pet that is gone waits behind everyone present
    local rows = Rows()
    local order = {}
    for i, c in ipairs(members) do order[i] = { c = c, pet = pets[i], row = rows[c] or (i - 1), i = i } end
    table.sort(order, function(a, b)
        if a.row ~= b.row then return a.row < b.row end
        return a.i < b.i
    end)
    local row, at, waiting = 0, 0, {}
    for _, o in ipairs(order) do
        if UnitExists(o.c.unit) then
            at = Put(o.c, row, at)
            row = row + 1
        else
            waiting[#waiting + 1] = o.c
        end
        if o.pet then
            if UnitExists(o.pet.unit) then
                at = Put(o.pet, row, at)
                row = row + 1
            else
                Put(o.pet, count, at)
            end
        end
    end
    local behind = at
    for j, c in ipairs(waiting) do behind = Put(c, count + j - 1, behind) end
    local used = Put(stranger, count, at)
    if not extra then used = at end
    if across then
        holder:SetSize(math.max(used - GAP, w), size)
    else
        holder:SetSize(w, math.max(used - GAP, size))
    end
end

-- a unit's GUID, or nil while the game keeps it secret (debuffs.lua saw
-- an enemy target's GUID secret in a fight on 2026-11-08; a secret as a
-- key or in a comparison throws)
local function GUID(unit)
    if not UnitExists(unit) then return nil end
    return Ask(UnitGUID(unit))
end

-- the target stands in the table already (you or a party member): the
-- GUIDs say so, where UnitIsUnit may hand back a secret in a fight
local function InTable(guid)
    if RaidMode() then
        -- every raid member has a line: the game says whether the target is one
        local id = UnitInRaid("target")
        return not Secret(id) and id ~= nil
    end
    for _, unit in ipairs(PARTY) do
        if GUID(unit) == guid then return true end
    end
    for _, c in ipairs(pets) do
        if GUID(c.unit) == guid then return true end
    end
    return false
end

-- a friendly target outside the party gets the last line while it lasts
-- (hotStranger, on; owner 2026-11-08, with an NPC targeted far away:
-- "always a sixth one in the group" - off, the window is the group alone);
-- a target whose GUID is secret cannot be told from the party and gets none
local function StrangerWanted() return DeckUIForeverOrbsDB.hotStranger ~= false end

local function StrangerOn()
    if not StrangerWanted() or not Friendly("target") then return false end
    local guid = GUID("target")
    return guid ~= nil and not InTable(guid)
end

-- the target is you or a party member, known for sure (a secret GUID is
-- not a member: the healer mode's line stays visible for it)
local function TargetInTable()
    local guid = GUID("target")
    return guid ~= nil and InTable(guid)
end

-------------------------------------------------------------------
-- The spells' cooldowns (hotCooldown)
-------------------------------------------------------------------
-- A clock of ours on a slot while its spell is on cooldown (owner
-- 2026-11-10: "bei Spells ein CD-Timer einbauen, wenn gebraucht") - Power
-- Word: Shield's four seconds, Lay on Hands, Rebirth. Not the global
-- cooldown. The way LibActionButton's retail path does it: the info table
-- says whether a cooldown runs (isActive, isOnGCD), the duration object
-- goes to the Cooldown frame unread, so a secret time is no matter.
-- A heal's button gets the dark sweep with the time in the middle. A
-- HoT's slot has the aura's clock there already, so its cooldown is a
-- small number on the icon's top edge without a sweep. A resurrection's
-- clock rides on its button and is gone with it; cures and the missing
-- buffs get none. The same answer serves every line, asked once per spell.
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

local function StyleCooldown(s, e)
    local cd = SlotCooldown(s)
    local kind = e.need or e.kind
    if s.cdKind == kind then return cd end
    s.cdKind = kind
    local size = Size()
    local parent = (e.need == "dead" and s.cast) or s
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

-- what to hand the clock for this spell: a duration object, or a table
-- { start, duration } where the client has no duration objects, or false
local function EntryCooldown(e)
    if not (C_Spell and C_Spell.GetSpellCooldown) then return false end
    local ok, info = pcall(C_Spell.GetSpellCooldown, e.name)
    if not ok or Secret(info) or type(info) ~= "table" then return false end
    local gcd = info.isOnGCD
    if not Secret(gcd) and gcd then return false end
    local active = info.isActive
    if not Secret(active) then
        if active == false then return false end
        if active == nil then
            -- a client without the flag: the plain numbers decide
            local d = info.duration
            if Secret(d) or not d or d <= 1.5 then return false end
        end
    end
    if C_Spell.GetSpellCooldownDuration then
        local ok2, object = pcall(C_Spell.GetSpellCooldownDuration, e.name)
        return ok2 and object or false
    end
    local start, d = info.startTime, info.duration
    if Secret(start) or Secret(d) or not start or not d or d <= 0 then return false end
    return { start, d }
end

local function ApplyCooldowns()
    cdDirty = false
    local on = Opt("hotCooldown")
    local asked = {}
    for _, c in ipairs(lines) do
        for _, s in ipairs(c.slots) do
            local e = s.entry
            if not on or not e or e.kind == "buff" or e.need == "cure" then
                if s.cd then s.cd:Clear() end
            else
                local answer = asked[e]
                if answer == nil then
                    answer = EntryCooldown(e)
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

local cooldownWatch = CreateFrame("Frame")
cooldownWatch:RegisterEvent("SPELL_UPDATE_COOLDOWN")
cooldownWatch:SetScript("OnEvent", function() cdDirty = true end)

-------------------------------------------------------------------
-- Your mana regeneration (hotRegen)
-------------------------------------------------------------------
-- A small line above the window (owner 2026-11-10: "meine aktuelle
-- Manareg ... als Option im HoTs-Fenster"): what you regenerate right now
-- per five seconds, and beside it the other of the two rates
-- GetManaRegen hands out - the full one, and the one that holds for five
-- seconds after a spell that cost mana (Classic's five-second rule). The
-- text hangs on the holder and is no row of it, so Stack knows nothing of
-- it. Which rate holds is our own clock: the last cast of yours that cost
-- mana (UNIT_SPELLCAST_SUCCEEDED and the spell's cost). A secret rate in a
-- fight leaves the last text standing.
local FSR = 5
local MANA_TYPE = Enum.PowerType and Enum.PowerType.Mana or 0
local lastSpend = 0
local regenBox = CreateFrame("Frame", nil, holder)
regenBox:SetSize(1, 1)
regenBox:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, 0)
local regenText = Text(regenBox, 10)
regenText:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", PAD, 3)
regenText:Hide()

-- What starts the five seconds (owner 2026-11-10, in a fight: "die
-- aktuellen MPS werden auch 5 sec nach Cast nicht berechnet" - the line
-- stood at "in 5 s": every cast counted, a wand's shot too, because a
-- spell's cost is kept from us in a fight and unknown counted as yes).
-- Now, in this order:
--   1. your mana itself, where it can be read: a drop is a spend
--      (UNIT_POWER_UPDATE), and the casts are not asked at all;
--   2. else the cast, by what its cost was the last time it could be read
--      (costKnown, learned out of a fight); the auto-repeat ones never;
--   3. a spell never seen out of a fight, or a secret spell ID: no spend -
--      rather the full rate shown a little early than the clock stuck.
local costKnown = {}
local NO_SPEND = { [5019] = true, [75] = true, [6603] = true }   -- Shoot (wand), Auto Shot, Attack
local lastMana, manaReadable = nil, false
local regenSeen = "nothing yet"   -- for /orbs hots

-- true / false, or nil while the game will not say
local function CostsMana(spellID)
    if not (C_Spell and C_Spell.GetSpellPowerCost) then return nil end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or Secret(costs) or type(costs) ~= "table" then return nil end
    for _, cost in ipairs(costs) do
        local kind, amount = cost.type, cost.cost
        if Secret(kind) or Secret(amount) then return nil end
        if kind == MANA_TYPE and (amount or 0) > 0 then return true end
    end
    return false
end

local function SpendsMana(spellID)
    if Secret(spellID) or not spellID then
        regenSeen = "a cast with a secret ID"
        return false
    end
    if NO_SPEND[spellID] then return false end
    local costs = CostsMana(spellID)
    if costs ~= nil then
        costKnown[spellID] = costs
    else
        costs = costKnown[spellID]
    end
    regenSeen = ("cast %d, cost %s"):format(spellID, costs == nil and "unknown" or costs and "mana" or "none")
    return costs == true
end

local regenWatch = CreateFrame("Frame")
regenWatch:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
regenWatch:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
regenWatch:SetScript("OnEvent", function(_, event, _, _, spellID)
    if not (DeckUIForeverOrbsDB and DeckUIForeverOrbsDB.hotRegen) then return end
    local mana = UnitPower("player", MANA_TYPE)
    manaReadable = not Secret(mana) and mana ~= nil
    if event == "UNIT_POWER_UPDATE" then
        if manaReadable then
            if lastMana and mana < lastMana then
                lastSpend = GetTime()
                regenSeen = "mana dropped"
            end
            lastMana = mana
        else
            lastMana = nil
        end
    elseif not manaReadable and SpendsMana(spellID) then
        lastSpend = GetTime()
    elseif manaReadable then
        -- learn the cost for the fights where the mana is kept from us
        if not Secret(spellID) and spellID then
            local costs = CostsMana(spellID)
            if costs ~= nil then costKnown[spellID] = costs end
        end
    end
end)

local function UpdateRegen()
    if not Opt("hotRegen") or not GetManaRegen then
        regenText:Hide()
        return
    end
    local max = Ask(UnitPowerMax("player", MANA_TYPE))
    if max ~= nil and max <= 0 then   -- no mana at all: a warrior, a rogue
        regenText:Hide()
        return
    end
    regenText:Show()
    local full, casting = GetManaRegen()
    if Secret(full) or Secret(casting) or not full then return end
    casting = casting or full
    local per5 = function(v) return math.floor(v * 5 + 0.5) end
    local left = FSR - (GetTime() - lastSpend)
    if left > 0 then
        regenText:SetFormattedText("|cffe6c370MP5|r %d  |cff8c8c8c%d in %d s|r", per5(casting), per5(full), math.ceil(left))
    else
        regenText:SetFormattedText("|cffe6c370MP5|r %d  |cff8c8c8c%d after a cast|r", per5(full), per5(casting))
    end
end

function Update()
    if preview then return end
    UpdateRegen()
    -- your group and its pets, or with the raid table every raid member
    local count, raidMode = 0, RaidMode()
    for _, c in ipairs(lines) do
        if c ~= stranger then
            if (c.kind == "raid") == raidMode and UnitExists(c.unit) then
                FillLine(c)
                count = count + 1
            elseif not healer then
                c:Hide()
            end
        end
    end
    local extra = StrangerOn()
    if extra then
        FillLine(stranger)
    elseif not healer then
        stranger:Hide()
    end
    if healer then
        -- the state driver shows the line for a friendly target outside
        -- the party, and solo it cannot tell you from a stranger (owner
        -- 2026-11-08: "You" and the innkeeper, after targeting himself):
        -- for you or a member the line goes transparent instead. Alpha
        -- is not protected, so this holds in a fight too; the driver's
        -- own show and hide stay untouched.
        stranger:SetAlpha(TargetInTable() and 0 or 1)
    end
    Stack(count, extra)
    if cdDirty then ApplyCooldowns() end
    if not holder:IsShown() and not Locked() then holder:Show() end
    UpdateHints()
end

function ns.ApplyHotLayout()
    cdDirty = true
    if DeckUIForeverOrbsDB.hotTracker and not preview then Update() end
end

-- the slots changed (hotBuffSlots, hotCastSlots, hotCustom): read the
-- lists again; in the healer mode a fight delays the new layout to its end
local Rebuilt   -- below
function ns.ApplyHotList()
    Rebuilt()
    if DeckUIForeverOrbsDB.hotTracker and not preview then Update() end
end

-- the switch for the target line: the healer mode's driver comes or goes
-- with it, out of a fight (the line is protected); Update does the rest
function ns.ApplyHotStranger()
    ns.OutOfCombat("hotStranger", function()
        if healer and stranger then
            if StrangerWanted() then
                RegisterStateDriver(stranger, "visibility", StrangerShown())
            else
                UnregisterStateDriver(stranger, "visibility")
                stranger:Hide()
            end
        end
        if DeckUIForeverOrbsDB.hotTracker and not preview then Update() end
    end)
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

function Rebuilt()
    Rebuild()
    UpdateOthersFilter()
end

local SPEC_EVENTS = { "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        -- the bar alone, at once; the rest of the line waits for the tick
        local c = unit and byUnit[unit]
        if c and not preview and Opt("hotHealth") then UpdateHealth(c) end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        RefreshUnit(stranger)
        if DeckUIForeverOrbsDB.hotTracker and not preview then Update() end   -- the line's name and alpha at once
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
        -- party1 may be someone else now, and so may a pet or a raid token
        for _, c in ipairs(lines) do
            if c ~= stranger then RefreshUnit(c) end
        end
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" or event == "PLAYER_ROLES_ASSIGNED" then
        -- the style switch: the glyphs come or go with Update; a new role: the order
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
    you:ClearAllPoints()
    you:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    mate:ClearAllPoints()
    mate:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(Size() + GAP))
    holder:SetSize(LineWidth(#samples), 2 * (Size() + GAP) - GAP)
    holder:Show()
end

function ns.SetHotTracker(on)
    DeckUIForeverOrbsDB.hotTracker = on and true or false
    if on then
        for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD",
                             "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "INPUT_DEVICE_INTERFACE_TRANSITION",
                             "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_PET", "PLAYER_ROLES_ASSIGNED",
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

-------------------------------------------------------------------
-- What padheal.lua (Deck Heal) asks of this file
-------------------------------------------------------------------
-- the line of a unit token (player, party1-4), nil before the factory ran
function ns.HotLine(unit) return byUnit[unit] end

-- The spells Deck Heal casts when the player named none: your HoTs, then
-- your direct heals - the later of the list first, they are the stronger
-- ones (a priest's Flash Heal before Lesser Heal) - then your cures. Only
-- what the character knows, each name once, `max` at most.
function ns.HotLayerSpells(max)
    local list, seen = {}, {}
    local function Take(id)
        if #list >= max then return end
        local n = Known(id) and SpellName(id)
        if n and not seen[n] then
            seen[n] = true
            list[#list + 1] = { name = n, id = id, icon = SpellIcon(id), cast = ns.HotTopRank(n, id) }
        end
    end
    local key = ListKey()
    for _, e in ipairs(LISTS[key] or {}) do
        if Known(e.known or e.id) then Take(e.id) end
    end
    local casts = CASTS[key] or {}
    for i = #casts, 1, -1 do
        local e = casts[i]
        if not e.need and e.layer ~= false then Take(e.id) end
    end
    for _, e in ipairs(casts) do
        if e.need == "cure" then Take(e.id) end
    end
    return list
end

oUF:Factory(function()
    D.MakeMovable(holder, "HoTs", DeckUIForeverOrbsDB)
    loadedSize = Size()
    healer = DeckUIForeverOrbsDB.hotHealer and true or false
    petsOn = Opt("hotPets")
    raidOn = Opt("hotRaid")
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
    print(("DeckUIForever HoTs: %s, class %s, %d slots, buffs: %s, %s, order: %s, target line %s, icon %d px, click to cast %s, in combat: %s%s."):format(
        DeckUIForeverOrbsDB.hotTracker and "on" or "off", tostring(ListKey()), #entries,
        AllBuffs() and "every buff" or "yours up to a minute", Across() and "side by side" or "stacked",
        IsInRaid() and "tank, healer, damage, then raid group" or "tank, healer, damage, then you first", StrangerWanted() and "on" or "off",
        Size(), healer and "on" or "off", tostring(UnitAffectingCombat("player")),
        Locked() and " (window locked until it ends)" or ""))
    print(("  controller glyphs: option %s, gamepad style %s, party targeting %s, friendly modifier held %s"):format(
        DeckUIForeverOrbsDB.hotPadHints ~= false and "on" or "off", tostring(GamepadStyle()),
        tostring(HintsOn()), tostring(FriendlyModifierDown())))
    local function OnOff(key) return Opt(key) and "on" or "off" end
    print(("  extras: health %s, status %s, range %s, debuffs to remove %s (%s), missing buffs %s, cast buttons %s, pets %s (loaded %s), raid table %s (loaded %s, active %s), warning blink %s sound %s at %s s"):format(
        OnOff("hotHealth"), OnOff("hotStatus"), OnOff("hotRange"), OnOff("hotDispel"), DISPEL_FILTER,
        OnOff("hotBuffSlots"), OnOff("hotCastSlots"), OnOff("hotPets"), tostring(petsOn),
        OnOff("hotRaid"), tostring(raidOn), tostring(RaidMode()),
        OnOff("hotWarn"), OnOff("hotWarnSound"), tostring(DeckUIForeverOrbsDB.hotWarnAt or 3)))
    do
        -- what the game hands out for the regeneration line, raw (per second)
        local full, casting
        if GetManaRegen then full, casting = GetManaRegen() end
        local function Show(v) return Secret(v) and "secret" or tostring(v) end
        print(("  mana regeneration %s: GetManaRegen %s, full %s, after a cast %s, last mana spend %.1f s ago, mana readable %s, last seen: %s"):format(
            OnOff("hotRegen"), GetManaRegen and "there" or "missing", Show(full), Show(casting),
            lastSpend > 0 and (GetTime() - lastSpend) or -1, tostring(manaReadable), regenSeen))
    end
    if #customUnknown > 0 then
        print("  your own list, not known to the game: " .. table.concat(customUnknown, ", "))
    end
    for _, e in ipairs(LISTS[ListKey()] or {}) do
        local top = ns.HotTopRank(SpellName(e.id), e.id)
        print(("  list %d %s: known %s, casts %s %s"):format(e.id, tostring(SpellName(e.id)),
            tostring(Known(e.known or e.id)), tostring(top),
            tostring(C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(top) or "")))
    end
    for i, e in ipairs(entries) do
        local ids = {}
        for id in pairs(e.ids or {}) do ids[#ids + 1] = id end
        table.sort(ids)
        print(("  slot %d: %s (%d), %s%s%s%s"):format(i, tostring(e.name), e.id, e.kind,
            e.need == "cure" and (", only with " .. table.concat(e.types or {}, "/"))
                or e.need == "dead" and ", only on the dead" or "",
            e.custom and ", your own" or "",
            #ids > 0 and (", IDs " .. table.concat(ids, " ")) or ""))
    end
    for _, c in ipairs(lines) do
        if c.kind ~= "raid" or UnitExists(c.unit) then
        local slots = 0
        for _, s in ipairs(c.slots) do if s:IsShown() then slots = slots + 1 end end
        print(("  %s: %s, %s, row %s, role %s, raid index %s, slots %d%s"):format(c.unit,
            UnitExists(c.unit) and (tostring(UnitName(c.unit)) or "?") or "none",
            c:IsShown() and "shown" or "hidden", tostring(c.row),
            UnitGroupRolesAssigned and UnitExists(c.unit) and tostring(Ask(UnitGroupRolesAssigned(c.unit)) or "secret") or "-",
            IsInRaid() and UnitExists(c.unit) and tostring(Ask(UnitInRaid(c.unit)) or "secret") or "-", slots,
            c == stranger and (", friendly " .. tostring(Friendly("target")) .. ", in the table " ..
                tostring(GUID("target") ~= nil and InTable(GUID("target")))) or ""))
        -- the missing-buff slots: what the game answers for this unit right now
        if UnitExists(c.unit) and c.kind ~= "pet" then
            for i, e in ipairs(entries) do
                if e.kind == "buff" then
                    local state, read, hidden = BuffState(c.unit, e)
                    local s = c.slots[i]
                    print(("    %s: %s (buffs read %d, kept from us %d), icon shows missing: %s"):format(
                        tostring(e.name), state or "the game will not say", read, hidden,
                        tostring(s and s.missing or false)))
                end
            end
        end
        end
    end
end
