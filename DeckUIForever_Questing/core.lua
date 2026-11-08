local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- DeckUIForever Questing: the quests themselves made easier (2026-11-07)
-------------------------------------------------------------------
-- The owner's wish: "ein Modul um das Questen zu erleichtern" - the NPC
-- dialog on autopilot (accept, hand in, skip the small talk), a mark on
-- the reward worth taking, the tracker following the zone, a key for the
-- quest item, and a compendium of every quest by zone, class and chain
-- with what is done, where it starts and what it needs.
--
-- The Quests module is the tracker: it shows. This module acts, and it
-- reads. Nothing here replaces a Blizzard window: the dialog helpers only
-- call the quest API when Blizzard's events arrive, the reward marks are
-- frames of ours over Blizzard's buttons, and the compendium is a window
-- of its own. So the module is the same in the keyboard style and in the
-- gamepad style on the Steam Deck.
--
-- The compendium's knowledge comes from Questie's database when Questie
-- is installed (questdata.lua); the game itself knows only what you have
-- done, the quest lines of a map and the titles. Without Questie the
-- window shows that much and says so.
-------------------------------------------------------------------
local DEVICE_DEFAULTS = {
    deck = { scale = 0.9, itemScale = 1.1 },
    pc   = { scale = 1.0, itemScale = 1.0 },
}

local DEFAULTS = {
    -- the NPC dialog (dialog.lua)
    autoAccept    = true,    -- take the quests an NPC offers
    acceptTrivial = false,   -- grey ones too
    acceptShared  = true,    -- quests a party member shares, and escort starts
    autoTurnIn    = true,    -- hand in finished quests, take the reward when there is no choice
    autoGossip    = true,    -- skip the small talk when it leads nowhere else
    autoShare     = false,   -- share every new quest with the party
    announce      = true,    -- say in the chat what was done
    pauseKey      = "shift", -- held: nothing automatic. shift | ctrl | alt | none
    -- the reward (rewards.lua)
    rewardMarks   = true,    -- coin on the most valuable, arrow on an upgrade
    rewardAuto    = false,   -- take the most valuable when nothing is an upgrade
    -- the tracker (zone.lua)
    zoneTrack     = false,   -- track the quests of the zone you enter
    zoneUntrack   = false,   -- and stop tracking the others
    titleLevels   = true,    -- "[12] Title" in the Quests module's tracker
    -- the quest item key (questitem.lua)
    questItem     = true,
    -- the compendium (compendium.lua)
    hideDone      = false,
    onlyMine      = true,    -- hide quests for another class or race
    -- our own quest data (record.lua, scan.lua; the data itself is DeckUIForeverQuestDataDB)
    record        = true,    -- record what NPCs offer and take back
    -- data, not settings (kept on Defaults): NPCs the dialog helpers leave alone
    ignoredNPCs   = {},
}

function ns.DeviceDB()
    return D.DeviceDB(DeckUIForeverQuestingDB, DEVICE_DEFAULTS)
end

local function db() return DeckUIForeverQuestingDB end
ns.db = db

-- a value we may compare or do arithmetic with
function ns.Plain(...)
    if not issecretvalue then return true end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end

function ns.Print(text)
    print("|cffffd100DeckUIForever Questing:|r " .. text)
end

-- what the dialog helpers tell the chat, if asked to
function ns.Say(text)
    if db().announce then ns.Print(text) end
end

-------------------------------------------------------------------
-- The pause: a held key, or /questing pause
-------------------------------------------------------------------
-- Forever's gamepad emulation maps Shift to the left trigger, so on the
-- Steam Deck holding LT is holding Shift: the same pause on both devices.
local KEYS = {
    shift = IsShiftKeyDown,
    ctrl  = IsControlKeyDown,
    alt   = IsAltKeyDown,
    none  = function() return false end,
}
ns.PAUSE_KEYS = { "shift", "ctrl", "alt", "none" }
ns.PAUSE_NAMES = { shift = "Shift (LT on the Deck)", ctrl = "Ctrl (LB on the Deck)", alt = "Alt", none = "No key" }

ns.paused = false

function ns.Paused()
    if ns.paused then return true end
    local check = KEYS[db().pauseKey or "shift"] or KEYS.shift
    return check()
end

-------------------------------------------------------------------
-- NPCs left alone: /questing ignore while talking to one
-------------------------------------------------------------------
-- the creature id of a unit, nil for players and for a secret guid
function ns.NpcID(unit)
    local guid = UnitGUID(unit)
    if not guid or not ns.Plain(guid) then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
    return nil
end

function ns.Ignored(unit)
    local id = ns.NpcID(unit)
    return id ~= nil and db().ignoredNPCs[id] ~= nil
end

local function ToggleIgnore()
    local unit = UnitExists("questnpc") and "questnpc" or "npc"
    local id = ns.NpcID(unit)
    if not id then
        ns.Print("talk to an NPC first, then /questing ignore leaves that NPC alone.")
        return
    end
    local name = UnitName(unit) or ("NPC " .. id)
    if db().ignoredNPCs[id] then
        db().ignoredNPCs[id] = nil
        ns.Print(name .. " is handled again.")
    else
        db().ignoredNPCs[id] = name
        ns.Print(name .. " is left alone from now on. /questing ignore at the NPC takes it back.")
    end
end

-------------------------------------------------------------------
-- Events: one frame, many listeners
-------------------------------------------------------------------
-- ns.On("QUEST_DETAIL", fn): fn(event, ...) runs for every event; a file
-- registers what it needs and the frame is shared.
local listeners = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(listeners[event] or {}) do fn(event, ...) end
end)

function ns.On(event, fn)
    if not listeners[event] then
        listeners[event] = {}
        pcall(events.RegisterEvent, events, event)
    end
    table.insert(listeners[event], fn)
end

-- run fn now when out of combat, else when the fight ends
local waiting = {}
function ns.OutOfCombat(fn)
    if InCombatLockdown() then
        waiting[#waiting + 1] = fn
    else
        fn()
    end
end
ns.On("PLAYER_REGEN_ENABLED", function()
    local list = waiting
    waiting = {}
    for _, fn in ipairs(list) do fn() end
end)

-------------------------------------------------------------------
-- /questing
-------------------------------------------------------------------
local function Help()
    ns.Print("/questing opens the settings page, /compendium the quest compendium.")
    print("  /questing pause - stop everything automatic until the next /questing pause")
    print("  /questing ignore - leave the NPC you are talking to alone (again: handle it)")
    print("  /questing ignored - list those NPCs, /questing forget - clear the list")
    print("  /questing track - track this zone's quests now")
    print("  /questing scan [stop|reset] - ask the server for every quest's name, id by id")
    print("  /questing import [clear|status] - copy Questie's quest data into your own, once (switches Questie on for one login when it is installed but off)")
    print("  /questing record - how much your own quest data holds")
    print("  /questing questie [watch] - Questie as the client sees it, and how far its start has come")
    print("  /questing debug - what the module works with")
end

local function PrintIgnored()
    local n = 0
    for id, name in pairs(db().ignoredNPCs) do
        n = n + 1
        print(("  %s (%d)"):format(tostring(name), id))
    end
    if n == 0 then print("  no NPC is left alone.") end
end

function D.PrintQuesting()
    local d = db()
    ns.Print(("accept %s (trivial %s, shared %s), hand in %s, gossip %s, share %s, pause key %s%s"):format(
        tostring(d.autoAccept), tostring(d.acceptTrivial), tostring(d.acceptShared), tostring(d.autoTurnIn),
        tostring(d.autoGossip), tostring(d.autoShare), tostring(d.pauseKey), ns.paused and ", PAUSED" or ""))
    print(("  reward marks %s, auto reward %s, zone tracking %s (untrack %s), title levels %s, quest item %s"):format(
        tostring(d.rewardMarks), tostring(d.rewardAuto), tostring(d.zoneTrack), tostring(d.zoneUntrack),
        tostring(d.titleLevels), tostring(d.questItem)))
    if ns.DataDebug then ns.DataDebug() end
    if ns.ItemDebug then ns.ItemDebug() end
    print("  NPCs left alone:")
    PrintIgnored()
end

SLASH_DECKQUESTING1 = "/questing"
SlashCmdList.DECKQUESTING = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "pause" then
        ns.paused = not ns.paused
        ns.Print(ns.paused and "paused - nothing happens by itself until the next /questing pause."
            or "running again.")
    elseif msg == "ignore" then
        ToggleIgnore()
    elseif msg == "ignored" then
        ns.Print("NPCs left alone:")
        PrintIgnored()
    elseif msg == "forget" then
        wipe(db().ignoredNPCs)
        ns.Print("every NPC is handled again.")
    elseif msg == "track" then
        if ns.TrackZone then ns.TrackZone(true) end
    elseif msg == "scan" then
        if ns.Scan.Running() then ns.Print(ns.Scan.Status()) else ns.Scan.Start() end
    elseif msg == "scan stop" then
        ns.Scan.Stop()
        ns.Print(ns.Scan.Status())
    elseif msg == "scan reset" then
        ns.Scan.Reset()
    elseif msg == "scan status" then
        ns.Print(ns.Scan.Status())
    elseif msg == "import" then
        ns.Import.Guided()
    elseif msg == "import clear" then
        ns.Import.Clear()
    elseif msg == "import status" then
        ns.Print(ns.Import.Status())
    elseif msg == "record" then
        ns.Print("your quest data:")
        ns.Own.PrintStats()
        print("  " .. ns.Scan.Status())
        print("  " .. ns.Import.Status())
    elseif msg == "debug" then
        D.PrintQuesting()
    elseif msg == "questie" then
        ns.Print("Questie as the client sees it:")
        ns.QuestieDebug()
    elseif msg == "questie watch" then
        ns.QuestieWatch()
    elseif msg == "help" or msg == "?" then
        Help()
    else
        D.ToggleConfig("Questing")
    end
end

SLASH_DECKCOMPENDIUM1 = "/compendium"
SlashCmdList.DECKCOMPENDIUM = function(msg)
    if ns.ToggleCompendium then ns.ToggleCompendium((msg or ""):trim()) end
end

-- the hub's key binding (DeckUIForever/Bindings.xml) calls this
D.compendiumToggle = function() if ns.ToggleCompendium then ns.ToggleCompendium() end end

-------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------
local function Init()
    DeckUIForeverQuestingDB = DeckUIForeverQuestingDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckUIForeverQuestingDB[k] == nil then
            DeckUIForeverQuestingDB[k] = type(v) == "table" and {} or v
        end
    end
    if ns.InitRecord then ns.InitRecord() end   -- our own data first: the sources read it
    if ns.InitScan then ns.InitScan() end
    if ns.InitData then ns.InitData() end
    if ns.InitCompendium then ns.InitCompendium() end
    if ns.InitDialog then ns.InitDialog() end
    if ns.InitRewards then ns.InitRewards() end
    if ns.InitZone then ns.InitZone() end
    if ns.InitQuestItem then ns.InitQuestItem() end
end

if IsLoggedIn() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", Init)
end
