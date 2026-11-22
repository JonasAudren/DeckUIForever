local D = DeckUIForever

-------------------------------------------------------------------
-- Profiles: all settings under a name, and as a line of text to share
-------------------------------------------------------------------
-- Owner 2026-11-18: "Profile einbauen, mit denen man seine Einstellungen
-- speichern kann und auch einfach mit anderen teilen".
--
-- A profile is a copy of the settings of the hub and of every module that
-- is loaded when it is saved: DeckUIForeverDB and the modules'
-- DeckUIForever<Module>DB, perDevice (both devices, places on screen
-- included) and all. What is data and not a setting stays out (HUB_SKIP,
-- MODULE_SKIP): auction prices, the characters of the week overview,
-- waypoints, the error list, the device override of this machine. The
-- profiles live in DeckUIForeverDB.profiles[name] = { saved, addon, data },
-- data = { Hub = {...}, Orbs = {...}, ... } - account wide, like the rest.
--
-- Loading replaces: every setting key of a database is cleared and the
-- profile's are written, so what the profile does not carry falls back to
-- its default at the reload that follows. A module the profile has
-- settings for and switches on is loaded first - a module's saved table
-- exists only once the game has loaded the addon, and only a loaded
-- addon's table is written to disk. Modules the profile knows nothing
-- about keep what they have. What stood before the load is kept as the
-- profile BACKUP, so a load can be taken back.
--
-- Sharing: the profile as text, "DFP1" + "z" (deflated by C_EncodingUtil,
-- when the client has it and the round trip is clean) or "p" (plain) +
-- base64. The text is never run as code: Write/Read below are a format of
-- our own (booleans, numbers, strings, tables), read with limits on size
-- and depth. An imported profile is stored, not loaded - and on a load
-- a value whose type differs from the one in use is dropped, so a broken
-- or hand-made text cannot put a string where a module computes.
-------------------------------------------------------------------
local ADDON = "DeckUIForever"
local PREFIX = "DFP1"
local BACKUP = "Before the last load"
local MAX_NAME = 32
local MAX_TEXT = 400000      -- characters of pasted text we look at
local MAX_DEPTH = 8

local HUB_SKIP = {
    profiles = true,
    -- what this machine or this account has collected
    errors = true, errorSession = true, ahPrices = true, ahLastScan = true, alts = true, mailRecent = true,
    restockItems = true, barLayouts = true, editLayouts = true, apiProbe = true,
    -- this machine's state, and what is kept to be put back
    device = true, deckTest = true, plateCVars = true, plateNameOnly = true, migratedCrossPC = true,
}
local MODULE_SKIP = {
    Spec = { groupSets = true },
    Bags = { trackedItems = true },
    Questing = { ignoredNPCs = true },
    Week = { chars = true, weeklies = true, dailies = true, hidden = true, recorded = true },
    Nav = { waypoints = true },
}
local NO_SKIP = {}

local function DBName(key) return "DeckUIForever" .. key .. "DB" end
local function SkipFor(key) return key == "Hub" and HUB_SKIP or MODULE_SKIP[key] or NO_SKIP end

-------------------------------------------------------------------
-- Tables: a plain copy, a text of it, and back
-------------------------------------------------------------------
local function KeyOK(k)
    local t = type(k)
    return t == "string" or (t == "number" and k == k)
end

-- booleans, numbers, strings and tables of them; anything else is left out
local function Copy(v, skip, depth)
    local t = type(v)
    if t == "boolean" or t == "string" then return v end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        return v
    end
    if t ~= "table" then return nil end
    depth = depth or 1
    if depth > MAX_DEPTH then return nil end
    local out = {}
    for k, x in pairs(v) do
        if KeyOK(k) and not (skip and skip[k]) then
            out[k] = Copy(x, nil, depth + 1)
        end
    end
    return out
end

local function Number(v)
    if v == math.floor(v) and v > -1e15 and v < 1e15 then return ("%.0f"):format(v) end
    return ("%.17g"):format(v)
end

-- T, F, N<number>;, S<length>:<bytes>, { key value ... }
local function Write(out, v)
    local t = type(v)
    if t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "number" then
        out[#out + 1] = "N" .. Number(v) .. ";"
    elseif t == "string" then
        out[#out + 1] = "S" .. #v .. ":" .. v
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            local tx = type(x)
            if KeyOK(k) and (tx == "boolean" or tx == "number" or tx == "string" or tx == "table") then
                Write(out, k)
                Write(out, x)
            end
        end
        out[#out + 1] = "}"
    end
end

-- value and the position after it, or nil and what is wrong
local function Read(s, pos, depth)
    local c = s:sub(pos, pos)
    if c == "T" then return true, pos + 1 end
    if c == "F" then return false, pos + 1 end
    if c == "N" then
        local _, last, text = s:find("^([%d%.eE+-]+);", pos + 1)
        local n = text and tonumber(text)
        if not n or n ~= n or n == math.huge or n == -math.huge then return nil, "a number is broken" end
        return n, last + 1
    end
    if c == "S" then
        local _, last, text = s:find("^(%d+):", pos + 1)
        local len = text and #text <= 7 and tonumber(text)
        if not len or last + len > #s then return nil, "a text is cut off" end
        return s:sub(last + 1, last + len), last + len + 1
    end
    if c == "{" then
        if depth > MAX_DEPTH + 2 then return nil, "nested too deep" end
        local out = {}
        pos = pos + 1
        while true do
            if pos > #s then return nil, "the end is missing" end
            if s:sub(pos, pos) == "}" then return out, pos + 1 end
            local k, v
            k, pos = Read(s, pos, depth + 1)
            if k == nil then return nil, pos end
            if not KeyOK(k) then return nil, "a name is broken" end
            v, pos = Read(s, pos, depth + 1)
            if v == nil then return nil, pos end
            out[k] = v
        end
    end
    return nil, "not a profile"
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_VALUE = {}
for i = 1, 64 do B64_VALUE[B64:byte(i)] = i - 1 end

local function Encode64(s)
    local out, n = {}, 0
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local v = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(v / 262144)
        local c2 = math.floor(v / 4096) % 64
        local c3 = math.floor(v / 64) % 64
        local c4 = v % 64
        n = n + 1
        out[n] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function Decode64(s)
    s = s:gsub("=+$", "")
    if #s % 4 == 1 then return nil end
    local out, n = {}, 0
    for i = 1, #s, 4 do
        local a, b, c, d = s:byte(i, i + 3)
        a, b = B64_VALUE[a], B64_VALUE[b]
        if not (a and b) then return nil end
        local c6, d6 = c and B64_VALUE[c], d and B64_VALUE[d]
        if (c and not c6) or (d and not d6) then return nil end
        local v = a * 262144 + b * 4096 + (c6 or 0) * 64 + (d6 or 0)
        n = n + 1
        local x, y, z = math.floor(v / 65536), math.floor(v / 256) % 256, v % 256
        if d6 then
            out[n] = string.char(x, y, z)
        elseif c6 then
            out[n] = string.char(x, y)
        else
            out[n] = string.char(x)
        end
    end
    return table.concat(out)
end

-- the client's deflate, when it has one (retail's C_EncodingUtil)
local function Deflate(text)
    local E = C_EncodingUtil
    if not (E and E.CompressString and E.DecompressString) then return nil end
    local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    local ok, packed = pcall(E.CompressString, text, method)
    if not ok or type(packed) ~= "string" or #packed == 0 then return nil end
    -- only a text that comes back whole is handed out
    local ok2, back = pcall(E.DecompressString, packed, method)
    if ok2 and back == text then return packed end
    return nil
end

local function Inflate(packed)
    local E = C_EncodingUtil
    if not (E and E.DecompressString) then return nil, "this game cannot unpack a compressed profile" end
    local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    local ok, text = pcall(E.DecompressString, packed, method)
    if not ok or type(text) ~= "string" then return nil, "the text is damaged" end
    return text
end

local function Pack(value)
    local out = {}
    Write(out, value)
    local text = table.concat(out)
    local packed = Deflate(text)
    if packed then return PREFIX .. "z" .. Encode64(packed) end
    return PREFIX .. "p" .. Encode64(text)
end

local function Unpack(text)
    if type(text) ~= "string" then return nil, "nothing to read" end
    if #text > MAX_TEXT then return nil, "the text is too long for a profile" end
    text = text:gsub("%s+", "")
    if text == "" then return nil, "paste the profile's text first" end
    local kind, body = text:match("^" .. PREFIX .. "([zp])([A-Za-z0-9+/=]+)$")
    if not kind then return nil, "this is not a DeckUIForever profile (it starts with " .. PREFIX .. ")" end
    local raw = Decode64(body)
    if not raw then return nil, "the text is damaged - copy all of it" end
    if kind == "z" then
        local why
        raw, why = Inflate(raw)
        if not raw then return nil, why end
    end
    if #raw > MAX_TEXT * 4 then return nil, "the profile is too large" end
    local value, pos = Read(raw, 1, 1)
    if value == nil then return nil, "the text is damaged (" .. tostring(pos) .. ")" end
    if pos ~= #raw + 1 then return nil, "the text is damaged (something follows the end)" end
    return value
end

-- for a test outside the game (tools): the pieces that need no client
D.ProfileCodec = { Copy = Copy, Write = Write, Read = Read, Encode64 = Encode64, Decode64 = Decode64,
                   Pack = Pack, Unpack = Unpack }

-------------------------------------------------------------------
-- The store
-------------------------------------------------------------------
local function Store()
    DeckUIForeverDB.profiles = DeckUIForeverDB.profiles or {}
    return DeckUIForeverDB.profiles
end

local function CleanName(name)
    name = tostring(name or ""):gsub("|", ""):gsub("[%c]", " "):gsub("%s+", " ")
    name = strtrim(name)
    if #name > MAX_NAME then name = strtrim(name:sub(1, MAX_NAME)) end
    return name
end

-- the saved profiles' names, A to Z, the backup last
function D.ProfileNames()
    local names = {}
    for name in pairs(Store()) do
        if name ~= BACKUP then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    if Store()[BACKUP] then names[#names + 1] = BACKUP end
    return names
end

local function ModuleLoaded(key)
    local addon = D.MODULE_ADDONS[key]
    return addon ~= nil and C_AddOns.IsAddOnLoaded(addon)
end

-- the settings of now: the hub's and every loaded module's
local function Snapshot()
    local data = { Hub = Copy(DeckUIForeverDB, HUB_SKIP) }
    for _, key in ipairs(D.MODULE_ORDER) do
        local db = _G[DBName(key)]
        if type(db) == "table" and ModuleLoaded(key) then
            data[key] = Copy(db, SkipFor(key))
        end
    end
    return data
end

local function Version()
    return C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
end

function D.SaveProfile(name)
    name = CleanName(name)
    if name == "" then return nil end
    Store()[name] = { saved = time(), addon = Version(), data = Snapshot() }
    return name
end

function D.DeleteProfile(name)
    Store()[name] = nil
end

-- "3 modules on, saved 2026-11-18, version 1.5.4"
function D.ProfileInfo(name)
    local p = Store()[name]
    if not p then return "" end
    local on, hub = 0, p.data and p.data.Hub
    for _, key in ipairs(D.MODULE_ORDER) do
        if hub and type(hub.modules) == "table" and hub.modules[key] and D.ModuleExists(key) then on = on + 1 end
    end
    return ("%d modules on, saved %s, version %s"):format(on,
        p.saved and date("%Y-%m-%d", p.saved) or "?", tostring(p.addon or "?"))
end

-- the profile's settings into a database: what it had is cleared first
local function Fill(db, src, skip)
    local was = {}
    for k, v in pairs(db) do
        if KeyOK(k) and not skip[k] then
            was[k] = type(v)
            db[k] = nil
        end
    end
    for k, v in pairs(src) do
        -- a value of another kind than the one in use stays out
        if KeyOK(k) and not skip[k] and (was[k] == nil or was[k] == type(v)) then
            db[k] = Copy(v)
        end
    end
end

function D.LoadProfile(name)
    local p = Store()[name]
    local data = p and p.data
    if type(data) ~= "table" then return false end
    if InCombatLockdown() then
        print("DeckUIForever: not in combat - try again after the fight.")
        return false
    end
    -- what stands now, to take the load back
    if name ~= BACKUP then
        Store()[BACKUP] = { saved = time(), addon = Version(), data = Snapshot() }
    end
    local hub = type(data.Hub) == "table" and data.Hub or nil
    if hub then
        Fill(DeckUIForeverDB, hub, HUB_SKIP)
        if type(DeckUIForeverDB.modules) ~= "table" then DeckUIForeverDB.modules = {} end
    end
    for _, key in ipairs(D.MODULE_ORDER) do
        local src = data[key]
        if type(src) == "table" and D.ModuleExists(key) then
            -- its saved table is the game's to load: the module first
            if not ModuleLoaded(key) and DeckUIForeverDB.modules[key] and D.ModuleAllowed(key) then
                D.LoadModule(key)
            end
            if ModuleLoaded(key) then
                local dbName = DBName(key)
                if type(_G[dbName]) ~= "table" then _G[dbName] = {} end
                Fill(_G[dbName], src, SkipFor(key))
            end
        end
    end
    C_UI.Reload()
    return true
end

-- the profile as a line of text
function D.ExportProfile(name)
    local p = Store()[name]
    if not p then return nil end
    return Pack({ v = 1, name = name, addon = p.addon, saved = p.saved, data = p.data })
end

-- stores the text's profile under its name (a free one); the name, or nil
-- and what is wrong
function D.ImportProfile(text)
    local value, why = Unpack(text)
    if value == nil then return nil, why end
    if type(value) ~= "table" or value.v ~= 1 or type(value.data) ~= "table" then
        return nil, "this profile was made by a newer DeckUIForever - update first"
    end
    local data, count = {}, 0
    for _, key in ipairs({ "Hub", unpack(D.MODULE_ORDER) }) do
        if type(value.data[key]) == "table" then
            data[key] = Copy(value.data[key], SkipFor(key))
            count = count + 1
        end
    end
    if count == 0 then return nil, "the profile is empty" end
    local base = CleanName(type(value.name) == "string" and value.name or "")
    if base == "" or base == BACKUP then base = "Imported profile" end
    local name, n = base, 1
    while Store()[name] do
        n = n + 1
        local tail = " (" .. n .. ")"
        name = strtrim(base:sub(1, MAX_NAME - #tail)) .. tail
    end
    Store()[name] = {
        saved = type(value.saved) == "number" and value.saved or time(),
        addon = type(value.addon) == "string" and value.addon:sub(1, 16) or "?",
        data = data,
    }
    return name
end

-------------------------------------------------------------------
-- The text window: a profile to copy, or a field to paste one into
-------------------------------------------------------------------
local window
local selected       -- the profile the page's buttons act on

local function RefreshPage()
    local c = D.panel and D.panel.contents and D.panel.contents.Profiles
    if c and c.built then D.RefreshWidgets(c) end
end

local function BuildWindow()
    local w = CreateFrame("Frame", "DeckUIForeverProfileWindow", UIParent)
    w:SetSize(520, 300)
    w:SetPoint("CENTER", 0, 40)
    w:SetFrameStrata("FULLSCREEN_DIALOG")
    w:SetToplevel(true)
    w:EnableMouse(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", w.StartMoving)
    w:SetScript("OnDragStop", w.StopMovingOrSizing)
    D.FlatBox(w)
    tinsert(UISpecialFrames, "DeckUIForeverProfileWindow")

    w.title = w:CreateFontString(nil, "OVERLAY")
    w.title:SetFont(D.FONT, 15, "OUTLINE")
    w.title:SetPoint("TOPLEFT", 14, -12)
    w.title:SetTextColor(1, 0.82, 0)

    w.hint = w:CreateFontString(nil, "OVERLAY")
    w.hint:SetFont(D.FONT, 11, "OUTLINE")
    w.hint:SetPoint("TOPLEFT", 14, -34)
    w.hint:SetPoint("TOPRIGHT", -14, -34)
    w.hint:SetJustifyH("LEFT")
    w.hint:SetTextColor(0.7, 0.7, 0.7)

    local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local box = CreateFrame("Frame", nil, w)
    box:SetPoint("TOPLEFT", 12, -70)
    box:SetPoint("BOTTOMRIGHT", -30, 46)
    D.FlatBox(box, 1, 0.25)

    local scroll = CreateFrame("ScrollFrame", "DeckUIForeverProfileScroll", w, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", box, 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, -6, 6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetFont(D.FONT, 11, "")
    edit:SetWidth(460)
    edit:SetScript("OnEscapePressed", function() w:Hide() end)
    -- a profile on show is read only: whatever is typed, the text comes back
    edit:SetScript("OnTextChanged", function(self, user)
        if user and w.mode == "export" then
            self:SetText(w.text or "")
            self:HighlightText()
        end
    end)
    scroll:SetScrollChild(edit)
    -- a click anywhere in the field lands in the text
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    w.edit = edit

    w.status = w:CreateFontString(nil, "OVERLAY")
    w.status:SetFont(D.FONT, 11, "OUTLINE")
    w.status:SetPoint("BOTTOMLEFT", 150, 18)
    w.status:SetPoint("BOTTOMRIGHT", -14, 18)
    w.status:SetJustifyH("LEFT")
    w.status:SetTextColor(1, 0.4, 0.4)

    w.action = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    w.action:SetSize(130, 24)
    w.action:SetPoint("BOTTOMLEFT", 12, 12)
    w.action:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
    D.FlattenButton(w.action)
    w.action:SetScript("OnClick", function()
        if w.mode == "export" then
            edit:SetFocus()
            edit:HighlightText()
            return
        end
        local name, why = D.ImportProfile(edit:GetText())
        if not name then
            w.status:SetText("Not imported: " .. tostring(why) .. ".")
            return
        end
        selected = name
        w:Hide()
        RefreshPage()
        print(("DeckUIForever: profile \"%s\" imported. Nothing has changed yet - load it on the Profiles page (/df profiles)."):format(name))
    end)

    w:Hide()
    if D.GamepadWindow then D.GamepadWindow(w, { close = close }) end
    return w
end

local function ShowWindow(mode, name)
    window = window or BuildWindow()
    local w = window
    w.mode = mode
    w.status:SetText("")
    if mode == "export" then
        w.text = D.ExportProfile(name) or ""
        w.title:SetText(("Share \"%s\""):format(name))
        w.hint:SetText("This text is the whole profile. Copy it (Ctrl+A, Ctrl+C) and send it to a friend - in a chat program, a forum post or a text file. They paste it under \"Import a profile\".")
        w.action:SetText("Select all")
        w.edit:SetText(w.text)
        w:Show()
        w.edit:SetFocus()
        w.edit:HighlightText()
    else
        w.text = nil
        w.title:SetText("Import a profile")
        w.hint:SetText("Paste the text you were given into the field (click it, Ctrl+V) and press Import. The profile is only added to your list; your settings change when you load it.")
        w.action:SetText("Import")
        w.edit:SetText("")
        w:Show()
        w.edit:SetFocus()
    end
end

-------------------------------------------------------------------
-- The page
-------------------------------------------------------------------
local function Selected()
    local names = D.ProfileNames()
    if selected and Store()[selected] then return selected, names end
    selected = names[1]
    return selected, names
end

local function Build(c)
    local f = D.Flow(c)
    c.widgets = c.widgets or {}

    f:Hint("A profile is a copy of all your DeckUIForever settings: which modules are on, every option, and where the frames stand on the PC and on the Steam Deck. Save one before you try things out, keep one for each way of playing, or hand one to a friend as a text.")

    f:Label("Save")
    local nameBox = f:Add(30, function(parent, y)
        local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        edit:SetSize(250, 20)
        edit:SetPoint("TOP", 0, y - 2)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(MAX_NAME)
        edit:SetFontObject(ChatFontNormal)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        D.Tip(edit, "The profile's name", "For example \"Healer\", \"Raid\" or \"Steam Deck\". Leave it empty and the profile is named after today's date.")
        return edit
    end)
    local function Save()
        local name = CleanName(nameBox:GetText())
        if name == "" then name = "Profile " .. date("%Y-%m-%d %H:%M") end
        local function Do()
            selected = D.SaveProfile(name) or selected
            nameBox:SetText("")
            nameBox:ClearFocus()
            D.RefreshWidgets(c)
            print(("DeckUIForever: your settings are saved as the profile \"%s\"."):format(name))
        end
        if Store()[name] then
            D.Dialog({ width = 360, accept = "Replace",
                       text = ("A profile named \"%s\" exists. Replace it with your settings of now?"):format(name),
                       onAccept = Do })
        else
            Do()
        end
    end
    nameBox:SetScript("OnEnterPressed", Save)
    f:Button("Save my settings", Save,
        "Keeps everything as it is right now under the name above. Type the name of a profile you have to replace it. Settings of a module that is switched off are not part of it.")

    f:Label("Your profiles")
    local function PickText()
        local name, names = Selected()
        if not name then return "No profile saved yet" end
        local at = 1
        for i, n in ipairs(names) do
            if n == name then at = i end
        end
        return ("%s (%d of %d)"):format(name, at, #names)
    end
    local pick = f:Button(PickText(), function()
        local name, names = Selected()
        for i, n in ipairs(names) do
            if n == name then
                selected = names[i % #names + 1]
                break
            end
        end
        D.RefreshWidgets(c)
    end, "The profile the buttons below act on. Click to step through your profiles.")
    pick:GetFontString():SetFont(D.FONT, 13, "OUTLINE")
    local info = f:Hint(" ")
    function pick:Refresh()
        self:SetText(PickText())
        local name = Selected()
        info:SetText(name and D.ProfileInfo(name) or "Save your settings above, or import a profile below.")
    end
    table.insert(c.widgets, pick)

    f:Pair(
        { text = "Load", title = "Load this profile",
          tip = "Replaces all your DeckUIForever settings with the profile's and reloads the game. What you have now is kept as the profile \"" .. BACKUP .. "\", so you can go back.",
          onClick = function()
              local name = Selected()
              if not name then return end
              D.Dialog({
                  width = 360, accept = "Load and reload",
                  text = ("Load the profile \"%s\"?\n\nAll your DeckUIForever settings are replaced by the profile's: modules, options and the places of the frames. Your settings of now are kept as the profile \"%s\".\n\nThe game reloads to apply it."):format(name, BACKUP),
                  onAccept = function() D.LoadProfile(name) end,
              })
          end },
        { text = "Share", title = "Share this profile",
          tip = "Shows the profile as a text to copy. Anyone with DeckUIForever can import it.",
          onClick = function()
              local name = Selected()
              if name then ShowWindow("export", name) end
          end })
    f:Pair(
        { text = "Delete", title = "Delete this profile",
          tip = "Removes the profile from your list. Your settings in use stay as they are.",
          onClick = function()
              local name = Selected()
              if not name then return end
              D.Dialog({ width = 360, accept = "Delete",
                         text = ("Delete the profile \"%s\"? Your settings in use stay as they are."):format(name),
                         onAccept = function()
                             D.DeleteProfile(name)
                             selected = nil
                             D.RefreshWidgets(c)
                         end })
          end })

    f:Label("A profile from someone else")
    f:Button("Import a profile", function() ShowWindow("import") end,
        "Opens a field to paste a profile's text into. The profile is added to your list; nothing changes until you load it.")
    f:Hint("A profile holds settings only. Your waypoints, tracked items, auction prices, the week overview's characters and the device you play on are never part of it, and loading one leaves them alone.")
end

D.panel:AddTab("Profiles", {
    title = "Profiles",
    build = Build,
})
