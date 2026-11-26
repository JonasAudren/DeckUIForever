local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The healer's lists: what your class keeps up, heals with and cures with
-------------------------------------------------------------------
-- What is left of hots.lua, the HoT window (1.2.0 to 1.5.6). The window
-- itself is gone since 2026-11-26 (owner: "loese die gemeinsame Logik
-- heraus und entferne das HoT-Fenster"): the party list carries its
-- slots now (partyheal.lua, option partyHeal), and this file is the part
-- three others stand on -
--   partyheal.lua  the slots' list (ns.HotRebuild, ns.HotEntries), a
--                  HoT's time left (ns.HotRemaining), a spell's cooldown
--                  (ns.HotEntryCooldown), the mana regeneration line
--                  (ns.HotRegenAttach, ns.HotRegenUpdate)
--   padheal.lua    Deck Heal's spells (ns.HotLayerSpells, ns.HotLayerIDs),
--                  the highest rank (ns.HotTopRank), the round out of a
--                  fight (ns.HotRoundNext), the dispel filter
--   buffcheck.lua  your castable buffs and whether one is missing
--                  (ns.HotBuffEntries, ns.HotBuffState)
-- The names keep their "Hot": they are what those files call.
--
-- No Lua here reads an aura in a fight and trusts the answer: a slot's
-- HoT is the engine's own aura button (partyheal.lua), BuffState says
-- "don't know" where the game keeps a name from us.
-------------------------------------------------------------------
local DISPEL_FILTER = "HARMFUL|" .. (AuraUtil and AuraUtil.AuraFilters
    and AuraUtil.AuraFilters.RaidPlayerDispellable or "RAID")

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Ask(v) if Secret(v) then return nil end return v end

-- you and your party, for the round out of a fight
local PARTY = { "player", "party1", "party2", "party3", "party4" }
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
               { id = 976, also = { 27683 }, round = false } },   -- Shadow Protection, Prayer of Shadow Protection
    DRUID  = { { id = 1126, also = { 21849 } },    -- Mark of the Wild, Gift of the Wild
               { id = 467, round = false } },      -- Thorns (round = false: not part of Deck Heal's buff round)
    MAGE   = { { id = 1459, also = { 23028 } } },  -- Arcane Intellect, Arcane Brilliance
}

-- hotCastSlots: what a click casts on the member and leaves no aura to
-- watch - the direct heals, the dispels, the resurrection. First ranks;
-- the name casts the highest one you know. need says when the button is
-- there at all (owner 2026-11-10: "Debuff-Knöpfe nur wenn man wirklich
-- etwas debuffen kann und Resurrect nur bei Toten"): "cure" while the
-- member carries a debuff you can remove (types: the kinds this spell
-- takes), "dead" while the member is dead. The heals are always there.
-- power: how much a heal heals next to the class's others, 1 the least -
-- Deck Heal fills its buttons in that order (ns.HotLayerSpells); the
-- order here is the HoT window's.
local MAGIC, CURSE, DISEASE, POISON = "Magic", "Curse", "Disease", "Poison"
local function Cure(id, ...) return { id = id, need = "cure", types = { ... } } end
-- fight: a resurrection for the fight (a long cooldown), not for the round after it
local function Res(id, fight) return { id = id, need = "dead", fight = fight } end
local CASTS = {
    PRIEST  = { { id = 2050, power = 1 }, { id = 2054, power = 3 }, { id = 2060, power = 4 }, { id = 2061, power = 2 },   -- Lesser Heal, Heal, Greater Heal, Flash Heal
                Cure(527, MAGIC), Cure(528, DISEASE), Cure(552, DISEASE),     -- Dispel Magic, Cure Disease, Abolish Disease
                Res(2006) },                                                  -- Resurrection
    DRUID   = { { id = 5185 },                                                -- Healing Touch
                Cure(2782, CURSE), Cure(8946, POISON), Cure(2893, POISON),    -- Remove Curse, Cure Poison, Abolish Poison
                Res(20484, true) },                                                 -- Rebirth
    PALADIN = { { id = 635, power = 2 }, { id = 19750, power = 1 },           -- Holy Light, Flash of Light
                Cure(4987, MAGIC, POISON, DISEASE), Cure(1152, POISON, DISEASE),   -- Cleanse, Purify
                { id = 633, layer = false }, Res(7328) },                     -- Lay on Hands (never a Deck Heal default), Redemption
    SHAMAN  = { { id = 331, power = 2 }, { id = 8004, power = 1 }, { id = 1064, power = 3 },   -- Healing Wave, Lesser Healing Wave, Chain Heal
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
    local exclude = ns.PartyHealOn() and DeckUIForeverOrbsDB.hotExclude ~= false
    for _, entry in ipairs(ns.targetBuffs or {}) do
        pcall(entry.container.SetAuraGroupCandidateFilters, entry.container, entry.key, Merged(entry.base, exclude))
    end
end

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

-- The slots of a line, in this order (owner 2026-11-17: "zuerst Instant
-- Spells, dann Heals, dann Debuffer und dann Buffs"): your HoTs and the
-- shield - the instant ones - with the list of your own, then your direct
-- heals, the cures and the resurrection (CASTS keeps that order). kind
-- says how a slot behaves (hot: the engine's aura button; cast: a plain
-- button). The missing buffs are buffcheck.lua's.
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
    do
        for _, e in ipairs(CASTS[ListKey()] or {}) do
            local n = Known(e.id) and SpellName(e.id)
            if n and not seen[n] then
                seen[n] = true
                entries[#entries + 1] = { kind = "cast", name = n, icon = SpellIcon(e.id), id = e.id,
                                          need = e.need, types = e.types }
            end
        end
    end
    -- the missing buffs stood here as slots of kind "buff" until 2026-11-17
    -- (hotBuffSlots); they have a window of their own now, buffcheck.lua,
    -- which asks ns.HotBuffEntries and ns.HotBuffState below. What this file
    -- still does for a "buff" entry is never reached.
    for _, e in ipairs(entries) do e.cast = ns.HotTopRank(e.name, e.id) end
    ns.ApplyHotExclusion()
end

-------------------------------------------------------------------
-- Is a buff on the unit
-------------------------------------------------------------------
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


-------------------------------------------------------------------
-- A HoT's time left, a spell's cooldown
-------------------------------------------------------------------
-- the seconds your HoT has left on the unit, nil when it is not there or
-- the game keeps the time to itself
local function Remaining(unit, e)
    local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, e.name, "HELPFUL|PLAYER")
    if not ok or Secret(data) or data == nil then return nil end
    local expires, duration = Ask(data.expirationTime), Ask(data.duration)
    if not expires or not duration or duration <= 0 then return nil end
    return expires - GetTime()
end

ns.HotRemaining = Remaining   -- partyheal.lua's expiry warning

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

ns.HotEntryCooldown = EntryCooldown   -- partyheal.lua's clocks

-------------------------------------------------------------------
-- Your mana regeneration (hotRegen)
-------------------------------------------------------------------
-- A small line above the window (owner 2026-11-10: "meine aktuelle
-- Manareg ... als Option im HoTs-Fenster"): what you regenerate right now
-- per five seconds, and beside it the other of the two rates
-- GetManaRegen hands out - the full one, and the one that holds for five
-- seconds after a spell that cost mana (Classic's five-second rule). The
-- text is a frame of its own; partyheal.lua hangs it above the party list. Which rate holds is our own clock: the last cast of yours that cost
-- mana (UNIT_SPELLCAST_SUCCEEDED and the spell's cost). A secret rate in a
-- fight leaves the last text standing.
local FSR = 5
local MANA_TYPE = Enum.PowerType and Enum.PowerType.Mana or 0
local lastSpend = 0
local regenBox = CreateFrame("Frame", nil, UIParent)
regenBox:SetSize(1, 1)
regenBox:SetPoint("CENTER")   -- until partyheal.lua hangs it above the list (ns.HotRegenAttach)
local regenText = regenBox:CreateFontString(nil, "OVERLAY")
regenText:SetFont(ns.FONT, 10, "OUTLINE")
regenText:SetJustifyH("LEFT")
regenText:SetWordWrap(false)
regenText:SetPoint("BOTTOMLEFT", regenBox, "BOTTOMLEFT", 4, 3)
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

-- for partyheal.lua: the line hangs above the party list (or the raid)
-- while the heals are there, and is asked to refresh from its tick
local attached = false   -- no line before the party list said where it hangs
function ns.HotRegenAttach(anchor, x, y, scale)
    attached = true
    regenBox:SetScale(scale or 1)
    regenBox:ClearAllPoints()
    regenBox:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", x or 0, y or 0)
    regenText:ClearAllPoints()
    regenText:SetPoint("BOTTOMLEFT", regenBox, "BOTTOMLEFT", 4, 3)
end

local function UpdateRegen()
    if not (attached and DeckUIForeverOrbsDB.hotRegen) or not GetManaRegen then
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

ns.HotRegenUpdate = UpdateRegen

-------------------------------------------------------------------
-- What Deck Heal, the buff window and the party rows ask of this file
-------------------------------------------------------------------
-- The spells Deck Heal casts when the player named none: your HoTs, then
-- your direct heals from the weakest to the strongest (owner 2026-11-12,
-- after the first Deck test: "vom schwächsten zum stärksten, aber immer
-- mit dem höchsten Rang" - a priest's Lesser Heal, Flash Heal, Heal,
-- Greater Heal; CASTS' power, the list's order without it), then your
-- cures. Only what the character knows, each name once in its highest
-- rank, `max` at most.
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
    local heals = {}
    for i, e in ipairs(casts) do
        if not e.need and e.layer ~= false then heals[#heals + 1] = { id = e.id, power = e.power or i, i = i } end
    end
    table.sort(heals, function(a, b)
        if a.power ~= b.power then return a.power < b.power end
        return a.i < b.i
    end)
    for _, e in ipairs(heals) do Take(e.id) end
    for _, e in ipairs(casts) do
        if e.need == "cure" then Take(e.id) end
    end
    return list
end

-- for the buff window (buffcheck.lua): the buffs of your class you know,
-- each with the names that count as it (the group version too) and the
-- highest rank to cast; and the check itself
function ns.HotBuffEntries()
    local list = {}
    for _, e in ipairs(BUFFS[ListKey()] or {}) do
        local n = Known(e.id) and SpellName(e.id)
        if n then
            local names = { n }
            for _, other in ipairs(e.also or {}) do
                local o = SpellName(other)
                if o then names[#names + 1] = o end
            end
            list[#list + 1] = { name = n, icon = SpellIcon(e.id), id = e.id, names = names,
                                cast = ns.HotTopRank(n, e.id) }
        end
    end
    return list
end
ns.HotBuffState = BuffState

-- for Deck Heal's bar: the filter of the debuffs you can remove, and every
-- spell ID (all ranks) of the class's HoTs as a set
ns.HOT_DISPEL_FILTER = DISPEL_FILTER
function ns.HotLayerIDs()
    local ids = {}
    for _, e in ipairs(LISTS[ListKey()] or {}) do
        local name = SpellName(e.id)
        if name then
            for id in pairs(RankIDs(e, name)) do ids[id] = true end
        end
    end
    return ids
end

-- Deck Heal's round out of a fight (owner 2026-11-16: "Buff-Runde ...
-- dasselbe fuer Wiederbeleben nach einem Wipe"): the next thing a member
-- needs - a dead one the class's resurrection, then a living one a buff
-- of BUFFS that the game says is missing (BuffState; "don't know" is not
-- missing). You and party1-4, nobody far away or offline. nil: nothing.
function ns.HotRoundNext()
    local key = ListKey()
    if Ask(UnitIsDeadOrGhost("player")) ~= false then return nil end
    local units = {}
    for _, unit in ipairs(PARTY) do
        if unit == "player" or (UnitExists(unit) and Ask(UnitIsVisible(unit)) == true
            and Ask(UnitIsConnected(unit)) == true) then
            units[#units + 1] = unit
        end
    end
    local function Reach(name, unit)
        if unit == "player" or not (C_Spell and C_Spell.IsSpellInRange) then return true end
        local ok, near = pcall(C_Spell.IsSpellInRange, name, unit)
        return not (ok and not Secret(near) and near == false)
    end
    for _, e in ipairs(CASTS[key] or {}) do
        if e.need == "dead" and not e.fight and Known(e.id) then
            local name = SpellName(e.id)
            for _, unit in ipairs(units) do
                if name and unit ~= "player" and Ask(UnitIsDeadOrGhost(unit)) == true and Reach(name, unit) then
                    return { unit = unit, name = name, icon = SpellIcon(e.id), what = "dead",
                             cast = ns.HotTopRank(name, e.id) }
                end
            end
        end
    end
    for _, e in ipairs(BUFFS[key] or {}) do
        local name = e.round ~= false and Known(e.id) and SpellName(e.id)
        if name then
            local names = { name }
            for _, id in ipairs(e.also or {}) do names[#names + 1] = SpellName(id) end
            for _, unit in ipairs(units) do
                if Ask(UnitIsDeadOrGhost(unit)) == false and Reach(name, unit)
                    and BuffState(unit, { names = names }) == "missing" then
                    return { unit = unit, name = name, icon = SpellIcon(e.id), what = "buff",
                             cast = ns.HotTopRank(name, e.id) }
                end
            end
        end
    end
    return nil
end

-- for partyheal.lua: the slots' list (read again by ns.HotRebuild) and
-- the set of every aura ID in it
function ns.HotRebuild() Rebuild() end
function ns.HotEntries() return entries, allIDs end

-------------------------------------------------------------------
-- /orbs hots: the class, its list, what you know, and the party rows
-------------------------------------------------------------------
function ns.HotDebug()
    print(("DeckUIForever heals: class %s, %d slots, heals on the party list %s, in combat: %s."):format(
        tostring(ListKey()), #entries, ns.PartyHealOn() and "on" or "off (Group page)",
        tostring(UnitAffectingCombat("player"))))
    do
        -- what the game hands out for the regeneration line, raw (per second)
        local full, casting
        if GetManaRegen then full, casting = GetManaRegen() end
        local function Show(v) return Secret(v) and "secret" or tostring(v) end
        print(("  mana regeneration %s: GetManaRegen %s, full %s, after a cast %s, last mana spend %.1f s ago, mana readable %s, last seen: %s"):format(
            DeckUIForeverOrbsDB.hotRegen and "on" or "off", GetManaRegen and "there" or "missing", Show(full), Show(casting),
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
    if ns.PartyHealDebug then ns.PartyHealDebug() end
end
