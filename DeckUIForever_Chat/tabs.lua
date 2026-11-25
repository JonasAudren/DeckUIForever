local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Thin coloured tabs over the chat (2026-11-25)
-------------------------------------------------------------------
-- Owner's wish: "dünne farbige Reiter über dem Chat ... nach der Farbe
-- des Chats anordnen, Grün = Gildenchat, Blau = Gruppe", as an option
-- beside Blizzard's own tabs ("General", "Combat Log").
--
-- A row of our own buttons over the main chat window, one per kind of
-- chat, each in that chat's colour (read from ChatTypeInfo, so colours
-- picked in the chat's settings are followed): All, Guild, Party, Raid,
-- Whisper, Say, Channels. Behind them a grey tab for every other window
-- docked to the main one (the combat log, windows of the player's own).
--
-- Blizzard's chat is not rebuilt: no window is made, and its saved
-- settings are not touched. A tab is a view of the one main window:
--   * ChatFrame1's AddMessage is wrapped. Blizzard's message handler
--     passes the event's name (eighth argument) and the chat type's id
--     (fifth), so every line is sorted into a group (GroupOf: event, id,
--     colour) and kept in a list of ours (the last LINES_MAX).
--   * Picking a tab clears the window and writes the lines of that group
--     back from the list, through the function that was wrapped. "All"
--     writes everything back but the whispers. A line that arrives for another group is
--     kept and lights that group's tab.
--   * A line without type and colour (print, addon messages) shows in
--     every tab, so a slash command's answer is never swallowed.
-- A secret text (a fight, an instance) is never read: it is stored and
-- handed on as it came.
-- Blizzard's tabs of the docked windows are held at alpha 0 (ns.Hold,
-- the side buttons' way); floating windows keep theirs.
-- Untested in game at the time of writing.
-------------------------------------------------------------------
local db = function() return DeckUIForeverChatDB end
local Secret = ns.Secret

local LINES_MAX = 600

-- chat type (digits at the end cut off: CHANNEL7 -> CHANNEL) -> group
local TYPE_GROUP = {
    GUILD = "guild", OFFICER = "guild", GUILD_ACHIEVEMENT = "guild",
    PARTY = "party", PARTY_LEADER = "party", INSTANCE_CHAT = "party", INSTANCE_CHAT_LEADER = "party",
    RAID = "raid", RAID_LEADER = "raid", RAID_WARNING = "raid",
    WHISPER = "whisper", WHISPER_INFORM = "whisper", BN_WHISPER = "whisper", BN_WHISPER_INFORM = "whisper",
    SAY = "say", YELL = "say", EMOTE = "say", TEXT_EMOTE = "say",
    MONSTER_SAY = "say", MONSTER_YELL = "say", MONSTER_EMOTE = "say",
    CHANNEL = "channel", COMMUNITIES_CHANNEL = "channel",
}

-- the tabs in their order; `color` names the chat type whose colour the
-- tab wears, `say` the chat type a click starts typing in
local TABS = {
    { key = "all",     label = "All",      tip = "Every line except whispers - those have their own tab." },
    { key = "guild",   label = "Guild",    color = "GUILD",    say = "GUILD",
      tip = "The guild's and the officers' lines only." },
    { key = "party",   label = "Party",    color = "PARTY",    say = "PARTY",
      tip = "Your party's lines only, the instance group's too." },
    { key = "raid",    label = "Raid",     color = "RAID",     say = "RAID",
      tip = "The raid's lines and raid warnings only." },
    { key = "whisper", label = "Whisper",  color = "WHISPER",
      tip = "Whispers only, the ones you get and the ones you send." },
    { key = "say",     label = "Say",      color = "SAY",      say = "SAY",
      tip = "What is said, yelled and emoted near you." },
    { key = "channel", label = "Channels", color = "CHANNEL1",
      tip = "General, Trade, LookingForGroup and the other numbered channels." },
}
local FALLBACK = {
    all = { 1, 0.82, 0.3 }, guild = { 0.25, 1, 0.25 }, party = { 0.67, 0.67, 1 }, raid = { 1, 0.5, 0 },
    whisper = { 1, 0.5, 1 }, say = { 1, 1, 1 }, channel = { 1, 0.75, 0.75 },
}
local GREY = { 0.65, 0.65, 0.65 }

local main                 -- ChatFrame1
local prev                 -- what its AddMessage was before our wrap
local lines = {}           -- { group = "guild"|"other"|nil, n = count, ...arguments }
local current = "all"      -- the picked group
local unread = {}          -- [group] = true: a line came while another tab was picked
local byId = {}            -- [ChatTypeInfo id] = group
local counts = {}          -- for /df chat
local bar, buttons, dockButtons = nil, {}, {}

-------------------------------------------------------------------
-- Sorting a line
-------------------------------------------------------------------
local function TypeColor(kind)
    local info = kind and ChatTypeInfo and ChatTypeInfo[kind]
    if info and type(info.r) == "number" then return info.r, info.g, info.b end
end

local function TabColor(def)
    local r, g, b = TypeColor(def.color)
    if r then return r, g, b end
    local c = FALLBACK[def.key] or GREY
    return c[1], c[2], c[3]
end

local colors = {}           -- { r, g, b, group } for every chat type that has a tab

local function ReadTypes()
    wipe(byId)
    wipe(colors)
    if type(ChatTypeInfo) ~= "table" then return end
    for kind, info in pairs(ChatTypeInfo) do
        if type(kind) == "string" and type(info) == "table" then
            local group = TYPE_GROUP[(kind:gsub("%d+$", ""))]
            if type(info.id) == "number" then byId[info.id] = group or "other" end
            if group and type(info.r) == "number" and type(info.g) == "number" and type(info.b) == "number" then
                colors[#colors + 1] = { info.r, info.g, info.b, group }
            end
        end
    end
end

local function Near(a, b) return math.abs(a - b) < 0.02 end

-- "guild", ..., "other" (a typed line no tab has: system, loot, ...) or
-- nil (untyped: shown everywhere)
-- Three ways, the surest first (owner's first test, 2026-11-25: guild
-- lines stood in All and not in Guild, so the id alone does not carry it;
-- GetChatTypeIndex is the engine's and may hand two types one id):
--   1. the event's name. Blizzard's handler passes it for every line a
--      player wrote (ChatFrameOverrides.lua, MessageEventHandler:
--      AddMessage(msg, r, g, b, info.id, accessID, typeID, event, ...)).
--   2. the id, only where it names a group with a tab.
--   3. the colour, against every chat type that has a tab.
local last = {}   -- for /df chat: what the last coloured line brought
local how = { event = 0, id = 0, color = 0 }
local function GroupOf(r, g, b, id, event)
    if type(event) == "string" and not Secret(event) and event:sub(1, 9) == "CHAT_MSG_" then
        how.event = how.event + 1
        last.event = event
        return TYPE_GROUP[(event:sub(10):gsub("%d+$", ""))] or "other"
    end
    local typed = false
    if type(id) == "number" and not Secret(id) then
        typed = true
        local group = byId[id]
        if group and group ~= "other" then how.id = how.id + 1 return group end
    end
    if type(r) == "number" and type(g) == "number" and type(b) == "number"
        and not (Secret(r) or Secret(g) or Secret(b)) then
        last.r, last.g, last.b, last.id = r, g, b, (typed and id or type(id))
        for _, c in ipairs(colors) do
            if Near(r, c[1]) and Near(g, c[2]) and Near(b, c[3]) then how.color = how.color + 1 return c[4] end
        end
        return "other"
    end
    if typed then return "other" end
    return nil
end

-- "All" leaves the whispers out (owner 2026-11-25: "im All-Reiter keine
-- Whisper mehr bitte"): they have their tab, which lights up, and the
-- whisper windows.
local function Fits(group)
    if group == nil then return true end
    if current == "all" then return group ~= "whisper" end
    return group == current
end

-------------------------------------------------------------------
-- The wrap and the replay
-------------------------------------------------------------------
local Paint   -- below

local function Keep(group, ...)
    local line = { ... }
    line.n = select("#", ...)
    line.group = group
    lines[#lines + 1] = line
    if #lines > LINES_MAX + 100 then
        local cut = #lines - LINES_MAX
        local kept = {}
        for i = cut + 1, #lines do kept[#kept + 1] = lines[i] end
        lines = kept
    end
end

local function Wrap()
    if prev or not main then return end
    prev = main.AddMessage
    main.AddMessage = function(self, text, r, g, b, id, ...)
        local o = db()
        if not (o and o.tabs) then return prev(self, text, r, g, b, id, ...) end
        -- after the id come accessID, typeID and the event's name
        local ok, group = pcall(GroupOf, r, g, b, id, (select(3, ...)))
        if not ok then group = nil end
        Keep(group, text, r, g, b, id, ...)
        local name = group or "untyped"
        counts[name] = (counts[name] or 0) + 1
        if Fits(group) then return prev(self, text, r, g, b, id, ...) end
        if group ~= "other" and not unread[group] then
            unread[group] = true
            if Paint then Paint() end
        end
    end
end

local replayed, replayFailed, replayError = 0, 0, nil   -- for /df chat

-- the window again, with the lines of the picked group
local function Replay()
    if not (prev and main) then return end
    if #lines == 0 then return end   -- nothing of ours to write back: leave what stands
    main:Clear()
    local max = main.GetMaxLines and main:GetMaxLines() or 128
    local first, shown = 1, 0
    for i = #lines, 1, -1 do
        if Fits(lines[i].group) then
            shown = shown + 1
            if shown >= max then first = i break end
        end
    end
    for i = first, #lines do
        local line = lines[i]
        if Fits(line.group) then
            local ok, err = pcall(prev, main, unpack(line, 1, line.n))
            replayed = replayed + 1
            if not ok then
                replayFailed = replayFailed + 1
                replayError = tostring(err)
            end
        end
    end
    if main.ScrollToBottom then main:ScrollToBottom() end
end

-------------------------------------------------------------------
-- The docked windows
-------------------------------------------------------------------
local function Docked()
    local out = {}
    local list = GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES
    if type(list) == "table" then
        for _, frame in ipairs(list) do
            if frame ~= main then out[#out + 1] = frame end
        end
    end
    return out
end

local function Selected()
    if FCFDock_GetSelectedWindow and GENERAL_CHAT_DOCK then
        local ok, frame = pcall(FCFDock_GetSelectedWindow, GENERAL_CHAT_DOCK)
        if ok and frame then return frame end
    end
    return main
end

local function Select(frame)
    if Selected() == frame then return end
    if FCF_SelectDockFrame then
        pcall(FCF_SelectDockFrame, frame)
    elseif FCFDock_SelectWindow and GENERAL_CHAT_DOCK then
        pcall(FCFDock_SelectWindow, GENERAL_CHAT_DOCK, frame)
    end
end

local function WindowName(frame)
    local tab = _G[frame:GetName() .. "Tab"]
    local text = tab and tab.GetText and tab:GetText()
    if type(text) == "string" and text ~= "" and not Secret(text) then return text end
    return frame.name or frame:GetName()
end

-------------------------------------------------------------------
-- Typing: a click on Guild starts the input line in /g
-------------------------------------------------------------------
local function CanSay(kind)
    if kind == "GUILD" then return IsInGuild and IsInGuild() end
    if kind == "PARTY" then return IsInGroup and IsInGroup() end
    if kind == "RAID" then return IsInRaid and IsInRaid() end
    return true
end

local function SetTyping(kind)
    if not (kind and db().tabsType and CanSay(kind)) then return end
    local edit = _G[main:GetName() .. "EditBox"]
    if not edit then return end
    pcall(function()
        if edit.SetChatType then edit:SetChatType(kind) else edit:SetAttribute("chatType", kind) end
        if edit.SetStickyType then edit:SetStickyType(kind) else edit:SetAttribute("stickyType", kind) end
        if edit.UpdateHeader then
            edit:UpdateHeader()
        elseif ChatEdit_UpdateHeader then
            ChatEdit_UpdateHeader(edit)
        end
    end)
end

-------------------------------------------------------------------
-- The bar
-------------------------------------------------------------------
local function Scale() return ns.DeviceDB().tabScale or 1 end

local function PaintButton(button, r, g, b, picked, lit)
    local labels = db().tabLabels
    button.line:SetColorTexture(r, g, b, (picked or lit) and 1 or 0.55)
    button.line:SetHeight(picked and 3 or 2)
    button.wash:SetColorTexture(r, g, b, picked and 0.22 or (lit and 0.1 or 0))
    button.text:SetShown(labels and true or false)
    if picked or lit then
        button.text:SetTextColor(r, g, b, 1)
    else
        button.text:SetTextColor(r * 0.75, g * 0.75, b * 0.75, 0.8)
    end
    local h = labels and 15 or 7
    local w = labels and math.max(24, math.floor(button.text:GetStringWidth() + 12.5)) or 28
    button:SetSize(w, h)
end

local function MakeButton()
    local button = CreateFrame("Button", nil, bar)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.wash = button:CreateTexture(nil, "BACKGROUND")
    button.wash:SetAllPoints()
    button.line = button:CreateTexture(nil, "ARTWORK")
    button.line:SetPoint("BOTTOMLEFT")
    button.line:SetPoint("BOTTOMRIGHT")
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont(D.FONT, 10, "OUTLINE")
    button.text:SetPoint("CENTER", 0, 1)
    local over = button:CreateTexture(nil, "HIGHLIGHT")
    over:SetAllPoints()
    over:SetColorTexture(1, 1, 1, 0.08)
    return button
end

-- a right click anywhere on the bar: the menu Blizzard's own tab opens
local function BlizzardMenu(frame)
    local tab = _G[frame:GetName() .. "Tab"]
    local click = tab and tab:GetScript("OnClick")
    if click then pcall(click, tab, "RightButton") end
end

local function Pick(key)
    Select(main)
    unread[key] = nil
    if key ~= current then
        current = key
        Replay()
    end
    Paint()
end
ns.PickChatTab = Pick

local function Place()
    if not bar then return end
    local selected = Selected()
    local quick = CombatLogQuickButtonFrame_Custom
    local onLog = selected ~= main and selected == ChatFrame2 and quick and quick:IsShown()
    bar:ClearAllPoints()
    if onLog then
        -- the combat log carries its own row of filter buttons over the text
        bar:SetPoint("BOTTOMLEFT", quick, "TOPLEFT", -5, 2)
    else
        bar:SetPoint("BOTTOMLEFT", main, "TOPLEFT", -5, 5)
    end
end

function Paint()
    if not bar then return end
    local selected = Selected()
    local onMain = selected == main
    local x = 0
    for i, def in ipairs(TABS) do
        local button = buttons[i]
        local r, g, b = TabColor(def)
        button.text:SetText(def.label)
        PaintButton(button, r, g, b, onMain and current == def.key, unread[def.key])
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
        x = x + button:GetWidth() + 2
    end
    local docked = Docked()
    for i, frame in ipairs(docked) do
        local button = dockButtons[i]
        if not button then
            button = MakeButton()
            dockButtons[i] = button
            button:SetScript("OnClick", function(self, mouse)
                if not self.frame then return end
                if mouse == "RightButton" then BlizzardMenu(self.frame) return end
                Select(self.frame)
                Paint()
            end)
            button:SetScript("OnEnter", function(self)
                if not self.frame then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(WindowName(self.frame), 1, 0.82, 0)
                GameTooltip:AddLine("A chat window of its own. Right click: the window's menu.", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", GameTooltip_Hide)
        end
        button.frame = frame
        button.text:SetText(WindowName(frame))
        PaintButton(button, GREY[1], GREY[2], GREY[3], selected == frame, false)
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x + 6, 0)
        x = x + button:GetWidth() + 2
        button:Show()
    end
    for i = #docked + 1, #dockButtons do
        dockButtons[i].frame = nil
        dockButtons[i]:Hide()
    end
    bar:SetSize(math.max(x + 6, 10), db().tabLabels and 15 or 7)
    bar:SetScale(Scale())
    Place()
end

local function Build()
    if bar then return end
    bar = CreateFrame("Frame", "DeckChatTabs", UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel((main:GetFrameLevel() or 1) + 10)
    bar:SetSize(10, 15)
    for i, def in ipairs(TABS) do
        local button = MakeButton()
        buttons[i] = button
        button:SetScript("OnClick", function(_, mouse)
            if mouse == "RightButton" then BlizzardMenu(main) return end
            Pick(def.key)
            SetTyping(def.say)
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(def.label, TabColor(def))
            GameTooltip:AddLine(def.tip, 1, 1, 1, true)
            if def.say and db().tabsType then
                GameTooltip:AddLine("The input line then writes there.", 0.7, 0.7, 0.7, true)
            end
            GameTooltip:AddLine("Right click: the chat's own menu.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
    end
end

-------------------------------------------------------------------
-- Blizzard's tabs
-------------------------------------------------------------------
local function HoldTabs(on)
    ns.EachFrame(function(frame)
        local tab = _G[frame:GetName() .. "Tab"]
        if tab then
            -- a floating window keeps its tab: it is the handle to drag it by
            ns.Hold(tab, on and (frame == main or frame.isDocked) and true or false)
        end
    end)
end

-------------------------------------------------------------------
local pending = false
local function Later()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        if db() and db().tabs and bar then
            HoldTabs(true)
            Paint()
        end
    end)
end

local function Apply()
    main = main or ChatFrame1
    if not main then return end
    local on = db().tabs and true or false
    if on then
        ReadTypes()
        Wrap()
        Build()
        bar:Show()
        HoldTabs(true)
        Paint()
    else
        if bar then bar:Hide() end
        HoldTabs(false)
        if current ~= "all" then
            current = "all"
            Replay()
        end
        wipe(unread)
    end
end
ns.ApplyTabs = Apply

local function Init()
    -- Blizzard picks, docks and undocks windows on its own
    for _, name in ipairs({ "FCFDock_SelectWindow", "FCF_DockFrame", "FCF_UnDockFrame", "FCF_Close",
                            "FCF_SetWindowName" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, Later) end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UPDATE_CHAT_COLOR")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_CHAT_COLOR" then
            if db() and db().tabs then ReadTypes() Later() end
        else
            C_Timer.After(1.1, function() if db() and db().tabs then Apply() end end)
        end
    end)
end

local function Print()
    local parts = {}
    for name, n in pairs(counts) do parts[#parts + 1] = name .. " " .. n end
    table.sort(parts)
    local ids = 0
    for _ in pairs(byId) do ids = ids + 1 end
    print(("  tabs %s: showing %s, %d lines kept, %d chat types known, %d docked windows; lines by group: %s"):format(
        db().tabs and "ours" or "Blizzard's", current, #lines, ids, #Docked(),
        #parts > 0 and table.concat(parts, ", ") or "none yet"))
    print(("  tabs: sorted by event %d, by id %d, by colour %d (last event %s); written back %d lines, %d failed%s"):format(
        how.event, how.id, how.color, tostring(last.event), replayed, replayFailed,
        replayError and (": " .. replayError) or ""))
    local guild = ChatTypeInfo and ChatTypeInfo.GUILD
    print(("  tabs: last coloured line %s / %s / %s, fifth argument %s; GUILD is %s / %s / %s, id %s, %d colours known"):format(
        tostring(last.r), tostring(last.g), tostring(last.b), tostring(last.id),
        tostring(guild and guild.r), tostring(guild and guild.g), tostring(guild and guild.b),
        tostring(guild and guild.id), #colors))
end

ns.pieces.tabs = { Init = Init, Apply = Apply, Print = Print }
