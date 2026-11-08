local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The import: Questie's knowledge into our own data, once
-------------------------------------------------------------------
-- /questing import, with Questie loaded and started, walks every quest
-- Questie knows and writes it into DeckUIForeverQuestDataDB in
-- data_forever.lua's shape: name, levels, zone or sort key, givers and
-- finishers (NPCs, objects, start items), what comes before it (all of
-- them / any one of them), what it opens, what it excludes, its parent,
-- the breadcrumb target, class and race restrictions, objectives, the
-- tag Questie corrected. The NPCs and objects touched get a record with
-- name, map and position; a start item a name when the game has none;
-- every zone-or-sort key a name, its Journey category and its map
-- (sorts). Afterwards the compendium reads all of it from our own tables
-- and Questie can go.
--
-- The import is this account's personal copy of Questie's data (GPL): it
-- lives in the SavedVariables and ships with nothing. A few hundred
-- quests a frame, like the chains; /questing import clear takes it out
-- again (with it the recorded sightings of those quests).
-------------------------------------------------------------------
local Import = {}
ns.Import = Import

local PER_FRAME = 150

local running = false
local ticker
local stage, list, pos
local counts
local wantNPC, wantObject, wantItem, wantSort

local function db() return DeckUIForeverQuestDataDB end

local function Add(set, value)
    for _, v in ipairs(set) do if v == value then return set end end
    set[#set + 1] = value
    return set
end

local function SetOrNil(set)   -- an empty set is no restriction
    return (set and next(set)) and set or nil
end

local function Round(v) return math.floor(v * 10 + 0.5) / 10 end

-- the ids of a list as a fresh table, zeros and repeats dropped
local function Ids(src, abs)
    local out, seen = {}, {}
    for _, v in ipairs(src or {}) do
        if type(v) == "number" then
            if abs then v = math.abs(v) end
            if v > 0 and not seen[v] then seen[v] = true out[#out + 1] = v end
        end
    end
    return out
end

local function Keys(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-------------------------------------------------------------------
-- One quest, one NPC, one object
-------------------------------------------------------------------
local function WriteQuest(id)
    local Data = ns.Data
    local qq = Data.QuestieQuest(id)
    if not qq then return false end
    local q = ns.Own.Touch(id)
    q.i = true
    if qq.name and qq.name ~= "" then q.n = qq.name end
    if qq.level and qq.level > 0 then q.l = qq.level end
    if qq.requiredLevel and qq.requiredLevel > 0 then q.r = qq.requiredLevel end
    q.h = (qq.maxLevel and qq.maxLevel > 0) and qq.maxLevel or nil
    if qq.zone and qq.zone ~= 0 then
        q.s = qq.zone
        wantSort[qq.zone] = true
        local mapID = qq.zone > 0 and Data.MapForArea(qq.zone)
        if mapID then q.m = mapID end
    end
    local tagID = Data.QuestieTag(id)
    if tagID then q.t = tagID end
    -- givers and finishers, Questie's first; the recorded keys stay
    local g = {}
    for _, n in ipairs(qq.startNPCs) do Add(g, "n" .. n) wantNPC[n] = true end
    for _, o in ipairs(qq.startObjects) do Add(g, "o" .. o) wantObject[o] = true end
    for _, i in ipairs(qq.startItems) do Add(g, "i" .. i) wantItem[i] = true end
    for _, key in ipairs(q.g or {}) do Add(g, key) end
    q.g = #g > 0 and g or nil
    local f = {}
    for _, n in ipairs(qq.finishNPCs) do Add(f, "n" .. n) wantNPC[n] = true end
    for _, o in ipairs(qq.finishObjects) do Add(f, "o" .. o) wantObject[o] = true end
    for _, key in ipairs(q.f or {}) do Add(f, key) end
    q.f = #f > 0 and f or nil
    -- the links: Questie's word replaces what was inferred before it
    local p, a = Ids(qq.preGroup, true), Ids(qq.preSingle, true)
    q.p = #p > 0 and p or nil
    q.a = #a > 0 and a or nil
    if qq.nextInChain > 0 then q.x = Add(q.x or {}, qq.nextInChain) end
    local e = Ids(qq.exclusiveTo)
    q.e = #e > 0 and e or nil
    q.v = qq.parentQuest > 0 and qq.parentQuest or nil
    q.b = qq.breadcrumbFor > 0 and qq.breadcrumbFor or nil
    q.k = SetOrNil(qq.classOnly)
    q.y = SetOrNil(qq.raceOnly)
    if #qq.objectives > 0 then
        local texts = {}
        for _, text in ipairs(qq.objectives) do
            if type(text) == "string" and text ~= "" then texts[#texts + 1] = text:sub(1, 200) end
        end
        if #texts > 0 then q.o = texts end
    end
    if qq.repeatable or qq.daily then q.d = true end
    return true
end

-- the recorded place (where you stood) stays; Questie fills what is missing
local function Place(rec, thing)
    local Data = ns.Data
    if thing.name and thing.name ~= "" and (not rec.n or rec.n == "") then rec.n = thing.name end
    local areaID, x, y = Data.FirstSpawn(thing.spawns)
    areaID = areaID or thing.zone
    if not rec.m then
        local mapID = areaID and areaID > 0 and Data.MapForArea(areaID)
        if mapID then rec.m = mapID end
        if x and y then rec.x, rec.y = Round(x), Round(y) end
    end
    if areaID and areaID ~= 0 and areaID ~= -1 then rec.z = Data.ZoneName(areaID) end
    rec.i = true
end

local function WriteNPC(id)
    local n = ns.Data.QuestieNPC(id)
    if not n then return false end
    Place(ns.Own.TouchNPC(id), n)
    return true
end

local function WriteObject(id)
    local o = ns.Data.QuestieObject(id)
    if not o then return false end
    Place(ns.Own.TouchObject(id), o)
    return true
end

local function WriteItem(id)
    if C_Item.GetItemNameByID(id) then return false end
    local name = ns.Data.QuestieItemName(id)
    if name then db().items[id] = name return true end
    return false
end

local function WriteSort(sortID)
    local Data = ns.Data
    local s = db().sorts[sortID] or {}
    db().sorts[sortID] = s
    s.n = Data.ZoneName(sortID)
    s.c = Data.SortCategory(sortID)
    s.m = sortID > 0 and Data.MapForArea(sortID) or nil
    return true
end

-------------------------------------------------------------------
-- The slices
-------------------------------------------------------------------
local STAGES = {
    { name = "quests",  write = WriteQuest,  ids = function() return Keys(ns.Data.QuestieQuestIDs()) end },
    { name = "npcs",    write = WriteNPC,    ids = function() return Keys(wantNPC) end },
    { name = "objects", write = WriteObject, ids = function() return Keys(wantObject) end },
    { name = "items",   write = WriteItem,   ids = function() return Keys(wantItem) end },
    { name = "sorts",   write = WriteSort,   ids = function() return Keys(wantSort) end },
}

local function Finish()
    if ticker then ticker:Cancel() ticker = nil end
    running = false
    local d = db()
    d.imported = {
        at = time(), quests = counts.quests, npcs = counts.npcs, objects = counts.objects,
        questie = C_AddOns.GetAddOnMetadata("Questie", "Version") or "?",
    }
    ns.Own.Reload()
    ns.Data.Reset()
    if ns.Chains then ns.Chains.Invalidate() end
    if ns.RefreshCompendium then ns.RefreshCompendium() end
    ns.Print(("import done: %d quests, %d NPCs, %d objects, %d item names, %d zones and sorts from Questie %s. The compendium reads them from your own data now, with or without Questie."):format(
        counts.quests, counts.npcs, counts.objects, counts.items, counts.sorts, d.imported.questie))
    -- the guided import's end: Questie was switched on for this, so it may go off again
    local s = ns.db()
    if s.importPending then
        s.importPending = nil
        if s.importEnabledQuestie then
            s.importEnabledQuestie = nil
            D.Dialog({
                key = "questing-import-done",
                width = 360,
                text = "Questie's data is in your record. Switch Questie and QuestieDB off again and reload? The compendium keeps everything; Questie's own map icons and tracker go with it.",
                accept = "Off and reload",
                cancel = "Keep Questie",
                onAccept = function()
                    C_AddOns.DisableAddOn("Questie")
                    C_AddOns.DisableAddOn("QuestieDB")
                    ReloadUI()
                end,
            })
        end
    end
end

local function NextStage()
    stage = stage + 1
    local s = STAGES[stage]
    if not s then Finish() return false end
    list, pos = s.ids(), 0
    return true
end

local function Tick()
    local s = STAGES[stage]
    local done = 0
    while done < PER_FRAME do
        pos = pos + 1
        local id = list[pos]
        if not id then
            if not NextStage() then return end
            s = STAGES[stage]
        else
            local ok, wrote = pcall(s.write, id)
            if ok and wrote then counts[s.name] = counts[s.name] + 1 end
            done = done + 1
            if s.name == "quests" and pos % 1000 == 0 then
                ns.Print(("import: %d of %d quests"):format(pos, #list))
            end
        end
    end
end

function Import.Running() return running end

function Import.Available()
    return ns.Data ~= nil and ns.Data.HasQuestie()
end

-------------------------------------------------------------------
-- The guided import: one button, whatever the state of Questie
-------------------------------------------------------------------
-- Owner 2026-11-08: "einen vereinfachten Import ... um es den Nutzern zu
-- erleichtern". Questie installed and up: import now. Still starting: the
-- import begins by itself when it is up (importPending). Installed but
-- switched off: switch Questie and QuestieDB on, reload, import at the
-- next login, then offer to switch them off again (importEnabledQuestie
-- remembers that it was us). Not installed: say what to install.
local function Installed(name)
    return (pcall(C_AddOns.GetAddOnInfo, name))
end

local function Enabled(name)
    local ok, state = pcall(C_AddOns.GetAddOnEnableState, name)
    return ok and state ~= 0
end

-- "ready" | "starting" | "disabled" | "notloaded" | "nodb" | "missing"
function Import.QuestieState()
    if not Installed("Questie") then return "missing" end
    if not Installed("QuestieDB") then return "nodb" end
    if C_AddOns.IsAddOnLoaded("Questie") then
        return Import.Available() and "ready" or "starting"
    end
    if not (Enabled("Questie") and Enabled("QuestieDB")) then return "disabled" end
    return "notloaded"
end

function Import.Guided()
    if running then ns.Print(Import.Status()) return end
    local state = Import.QuestieState()
    if state == "ready" then
        Import.Start()
    elseif state == "starting" then
        ns.db().importPending = true
        ns.Print("Questie is still starting; the import begins by itself as soon as it is up.")
    elseif state == "missing" then
        ns.Print("the import needs Questie once: install Questie and its database QuestieDB for World of Warcraft: Forever (two addons; the CurseForge app may not offer the Forever client, Questie's own site does), log in, press Import again. Afterwards Questie can go.")
    elseif state == "nodb" then
        ns.Print("Questie is installed but its database addon QuestieDB is not; Questie cannot start without it. Install QuestieDB for Forever, then press Import again.")
    else
        D.Dialog({
            key = "questing-import",
            width = 360,
            text = state == "disabled"
                and "Questie is installed but switched off. Switch Questie and QuestieDB on and reload? The import runs by itself at the next login, and afterwards you are asked whether Questie may go off again."
                or "Questie is installed and on, but not loaded. Reload to load it? The import runs by itself at the next login.",
            accept = "Reload and import",
            onAccept = function()
                local d = ns.db()
                d.importPending = true
                if state == "disabled" then
                    d.importEnabledQuestie = true
                    C_AddOns.EnableAddOn("Questie")
                    C_AddOns.EnableAddOn("QuestieDB")
                end
                ReloadUI()
            end,
        })
    end
end

-- questdata.lua calls this when Questie is up: a pending import starts,
-- and an account that never imported hears once that it could
function Import.OnQuestieUp()
    local d = ns.db()
    if running then return end
    if d.importPending then
        C_Timer.After(1, function() if not running and Import.Available() then Import.Start() end end)
    elseif not db().imported and not d.importHinted then
        d.importHinted = true
        ns.Print("Questie is up. \"Import Questie's data\" on the Questing page (or /questing import) copies its quest data into your own record once, so the compendium keeps all of it without Questie.")
    end
end

-- Questie never came: a pending import is forgotten, with a word
function Import.QuestieAbsent()
    local d = ns.db()
    if d.importPending then
        d.importPending = nil
        d.importEnabledQuestie = nil
        ns.Print("the import waited for Questie, but Questie did not load this time. Check both Questie and QuestieDB in the addon list, then press Import again.")
    end
end

function Import.Start()
    if running then ns.Print("the import is running.") return end
    if not Import.Available() then
        if C_AddOns.IsAddOnLoaded("Questie") then
            ns.Print("Questie is still loading; try /questing import again in a moment.")
        else
            ns.Print("the import needs Questie loaded once. Install Questie (and QuestieDB), log in, run /questing import, then Questie can go again.")
        end
        return
    end
    running = true
    counts = { quests = 0, npcs = 0, objects = 0, items = 0, sorts = 0 }
    wantNPC, wantObject, wantItem, wantSort = {}, {}, {}, {}
    stage = 0
    if not NextStage() then return end
    ns.Print(("import: reading %d quests from Questie, a few hundred a frame."):format(#list))
    ticker = C_Timer.NewTicker(0, Tick)
end

function Import.Stop()
    if ticker then ticker:Cancel() ticker = nil end
    running = false
end

-- takes the imported entries out again, the recorded sightings of those quests with them
function Import.Clear()
    Import.Stop()
    local d = db()
    local quests, npcs = 0, 0
    for id, q in pairs(d.quests) do
        if q.i then d.quests[id] = nil quests = quests + 1 end
    end
    for id, n in pairs(d.npcs) do
        if n.i then d.npcs[id] = nil npcs = npcs + 1 end
    end
    wipe(d.objs)
    wipe(d.items)
    wipe(d.sorts)
    d.imported = nil
    ns.Own.Reload()
    ns.Data.Reset()
    if ns.Chains then ns.Chains.Invalidate() end
    if ns.RefreshCompendium then ns.RefreshCompendium() end
    ns.Print(("import cleared: %d quests and %d NPCs removed."):format(quests, npcs))
end

function Import.Status()
    local info = db().imported
    if running then
        local s = STAGES[stage]
        return ("import running: %s, %d of %d"):format(s and s.name or "?", pos or 0, list and #list or 0)
    end
    if info then
        return ("imported from Questie %s on %s: %d quests, %d NPCs, %d objects"):format(
            tostring(info.questie), date("%Y-%m-%d", info.at), info.quests or 0, info.npcs or 0, info.objects or 0)
    end
    return "nothing imported yet - /questing import with Questie loaded"
end
