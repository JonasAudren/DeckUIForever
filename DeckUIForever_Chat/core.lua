local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- DeckUIForever Chat (2026-11-24)
-------------------------------------------------------------------
-- Owner's wish ("lass uns mal am Chat arbeiten"; asked what it should do,
-- he picked all four): the look, comfort, highlighting and filtering, and
-- the Steam Deck. Blizzard's chat frames stay what they are - an Edit Mode
-- system with its own docking, tabs and saved settings; nothing is
-- rebuilt or reparented.
--   style.lua    the look: a flat dark panel behind each chat window,
--                plain tabs, the side buttons faded, our font, the size
--                and the input line per device
--   tabs.lua     thin coloured tabs over the main window, one per kind of
--                chat, in place of Blizzard's (an option)
--   text.lua     what a line says: short channel names, web addresses as
--                links to copy, keywords in gold; the alert sound; the
--                repeat filter
--   phrases.lua  a row of buttons that say a prepared sentence, for a
--                Deck without a keyboard
--   whisper.lua  a small window of ours per whisper conversation
--
-- Forever is retail's engine: a chat line can be a secret value in a
-- fight or an instance. Every piece that reads a text asks ns.Secret
-- first and hands a secret on untouched.
-- Untested in game at the time of writing.
-------------------------------------------------------------------
local DEFAULTS = {
    look          = true,    -- the flat panel, plain tabs and input line (off needs a reload)
    hideButtons   = true,    -- Blizzard's buttons beside the chat fade out
    font          = true,    -- DeckUIForever's font in the chat
    panelAlpha    = 0.45,    -- how dark the panel is
    tabs          = true,    -- our thin coloured tabs in place of Blizzard's (tabs.lua)
    tabLabels     = true,    -- ... with their names; off, they are coloured lines only
    tabsType      = true,    -- ... a click on Guild, Party, Raid or Say starts the input line there
    shortChannels = true,    -- [1] for [1. General], [P] for [Party]
    urls          = true,    -- web addresses become links that open a copy box
    arrowKeys     = true,    -- arrow keys walk through what you typed, without Alt
    highlight     = true,    -- your keywords in gold
    keywords      = "",      -- words between commas
    nameAlert     = true,    -- a sound when your name is said
    keywordAlert  = true,    -- a sound when a keyword is said
    spam          = false,   -- the same line from the same player within a minute is dropped
    phrases       = false,   -- the row of sentence buttons
    phrasesAlone  = true,    -- ... also without a group (then they are said aloud); the first build's key phrasesSolo (off) is ignored
    -- "short=sentence" between semicolons: the button wears the short word
    phrasesDock   = true,    -- ... docked under the main chat window (off: where Move put it)
    phrasesFit    = true,    -- ... as wide as the main chat window, the buttons share the width
    phraseList    = "Hi=Hello!;Thx=Thanks!;Ready=Ready;Wait=One moment, please;Mana=I need mana;Bye=Thanks for the group, bye!",
    whispers      = true,    -- a small window of ours per whisper conversation
    whisperWait   = false,   -- ... a new one opens only once a fight is over
}

-- per device: the Deck's screen is small and far away
local DEVICE_DEFAULTS = {
    deck = { sizeOn = true,  fontSize = 16, editScale = 1.2, whisperScale = 1.2, tabScale = 1.3 },
    pc   = { sizeOn = false, fontSize = 14, editScale = 1.0, whisperScale = 1.0, tabScale = 1.0 },
}

ns.PHRASE_DEFAULT = DEFAULTS.phraseList
ns.pieces = {}
ns.WHITE = "Interface\\Buttons\\WHITE8x8"
ns.GOLD = { 1, 0.82, 0.3 }

function ns.Secret(v) return issecretvalue and issecretvalue(v) or false end
function ns.DeviceDB() return D.DeviceDB(DeckUIForeverChatDB, DEVICE_DEFAULTS) end

-- ChatFrame1..N; fn(frame, index). The combat log is index 2.
function ns.EachFrame(fn)
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local frame = _G["ChatFrame" .. i]
        if frame then fn(frame, i) end
    end
end

-- "a, b ,c" -> { "a", "b", "c" }, split at `sep`; empty pieces dropped
function ns.Split(text, sep)
    local out = {}
    for piece in (text or ""):gmatch("[^" .. sep .. "]+") do
        piece = piece:match("^%s*(.-)%s*$")
        if piece ~= "" then out[#out + 1] = piece end
    end
    return out
end

function ns.Apply()
    for _, name in ipairs({ "style", "tabs", "text", "phrases", "whisper" }) do
        local piece = ns.pieces[name]
        if piece and piece.Apply then piece.Apply() end
    end
end

-------------------------------------------------------------------
-- Startup (normal login and load on demand from the menu)
-------------------------------------------------------------------
local ready = false

local function Init()
    if ready then return end
    ready = true
    DeckUIForeverChatDB = DeckUIForeverChatDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckUIForeverChatDB[k] == nil then DeckUIForeverChatDB[k] = v end
    end
    for _, name in ipairs({ "style", "tabs", "text", "phrases", "whisper" }) do
        local piece = ns.pieces[name]
        if piece and piece.Init then piece.Init() end
    end
    ns.Apply()
end

local ev = CreateFrame("Frame")
if IsLoggedIn() then
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", Init)
end

-- /df chat
function D.PrintChat()
    print("DeckUIForever Chat:")
    for _, name in ipairs({ "style", "tabs", "text", "phrases", "whisper" }) do
        local piece = ns.pieces[name]
        if piece and piece.Print then piece.Print() end
    end
end
