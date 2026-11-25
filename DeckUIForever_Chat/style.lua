local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The look of the chat windows
-------------------------------------------------------------------
-- Everything here is paint on Blizzard's frames: textures of theirs are
-- emptied (SetTexture(nil) - their code goes on showing, hiding and
-- fading them, there is just nothing to draw), frames of theirs are held
-- at alpha 0 by a SetAlpha post-hook with the mouse off, and our panel is
-- a texture of the chat frame itself. Nothing is reparented, hidden or
-- moved. Taking the look off again needs a reload: an emptied texture has
-- no way back.
-------------------------------------------------------------------
local db = function() return DeckUIForeverChatDB end
local styled = {}        -- [frame] = true once painted
local held = {}          -- [frame] = true while its alpha is held at 0
local hooked = {}
local mouseBefore = {}

local function Clear(tex)
    if tex and tex.SetTexture then tex:SetTexture(nil) end
end

local function NoMouse(frame, off)
    if frame.EnableMouse and frame.IsMouseEnabled then
        if off then
            if mouseBefore[frame] == nil then mouseBefore[frame] = frame:IsMouseEnabled() end
            frame:EnableMouse(false)
        elseif mouseBefore[frame] ~= nil then
            frame:EnableMouse(mouseBefore[frame])
            mouseBefore[frame] = nil
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do NoMouse(child, off) end
    end
end

-- Blizzard fades these in when the mouse comes near; the hook holds them out
local function Hold(frame, state)
    if not frame then return end
    if not state and not hooked[frame] then return end   -- never touched: leave it
    held[frame] = state or nil
    if not hooked[frame] then
        hooked[frame] = true
        hooksecurefunc(frame, "SetAlpha", function(self, alpha)
            if held[self] and alpha ~= 0 then self:SetAlpha(0) end
        end)
    end
    frame:SetAlpha(state and 0 or 1)
    NoMouse(frame, state)
end
ns.Hold = Hold   -- tabs.lua holds Blizzard's tabs out the same way

local SIDE_BUTTONS = { "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton", "TextToSpeechButtonFrame" }

local function ApplyButtons()
    local state = db().hideButtons and true or false
    for _, name in ipairs(SIDE_BUTTONS) do Hold(_G[name], state) end
    ns.EachFrame(function(frame)
        Hold(_G[frame:GetName() .. "ButtonFrame"], state)
    end)
end

local TAB_PARTS = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight" }
local EDIT_PARTS = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }

-- four one-pixel lines around `around`, drawn by `frame`
local function Edge(frame, around, r, g, b, a)
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a)
        t:SetPoint(p[1], around, p[1])
        t:SetPoint(p[2], around, p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
end

local function TabText(tab)
    return tab and (tab.Text or (tab.GetFontString and tab:GetFontString()))
end

local function Paint(frame)
    if styled[frame] then return end
    styled[frame] = true
    local name = frame:GetName()

    -- Blizzard's own background and border pieces
    for _, part in ipairs(CHAT_FRAME_TEXTURES or {}) do Clear(_G[name .. part]) end
    -- ours: a little wider than the text, so the letters do not touch the edge
    local panel = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    panel:SetPoint("TOPLEFT", -5, 4)
    panel:SetPoint("BOTTOMRIGHT", 5, -6)
    frame.deckPanel = panel
    Edge(frame, panel, 0.3, 0.3, 0.3, 0.9)

    local tab = _G[name .. "Tab"]
    if tab then
        for _, part in ipairs(TAB_PARTS) do
            Clear(tab[part])
            Clear(_G[name .. "Tab" .. part])
        end
        local text = TabText(tab)
        if text then text:SetFont(D.FONT, 12, "OUTLINE") end
    end

    local edit = _G[name .. "EditBox"]
    if edit then
        for _, part in ipairs(EDIT_PARTS) do
            Clear(_G[name .. "EditBox" .. part])
            Clear(edit[part:sub(1, 1):lower() .. part:sub(2)])   -- focusLeft, focusMid, focusRight
        end
        local bg = edit:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetPoint("TOPLEFT", 2, -3)
        bg:SetPoint("BOTTOMRIGHT", -2, 3)
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)
        Edge(edit, bg, 0.3, 0.3, 0.3, 0.9)
    end
end

local function ApplyFont(frame)
    local d = ns.DeviceDB()
    local file, size, flags = frame:GetFont()
    if d.sizeOn and d.fontSize and size and math.abs(size - d.fontSize) > 0.1 then
        -- Blizzard's own setter: it also keeps the size for the next login
        if FCF_SetChatWindowFontSize then
            FCF_SetChatWindowFontSize(nil, frame, d.fontSize)
        else
            frame:SetFont(file, d.fontSize, flags)
        end
        file, size, flags = frame:GetFont()
    end
    if db().font and size and file ~= D.FONT then
        frame:SetFont(D.FONT, size, flags)
    end
end

local function ApplyEdit(frame)
    local edit = _G[frame:GetName() .. "EditBox"]
    if not edit then return end
    local d = ns.DeviceDB()
    edit:SetScale(d.editScale or 1)
    if edit.SetAltArrowKeyMode then edit:SetAltArrowKeyMode(not db().arrowKeys) end
end

local function Apply()
    local on = db().look and true or false
    ns.EachFrame(function(frame)
        if on then Paint(frame) end
        if frame.deckPanel then
            frame.deckPanel:SetColorTexture(0.04, 0.04, 0.05, on and (db().panelAlpha or 0.45) or 0)
        end
        ApplyFont(frame)
        ApplyEdit(frame)
    end)
    ApplyButtons()
end
ns.ApplyStyle = Apply

local function Init()
    -- the picked tab in gold, the others grey; Blizzard sets its own colours
    -- whenever a tab is picked or flashes
    if FCFTab_UpdateColors then
        hooksecurefunc("FCFTab_UpdateColors", function(tab, selected)
            if not (db() and db().look) then return end
            local text = TabText(tab)
            if not text then return end
            if selected then
                text:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
            else
                text:SetTextColor(0.7, 0.7, 0.7)
            end
        end)
    end
    -- a size picked in the chat's own menu keeps our font
    if FCF_SetChatWindowFontSize then
        hooksecurefunc("FCF_SetChatWindowFontSize", function(_, frame)
            if frame and frame.GetFont and db() and db().font then
                local file, size, flags = frame:GetFont()
                if size and file ~= D.FONT then frame:SetFont(D.FONT, size, flags) end
            end
        end)
    end
    -- the game lays the chat out again when the world is entered
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function() C_Timer.After(1, Apply) end)
end

local function Print()
    local painted, heldCount = 0, 0
    for _ in pairs(styled) do painted = painted + 1 end
    for _ in pairs(held) do heldCount = heldCount + 1 end
    local d = ns.DeviceDB()
    local _, size = ChatFrame1:GetFont()
    print(("  look %s: %d windows painted, %d button frames held out; font size %s (ours %s, %s), input line x%s"):format(
        db().look and "on" or "off", painted, heldCount, tostring(size and math.floor(size + 0.5)),
        tostring(d.fontSize), d.sizeOn and "on" or "off", tostring(d.editScale)))
end

ns.pieces.style = { Init = Init, Apply = Apply, Print = Print }
