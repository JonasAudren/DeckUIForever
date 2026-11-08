local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The compendium: every quest, by zone, class and chain
-------------------------------------------------------------------
-- Three panes. Left the tree: zones by continent, dungeons, your class,
-- professions, battlegrounds, events, and the quest chains (epic, long).
-- Middle the quests of what you picked, grouped by their state for this
-- character - in your log, available, something missing, done, not
-- available, another class or race - each with its level and tag,
-- coloured like the quest log. Right the quest itself: where it starts
-- (with a waypoint button), where it ends, what it needs first, what it
-- leads to, its chain with your place in it, and its objectives.
--
-- A search box looks through every quest's name. Two filters, kept
-- between sessions: hide the done ones, hide the other classes' ones.
-- DeckUIForever's look (dark fill, thin edge, gold headings), dragged by
-- its frame, closed with Escape, and on the Steam Deck handed to
-- Blizzard's window navigation like the bag window.
-------------------------------------------------------------------
local Data = ns.Data

local W, H = 840, 540
local TOP = 72            -- the panes start below the title and the filter row
local PAD = 12
local TREE_W, LIST_W = 230, 280
local ROW = 20
local GOLD = { 1, 0.82, 0 }
local C = {
    GOLD = "|cffffd100", GREY = "|cff888888", GREEN = "|cff33ff33", ORANGE = "|cffff9933",
    RED = "|cffff5555", WHITE = "|cffffffff", DIM = "|cff666666", BLUE = "|cff88bbff",
}
local STATE_COLOR = { log = C.GOLD, available = C.WHITE, locked = C.ORANGE, done = C.GREY, blocked = C.DIM, foreign = C.DIM, unknown = C.GREY }
local SQUARE = "|TInterface\\Buttons\\WHITE8x8:9:9:0:0:8:8:0:8:0:8:%d:%d:%d|t"
local STATE_SQUARE = {
    log = SQUARE:format(255, 209, 0), available = SQUARE:format(230, 230, 230), locked = SQUARE:format(255, 153, 51),
    done = SQUARE:format(60, 160, 60), blocked = SQUARE:format(90, 90, 90), foreign = SQUARE:format(70, 70, 70), unknown = SQUARE:format(120, 120, 120),
}

local win = CreateFrame("Frame", "DeckCompendiumWindow", UIParent)
win:SetSize(W, H)
win:SetFrameStrata("HIGH")
win:SetToplevel(true)
win:EnableMouse(true)
win:SetClampedToScreen(true)
win.defaultPoint = { "CENTER", UIParent, "CENTER", 0, 20 }
win:SetPoint(unpack(win.defaultPoint))
win:Hide()
tinsert(UISpecialFrames, "DeckCompendiumWindow")
D.FlatBox(win, 0.95, 0.3)

local title = win:CreateFontString(nil, "OVERLAY")
title:SetFont(D.FONT, 15, "OUTLINE")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("Quest compendium")
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

local source = win:CreateFontString(nil, "OVERLAY")
source:SetFont(D.FONT, 11, "OUTLINE")
source:SetPoint("LEFT", title, "RIGHT", 12, 0)
source:SetPoint("RIGHT", win, "TOPRIGHT", -40, -12)
source:SetJustifyH("LEFT")
source:SetTextColor(0.6, 0.6, 0.6)

local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

-------------------------------------------------------------------
-- The filter row: search, hide done, only mine
-------------------------------------------------------------------
local search = CreateFrame("EditBox", "DeckCompendiumSearch", win, "InputBoxTemplate")
search:SetSize(200, 20)
search:SetPoint("TOPLEFT", 20, -40)
search:SetAutoFocus(false)
search:SetFont(D.FONT, 12, "")
search:SetMaxLetters(40)
local searchHint = search:CreateFontString(nil, "OVERLAY")
searchHint:SetFont(D.FONT, 11, "")
searchHint:SetPoint("LEFT", 2, 0)
searchHint:SetTextColor(0.5, 0.5, 0.5)
searchHint:SetText("Search a quest name")

local function SmallCheck(text, key, x, tip)
    local cb = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", x, -39)
    cb.label = cb:CreateFontString(nil, "OVERLAY")
    cb.label:SetFont(D.FONT, 12, "OUTLINE")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetText(text)
    cb:SetScript("OnClick", function(self)
        ns.db()[key] = self:GetChecked() and true or false
        if ns.RefreshCompendium then ns.RefreshCompendium() end
    end)
    cb.Refresh = function(self) self:SetChecked(ns.db()[key] and true or false) end
    D.Tip(cb, text, tip)
    return cb
end
local hideDone = SmallCheck("Hide done", "hideDone", 236, "Quests this character has already finished leave the list.")
local onlyMine = SmallCheck("Only my class and race", "onlyMine", 340,
    "Quests another class or race gets are left out. Questie's lists leave most of them out anyway.")

-------------------------------------------------------------------
-- The scan, and how much is known: top right of the filter row
-------------------------------------------------------------------
-- The button starts and stops scan.lua; the line before it counts what
-- our own data holds and where the scan stands, refreshed every second
-- while the window is open.
-- a footer of its own under the panes (the filter row was crowded, owner
-- 2026-11-07): the count at the left, the button at the right
local FOOT = 28
local scanButton = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
scanButton:SetSize(110, 20)
scanButton:SetPoint("BOTTOMRIGHT", -14, 8)
scanButton:GetFontString():SetFont(D.FONT, 11, "OUTLINE")
D.FlattenButton(scanButton)
D.Tip(scanButton, "Scan", "Asks the server for every quest's name, id by id, a few a second. Pauses in combat, carries on next session. Click again to stop.")

local scanText = win:CreateFontString(nil, "OVERLAY")
scanText:SetFont(D.FONT, 11, "OUTLINE")
scanText:SetPoint("BOTTOMLEFT", 20, 12)
scanText:SetPoint("RIGHT", scanButton, "LEFT", -12, 0)
scanText:SetJustifyH("LEFT")
scanText:SetTextColor(0.65, 0.65, 0.65)

local function UpdateScan()
    if not (ns.Scan and ns.Own) then return end
    local nextID, maxID, found, running, done = ns.Scan.Info()
    local quests, named, placed, linked = ns.Own.Stats()
    local known = ("%d quests known, %d with a giver, %d linked"):format(quests, placed, linked)
    if running then
        scanText:SetText(("%s  |cffffd100scanning id %d of %d|r"):format(known, nextID, maxID))
        scanButton:SetText("Stop scan")
    elseif done then
        scanText:SetText(("%s  |cff33ff33scan done|r"):format(known))
        scanButton:SetText("Scan done")
    elseif nextID > 1 then
        scanText:SetText(("%s  scan paused at id %d"):format(known, nextID))
        scanButton:SetText("Continue scan")
    else
        scanText:SetText(known)
        scanButton:SetText("Start scan")
    end
end
scanButton:SetScript("OnClick", function()
    if ns.Scan.Running() then
        ns.Scan.Stop()
    else
        local _, _, _, _, done = ns.Scan.Info()
        if done then ns.Scan.Reset() end
        ns.Scan.Start()
    end
    UpdateScan()
end)

-- the window's own OnShow/OnHide below start and stop the refresh (a
-- SetScript there would drop a hook placed here)
local scanTicker
local function StartScanRefresh()
    UpdateScan()
    if not scanTicker then scanTicker = C_Timer.NewTicker(1, UpdateScan) end
end
local function StopScanRefresh()
    if scanTicker then scanTicker:Cancel() scanTicker = nil end
end

-------------------------------------------------------------------
-- Panes: a scroll frame with a content frame each
-------------------------------------------------------------------
local function Pane(name, x, width)
    local box = CreateFrame("Frame", nil, win)
    box:SetPoint("TOPLEFT", x, -TOP)
    box:SetPoint("BOTTOMLEFT", x, PAD + 28)   -- the scan footer sits below
    box:SetWidth(width)
    D.FlatBox(box, 0.5, 0.2)
    local scroll = CreateFrame("ScrollFrame", name, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 2, -2)
    scroll:SetPoint("BOTTOMRIGHT", -22, 2)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width - 26, 10)
    scroll:SetScrollChild(content)
    box.scroll, box.content, box.width = scroll, content, width - 26
    return box
end

local treePane = Pane("DeckCompendiumTree", PAD, TREE_W)
local listPane = Pane("DeckCompendiumList", PAD + TREE_W + 6, LIST_W)
local detailPane = Pane("DeckCompendiumDetails", PAD + TREE_W + 6 + LIST_W + 6, W - (PAD + TREE_W + 6 + LIST_W + 6) - PAD)

-------------------------------------------------------------------
-- Pools: row buttons and plain lines
-------------------------------------------------------------------
local function Pool(parent, make)
    local p = { items = {}, used = 0, parent = parent, make = make }
    function p:Get()
        self.used = self.used + 1
        local item = self.items[self.used]
        if not item then
            item = self.make(self.parent)
            self.items[self.used] = item
        end
        item:Show()
        return item
    end
    function p:Release()
        for i = self.used + 1, #self.items do self.items[i]:Hide() end
        for i = 1, self.used do self.items[i]:Hide() end
        self.used = 0
    end
    return p
end

-- a row: a button with a left text and a right text, a faint fill under
-- the mouse, a gold fill when selected
local function MakeRow(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(ROW)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(D.FONT, 12, "OUTLINE")
    b.text:SetPoint("LEFT", 4, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.right = b:CreateFontString(nil, "OVERLAY")
    b.right:SetFont(D.FONT, 11, "OUTLINE")
    b.right:SetPoint("RIGHT", -4, 0)
    b.right:SetJustifyH("RIGHT")
    b.text:SetPoint("RIGHT", b.right, "LEFT", -4, 0)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetColorTexture(1, 0.82, 0, 0.12)
    b.sel:Hide()
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
    b:SetScript("OnEnter", function(self)
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tipTitle or "", 1, 0.82, 0)
            GameTooltip:AddLine(self.tip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local treeRows = Pool(treePane.content, MakeRow)
local listRows = Pool(listPane.content, MakeRow)
local detailRows = Pool(detailPane.content, MakeRow)

-- a small button in the details (waypoint, track)
local function MakeSmallButton(parent)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(90, 20)
    b:GetFontString():SetFont(D.FONT, 11, "OUTLINE")
    D.FlattenButton(b)
    return b
end
local detailButtons = Pool(detailPane.content, MakeSmallButton)

-------------------------------------------------------------------
-- State
-------------------------------------------------------------------
local nodes = {}          -- the tree, flattened for drawing
local expanded = {}       -- node key -> true
local selectedNode        -- the tree node on show
local selectedQuest       -- the quest in the details
local counts = {}         -- zone/chain key -> { done, total }
local dirty = false

local function Level(q)
    return q and q.level or 0
end

local function LevelColor(level)
    local c = GetQuestDifficultyColor(level or 1)
    return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

-- "[12+] Name" in the difficulty colour, the name in the state's colour
local function QuestText(id, state)
    local q = Data.Quest(id)
    local level = Level(q)
    local tag = level > 0 and ("%s[%d%s]|r "):format(LevelColor(level), level, Data.Suffix(id)) or ""
    return tag .. (STATE_COLOR[state] or C.WHITE) .. Data.Title(id) .. "|r"
end

-------------------------------------------------------------------
-- The tree
-------------------------------------------------------------------
local function Count(ids)
    local done, total = 0, 0
    for _, id in ipairs(ids) do
        total = total + 1
        if Data.Completed(id) then done = done + 1 end
    end
    return done, total
end

local function CountText(key, ids)
    local c = counts[key]
    if not c then
        local done, total = Count(ids)
        c = { done, total }
        counts[key] = c
    end
    local color = c[1] >= c[2] and C.GREEN or C.GREY
    return ("%s%d/%d|r"):format(color, c[1], c[2])
end

local function Add(list, node)
    list[#list + 1] = node
    return node
end

local function BuildTree()
    nodes = {}
    if not Data.Ready() then
        Add(nodes, { kind = "note", title = "Loading ...", depth = 0 })
        return
    end
    local cats = Data.Categories()
    if #cats == 0 then
        Add(nodes, { kind = "note", title = "Nothing known yet: play, scan, or import Questie's data (Questing page)", depth = 0 })
    end
    for _, cat in ipairs(cats) do
        local catKey = "cat:" .. cat.key
        Add(nodes, { kind = "fold", key = catKey, title = cat.title, depth = 0 })
        if expanded[catKey] then
            for gi, group in ipairs(cat.groups) do
                local groupKey = catKey .. ":" .. gi
                local depth = 1
                if group.title then
                    Add(nodes, { kind = "fold", key = groupKey, title = group.title, depth = 1 })
                    depth = 2
                end
                if not group.title or expanded[groupKey] then
                    for _, zone in ipairs(group.zones) do
                        Add(nodes, { kind = "zone", key = "zone:" .. cat.key .. ":" .. tostring(zone.id), title = zone.name, depth = depth, zone = zone })
                    end
                end
            end
        end
    end
    -- the chains
    Add(nodes, { kind = "fold", key = "cat:chains", title = "Quest chains", depth = 0 })
    if expanded["cat:chains"] then
        if not ns.Chains.built then
            Add(nodes, { kind = "note", title = ns.Chains.building and "Reading the chains ..." or "Click to read the chains", depth = 1, build = true })
        else
            for _, kind in ipairs({ { "epic", "Epic chains" }, { "long", "Long chains" } }) do
                local kindKey = "chains:" .. kind[1]
                local list = ns.Chains.List(kind[1])
                Add(nodes, { kind = "fold", key = kindKey, title = kind[2], depth = 1, right = C.GREY .. #list .. "|r" })
                if expanded[kindKey] then
                    if #list == 0 then Add(nodes, { kind = "note", title = "none known yet", depth = 2 }) end
                    for _, chain in ipairs(list) do
                        Add(nodes, { kind = "chain", key = "chain:" .. chain.key, title = ns.Chains.Title(chain), depth = 2, chain = chain,
                            tip = ("%d steps, level %d to %d"):format(chain.length, chain.minLevel, chain.maxLevel) })
                    end
                end
            end
        end
    end
end

local function DrawTree()
    treeRows:Release()
    local y = -2
    for _, node in ipairs(nodes) do
        local row = treeRows:Get()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetWidth(treePane.width)
        row.node = node
        local indent = ("    "):rep(node.depth)
        local text
        if node.kind == "fold" then
            text = indent .. C.GOLD .. (expanded[node.key] and "- " or "+ ") .. node.title .. "|r"
        elseif node.kind == "note" then
            text = indent .. C.GREY .. node.title .. "|r"
        else
            text = indent .. (selectedNode == node.key and C.GOLD or C.WHITE) .. node.title .. "|r"
        end
        row.text:SetText(text)
        if node.zone and node.zone.quests then
            row.right:SetText(CountText(node.key, node.zone.quests))
        elseif node.chain then
            local done, total = ns.Chains.Progress(node.chain)
            row.right:SetText(("%s%d/%d|r"):format(done >= total and C.GREEN or C.GREY, done, total))
        else
            row.right:SetText(node.right or "")
        end
        row.tip, row.tipTitle = node.tip, node.title
        row.sel:SetShown(selectedNode == node.key)
        row:SetScript("OnClick", function(self)
            local n = self.node
            if n.kind == "fold" then
                expanded[n.key] = not expanded[n.key] or nil
                ns.RefreshCompendium()
            elseif n.build then
                ns.Chains.OnBuilt(function() ns.RefreshCompendium() end)
                ns.Chains.Build()
                ns.RefreshCompendium()
            elseif n.kind == "zone" or n.kind == "chain" then
                selectedNode = n.key
                selectedQuest = nil
                search:SetText("")
                ns.RefreshCompendium()
            end
        end)
        y = y - ROW
    end
    treePane.content:SetHeight(math.max(-y + 2, 10))
end

-------------------------------------------------------------------
-- The list
-------------------------------------------------------------------
local function NodeByKey(key)
    for _, n in ipairs(nodes) do if n.key == key then return n end end
end

-- the ids on show, and whether they come as ordered chain steps
local function ListedQuests()
    local text = search:GetText():lower():trim()
    if #text >= 2 then
        local found = {}
        for id in pairs(Data.AllQuestIDs()) do
            local q = Data.Quest(id)
            if q and q.name:lower():find(text, 1, true) then
                found[#found + 1] = id
                if #found >= 300 then break end
            end
        end
        return found, false, ("Search: %d found%s"):format(#found, #found >= 300 and " (first 300)" or "")
    end
    local node = selectedNode and NodeByKey(selectedNode)
    if not node then return {}, false, "Pick a zone or a chain on the left" end
    if node.chain then return node.chain.ids, true, node.title end
    return node.zone.quests, false, node.title
end

local function Filtered(ids)
    local d = ns.db()
    local list = {}
    for _, id in ipairs(ids) do
        local state, reason = Data.State(id)
        if not (d.hideDone and state == "done") and not (d.onlyMine and state == "foreign") then
            list[#list + 1] = { id = id, state = state, reason = reason }
        end
    end
    return list
end

local function DrawList()
    listRows:Release()
    local ids, ordered, heading = ListedQuests()
    local entries = Filtered(ids)
    local y = -2
    local function Header(text)
        local row = listRows:Get()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetWidth(listPane.width)
        row.text:SetText(C.GOLD .. text .. "|r")
        row.right:SetText("")
        row.sel:Hide()
        row.tip = nil
        row:SetScript("OnClick", nil)
        y = y - ROW
    end
    local function Quest(e, prefix)
        local row = listRows:Get()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetWidth(listPane.width)
        row.text:SetText((prefix or "") .. QuestText(e.id, e.state))
        row.right:SetText(STATE_SQUARE[e.state] or "")
        row.sel:SetShown(selectedQuest == e.id)
        row.tip = e.reason and (Data.STATE_TITLES[e.state] .. ": " .. e.reason) or Data.STATE_TITLES[e.state]
        row.tipTitle = Data.Title(e.id)
        row.id = e.id
        row:SetScript("OnClick", function(self)
            selectedQuest = self.id
            ns.RefreshCompendium()
        end)
        y = y - ROW
    end

    Header(heading)
    if #entries == 0 then
        local row = listRows:Get()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetWidth(listPane.width)
        row.text:SetText(C.GREY .. (#ids == 0 and "Nothing here" or "Everything here is hidden by the filters") .. "|r")
        row.right:SetText("")
        row.sel:Hide()
        row:SetScript("OnClick", nil)
        y = y - ROW
    elseif ordered then
        -- a chain: its steps in order
        for i, e in ipairs(entries) do Quest(e, C.GREY .. i .. ".|r ") end
    elseif #entries > 400 then
        -- thousands of names: the first 400 by name, the rest through the search box
        table.sort(entries, function(a, b) return Data.Title(a.id) < Data.Title(b.id) end)
        Header(("%d quests - the first 400 by name, the search box finds the rest"):format(#entries))
        for i = 1, 400 do Quest(entries[i]) end
    else
        -- by state, each group by level then name
        local groups = {}
        for _, e in ipairs(entries) do
            groups[e.state] = groups[e.state] or {}
            table.insert(groups[e.state], e)
        end
        for _, state in ipairs(Data.STATE_ORDER) do
            local g = groups[state]
            if g then
                table.sort(g, function(a, b)
                    local la, lb = Level(Data.Quest(a.id)), Level(Data.Quest(b.id))
                    if la ~= lb then return la < lb end
                    return Data.Title(a.id) < Data.Title(b.id)
                end)
                y = y - 4
                Header(("%s (%d)"):format(Data.STATE_TITLES[state], #g))
                for _, e in ipairs(g) do Quest(e) end
            end
        end
    end
    listPane.content:SetHeight(math.max(-y + 2, 10))
end

-------------------------------------------------------------------
-- The details
-------------------------------------------------------------------
-- a writer that places pooled rows and buttons top to bottom
local function Writer()
    local w = { y = -4 }
    function w:Line(text, onClick, tip, tipTitle)
        local row = detailRows:Get()
        row:SetPoint("TOPLEFT", 0, self.y)
        row:SetWidth(detailPane.width)
        row.text:SetText(text)
        row.right:SetText("")
        row.sel:Hide()
        row.tip, row.tipTitle = tip, tipTitle
        row:SetScript("OnClick", onClick)
        row:EnableMouse(onClick ~= nil or tip ~= nil)
        self.y = self.y - ROW
        return row
    end
    function w:Wrapped(text)
        -- a long text: the row's string wraps and the row grows with it
        local row = self:Line(text)
        row.text:SetWordWrap(true)
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", 4, -3)
        row.text:SetPoint("RIGHT", -4, 0)
        local h = math.max(ROW, row.text:GetStringHeight() + 6)
        row:SetHeight(h)
        self.y = self.y - (h - ROW)
        return row
    end
    function w:Heading(text)
        self.y = self.y - 6
        self:Line(C.GOLD .. text .. "|r")
    end
    function w:Button(text, onClick, tip)
        local b = detailButtons:Get()
        b:SetPoint("TOPLEFT", 6, self.y - 2)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        D.Tip(b, text, tip)
        self.y = self.y - 26
        return b
    end
    return w
end

-- the row of a normal line is a plain button: reset what Wrapped changed
local function ResetRow(row)
    row.text:SetWordWrap(false)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", 4, 0)
    row.text:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row:SetHeight(ROW)
end

local function Place(where)
    local zone = where.zone or Data.MapName(where.mapID)
    if not zone then return "" end
    if where.x and where.y then return (" - %s (%.0f, %.0f)"):format(zone, where.x, where.y) end
    return " - " .. zone
end

local function SetWaypoint(where)
    local mapID = where.mapID
    if not (mapID and where.x and where.y) then
        ns.Print("no position on a map for " .. where.name .. ".")
        return
    end
    if not C_Map.CanSetUserWaypointOnMap(mapID) then
        ns.Print("this map takes no waypoints.")
        return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, where.x / 100, where.y / 100))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    ns.Print(("waypoint set: %s%s."):format(where.name, Place(where)))
end

local function JumpTo(id)
    return function()
        selectedQuest = id
        ns.RefreshCompendium()
    end
end

local function QuestLine(w, id, prefix)
    local state, reason = Data.State(id)
    w:Line((prefix or "") .. QuestText(id, state), JumpTo(id),
        reason and (Data.STATE_TITLES[state] .. ": " .. reason) or Data.STATE_TITLES[state], Data.Title(id))
end

local function DrawDetails()
    detailRows:Release()
    detailButtons:Release()
    for _, row in ipairs(detailRows.items) do ResetRow(row) end
    local w = Writer()
    local id = selectedQuest
    if not id then
        w:Line(C.GREY .. "Pick a quest in the middle.|r")
        detailPane.content:SetHeight(-w.y + 4)
        return
    end
    local q = Data.Quest(id)
    local state, reason = Data.State(id)

    -- the title and the state
    local level = Level(q)
    w:Wrapped(C.GOLD .. Data.Title(id) .. "|r" .. (level > 0 and (" %s[%d%s]|r"):format(LevelColor(level), level, Data.Suffix(id)) or ""))
    w:Line(STATE_SQUARE[state] .. " " .. (STATE_COLOR[state] or C.WHITE) .. Data.STATE_TITLES[state] .. "|r"
        .. (reason and (C.GREY .. " - " .. reason .. "|r") or ""))
    if state == "log" then
        w:Button("Track it", function()
            C_QuestLog.AddQuestWatch(id)
            C_SuperTrack.SetSuperTrackedQuestID(id)
        end, "Puts the quest in the tracker and makes it the navigation target.")
    end

    if not q then
        w:Line(C.GREY .. "Nothing more is known about this quest.|r")
        w:Wrapped(C.GREY .. "Playing it records its giver and its place; Questie, when installed, knows the rest.|r")
        detailPane.content:SetHeight(-w.y + 4)
        return
    end

    -- facts
    local facts = {}
    if q.requiredLevel > 0 then facts[#facts + 1] = ("needs level %d"):format(q.requiredLevel) end
    if q.maxLevel and q.maxLevel > 0 then facts[#facts + 1] = ("up to level %d"):format(q.maxLevel) end
    if q.daily then facts[#facts + 1] = "daily" elseif q.repeatable then facts[#facts + 1] = "repeatable" end
    if q.zoneName then facts[#facts + 1] = q.zoneName end
    if not q.questie then facts[#facts + 1] = q.imported and "imported from Questie" or "from your own data" end
    if #facts > 0 then w:Wrapped(C.GREY .. table.concat(facts, ", ") .. "|r") end

    -- where it starts and ends
    local starters = Data.Starters(q)
    if #starters > 0 then
        w:Heading("Starts at")
        for _, s in ipairs(starters) do
            local kind = s.kind == "item" and " (item)" or s.kind == "object" and " (object)" or s.kind == "spot" and " (seen there)" or ""
            w:Wrapped(C.WHITE .. s.name .. "|r" .. C.GREY .. kind .. Place(s) .. "|r")
            if s.mapID and s.x then
                w:Button("Waypoint", function() SetWaypoint(s) end, "Sets a waypoint there; the arrow and the compass follow it.")
            end
        end
    elseif q.own then
        w:Heading("Starts at")
        w:Line(C.GREY .. "not seen yet|r")
    end
    local finishers = Data.Finishers(q)
    if #finishers > 0 then
        w:Heading("Ends at")
        for _, f in ipairs(finishers) do
            w:Wrapped(C.WHITE .. f.name .. "|r" .. C.GREY .. Place(f) .. "|r")
            if f.mapID and f.x then
                w:Button("Waypoint", function() SetWaypoint(f) end, "Sets a waypoint there.")
            end
        end
    end

    -- what it needs first
    if #q.preGroup > 0 or #q.preSingle > 0 or q.parentQuest > 0 then
        w:Heading("Needs first")
        if #q.preGroup > 0 then
            if #q.preGroup > 1 then w:Line(C.GREY .. "all of these:|r") end
            for _, p in ipairs(q.preGroup) do QuestLine(w, math.abs(p), "  ") end
        end
        if #q.preSingle > 0 then
            if #q.preSingle > 1 then w:Line(C.GREY .. "one of these:|r") end
            for _, p in ipairs(q.preSingle) do QuestLine(w, p, "  ") end
        end
        if q.parentQuest > 0 then
            w:Line(C.GREY .. "while on:|r")
            QuestLine(w, q.parentQuest, "  ")
        end
    end
    if #q.exclusiveTo > 0 then
        w:Heading("Instead of")
        for _, e in ipairs(q.exclusiveTo) do QuestLine(w, e, "  ") end
    end

    -- what it leads to
    local following = ns.Chains.After(id)
    if q.nextInChain > 0 or #following > 0 then
        w:Heading("Leads to")
        local seen = {}
        if q.nextInChain > 0 then seen[q.nextInChain] = true QuestLine(w, q.nextInChain, "  ") end
        for _, f in ipairs(following) do
            if not seen[f] then seen[f] = true QuestLine(w, f, "  ") end
        end
    end

    -- the chain
    local chain = ns.Chains.Of(id)
    if chain then
        local done, total, at = ns.Chains.Progress(chain)
        w:Heading(("Chain: %d of %d steps done%s"):format(done, total, chain.epic and " - epic" or chain.long and " - long" or ""))
        for i, step in ipairs(chain.ids) do
            local marker = step == id and C.GOLD .. ">|r " or (step == at and C.GREEN .. ">|r " or "  ")
            QuestLine(w, step, marker .. C.GREY .. i .. ".|r ")
        end
    elseif not ns.Chains.built then
        w:Heading("Chain")
        w:Line(C.GREY .. "Read the chains first (Quest chains on the left).|r")
    end

    -- the objectives
    if #q.objectives > 0 then
        w:Heading("Objectives")
        for _, text in ipairs(q.objectives) do
            if type(text) == "string" and text ~= "" then w:Wrapped(C.GREY .. text .. "|r") end
        end
    end

    detailPane.content:SetHeight(-w.y + 4)
end

-------------------------------------------------------------------
-- Drawing and events
-------------------------------------------------------------------
function ns.RefreshCompendium()
    if not win:IsShown() then dirty = true return end
    dirty = false
    source:SetText(Data.SourceText())
    hideDone:Refresh()
    onlyMine:Refresh()
    searchHint:SetShown(search:GetText() == "" and not search:HasFocus())
    BuildTree()
    DrawTree()
    DrawList()
    DrawDetails()
end

-- the counts follow the character's progress, and what you play adds links
local function Progress()
    wipe(counts)
    Data.Reset()
    ns.Chains.Invalidate()
    if win:IsShown() then ns.RefreshCompendium() else dirty = true end
end

-- the zone the player stands in, opened on the first show: Questie's
-- zones carry area ids, our own the zone map's id
local function OpenHere()
    local mapID = C_Map.GetBestMapForUnit("player")
    local wanted = { [Data.AreaForMap(mapID) or -1] = true, [Data.ZoneMap(mapID) or -1] = true }
    for _, cat in ipairs(Data.Categories()) do
        if cat.key == "zones" or cat.key == "dungeons" then
            for gi, group in ipairs(cat.groups) do
                for _, zone in ipairs(group.zones) do
                    if wanted[zone.id] then
                        expanded["cat:" .. cat.key] = true
                        expanded["cat:" .. cat.key .. ":" .. gi] = true
                        selectedNode = "zone:" .. cat.key .. ":" .. tostring(zone.id)
                        return
                    end
                end
            end
        end
    end
    expanded["cat:zones"] = true
end

search:SetScript("OnTextChanged", function(self, user)
    searchHint:SetShown(self:GetText() == "" and not self:HasFocus())
    if user then ns.RefreshCompendium() end
end)
search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
search:SetScript("OnEditFocusLost", function(self) searchHint:SetShown(self:GetText() == "") end)
search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

local opened = false
win:SetScript("OnShow", function()
    -- the map's quest lines, and whatever was recorded since, go into the tree
    if ns.Own then ns.Own.HarvestLines(C_Map.GetBestMapForUnit("player")) end
    wipe(counts)
    Data.Reset()
    if not opened and Data.Ready() then
        opened = true
        OpenHere()
    end
    ns.RefreshCompendium()
    StartScanRefresh()
    -- the chains read themselves while the window is open
    if not ns.Chains.built then
        ns.Chains.OnBuilt(function() if win:IsShown() then ns.RefreshCompendium() end end)
        ns.Chains.Build()
    end
end)
win:SetScript("OnHide", function()
    search:ClearFocus()
    StopScanRefresh()
end)

-- the D-pad on the Steam Deck (hub, gamepad.lua); after the OnShow/OnHide above
if D.GamepadWindow then D.GamepadWindow(win, { close = close }) end

function ns.ToggleCompendium(arg)
    if arg == "here" and Data.Ready() then
        opened = false
        selectedQuest = nil
        win:Hide()
        win:Show()
        return
    end
    win:SetShown(not win:IsShown())
end

for _, e in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do ns.On(e, Progress) end
ns.On("QUEST_DATA_LOAD_RESULT", function() if win:IsShown() then ns.RefreshCompendium() end end)

function ns.InitCompendium()
    D.MakeMovable(win, "Compendium", DeckUIForeverQuestingDB)
    -- a button in the hub's dock, beside the settings and the week
    if D.DockButton then
        D.DockButton("compendium", {
            order = 3,
            icon = "Interface\\Icons\\INV_Misc_Book_09",
            title = "Quest compendium",
            tip = { "Click: every quest by zone, class and chain, and what you have done" },
            onClick = function() ns.ToggleCompendium() end,
        })
    end
    D.MakeDraggable(win)
    local function Scale() win:SetScale(ns.DeviceDB().scale or 1) end
    Scale()
    ns.ApplyCompendiumScale = Scale
    Data.OnReady(function()
        if win:IsShown() then
            if not opened then opened = true OpenHere() end
            ns.RefreshCompendium()
        end
    end)
end
