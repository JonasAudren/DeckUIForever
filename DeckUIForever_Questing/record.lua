local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Our own quest data: recorded while you play
-------------------------------------------------------------------
-- The shape is data_forever.lua's. What ships there is the base; what
-- this character sees lands on top in DeckUIForeverQuestDataDB (account
-- wide), and ns.Own answers from both, the recorded entry first.
--
-- Recorded: at a gossip or greeting NPC every quest it offers and every
-- quest it takes back (the lists come with ids and levels); at
-- QUEST_DETAIL the quest, its giver (the NPC with name and your
-- position, since you stand next to it; an item; or a spot on the map
-- when no unit stands there, a game object), its objectives text and
-- the class it was offered to; at QUEST_ACCEPTED the level and tag from
-- the log; at QUEST_TURNED_IN the finisher. A quest offered or taken
-- right after a hand-in at the same NPC is that quest's follow-up: the
-- link goes both ways (p: what came before, x: what it opened).
--
-- The game's quest lines (C_QuestLine, Forever has retail's API) are
-- harvested per map when the map is entered or the compendium opens: a
-- line's quests in order become links, and a quest's place on the map
-- becomes a spot giver when no NPC is known. Whether Forever fills the
-- lines for Classic quests is for the game to show (/questing record
-- says how many lines it found).
-------------------------------------------------------------------
local Own = {}
ns.Own = Own

local shipped = ns.SHIPPED or { quests = {}, npcs = {}, lines = {} }

local function db() return DeckUIForeverQuestDataDB end
local allCache
local EMPTY = {}

-------------------------------------------------------------------
-- Reading and writing
-------------------------------------------------------------------
local function Deep(t)
    local c = {}
    for k, v in pairs(t) do c[k] = type(v) == "table" and Deep(v) or v end
    return c
end

function Own.Quest(id)
    return db().quests[id] or shipped.quests[id]
end

-- the recorded entry, made from the shipped one if there is one
function Own.Touch(id)
    local q = db().quests[id]
    if not q then
        local base = shipped.quests[id]
        q = base and Deep(base) or {}
        db().quests[id] = q
        if allCache then allCache[id] = true end
    end
    return q
end

function Own.NPC(id)
    return db().npcs[id] or shipped.npcs[id]
end

function Own.TouchNPC(id)
    local n = db().npcs[id]
    if not n then
        local base = shipped.npcs[id]
        n = base and Deep(base) or {}
        db().npcs[id] = n
    end
    return n
end

function Own.Line(id)
    return db().lines[id] or shipped.lines[id]
end

-- the import's tables (import.lua): objects as quest givers, item names
-- the game lacks, and every zone-or-sort key with name, category and map
function Own.Object(id)
    return db().objs[id] or (shipped.objs or EMPTY)[id]
end

function Own.TouchObject(id)
    local o = db().objs[id]
    if not o then
        local base = (shipped.objs or EMPTY)[id]
        o = base and Deep(base) or {}
        db().objs[id] = o
    end
    return o
end

function Own.Item(id)
    return db().items[id] or (shipped.items or EMPTY)[id]
end

function Own.Sort(id)
    return db().sorts[id] or (shipped.sorts or EMPTY)[id]
end

-- every zone-or-sort key known, the recorded entry over the shipped one
local sortsCache
function Own.Sorts()
    if sortsCache then return sortsCache end
    sortsCache = {}
    for id, s in pairs(shipped.sorts or EMPTY) do sortsCache[id] = s end
    for id, s in pairs(db().sorts) do sortsCache[id] = s end
    return sortsCache
end

function Own.ImportInfo()
    return db().imported
end

-- after the import wrote or cleared whole tables
function Own.Reload()
    allCache, sortsCache = nil, nil
end

-- every quest id known to our own data, as a set
function Own.All()
    if allCache then return allCache end
    allCache = {}
    for id in pairs(shipped.quests) do allCache[id] = true end
    for id in pairs(db().quests) do allCache[id] = true end
    return allCache
end

function Own.Lines()
    local list = {}
    local seen = {}
    for _, src in ipairs({ db().lines, shipped.lines }) do
        for id, line in pairs(src) do
            if not seen[id] then
                seen[id] = true
                list[#list + 1] = { id = id, name = line.n, mapID = line.m, quests = line.q or {} }
            end
        end
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end

local function Add(list, value)
    for _, v in ipairs(list) do if v == value then return list end end
    list[#list + 1] = value
    return list
end

-- a link: before opened after
function Own.Link(before, after)
    if not (before and after) or before == after or before <= 0 or after <= 0 then return end
    local a, b = Own.Touch(before), Own.Touch(after)
    a.x = Add(a.x or {}, after)
    b.p = Add(b.p or {}, before)
end

-------------------------------------------------------------------
-- Where you stand
-------------------------------------------------------------------
local function PlayerSpot()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return mapID end
    local x, y = pos:GetXY()
    if not ns.Plain(x, y) or (x == 0 and y == 0) then return mapID end
    return mapID, x * 100, y * 100
end

-- the giver key for the unit in front of you: "n<id>" for an NPC (and
-- the NPC's record gets a name and a position), "i<id>" for an item, a
-- spot "s<map>:<x>:<y>" when no unit is there (a game object)
local function GiverKey(unit, itemID)
    if itemID and itemID > 0 then return "i" .. itemID end
    local npcID = ns.NpcID(unit)
    local mapID, x, y = PlayerSpot()
    if npcID then
        local n = Own.TouchNPC(npcID)
        if not n.n or n.n == "" then n.n = UnitName(unit) end
        if not n.m and mapID and x then n.m, n.x, n.y = mapID, math.floor(x * 10 + 0.5) / 10, math.floor(y * 10 + 0.5) / 10 end
        return "n" .. npcID
    end
    if mapID and x then
        return ("s%d:%.1f:%.1f"):format(mapID, x, y)
    end
    return nil
end

local playerClass = select(2, UnitClass("player"))

local function Recording()
    return ns.db() and ns.db().record ~= false
end

-- what every sighting adds: the title, the level, the map, the class
local function Seen(id, title, level, repeatable)
    local q = Own.Touch(id)
    if title and title ~= "" and (not q.n or q.n == "") then q.n = title end
    if level and ns.Plain(level) and level > 0 and (not q.l or q.l == 0) then q.l = level end
    if repeatable then q.d = true end
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID and not q.m then q.m = mapID end
    q.c = q.c or {}
    q.c[playerClass] = true
    return q
end

local function Offered(id, title, level, repeatable, key)
    local q = Seen(id, title, level, repeatable)
    if key then q.g = Add(q.g or {}, key) end
end

local function TakenBack(id, key)
    local q = Own.Touch(id)
    if key then q.f = Add(q.f or {}, key) end
end

-------------------------------------------------------------------
-- The events
-------------------------------------------------------------------
-- the last quest handed in: the next quest offered at that NPC follows it
local lastTurnIn   -- { id, key, at }
local FOLLOW_WINDOW = 20

local function Follows(newID, key)
    if lastTurnIn and lastTurnIn.id ~= newID and lastTurnIn.key == key and GetTime() - lastTurnIn.at < FOLLOW_WINDOW then
        Own.Link(lastTurnIn.id, newID)
    end
end

local function OnGossip()
    if not Recording() then return end
    local key = GiverKey("npc")
    for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
        if q.questID then
            Offered(q.questID, q.title, q.questLevel, q.repeatable, key)
            Follows(q.questID, key)
        end
    end
    for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
        if q.questID then TakenBack(q.questID, key) end
    end
end

local function OnGreeting()
    if not Recording() then return end
    local key = GiverKey("npc")
    for i = 1, GetNumAvailableQuests() do
        local ok, isTrivial, frequency, isRepeatable, _, questID = pcall(GetAvailableQuestInfo, i)
        local title = GetAvailableTitle(i)
        if ok and type(questID) == "number" and questID > 0 then
            Offered(questID, title, nil, isRepeatable or (frequency and frequency > 0), key)
            Follows(questID, key)
        end
    end
    for i = 1, GetNumActiveQuests() do
        local ok, questID = pcall(GetActiveQuestID, i)
        if ok and type(questID) == "number" and questID > 0 then TakenBack(questID, key) end
    end
end

local function OnDetail(_, questStartItemID)
    if not Recording() then return end
    local id = GetQuestID()
    if not id or id == 0 then return end
    local key = GiverKey("questnpc", questStartItemID)
    if UnitIsPlayer("questnpc") then key = nil end   -- shared: the giver is elsewhere
    local q = Seen(id, GetTitleText(), nil, nil)
    if key then
        q.g = Add(q.g or {}, key)
        Follows(id, key)
    end
    local objectives = GetObjectiveText and GetObjectiveText()
    if objectives and objectives ~= "" and not q.o then q.o = { objectives:sub(1, 200) } end
end

-- the log knows the level and the tag
local function OnAccepted(_, questID)
    if not Recording() or not questID then return end
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local info = logIndex and C_QuestLog.GetInfo(logIndex)
    local q = Seen(questID, info and info.title, info and info.difficultyLevel or info and info.level, info and info.frequency and info.frequency > 0)
    local tag = C_QuestLog.GetQuestTagInfo(questID)
    if tag and tag.tagID then q.t = tag.tagID end
    if not q.o then
        local list = {}
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
            if o.text and o.text ~= "" then list[#list + 1] = o.text:sub(1, 200) end
        end
        if #list > 0 then q.o = list end
    end
    -- taken right after a hand-in at the same NPC, without a detail page (auto accept)
    if UnitExists("questnpc") and not UnitIsPlayer("questnpc") then Follows(questID, GiverKey("questnpc")) end
end

local function OnTurnedIn(_, questID)
    if not Recording() or not questID then return end
    local key = UnitExists("questnpc") and GiverKey("questnpc") or nil
    TakenBack(questID, key)
    lastTurnIn = { id = questID, key = key, at = GetTime() }
end

-------------------------------------------------------------------
-- The game's quest lines
-------------------------------------------------------------------
local harvested = {}   -- mapID -> true this session

function Own.HarvestLines(mapID, force)
    if not (C_QuestLine and mapID) or (harvested[mapID] and not force) then return 0 end
    harvested[mapID] = true
    pcall(C_QuestLine.RequestQuestLinesForMap, mapID)
    local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
    if not ok or type(lines) ~= "table" then return 0 end
    -- Blizzard's map adds the quests a map always shows (QuestOfferDataProvider)
    local okF, forced = pcall(C_QuestLine.GetForceVisibleQuests, mapID)
    for _, questID in ipairs(okF and type(forced) == "table" and forced or {}) do
        local okI, info = pcall(C_QuestLine.GetQuestLineInfo, questID, mapID)
        if okI and type(info) == "table" and info.questLineID then lines[#lines + 1] = info end
    end
    local count = 0
    for _, entry in ipairs(lines) do
        local lineID = entry.questLineID
        if lineID then
            count = count + 1
            local okQ, ids = pcall(C_QuestLine.GetQuestLineQuests, lineID)
            ids = okQ and type(ids) == "table" and ids or {}
            local line = db().lines[lineID] or {}
            db().lines[lineID] = line
            line.n = entry.questLineName or line.n
            line.m = line.m or mapID
            if #ids > 0 then line.q = ids end
            for i, id in ipairs(ids) do
                local q = Own.Touch(id)
                if not q.m then q.m = entry.startMapID or mapID end
                if i > 1 then Own.Link(ids[i - 1], id) end
            end
            -- the entry's quest stands at x, y on this map
            if entry.questID and entry.x and entry.y and ns.Plain(entry.x, entry.y) then
                local q = Own.Touch(entry.questID)
                if not q.n or q.n == "" then q.n = entry.questName end
                local hasNPC = false
                for _, g in ipairs(q.g or {}) do if g:sub(1, 1) == "n" then hasNPC = true end end
                if not hasNPC then
                    q.g = Add(q.g or {}, ("s%d:%.1f:%.1f"):format(mapID, entry.x * 100, entry.y * 100))
                end
            end
        end
    end
    return count
end

local function HarvestHere()
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then Own.HarvestLines(mapID) end
end

-------------------------------------------------------------------
-- Counting, startup
-------------------------------------------------------------------
function Own.Stats()
    local quests, named, placed, linked, npcs, lines = 0, 0, 0, 0, 0, 0
    for id in pairs(Own.All()) do
        quests = quests + 1
        local q = Own.Quest(id)
        if q.n and q.n ~= "" then named = named + 1 end
        if q.g and #q.g > 0 then placed = placed + 1 end
        if (q.p and #q.p > 0) or (q.x and #q.x > 0) then linked = linked + 1 end
    end
    for _ in pairs(db().npcs) do npcs = npcs + 1 end
    for _ in pairs(shipped.npcs) do npcs = npcs + 1 end
    for _ in pairs(db().lines) do lines = lines + 1 end
    return quests, named, placed, linked, npcs, lines
end

function Own.PrintStats()
    local quests, named, placed, linked, npcs, lines = Own.Stats()
    print(("  own data: %d quests (%d named, %d with a giver, %d linked), %d NPCs, %d quest lines; recording %s"):format(
        quests, named, placed, linked, npcs, lines, Recording() and "on" or "off"))
    local recorded, imported = 0, 0
    for _, q in pairs(db().quests) do
        recorded = recorded + 1
        if q.i then imported = imported + 1 end
    end
    print(("  of them on this account: %d quests (%d imported from Questie) - the file is WTF\\Account\\<account>\\SavedVariables\\DeckUIForever_Questing.lua"):format(recorded, imported))
end

function ns.InitRecord()
    DeckUIForeverQuestDataDB = DeckUIForeverQuestDataDB or {}
    local d = DeckUIForeverQuestDataDB
    d.v = d.v or 1
    d.quests = d.quests or {}
    d.npcs = d.npcs or {}
    d.lines = d.lines or {}
    d.objs = d.objs or {}     -- the import's (import.lua)
    d.items = d.items or {}
    d.sorts = d.sorts or {}
    ns.On("GOSSIP_SHOW", OnGossip)
    ns.On("QUEST_GREETING", OnGreeting)
    ns.On("QUEST_DETAIL", OnDetail)
    ns.On("QUEST_ACCEPTED", OnAccepted)
    ns.On("QUEST_TURNED_IN", OnTurnedIn)
    ns.On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(2, HarvestHere) end)
    ns.On("PLAYER_ENTERING_WORLD", function() C_Timer.After(5, HarvestHere) end)
end
