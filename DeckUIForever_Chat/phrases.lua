local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Quick phrases: a row of buttons that say a prepared sentence
-------------------------------------------------------------------
-- For the Steam Deck, where typing "thanks" means opening the on-screen
-- keyboard: up to MAX sentences as buttons. The option's text is
-- "short=sentence" pieces between semicolons; a button wears the short
-- word and is as wide as that word, the tooltip shows the sentence
-- (owner 2026-11-25: "die Liste ist noch sehr lang, in der Liste sollten
-- Shorts sein"). A piece without "=" gets its first word as the short one.
-- The settings page edits them one row per sentence (config.lua). A click says the sentence to the group you are in - the raid,
-- the instance group, the party - or aloud when you are alone. A click is
-- a hardware event, which the game wants for /say outdoors.
-- Shown while you are in a group, or always with "also without a group".
-------------------------------------------------------------------
local MAX, BW, BH, GAP = 6, 40, 22, 4   -- BW: the narrowest a button gets
local SHORT_MAX = 10
local OLD_DEFAULT = "Hello!;Thanks!;Ready;One moment, please;I need mana;Thanks for the group, bye!"
local db = function() return DeckUIForeverChatDB end
ns.PHRASE_MAX = MAX

-- the option's text -> { { short = , text = }, ... }, MAX at most
local function Phrases()
    local out = {}
    for _, piece in ipairs(ns.Split(db().phraseList, ";")) do
        local short, text = piece:match("^([^=]-)=(.*)$")
        short = short and strtrim(short) or ""
        text = strtrim(text or piece)
        if text ~= "" then
            if short == "" then short = text:match("^[^%s%p]+") or text end
            if #short > SHORT_MAX then short = short:sub(1, SHORT_MAX) end
            out[#out + 1] = { short = short, text = text }
            if #out >= MAX then break end
        end
    end
    return out
end
ns.Phrases = Phrases

local bar = CreateFrame("Frame", "DeckChatPhrases", UIParent)
bar:SetSize(MAX * (60 + GAP) - GAP, BH)
bar.defaultPoint = { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 40, 260 }
bar:SetPoint(unpack(bar.defaultPoint))
bar:Hide()

local buttons, preview, sent = {}, false, 0

-- where a sentence goes right now: the chat type and a word for the tooltip
local function Target()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT", "the instance group" end
    if IsInRaid() then return "RAID", "the raid" end
    if IsInGroup() then return "PARTY", "the party" end
    return "SAY", "everyone near you"
end

local function Say(text)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send or not text or text == "" then return end
    local kind = Target()
    local ok, err = pcall(send, text, kind)
    if ok then
        sent = sent + 1
    else
        print("DeckUIForever Chat: the game did not take the sentence (" .. tostring(err) .. ").")
    end
end

local function Button(i)
    local b = buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, bar)
    b:SetSize(BW, BH)
    D.FlatBox(b, 0.85, 0.35)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], 0.18)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(D.FONT, 11, "OUTLINE")
    b.text:SetPoint("CENTER")
    b.text:SetWordWrap(false)
    b:SetScript("OnClick", function(self) Say(self.phrase) end)
    b:SetScript("OnEnter", function(self)
        local _, where = Target()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.phrase or "", 1, 1, 1, 1, true)
        GameTooltip:AddLine("Click: say it to " .. where, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    buttons[i] = b
    return b
end

-- "phrasesDock": the row hangs under the main chat window and goes where
-- the chat goes (owner 2026-11-25: "die Leiste soll automatisch unter dem
-- chat andocken"). The input line opens in the same place: while you type
-- the row is hidden and comes back when the line closes (first build: it
-- stepped down below the line, but the line counts as shown even while
-- invisible, and the room under it is the info bar's - owner's screenshot).
-- Only the "IM style" chat, whose input line is always there, gets the row
-- below the line. Off, the row is where "Move" put it.
local docked, typing = false, false
local function AlwaysLine() return GetCVar and GetCVar("chatStyle") == "im" end
local function Place()
    local chat = db().phrasesDock and ChatFrame1
    if not chat then
        if docked then
            docked = false
            bar:ClearAllPoints()
            bar:SetPoint(unpack(bar.defaultPoint))
            if D.ApplyPosition then D.ApplyPosition(bar) end
        end
        return
    end
    docked = true
    local scale = (chat:GetEffectiveScale() or 1) / (bar:GetEffectiveScale() or 1)
    local y = -9
    local edit = _G[chat:GetName() .. "EditBox"]
    if edit and AlwaysLine() then
        y = y - (edit:GetHeight() or 32) * (edit:GetEffectiveScale() or 1) / (chat:GetEffectiveScale() or 1)
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", chat, "BOTTOMLEFT", -5 * scale, y * scale)
end

local function Apply()
    local o = db()
    local list = Phrases()
    local shown, x = 0, 0
    local widths, natural = {}, 0
    for i = 1, #list do
        local b = Button(i)
        b.phrase = list[i].text
        b.text:SetText(list[i].short)
        widths[i] = math.max(BW, math.floor(b.text:GetStringWidth() + 14.5))
        natural = natural + widths[i]
    end
    -- "phrasesFit": the row is as wide as the main chat window's panel and
    -- the buttons share it, each keeping the room its word needs (owner
    -- 2026-11-25: "die Leiste passt sich noch nicht dynamisch an")
    local chat = o.phrasesFit and ChatFrame1
    if chat and #list > 0 then
        local scale = (chat:GetEffectiveScale() or 1) / (bar:GetEffectiveScale() or 1)
        local room = (chat:GetWidth() + 10) * scale - GAP * (#list - 1)
        if room > natural then
            local extra = (room - natural) / #list
            for i = 1, #list do widths[i] = widths[i] + extra end
        end
    end
    for i = 1, #list do
        shown = i
        local b = buttons[i]
        b:SetWidth(widths[i])
        b:ClearAllPoints()
        b:SetPoint("LEFT", bar, "LEFT", x, 0)
        x = x + widths[i] + GAP
        b:Show()
    end
    for i = shown + 1, #buttons do buttons[i]:Hide() end
    bar:SetWidth(math.max(BW, x - GAP))
    Place()
    local on = o.phrases and shown > 0 and (o.phrasesAlone or IsInGroup())
    if docked and typing and not AlwaysLine() then on = false end
    bar:SetShown(on or preview)
end
ns.ApplyPhrases = Apply

local function Init()
    -- the first build's list had no short words: an untouched one gets them
    if db().phraseList == OLD_DEFAULT then db().phraseList = ns.PHRASE_DEFAULT end
    D.MakeMovable(bar, "Chat phrases", DeckUIForeverChatDB)
    D.OnUnlock(function(state, only)
        preview = state and (not only or only["Chat phrases"]) and true or false
        Apply()
    end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("GROUP_ROSTER_UPDATE")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", Apply)
    -- the chat window dragged wider or narrower: the row follows
    if ChatFrame1 then
        local waiting = false
        ChatFrame1:HookScript("OnSizeChanged", function()
            if waiting or not (db() and db().phrasesFit) then return end
            waiting = true
            C_Timer.After(0.1, function() waiting = false Apply() end)
        end)
        -- the input line opening and closing under the chat
        local edit = _G[ChatFrame1:GetName() .. "EditBox"]
        if edit then
            local function Typing(on)
                typing = on
                if docked then Apply() end
            end
            edit:HookScript("OnEditFocusGained", function() Typing(true) end)
            edit:HookScript("OnEditFocusLost", function() Typing(false) end)
            edit:HookScript("OnHide", function() Typing(false) end)
        end
    end
    -- the hub puts a movable frame back to its saved place (unlock, profiles)
    if D.ApplyPosition then
        hooksecurefunc(D, "ApplyPosition", function(frame)
            if frame == bar and db() and db().phrasesDock then Place() end
        end)
    end
end

local function Print()
    local kind = Target()
    print(("  phrases %s: %d buttons, bar %s, a click goes to %s, %d sent this session"):format(
        db().phrases and "on" or "off", #Phrases(), bar:IsShown() and "shown" or "hidden", kind, sent))
end

ns.pieces.phrases = { Init = Init, Apply = Apply, Print = Print }
