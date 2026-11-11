DeckUIForever = {}
local D = DeckUIForever

-------------------------------------------------------------------
-- DeckUIForever: DeckUI for World of Warcraft: Forever
-------------------------------------------------------------------
-- The hub of DeckUI (retail / Mists of Pandaria Classic), taken over on
-- 2026-11-05 for Forever (DECKUIFOREVER_BERICHT.md, phase 1). Forever runs
-- retail's engine and UI with Classic content, so the retail branch of
-- every file is what runs here, and the Mists/retail switches are gone.
-- One game only: one .toc per addon, no _Mists variants. New prefix, slash
-- command (/df) and SavedVariables (DeckUIForeverDB), so nothing collides
-- with DeckUI should someone carry both into one client.
-------------------------------------------------------------------

-------------------------------------------------------------------
-- Shared constants
-------------------------------------------------------------------
-- STANDARD_TEXT_FONT is the client's own UI font, so Cyrillic, Chinese
-- and Korean clients get a font that actually has their glyphs.
D.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
D.MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
D.DISC = "Interface\\Minimap\\UI-Minimap-Background"

-- A round mask over the whole frame: add it to every texture that should
-- be cut to a circle (orbs, rings, spec and cross buttons, auras).
function D.RoundMask(frame)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(D.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(frame)
    return mask
end

D.MODULE_ADDONS = {
    Orbs  = "DeckUIForever_Orbs",
    Cross = "DeckUIForever_Cross",
    Bars  = "DeckUIForever_Bars",
    Pad   = "DeckUIForever_Pad",
    Spec  = "DeckUIForever_Spec",
    Bags  = "DeckUIForever_Bags",
    Quests = "DeckUIForever_Quests",
    Questing = "DeckUIForever_Questing",
    Map   = "DeckUIForever_Map",
    Tooltip = "DeckUIForever_Tooltip",
    Nav   = "DeckUIForever_Nav",
    Week  = "DeckUIForever_Week",
}
D.MODULE_ORDER = { "Orbs", "Cross", "Bars", "Pad", "Spec", "Bags", "Quests", "Questing", "Map", "Tooltip", "Nav", "Week" }
-- the module checkboxes in the General tab
D.MODULE_TITLES = {
    Orbs   = "Orbs (unit frames)",
    Cross  = "Cross (action bar)",
    Pad    = "Pad (controller bar look)",
    Spec   = "Spec (talent group switcher)",
    Bags   = "Bags (bags and banks)",
    Quests = "Quests (objective tracker)",
    Questing = "Questing (quest helper and compendium)",
    Map    = "Map (minimap and world map)",
    Tooltip = "Tooltip (mouse-over window)",
    Nav    = "Nav (compass and waypoints)",
    Week   = "Week (lockouts, legacy, weeklies)",
}

-- Modules that start switched off, for new installs and for players who
-- update into them alike. Replacing the bag window, the quest tracker or
-- the maps is not something an update should do to anyone unasked.
D.MODULE_OFF_BY_DEFAULT = { Pad = true, Bags = true, Quests = true, Questing = true, Map = true, Tooltip = true, Nav = true, Week = true }

-- Forever is its own project, WOW_PROJECT_CAMELOT (18 in build 70707;
-- Blizzard_ProjectConstants/Camelot). Asked by the named constant, never
-- the number - the wiki says "Camelot" may yet be renamed. DeckUIForever is
-- made for this one client, so no file branches on it: this is only a
-- guard that says so should the addon land in another client.
D.IsForever = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

-- Key bindings (Bindings.xml) live in the hub: the game reads them at
-- startup, before a LoadOnDemand module exists. They call into the module
-- through D.navStep, which DeckUIForever_Nav sets when it loads.
BINDING_HEADER_DECKUIFOREVER = "DeckUIForever"
BINDING_NAME_DECKUIFOREVER_NAV_NEXT = "Navigation: next tracked quest"
BINDING_NAME_DECKUIFOREVER_NAV_PREV = "Navigation: previous tracked quest"
BINDING_NAME_DECKUIFOREVER_LOOT_ALL = "Loot window: take all"
BINDING_NAME_DECKUIFOREVER_WEEK = "Week overview: open / close"
BINDING_NAME_DECKUIFOREVER_COMPENDIUM = "Quest compendium: open / close"
-- a click binding: the key clicks the Questing module's secure quest item button
_G["BINDING_NAME_CLICK DeckQuestingItem:LeftButton"] = "Quest item: use it"
-- and the Orbs module's healing layer for the controller (padheal.lua): hold it
_G["BINDING_NAME_CLICK DeckHealLayer:LeftButton"] = "Deck Heal: healing layer (hold)"
function D.ToggleCompendium()
    if D.compendiumToggle then
        D.compendiumToggle()
    else
        print("DeckUIForever: switch on the Questing module (General tab) for the quest compendium.")
    end
end
function D.ToggleWeek()
    if D.weekToggle then
        D.weekToggle()
    else
        print("DeckUIForever: switch on the Week module (General tab) for the week overview.")
    end
end
function D.NavStep(dir)
    if D.navStep then
        D.navStep(dir)
    else
        print("DeckUIForever: switch on the Nav module (General tab) to step through quests.")
    end
end

D.modules = {}   -- key -> { title = ..., build = function(content) end }

-------------------------------------------------------------------
-- Module registration (called by the modules when they load)
-------------------------------------------------------------------
function D.RegisterModule(key, def)
    D.modules[key] = def
    if D.panel then D.panel:AddTab(key, def) end
end

-------------------------------------------------------------------
-- Device detection (Steam Deck vs PC)
-- Lua cannot ask the OS, so we use two clues: the Deck's 1280x800
-- screen and an active gamepad. DeckUIForeverDB.device = "auto"|"deck"|"pc"
-- lets the user override the result.
-------------------------------------------------------------------
D.DEVICE_ORDER = { "auto", "deck", "pc" }
D.DEVICE_NAMES = { auto = "Auto", deck = "Steam Deck", pc = "PC" }

local function HasGamepad()
    if not (C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()) then return false end
    local ok, ids = pcall(C_GamePad.GetAllDeviceIDs)
    return ok and type(ids) == "table" and #ids > 0
end

function D.DetectDevice()
    local w, h = GetPhysicalScreenSize()
    w, h = math.floor(w + 0.5), math.floor(h + 0.5)
    if w == 1280 and h == 800 then return "deck", "screen 1280x800" end
    if HasGamepad() then return "deck", "gamepad active" end
    return "pc", "no gamepad, screen " .. w .. "x" .. h
end

-- Auto detection is decided once, at PLAYER_LOGIN, and kept for the
-- session. Asked afresh it was both slow on hot paths (every D.DeviceDB()
-- call, the quest tracker redraws once a frame) and wrong: a gamepad
-- plugged in or dropped mid-session flipped the device, sending saved
-- positions into the other device's table while the Cross bindings made
-- at login stayed. A different device already needed a /reload.
local detected, detectedWhy

-- effective device after override
function D.GetDevice()
    local o = DeckUIForeverDB and DeckUIForeverDB.device or "auto"
    if o == "deck" or o == "pc" then return o, "manual" end
    if detected then return detected, detectedWhy end
    return D.DetectDevice()
end

function D.IsDeck()
    return D.GetDevice() == "deck"
end

-- set the override directly: /df deck|pc|auto, handy for testing the
-- Deck behaviour while sitting at the PC
function D.SetDevice(key)
    if not D.DEVICE_NAMES[key] then return end
    DeckUIForeverDB.device = key
    D.PrintDevice()
    print("DeckUIForever: changes to the loaded modules take effect after /reload.")
    -- the Device button caption would go stale while the panel is open
    if D.panel and D.panel:IsShown() then
        local c = D.panel.contents[D.panel.current]
        if c then D.RefreshWidgets(c) end
    end
end

function D.CycleDevice()
    local cur = DeckUIForeverDB.device or "auto"
    for i, v in ipairs(D.DEVICE_ORDER) do
        if v == cur then
            D.SetDevice(D.DEVICE_ORDER[(i % #D.DEVICE_ORDER) + 1])
            return
        end
    end
    D.SetDevice("auto")   -- stored value was not one of ours
end

function D.DeviceText()
    local o = DeckUIForeverDB.device or "auto"
    if o == "auto" then
        local d, why = D.GetDevice()
        local now = D.DetectDevice()
        -- the device is kept for the session; say so when it has changed since
        local note = now ~= d and (", now " .. D.DEVICE_NAMES[now] .. " - /reload to switch") or ""
        return "Device: Auto (" .. D.DEVICE_NAMES[d] .. ", " .. why .. note .. ")"
    end
    return "Device: " .. D.DEVICE_NAMES[o] .. " (manual)"
end

function D.PrintDevice()
    print("DeckUIForever: " .. D.DeviceText())
    print("DeckUIForever: key bindings " .. (D.bindingsCVar.localOnly
        and "stay on this device (synchronizeBindings 0)"
        or "are synced with the server (synchronizeBindings 1)"))
end

-- Key bindings per device. WoW keeps them on the server, so every machine
-- logging into the account loads the same ones, and a change on the Deck
-- lands on the PC. The client's own CVar synchronizeBindings = 0 keeps
-- them in the local WTF folder instead - the CVar lives in Config.wtf, so
-- it is itself per machine and needs no DeckUIForeverDB entry. Blizzard's UI never
-- touches it; confirmed present on 12.1.0 (owner's /dump, 2026-09-30).
-- A table proxy, so the ordinary D.Checkbox can drive it.
D.bindingsCVar = setmetatable({}, {
    __index = function() return GetCVar("synchronizeBindings") == "0" end,
    __newindex = function(_, _, v) SetCVar("synchronizeBindings", v and "0" or "1") end,
})

function D.SetLocalBindings(localOnly)
    if localOnly then
        -- write what is loaded now into the local copy, so this device
        -- starts from the bindings it has instead of an older local file
        if not InCombatLockdown() then SaveBindings(GetCurrentBindingSet()) end
        print("DeckUIForever: key bindings now stay on this device.")
    else
        -- deliberately no SaveBindings here: it would upload this device's
        -- bindings over the server's
        print("DeckUIForever: key bindings are synced with the server again - the server's set loads at the next login.")
    end
end

-- One button for the lot: the interface settings, the chat windows and the
-- key bindings stop travelling through the server. Each is a client CVar
-- of its own in Config.wtf, so per machine like synchronizeBindings above.
-- The master switch synchronizeSettings is left alone on purpose: it would
-- take the macros along, which nobody asked for. Edit Mode layouts and
-- what sits on the action bars have no CVar - their checkboxes do that.
D.SYNC_CVARS = { "synchronizeConfig", "synchronizeChatFrames", "synchronizeBindings" }

-- true when none of them is synced any more (a CVar this client does not
-- know is skipped; nil when it knows none of them)
function D.SyncIsOff()
    local known = false
    for _, name in ipairs(D.SYNC_CVARS) do
        local v = GetCVar(name)
        if v ~= nil then
            known = true
            if v ~= "0" then return false end
        end
    end
    return known or nil
end

function D.SetServerSync(on)
    if InCombatLockdown() then
        print("DeckUIForever: not in combat - try again after the fight.")
        return
    end
    local changed = 0
    for _, name in ipairs(D.SYNC_CVARS) do
        if GetCVar(name) ~= nil then
            SetCVar(name, on and "1" or "0")
            changed = changed + 1
        end
    end
    if changed == 0 then
        print("DeckUIForever: this client has no switch for the server sync.")
    elseif on then
        -- no SaveBindings here either: it would upload this device's set
        print("DeckUIForever: interface settings and key bindings are synced with the server again - the server's copy loads at the next login.")
    else
        -- start the local copy from the bindings loaded now
        SaveBindings(GetCurrentBindingSet())
        print("DeckUIForever: interface settings and key bindings now stay on this device. Do the same on your other devices.")
    end
end

function D.PrintSync()
    for _, name in ipairs(D.SYNC_CVARS) do
        print(("DeckUIForever: %s = %s"):format(name, tostring(GetCVar(name))))
    end
    print(("DeckUIForever: synchronizeSettings = %s, synchronizeMacros = %s (not touched)"):format(
        tostring(GetCVar("synchronizeSettings")), tostring(GetCVar("synchronizeMacros"))))
end

-- The camera as far out as the client allows (owner 2026-11-11: "einen
-- Knopf für max Kameradistanz"). The game's slider stops short of what
-- the CVar cameraDistanceMaxZoomFactor takes; how far that goes differs
-- between the clients (2.6 in retail, more in the Classic ones), so the
-- candidates are tried from the top and the first the client keeps stands.
-- The client saves the CVar itself; nothing of ours is stored.
D.CAMERA_CVAR = "cameraDistanceMaxZoomFactor"
local CAMERA_TRIES = { 4, 3.4, 2.6 }

local function CameraFactor() return tonumber(GetCVar(D.CAMERA_CVAR) or "") end
local function CameraDefault()
    return tonumber(C_CVar and C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(D.CAMERA_CVAR) or "") or 1.9
end

-- true while the limit is above the client's default; nil when the client
-- has no such CVar
function D.CameraIsMax()
    local now = CameraFactor()
    if not now then return nil end
    return now > CameraDefault() + 0.01
end

function D.SetCameraMax(on)
    if not CameraFactor() then
        print("DeckUIForever: this client has no setting for the camera's distance limit.")
        return
    end
    if not on then
        SetCVar(D.CAMERA_CVAR, CameraDefault())
        print(("DeckUIForever: the camera's distance limit is back at the game's default (%s)."):format(
            tostring(CameraFactor())))
        return
    end
    for _, value in ipairs(CAMERA_TRIES) do
        pcall(SetCVar, D.CAMERA_CVAR, value)
        local now = CameraFactor()
        if now and now >= value - 0.01 then break end
    end
    -- and out to the new limit at once
    if CameraZoomOut then pcall(CameraZoomOut, 50) end
    print(("DeckUIForever: the camera now zooms out as far as the game allows (limit %s)."):format(
        tostring(CameraFactor())))
end

function D.PrintCamera()
    print(("DeckUIForever: %s = %s (default %s), zoom now %s"):format(D.CAMERA_CVAR,
        tostring(GetCVar(D.CAMERA_CVAR)), tostring(CameraDefault()),
        GetCameraZoom and ("%.1f"):format(GetCameraZoom()) or "?"))
end

-- /df build - the numbers a release depends on. The interface number in
-- our .toc files decides two things at once: whether WoW calls the addon
-- out of date, and which game version the CurseForge upload is filed under,
-- because the release script derives the version name from it. Reading it
-- off the running client beats reading it off a website, and the comparison
-- is the whole point: a mismatch is the thing to catch before tagging.
function D.PrintBuild()
    local version, build, _, toc = GetBuildInfo()
    -- GetAddOnMetadata does not hand out ## Interface in Forever (owner's
    -- /df build, 2026-11-05, build 70790); the client has a call of its own
    -- for it (AddOnsDocumentation.lua 1.60.1). The metadata as a fallback.
    local ours
    if C_AddOns.GetAddOnInterfaceVersion then
        local ok, v = pcall(C_AddOns.GetAddOnInterfaceVersion, "DeckUIForever")
        if ok and v and v ~= 0 then ours = v end
    end
    ours = ours or C_AddOns.GetAddOnMetadata("DeckUIForever", "Interface")
    print(("DeckUIForever: client %s (build %s), interface %s"):format(
        tostring(version), tostring(build), tostring(toc)))
    if not ours then
        print("DeckUIForever: cannot read our own ## Interface")
        return
    end
    if tostring(ours) == tostring(toc) then
        print(("DeckUIForever: our .toc says %s - matches, nothing to do"):format(tostring(ours)))
    else
        print(("DeckUIForever: our .toc says %s - MISMATCH, the .toc files want %s"):format(
            tostring(ours), tostring(toc)))
        print(("DeckUIForever: fix before releasing with  bump-version.ps1 <version> -Interface %s"):format(tostring(toc)))
    end
end

-- Per-device settings: positions and sizes differ between the Deck's
-- 1280x800 and a PC monitor, so modules keep them in db.perDevice[<device>].
-- D.DeviceDB(db) returns that table for the current device; with
-- defaults = { deck = {...}, pc = {...} } it also fills what is missing.
function D.DeviceKey()
    return D.IsDeck() and "deck" or "pc"
end

function D.DeviceDB(db, defaults)
    db.perDevice = db.perDevice or {}
    local key = D.DeviceKey()
    db.perDevice[key] = db.perDevice[key] or {}
    local d = db.perDevice[key]
    for k, v in pairs(defaults and defaults[key] or {}) do
        if d[k] == nil then d[k] = v end
    end
    return d
end

-- device, "name-realm", talent group: the key for what is kept per
-- device, character and talent setup (actionbars.lua, editmode.lua).
-- Forever has no specializations; from level 40 a character has up to
-- two talent groups (dual talents, the trainer), and the bars are kept
-- per group as in Mists - C_SpecializationInfo.GetActiveSpecGroup, the
-- call Blizzard's Camelot talent frame makes. 1 before that.
local function TalentGroup()
    local get = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup
    local ok, group = pcall(get or function() end, false, false)
    return ok and tonumber(group) or 1
end

function D.CharSpecKey()
    return D.DeviceKey(), UnitName("player") .. "-" .. GetRealmName(), TalentGroup()
end

-- one-time migration of old flat fields into the per-device table of
-- BOTH devices (so nothing looks different on either until changed)
function D.MigrateToDevice(db, fields)
    db.perDevice = db.perDevice or {}
    for _, dev in ipairs({ "deck", "pc" }) do
        db.perDevice[dev] = db.perDevice[dev] or {}
    end
    for _, f in ipairs(fields) do
        if db[f] ~= nil then
            for _, dev in ipairs({ "deck", "pc" }) do
                if db.perDevice[dev][f] == nil then db.perDevice[dev][f] = db[f] end
            end
            db[f] = nil
        end
    end
end

-- may this module be loaded on the current device?
function D.ModuleAllowed(key)
    if key == "Cross" and DeckUIForeverDB.crossDeckOnly and not D.IsDeck() then
        return false, "Cross hotbar is set to Steam Deck only"
    end
    return true
end

-------------------------------------------------------------------
-- Load / enable a module
-------------------------------------------------------------------
-- a module's addon folder, once it is ported (DECKUIFOREVER_BERICHT.md,
-- phases 2-5); until then the module is listed but cannot load
function D.ModuleExists(key)
    local addon = D.MODULE_ADDONS[key]
    return addon ~= nil and C_AddOns.DoesAddOnExist(addon)
end

local function LoadModule(key)
    local addon = D.MODULE_ADDONS[key]
    if C_AddOns.IsAddOnLoaded(addon) then return true end
    if not D.ModuleExists(key) then return false end
    C_AddOns.EnableAddOn(addon)
    local loaded, reason = C_AddOns.LoadAddOn(addon)
    if not loaded then
        print("DeckUIForever: module " .. key .. " could not be loaded (" .. tostring(reason) .. ")")
    end
    return loaded
end

function D.SetModuleEnabled(key, state)
    DeckUIForeverDB.modules[key] = state
    if state then
        local allowed, why = D.ModuleAllowed(key)
        if not D.ModuleExists(key) then
            print("DeckUIForever: module " .. key .. " is not part of DeckUIForever yet.")
        elseif not allowed then
            print("DeckUIForever: module " .. key .. " stays off on this device (" .. why .. ").")
        elseif InCombatLockdown() then
            print("DeckUIForever: module " .. key .. " will be loaded after combat (/reload).")
        else
            LoadModule(key)
        end
    else
        if C_AddOns.IsAddOnLoaded(D.MODULE_ADDONS[key]) then
            print("DeckUIForever: module " .. key .. " will be disabled on the next /reload.")
        end
    end
end

-------------------------------------------------------------------
-- Movable frames (shared by all modules)
-------------------------------------------------------------------
D.movables = {}
D.unlocked = false

-- positions live in the per-device table: db.perDevice[<device>].positions
local function Positions(entry)
    local d = D.DeviceDB(entry.db)
    -- migrate old device-independent positions once, to both devices
    if entry.db.positions then
        for _, dev in ipairs({ "deck", "pc" }) do
            entry.db.perDevice[dev] = entry.db.perDevice[dev] or {}
            entry.db.perDevice[dev].positions = entry.db.perDevice[dev].positions or {}
            for k, v in pairs(entry.db.positions) do
                if entry.db.perDevice[dev].positions[k] == nil then
                    entry.db.perDevice[dev].positions[k] = v
                end
            end
        end
        entry.db.positions = nil
    end
    d.positions = d.positions or {}
    return d.positions
end

local function ApplyPosition(entry)
    local pos = Positions(entry)[entry.key]
    if pos then
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

-- for frames something else re-anchors (the world map, see DeckUIForever_Map):
-- the saved place again, or the default one when there is none yet
function D.ApplyPosition(frame)
    local entry = frame.deckMovable
    if not entry then return end
    if Positions(entry)[entry.key] then
        ApplyPosition(entry)
    elseif frame.defaultPoint then
        frame:ClearAllPoints()
        frame:SetPoint(unpack(frame.defaultPoint))
    end
end

local function SavePosition(entry)
    local point, _, relPoint, x, y = entry.frame:GetPoint()
    Positions(entry)[entry.key] = { point = point, relPoint = relPoint, x = x, y = y }
end

-- frame: the frame, key: name used for saving/label, db: the module's SavedVariables table
function D.MakeMovable(frame, key, db)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameStrata("HIGH")
    overlay:EnableMouse(true)
    overlay:RegisterForDrag("LeftButton")
    overlay:Hide()

    local bg = overlay:CreateTexture(nil, "OVERLAY")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.8, 0, 0.35)

    local label = overlay:CreateFontString(nil, "OVERLAY")
    label:SetFont(D.FONT, 16, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(key)

    local entry = { frame = frame, key = key, db = db, overlay = overlay }

    overlay:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        frame:StartMoving()
    end)
    overlay:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(entry)
    end)

    table.insert(D.movables, entry)
    frame.deckMovable = entry
    ApplyPosition(entry)
    overlay:SetShown(D.unlocked)
end

-- Windows (the bag window) are also dragged directly, without /df unlock,
-- the way every window in the game is. Same saved position, same per-device
-- table, so /df reset still brings them back. Call after D.MakeMovable.
-- Unlike the HUD frames these are not protected, so combat does not matter.
function D.MakeDraggable(frame)
    local entry = frame.deckMovable
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if entry then SavePosition(entry) end
    end)
end

-- Re-anchors a frame by its top-left corner without moving it, and saves
-- that. After a drag WoW anchors a frame by whichever corner is nearest,
-- so one dropped in the lower half hangs from its bottom edge - and a
-- tracker that then shrinks (folded, fewer quests) collapses towards
-- where its old bottom was, far from its title. Reported 2026-09-29 as
-- "minimised, the window is gone".
function D.PinTopLeft(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then return false end
    -- GetLeft/GetTop and SetPoint offsets are both in the frame's own
    -- (scaled) coordinates, so they carry over unchanged
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    if frame.deckMovable then SavePosition(frame.deckMovable) end
    return true
end

-- only: optional set of frame keys ({ ["Raid"] = true }) - unlock just
-- those, as a settings page's "Move" button does; nil unlocks everything.
-- Locking always locks all.
function D.SetUnlocked(state, only)
    if state and InCombatLockdown() then
        print("DeckUIForever: not possible in combat.")
        return
    end
    D.unlocked = state
    D.unlockedOnly = state and only or nil
    for _, entry in ipairs(D.movables) do
        entry.overlay:SetShown(D.IsUnlocked(entry.key))
    end
    -- frames that are hidden most of the time show a sample while unlocked
    for _, fn in ipairs(D.unlockCallbacks) do xpcall(fn, geterrorhandler(), state, D.unlockedOnly) end
    print("DeckUIForever: frames " .. (state and "unlocked" or "locked"))
end

-- is the frame with this key unlocked right now?
function D.IsUnlocked(key)
    return D.unlocked and (not D.unlockedOnly or D.unlockedOnly[key]) and true or false
end

D.unlockCallbacks = {}
function D.OnUnlock(fn)
    table.insert(D.unlockCallbacks, fn)
end

-- One frame back to its default place (current device only), for a frame
-- that ended up somewhere it cannot be seen or reached.
function D.ResetPosition(frame)
    local entry = frame.deckMovable
    if not entry or InCombatLockdown() then return end
    Positions(entry)[entry.key] = nil
    if frame.defaultPoint then
        frame:ClearAllPoints()
        frame:SetPoint(unpack(frame.defaultPoint))
    end
end

function D.ResetPositions()
    if InCombatLockdown() then return end
    for _, entry in ipairs(D.movables) do
        Positions(entry)[entry.key] = nil
        if entry.frame.defaultPoint then
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint(unpack(entry.frame.defaultPoint))
        end
    end
    print("DeckUIForever: positions reset for this device (" .. D.DEVICE_NAMES[D.DeviceKey()] .. ").")
end

-------------------------------------------------------------------
-- Startup: load settings, load enabled modules
-------------------------------------------------------------------
local DEFAULTS = {
    modules       = {},   -- filled from MODULE_ORDER / MODULE_OFF_BY_DEFAULT below
    showMinimap   = true,
    minimapAngle  = 220,
    device        = "auto",
    crossDeckOnly = false,   -- Cross runs on both: controller on the Deck, keyboard on the PC
    applyUiScale  = false,
    uiScaleDeck   = 0.8,
    uiScalePC     = 0.71,
    keepBars      = false,   -- action bar layout per device (actionbars.lua)
    keepLayouts   = false,   -- Edit Mode layout per device (editmode.lua)
    styleDamageMeter = false, -- Blizzard's damage meter in DeckUIForever's look (damagemeter.lua)
    autoSellJunk  = false,   -- sell junk at every merchant (merchant.lua)
    autoRepair    = false,   -- repair at every merchant that can
    repairGuild   = true,    -- with guild funds first, when allowed
    fastLoot      = false,   -- take every slot at once when auto looting (loot.lua)
    lootWindow    = false,   -- DeckUIForever's loot window instead of Blizzard's
    lootRolls     = false,   -- group loot rolls in DeckUIForever's look (lootroll.lua)
    softTargetName = false,  -- the interact target's name under its icon (softtarget.lua)
    softTargetCast = true,   -- and a ring that fills while you cast on it
    rankMarks     = true,    -- elite/rare/boss emblems before enemy names (rankmark.lua)
    targetArrow   = false,   -- FFXIV's arrow over the target's nameplate (targetarrow.lua)
    xivPlates     = false,   -- enemy nameplates as FFXIV draws them (nameplates.lua)
    xivPlatesFriendly = true, -- with xivPlates: friends' plates too, in green (the soft friendly target's among them)
    plateSpace    = true,    -- and wider spacing between them (nameplates.lua sets the CVars)
    infoServer    = false,   -- FFXIV's server info: realm, mail, latency, time (infobars.lua)
    infoGold      = false,   -- the gold you carry, with a coin
    infoBags      = false,   -- a block of dots per bag, used and free slots
    hideBagBar    = false,   -- Blizzard's bag buttons out of sight (infobars.lua)
    mainMenu      = false,   -- the micro menu as FFXIV's round buttons (mainmenu.lua)
    dock          = true,    -- the dock: settings, week and compendium buttons in a row (dock.lua)
    ahScan        = true,    -- scan the auction house when it opens, every 15 min (auction.lua)
    ahStyle       = false,   -- the auction house window in DeckUIForever's look (auctionstyle.lua)
    restock       = false,   -- buy reagents, food, ammunition up to a count at merchants (restock.lua)
    mailHelper    = false,   -- your characters in the mail's "To" field, what Open All took (mail.lua)
    charPanel     = false,   -- item level and missing enchants on the character panel (charpanel.lua)
    listingWindow = false,   -- the group listing as a window: time listed, roles, group so far (lfglisting.lua)
    gamepadNav    = true,    -- our windows in Blizzard's gamepad window navigation (gamepad.lua)
}

-- Blizzard's whole-UI scale, set per device at login when enabled
function D.ApplyUiScale()
    if not DeckUIForeverDB.applyUiScale or InCombatLockdown() then return end
    local value = D.IsDeck() and DeckUIForeverDB.uiScaleDeck or DeckUIForeverDB.uiScalePC
    value = math.max(0.5, math.min(1.0, value or 1))
    SetCVar("useUiScale", "1")
    SetCVar("uiScale", tostring(value))
    UIParent:SetScale(value)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, name)
    if name ~= "DeckUIForever" then return end
    self:UnregisterEvent("ADDON_LOADED")

    if not D.IsForever then
        print("DeckUIForever: made for World of Warcraft: Forever - this is another client, expect missing pieces.")
    end

    DeckUIForeverDB = DeckUIForeverDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckUIForeverDB[k] == nil then DeckUIForeverDB[k] = v end
    end
    for _, key in ipairs(D.MODULE_ORDER) do
        if DeckUIForeverDB.modules[key] == nil then DeckUIForeverDB.modules[key] = not D.MODULE_OFF_BY_DEFAULT[key] end
    end
    -- one-time migration: Cross used to be Deck-only by default
    if not DeckUIForeverDB.migratedCrossPC then
        DeckUIForeverDB.migratedCrossPC = true
        DeckUIForeverDB.crossDeckOnly = false
    end

    for _, key in ipairs(D.MODULE_ORDER) do
        if DeckUIForeverDB.modules[key] and D.ModuleAllowed(key) then LoadModule(key) end
    end
end)

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
    detected, detectedWhy = D.DetectDevice()
    D.ApplyUiScale()
end)
