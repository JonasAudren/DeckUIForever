local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Your debuffs: what each class keeps up on an enemy, and the round icon
-------------------------------------------------------------------
-- What is left of the debuff window (2026-10-28 to 1.5.6). The window is
-- gone since 2026-11-26 (owner: "jetzt bauen wir Debuffs um, will das
-- Fenster auch entfernen und mit dem Mobs-am-Kampf-beteiligt-Fenster
-- verschmelzen"): every row of the enemy list carries your debuffs now
-- (enemies.lua, option enemyDots). This file keeps what others stand on:
--   * the round-icon pieces - ns.RoundIcon, ns.IconRim, ns.AuraIconButton
--     - which partyheal.lua, padheal.lua, buffcheck.lua and enemies.lua
--     build their icons from;
--   * the lists per class (LISTS) with every rank's ID (RankIDs), read by
--     ns.DotRebuild and handed out by ns.DotEntries;
--   * the exclusion: what the enemy list shows leaves the target frame's
--     own debuff icons (ns.ApplyDotExclusion, ns.targetDebuffs).
--
-- Why engine widgets: Forever keeps an enemy's auras from addons in a
-- fight - the index scan throws, the lookup by name finds nothing, even
-- for your own Shadow Word: Pain (owner's fight, 2026-11-05). So no Lua of
-- ours reads them. An icon is Blizzard's own aura button inside a
-- CustomAuraContainer with one slot filtered to the debuff's spell IDs;
-- the engine fills it in a fight too. A button only exists while the aura
-- does, so the "missing" picture is a layer of ours underneath.
-------------------------------------------------------------------
local GOLD = { 1, 0.82, 0.3 }
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function Secret(v) return issecretvalue and issecretvalue(v) end

-------------------------------------------------------------------
-- Round aura icons: the enemy list's debuffs, the party list's heals, Deck Heal, the buff window
-------------------------------------------------------------------
-- a round icon: the texture behind the portrait mask, as the orbs
function ns.RoundIcon(tex)
    local mask = tex:GetParent():CreateMaskTexture()
    mask:SetTexture(D.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    return tex
end

-- a disc a little larger than the parent, behind the icon: shows as a rim
function ns.IconRim(parent, r, g, b, a)
    local tex = parent:CreateTexture(nil, "BORDER")
    tex:SetTexture(WHITE)
    tex:SetVertexColor(r, g, b, a or 1)
    tex:SetPoint("TOPLEFT", -2, 2)
    tex:SetPoint("BOTTOMRIGHT", 2, -2)
    return ns.RoundIcon(tex)
end

-- The engine's button as a round icon, made once and handed every piece
-- it fills: the icon, the cooldown (its swipe is the round mask, so the
-- clock closes as a circle, reversed as Blizzard's buff frame runs it -
-- the dark part grows as the aura runs out - with the time in the
-- middle), the stack count and the gold rim of the pandemic window.
-- Every piece is anchored to the button before it is handed over, so it
-- follows the button's size; afterwards it is the engine's ("forbidden
-- object" on a touch). No script of ours on the button, not even a hook
-- (the engine's SetShown with a secret then throws).
function ns.AuraIconButton(button, size)
    local late = ns.IconRim(button, GOLD[1], GOLD[2], GOLD[3], 1)
    late:Hide()
    local icon = ns.RoundIcon(button:CreateTexture(nil, "ARTWORK"))
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cd:SetAllPoints(button)
    cd:SetSwipeTexture(D.MASK)
    cd:SetSwipeColor(0, 0, 0, 0.75)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetReverse(true)
    cd:SetHideCountdownNumbers(false)
    if cd.SetCountdownFont then cd:SetCountdownFont(ns.CountdownFont(size)) end
    -- the count above the swipe: on the cooldown frame, the topmost piece
    local count = cd:CreateFontString(nil, "OVERLAY")
    count:SetFont(ns.FONT, math.max(7, math.floor(size * 0.4)), "OUTLINE")
    count:SetJustifyH("RIGHT")
    count:SetPoint("BOTTOMRIGHT", 1, -1)
    button:SetIcon(icon)
    button:SetDurationCooldown(cd)
    button:SetApplicationCount(count, {})
    button:AddPandemicRegion(late)
    -- the tooltip is the engine's own aura tooltip (AuraButton's OnEnter)
    return button
end

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

-- What the enemy list shows as icons leaves the target frame's own debuff
-- icons (owner 2026-10-28: once a debuff has its place, it is not an icon
-- too) - while the list carries them and the switch says so
-- (enemyDotsExclude, on). Candidate filters are live, so no reload.
local NO_EXCLUDE = {}
function ns.ApplyDotExclusion()
    local filters = NO_EXCLUDE
    if ns.EnemyDotsOn and ns.EnemyDotsOn() and DeckUIForeverOrbsDB.enemyDotsExclude ~= false then
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

-- for enemies.lua: read the list again; the list and the set of its IDs
function ns.DotRebuild() Rebuild() end
function ns.DotEntries() return entries, allIDs end

-------------------------------------------------------------------
-- /orbs dots: the class, its list, what you know, each slot's IDs
-------------------------------------------------------------------
function ns.DotDebug()
    Rebuild()
    print(("DeckUIForever debuffs: class %s, %d known, on the enemy list %s, in combat: %s."):format(
        tostring(ListKey()), #entries, ns.EnemyDotsOn and ns.EnemyDotsOn() and "on" or "off (Enemies page)",
        tostring(UnitAffectingCombat("player"))))
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
    if ns.EnemyDebug then ns.EnemyDebug() end
    ns.DotCoverage()
end

-- Each debuff of the list against Blizzard's Cooldown Manager: whether
-- Blizzard's data knows the spell at all (and in which category), and
-- whether it sits in a tracked-buff bar now. Part of /orbs dots and of
-- /df cooldowns (D.CooldownReport).
function ns.DotCoverage()
    if not (D.CooldownManagerAvailable and D.CooldownManagerAvailable()) then
        print("  Cooldown Manager: not in this client")
        return
    end
    if #entries == 0 then Rebuild() end
    if #entries == 0 then
        print("  Cooldown Manager: no debuffs of this class known")
        return
    end
    print("  your debuffs and Blizzard's Cooldown Manager:")
    local fight = InCombatLockdown()
    local offered = D.CooldownManagerOffers()
    for _, e in ipairs(entries) do
        local viewer = D.CooldownManagerShows(e.name)
        print(("    %s: %s, %s"):format(e.name,
            fight and "offered ? (not read in combat)" or (offered[e.name] and ("offered by Blizzard (" .. offered[e.name] .. ")") or "not offered by Blizzard"),
            viewer and ("in " .. viewer) or "not in a buff bar"))
    end
end
D.CooldownReport = ns.DotCoverage
