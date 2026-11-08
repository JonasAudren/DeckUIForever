local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The scanner: every quest's name from the server, by id
-------------------------------------------------------------------
-- C_QuestLog.RequestLoadQuestByID asks the server for a quest's text;
-- QUEST_DATA_LOAD_RESULT(questID, success) answers, and then the title
-- (GetTitleForQuestID), the objectives (GetQuestObjectives), the tag
-- and the classification can be read for a quest never seen. Done for
-- the ids 1 to scan.max in order, a few a frame, with at most a
-- handful in flight; an id the server never answers is given up after
-- three seconds. The position is saved, so the scan carries on in the
-- next session where it stopped. It pauses in combat and in instances.
--
-- A name alone is already a lot: the compendium can list and search
-- every quest, and "done" is the game's flag. Givers and links come
-- from record.lua as you play, or from Questie when it is there.
-------------------------------------------------------------------
local Scan = {}
ns.Scan = Scan

local PER_TICK  = 2       -- requests per tick
local TICK      = 0.05    -- 40 requests a second
local IN_FLIGHT = 12
local TIMEOUT   = 3
local DEFAULT_MAX = 100000

local running = false
local ticker
local inFlight = {}       -- id -> time asked
local answered, missing = 0, 0   -- this session

local function state()
    local d = DeckUIForeverQuestDataDB
    d.scan = d.scan or { next = 1, max = DEFAULT_MAX, found = 0 }
    return d.scan
end

local function Store(id)
    local title = C_QuestLog.GetTitleForQuestID(id)
    if not title or title == "" then return false end
    local q = ns.Own.Touch(id)
    if not q.n or q.n == "" then q.n = title end
    local tag = C_QuestLog.GetQuestTagInfo(id)
    if tag and tag.tagID and not q.t then q.t = tag.tagID end
    if not q.o then
        local list = {}
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
            if o.text and o.text ~= "" then list[#list + 1] = o.text:sub(1, 200) end
        end
        if #list > 0 then q.o = list end
    end
    local okR, repeatable = pcall(C_QuestLog.IsRepeatableQuest, id)
    if okR and repeatable then q.d = true end
    -- the level, if the game answers it for a quest not in the log (to be
    -- seen in Forever; the gossip lists and the log fill it otherwise)
    if not q.l or q.l == 0 then
        local okL, level = pcall(C_QuestLog.GetQuestDifficultyLevel, id)
        if okL and type(level) == "number" and ns.Plain(level) and level > 0 then q.l = level end
    end
    return true
end

local function Paused()
    return InCombatLockdown() or IsInInstance()
end

local function Tick()
    local s = state()
    local now = GetTime()
    -- answers that never came
    for id, at in pairs(inFlight) do
        if now - at > TIMEOUT then
            inFlight[id] = nil
            missing = missing + 1
        end
    end
    if Paused() then return end
    local count = 0
    for _ in pairs(inFlight) do count = count + 1 end
    local sent = 0
    while sent < PER_TICK and count < IN_FLIGHT and s.next <= s.max do
        local id = s.next
        s.next = s.next + 1
        -- already named: no need to ask
        local known = ns.Own.Quest(id)
        if not (known and known.n and known.n ~= "") then
            local ok = pcall(C_QuestLog.RequestLoadQuestByID, id)
            if ok then
                inFlight[id] = now
                count = count + 1
                sent = sent + 1
            end
        end
    end
    if s.next > s.max and count == 0 then
        Scan.Stop()
        s.done = true
        ns.Print(("scan finished: %d quests named in all."):format(s.found or 0))
    end
end

local function OnResult(_, questID, success)
    if not inFlight[questID] then return end
    inFlight[questID] = nil
    if success and Store(questID) then
        answered = answered + 1
        state().found = (state().found or 0) + 1
    else
        missing = missing + 1
    end
end

function Scan.Start()
    if running then return end
    local s = state()
    if s.done and s.next > s.max then
        ns.Print("the scan is finished. /questing scan reset starts it over.")
        return
    end
    running = true
    ticker = C_Timer.NewTicker(TICK, Tick)
    ns.Print(("scan running from id %d to %d. It pauses in combat and instances, and carries on next session. /questing scan stop halts it."):format(s.next, s.max))
end

function Scan.Stop()
    if ticker then ticker:Cancel() ticker = nil end
    running = false
    wipe(inFlight)
end

function Scan.Reset()
    Scan.Stop()
    local s = state()
    s.next, s.done = 1, nil
    ns.Print("scan position reset to id 1.")
end

function Scan.Running() return running end

-- next id, last id, quests named in all, running, finished
function Scan.Info()
    local s = state()
    return s.next, s.max, s.found or 0, running, s.done == true
end

function Scan.Status()
    local s = state()
    return ("scan %s: at id %d of %d, %d quests named in all (this session %d answered, %d missing)"):format(
        running and "running" or (s.done and "finished" or "stopped"), s.next, s.max, s.found or 0, answered, missing)
end

function ns.InitScan()
    ns.On("QUEST_DATA_LOAD_RESULT", OnResult)
end
