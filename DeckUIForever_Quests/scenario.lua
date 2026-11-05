local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Scenarios and dungeons
-------------------------------------------------------------------
-- DeckUI's file without the delve header, the Mythic+ keystone and the
-- challenge mode medals: Forever has none of them (Blizzard_ChallengesUI
-- and the delve UI are not loaded there, C_ChallengeMode.* missing in
-- the probe of 2026-11-05). What stays is retail's C_Scenario path.
-- The same sources as Blizzard's ScenarioObjectiveTracker (12.1.0,
-- read 2026-09-29): the stage through the undocumented C_Scenario.GetInfo
-- and GetStepInfo, the criteria through C_ScenarioInfo.GetCriteriaInfo.
-- A criterion flagged isWeightedProgress carries its progress in
-- `quantity` as a 0-100 percentage (enemy forces work like that); a
-- whole weighted step reports it in GetStepInfo's weightedProgress.
--
-- GetStepInfo returns, in order: name, description, numCriteria,
-- stepFailed, isBonusStep, isForCurrentStepOnly, shouldShowBonusObjective,
-- numSpells, allSpellInfo, weightedProgress, rewardQuestID, widgetSetID.
--
-- The docs mark none of this secret. A Mythic+ key is one of the AddOn
-- restriction types, though, so if a number does turn out secret in a
-- key, the section errors - and core.lua shows the error on one line
-- instead of losing the tracker.
-------------------------------------------------------------------
local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- Blizzard hides criteria and spells while this is false (some scenarios
-- reveal their objectives only later); it arrives with an event.
local showCriteria = true

local function CriterionLine(c)
    local text = c.description
    if not c.isWeightedProgress and not c.isFormatted and c.totalQuantity and c.totalQuantity > 0 then
        text = ("%d/%d %s"):format(c.quantity, c.totalQuantity, c.description)
    end
    local line = { text = text, done = c.completed }
    if c.failed then line.color = { 1, 0.3, 0.3 } end
    if c.isWeightedProgress and not c.completed then
        line.bar = (c.quantity or 0) / 100
    end
    if c.duration and c.duration > 0 and c.elapsed and c.elapsed <= c.duration then
        line.text = line.text .. "  (" .. Clock(c.duration - c.elapsed) .. ")"
        ns.ticking.scenario = true
    end
    return line
end

local function CriteriaLines()
    local lines = {}
    local _, stageDescription, numCriteria, _, _, _, _, _, _, weightedProgress = C_Scenario.GetStepInfo()
    if weightedProgress then
        -- the whole step is one bar (Blizzard shows the description and the bar)
        lines[#lines + 1] = { text = stageDescription, bar = weightedProgress / 100 }
        return lines
    end
    for i = 1, numCriteria or 0 do
        local c = C_ScenarioInfo.GetCriteriaInfo(i)
        if c then lines[#lines + 1] = CriterionLine(c) end
    end
    return lines
end

-- 514 and 252: the fixed sets Blizzard's scenario module shows above and
-- below its blocks (its XML, 12.1.0)
local SCENARIO_TOP_SET, SCENARIO_BOTTOM_SET = 514, 252

-------------------------------------------------------------------
-- Scenario spells: secure spell buttons, one entry per spell
-------------------------------------------------------------------
local function SpellEntries(allSpellInfo)
    local entries, seen = {}, {}
    local function Add(spellID, name, icon)
        if not spellID or seen[spellID] then return end
        seen[spellID] = true
        if not (name and icon) then
            local info = C_Spell.GetSpellInfo(spellID)
            name = name or (info and info.name)
            icon = icon or (info and info.iconID)
        end
        entries[#entries + 1] = {
            key = "spell" .. spellID,
            title = name or ("Spell " .. spellID),
            color = { 0.6, 0.8, 1 },
            secure = { type = "spell", value = spellID, icon = icon },
            OnEnter = function(row)
                GameTooltip:SetOwner(row, "ANCHOR_LEFT")
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:Show()
            end,
        }
    end
    for _, s in ipairs(allSpellInfo or {}) do
        Add(s.spellID, s.spellName or s.name, s.spellIcon or s.icon)
    end
    -- delves: the tiered entrance's active spells
    if C_ScenarioInfo.IsTieredEntranceScenario and C_ScenarioInfo.IsTieredEntranceScenario() then
        for _, spellID in ipairs(C_ScenarioInfo.GetTieredEntranceActiveSpells() or {}) do
            Add(spellID)
        end
    end
    return entries
end

-------------------------------------------------------------------
-- Bonus steps (Blizzard showed these in its bonus objective module)
-------------------------------------------------------------------
local function StepComplete(step)
    local _, _, numCriteria = C_Scenario.GetStepInfo(step)
    for i = 1, numCriteria or 0 do
        local c = C_ScenarioInfo.GetCriteriaInfoByStep(step, i)
        if c and not c.completed then return false end
    end
    return true
end

local function BonusEntries()
    local entries = {}
    -- a step that supersedes another stays hidden until that one is done
    local waitsFor = {}
    for _, pair in ipairs(C_Scenario.GetSupersededObjectives() or {}) do
        local step, superseded = pair[1] or pair.scenarioBonusStepID, pair[2] or pair.supersededBonusStepID
        if step and superseded then waitsFor[step] = superseded end
    end
    for _, step in ipairs(C_Scenario.GetBonusSteps() or {}) do
        local name, description, numCriteria, failed, _, _, shouldShow = C_Scenario.GetStepInfo(step)
        if shouldShow and not (waitsFor[step] and not StepComplete(waitsFor[step])) then
            local lines = {}
            for i = 1, numCriteria or 0 do
                local c = C_ScenarioInfo.GetCriteriaInfoByStep(step, i)
                if c then lines[#lines + 1] = CriterionLine(c) end
            end
            if #lines == 0 and description and description ~= "" then
                lines[1] = { text = description }
            end
            entries[#entries + 1] = {
                key = "bonusstep" .. step,
                title = name,
                color = failed and { 1, 0.3, 0.3 } or { 0.9, 0.75, 0.2 },
                lines = lines,
            }
        end
    end
    return entries
end

-------------------------------------------------------------------
-- The section
-------------------------------------------------------------------
-- the eye on the stage, when Blizzard's tracker would show one
local function FindScenarioGroup(scenarioID)
    if scenarioID and C_LFGList.CanCreateScenarioGroup and C_LFGList.CanCreateScenarioGroup(scenarioID) then
        return { kind = "scenario", id = scenarioID }
    end
    return nil
end

local function Collect()
    ns.ticking.scenario = nil
    local entries = {}
    local function Add(e) if e then entries[#entries + 1] = e end end

    -- the 13th return is the scenario's ID (Blizzard's tracker reads it so)
    local name, currentStage, numStages, _, _, _, _, _, _, _, _, _, scenarioID = C_Scenario.GetInfo()
    if not name or not numStages or numStages == 0 then
        return entries
    end

    if currentStage and currentStage <= numStages then
        local stageName, _, _, _, _, _, _, _, allSpellInfo, _, _, widgetSetID = C_Scenario.GetStepInfo()

        local title = name
        if numStages > 1 then
            title = ("%s - %d/%d %s"):format(name, currentStage, numStages, stageName or "")
        elseif stageName and stageName ~= "" and stageName ~= name then
            title = name .. " - " .. stageName
        end
        -- the scenario's fixed widget sets frame the stage's own lines
        -- (the stage's own set may hold widgets too - bars, texts)
        local lines = ns.WidgetLines("scenario", SCENARIO_TOP_SET)
        ns.WidgetLines("scenario", widgetSetID, lines)
        for _, l in ipairs(showCriteria and CriteriaLines() or {}) do lines[#lines + 1] = l end
        ns.WidgetLines("scenario", SCENARIO_BOTTOM_SET, lines)
        Add({ key = "stage", title = title, lines = lines, findGroup = FindScenarioGroup(scenarioID) })
        if showCriteria then
            for _, e in ipairs(SpellEntries(allSpellInfo)) do Add(e) end
        end
    else
        Add({ key = "stage", title = name, lines = { { text = COMPLETE or "Complete", done = true } } })
    end

    for _, e in ipairs(BonusEntries()) do Add(e) end
    return entries
end

ns.RegisterSection("scenario", {
    title = "Scenario",
    order = 10,
    Collect = Collect,
    Init = function()
        if C_Scenario.ShouldShowCriteria then showCriteria = C_Scenario.ShouldShowCriteria() end
    end,
})

local ev = CreateFrame("Frame")
for _, e in ipairs({
    "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE", "SCENARIO_COMPLETED", "SCENARIO_SPELL_UPDATE",
    "SCENARIO_BONUS_VISIBILITY_UPDATE", "SCENARIO_CRITERIA_SHOW_STATE_UPDATE", "CRITERIA_COMPLETE",
    "WORLD_STATE_TIMER_START", "WORLD_STATE_TIMER_STOP",
}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, arg)
    if event == "SCENARIO_CRITERIA_SHOW_STATE_UPDATE" then showCriteria = arg and true or false end
    ns.RequestUpdate()
end)
