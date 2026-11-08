local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Quest chains: which quest follows which
-------------------------------------------------------------------
-- Questie records a chain in three ways: nextQuestInChain (the one that
-- follows), preQuestSingle (any of these done opens it) and preQuestGroup
-- (all of these done open it). The links are read once for every quest
-- the data knows, a few hundred per frame so the game does not stutter,
-- and joined into components: a component is a chain, its quests in the
-- order the links allow (what comes before stands first), its length
-- the longest path through it.
--
-- "Long" chains have five steps or more. "Epic" ones are those Questie
-- sorts under Epic or Legendary, and the long ones that reach level 50
-- and carry an elite, dungeon or raid quest, or are class quests - the
-- Onyxia attunement, Benediction, the warlock's mount and their kind.
-------------------------------------------------------------------
local Chains = { built = false, building = false }
ns.Chains = Chains

local LONG_MIN  = 5
local EPIC_MIN  = 4
local EPIC_LEVEL = 50
local SORT_EPIC, SORT_LEGENDARY = -1, -344
local EPIC_TAGS = { [1] = true, [81] = true, [62] = true, [88] = true, [89] = true, [21] = true }   -- elite, dungeon, raid, class

local before = {}   -- questID -> { ids that come before it }
local after  = {}   -- questID -> { ids that follow it }
local chainOf = {}  -- questID -> chain
local chains = {}   -- list of { key, ids (ordered), length, minLevel, maxLevel, epic, long }

local function Link(from, to)
    if not (from and to) or from <= 0 or to <= 0 or from == to then return end
    after[from] = after[from] or {}
    before[to] = before[to] or {}
    for _, v in ipairs(after[from]) do if v == to then return end end
    after[from][#after[from] + 1] = to
    before[to][#before[to] + 1] = from
end

-- a quest opened by exactly one other follows it; one opened by any of
-- several follows each (the breadcrumbs into a hub), the chain then
-- branches and the longest path decides. Data.Links joins Questie's
-- links and our own recorded ones.
local function ReadLinks(id)
    local before, after = ns.Data.Links(id)
    for _, p in ipairs(before) do Link(p, id) end
    for _, n in ipairs(after) do Link(id, n) end
end

-------------------------------------------------------------------
-- Components and their order
-------------------------------------------------------------------
local function Component(start, seen)
    local ids, stack = {}, { start }
    seen[start] = true
    while #stack > 0 do
        local id = table.remove(stack)
        ids[#ids + 1] = id
        for _, n in ipairs(after[id] or {}) do
            if not seen[n] then seen[n] = true stack[#stack + 1] = n end
        end
        for _, p in ipairs(before[id] or {}) do
            if not seen[p] then seen[p] = true stack[#stack + 1] = p end
        end
    end
    return ids
end

-- the quests in link order (Kahn), ties by level then id; a cycle (bad
-- data) is broken by taking the lowest level left
local function Order(ids)
    local inSet, indeg = {}, {}
    for _, id in ipairs(ids) do inSet[id] = true indeg[id] = 0 end
    for _, id in ipairs(ids) do
        for _, p in ipairs(before[id] or {}) do
            if inSet[p] then indeg[id] = indeg[id] + 1 end
        end
    end
    local function Level(id)
        local q = ns.Data.Quest(id)
        return q and q.level or 0
    end
    local ready, ordered, placed = {}, {}, {}
    for _, id in ipairs(ids) do if indeg[id] == 0 then ready[#ready + 1] = id end end
    local function Pick()
        table.sort(ready, function(a, b)
            local la, lb = Level(a), Level(b)
            if la ~= lb then return la < lb end
            return a < b
        end)
        return table.remove(ready, 1)
    end
    while #ordered < #ids do
        if #ready == 0 then
            -- a cycle: free the lowest-level quest still waiting
            local best
            for _, id in ipairs(ids) do
                if not placed[id] and (not best or Level(id) < Level(best)) then best = id end
            end
            ready[1] = best
        end
        local id = Pick()
        if not placed[id] then
            placed[id] = true
            ordered[#ordered + 1] = id
            for _, n in ipairs(after[id] or {}) do
                if inSet[n] and not placed[n] then
                    indeg[n] = indeg[n] - 1
                    if indeg[n] <= 0 then ready[#ready + 1] = n end
                end
            end
        end
    end
    return ordered
end

-- the longest path, in quests, through the ordered component
local function Length(ordered)
    local inSet, dist, best = {}, {}, 1
    for _, id in ipairs(ordered) do inSet[id] = true end
    for _, id in ipairs(ordered) do
        local d = 1
        for _, p in ipairs(before[id] or {}) do
            if inSet[p] and dist[p] and dist[p] + 1 > d then d = dist[p] + 1 end
        end
        dist[id] = d
        if d > best then best = d end
    end
    return best
end

local function Describe(ordered)
    local Data = ns.Data
    local minLevel, maxLevel, epicSort, epicTag, classQuest = 999, 0, false, false, false
    for _, id in ipairs(ordered) do
        local q = Data.Quest(id)
        if q then
            if q.level > 0 and q.level < minLevel then minLevel = q.level end
            if q.level > maxLevel then maxLevel = q.level end
            if q.zone == SORT_EPIC or q.zone == SORT_LEGENDARY then epicSort = true end
            if q.classOnly then classQuest = true end
            local tag = Data.Tag(id)
            if tag and EPIC_TAGS[tag] then epicTag = true end
        end
    end
    if minLevel == 999 then minLevel = 0 end
    local length = Length(ordered)
    local epic = epicSort or (length >= EPIC_MIN and maxLevel >= EPIC_LEVEL and (epicTag or classQuest))
    return {
        key = ordered[1], ids = ordered, length = length,
        minLevel = minLevel, maxLevel = maxLevel,
        long = length >= LONG_MIN, epic = epic,
    }
end

-------------------------------------------------------------------
-- Building, a slice per frame
-------------------------------------------------------------------
local SLICE = 300
local onBuilt = {}

function Chains.OnBuilt(fn)
    if Chains.built then fn() else onBuilt[#onBuilt + 1] = fn end
end

function Chains.Build()
    if Chains.built or Chains.building then return end
    Chains.building = true
    wipe(before) wipe(after) wipe(chainOf) wipe(chains)
    local ids = {}
    for id in pairs(ns.Data.AllQuestIDs()) do ids[#ids + 1] = id end
    if #ids == 0 then
        Chains.built, Chains.building = true, false
        return
    end
    local i = 0
    local ticker
    ticker = C_Timer.NewTicker(0, function()
        local stop = math.min(i + SLICE, #ids)
        while i < stop do
            i = i + 1
            ReadLinks(ids[i])
        end
        if i >= #ids then
            ticker:Cancel()
            -- the components, in one go: joining is cheap once the links exist
            local seen = {}
            for _, id in ipairs(ids) do
                if not seen[id] and (after[id] or before[id]) then
                    local component = Component(id, seen)
                    if #component > 1 then
                        local chain = Describe(Order(component))
                        chains[#chains + 1] = chain
                        for _, member in ipairs(chain.ids) do chainOf[member] = chain end
                    end
                end
            end
            table.sort(chains, function(a, b)
                if a.length ~= b.length then return a.length > b.length end
                return a.minLevel < b.minLevel
            end)
            Chains.built, Chains.building = true, false
            local list = onBuilt
            onBuilt = {}
            for _, fn in ipairs(list) do fn() end
        end
    end)
end

-------------------------------------------------------------------
-- Asking
-------------------------------------------------------------------
function Chains.Of(questID) return chainOf[questID] end
function Chains.Before(questID) return before[questID] or {} end
function Chains.After(questID) return after[questID] or {} end

-- "long" or "epic": the chains of that kind, longest first
function Chains.List(kind)
    local list = {}
    for _, chain in ipairs(chains) do
        if (kind == "epic" and chain.epic) or (kind == "long" and chain.long and not chain.epic) then
            list[#list + 1] = chain
        end
    end
    return list
end

-- the chain's name: its first quest, and the last when they differ
function Chains.Title(chain)
    local first = ns.Data.Title(chain.ids[1])
    if #chain.ids > 1 then
        local last = ns.Data.Title(chain.ids[#chain.ids])
        if last ~= first then return first .. " ... " .. last end
    end
    return first
end

-- done steps, total steps, the quest you are at (first not done)
function Chains.Progress(chain)
    local done, at = 0, nil
    for _, id in ipairs(chain.ids) do
        if ns.Data.Completed(id) then
            done = done + 1
        elseif not at then
            at = id
        end
    end
    return done, #chain.ids, at
end

function Chains.Count()
    return #chains
end

-- our own links grow while you play: read again on the next open
function Chains.Invalidate()
    if not Chains.building then Chains.built = false end
end
