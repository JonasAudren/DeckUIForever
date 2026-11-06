local ADDON, ns = ...
local D = DeckUIForever
local oUF = ns.oUF

-------------------------------------------------------------------
-- Your debuffs, one capsule each, as FFXIV would draw them
-------------------------------------------------------------------
-- The owner's wish (2026-10-28, in Mists): a class needs its own view of
-- what it keeps up - a warlock's DoTs, a druid's bleeds. A window of its
-- own (movable "Debuffs"): a column for your target and a smaller one for
-- your focus. DeckUIForeverOrbsDB.dotTracker, off by default, switched
-- without a reload; /orbs dots prints what it sees.
--
-- Rebuilt for Forever on 2026-11-05. Forever (as Midnight) keeps an
-- enemy's auras from addons in combat - even the player's own: the index
-- scan throws ("Auras cannot be accessed when secret while tainted"), and
-- the one allowed lookup, GetAuraDataBySpellName, returned nothing for the
-- owner's Shadow Word: Pain on a living target in a fight. So no Lua of
-- ours reads the auras any more. Each row is Blizzard's own aura widget:
-- a CustomAuraContainer with one aura slot filtered to that debuff's spell
-- IDs, whose button the engine fills in combat too - the icon (SetIcon),
-- the name (SetSpellName), the capsule (SetDurationBar: the engine drives
-- our StatusBar from the aura's duration), the time text (SetDurationText),
-- the stack count, and the last 30% (AddPandemicRegion: the engine shows
-- our gold wash inside the pandemic window). The container works for an
-- addon exactly as it does for Blizzard: it is an intrinsic frame
-- (Blizzard_AuraContainer, 1.60.1; the FF target bar's icons are the same).
--
-- What the engine does not say is what is NOT there: a button only exists
-- while the aura does. So every row has a layer of ours underneath - the
-- same icon and name, an empty capsule with a red edge - and the engine's
-- button covers it while the debuff runs. In a fight the red edge means
-- "missing"; out of it the layer is dimmed, since out of combat the
-- window said "Censure --" at every crocolisk (owner, 2026-10-28).
--
-- Rows show only for what you know (IsPlayerSpell), so talents sort
-- themselves out. A row's slot takes every rank of the spell: the base
-- IDs below plus every spellbook entry of the same name - a debuff is
-- matched by its spell ID inside the engine, and Classic has ranks. Your
-- other debuffs on the target follow below the list as an aura group of
-- up to four, with the engine's names.
--
-- What the window tracks leaves the target frame's own debuff icons
-- (owner 2026-10-28: once a debuff runs as a bar, it is not an icon too):
-- the list's IDs go into the icon rows' excludeSpellIDs (ns.targetDebuffs,
-- ffstyle.lua). Candidate filters are live, so no reload.
--
-- Limits of the engine path: the capsule and the text are children of the
-- engine's button and are laid out once, when the button is made - the
-- name's width follows the "Show the names" setting at the next reload
-- (the bar itself is anchored between name and time and follows a width
-- change at once). Not yet tested in game.
-------------------------------------------------------------------
-- one line per debuff, close together (owner, 2026-10-28): icon, name,
-- capsule, and the time after it
local W, FOCUS_W, ROW_H, TITLE, PAD, ICON = 240, 170, 16, 20, 5, 14
local ROW_GAP, TIME_W, BAR_H = 2, 30, 6
local MAX_OTHER = 4
local PANDEMIC = 0.3
local POLL = 0.25
local GOLD = { 1, 0.82, 0.3 }
local RUN = { 0.5, 0.75, 0.3 }
local LATE = { 0.88, 0.7, 0.29 }
local MISSING = { 0.9, 0.3, 0.3 }
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Ask(v) if Secret(v) then return nil end return v end

-------------------------------------------------------------------
-- What each class keeps up
-------------------------------------------------------------------
-- id: the debuff (its name and icon); known: the spell that tells
-- whether you can apply it, when that is not the same one (a talent's
-- effect). The Classic spells' first ranks (vanilla IDs, kept unchanged
-- in Blizzard's spell data); Forever's talent rework may add or drop some
-- - not yet checked in game, /orbs dots says what the client knows. A
-- rogue's poisons are weapon enchants in Classic, not buffs, so DeckUI's
-- Mists poison rows are gone.
local LISTS = {
    WARLOCK = { { id = 980 }, { id = 172 }, { id = 348 }, { id = 18265 }, { id = 603 } },  -- Curse of Agony, Corruption, Immolate, Siphon Life, Curse of Doom
    PRIEST  = { { id = 589 }, { id = 2944 } },                                             -- Shadow Word: Pain, Devouring Plague
    DRUID   = { { id = 8921 }, { id = 5570 }, { id = 1822 }, { id = 1079 }, { id = 770 }, { id = 16857, known = 16857 } }, -- Moonfire, Insect Swarm, Rake, Rip, Faerie Fire, Faerie Fire (Feral) - a name of its own, matched by its own ID
    ROGUE   = { { id = 1943 }, { id = 703 }, { id = 8647 }, { id = 16511 } },               -- Rupture, Garrote, Expose Armor, Hemorrhage
    HUNTER  = { { id = 1978 }, { id = 1130 } },                                            -- Serpent Sting, Hunter's Mark
    WARRIOR = { { id = 772 }, { id = 7386 }, { id = 1160 } },                              -- Rend, Sunder Armor, Demoralizing Shout
    SHAMAN  = { { id = 8050 }, { id = 17364, known = 17364 } },                            -- Flame Shock, Stormstrike (talent)
    MAGE    = { { id = 11366 }, { id = 12654, known = 12846 }, { id = 22959, known = 2948 }, { id = 12579, known = 11180 } }, -- Pyroblast, Ignite, Fire Vulnerability (from Scorch), Winter's Chill (talent)
    PALADIN = { { id = 20185, known = 20165 }, { id = 20186, known = 20166 }, { id = 20188, known = 21082 } }, -- Judgement of Light (Seal of Light), of Wisdom (Seal of Wisdom), of the Crusader (Seal of the Crusader)
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

-- the list's key: the player's class
local function ListKey()
    return (select(2, UnitClass("player")))
end

-- Every spell ID a row's slot should take: the list's IDs and each
-- spellbook entry of the same name (the ranks the character knows),
-- read the way actionbars.lua walks the spellbook.
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

-- the rows of this class you can use: { name, icon, id, ids }, and every
-- ID of them for the exclusions
local entries = {}
local allIDs = {}

local NO_EXCLUDE = {}
function ns.ApplyDotExclusion()
    local filters = NO_EXCLUDE
    if DeckUIForeverOrbsDB.dotTracker then
        filters = { excludeSpellIDs = allIDs }
    end
    for _, entry in ipairs(ns.targetDebuffs or {}) do
        pcall(entry.container.SetAuraGroupCandidateFilters, entry.container, entry.key, filters)
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
    ns.ApplyDotExclusion()
end

-------------------------------------------------------------------
-- The window: two columns of rows
-------------------------------------------------------------------
local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.FONT, size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local holder = CreateFrame("Frame", "DeckOrbsDebuffs", UIParent)
holder:SetSize(W, 60)
holder.defaultPoint = { "CENTER", UIParent, "CENTER", 260, -120 }
holder:SetPoint(unpack(holder.defaultPoint))
holder:Hide()

-- No box, no edge, no title band (owner, 2026-11-05, after the first look
-- in Forever: "frameless and borderless like the player frame"): the
-- unit's name stands over the capsules the way the player's name stands
-- over the XIV bars, and that is all. It goes too when the rows hang at
-- the target frame (c.chrome).
local function Column(parent, width, tag, unit)
    local c = CreateFrame("Frame", nil, parent)
    c:SetWidth(width)
    c.unit = unit
    c.chrome = {}
    c.title = Text(c, 12)
    c.chrome[#c.chrome + 1] = c.title
    c.title:SetPoint("TOPLEFT", PAD, -3)
    c.title:SetPoint("RIGHT", -PAD, 0)
    c.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.rows, c.width = {}, width
    return c
end

local target = Column(holder, W, "TARGET", "target")
local focus = Column(holder, FOCUS_W, "FOCUS", "focus")

-- the columns of the units you left (Keep, below): made as needed, reused;
-- width, names and the others' filter follow them as they do the two above
local allKept = {}
local function Columns()
    local t = { target, focus }
    for _, c in ipairs(allKept) do t[#t + 1] = c end
    return t
end

-- Two ways to stand (DeckUIForeverOrbsDB.dotAttach): a window of its own, or the
-- bare rows at the target frame - the FF bar or the orb, whichever this
-- style spawned - and the focus column at the focus frame, above or below
-- them (DeckUIForeverOrbsDB.dotAbove). Our frames only anchor to theirs; nothing on
-- the unit frames changes.
--
-- Clear of what already hangs there (owner, 2026-10-28): below an FF bar
-- sit the cast bar, its text and the target's status icons - one row,
-- 22 px, 15 or 16 icons wide, for at most 8 debuffs + 6 buffs - so the
-- rows go under that row. An orb keeps its auras beside it, but its name
-- or cast text sits on the edge we hang at; a FF focus has its cast below.
local attached = false
local Title   -- a column's title, below (after `preview`)
local top = TITLE   -- where the rows start below a column's top edge
local GAP = 6
local TEXT_CLEAR = 22   -- an orb's name or cast text, an FF focus's cast and its text

local function UnitFrameFor(unit)
    if unit == "target" then return _G.DeckFFTarget or _G.DeckOrbsTarget end
    return _G.DeckXIVFocus or _G.DeckOrbsFocus
end

-- an FF bar or an orb: in the "ff" style the focus is still an orb
local function IsBar(frame)
    local name = frame:GetName() or ""
    return name:find("^DeckFF") or name:find("^DeckXIV")
end

-- An FF target bar names its outermost aura line on each side
-- (frame.DeckBelow / DeckAbove, ffstyle.lua TargetAuraRows): the column
-- hangs past it. Without one, past the orb's name or cast text.
local function Hang(c, frame, above)
    if above then
        -- the column grows upwards from its bottom edge, rows stay in order
        local over = frame.DeckAbove
        if over then
            c:SetPoint("BOTTOMLEFT", over, "TOPLEFT", 0, GAP)
        else
            c:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, IsBar(frame) and GAP or TEXT_CLEAR)
        end
        return
    end
    local under = frame.DeckBelow
    if under then
        c:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -GAP)
    else
        c:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -TEXT_CLEAR)
    end
end

function ns.ApplyDotLayout()
    attached = DeckUIForeverOrbsDB.dotAttach and true or false
    local above = DeckUIForeverOrbsDB.dotAbove and true or false
    top = attached and 0 or TITLE
    for _, c in ipairs({ target, focus }) do
        for _, piece in ipairs(c.chrome) do piece:SetShown(not attached) end
        c:ClearAllPoints()
    end
    local tf, ff = UnitFrameFor("target"), UnitFrameFor("focus")
    if attached and tf then
        Hang(target, tf, above)
    else
        target:SetPoint("TOPLEFT", holder, "TOPLEFT")
    end
    if attached and ff then
        Hang(focus, ff, above)
    else
        focus:SetPoint("TOPLEFT", target, "TOPRIGHT", 6, 0)
    end
end

-------------------------------------------------------------------
-- Rows: a layer of ours below, the engine's button above
-------------------------------------------------------------------
-- the geometry both layers share: name width and the bar between name and time
local function Names() return DeckUIForeverOrbsDB.dotNames ~= false end

local function NameWidth(c)
    local inner = c.width - 2 * PAD - ICON - 2
    return Names() and math.floor(inner * 0.4) or 0
end

-- places icon edge, icon, name, bar, time and tick of one layer in a row
local function Place(L, r, c, names)
    L.edge:ClearAllPoints()
    L.edge:SetPoint("LEFT", r, "LEFT", 0, 0)
    L.icon:ClearAllPoints()
    L.icon:SetPoint("CENTER", L.edge)
    L.name:SetShown(names)
    L.name:ClearAllPoints()
    L.name:SetPoint("LEFT", L.edge, "RIGHT", 4, 0)
    L.name:SetWidth(math.max(1, NameWidth(c)))
    L.time:ClearAllPoints()
    L.time:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    L.time:SetWidth(TIME_W)
    L.bar:ClearAllPoints()
    if names then
        L.bar:SetPoint("LEFT", L.name, "RIGHT", 4, 0)
    else
        L.bar:SetPoint("LEFT", L.edge, "RIGHT", 4, 0)
    end
    L.bar:SetPoint("RIGHT", L.time, "LEFT", -4, 0)
    if L.tick then
        L.tick:ClearAllPoints()
        local barW = c.width - 2 * PAD - ICON - 2 - NameWidth(c) - TIME_W - (names and 12 or 8)
        L.tick:SetPoint("LEFT", L.bar, "LEFT", math.floor(math.max(1, barW) * PANDEMIC), 0)
    end
end

-- the pieces of a layer on `parent`; `live` marks the engine's layer,
-- which gets no "--" and a gold wash for the pandemic window
local function Layer(parent, live)
    local L = {}
    L.edge = parent:CreateTexture(nil, "ARTWORK")
    L.edge:SetSize(ICON + 2, ICON + 2)
    L.icon = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    L.icon:SetSize(ICON, ICON)
    L.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    L.count = Text(parent, 9, "RIGHT")
    L.count:SetPoint("BOTTOMRIGHT", L.icon, "BOTTOMRIGHT", 2, -2)
    L.name = Text(parent, 10)
    L.bar = ns.PillBar(parent, 10, BAR_H)
    L.time = Text(parent, 10, "LEFT")
    if live then
        L.edge:SetColorTexture(0.55, 0.5, 0.42, 1)
        L.name:SetTextColor(0.95, 0.92, 0.85)
        L.time:SetTextColor(0.85, 0.82, 0.75)
        L.bar:SetStatusBarColor(RUN[1], RUN[2], RUN[3])
        L.bar.edge:SetVertexColor(0, 0, 0, 0.9)
        -- the last 30%: a wash over the fill, shown by the engine
        L.late = L.bar:CreateTexture(nil, "OVERLAY", nil, 1)
        L.late:SetTexture(WHITE)
        L.late:SetAllPoints(L.bar:GetStatusBarTexture())
        L.late:SetVertexColor(LATE[1], LATE[2], LATE[3], 0.7)
        L.late:Hide()
    else
        -- where the last 30% begin, on the empty track
        L.tick = L.bar:CreateTexture(nil, "OVERLAY", nil, 2)
        L.tick:SetSize(1, BAR_H)
        L.tick:SetColorTexture(1, 1, 1, 0.6)
        L.bar:SetMinMaxValues(0, 1)
        L.bar:SetValue(0)
    end
    return L
end

-- the static layer's look: red "missing" in a fight, dimmed out of it
-- Out of a fight the empty capsules show only when asked for (dotIdle,
-- off; owner 2026-11-06: "turn this off, as an option") or in the unlock
-- preview (force). In a fight the red missing ones always show.
local function Idle() return DeckUIForeverOrbsDB.dotIdle and true or false end

local function SetStatic(r, fighting, force)
    local L = r.static
    local on = force or fighting or Idle()
    L.edge:SetShown(on)
    L.icon:SetShown(on)
    L.count:SetShown(on)
    L.name:SetShown(on and Names())
    L.bar:SetShown(on)
    L.time:SetShown(on)
    if fighting then
        L.edge:SetColorTexture(MISSING[1], MISSING[2], MISSING[3], 1)
        L.bar.edge:SetVertexColor(MISSING[1], MISSING[2], MISSING[3], 1)
        L.icon:SetDesaturated(true)
        L.icon:SetAlpha(0.6)
        L.name:SetTextColor(0.95, 0.6, 0.6)
        r:SetAlpha(1)
    else
        L.edge:SetColorTexture(0.35, 0.33, 0.3, 1)
        L.bar.edge:SetVertexColor(0, 0, 0, 0.9)
        L.icon:SetDesaturated(true)
        L.icon:SetAlpha(0.5)
        L.name:SetTextColor(0.7, 0.68, 0.64)
        r:SetAlpha(0.6)
    end
end

-- The engine's button for a row or for one of the "other" debuffs: made
-- once, when the container creates it (initializeFrame runs before the
-- button's access restrictions), and handed every piece the engine fills.
-- anchorButton: the button takes the row's place (a list row); the
-- "others" do it the other way round, their row frame is the button's
-- child and follows it - anchoring both ways was a circle (20 errors on
-- the owner's first look, 2026-11-05)
local function LiveButton(button, r, c, named, anchorButton)
    -- no script of ours on the button, not even a hook: the engine shows
    -- and hides it with a secret, and "SetShown(): Cannot be called with
    -- secrets due to existing script handlers" killed every row's creation
    -- (1514 errors, owner 2026-11-06)
    if anchorButton then button:SetAllPoints(r) end
    local L = Layer(button, true)
    button:SetIcon(L.icon)
    button:SetApplicationCount(L.count, {})
    -- the engine writes the name, in the list rows too: a piece handed to
    -- the engine's button is forbidden to us afterwards (SetText on it
    -- threw "forbidden object" when a row was reassigned, owner
    -- 2026-11-05), and a list row's slot holds that one spell anyway
    button:SetSpellName(L.name)
    button:SetDurationBar(L.bar, { direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime })
    button:SetDurationText(L.time, {})
    button:AddPandemicRegion(L.late)
    Place(L, r, c, Names())
    r.live = L
    -- the tooltip is the engine's own aura tooltip (AuraButton's OnEnter)
    return button
end

local function Row(c, i)
    local r = c.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, c)
    r:SetSize(c.width - 2 * PAD, ROW_H)
    r.static = Layer(r, false)
    Place(r.static, r, c, Names())
    -- the engine's layer: a container with one slot, filtered to the row's
    -- spell when the row is assigned (Assign)
    local auras = CreateFrame("AuraContainer", nil, r, "CustomAuraContainerTemplate")
    auras:SetAllPoints(r)
    auras:SetUnit(c.unit)
    auras:AddAuraSlot("dot", "HARMFUL|PLAYER", {
        candidateFilters = { includeSpellIDs = {} },
        initializeFrame = function(button) LiveButton(button, r, c, false, true) end,
    })
    r.auras = auras
    c.rows[i] = r
    return r
end

-- a row takes a list entry: the static icon and name, the slot's spell IDs
local function Assign(r, e)
    r.entry = e
    r.liveName = e.name
    r.static.icon:SetTexture(e.icon or 134400)
    r.static.name:SetText(e.name or "")
    pcall(r.auras.SetAuraSlotCandidateFilters, r.auras, "dot", { includeSpellIDs = e.ids or {} })
end

-- the rest of your debuffs on the unit, below the list: an aura group of
-- the engine's, up to MAX_OTHER rows, their names from the engine
local function Others(c)
    if c.others then return c.others end
    local auras = CreateFrame("AuraContainer", nil, c, "CustomAuraContainerTemplate")
    auras:SetSize(c.width - 2 * PAD, MAX_OTHER * (ROW_H + ROW_GAP))
    auras:SetUnit(c.unit)
    auras:SetFlowLayoutAnchorPoint("TOPLEFT")
    auras:SetFlowLayoutAxis(ns.FLOW.Vertical)
    auras:SetFlowLayoutMaximumLineSize(MAX_OTHER * (ROW_H + ROW_GAP))
    auras:SetFlowLayoutGrowthDirection(1, -1)
    auras:AddAuraGroup("others", "HARMFUL|PLAYER", {
        maxFrameCount = MAX_OTHER,
        candidateFilters = { excludeSpellIDs = allIDs },
        layout = { elementSpacing = ROW_GAP },
        initializeFrame = function(button)
            -- a row frame of ours under each, for the shared geometry
            button:SetSize(c.width - 2 * PAD, ROW_H)
            local r = CreateFrame("Frame", nil, button)
            r:SetAllPoints(button)
            LiveButton(button, r, c, true, false)
        end,
    })
    c.others = auras
    return auras
end

-- the list's IDs may change (a new rank, a new talent): the others leave them out
local function UpdateOthersFilter()
    for _, c in ipairs(Columns()) do
        if c.others then
            pcall(c.others.SetAuraGroupCandidateFilters, c.others, "others", { excludeSpellIDs = allIDs })
        end
    end
end

function ns.ApplyDotNames()
    local names = Names()
    for _, c in ipairs(Columns()) do
        for _, r in ipairs(c.rows) do Place(r.static, r, c, names) end
    end
    -- the engine's layer is laid out when its button is made
    D.NeedReload("dotNames")
end

-- The columns' width, per device (ns.DeviceDB().dotScale, a percentage of
-- W on the Debuffs page, 175% = the widest target bar - owner 2026-10-28);
-- the focus column keeps its share of it. Rows already made follow at
-- once; the engine's bars are anchored between name and time and stretch.
local FOCUS_SHARE = FOCUS_W / W
function ns.ApplyDotWidth()
    local w = math.floor(W * (ns.DeviceDB().dotScale or 100) / 100 + 0.5)
    target.width, focus.width = w, math.floor(w * FOCUS_SHARE)
    for _, c in ipairs(allKept) do c.width = focus.width end
    for _, c in ipairs(Columns()) do
        c:SetWidth(c.width)
        for _, r in ipairs(c.rows) do
            r:SetWidth(c.width - 2 * PAD)
            Place(r.static, r, c, Names())
        end
        if c.others then c.others:SetWidth(c.width - 2 * PAD) end
    end
    holder:SetWidth(w)
end

-- lays the shown rows out and sizes the column; false when it has none
local function Finish(c, shown)
    local y = -top - 3
    for i = 1, shown do
        local r = c.rows[i]
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", PAD, y)
        r:Show()
        y = y - ROW_H - ROW_GAP
    end
    for i = shown + 1, #c.rows do c.rows[i]:Hide() end
    -- the other debuffs hang below the list, outside the column's box
    local others = Others(c)
    others:ClearAllPoints()
    others:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, y - 2)
    c:SetHeight(-y + PAD - 2)
    c:SetShown(shown > 0)
    return shown > 0
end

local function Attackable(unit)
    if not UnitExists(unit) then return false end
    if Ask(UnitCanAttack("player", unit)) == false then return false end
    return Ask(UnitIsDead(unit)) ~= true
end

-- a secret answer counts as fighting: better a red row too many than none
local function Fighting()
    return Ask(UnitAffectingCombat("player")) ~= false
end

-- a kept column reads a nameplate token that may change hands: every
-- container of the column is pointed at the new token (as hots.lua does)
local function SetColumnUnit(c, unit)
    if c.unit == unit then return end
    c.unit = unit
    for _, r in ipairs(c.rows) do pcall(r.auras.SetUnit, r.auras, unit) end
    if c.others then pcall(c.others.SetUnit, c.others, unit) end
    RefreshUnit(c)
end

local function FillColumn(c, unit)
    if not Attackable(unit) then
        c:Hide()
        return false
    end
    SetColumnUnit(c, unit)
    local fighting = Fighting()
    for i, e in ipairs(entries) do
        local r = Row(c, i)
        if r.entry ~= e then Assign(r, e) end
        SetStatic(r, fighting)
    end
    c.title:SetText(UnitName(unit))
    Title(c)
    return Finish(c, #entries)
end

local preview = false

-- Out of a fight nothing is secret, so the one by-name lookup says which
-- of the list runs on the column's unit (the engine's button cannot be
-- asked - see LiveButton). The first running name, or nil; a throw or a
-- secret answer counts as none. In a fight the title shows anyway.
local function Running(c)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return nil end
    for _, r in ipairs(c.rows) do
        if r.entry and r:IsShown() then
            local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, c.unit, r.entry.name, "HARMFUL|PLAYER")
            if ok and data and not Secret(data) then return r.entry.name end
        end
    end
    return nil
end

-- the column's title: in a fight or with the empty capsules it heads
-- the rows; otherwise only a running capsule, else nothing hangs there
function Title(c)
    if preview then return end
    local on = Fighting() or Idle() or Running(c) ~= nil
    c.title:SetShown(on and not attached)
end

-------------------------------------------------------------------
-- Units you leave: the one you targeted keeps its column (dotKeep)
-------------------------------------------------------------------
-- Owner 2026-11-06: "keep the DoTs and HoTs on targets when I switch
-- targets - they vanish now". A container follows a unit token, so a left
-- unit needs one of its own: the nameplate it stands under -
-- so enemy nameplates must be on; an enemy without one cannot be kept.
-- TokenFor finds it by GUID each tick. Kept columns stack under the target
-- column at the focus width, newest first, in the window only (at the
-- target frame there is nothing to hang them from). A unit is kept when
-- it is known to carry one of the list - the by-name lookup out of a
-- fight, or a cast of ours on it (UNIT_SPELLCAST_SUCCEEDED, our IDs) -
-- not merely for having been looked at. A column goes when the unit has
-- no token any more, is dead, out of a fight has none of the list
-- running, or KEEP seconds after the last cast or sighting: in a fight
-- the lookup may say nothing, and a Classic DoT runs 24 s at most - a long
-- curse outlives its column.
local KEEP, MAX_KEEP = 30, 4
local kept = {}       -- { guid, column, since }, newest first
local spare = {}      -- columns to reuse
local castOn = {}     -- guid -> the time of our last cast of the list on it

local function KeepOn() return DeckUIForeverOrbsDB.dotKeep ~= false end

local TOKENS = {}
for i = 1, 40 do TOKENS[#TOKENS + 1] = "nameplate" .. i end

local function TokenFor(guid)
    for _, t in ipairs(TOKENS) do
        if UnitExists(t) and UnitGUID(t) == guid then return t end
    end
    return nil
end

local function KeptColumn()
    local c = table.remove(spare)
    if not c then
        c = Column(holder, focus.width, "KEPT", "player")
        allKept[#allKept + 1] = c
    end
    return c
end

local function Drop(i)
    local k = table.remove(kept, i)
    k.column:Hide()
    spare[#spare + 1] = k.column
end

local function DropAll()
    for i = #kept, 1, -1 do Drop(i) end
end

local function CastOn(guid)
    if guid then castOn[guid] = GetTime() end
end

-- the unit the target column showed, as it goes
local function Keep(guid, running)
    if not KeepOn() or attached or not guid then return end
    for _, k in ipairs(kept) do
        if k.guid == guid then k.since = GetTime() return end
    end
    local now = GetTime()
    if not (running or (castOn[guid] and now - castOn[guid] < KEEP)) then return end
    if #kept >= MAX_KEEP then Drop(#kept) end
    table.insert(kept, 1, { guid = guid, column = KeptColumn(), since = now })
end

-- fills, prunes and stacks the kept columns; returns the stack's height
local function UpdateKept(targetGUID, focusGUID, targetShown)
    local now, fighting = GetTime(), Fighting()
    for g, t in pairs(castOn) do if now - t > KEEP then castOn[g] = nil end end
    for i = #kept, 1, -1 do
        local k = kept[i]
        local token = (KeepOn() and not attached and k.guid ~= targetGUID and k.guid ~= focusGUID) and TokenFor(k.guid) or nil
        local shown = token and FillColumn(k.column, token)
        if shown then
            local run = Running(k.column)
            if run or (castOn[k.guid] or 0) > k.since then k.since = now end
            -- out of a fight the lookup is the truth, a second after a cast
            if (not fighting and not run and now - (castOn[k.guid] or 0) > 1) or now - k.since > KEEP then shown = false end
        end
        if not shown then Drop(i) end
    end
    local anchor = targetShown and target or nil
    local h = 0
    for _, k in ipairs(kept) do
        local c = k.column
        c:ClearAllPoints()
        if anchor then
            c:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -GAP)
        else
            c:SetPoint("TOPLEFT", holder, "TOPLEFT")
        end
        anchor = c
        h = h + GAP + c:GetHeight()
    end
    return h
end

local lastGUID, lastRunning = nil, false

local function Update()
    if preview then return end
    local guid = Attackable("target") and UnitGUID("target") or nil
    if guid ~= lastGUID then
        Keep(lastGUID, lastRunning)
        lastGUID, lastRunning = guid, false
    end
    local any = FillColumn(target, "target")
    if any and Running(target) then lastRunning = true end
    local focusOn = UnitExists("focus") and Ask(UnitIsUnit("focus", "target")) == false
    if focusOn then
        focusOn = FillColumn(focus, "focus")
    else
        focus:Hide()
    end
    -- the focus column keeps its place when the target column is empty
    target:SetShown(any)
    local stack = UpdateKept(guid, UnitExists("focus") and UnitGUID("focus") or nil, any)
    holder:SetHeight(math.max((any and target:GetHeight() or 0) + stack, focusOn and focus:GetHeight() or 0, 20))
    holder:SetShown(any or focusOn or #kept > 0)
end

-- the containers follow their unit token, not the unit behind it: a new
-- target or focus is read in afresh
local function RefreshUnit(c)
    for _, r in ipairs(c.rows) do pcall(r.auras.UpdateAllAuras, r.auras) end
    if c.others then pcall(c.others.UpdateAllAuras, c.others) end
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

-- a talent group switch or a new talent can change what is known
local SPEC_EVENTS = { "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }
driver:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- one of the list cast by you: on the unit the target column shows
        if unit == "player" and spellID and allIDs[spellID] then CastOn(lastGUID) end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        RefreshUnit(target)
    elseif event == "PLAYER_FOCUS_CHANGED" then
        RefreshUnit(focus)
    elseif event ~= "PLAYER_REGEN_ENABLED" and event ~= "PLAYER_REGEN_DISABLED" then
        Rebuild()
        UpdateOthersFilter()
    end
    Update()
end)

local function ShowPreview(on)
    preview = on
    if not on then
        if DeckUIForeverOrbsDB.dotTracker then Update() else holder:Hide() end
        return
    end
    -- the sample rows only when asked for (dotPreview, off; owner 2026-11-06:
    -- "take the preview out, as an option"): without them the window is
    -- an empty box the height of three rows, enough to drag by its overlay
    if not DeckUIForeverOrbsDB.dotPreview then
        target:Hide()
        focus:Hide()
        holder:SetHeight(TITLE + 3 * (ROW_H + ROW_GAP) + PAD)
        holder:Show()
        return
    end
    target:SetShown(true)
    target.title:SetText("Debuffs")
    target.title:SetShown(not attached)
    local samples = { { 136118, "Drag me" }, { 136139, "A running debuff fills in" }, { 136188, "Missing in a fight" } }
    for i, s in ipairs(samples) do
        local r = Row(target, i)
        r.static.icon:SetTexture(s[1])
        r.static.name:SetText(s[2])
        SetStatic(r, i == 3, true)
    end
    Finish(target, 3)
    focus.title:SetText("Focus")
    focus.title:SetShown(not attached)
    local r = Row(focus, 1)
    r.static.icon:SetTexture(136118)
    r.static.name:SetText("Sample")
    SetStatic(r, false, true)
    Finish(focus, 1)
    holder:SetHeight(target:GetHeight())
    holder:Show()
end

function ns.SetDotTracker(on)
    DeckUIForeverOrbsDB.dotTracker = on and true or false
    if on then
        for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
                             unpack(SPEC_EVENTS) }) do
            if not C_EventUtils or C_EventUtils.IsEventValid(e) then driver:RegisterEvent(e) end
        end
        pcall(driver.RegisterUnitEvent, driver, "UNIT_SPELLCAST_SUCCEEDED", "player")
        driver:SetScript("OnUpdate", Tick)
        Rebuild()
        UpdateOthersFilter()
        Update()
    else
        driver:UnregisterAllEvents()
        driver:SetScript("OnUpdate", nil)
        if not preview then holder:Hide() end
        DropAll()
        ns.ApplyDotExclusion()   -- the icons come back
    end
end

oUF:Factory(function()
    D.MakeMovable(holder, "Debuffs", DeckUIForeverOrbsDB)
    ns.ApplyDotWidth()
    -- after the unit frames: this factory runs after layout.lua's
    ns.ApplyDotLayout()
    ns.SetDotTracker(DeckUIForeverOrbsDB.dotTracker)
    D.OnUnlock(function(state, only)
        if only and not only["Debuffs"] then state = false end
        ShowPreview(state and DeckUIForeverOrbsDB.dotTracker and true or false)
    end)
end)

-- /orbs dots: the class, its list, what you know and which IDs each row's
-- slot takes. What is on the target the engine keeps to itself in a fight.
function ns.DotDebug()
    print(("DeckUIForever debuffs: %s, class %s, %d rows."):format(
        DeckUIForeverOrbsDB.dotTracker and "on" or "off", tostring(ListKey()), #entries))
    for _, e in ipairs(LISTS[ListKey()] or {}) do
        local name = SpellName(e.id)
        local ids, n = {}, 0
        for _, entry in ipairs(entries) do
            if entry.id == e.id then
                for id in pairs(entry.ids) do ids[#ids + 1] = id end
            end
        end
        table.sort(ids)
        print(("  %d %s: known %s, slot IDs %s"):format(e.id, tostring(name), tostring(Known(e.known or e.id)),
            #ids > 0 and table.concat(ids, " ") or "-"))
    end
    print(("  target: %s, attackable %s, in combat: %s, rows shown %d, running by name: %s, title %s"):format(
        UnitExists("target") and (tostring(UnitName("target")) or "?") or "none",
        tostring(Attackable("target")), tostring(UnitAffectingCombat("player")),
        target:IsShown() and #entries or 0, tostring(Running(target)), target.title:IsShown() and "shown" or "hidden"))
    for i, k in ipairs(kept) do
        local token = TokenFor(k.guid)
        print(("  kept %d: %s (%s), %.0f s ago, running by name: %s"):format(i, token and tostring(UnitName(token)) or "?",
            tostring(token), GetTime() - k.since, tostring(Running(k.column))))
    end
end
