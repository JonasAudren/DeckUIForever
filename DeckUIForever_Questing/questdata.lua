local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Where the compendium's knowledge comes from
-------------------------------------------------------------------
-- Three sources, read through ns.Data so the window never knows which:
--
-- 1. The game. For any quest id it says whether this character has done
--    it (C_QuestLog.IsQuestFlaggedCompleted), whether it is in the log,
--    its title, tag and objectives once loaded, and the quest lines of a
--    map (C_QuestLine). Always there, and "done" is always its word.
-- 2. Our own data (record.lua, scan.lua, data_forever.lua): what this
--    account has seen at NPCs, what the scanner named, what the quest
--    lines said, and what ships with the module. Ours to keep.
-- 3. Questie's database, when Questie is installed - the Forever build,
--    read 2026-11-07 in Questie/Questie: Database/QuestieDB.lua binds
--    LibQuestieDB (the separate QuestieDB addon), Journey builds its zone
--    groups from ZoneDB.GetZonesWithQuests. Reached through Questie's own
--    module API, every call pcall'd; nothing of its data is copied into
--    this package (Questie is GPL, this addon MIT). It knows every giver,
--    every requirement and every class; the richer answer while it is
--    there, a bonus and not a need.
--
-- A quest's record merges the sources: Questie's fields when it has the
-- quest, our own on top where Questie is silent, the game's title first.
-------------------------------------------------------------------
local Data = { ready = false, source = "none" }
ns.Data = Data

-- Questie's modules, bound once Questie says it has started
local QDB, ZoneDB, Player, l10n, Journey

local function Import(name)
    if not _G.QuestieLoader then return nil end
    local ok, m = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
    return ok and m or nil
end

-- Questie.started is its own word for "done"; but its database and the
-- Journey's zone groups are built well before that word (QuestieInit
-- Stage3), and a late stage may fail on Forever (owner 2026-11-07: "still
-- loading" for minutes), so those two are what we wait for
local function Started()
    if not (_G.Questie and _G.QuestieLoader) then return false end
    if _G.Questie.started == true then return true end
    local q, j = Import("QuestieDB"), Import("QuestieJourney")
    return q ~= nil and type(q.QuestPointers) == "table" and next(q.QuestPointers) ~= nil
        and j ~= nil and type(j.zoneMap) == "table" and next(j.zoneMap) ~= nil
end

local function Bind()
    QDB, ZoneDB, Player, l10n, Journey = Import("QuestieDB"), Import("ZoneDB"), Import("QuestiePlayer"), Import("l10n"), Import("QuestieJourney")
    if QDB and QDB.QueryQuest and QDB.QuestPointers and ZoneDB and Player then
        Data.source = "questie"
        return true
    end
    return false
end

function Data.Ready() return Data.ready end
function Data.HasQuestie() return Data.source == "questie" end

-- what the window says about its sources
function Data.SourceText()
    local quests = ns.Own and select(1, ns.Own.Stats()) or 0
    local own = ("own data: %d quests"):format(quests)
    local info = ns.Own and ns.Own.ImportInfo and ns.Own.ImportInfo()
    if info then own = own .. (" (Questie %s imported %s)"):format(tostring(info.questie), date("%Y-%m-%d", info.at or 0)) end
    if Data.source == "questie" then return own .. ", plus Questie live" end
    if C_AddOns.IsAddOnLoaded("Questie") then return own .. ", Questie still loading" end
    if info then return own end
    return own .. " - scan and play to grow it, or import Questie's data once"
end

local onReady = {}
function Data.OnReady(fn)
    if Data.ready then fn() else onReady[#onReady + 1] = fn end
end

local function BecomeReady()
    Data.ready = true
    local list = onReady
    onReady = {}
    for _, fn in ipairs(list) do fn() end
end

local playerClass = select(2, UnitClass("player"))
local playerRace  = select(2, UnitRace("player"))

-------------------------------------------------------------------
-- Maps and zones
-------------------------------------------------------------------
local mapNames = {}
function Data.MapName(mapID)
    if not mapID then return nil end
    local n = mapNames[mapID]
    if n == nil then
        local info = C_Map.GetMapInfo(mapID)
        n = info and info.name or false
        mapNames[mapID] = n
    end
    return n or nil
end

-- the zone map a map belongs to (itself when it is one), and its continent
local ZONE, CONTINENT, DUNGEON = Enum.UIMapType.Zone, Enum.UIMapType.Continent, Enum.UIMapType.Dungeon
local zoneOf = {}
function Data.ZoneMap(mapID)
    if not mapID then return nil end
    local z = zoneOf[mapID]
    if z ~= nil then return z or nil end
    local id, info = mapID, C_Map.GetMapInfo(mapID)
    local steps = 0
    while info and info.mapType ~= ZONE and info.mapType ~= DUNGEON and info.mapType ~= CONTINENT and info.parentMapID and info.parentMapID > 0 and steps < 8 do
        id = info.parentMapID
        info = C_Map.GetMapInfo(id)
        steps = steps + 1
    end
    z = info and id or false
    zoneOf[mapID] = z
    return z or nil
end

function Data.ContinentName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    local steps = 0
    while info and info.mapType ~= CONTINENT and info.parentMapID and info.parentMapID > 0 and steps < 8 do
        info = C_Map.GetMapInfo(info.parentMapID)
        steps = steps + 1
    end
    return info and info.mapType == CONTINENT and info.name or "Elsewhere"
end

local mapOfArea, areaOfMap = {}, {}

-- Questie's ZoneDB answers while it is there; afterwards the import's
-- table of zones and sorts (which stored the map of every area)
function Data.MapForArea(areaID)
    if not areaID or areaID <= 0 then return nil end
    local m = mapOfArea[areaID]
    if m ~= nil then return m or nil end
    if ZoneDB then
        local ok, mapID = pcall(ZoneDB.GetUiMapIdByAreaId, ZoneDB, areaID)
        m = ok and mapID or false
    else
        local s = ns.Own and ns.Own.Sort and ns.Own.Sort(areaID)
        m = s and s.m or false
    end
    mapOfArea[areaID] = m
    return m or nil
end

function Data.AreaForMap(mapID)
    if not mapID then return nil end
    local a = areaOfMap[mapID]
    if a ~= nil then return a or nil end
    if ZoneDB then
        local ok, areaID = pcall(ZoneDB.GetAreaIdByUiMapId, ZoneDB, mapID)
        a = ok and areaID or false
    else
        a = false
        for id, s in pairs((ns.Own and ns.Own.Sorts and ns.Own.Sorts()) or {}) do
            if id > 0 and s.m == mapID then a = id break end
        end
    end
    areaOfMap[mapID] = a
    return a or nil
end

-- Questie's sort categories (negative zoneOrSort) by name, from its lookups
local sortNames
local function SortNames()
    if sortNames then return sortNames end
    sortNames = {}
    for _, group in pairs((l10n and l10n.zoneCategoryLookup) or {}) do
        for id, name in pairs(group) do
            if type(id) == "number" and id < 0 then sortNames[id] = name end
        end
    end
    return sortNames
end

local zoneNames = {}
-- a Questie area or sort id as a name: the game's map name where there is a map
function Data.ZoneName(areaOrSort)
    if not areaOrSort or areaOrSort == 0 then return "Somewhere" end
    local cached = zoneNames[areaOrSort]
    if cached then return cached end
    local name
    if areaOrSort < 0 then
        name = SortNames()[areaOrSort]
    else
        name = Data.MapName(Data.MapForArea(areaOrSort))
        if not name and l10n and l10n.zoneLookup then
            for _, cont in pairs(l10n.zoneLookup) do
                if cont[areaOrSort] then name = cont[areaOrSort] break end
            end
        end
    end
    if not name and ns.Own and ns.Own.Sort then   -- the import's table of zones and sorts
        local s = ns.Own.Sort(areaOrSort)
        name = s and s.n
    end
    name = name or ("Area " .. areaOrSort)
    zoneNames[areaOrSort] = name
    return name
end

-------------------------------------------------------------------
-- Quests
-------------------------------------------------------------------
-- the fields read from Questie, in one query per quest; the order here is
-- the order of the packed answer
local QUEST_KEYS = {
    "name", "questLevel", "requiredLevel", "requiredMaxLevel", "zoneOrSort",
    "startedBy", "finishedBy", "requiredRaces", "requiredClasses",
    "preQuestSingle", "preQuestGroup", "nextQuestInChain", "exclusiveTo",
    "childQuests", "parentQuest", "specialFlags", "questFlags", "objectivesText",
    "breadcrumbForQuestId", "requiredSkill",
}
local QUEST_FLAGS_DAILY = 4096

-- Questie's class and race masks as sets of the game's tokens (what
-- UnitClass / UnitRace return), nil when every classic class or race is
-- in - the shape our own data keeps (k, y) and the import writes
local CLASS_BITS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, DEATHKNIGHT = 32, SHAMAN = 64,
    MAGE = 128, WARLOCK = 256, MONK = 512, DRUID = 1024, DEMONHUNTER = 2048, EVOKER = 4096 }
local RACE_BITS = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128,
    Goblin = 256, BloodElf = 512, Draenei = 1024, Worgen = 2097152, Pandaren = 8388608 }
local RACE_TOKENS = { HUMAN = "Human", ORC = "Orc", DWARF = "Dwarf", NIGHT_ELF = "NightElf", UNDEAD = "Scourge",
    TAUREN = "Tauren", GNOME = "Gnome", TROLL = "Troll", GOBLIN = "Goblin", BLOOD_ELF = "BloodElf", DRAENEI = "Draenei",
    WORGEN = "Worgen", PANDAREN = "Pandaren" }
local CLASSIC_CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true }
local CLASSIC_RACES = { Human = true, Orc = true, Dwarf = true, NightElf = true, Scourge = true, Tauren = true, Gnome = true, Troll = true }

local classBits, raceBits
local function MaskSet(mask, bits, classic)
    if type(mask) ~= "number" or mask <= 0 then return nil end
    local set, all = {}, true
    for token, bit_ in pairs(bits) do
        if bit.band(mask, bit_) ~= 0 then set[token] = true end
    end
    for token in pairs(classic) do if not set[token] then all = false end end
    if all or not next(set) then return nil end
    return set
end

function Data.ClassSet(mask)
    if not classBits then
        classBits = CLASS_BITS
        if QDB and type(QDB.classKeys) == "table" then
            classBits = {}
            for name, v in pairs(QDB.classKeys) do if type(v) == "number" and v > 0 then classBits[name:gsub("_", "")] = v end end
        end
    end
    return MaskSet(mask, classBits, CLASSIC_CLASSES)
end

function Data.RaceSet(mask)
    if not raceBits then
        raceBits = RACE_BITS
        if QDB and type(QDB.raceKeys) == "table" then
            raceBits = {}
            for name, v in pairs(QDB.raceKeys) do
                if RACE_TOKENS[name] and type(v) == "number" and v > 0 then raceBits[RACE_TOKENS[name]] = v end
            end
        end
    end
    return MaskSet(mask, raceBits, CLASSIC_RACES)
end

local questieQuests = {}   -- id -> Questie's part, built on first ask (false: Questie has none)

local function Copy(t)
    if type(t) ~= "table" then return {} end
    local c = {}
    for i, v in ipairs(t) do c[i] = v end
    return c
end

local function FromQuestie(id)
    local q = questieQuests[id]
    if q ~= nil then return q or nil end
    if not QDB then questieQuests[id] = false return nil end
    local ok, raw = pcall(QDB.QueryQuest, id, QUEST_KEYS)
    if not ok or type(raw) ~= "table" then questieQuests[id] = false return nil end
    local startedBy, finishedBy = raw[6] or {}, raw[7] or {}
    local special, flags = raw[16] or 0, raw[17] or 0
    q = {
        name          = raw[1],
        level         = raw[2] or 0,
        requiredLevel = raw[3] or 0,
        maxLevel      = raw[4] or 0,
        zone          = raw[5] or 0,
        startNPCs     = Copy(startedBy[1]),
        startObjects  = Copy(startedBy[2]),
        startItems    = Copy(startedBy[3]),
        finishNPCs    = Copy(finishedBy[1]),
        finishObjects = Copy(finishedBy[2]),
        requiredRaces = raw[8],
        requiredClasses = raw[9],
        preSingle     = Copy(raw[10]),   -- any one of these done
        preGroup      = Copy(raw[11]),   -- all of these done
        nextInChain   = raw[12] or 0,
        exclusiveTo   = Copy(raw[13]),
        childQuests   = Copy(raw[14]),
        parentQuest   = raw[15] or 0,
        repeatable    = bit.band(special, 1) ~= 0,
        daily         = (flags % (2 * QUEST_FLAGS_DAILY)) >= QUEST_FLAGS_DAILY,
        objectives    = Copy(raw[18]),
        breadcrumbFor = raw[19] or 0,
        requiredSkill = raw[20],
    }
    -- a scaling quest (-1) is the player's level, as Questie reads it
    if q.level == -1 then q.level = math.max(q.requiredLevel, UnitLevel("player")) end
    q.classOnly = Data.ClassSet(q.requiredClasses)
    q.raceOnly  = Data.RaceSet(q.requiredRaces)
    questieQuests[id] = q
    return q
end
Data.QuestieQuest = FromQuestie   -- import.lua reads Questie's part through this

local EMPTY = {}

function Data.QuestieQuestIDs()
    return (QDB and QDB.QuestPointers) or EMPTY
end

-- the tag Questie corrected, if it has one for the quest
function Data.QuestieTag(id)
    if QDB and QDB.GetQuestTagInfo then
        local ok, tagID = pcall(QDB.GetQuestTagInfo, id)
        if ok and type(tagID) == "number" and tagID > 0 then return tagID end
    end
    return nil
end

-- the Journey category of a zone-or-sort key (1 EK, 2 Kalimdor, 8 Zephras
-- Isle, 9 Dungeons, 10 Battlegrounds, 11 Class, 12 Professions, 13 Events)
local sortCategory
function Data.SortCategory(areaOrSort)
    if not sortCategory then
        sortCategory = {}
        for cat, group in pairs((l10n and l10n.zoneCategoryLookup) or {}) do
            for id in pairs(group) do if type(id) == "number" then sortCategory[id] = cat end end
        end
    end
    return sortCategory[areaOrSort]
end

-- the merged record; our own part is read fresh every time (it grows
-- while you play), Questie's is cached
function Data.Quest(id)
    local qq = FromQuestie(id)
    local own = ns.Own and ns.Own.Quest(id)
    if not (qq or own) then return nil end
    local q = {
        id = id,
        questie = qq ~= nil,
        own = own,
        name          = (qq and qq.name) or (own and own.n) or ("Quest " .. id),
        level         = (qq and qq.level > 0 and qq.level) or (own and own.l) or 0,
        requiredLevel = (qq and qq.requiredLevel) or (own and own.r) or 0,
        maxLevel      = (qq and qq.maxLevel) or (own and own.h) or 0,
        zone          = (qq and qq.zone) or (own and own.s) or 0,
        mapID         = own and own.m or nil,
        imported      = (own and own.i == true) or false,
        classOnly     = (qq and qq.classOnly) or (own and own.k) or nil,
        raceOnly      = (qq and qq.raceOnly) or (own and own.y) or nil,
        startNPCs     = qq and qq.startNPCs or EMPTY,
        startObjects  = qq and qq.startObjects or EMPTY,
        startItems    = qq and qq.startItems or EMPTY,
        finishNPCs    = qq and qq.finishNPCs or EMPTY,
        finishObjects = qq and qq.finishObjects or EMPTY,
        requiredRaces = qq and qq.requiredRaces,
        requiredClasses = qq and qq.requiredClasses,
        preSingle     = (qq and qq.preSingle) or (own and own.a) or EMPTY,
        preGroup      = (qq and qq.preGroup) or (own and own.p) or EMPTY,
        nextInChain   = (qq and qq.nextInChain) or (own and own.x and own.x[1]) or 0,
        exclusiveTo   = (qq and qq.exclusiveTo) or (own and own.e) or EMPTY,
        childQuests   = qq and qq.childQuests or EMPTY,
        parentQuest   = (qq and qq.parentQuest) or (own and own.v) or 0,
        repeatable    = (qq and qq.repeatable) or (own and own.d) or false,
        daily         = qq and qq.daily or false,
        objectives    = (qq and #qq.objectives > 0 and qq.objectives) or (own and own.o) or EMPTY,
        breadcrumbFor = (qq and qq.breadcrumbFor) or (own and own.b) or 0,
        requiredSkill = qq and qq.requiredSkill,
        tag           = own and own.t,
    }
    if q.zone ~= 0 then
        q.zoneName = Data.ZoneName(q.zone)
    elseif q.mapID then
        q.zoneName = Data.MapName(Data.ZoneMap(q.mapID)) or Data.MapName(q.mapID)
    end
    return q
end

-- every quest id any source knows, as a set (built fresh: our own data grows)
function Data.AllQuestIDs()
    local set = {}
    for id in pairs(QDB and QDB.QuestPointers or EMPTY) do set[id] = true end
    if ns.Own then for id in pairs(ns.Own.All()) do set[id] = true end end
    return set
end

-- the game's title when it has one (localised), else Questie's, else ours
function Data.Title(id)
    local title = C_QuestLog.GetTitleForQuestID(id)
    if title and title ~= "" then return title end
    local q = Data.Quest(id)
    return q and q.name or ("Quest " .. id)
end

-- the tag: elite, dungeon, raid, pvp, group ... (Questie corrects
-- Blizzard's wrong tags, so ask it first)
function Data.Tag(id)
    if QDB and QDB.GetQuestTagInfo then
        local ok, tagID, tagName = pcall(QDB.GetQuestTagInfo, id)
        if ok and tagID then return tagID, tagName end
    end
    local own = ns.Own and ns.Own.Quest(id)
    if own and own.i and own.t then return own.t end   -- the import carries Questie's corrected tag
    local info = C_QuestLog.GetQuestTagInfo(id)
    if info and info.tagID then return info.tagID, info.tagName end
    if own and own.t then return own.t end
end

-- "+" elite, "D" dungeon, "R" raid, "P" pvp: the quest log's letters
local TAG_SUFFIX = { [1] = "+", [81] = "D", [62] = "R", [88] = "R", [89] = "R", [41] = "P", [83] = "++", [84] = "", [21] = "" }
function Data.Suffix(id)
    local tagID, tagName = Data.Tag(id)
    if not tagID then return "" end
    local s = TAG_SUFFIX[tagID]
    if s then return s end
    return tagName and tagName:sub(1, 1) or ""
end

function Data.Completed(id)
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
    return ok and done == true
end

function Data.InLog(id)
    return C_QuestLog.IsOnQuest(id) == true
end

function Data.ForPlayer(q)
    if not q then return true end
    if q.questie and Player then
        local okR, race = pcall(Player.HasRequiredRace, q.requiredRaces)
        local okC, class = pcall(Player.HasRequiredClass, q.requiredClasses)
        return (not okR or race ~= false) and (not okC or class ~= false)
    end
    -- our own data: the import's restrictions, or a class quest seen only by other classes
    if q.classOnly and not q.classOnly[playerClass] then return false end
    if q.raceOnly and not q.raceOnly[playerRace] then return false end
    local own = q.own
    if own and own.c and own.t == 21 and not own.c[playerClass] then return false end
    return true
end

function Data.Trivial(q)
    if not q then return false end
    if q.questie and QDB and QDB.IsTrivial then
        local ok, t = pcall(QDB.IsTrivial, q.level)
        if ok then return t == true end
    end
    if q.level > 0 then
        local okR, range = pcall(C_QuestLog.GetTrivialRange)
        return UnitLevel("player") - q.level > ((okR and range) or 10)
    end
    return false
end

-- before: the quests that open it; after: the quests it opens - from
-- both sources, for the chains
function Data.Links(id)
    local before, after, seenB, seenA = {}, {}, {}, {}
    local function B(v) v = math.abs(v) if v > 0 and not seenB[v] then seenB[v] = true before[#before + 1] = v end end
    local function A(v) if v > 0 and not seenA[v] then seenA[v] = true after[#after + 1] = v end end
    local qq = FromQuestie(id)
    if qq then
        for _, p in ipairs(qq.preSingle) do B(p) end
        for _, p in ipairs(qq.preGroup) do B(p) end
        if qq.nextInChain > 0 then A(qq.nextInChain) end
    end
    local own = ns.Own and ns.Own.Quest(id)
    if own then
        for _, p in ipairs(own.p or EMPTY) do B(p) end
        for _, p in ipairs(own.a or EMPTY) do B(p) end
        for _, n in ipairs(own.x or EMPTY) do A(n) end
    end
    return before, after
end

-------------------------------------------------------------------
-- The state of a quest for this character
-------------------------------------------------------------------
-- done, log, available, locked (something is missing), blocked (not
-- available any more, or not now), foreign (another class or race),
-- unknown (a name and nothing else). With Questie its IsDoableVerbose
-- does the reasoning - it knows the breadcrumbs, the exclusive groups,
-- the professions, the events - and its state code is mapped onto ours;
-- its brief text is the reason. Without it, our own links and sightings.
local LOCKED = {
    NO_PREQUESTSINGLE = true, NO_PREQUESTGROUP = true, LEVEL_TOO_LOW = true, MISSING_REPUTATION = true,
    PROFESSION_SKILL = true, PROFESSION_RANK = true, PARENT_INACTIVE = true, PARENT_ACTIVE = true,
    SPELL_MISSING = true, BREADCRUMB_ACTIVE = true, ENABLING_QUEST_MISSING = true, DISABLED_BY = true,
    ARENA_RATING = true, MISSING_ACHIEVEMENT = true,
}
local FOREIGN = { WRONG_RACE = true, WRONG_CLASS = true }
local DONE = { COMPLETED = true, EXCLUSIVE_COMPLETED = true }

local stateNames   -- code -> name, from Questie's enum
local function StateName(code)
    if not stateNames then
        stateNames = {}
        for name, value in pairs((QDB and QDB.DoableStates) or {}) do stateNames[value] = name end
    end
    return stateNames[code]
end

Data.STATE_ORDER = { "log", "available", "locked", "done", "blocked", "foreign", "unknown" }
Data.STATE_TITLES = {
    log = "In your log", available = "Available", locked = "Something missing", done = "Done",
    blocked = "Not available", foreign = "Another class or race", unknown = "Known by name",
}

-- Questie's brief reads "Unavailable: Missing prequest"; the part after
-- the colon is what the line needs
function Data.Reason(text)
    if type(text) ~= "string" then return nil end
    local after = text:match(":%s*(.+)$")
    return after or text
end

-- state, reason (text or nil)
function Data.State(id)
    if Data.Completed(id) then return "done" end
    if Data.InLog(id) then return "log" end
    local q = Data.Quest(id)
    if not q then return "unknown" end
    if not Data.ForPlayer(q) then return "foreign" end
    if q.questie and QDB and QDB.IsDoableVerbose then
        local ok, text, _, code = pcall(QDB.IsDoableVerbose, id, false, true, true)
        if ok then
            local name = StateName(code)
            if name == nil or name == "AVAILABLE" or name == "QUEST_LOG" then return "available" end
            if DONE[name] then return "done", name == "EXCLUSIVE_COMPLETED" and "another version of it is done" or nil end
            if FOREIGN[name] then return "foreign", text end
            if LOCKED[name] then return "locked", Data.Reason(text) end
            return "blocked", Data.Reason(text)
        end
    end
    -- our own knowledge (the import's, or what was recorded): another
    -- version done, the breadcrumb's chain moved on, the parent quest,
    -- what came before it, the levels, and whether it was ever offered
    for _, e in ipairs(q.exclusiveTo) do
        if Data.Completed(e) then return "done", "another version of it is done" end
    end
    if q.breadcrumbFor > 0 and (Data.Completed(q.breadcrumbFor) or Data.InLog(q.breadcrumbFor)) then
        return "blocked", "its chain has moved on"
    end
    if q.parentQuest > 0 and not Data.InLog(q.parentQuest) then return "locked", "part of another quest" end
    for _, p in ipairs(q.preGroup) do
        if not Data.Completed(math.abs(p)) then return "locked", "a quest before it is not done" end
    end
    if #q.preSingle > 0 then
        local any = false
        for _, p in ipairs(q.preSingle) do if Data.Completed(math.abs(p)) then any = true end end
        if not any then return "locked", "a quest before it is not done" end
    end
    local level = UnitLevel("player")
    if q.requiredLevel > level then return "locked", ("needs level %d"):format(q.requiredLevel) end
    if q.maxLevel > 0 and level > q.maxLevel then return "blocked", ("only up to level %d"):format(q.maxLevel) end
    if q.questie or q.imported then return "available" end
    local own = q.own
    if own and own.g and #own.g > 0 then return "available", "seen offered" end
    return "unknown"
end

-------------------------------------------------------------------
-- NPCs, objects, items: who gives a quest and where
-------------------------------------------------------------------
local npcs, objects, items = {}, {}, {}

local function QuestieNPC(id)
    local n = npcs[id]
    if n ~= nil then return n or nil end
    if not QDB then npcs[id] = false return nil end
    local ok, raw = pcall(QDB.QueryNPC, id, { "name", "spawns", "zoneID" })
    if not ok or type(raw) ~= "table" then npcs[id] = false return nil end
    n = { id = id, name = raw[1] or ("NPC " .. id), spawns = type(raw[2]) == "table" and raw[2] or {}, zone = raw[3] or 0 }
    npcs[id] = n
    return n
end

local function QuestieObject(id)
    local o = objects[id]
    if o ~= nil then return o or nil end
    if not QDB then objects[id] = false return nil end
    local ok, raw = pcall(QDB.QueryObject, id, { "name", "spawns", "zoneID" })
    if not ok or type(raw) ~= "table" then objects[id] = false return nil end
    o = { id = id, name = raw[1] or ("Object " .. id), spawns = type(raw[2]) == "table" and raw[2] or {}, zone = raw[3] or 0 }
    objects[id] = o
    return o
end

function Data.ItemName(id)
    local name = items[id]
    if name ~= nil then return name or nil end
    local game = C_Item.GetItemNameByID(id)
    if game then items[id] = game return game end
    if QDB then
        local ok, n = pcall(QDB.QueryItemSingle, id, "name")
        if ok and type(n) == "string" then items[id] = n return n end
    end
    local own = ns.Own and ns.Own.Item and ns.Own.Item(id)   -- the import's item names
    if own then items[id] = own return own end
    items[id] = false
    return nil
end

-- the first place a Questie thing stands: areaID, x, y (percent) - the
-- spawn list is { [areaID] = { {x, y}, ... } }, -1 inside an instance
local function FirstSpawn(spawns)
    local areas = {}
    for areaID in pairs(spawns or {}) do areas[#areas + 1] = areaID end
    table.sort(areas)
    for _, areaID in ipairs(areas) do
        for _, pos in ipairs(spawns[areaID]) do
            if type(pos) == "table" and pos[1] and pos[1] > 0 and pos[2] and pos[2] > 0 then
                return areaID, pos[1], pos[2]
            end
        end
    end
    for _, areaID in ipairs(areas) do return areaID end
end

-- import.lua reads Questie's NPCs, objects and item names through these
Data.FirstSpawn    = FirstSpawn
Data.QuestieNPC    = QuestieNPC
Data.QuestieObject = QuestieObject
function Data.QuestieItemName(id)
    if not QDB then return nil end
    local ok, n = pcall(QDB.QueryItemSingle, id, "name")
    return (ok and type(n) == "string" and n ~= "") and n or nil
end

-- a place: { kind = "npc" | "object" | "item" | "spot", id, name, mapID, zone, x, y (percent) }
local function QuestiePlace(kind, id, thing)
    local areaID, x, y = FirstSpawn(thing.spawns)
    areaID = areaID or thing.zone
    local mapID = Data.MapForArea(areaID)
    return { kind = kind, id = id, name = thing.name, mapID = mapID, zone = areaID and areaID ~= 0 and Data.ZoneName(areaID) or nil, x = x, y = y }
end

-- our own giver keys: "n123", "i456", "s52:45.2:67.8"
local function OwnPlace(key)
    local kind, rest = key:sub(1, 1), key:sub(2)
    if kind == "n" then
        local id = tonumber(rest)
        local n = id and ns.Own.NPC(id)
        if not n then return nil end
        return { kind = "npc", id = id, name = n.n or ("NPC " .. id), mapID = n.m, zone = Data.MapName(n.m) or n.z, x = n.x, y = n.y }
    elseif kind == "o" then
        local id = tonumber(rest)
        local o = id and ns.Own.Object and ns.Own.Object(id)
        if not o then return nil end
        return { kind = "object", id = id, name = o.n or ("Object " .. id), mapID = o.m, zone = Data.MapName(o.m) or o.z, x = o.x, y = o.y }
    elseif kind == "i" then
        local id = tonumber(rest)
        return id and { kind = "item", id = id, name = Data.ItemName(id) or ("Item " .. id) } or nil
    elseif kind == "s" then
        local m, x, y = rest:match("^(%d+):([%d%.]+):([%d%.]+)$")
        m, x, y = tonumber(m), tonumber(x), tonumber(y)
        if not m then return nil end
        return { kind = "spot", name = "Quest giver", mapID = m, zone = Data.MapName(m), x = x, y = y }
    end
end

local function Places(q, questieNPCs, questieObjects, questieItems, ownKeys)
    local list, seenNPC, seenObject, seenItem = {}, {}, {}, {}
    for _, id in ipairs(questieItems or EMPTY) do
        seenItem[id] = true
        list[#list + 1] = { kind = "item", id = id, name = Data.ItemName(id) or ("Item " .. id) }
    end
    for _, id in ipairs(questieNPCs or EMPTY) do
        local n = QuestieNPC(id)
        if n then seenNPC[id] = true list[#list + 1] = QuestiePlace("npc", id, n) end
    end
    for _, id in ipairs(questieObjects or EMPTY) do
        local o = QuestieObject(id)
        if o then seenObject[id] = true list[#list + 1] = QuestiePlace("object", id, o) end
    end
    -- our own keys (recorded, or the import's), what Questie listed already left out
    for _, key in ipairs(ownKeys or EMPTY) do
        local p = OwnPlace(key)
        if p and not (p.kind == "npc" and seenNPC[p.id]) and not (p.kind == "object" and seenObject[p.id])
            and not (p.kind == "item" and seenItem[p.id]) and not (p.kind == "spot" and #list > 0) then
            list[#list + 1] = p
        end
    end
    return list
end

function Data.Starters(q)
    return Places(q, q.startNPCs, q.startObjects, q.startItems, q.own and q.own.g)
end

function Data.Finishers(q)
    return Places(q, q.finishNPCs, q.finishObjects, nil, q.own and q.own.f)
end

-------------------------------------------------------------------
-- The categories
-------------------------------------------------------------------
-- { { key, title, groups = { { title?, zones = { { id, name, quests } } } } }, ... }
-- With Questie: Journey's groups (zones by continent, dungeons, the
-- class, professions, battlegrounds, events), which already leave out
-- the quests of other classes and races. Our own quests join the zone
-- they were offered in. Without Questie: our own data by the map it was
-- offered on, grouped by continent, dungeons apart, the game's quest
-- lines, and the quests known by name only.
local CAT = { EK = 1, KALIMDOR = 2, ZEPHRAS = 8, DUNGEONS = 9, BATTLEGROUNDS = 10, CLASS = 11, PROFESSIONS = 12, EVENTS = 13 }

local categories
local zoneMap   -- Questie: zoneOrSort -> { questID = true }

local function ZoneMap()
    if zoneMap then return zoneMap end
    if Journey and type(Journey.zoneMap) == "table" and next(Journey.zoneMap) then
        zoneMap = Journey.zoneMap
    else
        local ok, map = pcall(ZoneDB.GetZonesWithQuests, false)
        zoneMap = ok and type(map) == "table" and map or {}
    end
    return zoneMap
end

local function QuestieZonesOf(categoryID)
    local list = {}
    local map = ZoneMap()
    local names = Journey and type(Journey.zones) == "table" and Journey.zones[categoryID]
    if not names and l10n and l10n.zoneCategoryLookup then names = l10n.zoneCategoryLookup[categoryID] end
    for id in pairs(names or {}) do
        local set = map[id]
        if set and next(set) then
            local ids = {}
            for questID in pairs(set) do ids[#ids + 1] = questID end
            list[#list + 1] = { id = id, name = Data.ZoneName(id), quests = ids }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function SortZones(list)
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- our own quests by the zone map they were offered on; skip(id) leaves
-- out what another grouping shows already
local function OwnGroups(skip)
    local byZone, dungeons, unplaced, lineQuests = {}, {}, {}, {}
    for _, line in ipairs(ns.Own.Lines()) do
        for _, id in ipairs(line.quests) do lineQuests[id] = true end
    end
    for id in pairs(ns.Own.All()) do
        if not (skip and skip(id)) then
            local own = ns.Own.Quest(id)
            local zone = own and own.m and Data.ZoneMap(own.m)
            local info = zone and C_Map.GetMapInfo(zone)
            if info and info.mapType == DUNGEON then
                dungeons[zone] = dungeons[zone] or { id = zone, name = info.name, quests = {} }
                table.insert(dungeons[zone].quests, id)
            elseif info then
                byZone[zone] = byZone[zone] or { id = zone, name = info.name, quests = {}, continent = Data.ContinentName(zone) }
                table.insert(byZone[zone].quests, id)
            elseif not lineQuests[id] then
                unplaced[#unplaced + 1] = id
            end
        end
    end
    local continents = {}
    for _, zone in pairs(byZone) do
        continents[zone.continent] = continents[zone.continent] or { title = zone.continent, zones = {} }
        table.insert(continents[zone.continent].zones, zone)
    end
    local groups = {}
    for _, g in pairs(continents) do SortZones(g.zones) groups[#groups + 1] = g end
    table.sort(groups, function(a, b) return a.title < b.title end)
    local dungeonList = {}
    for _, z in pairs(dungeons) do dungeonList[#dungeonList + 1] = z end
    return groups, SortZones(dungeonList), unplaced
end

local function LineZones()
    local list = {}
    for _, line in ipairs(ns.Own.Lines()) do
        if #line.quests > 0 then
            list[#list + 1] = { id = "line" .. line.id, name = line.name or ("Quest line " .. line.id), quests = line.quests }
        end
    end
    return list
end

-- the import's quests by their zone-or-sort key, grouped as Questie's
-- Journey groups them (the sorts table knows each key's category)
local importedMap   -- zoneOrSort -> { ids }
local function ImportedMap()
    if importedMap then return importedMap end
    importedMap = {}
    for id in pairs(ns.Own.All()) do
        local own = ns.Own.Quest(id)
        if own and own.s then
            local ids = importedMap[own.s]
            if not ids then ids = {} importedMap[own.s] = ids end
            ids[#ids + 1] = id
        end
    end
    return importedMap
end

local function ImportedZonesOf(categoryID, forPlayerOnly)
    local list = {}
    local map = ImportedMap()
    for sortID, s in pairs(ns.Own.Sorts()) do
        local ids = s.c == categoryID and map[sortID]
        if ids and #ids > 0 then
            local keep = true
            if forPlayerOnly then   -- the class groups: only the ones with a quest for this character
                keep = false
                for _, id in ipairs(ids) do
                    if Data.ForPlayer(Data.Quest(id)) then keep = true break end
                end
            end
            if keep then list[#list + 1] = { id = sortID, name = s.n or Data.ZoneName(sortID), quests = ids } end
        end
    end
    return SortZones(list)
end

local function HasImport()
    return ns.Own and ns.Own.Sorts and next(ns.Own.Sorts()) ~= nil
end

local function IsQuestie(id) return FromQuestie(id) ~= nil end
local function IsImported(id) local own = ns.Own.Quest(id) return own ~= nil and own.s ~= nil end

local function OwnCategory(list, title, groups, dungeonList, unplaced)
    local ownGroups = {}
    for _, g in ipairs(groups) do ownGroups[#ownGroups + 1] = g end
    if #dungeonList > 0 then ownGroups[#ownGroups + 1] = { title = "Dungeons", zones = dungeonList } end
    if #unplaced > 0 then ownGroups[#ownGroups + 1] = { zones = { { id = "unplaced", name = "Known by name only", quests = unplaced } } } end
    if #ownGroups > 0 then list[#list + 1] = { key = "own", title = title, groups = ownGroups } end
end

function Data.Categories()
    if categories then return categories end
    local className = UnitClass("player") or "Class"
    local list = {}
    if Data.HasQuestie() then
        list[#list + 1] = { key = "zones", title = "Zones", groups = {
            { title = "Eastern Kingdoms", zones = QuestieZonesOf(CAT.EK) },
            { title = "Kalimdor",         zones = QuestieZonesOf(CAT.KALIMDOR) },
            { title = "Zephras Isle",     zones = QuestieZonesOf(CAT.ZEPHRAS) },
        } }
        list[#list + 1] = { key = "dungeons",    title = "Dungeons and raids", groups = { { zones = QuestieZonesOf(CAT.DUNGEONS) } } }
        list[#list + 1] = { key = "class",       title = className .. " quests", groups = { { zones = QuestieZonesOf(CAT.CLASS) } } }
        list[#list + 1] = { key = "professions", title = "Professions", groups = { { zones = QuestieZonesOf(CAT.PROFESSIONS) } } }
        list[#list + 1] = { key = "pvp",         title = "Battlegrounds", groups = { { zones = QuestieZonesOf(CAT.BATTLEGROUNDS) } } }
        list[#list + 1] = { key = "events",      title = "Events and special", groups = { { zones = QuestieZonesOf(CAT.EVENTS) } } }
        -- what we saw that Questie does not list
        OwnCategory(list, "Recorded by you, new to Questie", OwnGroups(IsQuestie))
    elseif HasImport() then
        -- Questie's data as imported: the Journey's groups from our own tables
        list[#list + 1] = { key = "zones", title = "Zones", groups = {
            { title = "Eastern Kingdoms", zones = ImportedZonesOf(CAT.EK) },
            { title = "Kalimdor",         zones = ImportedZonesOf(CAT.KALIMDOR) },
            { title = "Zephras Isle",     zones = ImportedZonesOf(CAT.ZEPHRAS) },
        } }
        list[#list + 1] = { key = "dungeons",    title = "Dungeons and raids", groups = { { zones = ImportedZonesOf(CAT.DUNGEONS) } } }
        list[#list + 1] = { key = "class",       title = className .. " quests", groups = { { zones = ImportedZonesOf(CAT.CLASS, true) } } }
        list[#list + 1] = { key = "professions", title = "Professions", groups = { { zones = ImportedZonesOf(CAT.PROFESSIONS) } } }
        list[#list + 1] = { key = "pvp",         title = "Battlegrounds", groups = { { zones = ImportedZonesOf(CAT.BATTLEGROUNDS) } } }
        list[#list + 1] = { key = "events",      title = "Events and special", groups = { { zones = ImportedZonesOf(CAT.EVENTS) } } }
        list[#list + 1] = { key = "lines",       title = "Quest lines", groups = { { zones = LineZones() } } }
        OwnCategory(list, "Recorded by you, not in the import", OwnGroups(IsImported))
    else
        local groups, dungeonList, unplaced = OwnGroups(nil)
        list[#list + 1] = { key = "zones", title = "Zones", groups = groups }
        list[#list + 1] = { key = "dungeons", title = "Dungeons and raids", groups = { { zones = dungeonList } } }
        list[#list + 1] = { key = "lines", title = "Quest lines", groups = { { zones = LineZones() } } }
        if #unplaced > 0 then
            list[#list + 1] = { key = "named", title = "Known by name only", groups = { { zones = { { id = "unplaced", name = ("All (%d)"):format(#unplaced), quests = unplaced } } } } }
        end
    end
    local completed = C_QuestLog.GetAllCompletedQuestIDs and C_QuestLog.GetAllCompletedQuestIDs() or {}
    list[#list + 1] = { key = "me", title = "This character", groups = { { zones = { { id = "done", name = "Done", quests = completed } } } } }
    -- a category with nothing in it is left out
    categories = {}
    for _, cat in ipairs(list) do
        local groups = {}
        for _, g in ipairs(cat.groups) do
            if #g.zones > 0 then groups[#groups + 1] = g end
        end
        if #groups > 0 then
            cat.groups = groups
            categories[#categories + 1] = cat
        end
    end
    return categories
end

-- our own data grows while you play: the window rebuilds the tree on show
function Data.Reset()
    zoneMap, categories, importedMap = nil, nil, nil
end

-------------------------------------------------------------------
-- Startup: wait for Questie, or go without it
-------------------------------------------------------------------
local loginAt   -- GetTime() at our start, for QuestieDebug's "s after login"

function ns.InitData()
    loginAt = GetTime()
    if not C_AddOns.IsAddOnLoaded("Questie") then
        if ns.Import then ns.Import.QuestieAbsent() end   -- a guided import that waited for it
        BecomeReady()
        return
    end
    -- Questie initialises in coroutines after login; Questie.started says
    -- when its database and Journey groups exist. Its first start after an
    -- install or an update compiles the whole database and can take
    -- minutes (owner, 2026-11-07), so: looked at once a second for two
    -- minutes, then the window opens on our own data, and Questie is
    -- still looked for every five seconds and joins when it is there.
    local tries = 0
    local function Try()
        tries = tries + 1
        if Started() and Bind() then
            if Data.ready then
                -- late: the categories are rebuilt with Questie's groups
                Data.Reset()
                if ns.Chains then ns.Chains.Invalidate() end
                if ns.RefreshCompendium then ns.RefreshCompendium() end
                ns.Print("Questie is up; the compendium reads its database now.")
            else
                BecomeReady()
            end
            if ns.Import then ns.Import.OnQuestieUp() end   -- a pending guided import, or the hint
        elseif tries < 120 then
            C_Timer.After(1, Try)
        else
            if not Data.ready then BecomeReady() end   -- our own data and the game's for now
            C_Timer.After(5, Try)
        end
    end
    Try()
end

-- what the client says about an addon: enabled, loaded, else why not
local function AddonState(name)
    local ok, _, _, _, loadable, reason = pcall(C_AddOns.GetAddOnInfo, name)
    if not ok then return "not installed" end
    local okE, state = pcall(C_AddOns.GetAddOnEnableState, name)
    local enabled = okE and state ~= 0
    local version = C_AddOns.GetAddOnMetadata(name, "Version") or "?"
    if C_AddOns.IsAddOnLoaded(name) then return ("v%s loaded"):format(version) end
    if not enabled then return ("v%s DISABLED in the addon list"):format(version) end
    return ("v%s not loaded (%s%s)"):format(version, loadable and "loadable" or "not loadable", reason and (", " .. tostring(reason)) or "")
end

-- Questie and its database as the client sees them, and how far Questie's
-- start has come: for the owner's "why does Questie not start"
-- (2026-11-08). QuestieInit runs three stages in a coroutine after
-- PLAYER_LOGIN: 1 binds the database (QuestieDB.QuestPointers), 2 builds
-- the Journey's zone map, 3 sets Questie.started (false when a stage
-- failed). "not yet" everywhere two minutes after login means the start
-- never began - its PLAYER_LOGIN handler did not run - or sits in stage 1.
local function Count(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

function ns.QuestieDebug(brief)
    local Q = _G.Questie
    if not brief then
        print("  Questie: " .. AddonState("Questie") .. ", QuestieDB: " .. AddonState("QuestieDB"))
        local lib = _G.LibQuestieDB
        if type(lib) == "table" then
            local E = C_EncodingUtil
            print(("  LibQuestieDB: present, mode %s, flavor %s, contract %s, Support %s; C_EncodingUtil base64 %s, decompress %s, cbor %s"):format(
                tostring(lib.readMode), tostring(lib.flavor and lib.flavor.name), tostring(lib.contractVersion),
                type(lib.Support) == "table" and "yes" or "MISSING",
                E and type(E.DecodeBase64) or "none", E and type(E.DecompressString) or "none", E and type(E.DeserializeCBOR) or "none"))
        else
            local flavor = C_AddOns.GetAddOnMetadata("QuestieDB", "X-Flavor")
            print(("  LibQuestieDB: MISSING (QuestieDB's files did not finish loading) - X-Flavor from its toc: %s"):format(tostring(flavor)))
        end
    end
    if not Q then
        print("  Questie global: no")
        return
    end
    local qdb, journey, status = Import("QuestieDB"), Import("QuestieJourney"), Import("QuestieStatus")
    local since = loginAt and ("%d s after login"):format(GetTime() - loginAt) or "login time unknown"
    print(("  Questie's start, %s: config %s, addon-loaded part %s, stage 1 database %s, stage 2 zone map %s, stage 3 started %s, API ready %s"):format(
        since, Q.db and "yes" or "NO",
        _G.SLASH_ACECONSOLE_QUESTIE1 and "done" or "not yet",
        (qdb and type(qdb.QuestPointers) == "table") and (Count(qdb.QuestPointers) .. " quests") or "not yet",
        (journey and type(journey.zoneMap) == "table") and (Count(journey.zoneMap) .. " zones") or "not yet",
        Q.started == true and "yes" or (Q.started == false and "FAILED" or "not yet"),
        tostring(Q.API and Q.API.isReady)))
    local ok, issues = pcall(function() return status and status.GetIssues and status.GetIssues() end)
    if ok and type(issues) == "table" and #issues > 0 then
        for _, i in ipairs(issues) do
            local okF, text = pcall(string.format, tostring(i.message), unpack(i.args or {}))
            print(("  Questie reports (%s): %s%s"):format(
                i.severity == 1 and "error" or (i.severity == 2 and "warning" or "info"),
                okF and text or tostring(i.message), i.action and (" - " .. tostring(i.action)) or ""))
        end
    else
        print("  Questie reports no issue of its own.")
    end
end

-- /questing questie watch: the start line every 15 s until Questie has
-- started or failed, ten minutes at most
local watch
function ns.QuestieWatch()
    if watch then
        watch:Cancel() watch = nil
        ns.Print("Questie watch off.")
        return
    end
    local looks = 0
    ns.Print("watching Questie's start every 15 s (/questing questie watch stops it):")
    ns.QuestieDebug(true)
    watch = C_Timer.NewTicker(15, function()
        looks = looks + 1
        ns.QuestieDebug(true)
        if (_G.Questie and _G.Questie.started ~= nil) or looks >= 40 then
            watch:Cancel() watch = nil
            ns.Print("Questie watch done.")
        end
    end)
end

function ns.DataDebug()
    local n = 0
    if QDB and QDB.QuestPointers then for _ in pairs(QDB.QuestPointers) do n = n + 1 end end
    print(("  data: %s, ready %s, Questie loaded %s, started %s, Questie quests %d, categories %d"):format(
        Data.source, tostring(Data.ready), tostring(C_AddOns.IsAddOnLoaded("Questie")),
        tostring(_G.Questie and _G.Questie.started or false), n, #(Data.Categories())))
    ns.QuestieDebug()
    local completed = C_QuestLog.GetAllCompletedQuestIDs and C_QuestLog.GetAllCompletedQuestIDs() or {}
    print(("  completed on this character: %d"):format(#completed))
    if ns.Own then ns.Own.PrintStats() end
    if ns.Scan then print("  " .. ns.Scan.Status()) end
    if ns.Import then print("  " .. ns.Import.Status()) end
end
