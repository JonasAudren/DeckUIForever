local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- What a chat line says: channels, links, keywords, alerts, repeats
-------------------------------------------------------------------
-- Rewriting a line needs the one hook every chat addon has: the chat
-- frame's AddMessage is wrapped, the text changed, the original called.
-- It is only installed once a rewriting option is on, never on the combat
-- log (ChatFrame2), and it hands on untouched whatever it may not read: a
-- secret text (a fight, an instance) and anything that is not a string.
-- The rewrite runs in a pcall, so a line is never lost to an error of ours.
--
--   channels   |Hchannel:...|h[1. General - Elwynn]|h  ->  [1]
--              |Hchannel:PARTY|h[Party]|h              ->  [P]
--   addresses  http://..., https://..., www....  ->  a link of the game's
--              "addon" kind (|Haddon:DeckUIForever:url:...|h), which the
--              game hands to the SetItemRef callback: a box with the
--              address, selected, to copy with Ctrl+C
--   keywords   your words in gold, outside links only (a colour code
--              inside a link's data would break the link)
--
-- The alert sound does not use the hook: a frame of ours listens to the
-- chat events themselves, where the sender is known (your own lines never
-- alert). The repeat filter is a message event filter, the game's own way
-- to drop a line; it is added the first time the option is on.
-------------------------------------------------------------------
local db = function() return DeckUIForeverChatDB end
local Secret = ns.Secret

-------------------------------------------------------------------
-- Rewriting
-------------------------------------------------------------------
local SHORT = {
    GUILD = "G", OFFICER = "O", PARTY = "P", RAID = "R", RAID_WARNING = "RW",
    INSTANCE_CHAT = "I", SAY = "S", YELL = "Y",
}

local function ShortChannel(data, label)
    local number = label:match("^(%d+)%.")
    if number then return ("|Hchannel:%s|h[%s]|h"):format(data, number) end
    local short = SHORT[data:upper()]
    if short then return ("|Hchannel:%s|h[%s]|h"):format(data, short) end
end

-- fn on every stretch of text that is not a link; the links stay as they are
local function OutsideLinks(text, fn)
    local out, pos = {}, 1
    while true do
        local s, e = text:find("|H.-|h.-|h", pos)
        if not s then break end
        if s > pos then out[#out + 1] = fn(text:sub(pos, s - 1)) end
        out[#out + 1] = text:sub(s, e)
        pos = e + 1
    end
    if pos <= #text then out[#out + 1] = fn(text:sub(pos)) end
    return table.concat(out)
end
ns.OutsideLinks = OutsideLinks

local URL_CHARS = "[%w_%.%-/~%?=&#%%:%+@,;!]+"
local function UrlLink(url)
    -- a full stop or comma at the end belongs to the sentence
    local tail = url:match("[%.,;:!%?]+$") or ""
    url = url:sub(1, #url - #tail)
    if #url < 6 then return nil end
    return ("|cff66bbff|Haddon:DeckUIForever:url:%s|h[%s]|h|r%s"):format(url, url, tail)
end

local function Urls(seg)
    seg = seg:gsub("https?://" .. URL_CHARS, UrlLink)
    return seg
end
local function WwwUrls(seg)
    seg = seg:gsub("www%.[%w_%-]+%." .. URL_CHARS, UrlLink)
    return seg
end

-- keyword -> a pattern that matches it in any case: "ubrs" -> "[uU][bB][rR][sS]"
local function AnyCase(word)
    return (word:gsub("%W", "%%%0"):gsub("%a", function(c)
        return "[" .. c:lower() .. c:upper() .. "]"
    end))
end

local patterns, plain = {}, {}   -- the keywords as patterns, and lower case for the alert
local function ReadKeywords()
    wipe(patterns)
    wipe(plain)
    for _, word in ipairs(ns.Split(db().keywords, ",")) do
        if #word >= 3 then   -- shorter ones would light up half the chat
            patterns[#patterns + 1] = AnyCase(word)
            plain[#plain + 1] = word:lower()
        end
    end
end

local function Keywords(seg)
    for _, pattern in ipairs(patterns) do
        seg = seg:gsub(pattern, "|cffffd100%0|r")
    end
    return seg
end

local function Rewrite(text)
    local o = db()
    if o.shortChannels then
        text = text:gsub("|Hchannel:([^|]-)|h%[([^%]]-)%]|h", ShortChannel)
    end
    if o.urls and (text:find("://", 1, true) or text:find("www.", 1, true)) then
        text = OutsideLinks(text, Urls)
        text = OutsideLinks(text, WwwUrls)
    end
    if o.highlight and #patterns > 0 then
        text = OutsideLinks(text, Keywords)
    end
    return text
end
ns.Rewrite = Rewrite   -- for /df chat's test

local originals = {}   -- [frame] = Blizzard's AddMessage
local rewrites, passed = 0, 0

local function Hook(frame)
    if originals[frame] then return end
    local original = frame.AddMessage
    originals[frame] = original
    frame.AddMessage = function(self, text, ...)
        if not Secret(text) and type(text) == "string" then
            local ok, new = pcall(Rewrite, text)
            if ok and type(new) == "string" then
                if new ~= text then rewrites = rewrites + 1 end
                text = new
            end
        else
            passed = passed + 1
        end
        return original(self, text, ...)
    end
end

-------------------------------------------------------------------
-- The copy box
-------------------------------------------------------------------
local copy
local function ShowCopy(text)
    if not copy then
        copy = CreateFrame("Frame", "DeckUIForeverChatCopy", UIParent)
        copy:SetSize(420, 64)
        copy:SetPoint("CENTER", 0, 120)
        copy:SetFrameStrata("DIALOG")
        copy:EnableMouse(true)
        D.FlatBox(copy, 0.95)
        local label = copy:CreateFontString(nil, "OVERLAY")
        label:SetFont(D.FONT, 12, "OUTLINE")
        label:SetPoint("TOPLEFT", 10, -8)
        label:SetText("Ctrl+C copies it, Escape closes")
        label:SetTextColor(0.7, 0.7, 0.7)
        local edit = CreateFrame("EditBox", nil, copy, "InputBoxTemplate")
        edit:SetPoint("BOTTOMLEFT", 16, 10)
        edit:SetPoint("BOTTOMRIGHT", -12, 10)
        edit:SetHeight(20)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetScript("OnEscapePressed", function() copy:Hide() end)
        edit:SetScript("OnEnterPressed", function() copy:Hide() end)
        -- what is shown stays what was clicked, whatever is typed
        edit:SetScript("OnTextChanged", function(self, user)
            if user then
                self:SetText(copy.text or "")
                self:HighlightText()
            end
        end)
        copy.edit = edit
        tinsert(UISpecialFrames, "DeckUIForeverChatCopy")
    end
    copy.text = text
    copy:Show()
    copy.edit:SetText(text)
    copy.edit:SetFocus()
    copy.edit:HighlightText()
end

local function OnLink(link)
    if type(link) ~= "string" then return end
    local kind, addon, what, rest = strsplit(":", link, 4)
    if kind == "addon" and addon == "DeckUIForever" and what == "url" and rest then
        ShowCopy(rest)
    end
end

-------------------------------------------------------------------
-- The alert: your name or a keyword in someone else's line
-------------------------------------------------------------------
local ALERT_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }
local alertFrame = CreateFrame("Frame")
local lastAlert, alerts = 0, 0
local me

local function Mine(sender)
    me = me or UnitName("player")
    return sender == me or (Ambiguate and Ambiguate(sender, "short") == me)
end

alertFrame:SetScript("OnEvent", function(_, _, message, sender)
    if Secret(message) or Secret(sender) or type(message) ~= "string" or type(sender) ~= "string" then return end
    if Mine(sender) then return end
    local o = db()
    local lower = message:lower()
    local hit = o.nameAlert and me and lower:find(me:lower(), 1, true)
    if not hit and o.keywordAlert then
        for _, word in ipairs(plain) do
            if lower:find(word, 1, true) then hit = true break end
        end
    end
    if not hit then return end
    local now = GetTime()
    if now - lastAlert < 3 then return end   -- a busy channel is one ping, not ten
    lastAlert, alerts = now, alerts + 1
    PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081, "Master")
end)

-------------------------------------------------------------------
-- The repeat filter
-------------------------------------------------------------------
-- The filter runs once for every chat window that shows the channel, so
-- the verdict is kept per line ID: the second window gets the answer the
-- first one got.
local REPEAT = 60
local seen, dropped, filterOn = {}, 0, false

local function Filter(_, _, message, sender, ...)
    local o = db()
    if not (o and o.spam) then return false end
    if Secret(message) or Secret(sender) or type(message) ~= "string" or type(sender) ~= "string" then return false end
    local line = select(9, ...)   -- the 11th argument of the event
    if Secret(line) then return false end
    if Mine(sender) then return false end
    local key = sender .. "\031" .. message
    local now = GetTime()
    local s = seen[key]
    if s and s.line == line then return s.drop end
    local drop = s ~= nil and now - s.time < REPEAT
    if drop then
        dropped = dropped + 1
        s.line, s.drop = line, true
    else
        seen[key] = { time = now, line = line, drop = false }
    end
    return drop
end

local cleaner
local function ApplyFilter()
    if filterOn or not db().spam then return end
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if not add then return end
    filterOn = true
    for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL" }) do
        add(event, Filter)
    end
    -- what was last said more than a few minutes ago is forgotten
    cleaner = C_Timer.NewTicker(120, function()
        local now = GetTime()
        for key, s in pairs(seen) do
            if now - s.time > REPEAT * 2 then seen[key] = nil end
        end
    end)
end

-------------------------------------------------------------------
local function Apply()
    local o = db()
    ReadKeywords()
    if o.shortChannels or o.urls or o.highlight then
        ns.EachFrame(function(frame, i)
            if i ~= 2 then Hook(frame) end
        end)
    end
    for _, event in ipairs(ALERT_EVENTS) do
        if not C_EventUtils or C_EventUtils.IsEventValid(event) then
            if o.nameAlert or (o.keywordAlert and #plain > 0) then
                alertFrame:RegisterEvent(event)
            else
                alertFrame:UnregisterEvent(event)
            end
        end
    end
    ApplyFilter()
end
ns.ApplyText = Apply

local function Init()
    -- a click on one of our address links
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("SetItemRef", function(_, link) OnLink(link) end, ns)
    elseif SetItemRef then
        hooksecurefunc("SetItemRef", OnLink)
    end
end

local function Print()
    local hooks = 0
    for _ in pairs(originals) do hooks = hooks + 1 end
    print(("  text: %d windows hooked, %d lines changed, %d handed on unread (secret); keywords %d; alerts %d; repeat filter %s, %d dropped"):format(
        hooks, rewrites, passed, #plain, alerts, filterOn and "on" or "off", dropped))
    local sample = "|Hchannel:channel:1|h[1. General - Elwynn Forest]|h see www.example.com."
    local ok, out = pcall(Rewrite, sample)
    print("  test line: " .. (ok and out:gsub("|", "||") or ("error: " .. tostring(out))))
end

ns.pieces.text = { Init = Init, Apply = Apply, Print = Print }
