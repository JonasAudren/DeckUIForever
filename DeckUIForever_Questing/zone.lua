local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The tracker follows the zone, and the level in the title
-------------------------------------------------------------------
-- Entering a zone: every quest of the log with an objective on this map
-- (C_QuestLog.GetQuestsOnMap) is tracked, and - if asked - the others
-- are untracked, but never the navigation target. Only the watch list is
-- touched, which both our tracker and Blizzard's read, so it works with
-- either on show. The map's quest marks arrive a moment after the zone
-- change, so the pass runs a second later and again on QUEST_POI_UPDATE
-- shortly after.
--
-- "[12] Title": the Quests module asks D.DecorateQuestTitle for every
-- entry it draws (quests.lua); the level and the tag letter go in front.
-- Blizzard's own tracker and the quest log are not touched: a hook on
-- the map's quest list runs tainted into its pins.
-------------------------------------------------------------------
local pending

local function Watched(questID)
    local t = C_QuestLog.GetQuestWatchType(questID)
    return t ~= nil
end

function ns.TrackZone(byHand)
    local d = ns.db()
    if not (byHand or d.zoneTrack) then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local onMap = {}
    for _, q in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
        if q.questID then onMap[q.questID] = true end
    end
    local super = C_SuperTrack.GetSuperTrackedQuestID()
    local added, removed = 0, 0
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isTask and not info.isBounty and not info.isHidden then
            local id = info.questID
            if onMap[id] then
                if not Watched(id) and C_QuestLog.AddQuestWatch(id) then added = added + 1 end
            elseif (byHand or d.zoneUntrack) and Watched(id) and id ~= super then
                C_QuestLog.RemoveQuestWatch(id)
                removed = removed + 1
            end
        end
    end
    if byHand then
        ns.Print(("tracking this zone: %d added, %d removed."):format(added, removed))
    end
end

local function Later(delay)
    if pending then pending:Cancel() end
    pending = C_Timer.NewTimer(delay, function()
        pending = nil
        ns.TrackZone(false)
    end)
end

-------------------------------------------------------------------
-- "[12+] Title" in the Quests module's tracker
-------------------------------------------------------------------
local SUFFIX = { [1] = "+", [81] = "D", [62] = "R", [88] = "R", [89] = "R", [41] = "P" }

function D.DecorateQuestTitle(questID, title)
    if not (ns.db() and ns.db().titleLevels) or not title then return title end
    local level = C_QuestLog.GetQuestDifficultyLevel(questID)
    if not level or not ns.Plain(level) or level <= 0 then return title end
    local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
    local suffix = tagInfo and SUFFIX[tagInfo.tagID] or ""
    local c = GetQuestDifficultyColor(level)
    return ("|cff%02x%02x%02x[%d%s]|r %s"):format(c.r * 255, c.g * 255, c.b * 255, level, suffix, title)
end

-- the tracker redraws on the watch list's event; re-sorting fires it
function ns.RedrawTracker()
    pcall(C_QuestLog.SortQuestWatches)
end

function ns.InitZone()
    ns.On("ZONE_CHANGED_NEW_AREA", function() Later(1) end)
    ns.On("PLAYER_ENTERING_WORLD", function() Later(3) end)
    ns.On("QUEST_POI_UPDATE", function()
        -- only shortly after a zone change, when the marks arrive late
        if pending then Later(0.5) end
    end)
end
