local ADDON, ns = ...
local D = DeckUIForever
local oUF = ns.oUF

-------------------------------------------------------------------
-- The buff window: who in your party lacks a buff you can cast
-------------------------------------------------------------------
-- Owner 2026-11-17: "können wir ein separates Buff-Fenster bauen, ich
-- möchte das nicht mehr im HoTs haben". Until then the missing buffs were
-- slots of the HoT window's lines (hotBuffSlots, kind "buff"); they left
-- that window and stand here: DeckUIForeverOrbsDB.buffCheck (off, /reload;
-- a saved hotBuffSlots = true turns it on once, layout.lua's Factory).
--
-- A line per party token - you, party1-4 - with the member's name and one
-- round icon per buff of the class (heals.lua's BUFFS through
-- ns.HotBuffEntries: Fortitude, Mark of the Wild, Arcane Intellect ...).
-- An icon shows only while that member lacks the buff, whoever cast it
-- (ns.HotBuffState, the HoT window's check: "there", "missing" or nil
-- while the game will not say - then the last answer for the same person
-- stands). A line without a missing buff shows nothing, name included, so
-- a fully buffed party leaves the window empty. Not for the dead, the far
-- away or the offline; not for pets (no target for these buffs in
-- Forever); not for raid groups other than yours.
--
-- Every icon is a button that casts the buff on that member: a
-- SecureActionButton (type spell, unit = the line's token, spell = the
-- highest rank), so the window is protected like the HoT window's healer
-- mode. What follows from that:
--   * the lines are made once, out of a fight, and never moved, sized,
--     shown or hidden by us - a state driver shows a party token's line
--     while the token exists;
--   * a button comes and goes by alpha alone. Out of a fight its mouse goes
--     with it; in a fight an invisible button keeps what it had (a buff
--     that drops mid-fight shows, a click on it works only if the button
--     was missing before the fight - it catches up when the fight ends);
--   * the spells are written out of a fight (SPELLS_CHANGED in a fight
--     waits for PLAYER_REGEN_ENABLED).
-- /orbs buffs prints what the window sees.
-------------------------------------------------------------------
local UNITS = { "player", "party1", "party2", "party3", "party4" }
local ICON = 22       -- at 100% (device buffCheckScale)
local NAME_W = 64
local GAP = 3
local MAX = 6         -- slots a line is made with; no class has more buffs in BUFFS
local TICK = 0.5

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Ask(v) if Secret(v) then return nil end return v end

local function Size()
    return math.max(10, math.floor(ICON * (ns.DeviceDB().buffCheckScale or 100) / 100 + 0.5))
end

local holder = CreateFrame("Frame", "DeckOrbsBuffCheck", UIParent)
holder:SetSize(NAME_W + MAX * (ICON + GAP), #UNITS * (ICON + GAP))
holder.defaultPoint = { "CENTER", UIParent, "CENTER", -320, 120 }
holder:SetPoint(unpack(holder.defaultPoint))
holder:Hide()

local lines = {}
local entries = {}
local built = false
local pendingSpells = false

local function OnEnter(b)
    if not (b.entry and b.missing) then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(b.entry.cast or b.entry.id)
    GameTooltip:Show()
end

-- the frames, once and out of a fight
local function Build()
    if built then return end
    built = true
    local size = Size()
    holder:SetSize(NAME_W + MAX * (size + GAP), #UNITS * (size + GAP) - GAP)
    for i, unit in ipairs(UNITS) do
        local line = CreateFrame("Frame", nil, holder)
        line.unit = unit
        line:SetSize(NAME_W + MAX * (size + GAP), size)
        line:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * (size + GAP))

        local name = line:CreateFontString(nil, "OVERLAY")
        name:SetFont(ns.FONT, 12, "OUTLINE")
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        name:SetWidth(NAME_W - 4)
        name:SetPoint("LEFT", line, "LEFT", 0, 0)
        name:SetAlpha(0)
        line.name = name

        line.slots = {}
        for j = 1, MAX do
            local b = CreateFrame("Button", nil, line, "SecureActionButtonTemplate")
            b:RegisterForClicks("AnyDown", "AnyUp")   -- the template keeps the one the key-down setting wants
            b:SetAttribute("type", "spell")
            b:SetAttribute("unit", unit)
            b:SetSize(size, size)
            b:SetPoint("LEFT", line, "LEFT", NAME_W + (j - 1) * (size + GAP), 0)
            ns.IconRim(b, 0.9, 0.3, 0.3, 1)
            local icon = ns.RoundIcon(b:CreateTexture(nil, "ARTWORK"))
            icon:SetAllPoints(b)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b.icon = icon
            b:SetAlpha(0)
            b:EnableMouse(false)
            b:SetScript("OnEnter", OnEnter)
            b:SetScript("OnLeave", GameTooltip_Hide)
            line.slots[j] = b
        end

        if unit ~= "player" then
            RegisterStateDriver(line, "visibility", ("[@%s,exists] show; hide"):format(unit))
        end
        lines[i] = line
    end
end

-- which buffs, and what each button casts; out of a fight only
local function ApplySpells()
    if InCombatLockdown() then pendingSpells = true return end
    pendingSpells = false
    entries = ns.HotBuffEntries and ns.HotBuffEntries() or {}
    for _, line in ipairs(lines) do
        for j, b in ipairs(line.slots) do
            local e = entries[j]
            if b.entry ~= e then b.missing = nil end
            b.entry = e
            b:SetAttribute("spell", e and (e.cast or e.id) or nil)
            b.icon:SetTexture(e and e.icon or nil)
            if not e then
                b:SetAlpha(0)
                b:EnableMouse(false)
            end
        end
    end
end

local function Label(line)
    if line.unit == "player" then
        line.name:SetText("You")
    else
        -- a name the game keeps to itself goes to the font string as it is
        local ok, name = pcall(UnitName, line.unit)
        if ok then pcall(line.name.SetText, line.name, name) end
    end
end

local function Update()
    if not built then return end
    local fighting = InCombatLockdown()
    for _, line in ipairs(lines) do
        local unit = line.unit
        local any = false
        if UnitExists(unit) then
            -- someone new behind the token: the old answers are not theirs
            local guid = Ask(UnitGUID(unit))
            if guid ~= line.guid then
                line.guid = guid
                for _, b in ipairs(line.slots) do b.missing = nil end
            end
            local away = Ask(UnitIsDeadOrGhost(unit)) == true or Ask(UnitIsVisible(unit)) == false
                or Ask(UnitIsConnected(unit)) == false
            for _, b in ipairs(line.slots) do
                local e = b.entry
                if e then
                    local missing = false
                    if not away then
                        local state = ns.HotBuffState(unit, e)
                        if state == "missing" then
                            missing = true
                        elseif state == nil then
                            missing = b.missing or false   -- the game will not say: the last answer stands
                        end
                    end
                    b.missing = missing
                    b:SetAlpha(missing and 1 or 0)
                    if not fighting then b:EnableMouse(missing) end
                    any = any or missing
                end
            end
            if any then Label(line) end
        end
        line.name:SetAlpha(any and 1 or 0)
    end
end

-- /orbs buffs
function ns.BuffCheckDebug()
    print(("DeckUIForever buff window: %s, built %s, %d buffs of your class, icon %d px, in combat: %s."):format(
        DeckUIForeverOrbsDB.buffCheck and "on" or "off", tostring(built), #entries, Size(), tostring(InCombatLockdown())))
    for j, e in ipairs(entries) do
        print(("  %d. %s (id %s, casts %s), also counts: %s"):format(j, tostring(e.name), tostring(e.id),
            tostring(e.cast or e.id), table.concat(e.names or {}, ", ")))
    end
    if not ns.HotBuffState then return end
    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) then
            local parts = {}
            for _, e in ipairs(entries) do
                local state, read, hidden = ns.HotBuffState(unit, e)
                parts[#parts + 1] = ("%s %s (%d read, %d kept from us)"):format(tostring(e.name),
                    tostring(state or "unknown"), read or 0, hidden or 0)
            end
            print(("  %s: %s"):format(unit, #parts > 0 and table.concat(parts, "; ") or "nothing to check"))
        end
    end
end

oUF:Factory(function()
    if not DeckUIForeverOrbsDB.buffCheck then return end
    D.MakeMovable(holder, "Buff check", DeckUIForeverOrbsDB)

    local function Start()
        Build()
        ApplySpells()
        holder:Show()
        Update()
    end

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("SPELLS_CHANGED")
    ev:RegisterEvent("GROUP_ROSTER_UPDATE")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            -- a /reload in a fight: the frames wait for its end
            if not built then Start() return end
            if pendingSpells then ApplySpells() end
        elseif event == "SPELLS_CHANGED" then
            if built then ApplySpells() end
        end
        Update()
    end)

    if not InCombatLockdown() then Start() end
    C_Timer.NewTicker(TICK, Update)
end)
