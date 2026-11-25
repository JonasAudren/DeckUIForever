local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Whisper windows: a small chat window per conversation
-------------------------------------------------------------------
-- Owner's wish (2026-11-24): "kleine Chatfenster für Whisper, die
-- aufgehen". A whisper - one you get or one you send - opens a small
-- window of ours with that conversation alone and a line to answer in.
-- Blizzard's chat is not touched: the whisper still shows there too.
--
--   talks[key]   one conversation: the lines of this session (KEEP at
--                most), who to answer. key is the sender's full name, or
--                "bn<id>" for a Battle.net friend.
--   windows[i]   MAX windows, stacked upwards from the movable anchor
--                "Whisper windows". A further conversation takes the
--                window that was quiet the longest; its lines are kept and
--                come back when that conversation goes on.
--                Each window can be dragged by its title bar and keeps
--                that place (owner, the same day: "frei verschiebbar").
--
-- Secret values (a fight, an instance): a secret sender cannot name a
-- window, so that whisper stays in Blizzard's chat only. A secret text is
-- handed to the window unread; if the window does not take it, a note
-- stands in its place.
-- The answer is sent on Enter, a key press, as the game wants it.
-------------------------------------------------------------------
local MAX, W, H, GAP, KEEP, BAR = 4, 300, 150, 6, 60, 18
local db = function() return DeckUIForeverChatDB end
local Secret = ns.Secret

local anchor = CreateFrame("Frame", "DeckChatWhispers", UIParent)
anchor:SetSize(W, H)
anchor.defaultPoint = { "LEFT", UIParent, "LEFT", 40, 40 }
anchor:SetPoint(unpack(anchor.defaultPoint))

local talks, windows, waiting = {}, {}, {}
local opened, hidden = 0, 0

local IN, OUT, NOTE = { 1, 0.78, 1 }, { 0.7, 0.7, 0.7 }, { 1, 0.5, 0.3 }

local function Stamp() return "|cff808080" .. date("%H:%M") .. "|r " end

-------------------------------------------------------------------
-- Sending
-------------------------------------------------------------------
local AddLine   -- below

local function Send(talk, text)
    text = strtrim(text or "")
    if not talk or text == "" then return end
    local ok, err
    if talk.bn then
        local send = (C_BattleNet and C_BattleNet.SendWhisper) or BNSendWhisper
        if not send then
            ok, err = false, "no Battle.net whisper in this game"
        else
            ok, err = pcall(send, talk.bn, text)
        end
    else
        local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
        ok, err = pcall(send, text, "WHISPER", nil, talk.name)
    end
    -- a sent line comes back as the game's own "to ..." event and is added there
    if not ok then AddLine(talk, "Not sent: " .. tostring(err), NOTE) end
end

-------------------------------------------------------------------
-- The windows
-------------------------------------------------------------------
-- A window dragged by its title bar keeps that place (per device and
-- window number, in UIParent's units so a new size does not shift it);
-- the others stack at the anchor.
local function Places()
    local d = ns.DeviceDB()
    d.whisperPlaces = d.whisperPlaces or {}
    return d.whisperPlaces
end

local function Restack()
    local places, n = Places(), 0
    for i = 1, MAX do
        local w = windows[i]
        if w and w:IsShown() then
            local p, scale = places[i], w:GetScale()
            w:ClearAllPoints()
            if p and scale and scale > 0 then
                w:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p[1] / scale, p[2] / scale)
            else
                w:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, n * (H + GAP))
                n = n + 1
            end
        end
    end
end

local function Dropped(w, i)
    w:StopMovingOrSizing()
    local left, bottom, scale = w:GetLeft(), w:GetBottom(), w:GetScale()
    if left and bottom and scale then Places()[i] = { left * scale, bottom * scale } end
    Restack()
end

function ns.ResetWhisperPlaces()
    wipe(Places())
    Restack()
end

local function Close(w)
    w.talk = nil
    w.edit:ClearFocus()
    w:Hide()
    Restack()
end

local function Build(i)
    local w = CreateFrame("Frame", "DeckChatWhisper" .. i, anchor)
    w:SetSize(W, H)
    w:SetFrameStrata("MEDIUM")
    w:EnableMouse(true)   -- a click on the window is not a click into the world
    D.FlatBox(w, 0.85, 0.3)

    local bar = w:CreateTexture(nil, "BACKGROUND", nil, -7)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(BAR)
    bar:SetColorTexture(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], 0.12)

    w.title = w:CreateFontString(nil, "OVERLAY")
    w.title:SetFont(D.FONT, 12, "OUTLINE")
    w.title:SetPoint("TOPLEFT", 6, -4)
    w.title:SetPoint("TOPRIGHT", -24, -4)
    w.title:SetJustifyH("LEFT")
    w.title:SetWordWrap(false)

    -- the title bar is the handle: drag it and the window goes anywhere
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    local grip = CreateFrame("Frame", nil, w)
    grip:SetPoint("TOPLEFT", 1, -1)
    grip:SetPoint("TOPRIGHT", -(BAR + 5), -1)
    grip:SetHeight(BAR)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() w:StartMoving() end)
    grip:SetScript("OnDragStop", function() Dropped(w, i) end)

    local close = CreateFrame("Button", nil, w)
    close:SetSize(BAR + 4, BAR)
    close:SetPoint("TOPRIGHT", -1, -1)
    local x = close:CreateFontString(nil, "OVERLAY")
    x:SetFont(D.FONT, 13, "OUTLINE")
    x:SetPoint("CENTER")
    x:SetText("x")
    x:SetTextColor(0.7, 0.7, 0.7)
    close:SetScript("OnEnter", function() x:SetTextColor(1, 0.3, 0.3) end)
    close:SetScript("OnLeave", function() x:SetTextColor(0.7, 0.7, 0.7) end)
    close:SetScript("OnClick", function() Close(w) end)

    local edit = CreateFrame("EditBox", nil, w)
    edit:SetPoint("BOTTOMLEFT", 6, 5)
    edit:SetPoint("BOTTOMRIGHT", -6, 5)
    edit:SetHeight(18)
    edit:SetAutoFocus(false)   -- a window that opens never takes the keyboard
    edit:SetFont(D.FONT, 12, "")
    edit:SetMaxLetters(255)
    local line = edit:CreateTexture(nil, "BACKGROUND")
    line:SetPoint("TOPLEFT", -3, 1)
    line:SetPoint("BOTTOMRIGHT", 3, -1)
    line:SetColorTexture(0, 0, 0, 0.5)
    local hint = edit:CreateFontString(nil, "OVERLAY")
    hint:SetFont(D.FONT, 11, "")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText("Click to answer, Enter sends")
    hint:SetTextColor(0.45, 0.45, 0.45)
    edit:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
    edit:SetScript("OnEnterPressed", function(self)
        Send(w.talk, self:GetText())
        self:SetText("")
        self:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    w.edit = edit

    local log = CreateFrame("ScrollingMessageFrame", nil, w)
    log:SetPoint("TOPLEFT", 6, -(BAR + 4))
    log:SetPoint("BOTTOMRIGHT", edit, "TOPRIGHT", 0, 5)
    log:SetFont(D.FONT, 12, "")
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(KEEP)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    -- item, quest and our own address links work as in the chat
    log:SetHyperlinksEnabled(true)
    log:SetScript("OnHyperlinkClick", function(self, link, text, button)
        if SetItemRef then pcall(SetItemRef, link, text, button, self) end
    end)
    w.log = log

    w:Hide()
    windows[i] = w
    return w
end

local function Title(w)
    local talk = w.talk
    local c = talk.color
    w.title:SetText(talk.title)
    if c then w.title:SetTextColor(c.r, c.g, c.b) else w.title:SetTextColor(1, 1, 1) end
end

local function WindowOf(talk)
    for i = 1, MAX do
        local w = windows[i]
        if w and w.talk == talk then return w end
    end
end

-- the window of a conversation, opened if it is not: a free one, or the
-- one that was quiet the longest
local function Open(talk)
    local w = WindowOf(talk)
    if w then return w end
    local oldest
    for i = 1, MAX do
        local have = windows[i]
        if not have then w = Build(i) break end
        if not have:IsShown() then w = have break end
        if not oldest or have.talk.last < oldest.talk.last then oldest = have end
    end
    w = w or oldest
    w.talk = talk
    w.edit:SetText("")
    w.edit:ClearFocus()
    w.log:Clear()
    for _, l in ipairs(talk.lines) do w.log:AddMessage(l[1], l[2], l[3], l[4]) end
    w:SetScale(ns.DeviceDB().whisperScale or 1)
    Title(w)
    w:Show()
    Restack()
    opened = opened + 1
    return w
end

-- a line of ours (never a secret) into a conversation and its window
function AddLine(talk, text, color)
    local l = { Stamp() .. text, color[1], color[2], color[3] }
    local lines = talk.lines
    lines[#lines + 1] = l
    if #lines > KEEP then table.remove(lines, 1) end
    local w = WindowOf(talk)
    if w then w.log:AddMessage(l[1], l[2], l[3], l[4]) end
end

-------------------------------------------------------------------
-- The whispers
-------------------------------------------------------------------
local function ClassColor(guid)
    if type(guid) ~= "string" or Secret(guid) or not GetPlayerInfoByGUID then return nil end
    local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
    return ok and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] or nil
end

local function Talk(key, name, title, bn)
    local talk = talks[key]
    if not talk then
        talk = { key = key, name = name, title = title, bn = bn, lines = {}, last = 0 }
        talks[key] = talk
    end
    return talk
end

local function Show(talk)
    if db().whisperWait and InCombatLockdown() and not WindowOf(talk) then
        waiting[talk] = true
        return nil
    end
    return Open(talk)
end

local ev = CreateFrame("Frame")
local EVENTS = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" }

ev:SetScript("OnEvent", function(_, event, message, sender, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        for talk in pairs(waiting) do Open(talk) end
        wipe(waiting)
        return
    end
    if not db().whispers then return end
    -- without a name to read there is no window to pick
    if Secret(sender) or type(sender) ~= "string" or sender == "" then
        hidden = hidden + 1
        return
    end
    local mine = event:find("INFORM", 1, true) ~= nil
    local talk
    if event:find("BN_", 1, true) then
        local id = select(11, ...)   -- the 13th argument: the friend's Battle.net id
        if Secret(id) or type(id) ~= "number" then hidden = hidden + 1 return end
        talk = Talk("bn" .. id, nil, sender, id)
        talk.bn, talk.title = id, sender
    else
        talk = Talk(sender, sender, Ambiguate and Ambiguate(sender, "short") or sender)
        if not mine and not talk.color then talk.color = ClassColor(select(10, ...)) end
    end
    talk.last = GetTime()
    local color = mine and OUT or IN
    local w = Show(talk)
    if w and talk.color then Title(w) end

    if Secret(message) or type(message) ~= "string" then
        -- unread into the window; the kept copy is a note
        local shown = w and pcall(w.log.AddMessage, w.log, message, color[1], color[2], color[3])
        local lines = talk.lines
        lines[#lines + 1] = { Stamp() .. "(a line the game keeps to its own chat)", NOTE[1], NOTE[2], NOTE[3] }
        if #lines > KEEP then table.remove(lines, 1) end
        if w and not shown then
            local l = lines[#lines]
            w.log:AddMessage(l[1], l[2], l[3], l[4])
        end
        return
    end
    local ok, new = pcall(ns.Rewrite, message)   -- addresses to copy, keywords in gold
    if ok and type(new) == "string" then message = new end
    AddLine(talk, (mine and "> " or "") .. message, color)
end)

-------------------------------------------------------------------
local function Apply()
    local on = db().whispers
    for _, event in ipairs(EVENTS) do
        if not C_EventUtils or C_EventUtils.IsEventValid(event) then
            if on then ev:RegisterEvent(event) else ev:UnregisterEvent(event) end
        end
    end
    if on then ev:RegisterEvent("PLAYER_REGEN_ENABLED") else ev:UnregisterEvent("PLAYER_REGEN_ENABLED") end
    local scale = ns.DeviceDB().whisperScale or 1
    for i = 1, MAX do
        local w = windows[i]
        if w then
            if not on and w:IsShown() then Close(w) end
            w:SetScale(scale)
        end
    end
    Restack()   -- a new size moves the placed windows' numbers
    if not on then wipe(waiting) end
end
ns.ApplyWhispers = Apply

local function Init()
    D.MakeMovable(anchor, "Whisper windows", DeckUIForeverChatDB)
end

local function Print()
    local count, open = 0, 0
    for _ in pairs(talks) do count = count + 1 end
    for i = 1, MAX do
        if windows[i] and windows[i]:IsShown() then open = open + 1 end
    end
    print(("  whisper windows %s: %d conversations this session, %d open, %d opened, %d whispers left to the chat (name hidden)"):format(
        db().whispers and "on" or "off", count, open, opened, hidden))
end

ns.pieces.whisper = { Init = Init, Apply = Apply, Print = Print }
