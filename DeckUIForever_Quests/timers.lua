local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Quest timers (DECKUIFOREVER_BERICHT.md, phase 3)
-------------------------------------------------------------------
-- Classic's timed quests are back in Forever, and Blizzard draws them in
-- Blizzard_QuestTimer's QuestTimerFrame - a child of ObjectiveTrackerFrame,
-- which goes out of sight with Blizzard's tracker (core.lua). So the same
-- data is drawn here: C_QuestLog.GetQuestTimers() lists the running
-- timers as { questID, questTimer (seconds left) }, read once a second
-- while one runs, the way Blizzard's frame counts them down in its
-- OnUpdate (Blizzard_QuestTimer.lua, 1.60.1). Not yet tested in game.
-------------------------------------------------------------------
local WARN = { 1, 0.3, 0.3 }

local function Title(questID)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    return title and title ~= "" and title or ("Quest " .. tostring(questID))
end

ns.RegisterSection("timers", {
    title = QUEST_TIMERS or "Quest timers",
    order = 5,
    Collect = function()
        ns.ticking.timers = nil
        local entries = {}
        if not (C_QuestLog.GetQuestTimers) then return entries end
        for _, info in ipairs(C_QuestLog.GetQuestTimers() or {}) do
            local left = info.questTimer or 0
            entries[#entries + 1] = {
                key = "timer" .. tostring(info.questID),
                title = Title(info.questID),
                lines = { { text = SecondsToTime(left), color = left < 60 and WARN or nil } },
                OnClick = function(_, button)
                    if button == "LeftButton" and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
                        C_SuperTrack.SetSuperTrackedQuestID(info.questID)
                    end
                end,
            }
        end
        if #entries > 0 then ns.ticking.timers = true end
        return entries
    end,
})

local ev = CreateFrame("Frame")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() ns.RequestUpdate("timers") end)
