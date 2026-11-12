local D = DeckUIForever

-- Each container keeps a list of its widgets so they can be refreshed when shown
local function Register(parent, widget)
    parent.widgets = parent.widgets or {}
    table.insert(parent.widgets, widget)
end

function D.RefreshWidgets(parent)
    if not parent.widgets then return end
    for _, w in ipairs(parent.widgets) do
        if w.Refresh then w:Refresh() end
    end
end

-------------------------------------------------------------------
-- Heading
-------------------------------------------------------------------
function D.Label(parent, text, y, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, size or 14, "OUTLINE")
    fs:SetPoint("TOP", 0, y)
    fs:SetText(text)
    return fs
end

-------------------------------------------------------------------
-- Hint: the small grey line under a control
-------------------------------------------------------------------
-- Width-limited on purpose. Without it a long line runs straight out of the
-- panel and loses its last characters - "disabling after /reload" was cut
-- off mid-word. Let the font string wrap; never hand-place newlines, they
-- fight the wrapping and leave single words stranded on their own line.
function D.Hint(parent, text, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, 11, "OUTLINE")
    fs:SetPoint("TOP", 0, y)
    fs:SetWidth(width or 290)
    fs:SetJustifyH("CENTER")
    fs:SetTextColor(0.7, 0.7, 0.7)
    fs:SetText(text)
    return fs
end

-------------------------------------------------------------------
-- DeckUIForever's flat look: a dark fill and four one-pixel lines, anchored only
-------------------------------------------------------------------
-- The same box the week window, the raid tiles and the bags wear. Never
-- BackdropTemplate on anything a tooltip could size (see the Tooltip
-- notes); plain textures are safe everywhere.
function D.FlatBox(frame, alpha, edge)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, alpha or 0.95)
    local c = edge or 0.3
    local lines = {}
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(c, c, c, 1)
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
        lines[#lines + 1] = t
    end
    return bg, lines
end

-- A Blizzard panel button in the flat look: its three-piece red art at
-- alpha 0 (textures only, the template's scripts stay), our box instead,
-- a lighter fill under the mouse.
function D.FlattenButton(b)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        if b[key] then b[key]:SetAlpha(0) end
    end
    for _, tex in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b:GetDisabledTexture() }) do
        tex:SetAlpha(0)
    end
    local hl = b:GetHighlightTexture()
    if hl then
        hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        hl:SetVertexColor(1, 1, 1, 0.08)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    local bg = D.FlatBox(b, 1, 0.35)
    bg:SetColorTexture(0.12, 0.12, 0.12, 1)
    return b
end

-------------------------------------------------------------------
-- Button
-------------------------------------------------------------------
function D.Button(parent, text, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(260, 34)
    b:SetPoint("TOP", 0, y)
    b:SetText(text)
    b:GetFontString():SetFont(D.FONT, 15, "OUTLINE")
    b:SetScript("OnClick", onClick)
    D.FlattenButton(b)
    return b
end

-------------------------------------------------------------------
-- Slider: text, y, min, max, step, format function,
--         db = function returning the table, key = field in it, apply = function(value)
-------------------------------------------------------------------
local sliderCount = 0
function D.Slider(parent, text, y, minV, maxV, step, fmt, db, key, apply)
    sliderCount = sliderCount + 1
    local name = "DeckUIForeverSlider" .. sliderCount

    D.Label(parent, text, y, 14)

    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOP", 0, y - 22)
    s:SetWidth(240)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    _G[name .. "Low"]:SetText(fmt(minV))
    _G[name .. "High"]:SetText(fmt(maxV))
    -- OptionsSliderTemplate parks its value text right above the slider,
    -- which is exactly where our heading sits - the two printed on top of
    -- each other. It moves below the bar instead, into the gap between the
    -- min and max labels, which is empty. Appending it to the heading was
    -- the other option and was dropped: headings have no width limit, so
    -- "Buffs up to duration (needs /reload)   5 min" would have traded this
    -- bug for the one next door.
    s.valueText = _G[name .. "Text"]
    s.valueText:ClearAllPoints()
    s.valueText:SetPoint("TOP", s, "BOTTOM", 0, 3)

    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        self.valueText:SetText(fmt(v))
        if not self.loading then apply(v) end
    end)

    function s:Refresh()
        self.loading = true
        local v = db()[key] or minV
        self:SetValue(v)
        -- SetValue stays quiet when the value did not actually change, so
        -- the text is written here rather than left blank.
        self.valueText:SetText(fmt(v))
        self.loading = false
    end

    Register(parent, s)
    return s
end

-------------------------------------------------------------------
-- Checkbox: text, y, db = function returning the table, key, apply
-------------------------------------------------------------------
function D.Checkbox(parent, text, y, db, key, apply)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(28, 28)
    cb:SetPoint("TOPLEFT", 20, y)

    local t = cb:CreateFontString(nil, "OVERLAY")
    t:SetFont(D.FONT, 14, "OUTLINE")
    t:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    -- The box starts 20 in from a 320-wide content area and is 28 across, so
    -- this is what is left. Without the limit a long label ran off the right
    -- edge instead of wrapping onto a second line.
    t:SetWidth(258)
    t:SetJustifyH("LEFT")
    t:SetText(text)

    cb:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        db()[key] = v
        apply(v)
    end)

    function cb:Refresh()
        self:SetChecked(db()[key])
    end

    Register(parent, cb)
    return cb
end

-------------------------------------------------------------------
-- Dialog: a question with two buttons, optionally a money input
-------------------------------------------------------------------
-- Never StaticPopup_Show from addon code: StaticPopup1..4 are shared by the
-- whole game, a dialog shown from our code keeps fields written while
-- tainted, and the next Blizzard dialog on the same frame - some of which
-- call protected functions on accept - runs tainted too. One window of our
-- own instead, one question at a time; a new question replaces the old.
--
-- opts: text, onAccept(copper), accept / cancel (button texts), width,
--       money = true for a gold/silver/copper input (Blizzard's
--       MoneyInputFrameTemplate - an instance of our own, so it is ours),
--       key = anything, so a caller can tell whether its question is up.
local dialog

local function BuildDialog()
    local f = CreateFrame("Frame", "DeckUIForeverDialog", UIParent, "BackdropTemplate")
    f:SetPoint("TOP", 0, -160)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    f:Hide()
    tinsert(UISpecialFrames, "DeckUIForeverDialog")

    f.text = D.Hint(f, "", -14)
    f.text:SetTextColor(1, 1, 1)

    f.money = CreateFrame("Frame", "DeckUIForeverDialogMoney", f, "MoneyInputFrameTemplate")
    f.money:Hide()

    f.accept = D.Button(f, ACCEPT or "Accept", 0, function()
        local opts = f.opts
        local copper = opts.money and MoneyInputFrame_GetCopper(f.money) or nil
        f:Hide()
        if opts.onAccept then opts.onAccept(copper) end
    end)
    f.cancel = D.Button(f, CANCEL or "Cancel", 0, function() f:Hide() end)
    for _, b in ipairs({ f.accept, f.cancel }) do
        b:SetSize(130, 26)
        b:GetFontString():SetFont(D.FONT, 13, "OUTLINE")
        b:ClearAllPoints()
    end
    f.accept:SetPoint("BOTTOMLEFT", 16, 14)
    f.cancel:SetPoint("BOTTOMRIGHT", -16, 14)

    f:SetScript("OnHide", function(self)
        MoneyInputFrame_ResetMoney(self.money)
        MoneyInputFrame_ClearFocus(self.money)
        self.opts = nil
    end)
    -- a popup: the pad's cursor comes back to the window it was in
    if D.GamepadWindow then D.GamepadWindow(f, { popup = true, close = f.cancel }) end
    return f
end

function D.Dialog(opts)
    dialog = dialog or BuildDialog()
    dialog:Hide()
    dialog.opts = opts
    local width = opts.width or 320
    dialog:SetWidth(width)
    dialog.text:SetWidth(width - 30)
    dialog.text:SetText(opts.text or "")
    dialog.accept:SetText(opts.accept or ACCEPT or "Accept")
    dialog.cancel:SetText(opts.cancel or CANCEL or "Cancel")

    local height = 14 + dialog.text:GetStringHeight() + 12
    dialog.money:SetShown(opts.money and true or false)
    if opts.money then
        dialog.money:ClearAllPoints()
        dialog.money:SetPoint("TOP", dialog.text, "BOTTOM", 10, -12)
        height = height + 34
    end
    dialog:SetHeight(height + 54)
    dialog:Show()
    if opts.money then dialog.money.gold:SetFocus() end
end

-- the question with this key, if it is the one on screen
function D.DialogShown(key)
    return dialog and dialog:IsShown() and dialog.opts and dialog.opts.key == key
end

function D.HideDialog(key)
    if dialog and (key == nil or D.DialogShown(key)) then dialog:Hide() end
end

-------------------------------------------------------------------
-- Flow: the widgets above, stacked without pixel numbers
-------------------------------------------------------------------
-- A settings page used to place every widget at a hand-counted y, and every
-- new option moved everything below it. D.Flow keeps the cursor instead:
--   local f = D.Flow(content)
--   f:Label("Raid frames"); f:Checkbox("Show", db, "showRaid", apply)
--   f:Slider("Size", 0.5, 1.4, 0.05, pct, db, "scale", apply); f:Hint("...")
-- Each call returns the widget, like the plain functions. The page scrolls
-- (panel.lua), so a long page is no longer a problem.
local Flow = {}
Flow.__index = Flow

-- the explanation a page used to print under a widget, on mouse-over instead
function D.Tip(frame, title, text)
    if not text then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

function D.Flow(parent, y)
    return setmetatable({ parent = parent, y = y or -6 }, Flow)
end

function Flow:Gap(n) self.y = self.y - (n or 10) end

function Flow:Label(text, size)
    local fs = D.Label(self.parent, text, self.y, size or 15)
    self.y = self.y - 24
    return fs
end

-- tip: optional mouse-over explanation (D.Tip)
function Flow:Checkbox(text, db, key, apply, tip)
    local cb = D.Checkbox(self.parent, text, self.y, db, key, apply or function() end)
    D.Tip(cb, text, tip)
    self.y = self.y - 28
    return cb
end

function Flow:Slider(text, minV, maxV, step, fmt, db, key, apply, tip)
    local s = D.Slider(self.parent, text, self.y, minV, maxV, step, fmt, db, key, apply)
    D.Tip(s, text, tip)
    self.y = self.y - 64
    return s
end

function Flow:Button(text, onClick, tip)
    local b = D.Button(self.parent, text, self.y, onClick)
    D.Tip(b, text, tip)
    self.y = self.y - 40
    return b
end

-- two buttons side by side, each half the page wide; left and right are
-- { text = , onClick = , tip = }. Returns both buttons.
function Flow:Pair(left, right)
    local width = math.floor((self.parent:GetWidth() - 24) / 2)
    local function Make(def, point, x)
        local b = D.Button(self.parent, def.text, self.y, def.onClick)
        b:SetSize(width, 28)
        b:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        b:ClearAllPoints()
        b:SetPoint(point, self.parent, point, x, self.y)
        D.Tip(b, def.title or def.text, def.tip)
        return b
    end
    local a = Make(left, "TOPLEFT", 8)
    local b = right and Make(right, "TOPRIGHT", -8)
    self.y = self.y - 34
    return a, b
end

-- Two buttons that step through a list of values each. A side is
-- { label = , values = { ... }, names = { [value] = text }, get = fn, set = fn(v), tip = }
-- and reads "label: name". Both refresh when the page shows.
function Flow:Cycles(left, right)
    local function Wire(b, def)
        if not (b and def) then return end
        local function Text() return def.label .. ": " .. (def.names[def.get()] or tostring(def.get())) end
        b:SetScript("OnClick", function(self)
            local cur, nextValue = def.get(), def.values[1]
            for i, v in ipairs(def.values) do
                if v == cur then nextValue = def.values[i % #def.values + 1] end
            end
            def.set(nextValue)
            self:SetText(Text())
        end)
        function b:Refresh() self:SetText(Text()) end
        Register(self.parent, b)
    end
    local a, b = self:Pair(
        { text = left.label, title = left.label, tip = left.tip },
        right and { text = right.label, title = right.label, tip = right.tip })
    Wire(a, left)
    Wire(b, right)
    return a, b
end

-- anything else: build(parent, y) places it, height is what it takes
function Flow:Add(height, build)
    local result = build(self.parent, self.y)
    self.y = self.y - height
    return result
end

function Flow:Hint(text)
    local fs = D.Hint(self.parent, text, self.y)
    self.y = self.y - fs:GetStringHeight() - 10
    return fs
end

-------------------------------------------------------------------
-- Flow: the important options first, the fine-tuning on request
-------------------------------------------------------------------
-- The third menu review (owner 2026-11-12: "einsteigerfreundlicher, etwas
-- geführter - es kommen sehr viele Optionen dazu, da verliert man den
-- Überblick"). A page marks where its fine-tuning starts:
--   f:More()               from here to the next Label: fine-tuning
--   f:MoreSection("Look")  a whole section of fine-tuning, heading included
--   f:Basic()              important again, before the next Label
-- A Label ends it. While DeckUIForeverDB.showAllOptions is off, the
-- fine-tuning is hidden and the page closes up over it; a line at the
-- page's end says how many options wait and shows them (D.SetShowAll).
--
-- For that every Flow call is recorded as an item: the frames and font
-- strings it added to the page (whatever is new among the page's children
-- and regions), their place relative to the item's top, its height, and -
-- for the search (panel.lua) - its text and explanation. Relayout walks
-- the items and stacks the visible ones again. Only what hangs on the page
-- by a single point moves; a widget anchored to another follows that one.
-- A page that never calls More is laid out exactly as before.
local RECORDED = { "Label", "Checkbox", "Slider", "Button", "Pair", "Cycles", "Add", "Hint" }

local function Count(...) return select("#", ...) end

local function Collect(item, parent, from, ...)
    for i = from + 1, select("#", ...) do
        local r = select(i, ...)
        local o = { r = r }
        if r:GetNumPoints() == 1 then
            local point, rel, relPoint, x, y = r:GetPoint(1)
            if rel == parent or rel == nil then
                o.point, o.relPoint, o.x, o.dy = point, relPoint, x, y - item.y0
            end
        end
        item.objs[#item.objs + 1] = o
    end
end

-- what the search finds an item by: { text, tip } per option in it
local function Texts(name, ...)
    local a, b, c = ...
    if name == "Checkbox" then return { { a, (select(5, ...)) } } end
    if name == "Slider" then return { { a, (select(9, ...)) } } end
    if name == "Button" then return { { a, c } } end
    if name == "Pair" or name == "Cycles" then
        local list = {}
        for _, def in ipairs({ a, b }) do
            if type(def) == "table" then list[#list + 1] = { def.title or def.label or def.text, def.tip } end
        end
        return list
    end
    return nil
end

for _, name in ipairs(RECORDED) do
    local raw = Flow[name]
    Flow[name] = function(self, ...)
        if self.inside then return raw(self, ...) end   -- Cycles builds on Pair
        if name == "Label" then
            self.more = self.nextMore or false
            self.nextMore = nil
            self.section = (...)
        end
        local parent = self.parent
        local children, regions = Count(parent:GetChildren()), Count(parent:GetRegions())
        local item = { y0 = self.y, objs = {}, more = self.more, section = self.section,
                       texts = Texts(name, ...), kind = name }
        self.inside = true
        local r1, r2 = raw(self, ...)
        self.inside = false
        item.h = item.y0 - self.y
        Collect(item, parent, children, parent:GetChildren())
        Collect(item, parent, regions, parent:GetRegions())
        self.items[#self.items + 1] = item
        -- one value where the call gave one: table.insert(t, f:Add(...))
        -- takes a second value, even nil, for a position (owner's error
        -- 2026-11-12, panel.lua "bad argument #2 to 'insert'")
        if r2 == nil then return r1 end
        return r1, r2
    end
end

local rawGap = Flow.Gap
function Flow:Gap(n)
    local y0 = self.y
    rawGap(self, n)
    self.items[#self.items + 1] = { y0 = y0, h = y0 - self.y, objs = {}, more = self.more, kind = "Gap" }
end

function Flow:More() self.more = true end
-- back to the important options before the next Label (a loop that mixes both)
function Flow:Basic() self.more = false end

function Flow:MoreSection(text, size)
    self.nextMore = true
    return self:Label(text, size)
end

local rawFlow = D.Flow
function D.Flow(parent, y)
    local f = rawFlow(parent, y)
    f.items, f.top, f.more = {}, f.y, false
    parent.flows = parent.flows or {}
    table.insert(parent.flows, f)
    return f
end

-- the line under a page with fine-tuning: shows or hides it
local function MoreLine(self)
    if self.moreLine then return self.moreLine end
    local b = CreateFrame("Button", nil, self.parent)
    b:SetSize(300, 22)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(D.FONT, 12, "OUTLINE")
    b.text:SetPoint("CENTER")
    b.text:SetTextColor(1, 0.82, 0)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
    b:SetScript("OnClick", function() D.SetShowAll(not DeckUIForeverDB.showAllOptions) end)
    D.Tip(b, "Fine-tuning", "Every page shows its important options first. The rest - sizes, looks, special cases - is the fine-tuning. This switch is for all pages; \"All options\" at the bottom of the window does the same.")
    self.moreLine = b
    return b
end

-- stacks the page again: `all` shows the fine-tuning too
function Flow:Relayout(all)
    local y, waiting = self.top, 0
    for _, it in ipairs(self.items) do
        local show = all or not it.more
        if it.more and it.texts then waiting = waiting + #it.texts end
        if show ~= (not it.hidden) then
            it.hidden = not show
            for _, o in ipairs(it.objs) do
                if show then
                    o.r:SetShown(o.shown)
                else
                    o.shown = o.r:IsShown()
                    o.r:Hide()
                end
            end
        end
        if show then
            for _, o in ipairs(it.objs) do
                if o.point then o.r:SetPoint(o.point, self.parent, o.relPoint, o.x, y + o.dy) end
            end
            it.at = y
            y = y - it.h
        else
            it.at = nil
        end
    end
    if waiting > 0 then
        local line = MoreLine(self)
        line:ClearAllPoints()
        line:SetPoint("TOP", self.parent, "TOP", 0, y - 6)
        line.text:SetText(all and ("Hide the fine-tuning (%d options)"):format(waiting)
            or ("+ %d more options: show the fine-tuning"):format(waiting))
        line:Show()
    elseif self.moreLine then
        self.moreLine:Hide()
    end
    return waiting
end

-- a page's Flows in the mode that is set; reveal: this page shows all
function D.ApplyOptionMode(content)
    if not content.flows then return end
    local all = DeckUIForeverDB.showAllOptions or content.reveal
    for _, f in ipairs(content.flows) do f:Relayout(all and true or false) end
end
