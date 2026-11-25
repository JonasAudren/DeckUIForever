local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverChatDB end
local device = function() return ns.DeviceDB() end
local style = function() ns.ApplyStyle() end
local tabs = function() ns.ApplyTabs() end
local text = function() ns.ApplyText() end
local phrases = function() ns.ApplyPhrases() end
local whispers = function() ns.ApplyWhispers() end

-- The game's own time stamp setting (Options > Social) is a CVar; the
-- checkbox reads and writes that, nothing of ours is saved.
local STAMP = "%H:%M "
local stamps = setmetatable({}, {
    __index = function() return (GetCVar("showTimestamps") or "none") ~= "none" end,
    __newindex = function(_, _, on) SetCVar("showTimestamps", on and STAMP or "none") end,
})

-- every chat type the game can colour names in
local COLOR_TYPES = { "SAY", "YELL", "EMOTE", "GUILD", "OFFICER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER",
    "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "WHISPER" }
local function ClassColors()
    if not SetChatColorNameByClass then
        print("DeckUIForever Chat: this game has no class colours for names.")
        return
    end
    local n = 0
    local function Set(kind)
        if pcall(SetChatColorNameByClass, kind, true) then n = n + 1 end
    end
    for _, kind in ipairs(COLOR_TYPES) do Set(kind) end
    for i = 1, 20 do Set("CHANNEL" .. i) end
    print(("DeckUIForever Chat: names are in class colours now (%d chat types)."):format(n))
end

-- a line to type a list into; Enter saves
local function ListBox(f, key, apply, title, tip)
    f:Add(30, function(parent, y)
        local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        edit:SetSize(340, 20)
        edit:SetPoint("TOP", 0, y)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetScript("OnEnterPressed", function(self)
            DeckUIForeverChatDB[key] = strtrim(self:GetText() or "")
            self:ClearFocus()
            apply()
        end)
        edit:SetScript("OnEscapePressed", function(self)
            self:SetText(DeckUIForeverChatDB[key] or "")
            self:ClearFocus()
        end)
        edit:SetScript("OnShow", function(self) self:SetText(DeckUIForeverChatDB[key] or "") end)
        edit:SetText(DeckUIForeverChatDB[key] or "")
        D.Tip(edit, title, tip)
        return edit
    end)
end

-- The quick phrases, a row each: the short word the button wears and the
-- sentence it says. Enter or leaving a field saves all rows into the one
-- option text ("short=sentence;..."); an empty sentence drops its row.
local phraseRows = {}
local function FillPhrases()
    local list = ns.Phrases()
    for i, row in ipairs(phraseRows) do
        row.short:SetText(list[i] and list[i].short or "")
        row.text:SetText(list[i] and list[i].text or "")
    end
end
local function SavePhrases()
    local out = {}
    for _, row in ipairs(phraseRows) do
        -- ";" and "=" are what the option text is split at
        local short = strtrim(((row.short:GetText() or ""):gsub("[;=]", "")))
        local text = strtrim(((row.text:GetText() or ""):gsub(";", ",")))
        if text ~= "" then out[#out + 1] = short .. "=" .. text end
    end
    DeckUIForeverChatDB.phraseList = table.concat(out, ";")
    ns.ApplyPhrases()
end
local function PhraseBox(parent, width, letters, title, tip)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(width, 20)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(letters)
    edit:SetFontObject(ChatFontNormal)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self)
        self.dropped = true   -- Escape: what was typed is thrown away
        self:ClearFocus()
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        if self.dropped then self.dropped = nil else SavePhrases() end
        FillPhrases()
    end)
    D.Tip(edit, title, tip)
    return edit
end
local function PhraseRows(f)
    for i = 1, ns.PHRASE_MAX do
        f:Add(26, function(parent, y)
            local row = CreateFrame("Frame", nil, parent)
            row:SetSize(360, 22)
            row:SetPoint("TOP", 0, y)
            row.short = PhraseBox(row, 76, 10, "Short word", "What the button wears - a few letters.")
            row.short:SetPoint("LEFT", 6, 0)
            row.text = PhraseBox(row, 262, 200, "Sentence", "What a click says. Empty: no button.")
            row.text:SetPoint("LEFT", row.short, "RIGHT", 12, 0)
            row:SetScript("OnShow", FillPhrases)
            phraseRows[i] = row
            return row
        end)
    end
    FillPhrases()
end

D.RegisterModule("Chat", {
    title = "Chat",
    build = function(c)
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local pt = function(v) return tostring(v) end
        local f = D.Flow(c)
        f:Hint("Blizzard's chat stays what it is - its windows, channels and settings - and gets a calmer look and a few helpers. /df chat prints what the module is doing.")

        f:Label("Look")
        f:Checkbox("DeckUIForever's look", db, "look", function(v)
            if v then ns.ApplyStyle() else D.NeedReload("chatLook", true) end
        end, "A flat dark panel behind every chat window, plain tabs with the picked one in gold, and a plain input line. Switching it off needs a reload.")
        f:Checkbox("Hide the buttons beside the chat", db, "hideButtons", style,
            "The menu, channel and scroll buttons at the chat's side fade out. Shift and the mouse wheel still jump to the newest line; a right click on a tab opens the chat's settings.")
        f:More()
        f:Checkbox("DeckUIForever's font", db, "font", function(v)
            if v then ns.ApplyStyle() else D.NeedReload("chatFont", true) end
        end, "The chat in the font of the rest of DeckUIForever. Switching it off needs a reload.")
        f:Slider("Panel darkness", 0, 0.9, 0.05, pct, db, "panelAlpha", function(v)
            DeckUIForeverChatDB.panelAlpha = v
            ns.ApplyStyle()
        end)

        f:Label("Tabs")
        f:Checkbox("Thin coloured tabs", db, "tabs", tabs,
            "Our own tabs over the chat in place of Blizzard's: one per kind of chat, in that chat's colour - All, Guild in green, Party in blue, Raid, Whisper, Say, Channels - and a grey one for the combat log and every other docked window. A tab shows only its lines; a tab that got a new line lights up. Off, Blizzard's tabs are back.")
        f:Checkbox("Names on the tabs", db, "tabLabels", tabs,
            "Off, the tabs are coloured lines without a name - thinner still.")
        f:More()
        f:Checkbox("A tab also picks where you write", db, "tabsType", tabs,
            "A click on Guild, Party, Raid or Say starts the input line in that chat, if you are in one.")
        f:Slider("Tab size (this device)", 0.8, 2, 0.1, pct, device, "tabScale", function(v)
            ns.DeviceDB().tabScale = v
            ns.ApplyTabs()
        end)

        f:Label("Size (this device)")
        f:Checkbox("Set the chat's font size", device, "sizeOn", style,
            "Every chat window gets the size below. Off, the sizes you picked in the chat's own menu stay.")
        f:Slider("Font size", 10, 24, 1, pt, device, "fontSize", function(v)
            ns.DeviceDB().fontSize = v
            ns.ApplyStyle()
        end)
        f:More()
        f:Slider("Input line", 0.8, 1.6, 0.1, pct, device, "editScale", function(v)
            ns.DeviceDB().editScale = v
            ns.ApplyStyle()
        end, "The size of the line you type in.")

        f:Label("Reading")
        f:Checkbox("Short channel names", db, "shortChannels", text,
            "[1] in place of [1. General], [P] for the party, [G] for the guild, [R] for the raid. New lines only.")
        f:Checkbox("Web addresses to copy", db, "urls", text,
            "An address in the chat becomes a blue link. A click opens a small box with the address selected - Ctrl+C copies it.")
        f:Checkbox("Time in front of every line", function() return stamps end, "on", function() end,
            "The game's own time stamps, as hour and minute. May need a reload to show.")
        f:More()
        f:Checkbox("Arrow keys recall what you typed", db, "arrowKeys", style,
            "Up and down in the input line walk through your last lines without holding Alt.")
        f:Button("Names in class colours", ClassColors,
            "Sets the game's own option for every channel at once: player names in the colour of their class.")

        f:Label("Keywords")
        f:Checkbox("Keywords in gold", db, "highlight", text,
            "The words you list below stand out in gold wherever they are said.")
        f:Hint("Your keywords, separated by commas - a dungeon you look for, an item, a friend's name. At least three letters each. Press Enter to save.")
        ListBox(f, "keywords", text, "Keywords", "For example: deadmines, healer, enchanter. Upper and lower case do not matter.")
        f:Checkbox("Sound when a keyword is said", db, "keywordAlert", text,
            "A short sound when someone else's line has one of your keywords. At most one every three seconds.")
        f:Checkbox("Sound when your name is said", db, "nameAlert", text,
            "A short sound when someone else writes your character's name.")
        f:More()
        f:Checkbox("Drop repeated lines", db, "spam", text,
            "The same line from the same player within a minute is shown once - in channels, say and yell. Switching it off again takes a reload to end fully.")

        f:Label("Whispers")
        f:Checkbox("Small windows for whispers", db, "whispers", whispers,
            "A whisper - one you get or one you send - opens a small window with that conversation alone and a line to answer in. Up to four at once; the chat shows the whisper as before. Drag a window by its title bar to put it anywhere; Move below moves the stack they open in.")
        f:More()
        f:Checkbox("Wait until a fight is over", db, "whisperWait", whispers,
            "In a fight a new window stays closed and opens when the fight ends. A window that is already open still gets its lines.")
        f:Slider("Size (this device)", 0.8, 1.6, 0.1, pct, device, "whisperScale", function(v)
            ns.DeviceDB().whisperScale = v
            ns.ApplyWhispers()
        end)
        f:Button("Windows back into the stack", function() ns.ResetWhisperPlaces() end,
            "Every whisper window can be dragged by its title bar and stays where you drop it. This puts them all back into the stack.")

        f:Label("Quick phrases")
        f:Checkbox("Buttons for prepared sentences", db, "phrases", phrases,
            "A row of small buttons, made for the Steam Deck: each wears a short word, a click says its sentence to your party or raid, the tooltip shows it.")
        f:Checkbox("Also without a group", db, "phrasesAlone", phrases,
            "Shows the buttons when you are alone too. A sentence is then said aloud to everyone near you.")
        f:Checkbox("Docked under the chat", db, "phrasesDock", phrases,
            "The row hangs under the main chat window and goes where the chat goes; it sits where the input line opens, so while you type it is hidden. Off, the row stays where Move below put it.")
        f:Checkbox("As wide as the chat", db, "phrasesFit", phrases,
            "The row is as wide as the main chat window and the buttons share that width; it follows when you resize the chat. Off, every button is only as wide as its word.")
        f:Hint("Six at most. Left the short word on the button, right the sentence it says. Change them as you like - Enter saves, an empty sentence takes its button away.")
        PhraseRows(f)
        f:Gap(6)
        f:Button("Our sentences again", function()
            DeckUIForeverChatDB.phraseList = ns.PHRASE_DEFAULT
            FillPhrases()
            ns.ApplyPhrases()
        end, "Puts the six sentences back that the module came with.")
    end,
})

D.PAGE_FRAMES.Chat = { "Chat phrases", "Whisper windows" }
D.PAGE_RESET.Chat = { db = "DeckUIForeverChatDB" }
