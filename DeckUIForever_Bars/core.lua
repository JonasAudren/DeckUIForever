local ADDON, ns = ...
local D = DeckUIForever
local LAB = LibStub("LibActionButton-1.0")

-------------------------------------------------------------------
-- The eight action bars in Final Fantasy XIV's hotbar look
-------------------------------------------------------------------
-- Owner's wish (2026-11-05): the action bars on the PC as FFXIV's
-- hotbars - ordinary bars for keyboard and mouse, not the controller
-- crosses of DeckUI Cross. The look is DeckUI Cross's bars.lua (bars 3-8
-- in retail), brought closer to FFXIV's own hotbar on the owner's
-- screenshot (2026-11-05): an empty slot is all but transparent - a thin
-- light outline and a faint shade, the ground shows through - the key
-- sits white on the top-left corner, the count bottom right, the icon
-- fills the slot with rounded corners; a small number tag at the left
-- end, as FFXIV marks its hotbars. All eight bars take part, and Action Bar 1 pages like
-- Blizzard's main bar - stances and forms, vehicles, the possess and
-- override bars - through a secure page state driver, as the crosses do.
--
-- The buttons are LibActionButton's, one per slot of the bar. Keys stay
-- Blizzard's: the player's bindings for ACTIONBUTTON1 and friends are the
-- client's own commands and work with Blizzard's bar out of sight; ours
-- show the key from the same command (LAB's keyBoundTarget) and mirror
-- the pushed state from Blizzard's button. A mouse click on ours uses the
-- action through LAB's secure button. Blizzard's bar is parked while ours
-- shows (blizzard.lua) and given back when a bar is switched off.
-- DeckUIForeverBarsDB: bars[n].shown / perRow (the first time, the bars
-- the game showed stay on), barAlpha, barNumbers, hideKeys shared; the
-- scale (barScale) and the positions per device.
-------------------------------------------------------------------
local SIZE, GAP = 36, 3
local TAG = 16      -- the number tag at the left end
local MASK = "Interface\\AddOns\\DeckUIForever_Bars\\textures\\slot_rounded"

-- bar number (Blizzard's, as Edit Mode names them) -> first action slot,
-- binding command prefix, Blizzard's buttons
ns.BARS = {
    [1] = { first = 1,   command = "ACTIONBUTTON",          native = "ActionButton",             paged = true },
    [2] = { first = 61,  command = "MULTIACTIONBAR1BUTTON", native = "MultiBarBottomLeftButton" },
    [3] = { first = 49,  command = "MULTIACTIONBAR2BUTTON", native = "MultiBarBottomRightButton" },
    [4] = { first = 25,  command = "MULTIACTIONBAR3BUTTON", native = "MultiBarRightButton" },
    [5] = { first = 37,  command = "MULTIACTIONBAR4BUTTON", native = "MultiBarLeftButton" },
    [6] = { first = 145, command = "MULTIACTIONBAR5BUTTON", native = "MultiBar5Button" },
    [7] = { first = 157, command = "MULTIACTIONBAR6BUTTON", native = "MultiBar6Button" },
    [8] = { first = 169, command = "MULTIACTIONBAR7BUTTON", native = "MultiBar7Button" },
}
ns.BAR_LAYOUTS = { 12, 6, 4, 3, 2, 1 }   -- buttons per row
local DEFAULT_ROW = { 12, 12, 12, 1, 1, 12, 12, 12 }
-- bars 1-3 stacked at the bottom, 4 and 5 as columns at the right edge,
-- 6-8 above the stack (FFXIV's default: hotbar 1 lowest)
local DEFAULT_POINT = {
    [1] = { "BOTTOM", UIParent, "BOTTOM", 0, 40 },
    [2] = { "BOTTOM", UIParent, "BOTTOM", 0, 85 },
    [3] = { "BOTTOM", UIParent, "BOTTOM", 0, 130 },
    [4] = { "RIGHT", UIParent, "RIGHT", -8, 40 },
    [5] = { "RIGHT", UIParent, "RIGHT", -50, 40 },
    [6] = { "BOTTOM", UIParent, "BOTTOM", 0, 175 },
    [7] = { "BOTTOM", UIParent, "BOTTOM", 0, 220 },
    [8] = { "BOTTOM", UIParent, "BOTTOM", 0, 265 },
}

function ns.DeviceDB()
    DeckUIForeverBarsDB = DeckUIForeverBarsDB or {}
    return D.DeviceDB(DeckUIForeverBarsDB)
end

-------------------------------------------------------------------
-- Paging for Action Bar 1: Blizzard's own page macro
-------------------------------------------------------------------
local function PageMacro()
    local m = ""
    m = m .. "[overridebar]" .. GetOverrideBarIndex() .. ";"
    m = m .. "[shapeshift]"  .. GetTempShapeshiftBarIndex() .. ";"
    m = m .. "[vehicleui]"   .. GetVehicleBarIndex() .. ";"
    m = m .. "[possessbar]"  .. GetVehicleBarIndex() .. ";"
    m = m .. "[bonusbar:5]"  .. GetBonusBarIndex() .. ";"
    m = m .. "[bar:2]2;[bar:3]3;[bar:4]4;[bar:5]5;[bar:6]6;"
    m = m .. "[bonusbar:1]7;[bonusbar:2]8;[bonusbar:3]9;[bonusbar:4]10;1"
    return m
end
-- every index the macro can return needs a registered state, or the
-- buttons fall back to "empty" on that page (the override bar is 18)
local NUM_PAGES = math.max(
    NUM_ACTIONBAR_PAGES or 6,
    GetOverrideBarIndex(),
    GetVehicleBarIndex(),
    GetTempShapeshiftBarIndex(),
    GetBonusBarIndex()
)

-------------------------------------------------------------------
-- LibActionButton's configuration
-------------------------------------------------------------------
local config = {
    showGrid = true,
    clickOnDown = true,
    hideElements = { macro = true, hotkey = false, equipped = false },
    text = {
        hotkey = {
            font = { font = D.FONT, size = 11, flags = "OUTLINE" },
            color = { 1, 1, 1 },
            -- on the corner itself, as FFXIV writes its keys
            position = { anchor = "TOPLEFT", relAnchor = "TOPLEFT", offsetX = 0, offsetY = 2 },
            justifyH = "LEFT",
        },
        count = {
            font = { font = D.FONT, size = 12, flags = "OUTLINE" },
            color = { 1, 1, 1 },
            position = { anchor = "BOTTOMRIGHT", relAnchor = "BOTTOMRIGHT", offsetX = -2, offsetY = 2 },
            justifyH = "RIGHT",
        },
    },
}

local function ButtonConfig(info, i)
    local c = CopyTable(config)
    c.keyBoundTarget = info.command .. i
    c.hideElements.hotkey = DeckUIForeverBarsDB.hideKeys and true or false
    return c
end

-------------------------------------------------------------------
-- The FFXIV slot look (DeckUI Cross's bars.lua)
-------------------------------------------------------------------
local function Nop() end
local PUSH_MIN = 0.18

local function Style(b)
    local mask = b:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b)

    -- the empty slot: a faint shade (Blizzard's icon is in BACKGROUND,
    -- ours goes below it at -7) and a thin light outline on top of
    -- everything, as FFXIV's hotbar draws its slots
    local slot = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    slot:SetAllPoints()
    slot:SetTexture(MASK)
    slot:SetVertexColor(0, 0, 0, 0.2)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = b:CreateTexture(nil, "OVERLAY", nil, 6)
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetVertexColor(0.85, 0.85, 0.85, 0.3)
        if side == "TOP" or side == "BOTTOM" then
            line:SetPoint(side .. "LEFT")
            line:SetPoint(side .. "RIGHT")
            line:SetHeight(1)
        else
            line:SetPoint("TOP" .. side)
            line:SetPoint("BOTTOM" .. side)
            line:SetWidth(1)
        end
    end

    if b.icon then
        b.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
        b.icon:AddMaskTexture(mask)
    end
    if b.NormalTexture then
        b.NormalTexture:SetTexture(nil)
        b.NormalTexture:SetAlpha(0)
        b.NormalTexture.SetTexture = Nop
        b.NormalTexture.SetAlpha = Nop
    end
    -- LibActionButton puts these back on art updates; ours stay instead
    for _, getter in ipairs({ "GetHighlightTexture", "GetPushedTexture", "GetCheckedTexture" }) do
        local tex = b[getter] and b[getter](b)
        if tex then
            tex:SetTexture(nil)
            tex:SetAlpha(0)
            tex.SetTexture, tex.SetAtlas, tex.SetAlpha = Nop, Nop, Nop
        end
    end
    b.SetHighlightTexture, b.SetPushedTexture, b.SetCheckedTexture = Nop, Nop, Nop

    local fx = CreateFrame("Frame", nil, b)
    fx:SetAllPoints()
    fx:SetFrameLevel(b:GetFrameLevel() + 3)
    local function Glow(r, g, bl, a)
        local t = fx:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:SetVertexColor(r, g, bl, a)
        t:SetBlendMode("ADD")
        t:AddMaskTexture(mask)
        t:Hide()
        return t
    end
    b.DeckHover = Glow(1, 1, 1, 0.15)
    b.DeckPushed = Glow(1, 0.85, 0.3, 0.4)
    b.DeckChecked = Glow(0.3, 0.7, 1, 0.3)
    b:HookScript("OnEnter", function(self) self.DeckHover:Show() end)
    b:HookScript("OnLeave", function(self) self.DeckHover:Hide() end)
    b:HookScript("OnMouseDown", function(self) self.DeckPushed:Show() end)
    b:HookScript("OnMouseUp", function(self) self.DeckPushed:Hide() end)
    hooksecurefunc(b, "SetChecked", function(self, on) self.DeckChecked:SetShown(on and true or false) end)

    if b.cooldown then
        b.cooldown:SetSwipeTexture(MASK)
        b.cooldown:SetSwipeColor(0, 0, 0, 0.7)
        b.cooldown:SetDrawEdge(false)
    end
    if b.Border then b.Border:SetAlpha(0) end
end

-- Blizzard's PUSHED state is gone before the eye sees it; hold ours a moment
local function ShowPushed(b, on)
    if on then
        b.DeckPushedAt = GetTime()
        b.DeckPushed:Show()
        return
    end
    local left = PUSH_MIN - (GetTime() - (b.DeckPushedAt or 0))
    if left <= 0 then b.DeckPushed:Hide() else C_Timer.After(left, function() b.DeckPushed:Hide() end) end
end

-- Retail's ActionButtonTemplate puts a TextOverlayContainer on top of the
-- button with textures that dim it while a modifier is held; the stack
-- count lives in it, so the container stays and its textures go (DeckUI
-- Cross's core.lua). The assisted-combat frames LAB makes stay hidden -
-- Forever has the API without the assistant.
local function StripTextures(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and not region.DeckHidden then
            region.DeckHidden = true
            region:SetTexture(nil)
            region:SetAlpha(0)
            region:Hide()
            region.SetTexture, region.SetAtlas, region.SetColorTexture = Nop, Nop, Nop
            region.SetAlpha, region.Show, region.SetShown = Nop, Nop, Nop
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do StripTextures(child) end
end

local function CleanButton(b)
    local c = b.TextOverlayContainer
    if c then
        StripTextures(c)
        if not c.DeckHooked then
            c.DeckHooked = true
            c:HookScript("OnShow", function(self) StripTextures(self) end)
        end
    end
    for _, key in ipairs({ "AssistedCombatRotationFrame", "AssistedCombatHighlightFrame" }) do
        local f = b[key]
        if f and not f.DeckHidden then
            f.DeckHidden = true
            f:Hide()
            f.Show, f.SetShown = Nop, Nop
        end
    end
end

-------------------------------------------------------------------
-- The bars
-------------------------------------------------------------------
local bars = {}   -- n -> { holder, header, buttons, tag }
ns.bars = bars

-- a bar's settings; the first time, a bar the game showed stays on
local function Settings(n)
    DeckUIForeverBarsDB = DeckUIForeverBarsDB or {}
    local db = DeckUIForeverBarsDB
    db.bars = db.bars or {}
    if not db.bars[n] then
        local bar = ns.ResolveBar(ns.BARS[n].native .. "1")
        db.bars[n] = { shown = (n == 1 or (bar and bar:IsShown())) and true or false, perRow = DEFAULT_ROW[n] }
    end
    return db.bars[n]
end
ns.BarSettings = Settings

local function Build(n)
    local info = ns.BARS[n]
    local holder = CreateFrame("Frame", "DeckUIForeverBar" .. n, UIParent)
    holder:SetSize(SIZE, SIZE)
    holder.defaultPoint = DEFAULT_POINT[n]
    holder:SetPoint(unpack(holder.defaultPoint))
    holder:Hide()

    local header = CreateFrame("Frame", nil, holder, "SecureHandlerStateTemplate")
    header:SetAllPoints()
    if info.paged then
        header:SetAttribute("_onstate-page", [[
            self:SetAttribute("state", newstate)
            control:ChildUpdate("state", newstate)
        ]])
    end

    local buttons = {}
    for i = 1, 12 do
        local b = LAB:CreateButton(n * 12 + i, "DeckUIForeverBar" .. n .. "Button" .. i, header, ButtonConfig(info, i))
        b:SetSize(SIZE, SIZE)
        if info.paged then
            for page = 1, NUM_PAGES do
                b:SetState(page, "action", (page - 1) * 12 + i)
            end
        else
            b:SetState(0, "action", info.first + i - 1)
        end
        Style(b)
        CleanButton(b)
        local native = _G[info.native .. i]
        if native then
            hooksecurefunc(native, "SetButtonState", function(_, state) ShowPushed(b, state == "PUSHED") end)
        end
        buttons[i] = b
    end
    if info.paged then RegisterStateDriver(header, "page", PageMacro()) end

    -- the number tag: a small dark square with the bar's number, left of
    -- the first row
    local tag = CreateFrame("Frame", nil, holder)
    tag:SetSize(TAG, TAG)
    tag:SetPoint("TOPRIGHT", holder, "TOPLEFT", -GAP, -(SIZE - TAG) / 2)
    local bg = tag:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(MASK)
    bg:SetVertexColor(0.05, 0.05, 0.06, 0.9)
    local text = tag:CreateFontString(nil, "OVERLAY")
    text:SetFont(D.FONT, 10, "OUTLINE")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(n)

    D.MakeMovable(holder, "Bar " .. n, DeckUIForeverBarsDB)
    bars[n] = { holder = holder, header = header, buttons = buttons, tag = tag }
    return bars[n]
end

-- places the twelve buttons in rows of perRow (secure buttons: out of combat)
local function Layout(n)
    local bar = bars[n]
    local per = Settings(n).perRow or 12
    local rows = math.ceil(12 / per)
    bar.holder:SetSize(per * (SIZE + GAP) - GAP, rows * (SIZE + GAP) - GAP)
    for i, b in ipairs(bar.buttons) do
        local col, row = (i - 1) % per, math.floor((i - 1) / per)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar.holder, "TOPLEFT", col * (SIZE + GAP), -row * (SIZE + GAP))
    end
    bar.tag:SetShown(DeckUIForeverBarsDB.barNumbers ~= false)
end

local pending = false

-- How see-through the bars are (FFXIV's hotbars have the same setting),
-- DeckUIForeverBarsDB.barAlpha, shared by both devices. On the holder, so
-- LibActionButton setting a button back to alpha 1 on every update does
-- not undo it; alpha may change in combat too.
function ns.ApplyBarAlpha()
    local alpha = DeckUIForeverBarsDB and DeckUIForeverBarsDB.barAlpha or 1
    for _, bar in pairs(bars) do bar.holder:SetAlpha(alpha) end
end

-- the number tags, live
function ns.ApplyBarNumbers()
    for _, bar in pairs(bars) do bar.tag:SetShown(DeckUIForeverBarsDB.barNumbers ~= false) end
end

-- the key names on the slots, live (LAB re-reads hideElements)
function ns.ApplyKeys()
    for n, bar in pairs(bars) do
        for i, b in ipairs(bar.buttons) do
            b:UpdateConfig(ButtonConfig(ns.BARS[n], i))
        end
    end
end

-- shows our bars and hides Blizzard's (or gives them back), out of combat
function ns.ApplyBars()
    if not DeckUIForeverBarsDB then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local scale = ns.DeviceDB().barScale or 1
    for n, info in ipairs(ns.BARS) do
        local s = Settings(n)
        if s.shown and not bars[n] then Build(n) end
        if bars[n] then
            Layout(n)
            bars[n].holder:SetScale(scale)
            bars[n].holder:SetShown(s.shown)
        end
        -- Blizzard's bar: parked while ours shows; asked every time, hiding
        -- twice and showing a bar never hidden are both no-ops
        ns.SetBlizzardBarHidden(info.native .. "1", s.shown and true or false)
    end
    -- our bar 1 pages to the override bar, so Blizzard's stays faded then
    ns.SetOverrideBarFaded(Settings(1).shown and true or false)
    ns.ApplyBarAlpha()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
    if pending then ns.ApplyBars() end
end)

local callbacks = {}
LAB.RegisterCallback(callbacks, "OnButtonUpdate", function(_, button)
    if button.DeckHover then CleanButton(button) end
end)

-- /df bars
function ns.PrintBars()
    print("DeckUIForever Bars: scale " .. tostring(ns.DeviceDB().barScale or 1)
        .. ", opacity " .. tostring(DeckUIForeverBarsDB.barAlpha or 1)
        .. ", pages 1-" .. NUM_PAGES)
    for n in ipairs(ns.BARS) do
        local s = Settings(n)
        local bar = bars[n]
        print(("  Action Bar %d: %s, %d per row%s"):format(n, s.shown and "ours" or "Blizzard's", s.perRow or 12,
            (bar and bar.header:GetAttribute("state")) and (", page " .. bar.header:GetAttribute("state")) or ""))
    end
    ns.PrintBlizzardBars()
end

local function Init()
    DeckUIForeverBarsDB = DeckUIForeverBarsDB or {}
    local db = DeckUIForeverBarsDB
    if db.barAlpha == nil then db.barAlpha = 1 end
    if db.barNumbers == nil then db.barNumbers = true end
    ns.InitLeaveButton()
    ns.ApplyBars()
end

-- Loaded on demand by the hub, before or after PLAYER_LOGIN. The saved
-- variables arrive with ADDON_LOADED, after these files ran - so the
-- table is made there, as the Week module does (nil DB, owner's first
-- test 2026-11-05).
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
    login:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Init()
    end)
end
