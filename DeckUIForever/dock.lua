local D = DeckUIForever

-------------------------------------------------------------------
-- The dock: DeckUIForever's own windows as a row of round buttons
-------------------------------------------------------------------
-- The owner's wish (2026-11-07): the week button on screen grows into a
-- small panel with the hub's settings and the quest compendium beside
-- it, in Final Fantasy XIV's manner - a flat dark panel with a thin
-- edge and a faint gold line along its top, the buttons the round ones
-- of the main menu (mainmenu.lua: gold ring, dark disc, the icon cut
-- round). Dragged anywhere by any of its buttons, a drag is no click;
-- /df unlock moves it too, the place is kept per device ("Dock").
--
-- The buttons come from whoever has a window: the hub puts its settings
-- first, the Week module its overview (with the badge it had), the
-- Questing module its compendium. D.DockButton(key, spec) registers one:
--   spec.order     where in the row (settings 1, week 2, compendium 3)
--   spec.icon      a texture; spec.texCoord to cut the icon's edge
--   spec.title     the tooltip's first line
--   spec.tip       lines under it: a table, or a function returning one
--   spec.onClick   left click; spec.onRightClick right click
--   spec.badge     function returning a short text for the corner, or ""
--   spec.available function: false hides the button (the module's own switch)
-- D.DockUpdate() re-reads the badges and the availability.
-------------------------------------------------------------------
local SIZE, GAP, PAD = 28, 6, 6
local GOLD = { 0.85, 0.68, 0.3 }

local dock = CreateFrame("Frame", "DeckUIForeverDock", UIParent)
dock:SetFrameStrata("MEDIUM")
dock:SetSize(SIZE + 2 * PAD, SIZE + 2 * PAD)
dock:SetClampedToScreen(true)
dock.defaultPoint = { "TOPRIGHT", UIParent, "TOPRIGHT", -230, -26 }
dock:SetPoint(unpack(dock.defaultPoint))
dock:Hide()

do  -- the panel: a dark fill, a one-pixel edge, a gold line along the top
    local bg = dock:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.05, 0.75)
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = dock:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.28, 0.26, 0.22, 1)
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
    local gold = dock:CreateTexture(nil, "BORDER", nil, 1)
    gold:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.45)
    gold:SetPoint("TOPLEFT", 1, -1)
    gold:SetPoint("TOPRIGHT", -1, -1)
    gold:SetHeight(1)
end

local specs, buttons = {}, {}

-- the round look of the main menu's buttons
local function Dress(b)
    local mask = D.RoundMask(b)
    local ring = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetSize(SIZE + 4, SIZE + 4)
    ring:SetPoint("CENTER")
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    local disc = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    disc:SetAllPoints()
    disc:SetTexture(D.DISC)
    disc:SetVertexColor(0.06, 0.05, 0.04)
    b.ring = ring
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(SIZE - 6, SIZE - 6)
    icon:AddMaskTexture(mask)
    b.icon = icon
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetTexture(D.DISC)
    hover:SetVertexColor(1, 1, 1, 0.15)
    hover:SetBlendMode("ADD")
    b.badge = b:CreateFontString(nil, "OVERLAY")
    b.badge:SetFont(D.FONT, 11, "OUTLINE")
    b.badge:SetPoint("BOTTOMRIGHT", 3, -3)
    b.badge:SetTextColor(1, 0.82, 0)
end

-- a press that turned into a drag of the dock is not a click
local function Build(key, spec)
    local b = CreateFrame("Button", nil, dock)
    b:SetSize(SIZE, SIZE)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    Dress(b)
    b.key, b.spec = key, spec
    b.icon:SetTexture(spec.icon)
    local tc = spec.texCoord or { 0.08, 0.92, 0.08, 0.92 }
    b.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    b:SetScript("OnMouseDown", function(self) self.dragged = false end)
    b:SetScript("OnDragStart", function(self)
        self.dragged = true
        GameTooltip:Hide()
        local start = dock:GetScript("OnDragStart")
        if start then start(dock) end
    end)
    b:SetScript("OnDragStop", function()
        local stop = dock:GetScript("OnDragStop")
        if stop then stop(dock) end
    end)
    b:SetScript("OnClick", function(self, mouse)
        if self.dragged then return end
        if mouse == "RightButton" then
            if spec.onRightClick then spec.onRightClick() end
        elseif spec.onClick then
            spec.onClick()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(spec.title or key, 1, 1, 1)
        local lines = type(spec.tip) == "function" and spec.tip() or spec.tip
        for _, line in ipairs(lines or {}) do GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
        GameTooltip:AddLine("Drag: move the dock", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function Available(b)
    local a = b.spec.available
    return a == nil or a() ~= false
end

local function Layout()
    table.sort(buttons, function(a, b) return (a.spec.order or 99) < (b.spec.order or 99) end)
    local x, n = PAD, 0
    for _, b in ipairs(buttons) do
        b:ClearAllPoints()
        if Available(b) then
            b:SetPoint("LEFT", dock, "LEFT", x, 0)
            b:Show()
            x = x + SIZE + GAP
            n = n + 1
        else
            b:Hide()
        end
        local badge = b.spec.badge and b.spec.badge() or ""
        b.badge:SetText(badge or "")
    end
    dock:SetWidth(n > 0 and (x - GAP + PAD) or (SIZE + 2 * PAD))
    local on = DeckUIForeverDB and DeckUIForeverDB.dock ~= false
    dock:SetShown(on and (n > 0 or D.unlocked == true))
end

function D.DockButton(key, spec)
    if specs[key] then
        specs[key] = spec
        for _, b in ipairs(buttons) do
            if b.key == key then b.spec = spec end
        end
    else
        specs[key] = spec
        buttons[#buttons + 1] = Build(key, spec)
    end
    Layout()
end

function D.DockUpdate()
    Layout()
end

function D.ApplyDock()
    Layout()
end

-- the hub's own button: the settings, and a right click unlocks the frames
D.DockButton("settings", {
    order = 1,
    icon = "Interface\\AddOns\\DeckUIForever\\textures\\face_a",
    texCoord = { 0, 1, 0, 1 },
    title = "DeckUIForever",
    tip = { "Click: the settings", "Right click: unlock the frames to move them" },
    onClick = function() D.ToggleConfig() end,
    onRightClick = function() D.SetUnlocked(not D.unlocked) end,
})

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    D.MakeMovable(dock, "Dock", DeckUIForeverDB)
    D.MakeDraggable(dock)
    if D.OnUnlock then D.OnUnlock(function() Layout() end) end
    Layout()
end)
