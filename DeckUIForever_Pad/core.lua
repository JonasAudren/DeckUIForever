local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Blizzard's controller action bar in the hotbar look
-------------------------------------------------------------------
-- Owner's wish (2026-11-07, after the first Steam Deck run): Blizzard's
-- gamepad style stays - its cross hotbar, targeting, radial menus and
-- window navigation work better on the Deck than our own would - but the
-- bar should look like the rest of DeckUIForever. So this module changes
-- the look only: nothing of the input, the bindings, the pages, the
-- positions or the Edit Mode settings is touched. Blizzard's bar is a
-- set of secure action buttons on GamepadMainActionBarFrame (one page
-- unit: top, left, right and bottom bar, a stance and a possess bar, the
-- two targeting bars of the shoulders, the shortcuts bar, the two class
-- action buttons); each button carries the standard action button art
-- plus square and circle variants of border, shadow, mask and glow that
-- Blizzard swaps with SetShapeToSquare / SetShapeToCircle on every
-- expand, collapse and press (Blizzard_GamepadActionBars/
-- ActionBarStyles.lua: the D-pad group is square, the face group round).
--
-- The look is the Bars module's FFXIV slot (owner: "all square, like
-- FFXIV", 2026-11-07): a faint black shade under a thin light outline,
-- the icon behind a rounded mask, no Blizzard border, shadow or glow;
-- the button glyph (A, B, X, Y, D-pad) small in the top-left corner as
-- the keys sit on the PC's bars; a flat dark panel in place of the
-- focus art behind the active bar. The face group's circle is dropped by
-- hiding its circle mask once Blizzard has shown it - everything is
-- done through hooksecurefunc on the buttons' own methods and textures,
-- so Blizzard's secure path never reads a value of ours: sizes and
-- anchors stay Blizzard's (the 4 px shrink on a press included), and
-- no protected call runs tainted in combat. Undo needs a reload.
-- DeckUIForeverPadDB: glyphs, emptyGlyph, focusPanel, slotAlpha.
-------------------------------------------------------------------
local MASK = "Interface\\AddOns\\DeckUIForever_Pad\\textures\\slot_rounded"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local FOCUS_ATLAS = "gamepad-actionbar-focus-bg-section"
local SQUARE_FILL_MASK = "UI-HUD-ActionBar-IconFrame-Mask"
local SQUARE_CAST_END_MASK = "gamepad-actionbar-squareslot-castend-mask"
local SQUARE_CHANNEL_GLOW = "gamepad-actionbar-squareslot-channel"
local SQUARE_CASTING_GLOW = "gamepad-actionbar-squareslot-casting"

local DEFAULTS = {
    glyphs     = true,   -- the button glyph in every slot's corner, not only on the focused bar
    emptyGlyph = false,  -- Blizzard's big glyph as the background of an empty slot
    focusPanel = true,   -- a flat dark panel behind the active bar in place of Blizzard's focus art
    slotAlpha  = 0.2,    -- the shade of a slot
}

local dressed = {}   -- button -> true
local bars = {}      -- the bars we dressed, for the glyph and panel options
local dressedAll = false

-- A texture of Blizzard's kept invisible: alpha 0 now, and again after
-- every SetTexture / SetAtlas - Blizzard sets the atlas anew on each
-- shape change (SetNormalAtlas and friends reuse the texture objects).
local function Fade(tex)
    if not tex or tex.DeckFaded then return end
    tex.DeckFaded = true
    tex:SetAlpha(0)
    for _, setter in ipairs({ "SetTexture", "SetAtlas" }) do
        if tex[setter] then hooksecurefunc(tex, setter, function(self) self:SetAlpha(0) end) end
    end
end

-- The focus shadows and glows: their alpha is driven by Blizzard's
-- animation groups, so the texture itself goes (nothing sets it again
-- from Lua; the hook is for safety).
local function Kill(tex)
    if not tex or tex.DeckKilled then return end
    tex.DeckKilled = true
    tex:SetTexture(nil)
    if tex.SetAtlas then hooksecurefunc(tex, "SetAtlas", function(self) self:SetTexture(nil) end) end
end

-- the glyph frame (Blizzard's ButtonIcon, an InputIconTextureFrame) in
-- the top-left corner, where the PC's bars write their keys; Blizzard
-- anchors it top-right on every expand and collapse, so this runs after
-- each shape change
local function PlaceGlyph(b)
    local icon = b.ButtonIcon
    if not icon then return end
    icon:ClearAllPoints()
    icon:SetSize(14, 14)
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
end

-- after each of Blizzard's shape changes: all square again
local function ApplySquare(b)
    -- the face group's circle mask and shadow go away once Blizzard has
    -- shown them (our hook runs after its SetShapeToCircle); the square
    -- mask (3 px inset) too - ours is on the icon instead, full slot, rounded
    if b.CircleMask then b.CircleMask:Hide() end
    if b.SquareMask then b.SquareMask:Hide() end
    if b.IconMask then b.IconMask:Hide() end
    if b.cooldown then
        b.cooldown:SetSwipeTexture(MASK)
        b.cooldown:SetSwipeColor(0, 0, 0, 0.7)
        b.cooldown:SetDrawEdge(false)
    end
    PlaceGlyph(b)
end

local function Dress(b)
    if not b or dressed[b] then return end
    dressed[b] = true

    local mask = b:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b)

    -- the slot: the shade below Blizzard's icon (BACKGROUND -7), the
    -- outline over everything, as the Bars module draws its slots
    local slot = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    slot:SetAllPoints()
    slot:SetTexture(MASK)
    slot:SetVertexColor(0, 0, 0, DeckUIForeverPadDB.slotAlpha)
    b.DeckSlot = slot
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = b:CreateTexture(nil, "OVERLAY", nil, 6)
        line:SetTexture(WHITE)
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
    if b.Flash then b.Flash:AddMaskTexture(mask) end
    if b.SpecialActionIcon then b.SpecialActionIcon:AddMaskTexture(mask) end

    -- Blizzard's art: the normal, pushed, hover and checked borders are
    -- set per shape on the same texture objects, the drop shadows and
    -- focus glows once in XML
    Fade(b.NormalTexture)
    Fade(b.GetNormalTexture and b:GetNormalTexture())
    Fade(b.PushedTexture)
    Fade(b.GetPushedTexture and b:GetPushedTexture())
    Fade(b.HighlightTexture)
    Fade(b.GetHighlightTexture and b:GetHighlightTexture())
    Fade(b.CheckedTexture)
    Fade(b.GetCheckedTexture and b:GetCheckedTexture())
    Fade(b.Border)
    Fade(b.SpellHighlightTexture)
    Fade(b.NewActionTexture)
    Fade(b.SlotBackground)
    Kill(b.CircleShadow)
    Kill(b.SquareShadow)
    Kill(b.CircleShadowFocus)
    Kill(b.SquareShadowFocus)
    Kill(b.CircleGlowFocus)
    Kill(b.SquareGlowFocus)
    -- the empty-slot glyph art: a setting (read once; a reload to change)
    if b.SlotArt and not DeckUIForeverPadDB.emptyGlyph then Fade(b.SlotArt) end

    -- our states: hover white, pressed gold, checked blue, as the Bars module glows
    local fx = CreateFrame("Frame", nil, b)
    fx:SetAllPoints()
    fx:SetFrameLevel(b:GetFrameLevel() + 3)
    local function Glow(r, g, bl, a)
        local t = fx:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetTexture(WHITE)
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
    -- a pad press is not a mouse press: Blizzard sets the button state
    hooksecurefunc(b, "SetButtonState", function(self, state) self.DeckPushed:SetShown(state == "PUSHED") end)
    hooksecurefunc(b, "SetChecked", function(self, on) self.DeckChecked:SetShown(on and true or false) end)
    if b.GetChecked and b:GetChecked() then b.DeckChecked:Show() end

    if b.Count then b.Count:SetFont(D.FONT, 12, "OUTLINE") end

    if b.SetShapeToCircle then hooksecurefunc(b, "SetShapeToCircle", ApplySquare) end
    if b.SetShapeToSquare then hooksecurefunc(b, "SetShapeToSquare", ApplySquare) end
    -- the cast and channel fill of the face group would run in a circle:
    -- Blizzard calls the function it captured at the shape change, which
    -- is the hooked one, so the square atlases follow its circle ones
    if b.SetCircleCastingTextures then
        hooksecurefunc(b, "SetCircleCastingTextures", function(self, isChannel)
            local anim = self.SpellCastAnimFrame
            if not anim then return end
            local fill, burst = anim.Fill, anim.EndBurst
            if fill then
                if fill.FillMask then fill.FillMask:SetAtlas(SQUARE_FILL_MASK) end
                if fill.InnerGlowTexture then fill.InnerGlowTexture:SetAtlas(isChannel and SQUARE_CHANNEL_GLOW or SQUARE_CASTING_GLOW, true) end
            end
            if burst and burst.EndMask then burst.EndMask:SetAtlas(SQUARE_CAST_END_MASK) end
        end)
    end
    ApplySquare(b)
end

-------------------------------------------------------------------
-- A bar: its buttons, the glyphs, the focus panel
-------------------------------------------------------------------
local function BarButtons(bar)
    local list = {}
    if bar.actionButtons then
        for _, b in ipairs(bar.actionButtons) do list[#list + 1] = b end
    else
        for _, group in ipairs({ bar.Left, bar.Right }) do
            if group then
                for i = 1, 4 do
                    if group["ActionButton" .. i] then list[#list + 1] = group["ActionButton" .. i] end
                end
            end
        end
    end
    return list
end

local function ShowGlyphs(bar)
    if not DeckUIForeverPadDB.glyphs then return end
    for _, b in ipairs(BarButtons(bar)) do
        if b.ButtonIcon then b.ButtonIcon:Show() end
    end
end

-- the focus art behind the active bar: a flat panel in our look, or
-- Blizzard's atlas again. The texture keeps Blizzard's show and hide
-- (its Edit Mode "highlight" setting); the outline follows it.
function ns.ApplyFocusPanel(bar)
    local focus = bar.BackgroundFocus
    if not focus then return end
    if DeckUIForeverPadDB.focusPanel then
        focus:SetTexture(WHITE)
        focus:SetVertexColor(0, 0, 0, 1)   -- the texture's own alpha (0.375 in XML) stays
        focus:ClearAllPoints()
        focus:SetPoint("TOPLEFT", bar, "TOPLEFT", -6, 6)
        focus:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
        focus.DeckFlat = true
    elseif focus.DeckFlat then
        focus:SetAtlas(FOCUS_ATLAS)
        focus:SetVertexColor(1, 1, 1, 1)
        focus:ClearAllPoints()
        focus:SetSize(512, 160)
        focus:SetPoint("CENTER")
        focus.DeckFlat = nil
    end
    local on = DeckUIForeverPadDB.focusPanel and focus:IsShown()
    for _, line in ipairs(bar.DeckLines or {}) do line:SetShown(on) end
end

local function DressBar(bar)
    if not bar or bar.DeckDressed then return end
    bar.DeckDressed = true
    bars[#bars + 1] = bar
    for _, b in ipairs(BarButtons(bar)) do Dress(b) end

    -- the glyphs on every bar, not only the focused one: Blizzard hides
    -- them when a bar loses focus and when its "button prompts" setting is off
    if bar.HideButtonIcons then hooksecurefunc(bar, "HideButtonIcons", ShowGlyphs) end
    ShowGlyphs(bar)

    local focus = bar.BackgroundFocus
    if focus then
        bar.DeckLines = {}
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local line = bar:CreateTexture(nil, "BORDER")
            line:SetTexture(WHITE)
            line:SetVertexColor(0.85, 0.85, 0.85, 0.25)
            if side == "TOP" or side == "BOTTOM" then
                line:SetPoint(side .. "LEFT", focus, side .. "LEFT")
                line:SetPoint(side .. "RIGHT", focus, side .. "RIGHT")
                line:SetHeight(1)
            else
                line:SetPoint("TOP" .. side, focus, "TOP" .. side)
                line:SetPoint("BOTTOM" .. side, focus, "BOTTOM" .. side)
                line:SetWidth(1)
            end
            line:Hide()
            bar.DeckLines[#bar.DeckLines + 1] = line
        end
        local function Follow(self)
            local on = DeckUIForeverPadDB.focusPanel and self:IsShown()
            for _, line in ipairs(bar.DeckLines) do line:SetShown(on) end
        end
        hooksecurefunc(focus, "Show", Follow)
        hooksecurefunc(focus, "Hide", Follow)
        hooksecurefunc(focus, "SetShown", Follow)
        ns.ApplyFocusPanel(bar)
    end
end

-------------------------------------------------------------------
-- Apply: the whole page unit, then the live settings
-------------------------------------------------------------------
function ns.Apply()
    local frame = _G.GamepadMainActionBarFrame
    local unit = frame and frame.PageUnit
    if not unit then return false end
    if not dressedAll then
        dressedAll = true
        -- Blizzard anchors the glyph top-right after the shape change, in
        -- the icon style of its two style functions (ActionBarStyles.lua);
        -- the glyph goes back to the corner once they are through. The
        -- glyph frame is not protected, so this is safe in combat too.
        local util = _G.GamepadActionBarStyleUtil
        if util then
            local function Replace(actionBar)
                for _, b in ipairs(BarButtons(actionBar)) do
                    if dressed[b] then PlaceGlyph(b) end
                end
            end
            for _, name in ipairs({ "ApplyCollapsedActionBarStyle", "ApplyExpandedActionBarStyle" }) do
                if util[name] then hooksecurefunc(util, name, Replace) end
            end
        end
        for _, bar in pairs(unit.actionBars or {}) do DressBar(bar) end
        -- and by key, should actionBars be missing on another build
        for _, key in ipairs({ "TopCenteredAnchor", "BottomCenteredAnchor", "LeftCenteredAnchor", "RightCenteredAnchor" }) do
            local anchor = unit[key]
            if anchor then
                DressBar(anchor.Bar)
                DressBar(anchor.PossessBar)
                DressBar(anchor.StanceBar)
            end
        end
        DressBar(unit.FriendlyTargetingActionBar)
        DressBar(unit.HostileTargetingActionBar)
        DressBar(unit.ShortcutsActionBar)
        Dress(unit.LeftClassAction)
        Dress(unit.RightClassAction)
    end
    for b in pairs(dressed) do
        if b.DeckSlot then b.DeckSlot:SetVertexColor(0, 0, 0, DeckUIForeverPadDB.slotAlpha) end
    end
    for _, bar in ipairs(bars) do
        ns.ApplyFocusPanel(bar)
        ShowGlyphs(bar)
    end
    return true
end

function ns.ApplyGlyphs()
    for _, bar in ipairs(bars) do
        for _, b in ipairs(BarButtons(bar)) do
            if b.ButtonIcon then b.ButtonIcon:SetShown(DeckUIForeverPadDB.glyphs and true or false) end
        end
    end
end

-- /df pad
function ns.Print()
    local frame = _G.GamepadMainActionBarFrame
    local style = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and C_InputInterfaceStyle.GetCurrentStyle()
    local n = 0
    for _ in pairs(dressed) do n = n + 1 end
    print(("DeckUIForever Pad: interface style %s, Blizzard's bar %s (%s), %d buttons on %d bars dressed, glyphs %s, empty glyph %s, panel %s, shade %s"):format(
        tostring(style), frame and "found" or "missing", frame and (frame:IsShown() and "shown" or "hidden") or "-",
        n, #bars, tostring(DeckUIForeverPadDB.glyphs), tostring(DeckUIForeverPadDB.emptyGlyph),
        tostring(DeckUIForeverPadDB.focusPanel), tostring(DeckUIForeverPadDB.slotAlpha)))
end
D.PrintPad = ns.Print

-------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    DeckUIForeverPadDB = DeckUIForeverPadDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckUIForeverPadDB[k] == nil then DeckUIForeverPadDB[k] = v end
    end
    if not ns.Apply() then
        print("DeckUIForever Pad: Blizzard's controller action bar was not found - nothing to dress.")
    end
end)
