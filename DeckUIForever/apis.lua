local D = DeckUIForever

-------------------------------------------------------------------
-- /df apis: what this game hands out (2026-11-21)
-------------------------------------------------------------------
-- Blizzard's API documentation is one for all games, so a function in it
-- need not exist in Forever. Before a module is built on one of these
-- (swing timer, loss of control, breath timers, threat, durability,
-- death recap, the encounter timeline, loot history, the combat log),
-- this prints what is really there: the function, the event, and the
-- answer of the "is it available" calls. Nothing is changed.
--
-- The lines are also kept in DeckUIForeverDB.apiProbe, so they can be
-- read from the SavedVariables after a /reload instead of being copied
-- from the chat.
-------------------------------------------------------------------
local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local function Show(v)
    if Secret(v) then return "hidden by the game" end
    if type(v) == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "table (" .. n .. ")"
    end
    return tostring(v)
end

-- "C_SwingTimer.IsTargetWithinSwingRange" -> the function, or nil
local function Find(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

local function Event(name)
    if not (C_EventUtils and C_EventUtils.IsEventValid) then return "?" end
    local ok, valid = pcall(C_EventUtils.IsEventValid, name)
    return ok and (valid and "yes" or "no") or "?"
end

-- what a call answers, every return value, or the error
local function Call(path, ...)
    local fn = Find(path)
    if type(fn) ~= "function" then return "missing" end
    local out = { pcall(fn, ...) }
    if not out[1] then return "error: " .. tostring(out[2]) end
    if #out == 1 then return "nothing" end
    local parts = {}
    for i = 2, math.min(#out, 6) do parts[#parts + 1] = Show(out[i]) end
    return table.concat(parts, ", ")
end

local function Has(path) return type(Find(path)) == "function" and "yes" or "no" end

-- { title, lines = { { label, value } ... } }, built when asked
local function Probe()
    local swing = Enum and Enum.PlayerSwingType
    local firstSwing
    if type(swing) == "table" then
        for _, v in pairs(swing) do
            if firstSwing == nil or v < firstSwing then firstSwing = v end
        end
    end
    return {
        { "Swing timer", {
            { "C_SwingTimer.EnableRangeCheck", Has("C_SwingTimer.EnableRangeCheck") },
            { "IsTargetWithinSwingRange(first type)", firstSwing ~= nil
                and Call("C_SwingTimer.IsTargetWithinSwingRange", firstSwing) or "no Enum.PlayerSwingType" },
            { "event PLAYER_SWING", Event("PLAYER_SWING") },
            { "event PLAYER_SWING_RANGE_UPDATE", Event("PLAYER_SWING_RANGE_UPDATE") },
            { "UnitAttackSpeed(player)", Call("UnitAttackSpeed", "player") },
        } },
        { "Loss of control", {
            { "GetActiveLossOfControlDataCount()", Call("C_LossOfControl.GetActiveLossOfControlDataCount") },
            { "GetActiveLossOfControlDataCountByUnit(player)", Call("C_LossOfControl.GetActiveLossOfControlDataCountByUnit", "player") },
            { "event LOSS_OF_CONTROL_ADDED", Event("LOSS_OF_CONTROL_ADDED") },
            { "event PLAYER_CONTROL_LOST", Event("PLAYER_CONTROL_LOST") },
        } },
        { "Diminishing returns", {
            { "C_SpellDiminish.IsSystemSupported()", Call("C_SpellDiminish.IsSystemSupported") },
            { "GetAllSpellDiminishCategories()", Call("C_SpellDiminish.GetAllSpellDiminishCategories") },
        } },
        { "Breath and other mirror timers", {
            { "GetMirrorTimerInfo(1)", Call("GetMirrorTimerInfo", 1) },
            { "GetMirrorTimerProgress(BREATH)", Call("GetMirrorTimerProgress", "BREATH") },
            { "event MIRROR_TIMER_START", Event("MIRROR_TIMER_START") },
        } },
        { "Threat", {
            { "UnitDetailedThreatSituation(player, target)", Call("UnitDetailedThreatSituation", "player", "target") },
            { "UnitThreatSituation(player)", Call("UnitThreatSituation", "player") },
            { "event UNIT_THREAT_LIST_UPDATE", Event("UNIT_THREAT_LIST_UPDATE") },
        } },
        { "Durability and supplies", {
            { "GetInventoryItemDurability(chest)", Call("GetInventoryItemDurability", 5) },
            { "GetInventoryItemDurability(main hand)", Call("GetInventoryItemDurability", 16) },
            { "GetInventoryItemCount(player, ammo slot)", Call("GetInventoryItemCount", "player", 0) },
            { "C_Item.GetItemCount(hearthstone)", Call("C_Item.GetItemCount", 6948) },
            { "event UPDATE_INVENTORY_DURABILITY", Event("UPDATE_INVENTORY_DURABILITY") },
        } },
        { "Death recap", {
            { "C_DeathRecap.HasRecapEvents()", Call("C_DeathRecap.HasRecapEvents") },
            { "C_DeathRecap.GetRecapEvents", Has("C_DeathRecap.GetRecapEvents") },
            { "DeathRecap_HasEvents (old)", Has("DeathRecap_HasEvents") },
        } },
        { "Encounter timeline and warnings", {
            { "C_EncounterTimeline.IsFeatureAvailable()", Call("C_EncounterTimeline.IsFeatureAvailable") },
            { "C_EncounterTimeline.IsFeatureEnabled()", Call("C_EncounterTimeline.IsFeatureEnabled") },
            { "C_EncounterWarnings.IsFeatureAvailable()", Call("C_EncounterWarnings.IsFeatureAvailable") },
            { "event ENCOUNTER_START", Event("ENCOUNTER_START") },
        } },
        { "Loot history", {
            { "C_LootHistory.GetAllEncounterInfos()", Call("C_LootHistory.GetAllEncounterInfos") },
            { "event LOOT_HISTORY_UPDATE_DROP", Event("LOOT_HISTORY_UPDATE_DROP") },
        } },
        { "Cooldown viewer", {
            { "C_CooldownViewer.IsCooldownViewerAvailable()", Call("C_CooldownViewer.IsCooldownViewerAvailable") },
        } },
        { "Combat log", {
            { "C_CombatLog.IsCombatLogRestricted()", Call("C_CombatLog.IsCombatLogRestricted") },
            { "CombatLogGetCurrentEventInfo", Has("CombatLogGetCurrentEventInfo") },
            { "event COMBAT_LOG_EVENT_UNFILTERED", Event("COMBAT_LOG_EVENT_UNFILTERED") },
        } },
        { "Already in use, for comparison", {
            { "UnitGetIncomingHeals(player)", Call("UnitGetIncomingHeals", "player") },
            { "GetTotemInfo(1)", Call("GetTotemInfo", 1) },
            { "C_DamageMeter", type(C_DamageMeter) == "table" and "yes" or "no" },
        } },
    }
end

function D.PrintApis()
    local lines = {}
    local function Out(text)
        lines[#lines + 1] = text
        print(text)
    end
    local version, build, _, toc = GetBuildInfo()
    Out(("DeckUIForever apis: game %s (%s), interface %s"):format(tostring(version), tostring(build), tostring(toc)))
    for _, group in ipairs(Probe()) do
        Out("  " .. group[1])
        for _, line in ipairs(group[2]) do
            Out(("    %s: %s"):format(line[1], tostring(line[2])))
        end
    end
    DeckUIForeverDB.apiProbe = lines
    Out("  Kept for the next /reload (DeckUIForeverDB.apiProbe).")
end
