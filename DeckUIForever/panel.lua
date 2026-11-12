local D = DeckUIForever

-------------------------------------------------------------------
-- The settings window: a sidebar of pages, the page scrolls
-------------------------------------------------------------------
-- Rebuilt 2026-10-02 (owner's choice from the menu review): thirteen tabs
-- in two rows of 42-pixel buttons had become unreadable, and every page
-- was hand-placed to the pixel inside a window that could neither grow
-- (the Deck's 800-pixel screen) nor scroll - each new option meant moving
-- everything below it. Now:
--  - a sidebar on the left, pages grouped by theme (D.PAGE_GROUPS); a page
--    a module registers lands in its group, an unknown one under "More";
--  - the page on the right scrolls, so its length no longer matters;
--  - a bar at the bottom collects changes that need a /reload
--    (D.NeedReload), with a button that does it.
-- Pages keep their old build(content) functions for now - they are moved
-- to D.Flow (widgets.lua) one by one.
-------------------------------------------------------------------
local W, H = 600, 540
local SIDE_W = 160
local GOLD = { 1, 0.82, 0 }

local panel = CreateFrame("Frame", "DeckUIForeverPanel", UIParent)
panel:SetSize(W, H)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetToplevel(true)
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
D.FlatBox(panel, 0.95)
panel:Hide()
tinsert(UISpecialFrames, "DeckUIForeverPanel")
D.panel = panel

local title = panel:CreateFontString(nil, "OVERLAY")
title:SetFont(D.FONT, 18, "OUTLINE")
title:SetPoint("TOPLEFT", 14, -12)
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
title:SetText("DeckUIForever")

local pageTitle = panel:CreateFontString(nil, "OVERLAY")
pageTitle:SetFont(D.FONT, 16, "OUTLINE")
pageTitle:SetPoint("TOPLEFT", SIDE_W + 22, -14)

local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

-------------------------------------------------------------------
-- Groups and names of the pages
-------------------------------------------------------------------
-- The second menu review (owner 2026-11-07, "simpler"): the hub's own
-- pages (Screen, Targets, Windows) stand in the General group for
-- everyone to see - as sub-pages of the Overview they were listed only
-- while the Overview was on show; the minimap settings moved onto the
-- Maps page and the tooltip's extra lines onto the Tooltip page (two
-- pages of a hint and six checkboxes each); the Orbs page is "Unit
-- frames", the Overview "Modules", the Units group "Frames".
D.PAGE_GROUPS = {
    { title = "General",   pages = { "General", "Devices", "Screen", "Targets", "Windows", "Console" } },
    { title = "Frames",    pages = { "Orbs", "FramePlayer", "FrameTarget", "FrameToT", "BuffBar", "Enemies", "Debuffs", "HoTs", "DeckHeal", "Group", "Raid" } },
    { title = "Actions",   pages = { "Bars", "Pad", "Spec", "Cross", "CrossController" } },
    { title = "World",     pages = { "Quests", "Questing", "Map", "MapWorld", "Nav" } },
    { title = "Inventory", pages = { "Bags", "Loot" } },
    { title = "Info",      pages = { "Tooltip", "Week" } },
}
-- the sidebar's name where the module's title is too short to say it
D.PAGE_NAMES = {
    Orbs = "Unit frames", Cross = "Cross hotbar", Spec = "Talent groups",
    Nav = "Navigation", Map = "Maps", Week = "Week overview", Bars = "Action bars", Pad = "Controller bar",
    Debuffs = "Your debuffs", HoTs = "Your HoTs", FramePlayer = "Player", FrameTarget = "Target", FrameToT = "Target of target",
    BuffBar = "Buff bar", Enemies = "Enemies and bosses", CrossController = "Controller",
    MapWorld = "World map",
}
-- A page shown indented under another, as part of it, and listed only
-- while that parent or a sibling is on show (owner's wish 2026-10-28, the
-- first menu review: the Overview had eighteen checkboxes, Player and
-- target as many plus six sliders). A sub-page of a module registers with
-- the module, so a module that is off shows only its stand-in.
D.PAGE_PARENT = {
    FramePlayer = "Orbs", FrameTarget = "Orbs", FrameToT = "Orbs", Debuffs = "Orbs", HoTs = "Orbs", DeckHeal = "Orbs",
    BuffBar = "Orbs", Enemies = "Orbs",
    CrossController = "Cross",
    MapWorld = "Map",
}

-------------------------------------------------------------------
-- Sidebar
-------------------------------------------------------------------
local sideBox = CreateFrame("Frame", nil, panel)
sideBox:SetPoint("TOPLEFT", 8, -68)   -- the search field sits above it
sideBox:SetPoint("BOTTOMLEFT", 8, 8)
sideBox:SetWidth(SIDE_W)
D.FlatBox(sideBox, 0.6, 0.2)

-- The entries live on a list inside a scroll frame: with the sub-pages
-- unfolded the sidebar outgrew the window (2026-10-28), and the window
-- cannot grow - 540 is what the Deck's 800-pixel screen allows. The mouse
-- wheel scrolls it, and the page on show is always brought into view.
local sideScroll = CreateFrame("ScrollFrame", nil, sideBox)
sideScroll:SetPoint("TOPLEFT", 0, -2)
sideScroll:SetPoint("BOTTOMRIGHT", 0, 2)
local side = CreateFrame("Frame", nil, sideScroll)
side:SetSize(SIDE_W - 10, 10)
sideScroll:SetScrollChild(side)
sideScroll:EnableMouseWheel(true)
sideScroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, side:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 42)))
end)

-- A thin scrollbar at the box's right edge (owner 2026-11-07: "the left
-- box still lacks a scrollbar"): a faint track and a gold thumb the size
-- of the part in view. Drag the thumb, click the track for a page, or
-- wheel the list; it hides while everything fits.
local track = CreateFrame("Frame", nil, sideBox)
track:SetPoint("TOPRIGHT", -3, -4)
track:SetPoint("BOTTOMRIGHT", -3, 4)
track:SetWidth(4)
track:EnableMouse(true)
local trackBg = track:CreateTexture(nil, "BACKGROUND")
trackBg:SetAllPoints()
trackBg:SetColorTexture(1, 1, 1, 0.08)
local thumb = CreateFrame("Button", nil, track)
thumb:SetWidth(4)
thumb:SetPoint("TOP", 0, 0)
local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
thumbTex:SetAllPoints()
thumbTex:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.7)
track:Hide()

local function SideRange()
    local seen, total = sideScroll:GetHeight() or 0, side:GetHeight() or 0
    return seen, math.max(0, total - seen)
end

local function UpdateSideBar()
    local seen, max = SideRange()
    if seen <= 0 or max <= 1 then
        track:Hide()
        return
    end
    track:Show()
    local h = track:GetHeight() or 0
    local th = math.max(16, math.min(h, h * seen / (seen + max)))
    thumb:SetHeight(th)
    thumb:SetPoint("TOP", 0, -(h - th) * (sideScroll:GetVerticalScroll() / max))
end
sideScroll:SetScript("OnVerticalScroll", UpdateSideBar)
sideScroll:SetScript("OnScrollRangeChanged", UpdateSideBar)
sideScroll:SetScript("OnSizeChanged", UpdateSideBar)

local function CursorY(frame)
    return (select(2, GetCursorPosition())) / frame:GetEffectiveScale()
end

thumb:RegisterForDrag("LeftButton")
thumb:SetScript("OnDragStart", function(self)
    self.fromY, self.fromScroll = CursorY(self), sideScroll:GetVerticalScroll()
    self:SetScript("OnUpdate", function(b)
        local seen, max = SideRange()
        local room = (track:GetHeight() or 0) - (b:GetHeight() or 0)
        if room <= 0 or max <= 0 then return end
        local scrolled = b.fromScroll + (b.fromY - CursorY(b)) / room * max
        sideScroll:SetVerticalScroll(math.max(0, math.min(max, scrolled)))
    end)
end)
thumb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
track:SetScript("OnMouseDown", function(self)
    local y = CursorY(self)
    local seen, max = SideRange()
    local cur = sideScroll:GetVerticalScroll()
    if thumb:GetTop() and y > thumb:GetTop() then
        sideScroll:SetVerticalScroll(math.max(0, cur - seen))
    elseif thumb:GetBottom() and y < thumb:GetBottom() then
        sideScroll:SetVerticalScroll(math.min(max, cur + seen))
    end
end)

panel.tabs     = {}   -- key -> sidebar entry (the old name, kept for callers)
panel.contents = {}
panel.tabOrder = {}

local headings, usedHeadings = {}, 0

local function Heading(text, y)
    usedHeadings = usedHeadings + 1
    local fs = headings[usedHeadings]
    if not fs then
        fs = side:CreateFontString(nil, "OVERLAY")
        fs:SetFont(D.FONT, 11, "OUTLINE")
        fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        headings[usedHeadings] = fs
    end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 10, y)
    fs:SetText(text:upper())
    fs:Show()
end

local function NewEntry(key)
    local b = CreateFrame("Button", nil, side)
    b:SetSize(SIDE_W - 16, 20)   -- the scrollbar's track takes the right edge
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(D.FONT, 13, "OUTLINE")
    b.text:SetPoint("LEFT", 14, 0)
    b.text:SetJustifyH("LEFT")
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b.bar:SetPoint("TOPLEFT", 4, -3)
    b.bar:SetPoint("BOTTOMLEFT", 4, 3)
    b.bar:SetWidth(2)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b.fill:SetColorTexture(1, 1, 1, 0.07)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
    b:SetScript("OnClick", function() panel:ShowTab(key) end)
    -- a page with sub-pages wears a small chevron at the right: ">" while
    -- they are folded, "v" while they show (owner's wish, 2026-10-28)
    b.fold = b:CreateFontString(nil, "OVERLAY")
    b.fold:SetFont(D.FONT, 11, "OUTLINE")
    b.fold:SetPoint("RIGHT", -8, 0)
    b.fold:SetTextColor(0.6, 0.6, 0.6)
    b.fold:Hide()
    return b
end

-- does any registered page hang under this one?
local function HasSubPages(key)
    for sub, parent in pairs(D.PAGE_PARENT) do
        if parent == key and panel.tabs[sub] then return true end
    end
    return false
end

local function PageName(key)
    local content = panel.contents[key]
    return D.PAGE_NAMES[key] or (content and content.def.title) or key
end

-- A sub-page (D.PAGE_PARENT) is listed only while its parent, or one of
-- its siblings, is the page on show - so the sidebar stays short however
-- many there are (2026-10-28, the menu review: twenty pages and growing).
local function SubShown(key)
    local parent = D.PAGE_PARENT[key]
    if not parent then return true end
    local cur = panel.current
    return cur == parent or D.PAGE_PARENT[cur] == parent
end

local function LayoutSidebar()
    for i = 1, usedHeadings do headings[i]:Hide() end
    usedHeadings = 0
    for _, b in pairs(panel.tabs) do b:Hide() end

    local y, placed = -8, {}
    local function Group(name, keys)
        local any = false
        for _, key in ipairs(keys) do
            -- a module that is off has only its stand-in page: it is
            -- listed on the Start page, not here (owner 2026-11-12: the
            -- sidebar shows what you use) - except while it is on show
            local content = panel.contents[key]
            local off = content and content.def.stub and panel.current ~= key
            if panel.tabs[key] and not placed[key] and SubShown(key) and not off then
                if not any then
                    Heading(name, y)
                    y = y - 16
                    any = true
                end
                local b = panel.tabs[key]
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 4, y)
                local sub = D.PAGE_PARENT[key] ~= nil
                b.text:ClearAllPoints()
                b.text:SetPoint("LEFT", sub and 26 or 14, 0)
                b.text:SetFont(D.FONT, sub and 12 or 13, "OUTLINE")
                b.text:SetText(PageName(key))
                if HasSubPages(key) then
                    local open = panel.current == key or D.PAGE_PARENT[panel.current] == key
                    b.fold:SetText(open and "v" or ">")
                    b.fold:Show()
                else
                    b.fold:Hide()
                end
                b:Show()
                placed[key] = true
                y = y - 21
            end
        end
        if any then y = y - 8 end
    end
    for _, group in ipairs(D.PAGE_GROUPS) do Group(group.title, group.pages) end
    Group("More", panel.tabOrder)   -- whatever no group names
    side:SetHeight(-y + 4)
    -- the page on show stays in sight: scroll just enough to reach it
    local b = panel.current and panel.tabs[panel.current]
    local seen = sideScroll:GetHeight()
    if b and seen and seen > 0 then
        local top = -select(5, b:GetPoint(1))      -- its offset from the list's top edge
        local cur = sideScroll:GetVerticalScroll()
        if top + 21 > cur + seen then
            sideScroll:SetVerticalScroll(top + 21 - seen)
        elseif top < cur then
            sideScroll:SetVerticalScroll(top)
        end
    end
    UpdateSideBar()
end

-------------------------------------------------------------------
-- The page: a scroll frame on the right, plus the reload bar below it
-------------------------------------------------------------------
local scroll = CreateFrame("ScrollFrame", "DeckUIForeverPanelScroll", panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", SIDE_W + 16, -42)
scroll:SetPoint("BOTTOMRIGHT", -30, 40)
local PAGE_W = W - SIDE_W - 16 - 30

-- Old pages place their widgets at fixed points and say nothing about
-- their height, so it is measured: the lowest widget's bottom edge.
local function Measure(content)
    local top = content:GetTop()
    if not top then return end
    local low = top - 20
    local function Visit(...)
        for i = 1, select("#", ...) do
            local r = select(i, ...)
            if r:IsShown() then
                local bottom = r:GetBottom()
                if bottom and bottom < low then low = bottom end
            end
        end
    end
    Visit(content:GetChildren())
    Visit(content:GetRegions())
    content:SetHeight(math.max(10, top - low + 16))
end

-------------------------------------------------------------------
-- The footer: "Move" and "Defaults" for the page, the reload notice
-------------------------------------------------------------------
-- Added 2026-10-02 with the last points of the menu review: a page's own
-- frames can be unlocked alone (D.SetUnlocked with a set of keys), and a
-- page can put its settings back to the defaults.

-- the frames each page moves, by the key D.MakeMovable got
D.PAGE_FRAMES = {
    Orbs    = { "EXP bar", "Cast bar" },
    FramePlayer = { "Player", "Player (FF)" },
    FrameTarget = { "Target", "Target (FF)" },
    Debuffs = { "Debuffs" },
    HoTs    = { "HoTs" },
    DeckHeal = { "Deck Heal" },
    BuffBar = { "Buffs" },
    Enemies = { "Focus", "Focus (FF)", "Boss frames", "Boss frames (FF)", "Enemy list" },
    Group   = { "Party" },
    Raid    = { "Raid" },
    Cross   = { "Cross Hotbar", "Leave vehicle" },
    Bars    = { "Bar 1", "Bar 2", "Bar 3", "Bar 4", "Bar 5", "Bar 6", "Bar 7", "Bar 8", "Stance bar", "Pet bar", "Leave vehicle" },
    Spec    = { "Spec bar" },
    Bags    = { "Bags", "Bank" },
    Quests  = { "Quest tracker" },
    Questing = { "Quest item", "Compendium" },
    Map     = { "Minimap", "World map" },
    Tooltip = { "Tooltip" },
    Nav     = { "Compass", "Navigation target", "Waypoint list" },
    Week    = { "Week" },
    Loot    = { "Loot", "Loot list", "Loot rolls" },
    Screen  = { "Server info", "Gold", "Bag overview", "Main menu", "Dock" },
    Windows = { "Group listing" },
}

-- What "Defaults" clears on each page: the SavedVariables table by name,
-- `match` for the keys that belong to this page when several pages share
-- one table (Orbs, Group and Raid; the hub's Loot settings), and `keep` for
-- what is data, not settings. Positions are never touched - "Reset all
-- positions" on the Devices page does that. The game reloads right after,
-- and each module fills what is missing with its defaults as it loads.
local LOOT_KEYS = { autoSellJunk = true, autoRepair = true, repairGuild = true, fastLoot = true, lootWindow = true, lootRolls = true,
                    restock = true, mailHelper = true }
local function GroupKey(k) return k == "showParty" or k:find("^party") ~= nil end
local function RaidKey(k) return k == "showRaid" or k:find("^raid") ~= nil end
local function DotKey(k) return k:find("^dot") ~= nil end
local function HotKey(k) return k:find("^hot") ~= nil end
local function PadHealKey(k) return k:find("^padHeal") ~= nil end
local function PlayerKey(k) return k:find("^player") ~= nil end
local function TargetKey(k) return k:find("^target") ~= nil end
local function ToTKey(k) return k:find("^tot") ~= nil end
-- the buff bar's keys: buffBar* plus the sizes and counts (buffMaxDuration stays the Orbs page's)
local BUFFBAR_KEYS = { buffSize = true, buffPerRow = true, buffRows = true, buffDebuffMax = true }
local ENEMY_KEYS = { enemyList = true, showFocus = true, showBoss = true, bossStyle = true }
local function BuffBarKey(k) return BUFFBAR_KEYS[k] == true or k:find("^buffBar") ~= nil end
local function EnemyKey(k) return ENEMY_KEYS[k] == true end
-- the Overview's three sub-pages share DeckUIForeverDB with everything else of the hub
local SCREEN_KEYS = { infoServer = true, infoParts = true, infoGold = true, infoBags = true, hideBagBar = true, mainMenu = true, dock = true }
local TARGET_KEYS = { targetArrow = true, xivPlates = true, xivPlatesFriendly = true, xivPlatesNameOnly = true, plateSpace = true, rankMarks = true,
                      softTargetName = true, softTargetCast = true }
local WINDOW_KEYS = { styleDamageMeter = true, charPanel = true, listingWindow = true }
D.PAGE_RESET = {
    Orbs    = { db = "DeckUIForeverOrbsDB", match = function(k)
        return not (GroupKey(k) or RaidKey(k) or HotKey(k) or DotKey(k) or PlayerKey(k) or TargetKey(k) or ToTKey(k)
                    or BuffBarKey(k) or EnemyKey(k) or PadHealKey(k))
    end },
    BuffBar = { db = "DeckUIForeverOrbsDB", match = BuffBarKey },
    Enemies = { db = "DeckUIForeverOrbsDB", match = EnemyKey },
    Screen  = { db = "DeckUIForeverDB", match = function(k) return SCREEN_KEYS[k] end },
    Targets = { db = "DeckUIForeverDB", match = function(k) return TARGET_KEYS[k] end },
    Windows = { db = "DeckUIForeverDB", match = function(k) return WINDOW_KEYS[k] end },
    FramePlayer = { db = "DeckUIForeverOrbsDB", match = PlayerKey },
    FrameTarget = { db = "DeckUIForeverOrbsDB", match = TargetKey },
    FrameToT    = { db = "DeckUIForeverOrbsDB", match = ToTKey },
    Debuffs = { db = "DeckUIForeverOrbsDB", match = DotKey },
    HoTs    = { db = "DeckUIForeverOrbsDB", match = HotKey },
    DeckHeal = { db = "DeckUIForeverOrbsDB", match = PadHealKey },
    Group   = { db = "DeckUIForeverOrbsDB", match = GroupKey },
    Raid    = { db = "DeckUIForeverOrbsDB", match = RaidKey },
    Cross   = { db = "DeckUIForeverCrossDB" },   -- phase 4: the module does not exist yet, its page is a stand-in
    Bars    = { db = "DeckUIForeverBarsDB" },
    Spec    = { db = "DeckUIForeverSpecDB", keep = { groupSets = true } },
    Bags    = { db = "DeckUIForeverBagsDB", keep = { trackedItems = true } },
    Quests  = { db = "DeckUIForeverQuestsDB" },
    Questing = { db = "DeckUIForeverQuestingDB", keep = { ignoredNPCs = true } },
    Map     = { db = "DeckUIForeverMapDB" },
    Tooltip = { db = "DeckUIForeverTooltipDB" },
    Nav     = { db = "DeckUIForeverNavDB" },
    Week    = { db = "DeckUIForeverWeekDB", keep = { chars = true, weeklies = true, dailies = true, hidden = true, recorded = true } },
    Loot    = { db = "DeckUIForeverDB", match = function(k) return LOOT_KEYS[k] end },
}

local function ResetPage(key)
    local rule = D.PAGE_RESET[key]
    local db = rule and _G[rule.db]
    if not db then return end
    local function Clears(k)
        if k == "perDevice" or (rule.keep and rule.keep[k]) then return false end
        return not rule.match or rule.match(k)
    end
    for k in pairs(db) do
        if type(k) == "string" and Clears(k) then db[k] = nil end
    end
    for _, dev in pairs(db.perDevice or {}) do
        for k in pairs(dev) do
            if type(k) == "string" and k ~= "positions" and Clears(k) then dev[k] = nil end
        end
    end
end

local footer = CreateFrame("Frame", nil, panel)
footer:SetPoint("BOTTOMLEFT", SIDE_W + 16, 8)
footer:SetPoint("BOTTOMRIGHT", -8, 8)
footer:SetHeight(26)

local function FooterButton(text, x, width)
    local b = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    b:SetSize(width or 76, 22)
    b:SetPoint("LEFT", x, 0)
    b:SetText(text)
    b:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
    D.FlattenButton(b)
    return b
end

-- this page's frames as a set, or nil when none of them exists
local function PageFrames(key)
    local keys = D.PAGE_FRAMES[key]
    if not keys then return nil end
    local set, any = {}, false
    for _, k in ipairs(keys) do set[k] = true end
    for _, entry in ipairs(D.movables) do
        if set[entry.key] then any = true end
    end
    return any and set or nil
end

local moveBtn = FooterButton("Move", 0, 60)
local defaultsBtn = FooterButton("Defaults", 64, 70)
-- the fine-tuning of every page, shown or folded away (widgets.lua, Flow:More)
local allBtn = FooterButton("All options", 138, 96)

-- does the page on show have fine-tuning at all?
local function HasMore(content)
    for _, f in ipairs(content and content.flows or {}) do
        for _, it in ipairs(f.items) do
            if it.more and it.texts then return true end
        end
    end
    return false
end

function D.UpdateFooter()
    local key = panel.current
    local frames = key and PageFrames(key)
    local stub = key and panel.contents[key] and panel.contents[key].def.stub
    moveBtn:SetShown(frames ~= nil and not stub)
    moveBtn:SetText(D.unlocked and "Lock" or "Move")
    defaultsBtn:SetShown(key and D.PAGE_RESET[key] ~= nil and not stub and _G[D.PAGE_RESET[key].db] ~= nil)
    allBtn:SetShown(not panel.searching and key and HasMore(panel.contents[key]) or false)
    allBtn:SetText(DeckUIForeverDB.showAllOptions and "Fewer options" or "All options")
    if panel.searching then
        moveBtn:Hide()
        defaultsBtn:Hide()
    end
end

function D.SetShowAll(on)
    DeckUIForeverDB.showAllOptions = on and true or false
    local content = panel.current and panel.contents[panel.current]
    if content and content:IsShown() then
        content.reveal = nil
        D.ApplyOptionMode(content)
        D.RefreshWidgets(content)
        C_Timer.After(0, function() Measure(content) end)
    end
    D.UpdateFooter()
end

allBtn:SetScript("OnClick", function() D.SetShowAll(not DeckUIForeverDB.showAllOptions) end)
D.Tip(allBtn, "All options", "Every page shows its important options first. This shows the fine-tuning as well - sizes, looks, special cases - on all pages, or folds it away again.")

moveBtn:SetScript("OnClick", function()
    if D.unlocked then
        D.SetUnlocked(false)
    else
        D.SetUnlocked(true, PageFrames(panel.current))
    end
    D.UpdateFooter()
end)
D.Tip(moveBtn, "Move", "Unlocks only this page's frames, to drag them to a new place. Click again to lock. All frames at once: the Devices page or /df unlock.")

defaultsBtn:SetScript("OnClick", function()
    local key = panel.current
    D.Dialog({
        text = ("Put the settings of \"%s\" back to their defaults? Places on screen stay. The game reloads to apply it."):format(PageName(key)),
        accept = "Defaults",
        onAccept = function()
            ResetPage(key)
            C_UI.Reload()
        end,
    })
end)
D.Tip(defaultsBtn, "Defaults", "Puts this page's settings back as they were at installation, then reloads. Places on screen stay.")

-- changes that wait for a /reload, by key, with a button that does it
local reloadBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
reloadBtn:SetSize(84, 22)
reloadBtn:SetPoint("RIGHT")
reloadBtn:SetText("Reload")
reloadBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
reloadBtn:SetScript("OnClick", function() C_UI.Reload() end)
D.FlattenButton(reloadBtn)
reloadBtn:Hide()
local reloadText = footer:CreateFontString(nil, "OVERLAY")
reloadText:SetFont(D.FONT, 12, "OUTLINE")
reloadText:SetPoint("RIGHT", reloadBtn, "LEFT", -6, 0)
reloadText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

local pendingReload = {}

-- key: anything that names the change, so switching back and forth
-- counts once; pass false as `on` when the change was undone
function D.NeedReload(key, on)
    pendingReload[key] = (on ~= false) or nil
    local n = 0
    for _ in pairs(pendingReload) do n = n + 1 end
    -- short: the footer holds three buttons on the left since the "All options" switch
    reloadText:SetText("Needs a reload:")
    reloadBtn:SetText(("Reload (%d)"):format(n))
    reloadText:SetShown(n > 0)
    reloadBtn:SetShown(n > 0)
end

-------------------------------------------------------------------
-- Pages
-------------------------------------------------------------------
-- A module's real page replaces its stand-in (a page with def.stub, see
-- "Modules" below) when the module loads.
function panel:AddTab(key, def)
    if self.tabs[key] then
        local old = self.contents[key]
        if not (old and old.def.stub) then return end
        old:Hide()
    else
        self.tabs[key] = NewEntry(key)
        table.insert(self.tabOrder, key)
    end

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PAGE_W, 10)
    content:Hide()
    content.def = def
    content:SetScript("OnShow", function(c)
        if not c.built then
            c.built = true
            if c.def.build then c.def.build(c) end
        end
        D.RefreshWidgets(c)
        D.ApplyOptionMode(c)   -- the important options, or all of them (widgets.lua)
        -- the widgets have their places only after this frame is drawn
        C_Timer.After(0, function() Measure(c) end)
    end)
    self.contents[key] = content

    LayoutSidebar()
    -- A module switched on from its own page registers that page while it
    -- loads, before its SavedVariables exist (they come with ADDON_LOADED,
    -- after its files ran) - building the page now read a nil table
    -- (2026-10-26). A frame later the module has set them up.
    if self.current == key and self:IsShown() then
        C_Timer.After(0, function()
            if self.current == key and self:IsShown() then self:ShowTab(key) end
        end)
    end
end

function panel:ShowTab(key)
    if not self.contents[key] then key = "General" end
    if self.EndSearch then self.EndSearch() end
    for k, content in pairs(self.contents) do
        local on = k == key
        -- a search result opens its page with everything on show; that
        -- ends when the page is left
        if not on or self.revealFor ~= key then content.reveal = nil end
        if on then scroll:SetScrollChild(content) end
        content:SetShown(on)
        local b = self.tabs[k]
        b.bar:SetShown(on)
        b.fill:SetShown(on)
        -- gold: the page on show; grey: a module that is off
        local grey = content.def.stub and 0.5 or 1
        b.text:SetTextColor(on and GOLD[1] or grey, on and GOLD[2] or grey, on and GOLD[3] or grey)
    end
    scroll:SetVerticalScroll(0)
    pageTitle:SetText(PageName(key))
    self.current = key
    self.revealFor = nil
    LayoutSidebar()   -- this page's sub-pages unfold, the others' fold
    if D.UpdateModuleSwitch then D.UpdateModuleSwitch() end
    D.UpdateFooter()
end

-------------------------------------------------------------------
-- Search: any option of any page by a word
-------------------------------------------------------------------
-- Owner 2026-11-12 (the third menu review: some 240 options on 30 pages,
-- "da verliert man den Überblick"). A field above the sidebar; while it
-- holds text the page area lists every option whose name, explanation,
-- page or section holds all the words typed. A click opens the page,
-- scrolls to the option and marks it for a moment - with the fine-tuning
-- on show for that visit if the option is part of it.
--
-- The index is read from what the Flows recorded (widgets.lua): pages
-- build on their first show, so the first search builds the ones not
-- seen yet. A module that is off has no page - its stand-in is found by
-- the module's name and description.
local searchBox = CreateFrame("EditBox", "DeckUIForeverPanelSearch", panel)
searchBox:SetPoint("TOPLEFT", 8, -40)
searchBox:SetSize(SIDE_W, 24)
D.FlatBox(searchBox, 0.6, 0.2)
searchBox:SetAutoFocus(false)
searchBox:SetFont(D.FONT, 12, "OUTLINE")
searchBox:SetTextInsets(8, 24, 0, 0)
searchBox:SetMaxLetters(40)
local searchHint = searchBox:CreateFontString(nil, "OVERLAY")
searchHint:SetFont(D.FONT, 12, "OUTLINE")
searchHint:SetPoint("LEFT", 8, 0)
searchHint:SetTextColor(0.5, 0.5, 0.5)
searchHint:SetText("Search options ...")
local searchClear = CreateFrame("Button", nil, searchBox)
searchClear:SetSize(20, 20)
searchClear:SetPoint("RIGHT", -2, 0)
searchClear.text = searchClear:CreateFontString(nil, "OVERLAY")
searchClear.text:SetFont(D.FONT, 12, "OUTLINE")
searchClear.text:SetPoint("CENTER")
searchClear.text:SetTextColor(0.7, 0.7, 0.7)
searchClear.text:SetText("x")
searchClear:Hide()

local results = CreateFrame("Frame", nil, scroll)
results:SetSize(PAGE_W, 10)
results:Hide()
local resultRows = {}
local resultNote = results:CreateFontString(nil, "OVERLAY")
resultNote:SetFont(D.FONT, 12, "OUTLINE")
resultNote:SetPoint("TOP", 0, -8)
resultNote:SetWidth(PAGE_W - 40)
resultNote:SetTextColor(0.7, 0.7, 0.7)
local MAX_RESULTS = 40

-- the gold mark on the option a result led to
local flash = CreateFrame("Frame", nil, panel)
flash:Hide()
local flashTex = flash:CreateTexture(nil, "BACKGROUND")
flashTex:SetAllPoints()
flashTex:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)
local flashAnim = flash:CreateAnimationGroup()
local fade = flashAnim:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0)
fade:SetStartDelay(0.8)
fade:SetDuration(1.2)
flashAnim:SetScript("OnFinished", function() flash:Hide() end)

local function Jump(content, item)
    if not (content:IsShown() and item.at) then return end
    local max = math.max(0, content:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.min(max, math.max(0, -item.at - 30)))
    flashAnim:Stop()
    flash:SetParent(content)
    flash:ClearAllPoints()
    flash:SetPoint("TOPLEFT", content, "TOPLEFT", 4, item.at + 2)
    flash:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, item.at + 2)
    flash:SetHeight(math.max(20, item.h))
    flash:SetFrameLevel(content:GetFrameLevel())
    flash:SetAlpha(1)
    flash:Show()
    flashAnim:Play()
end

-- where a page lives, as the sidebar shows it: "Unit frames > Your HoTs"
local function PagePath(key)
    local parent = D.PAGE_PARENT[key]
    return parent and (PageName(parent) .. " > " .. PageName(key)) or PageName(key)
end

local function Index()
    local list = {}
    for _, key in ipairs(panel.tabOrder) do
        local c = panel.contents[key]
        if c.def.stub then
            list[#list + 1] = { page = key, text = PageName(key), tip = D.MODULE_DESCRIPTIONS[key],
                                where = "Module, switched off" }
        else
            if not c.built then
                c.built = true
                if c.def.build then xpcall(c.def.build, geterrorhandler(), c) end
            end
            list[#list + 1] = { page = key, text = PageName(key), where = "Page",
                                tip = D.MODULE_DESCRIPTIONS[key] }
            for _, f in ipairs(c.flows or {}) do
                for _, it in ipairs(f.items) do
                    for _, t in ipairs(it.texts or {}) do
                        if type(t[1]) == "string" then
                            list[#list + 1] = { page = key, text = t[1], tip = t[2], item = it,
                                                where = PagePath(key) .. (it.section and (" > " .. it.section) or "") }
                        end
                    end
                end
            end
        end
    end
    return list
end

local function Matches(query)
    local words = {}
    for w in query:lower():gmatch("%S+") do words[#words + 1] = w end
    local found = {}
    for order, e in ipairs(Index()) do
        local name = e.text:lower()
        local all = name .. " " .. (e.tip or ""):lower() .. " " .. e.where:lower()
        local inAll, inName = true, true
        for _, w in ipairs(words) do
            if not all:find(w, 1, true) then inAll = false break end
            if not name:find(w, 1, true) then inName = false end
        end
        if inAll then
            e.rank = (inName and 0 or 1) * 10000 + order   -- the name first, then the explanation
            found[#found + 1] = e
        end
    end
    table.sort(found, function(a, b) return a.rank < b.rank end)
    return found
end

local function ResultRow(i)
    local b = resultRows[i]
    if b then return b end
    b = CreateFrame("Button", nil, results)
    b:SetSize(PAGE_W - 12, 36)
    b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 38)
    D.FlatBox(b, 0.5, 0.2)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
    b.title = b:CreateFontString(nil, "OVERLAY")
    b.title:SetFont(D.FONT, 13, "OUTLINE")
    b.title:SetPoint("TOPLEFT", 8, -4)
    b.title:SetPoint("RIGHT", -8, 0)
    b.title:SetJustifyH("LEFT")
    b.title:SetWordWrap(false)
    b.where = b:CreateFontString(nil, "OVERLAY")
    b.where:SetFont(D.FONT, 11, "OUTLINE")
    b.where:SetPoint("TOPLEFT", 8, -20)
    b.where:SetPoint("RIGHT", -8, 0)
    b.where:SetJustifyH("LEFT")
    b.where:SetWordWrap(false)
    b.where:SetTextColor(0.6, 0.6, 0.6)
    b:SetScript("OnClick", function(self)
        local e = self.entry
        local content = panel.contents[e.page]
        if e.item and e.item.more and not DeckUIForeverDB.showAllOptions then
            content.reveal = true
            panel.revealFor = e.page
        end
        panel:ShowTab(e.page)
        if e.item then
            C_Timer.After(0.05, function() Jump(content, e.item) end)
        end
    end)
    b:SetScript("OnEnter", function(self)
        local e = self.entry
        if not (e and e.tip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(e.text, 1, 0.82, 0)
        GameTooltip:AddLine(e.tip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    resultRows[i] = b
    return b
end

local function ShowSearch(query)
    panel.searching = true
    for _, content in pairs(panel.contents) do content:Hide() end
    scroll:SetScrollChild(results)
    results:Show()
    scroll:SetVerticalScroll(0)
    pageTitle:SetText("Search")
    local found = Matches(query)
    local n = math.min(#found, MAX_RESULTS)
    for i = 1, n do
        local b = ResultRow(i)
        b.entry = found[i]
        b.title:SetText(found[i].text)
        b.where:SetText(found[i].where)
        b:Show()
    end
    for i = n + 1, #resultRows do resultRows[i]:Hide() end
    resultNote:ClearAllPoints()
    resultNote:SetPoint("TOP", 0, -10 - n * 38)
    if #found == 0 then
        resultNote:SetText(("Nothing found for \"%s\". Try a shorter word - the names are English, such as \"buff\", \"size\" or \"raid\"."):format(query))
    elseif #found > MAX_RESULTS then
        resultNote:SetText(("%d more - add a word to narrow it down."):format(#found - MAX_RESULTS))
    else
        resultNote:SetText("Click a line to go there.")
    end
    results:SetHeight(n * 38 + 60)
    if D.UpdateModuleSwitch then D.UpdateModuleSwitch() end
    D.UpdateFooter()
end

-- back to the pages; ShowTab calls this before it shows one
function panel.EndSearch()
    if not panel.searching then return end
    panel.searching = false
    results:Hide()
    searchBox:SetText("")
    searchBox:ClearFocus()
end

searchBox:SetScript("OnTextChanged", function(self)
    local text = strtrim(self:GetText() or "")
    searchHint:SetShown(text == "")
    searchClear:SetShown(text ~= "")
    if text ~= "" then
        ShowSearch(text)
    elseif panel.searching then
        panel.searching = false
        results:Hide()
        panel:ShowTab(panel.current)
    end
end)
searchBox:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
end)
searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
searchClear:SetScript("OnClick", function()
    searchBox:SetText("")
    searchBox:ClearFocus()
end)
panel:HookScript("OnHide", function() panel.EndSearch() end)

panel:SetScript("OnShow", function(self)
    self:ShowTab(self.current or "General")
end)
D.GamepadWindow(panel, { close = close })

function D.ToggleConfig(tabKey)
    if tabKey and panel.contents[tabKey] then panel.current = tabKey end
    if panel:IsShown() and not tabKey then
        panel:Hide()
    else
        panel:Show()
        if tabKey then panel:ShowTab(tabKey) end
    end
end

-------------------------------------------------------------------
-- Modules: a switch on their own page, a stand-in page while off
-------------------------------------------------------------------
-- Owner's choice (2026-10-02): a module is switched on and off at the top
-- of its own page, not in a list on another one. A module that is off has
-- not loaded, so it has no page of its own yet - a stand-in takes its
-- place in the sidebar (greyed) and says what the module does. Switched
-- on, the module loads and registers its page, which replaces the stand-in.
D.MODULE_DESCRIPTIONS = {
    Orbs    = "Unit frames for you, your target, focus, pet and bosses - round orbs or Final Fantasy's bars - plus the party list and raid frames.",
    Cross   = "The cross hotbar: Action Bar 1 and 2 as two crosses per side, for the Steam Deck's triggers and buttons.",
    Bars    = "The eight action bars in Final Fantasy XIV's hotbar look, for keyboard and mouse.",
    Pad     = "Blizzard's controller action bar on the Steam Deck in the same hotbar look. The look only; the controls stay Blizzard's.",
    Spec    = "A small bar of your talent groups; click one to switch.",
    Bags    = "One window for all bags and the keyring, sorted into categories, and the bank in the same look.",
    Quests  = "Its own quest tracker in place of Blizzard's: quests, timers, scenarios, legacy challenges.",
    Questing = "Quests made easier: the NPC dialog on autopilot, a mark on the reward worth taking, a key for the quest item, and a compendium of every quest by zone, class and chain.",
    Map     = "A square or round minimap and a smaller, cleaner world map.",
    Tooltip = "The mouse-over tooltip in DeckUIForever's look, with a few extra lines.",
    Nav     = "A compass bar, the navigation target with distance and arrival time, and /way waypoints.",
    Week    = "The week at a glance for all your characters: lockouts, renown, dailies, reputation, weekly quests.",
}

local function ModuleLoaded(key)
    return C_AddOns.IsAddOnLoaded(D.MODULE_ADDONS[key])
end

-- what the switch and the overview say about a module
local function ModuleState(key)
    local on, loaded = DeckUIForeverDB.modules[key], ModuleLoaded(key)
    if not D.ModuleExists(key) then return "Not ported yet", false end
    if on and loaded then return "On", true end
    if not on and loaded then return "Off after reload", true end
    if on then
        local allowed = D.ModuleAllowed(key)
        return allowed and "On after reload" or "Not on this device", false
    end
    return "Off", false
end
D.ModuleState = ModuleState

local switch = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
switch:SetSize(150, 22)
switch:SetPoint("TOPRIGHT", -34, -10)
switch:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
D.FlattenButton(switch)
switch:Hide()

function D.UpdateModuleSwitch()
    local key = panel.current
    if panel.searching or not (key and D.MODULE_ADDONS[key]) then
        switch:Hide()
        return
    end
    local state, live = ModuleState(key)
    local color = DeckUIForeverDB.modules[key] and "|cff33ff33" or "|cff888888"
    switch:SetText("Module: " .. color .. state .. "|r")
    switch:Show()
end

switch:SetScript("OnClick", function()
    local key = panel.current
    local on = not DeckUIForeverDB.modules[key]
    D.SetModuleEnabled(key, on)
    -- a module once loaded stays until the reload
    D.NeedReload("module:" .. key, not on and ModuleLoaded(key))
    panel:ShowTab(key)
end)

local function StubPage(key)
    return {
        title = key, stub = true,
        build = function(c)
            local f = D.Flow(c)
            f:Hint(D.MODULE_DESCRIPTIONS[key] or "")
            if key == "Cross" then
                f:Gap(6)
                f:Checkbox("Cross hotbar only on Steam Deck", function() return DeckUIForeverDB end, "crossDeckOnly",
                    function(v) D.SetCrossDeckOnly(v) end)
            end
            f:Gap(6)
            c.stateText = f:Hint("")   -- last: its text changes length
            c.widgets = c.widgets or {}
            table.insert(c.widgets, { Refresh = function()
                local state = ModuleState(key)
                c.stateText:SetText(state == "Not ported yet"
                    and "This module of DeckUI has not been carried over to Forever yet."
                    or state == "Not on this device"
                    and "Switched on, but set to the Steam Deck only."
                    or "Switch it on with the button at the top right. It loads at once.")
            end })
        end,
    }
end

-------------------------------------------------------------------
-- "Start": a guided first page - presets, the modules with their switches, help
-------------------------------------------------------------------
D.PAGE_NAMES.General = "Start"

-- one line per module for the Start page; MODULE_DESCRIPTIONS has the long one
D.MODULE_SHORT = {
    Orbs     = "Health and resources of you, your target, party and raid - as orbs or Final Fantasy bars.",
    Cross    = "Two crosses of action buttons for a controller's triggers.",
    Bars     = "The action bars in the Final Fantasy XIV look, for keyboard and mouse.",
    Pad      = "Blizzard's controller bar on the Steam Deck in the same look.",
    Spec     = "A small bar to switch between your talent groups.",
    Bags     = "All bags in one sorted window, and the bank to match.",
    Quests   = "A cleaner quest tracker in place of Blizzard's.",
    Questing = "Quest help: dialogs on autopilot, the best reward marked, a quest compendium.",
    Map      = "A square or round minimap and a tidier world map.",
    Tooltip  = "The tooltip in the same look, with a few extra lines.",
    Nav      = "A compass, the distance to your goal and /way waypoints.",
    Week     = "Lockouts and weekly goals of all your characters.",
}

-- the modules by what they are for, in the order a new player meets them
local START_GROUPS = {
    { "Frames",           { "Orbs" } },
    { "Action bars",      { "Bars", "Pad", "Cross", "Spec" } },
    { "Quests and world", { "Quests", "Questing", "Map", "Nav" } },
    { "Bags and info",    { "Bags", "Tooltip", "Week" } },
}

local function ToggleModule(key)
    local on = not DeckUIForeverDB.modules[key]
    D.SetModuleEnabled(key, on)
    -- a module once loaded stays until the reload
    D.NeedReload("module:" .. key, not on and ModuleLoaded(key))
end

-- A module on the Start page: the switch, the name, one line on what it
-- does. A click on the row opens the module's page.
local function ModuleRow(c, y, key)
    local row = CreateFrame("Button", nil, c)
    row:SetSize(380, 44)
    row:SetPoint("TOP", 0, y)
    D.FlatBox(row, 0.5, 0.2)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
    local toggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    toggle:SetSize(50, 22)
    toggle:SetPoint("LEFT", 8, 0)
    toggle:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
    D.FlattenButton(toggle)
    local name = row:CreateFontString(nil, "OVERLAY")
    name:SetFont(D.FONT, 13, "OUTLINE")
    name:SetPoint("TOPLEFT", 68, -5)
    name:SetText(D.PAGE_NAMES[key] or key)
    local state = row:CreateFontString(nil, "OVERLAY")
    state:SetFont(D.FONT, 11, "OUTLINE")
    state:SetPoint("LEFT", name, "RIGHT", 8, 0)
    state:SetTextColor(1, 0.82, 0)
    local desc = row:CreateFontString(nil, "OVERLAY")
    desc:SetFont(D.FONT, 11, "OUTLINE")
    desc:SetPoint("TOPLEFT", 68, -21)
    desc:SetWidth(304)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetHeight(22)
    desc:SetTextColor(0.7, 0.7, 0.7)
    desc:SetText(D.MODULE_SHORT[key] or D.MODULE_DESCRIPTIONS[key] or "")
    row:SetScript("OnClick", function() panel:ShowTab(key) end)
    D.Tip(row, D.PAGE_NAMES[key] or key, D.MODULE_DESCRIPTIONS[key])
    toggle:SetScript("OnClick", function()
        ToggleModule(key)
        D.RefreshWidgets(c)
    end)
    D.Tip(toggle, D.PAGE_NAMES[key] or key, "Switches the module on or off. On, it loads at once; off, it goes with the next reload.")
    function row:Refresh()
        local text = ModuleState(key)
        local on = DeckUIForeverDB.modules[key]
        toggle:SetText(on and "|cff33ff33On|r" or "|cff888888Off|r")
        toggle:SetEnabled(D.ModuleExists(key))
        -- only what On and Off do not say already
        state:SetText((text == "On" or text == "Off") and "" or text)
        name:SetTextColor(on and 1 or 0.6, on and 1 or 0.6, on and 1 or 0.6)
    end
    return row
end

-- Presets (owner 2026-11-12: "ja, mit Rückfrage"): a way of playing in one
-- click. modules: what goes on and off, everything not named stays; orbs:
-- settings of the unit frames written as they are (the module fills the
-- rest with its defaults); deckOrbs: the same, on the Steam Deck only. The
-- dialog lists what would change; accepting applies it and reloads.
local PRESETS = {
    keyboard = {
        text = "Keyboard and mouse",
        tip = "Unit frames, the action bars in the Final Fantasy XIV look, bags, quest tracker, maps and tooltip. The controller bars go off.",
        modules = { Orbs = true, Bars = true, Bags = true, Quests = true, Map = true, Tooltip = true,
                    Cross = false, Pad = false },
    },
    deck = {
        text = "Steam Deck",
        tip = "Unit frames, Blizzard's controller bar in our look, bags, quest tracker, maps and tooltip. The keyboard's action bars and the cross hotbar go off.",
        modules = { Orbs = true, Pad = true, Bags = true, Quests = true, Map = true, Tooltip = true,
                    Bars = false, Cross = false },
    },
    healer = {
        text = "I am a healer",
        tip = "Adds the healer's tools to whatever you have: the HoT window with click to cast, health bars, debuffs you can remove, missing buffs and your heals as buttons. On the Steam Deck also Deck Heal.",
        modules = { Orbs = true },
        orbs = { hotTracker = true, hotHealer = true, hotHealth = true, hotStatus = true, hotRange = true,
                 hotDispel = true, hotBuffSlots = true, hotCastSlots = true },
        orbsText = "On the \"Your HoTs\" page: the HoT window with click to cast, health bars, dead and offline marks, range, debuffs you can remove, missing buffs and your heals as buttons.",
        deckOrbs = { padHeal = true },
        deckText = "On this Steam Deck also Deck Heal: hold L, pick a friend with the D-pad, heal with A, X, Y, B.",
    },
}

-- what a preset would change right now, as the dialog's text; nil when nothing
local function PresetChanges(p)
    local on, off = {}, {}
    for _, key in ipairs(D.MODULE_ORDER) do
        local want = p.modules[key]
        if want ~= nil and D.ModuleExists(key) and (DeckUIForeverDB.modules[key] and true or false) ~= want then
            table.insert(want and on or off, D.PAGE_NAMES[key] or key)
        end
    end
    local lines = {}
    if #on > 0 then lines[#lines + 1] = "Switches on: " .. table.concat(on, ", ") .. "." end
    if #off > 0 then lines[#lines + 1] = "Switches off: " .. table.concat(off, ", ") .. "." end
    local function Differs(keys)
        local odb = DeckUIForeverOrbsDB
        for k, v in pairs(keys or {}) do
            if not odb or odb[k] ~= v then return true end
        end
        return false
    end
    if Differs(p.orbs) then lines[#lines + 1] = p.orbsText end
    if D.IsDeck() and Differs(p.deckOrbs) then lines[#lines + 1] = p.deckText end
    if #lines == 0 then return nil end
    return table.concat(lines, "\n\n")
end

local function ApplyPreset(p)
    if InCombatLockdown() then
        print("DeckUIForever: not in combat - try again after the fight.")
        return
    end
    for _, key in ipairs(D.MODULE_ORDER) do
        local want = p.modules[key]
        if want ~= nil and D.ModuleExists(key) and (DeckUIForeverDB.modules[key] and true or false) ~= want then
            D.SetModuleEnabled(key, want)
        end
    end
    if p.orbs or p.deckOrbs then
        -- the module fills what is missing with its defaults as it loads
        DeckUIForeverOrbsDB = DeckUIForeverOrbsDB or {}
        for k, v in pairs(p.orbs or {}) do DeckUIForeverOrbsDB[k] = v end
        if D.IsDeck() then
            for k, v in pairs(p.deckOrbs or {}) do DeckUIForeverOrbsDB[k] = v end
        end
    end
    C_UI.Reload()
end

local function PresetButton(id)
    local p = PRESETS[id]
    return { text = p.text, title = p.text, tip = p.tip, onClick = function()
        local changes = PresetChanges(p)
        if not changes then
            D.Dialog({ width = 360, accept = OKAY or "OK",
                       text = ("\"%s\" is set up already - nothing to change."):format(p.text) })
            return
        end
        D.Dialog({
            width = 360, accept = "Apply and reload",
            text = ("%s\n\n%s\n\nEverything else stays as it is. The game reloads to apply it."):format(p.text, changes),
            onAccept = function() ApplyPreset(p) end,
        })
    end }
end

panel:AddTab("General", {
    title = "Start",
    build = function(c)
        local db = function() return DeckUIForeverDB end
        local f = D.Flow(c)
        c.widgets = c.widgets or {}

        f:Hint("DeckUIForever is a set of modules. Switch on what you want and leave the rest off. Three steps get you started.")

        f:Gap(4)
        f:Label("1. How do you play?")
        f:Pair(PresetButton("keyboard"), PresetButton("deck"))
        f:Pair(PresetButton("healer"))
        f:Hint("Each button shows what it would change and asks first. You can change every bit of it afterwards.")

        f:Gap(4)
        f:Label("2. Your modules")
        f:Hint("On or Off switches a module. Click its row to open its page. Only modules that are on are listed on the left.")
        local listed = {}
        local function Group(title, keys)
            local any = false
            for _, key in ipairs(keys) do
                if D.MODULE_ADDONS[key] and not listed[key] then
                    if not any then
                        any = true
                        f:Add(18, function(parent, y)
                            local fs = parent:CreateFontString(nil, "OVERLAY")
                            fs:SetFont(D.FONT, 11, "OUTLINE")
                            fs:SetPoint("TOPLEFT", 8, y - 2)
                            fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
                            fs:SetText(title:upper())
                            return fs
                        end)
                    end
                    listed[key] = true
                    table.insert(c.widgets, f:Add(48, function(parent, y) return ModuleRow(parent, y, key) end))
                end
            end
        end
        for _, group in ipairs(START_GROUPS) do Group(group[1], group[2]) end
        Group("More", D.MODULE_ORDER)   -- a module no group names

        f:Gap(8)
        f:Label("3. Make it yours")
        local moveAll, allOptions = f:Pair(
            { text = "Move frames", title = "Move frames",
              tip = "Unlocks every frame of DeckUIForever to drag it to a new place; click again to lock. A page's own frames: the Move button at the bottom of that page.",
              onClick = function(b)
                  D.SetUnlocked(not D.unlocked)
                  b:SetText(D.unlocked and "Lock frames" or "Move frames")
                  D.UpdateFooter()
              end },
            { text = "All options", title = "All options",
              tip = "Every page shows its important options first. This shows the fine-tuning as well - sizes, looks, special cases - or folds it away again.",
              onClick = function(b)
                  D.SetShowAll(not DeckUIForeverDB.showAllOptions)
                  b:SetText(DeckUIForeverDB.showAllOptions and "Fewer options" or "All options")
              end })
        function moveAll:Refresh() self:SetText(D.unlocked and "Lock frames" or "Move frames") end
        function allOptions:Refresh() self:SetText(DeckUIForeverDB.showAllOptions and "Fewer options" or "All options") end
        table.insert(c.widgets, moveAll)
        table.insert(c.widgets, allOptions)
        f:Hint("Looking for something? Type a word into the search field at the top left, for example \"buff\" or \"size\". Screen pieces, nameplates and Blizzard's windows have pages of their own under General.")

        f:Gap(8)
        f:Label("Help")
        f:Checkbox("Minimap button", db, "showMinimap", function(v) D.SetMinimapShown(v) end,
            "Left click opens these settings, Shift-click the week overview.")
        -- the error collector (errors.lua), with how many it holds
        local errBtn = f:Button("Lua errors", function() D.ShowErrors() end,
            "Every Lua error since login, from any addon, ready to copy. Also /df errors.")
        function errBtn:Refresh() self:SetText(("Lua errors (%d)"):format(D.ErrorCount())) end
        table.insert(c.widgets, errBtn)
    end,
})

-- The Overview's three sub-pages (the menu review, 2026-10-28). Each
-- option below lives in a file of its own - an option shows when its file
-- has loaded, so a file left out of the .toc takes its option with it.
local hubDB = function() return DeckUIForeverDB end

panel:AddTab("Screen", {
    title = "Screen",
    build = function(c)
        local db, f = hubDB, D.Flow(c)
        f:Hint("Final Fantasy XIV's pieces around the screen. Move each with Move below.")
        if D.ApplyInfoBars then
            f:Label("Server info")
            f:Checkbox("Server info", db, "infoServer", function() D.ApplyInfoBars() end,
                "A line at the top right: your realm, a letter when mail waits, your latency and the time. The two buttons below pick what it shows.")
            -- what the server line shows, each value on its own switch
            local onOff = { [true] = "on", [false] = "off" }
            local function Part(key)
                return { label = D.INFO_PART_NAMES[key], values = { true, false }, names = onOff,
                         get = function() return D.InfoParts()[key] end,
                         set = function(v) D.InfoParts()[key] = v; D.ApplyInfoBars() end }
            end
            f:More()
            for i = 1, #D.INFO_PARTS, 2 do
                f:Cycles(Part(D.INFO_PARTS[i]), Part(D.INFO_PARTS[i + 1]))
            end
            f:Label("Gold and bags")
            f:Checkbox("Gold", db, "infoGold", function() D.ApplyInfoBars() end,
                "The gold you carry, with a coin. Hover it for the exact amount.")
            f:Checkbox("Bag overview", db, "infoBags", function() D.ApplyInfoBars() end,
                "A block of dots per bag, bright for a used slot, and the number of free slots. Click it to open your bags.")
            f:More()
            f:Checkbox("Hide Blizzard's bag buttons", db, "hideBagBar", function() D.ApplyInfoBars() end,
                "The backpack and bag slots at the bottom right go away; the bag overview takes their place. Your bag key still opens the bags.")
        end
        if D.ApplyMainMenu then
            f:Label("Main menu")
            f:Checkbox("Main menu as round buttons", db, "mainMenu", function() D.ApplyMainMenu() end,
                "The game's menu buttons as a row of round buttons with a gold ring. Blizzard's own row goes away.")
        end
        if D.ApplyDock then
            f:Label("Dock")
            f:Checkbox("DeckUIForever's dock", db, "dock", function() D.ApplyDock() end,
                "A small panel with round buttons for the settings, the week overview and the quest compendium, as the modules are on. Drag it by any button, or move it with Move below.")
        end
        if D.CameraIsMax() ~= nil then
            f:Label("Camera")
            local function CameraText()
                return D.CameraIsMax() and "Camera: back to normal distance" or "Camera: maximum distance"
            end
            c.widgets = c.widgets or {}
            local camBtn = f:Button(CameraText(), function()
                D.SetCameraMax(not D.CameraIsMax())
                D.RefreshWidgets(c)
            end, "Lets the camera zoom out further than the game's own slider allows, and zooms out at once. Press again to go back to the game's default limit. The game remembers it; /df camera prints the value.")
            function camBtn:Refresh() self:SetText(CameraText()) end
            table.insert(c.widgets, camBtn)
        end
    end,
})

panel:AddTab("Targets", {
    title = "Targets",
    build = function(c)
        local db, f = hubDB, D.Flow(c)
        f:Hint("What marks enemies and your target in the world.")
        if D.ApplyPlates then
            f:Label("Nameplates")
            f:Checkbox("Enemy nameplates like Final Fantasy XIV", db, "xivPlates", function() D.ApplyPlates() end,
                "Over each enemy only its level, marker, name and a thin red health bar. Clicking a plate still targets.")
            f:Checkbox("Friendly nameplates too", db, "xivPlatesFriendly", function() D.ApplyPlates() end,
                "With the Final Fantasy XIV nameplates on: friends get the same look in green - party members, and the friend your next heal would go to. Off, friends keep Blizzard's nameplate.")
            f:More()
            f:Checkbox("In dungeons: friends as names only", db, "xivPlatesNameOnly", function() D.ApplyPlates() end,
                "In dungeons and raids the game lets no addon touch a friend's nameplate, so ours cannot be drawn there. On, Blizzard's plate shrinks to the name alone - no bar, frame or level. Outside, your own setting returns.")
            f:Checkbox("Keep the nameplates apart", db, "plateSpace", function() D.ApplyPlates() end,
                "The game stacks the plates instead of letting them overlap.")
        end
        if D.ApplyRankMarks then
            f:Basic()
            f:Checkbox("Elite, rare and boss marks", db, "rankMarks", function() D.ApplyRankMarks() end,
                "A diamond before the name: gold for an elite, silver with a star for a rare, red with a crown for a boss. On the nameplates, the enemy list and the target bar.")
        end
        if D.ApplyTargetArrow then
            f:Label("Your target")
            f:Checkbox("Arrow over your target", db, "targetArrow", function() D.ApplyTargetArrow() end,
                "An arrowhead bobbing over your target's nameplate: red for an enemy, green for a friend. Needs the target's nameplate.")
        end
        if D.SetSoftTargetName then
            f:Label("Interact target")
            f:Checkbox("Name of the interact target", db, "softTargetName", D.SetSoftTargetName,
                "The chest, ore or herb your interact key would use gets its name below the game's icon: gold in reach, grey out of it. Needs the interact key on in the game's controls.")
            f:More()
            f:Checkbox("Ring while casting on it", db, "softTargetCast", function() end,
                "A ring fills around the icon while you cast or gather.")
        end
    end,
})

panel:AddTab("Windows", {
    title = "Windows",
    build = function(c)
        local db, f = hubDB, D.Flow(c)
        f:Hint("Blizzard's windows, restyled or helped along.")
        if D.SetDamageMeterStyled then
            f:Checkbox("Damage meter in DeckUIForever's look", db, "styleDamageMeter", D.SetDamageMeterStyled,
                "Blizzard's damage meter with flat bars and our font.")
        end
        if D.ApplyCharPanel then
            f:Checkbox("Character panel: item level and enchants", db, "charPanel", function() D.ApplyCharPanel() end,
                "The item level on each slot of the character panel, a red E where an enchant is missing, and the average item level below.")
        end
        if D.ApplyListingWindow then
            f:Checkbox("Group listing as a window", db, "listingWindow", function() D.ApplyListingWindow() end,
                "While you are listed in the group finder: a small window with the activity, your waiting time, your roles and the group so far. Right click unlists.")
        end
    end,
})

-------------------------------------------------------------------
-- "Loot and merchant": what used to sit under "Other" in General
-------------------------------------------------------------------
D.PAGE_NAMES.Loot = "Loot and merchant"

-- only where loot.lua runs (see the Overview's options above); asked once
-- all of the hub's files have loaded, since loot.lua comes after this one
EventUtil.ContinueOnAddOnLoaded("DeckUIForever", function()
    if not D.ApplyLootWindow then return end
    panel:AddTab("Loot", {
        title = "Loot and merchant",
        build = function(c)
            local db = function() return DeckUIForeverDB end
            local nothing = function() end
            local f = D.Flow(c)

            f:Label("At the merchant")
            f:Checkbox("Sell junk", db, "autoSellJunk", nothing,
                "Grey items are sold when a merchant opens.")
            f:Checkbox("Repair", db, "autoRepair", nothing,
                "Everything is repaired when a merchant can repair.")
            f:More()
            f:Checkbox("Repair with guild funds first", db, "repairGuild", nothing,
                "Uses the guild bank where you may; your own gold covers the rest.")

            f:Gap(8)
            f:Label("Loot")
            -- it speeds up the game's auto loot, which may be off (the owner
            -- pressed "take all" every time in Mists, 2026-10-26): ticking it
            -- switches the game's option on too
            f:Checkbox("Fast auto loot", db, "fastLoot", function(v)
                if v and not GetCVarBool("autoLootDefault") then
                    SetCVar("autoLootDefault", "1")
                    print("DeckUIForever: the game's auto loot is on now (Options > Controls).")
                end
            end, "Takes everything at once, without the loot window. Turns the game's own auto loot on too; hold Shift to loot by hand.")
            f:Checkbox("DeckUIForever's loot window", db, "lootWindow", function() D.ApplyLootWindow() end,
                "Replaces Blizzard's loot window. With auto loot a short list shows what you took. Move it with Move below.")
            f:Checkbox("DeckUIForever's loot rolls", db, "lootRolls", function() D.ApplyLootRolls() end,
                "Group rolls as one list: each item with its time left and Need, Greed and Pass. Move it with Move below.")

            f:More()
            if D.ApplyRestock then
                f:Checkbox("Restock at merchants", db, "restock", function() D.ApplyRestock() end,
                    "A small list beside the merchant of things to keep stocked - arrows, reagents, water, food. Drop an item on it and set how many; every visit buys what is missing. Per character.")
            end
            if D.ApplyMail then
                f:Checkbox("Mail helper", db, "mailHelper", function() D.ApplyMail() end,
                    "At the mailbox a button lists your characters and the last ten people you mailed. After Open All, one chat line says what you got.")
            end

            if D.PrintAuction then
                f:Gap(8)
                f:MoreSection("Auction house")
                f:Checkbox("Scan button at the auction house", db, "ahScan", function() end,
                    "A Scan button below the auction house reads all prices, at most every 15 minutes. Tooltips and the bags then show them.")
                f:Checkbox("Auction house window in DeckUIForever's look", db, "ahStyle", function(v)
                    D.NeedReload("ahStyle", true)
                end, "Blizzard's auction house in our dark look. Needs a reload.")
            end
        end,
    })
end)

-------------------------------------------------------------------
-- "Devices": everything that differs between the Deck and the PC
-------------------------------------------------------------------
-- Moved to D.Flow 2026-10-02. "Cross hotbar only on Steam Deck" went to
-- the Cross page (and its stand-in) - D.SetCrossDeckOnly below.
function D.SetCrossDeckOnly(v)
    if not v and DeckUIForeverDB.modules.Cross then
        D.SetModuleEnabled("Cross", true)
    else
        D.NeedReload("crossDeckOnly")
    end
end

panel:AddTab("Devices", {
    title = "Devices",
    build = function(c)
        local db = function() return DeckUIForeverDB end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)
        c.widgets = c.widgets or {}

        f:Label("This device")
        local devBtn = f:Button("Device", function(b)
            D.CycleDevice()
            b:SetText(D.DeviceText())
        end, "Auto: Steam Deck when the screen is 1280x800 or a gamepad is active, otherwise PC. Positions, sizes and every option marked (this device) follow it.")
        devBtn:SetWidth(300)
        devBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        function devBtn:Refresh() self:SetText(D.DeviceText()) end
        table.insert(c.widgets, devBtn)
        local function TestText()
            return D.DeckTestOn() and "End the Steam Deck test" or "Test the Steam Deck here"
        end
        f:More()
        local testBtn = f:Button(TestText(), function()
            local on = not D.DeckTestOn()
            D.Dialog({
                text = on and "Start the Steam Deck test? This device then counts as the Steam Deck and the game switches to its controller interface, so you see what the Deck shows. Deck Heal also listens to the keyboard: hold Tab, pick with the arrow keys, heal with 1 to 4. The game reloads."
                    or "End the Steam Deck test? Device and interface go back to what they were. The game reloads.",
                accept = on and "Start and reload" or "End and reload",
                onAccept = function() D.SetDeckTest(on) end,
            })
        end, "For trying the Steam Deck's side at the PC. A real controller plugged into the PC works as on the Deck. /df decktest says what is set.")
        testBtn:SetWidth(300)
        function testBtn:Refresh() self:SetText(TestText()) end
        table.insert(c.widgets, testBtn)

        f:Gap(4)
        f:MoreSection("UI scale")
        f:Checkbox("Set Blizzard's UI scale per device at login", db, "applyUiScale", function(v)
            if v then D.ApplyUiScale() end
        end, "One scale for the Deck's small screen, one for the PC. Off, the scale stays as it is.")
        f:Slider("On the Steam Deck", 0.5, 1.0, 0.01, pct, db, "uiScaleDeck",
            function() if D.IsDeck() then D.ApplyUiScale() end end)
        f:Slider("On the PC", 0.5, 1.0, 0.01, pct, db, "uiScalePC",
            function() if not D.IsDeck() then D.ApplyUiScale() end end)

        f:Gap(4)
        f:Label("Controller")
        f:Checkbox("D-pad in DeckUIForever's windows", db, "gamepadNav", function() D.SyncGamepadWindows() end,
            "On the Steam Deck the bags, the bank, the loot window, the week overview and this window join Blizzard's controller navigation: the D-pad moves, A clicks, B closes, LT and RT switch windows. Out of combat.")

        f:Gap(4)
        f:Label("Positions")
        local unlockBtn = f:Button("Unlock frames", function(b)
            D.SetUnlocked(not D.unlocked)
            b:SetText(D.unlocked and "Lock frames" or "Unlock frames")
        end, "Shows a handle on every frame; drag them where you want them. Each device keeps its own places. Also /df unlock.")
        function unlockBtn:Refresh()
            self:SetText(D.unlocked and "Lock frames" or "Unlock frames")
        end
        table.insert(c.widgets, unlockBtn)
        f:Button("Reset all positions", function()
            D.Dialog({
                text = "Put every DeckUIForever frame back to its default place on this device?",
                accept = "Reset",
                onAccept = D.ResetPositions,
            })
        end, "Only this device's places.")

        f:Gap(4)
        f:MoreSection("Keep on this device")
        local keepTip = "Blizzard keeps this on its server, so every device gets the same. Tick it on each device to keep that device's own."
        local function SyncText()
            return D.SyncIsOff() and "Sync UI and keys again" or "Stop syncing UI and keys"
        end
        local syncBtn = f:Button(SyncText(), function()
            D.SetServerSync(D.SyncIsOff() and true or false)
            D.RefreshWidgets(c)
        end, "Your interface settings, chat windows and key bindings no longer go to Blizzard's server, so this device keeps its own and your other devices keep theirs. Click again to sync them as before. Macros stay synced.")
        function syncBtn:Refresh() self:SetText(SyncText()) end
        table.insert(c.widgets, syncBtn)
        f:Checkbox("Key bindings", function() return D.bindingsCVar end, "localOnly", D.SetLocalBindings, keepTip)
        if D.SetKeepBars then
            f:Checkbox("Action bar layouts", db, "keepBars", D.SetKeepBars, keepTip)
        end
        if D.SetKeepLayouts then
            f:Checkbox("Edit Mode layout", db, "keepLayouts", D.SetKeepLayouts, keepTip)
        end
    end,
})

-- the stand-ins for every module not loaded yet; a module that loads
-- later (at login, or switched on) replaces its own
for _, key in ipairs(D.MODULE_ORDER) do
    if not panel.contents[key] then panel:AddTab(key, StubPage(key)) end
end

-------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------
-- the debug commands of files a game's .toc may leave out
local DEBUG_COMMANDS = {
    bars = "PrintBars", layout = "PrintLayout", ah = "PrintAuction", plates = "PlatesDebug",
    targetarrow = "TargetArrowDebug", softtarget = "PrintSoftTarget", rolls = "PrintLootRolls",
    gamepad = "PrintGamepad",
}

SLASH_DECKUIFOREVER1 = "/df"
SlashCmdList.DECKUIFOREVER = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "unlock" then
        D.SetUnlocked(true)
    elseif msg == "lock" then
        D.SetUnlocked(false)
    elseif msg == "reset" then
        D.ResetPositions()
    elseif msg == "device" then
        D.PrintDevice()
    elseif msg == "decktest on" then
        D.SetDeckTest(true)
    elseif msg == "decktest off" then
        D.SetDeckTest(false)
    elseif msg == "decktest" then
        D.PrintDeckTest()
    elseif msg == "sync" then
        D.PrintSync()
    elseif msg == "camera" then
        D.PrintCamera()
    elseif msg == "cvars" then
        if D.PrintCVars then D.PrintCVars() end
    elseif msg == "build" then
        D.PrintBuild()
    elseif DEBUG_COMMANDS[msg] then
        local fn = D[DEBUG_COMMANDS[msg]]
        if fn then fn() else print("DeckUIForever: /df " .. msg .. " is not part of DeckUIForever in this game.") end
        -- the Bars module adds its own lines to /df bars
        if msg == "bars" and D.PrintModuleBars then D.PrintModuleBars() end
    elseif msg == "questing" then
        if D.PrintQuesting then D.PrintQuesting() else print("DeckUIForever: switch on the Questing module (/df, Start page) for /df questing.") end
    elseif msg == "pad" then
        -- the Pad module's report on Blizzard's controller bar
        if D.PrintPad then D.PrintPad() else print("DeckUIForever: switch on the Pad module (/df, Start page) for /df pad.") end
    elseif msg == "errors" then
        D.ShowErrors()
    elseif msg == "deck" or msg == "pc" or msg == "auto" then
        D.SetDevice(msg)
    elseif msg == "" then
        D.ToggleConfig()
    elseif msg == "start" or msg == "modules" or msg == "general" then
        D.ToggleConfig("General")
    elseif msg == "all" then
        -- every page with its fine-tuning, or the important options only
        D.SetShowAll(not DeckUIForeverDB.showAllOptions)
        print("DeckUIForever: the settings show " .. (DeckUIForeverDB.showAllOptions and "all options." or "the important options."))
    else
        -- /df raid, /df bags, ...: open that page
        local page = D.FindPage(msg)
        if page then
            D.ToggleConfig(page)
        else
            print("DeckUIForever: no page \"" .. msg .. "\". Pages: " .. D.PageList())
            D.ToggleConfig()
        end
    end
end

-- a page by its key or its sidebar name, any case: "raid", "overview",
-- "loot", "player and target"
function D.FindPage(text)
    text = text:lower()
    for key in pairs(panel.contents) do
        if key:lower() == text or PageName(key):lower() == text then return key end
    end
    for key in pairs(panel.contents) do
        if PageName(key):lower():find(text, 1, true) then return key end
    end
end

function D.PageList()
    local keys = {}
    for _, key in ipairs(panel.tabOrder) do keys[#keys + 1] = key:lower() end
    return table.concat(keys, ", ")
end
