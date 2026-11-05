local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Talent group bar for World of Warcraft: Forever (DECKUIFOREVER_BERICHT.md, phase 3)
-------------------------------------------------------------------
-- DeckUI's Mists variant (core_mists.lua), taken over as it is: Forever
-- has no specializations either, but dual talents from level 40 at the
-- trainer - up to two talent groups per character. One round button per
-- group; a click activates it, the call Blizzard's own Camelot talent
-- frame makes from plain Lua (C_SpecializationInfo.SetActiveSpecGroup,
-- Blizzard_PlayerSpells/Camelot/ClassTalents, 1.60.1), a cast of a few
-- seconds, not in combat. GetActiveSpecGroup answered 1 in the probe of
-- 2026-11-05; GetNumSpecGroups is global. Not yet tested in game.
-------------------------------------------------------------------
local SIZE, GAP = 36, 6
local UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"

local bar = CreateFrame("Frame", "DeckSpecBar", UIParent)
bar:SetSize(SIZE, SIZE)
bar.defaultPoint = { "CENTER", UIParent, "CENTER", 0, -200 }
bar:SetPoint(unpack(bar.defaultPoint))
ns.bar = bar

ns.buttons = {}

-- Forever has no specialization inside a talent group (the probe's
-- GetSpecialization was nil), so a button shows the class with the
-- group's number instead of a spec icon
local CLASS = select(2, UnitClass("player"))

local function MakeButton(group)
    local b = CreateFrame("Button", "DeckSpecButton" .. group, bar)
    b:SetSize(SIZE, SIZE)
    b:SetPoint("LEFT", (group - 1) * (SIZE + GAP), 0)

    local mask = D.RoundMask(b)

    local ring = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetSize(SIZE + 6, SIZE + 6)
    ring:SetPoint("CENTER")
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(0.25, 0.25, 0.25, 1)
    b.ring = ring

    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    -- the class, from the circle sheet every client has
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    tex:SetTexCoord(unpack(CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[CLASS] or { 0, 1, 0, 1 }))
    tex:AddMaskTexture(mask)
    b.icon = tex

    local num = b:CreateFontString(nil, "OVERLAY")
    num:SetFont(D.FONT, 12, "OUTLINE")
    num:SetPoint("BOTTOMRIGHT", -3, 2)
    num:SetText(group)

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8x8")
    hl:SetVertexColor(1, 1, 1, 0.2)
    hl:SetBlendMode("ADD")
    hl:AddMaskTexture(mask)

    b.group = group

    b:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            print("DeckUIForever Spec: not possible in combat.")
            return
        end
        if C_SpecializationInfo.GetActiveSpecGroup(false, false) ~= self.group then
            C_SpecializationInfo.SetActiveSpecGroup(self.group)
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.group == 1 and "Primary talents" or "Secondary talents")
        local set = ns.GroupSet(self.group)
        if set then GameTooltip:AddLine("Gear: " .. set, 0.8, 0.8, 0.8, true) end
        if C_SpecializationInfo.GetActiveSpecGroup(false, false) ~= self.group then
            GameTooltip:AddLine("Click to switch (a short cast, not in combat).", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-------------------------------------------------------------------
-- Gear per talent group
-------------------------------------------------------------------
-- Owner's wish (2026-10-27, in Mists): switching the talent group puts on
-- the gear that goes with it. The equipment manager has sets but does not
-- swap them on a group change by itself, so DeckUIForever does: per character, a set name per group
-- (DeckUIForeverSpecDB.groupSets["Name-Realm"][group], by name - IDs are the
-- manager's own), chosen on the Spec page; on ACTIVE_TALENT_GROUP_CHANGED
-- the set is put on with C_EquipmentSet.UseEquipmentSet - the manager's
-- own call, the one its "Equip" button makes. A group switch cannot
-- happen in combat, so neither does the swap.
local function CharKey() return UnitName("player") .. "-" .. GetRealmName() end

function ns.GroupSet(group, name)
    DeckUIForeverSpecDB.groupSets = DeckUIForeverSpecDB.groupSets or {}
    local mine = DeckUIForeverSpecDB.groupSets[CharKey()] or {}
    DeckUIForeverSpecDB.groupSets[CharKey()] = mine
    if name ~= nil then mine[group] = name ~= "NONE" and name or nil end
    return mine[group]
end

-- "NONE" first, then the character's sets by name
function ns.SetNames(into)
    into = into or {}
    wipe(into)
    into[1] = "NONE"
    local names = {}
    for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
        local name = C_EquipmentSet.GetEquipmentSetInfo(id)
        if name then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do into[#into + 1] = name end
    return into
end

local function EquipGroupSet()
    local group = C_SpecializationInfo.GetActiveSpecGroup(false, false)
    local name = group and ns.GroupSet(group)
    if not name or InCombatLockdown() then return end
    local id = C_EquipmentSet.GetEquipmentSetID(name)
    if not id then
        print(("DeckUIForever Spec: the equipment set \"%s\" no longer exists - choose another on the Spec page."):format(name))
        return
    end
    C_EquipmentSet.UseEquipmentSet(id)
    print(("DeckUIForever Spec: put on \"%s\"."):format(name))
end

function ns.UpdateActive()
    local active = C_SpecializationInfo.GetActiveSpecGroup(false, false)
    for group, b in ipairs(ns.buttons) do
        local on = group == active
        b.ring:SetVertexColor(on and 0.9 or 0.25, on and 0.75 or 0.25, on and 0.2 or 0.25, 1)
        b.icon:SetDesaturated(not on)
    end
end

-- dual spec is learned at a trainer, mid-session: the second button
-- comes when the count changes
local function Build()
    local n = math.max(1, GetNumSpecGroups(false) or 1)
    bar:SetSize(n * SIZE + (n - 1) * GAP, SIZE)
    for group = 1, n do
        if not ns.buttons[group] then ns.buttons[group] = MakeButton(group) end
        ns.buttons[group]:Show()
    end
    for group = n + 1, #ns.buttons do ns.buttons[group]:Hide() end
    ns.UpdateActive()
end

function ns.SetBarShown(state)
    DeckUIForeverSpecDB.showBar = state
    bar:SetShown(state)
end

ns.HINT = "One round icon per talent group (dual talents, from level 40 at your trainer); click one to switch (not in combat). The active one has a gold ring. /spec toggles the bar, /df unlock moves it."

-------------------------------------------------------------------
-- Startup (normal login AND load on demand via the menu)
-------------------------------------------------------------------
local ready = false

local function Init()
    DeckUIForeverSpecDB = DeckUIForeverSpecDB or {}
    if DeckUIForeverSpecDB.showBar == nil then DeckUIForeverSpecDB.showBar = true end
    Build()
    D.MakeMovable(bar, "Spec bar", DeckUIForeverSpecDB)
    bar:SetShown(DeckUIForeverSpecDB.showBar)
    ready = true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ev:RegisterEvent("PLAYER_TALENT_UPDATE")
ev:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        Init()
    elseif not ready then
        return
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
        return
    else
        Build()
        -- a moment later: the group's spells and the swap settle first
        if event == "ACTIVE_TALENT_GROUP_CHANGED" then C_Timer.After(0.5, EquipGroupSet) end
    end
end)

if IsLoggedIn() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    ev:RegisterEvent("PLAYER_LOGIN")
end

SLASH_DECKSPEC1 = "/spec"
SLASH_DECKSPEC2 = "/qs"
SlashCmdList.DECKSPEC = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "config" then
        D.ToggleConfig("Spec")
    else
        ns.SetBarShown(not bar:IsShown())
    end
end
