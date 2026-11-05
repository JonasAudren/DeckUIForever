local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Forever: what a character's week holds (after core.lua)
-------------------------------------------------------------------
-- core.lua keeps the snapshot machinery and asks ns.COLLECTORS for the
-- parts; these are Forever's, after DeckUI's collect_mists.lua. Lockouts
-- are core's own collector (GetSavedInstanceInfo, documented in Forever);
-- the rest:
--  - renown: the Legacy reward track and the PvP rank, through
--    C_MajorFactions as Blizzard_LegacyRewardTrack reads them;
--  - currencies: every currency in the character's list, not a table of
--    IDs - nobody knows Forever's yet. A collapsed header hides its
--    entries from the list, so what the player folded away stays away;
--  - reputation: every faction with standing beyond neutral-at-zero, in
--    the game's own order (C_Reputation.GetFactionDataByIndex);
--  - dailies and weeklies are learned from the quest log the way DeckUI's
--    Mists port learns them, through retail's C_QuestLog.GetInfo: a daily
--    is remembered account-wide with its title and quest log header.
-- Not yet tested in game (2026-11-05).
-------------------------------------------------------------------
local WEEKLY = Enum.QuestFrequency and Enum.QuestFrequency.Weekly
local DAILY = Enum.QuestFrequency and Enum.QuestFrequency.Daily

local function Plain(v) return not (issecretvalue and issecretvalue(v)) end

-- Weeklies as in retail, and dailies too (owner's wish, 2026-10-27, in
-- Mists: Classic lives on its dailies). Which dailies the game offers
-- changes every day, so there is no "of how many" - only what was done.
function ns.LearnWeeklies()
    local known = DeckUIForeverWeekDB.weeklies
    local dailies = DeckUIForeverWeekDB.dailies
    local header
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            header = info.title
        elseif info and info.questID and not ns.KNOWN_QUESTS[info.questID] then
            if WEEKLY and info.frequency == WEEKLY then
                known[info.questID] = info.title or known[info.questID] or ("Quest " .. info.questID)
            elseif DAILY and info.frequency == DAILY then
                dailies[info.questID] = { title = info.title or ("Quest " .. info.questID), group = header or "" }
            end
        end
    end
end

-- the learned dailies this character has done today, counted by group
local function Dailies()
    local done, total = {}, 0
    for questID, q in pairs(DeckUIForeverWeekDB.dailies) do
        if ns.Done(questID) then
            done[q.group] = (done[q.group] or 0) + 1
            total = total + 1
        end
    end
    return { total = total, groups = done,
             resetAt = time() + (C_DateAndTime.GetSecondsUntilDailyReset() or 0) }
end

-- the renown tracks: level of max, and the reputation into the next level
local function Renown()
    local list = {}
    for _, track in ipairs(ns.RENOWN) do
        local data = C_MajorFactions.GetMajorFactionData(track.id)
        if data and Plain(data.renownLevel) then
            list[#list + 1] = {
                key = track.key, name = data.name or track.name, unlocked = data.isUnlocked,
                level = data.renownLevel or 0, max = data.maxLevel or 0,
                earned = data.renownReputationEarned or 0, threshold = data.renownLevelThreshold or 0,
            }
        end
    end
    return list
end

-- every currency in the list, headers left out, in the list's order
local function Currencies()
    local list = {}
    local n = C_CurrencyInfo.GetCurrencyListSize() or 0
    for i = 1, n do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and not info.isHeader and info.name and info.name ~= "" then
            -- the list entry names its currency (CurrencyInfo.currencyID,
            -- documented in 1.60.1); the link as a fallback
            local id = info.currencyID
            if not id then
                local link = C_CurrencyInfo.GetCurrencyListLink(i)
                id = link and tonumber(link:match("currency:(%d+)"))
            end
            local c = id and ns.Currency(id)
            if c then list[#list + 1] = c end
        end
    end
    return list
end

-- every faction with standing, the way the reputation pane lists them
local function Reputations()
    local list = {}
    local neutral = FACTION_STANDING_LABEL4
    local n = C_Reputation.GetNumFactions and C_Reputation.GetNumFactions() or 0
    for i = 1, n do
        local f = C_Reputation.GetFactionDataByIndex(i)
        if f and not f.isHeader and f.factionID then
            local s = D.FactionStatus and D.FactionStatus(f.factionID)
            if s and not (s.standing == neutral and s.cur == 0) then
                list[#list + 1] = s
            end
        end
    end
    return list
end

ns.COLLECTORS = {
    locks = ns.Locks, renown = Renown, currencies = Currencies,
    weekliesDone = ns.Weeklies, dailies = Dailies, reputations = Reputations,
}

local ev = CreateFrame("Frame")
for _, e in ipairs({ "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "MAJOR_FACTION_UNLOCKED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function()
    if DeckUIForeverWeekDB then ns.RequestSnapshot() end
end)
