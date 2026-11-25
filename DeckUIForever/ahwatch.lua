local D = DeckUIForever

-------------------------------------------------------------------
-- Auction watch: a small broker's desk for the prices you follow
-------------------------------------------------------------------
-- Owner's wish (2026-11-23): "eine Art Fenster mit Beobachtung der AH-
-- Preise für Items", and the day after "wie ein Broker-Tool mit Diagrammen,
-- Listen etc.". Opened from the dock or with /df watch. Three lists on the
-- left, one item's picture on the right:
--   Watched  the items you dropped on the window, each with its price from
--            the last auction scan (auction.lua) and how it moved against
--            the scan before;
--   Movers   what rose and fell most between your last two scans, over the
--            whole auction house (D.AuctionMovers);
--   My bags  what you carry that can be traded, by its auction value.
-- A click on a line shows the item on the right: a chart of its price over
-- your scans, the average, lowest and highest, what you hold of it, the
-- merchant's price, and a word on whether it is cheap or dear right now.
--
-- The game hands out auction prices only at the auction house and only
-- through the full scan, so "watching" is: every scan adds one point to
-- each watched item's history. No scan, no new point. Items that are not
-- watched have the last two scans at most (the movers) or one price.
--
--   DeckUIForeverDB.ahWatchItems = { itemID, ... }        the list, account-wide
--   DeckUIForeverDB.ahHistory[store][itemID] = { t, p, t, p, ... }
--       the points, oldest first, POINTS at most; `store` is the realm and
--       faction key the prices are kept under (D.AuctionStoreKey)
-- Both are data, not settings (profiles.lua's HUB_SKIP).
-------------------------------------------------------------------
local MAX, POINTS = 12, 30
local ROWS = 12                      -- every list shows this many lines, no scrolling
local W, LIST_W, ROW, ICON, PAD, HEAD, FOOT = 624, 300, 22, 18, 8, 54, 22
local PANE_W = W - LIST_W - 3 * PAD
local CHART_H, MX, MY = 120, 8, 16   -- the chart's height and the margins inside it
local FRESH = 120                    -- a price this young came from the scan that just ended
local CHEAP, DEAR = 0.85, 1.15       -- against the average of the scans
local GOLD = { 0.9, 0.75, 0.2 }

local function List()
    DeckUIForeverDB.ahWatchItems = DeckUIForeverDB.ahWatchItems or {}
    return DeckUIForeverDB.ahWatchItems
end

local function Watched(itemID)
    for _, id in ipairs(List()) do
        if id == itemID then return true end
    end
    return false
end

local function History(itemID, create)
    local key = D.AuctionStoreKey and D.AuctionStoreKey() or "?"
    local all = DeckUIForeverDB.ahHistory
    if not all then
        if not create then return nil end
        all = {}
        DeckUIForeverDB.ahHistory = all
    end
    if not all[key] then
        if not create then return nil end
        all[key] = {}
    end
    local h = all[key][itemID]
    if not h and create then
        h = {}
        all[key][itemID] = h
    end
    return h
end

-- one more point; the same moment twice (a reload inside a scan) is one
local function AddPoint(itemID, at, price)
    local h = History(itemID, true)
    local n = #h
    if n >= 2 and math.abs(h[n - 1] - at) < FRESH then
        h[n] = price
        return
    end
    h[n + 1], h[n + 2] = at, price
    while #h > POINTS * 2 do
        table.remove(h, 1)
        table.remove(h, 1)
    end
end

-- The points to draw for an item, oldest first, as { t, p, t, p, ... }:
-- its history when it is watched, else the two scans of a mover, else the
-- one price the scans know. Empty without any price.
local function Points(itemID)
    local h = History(itemID)
    if h and #h >= 2 then return h end
    local movers, prevTime, lastTime = nil, nil, nil
    if D.AuctionMovers then movers, prevTime, lastTime = D.AuctionMovers() end
    if movers and prevTime and lastTime then
        for _, list in ipairs({ movers.up, movers.down }) do
            for i = 1, #list, 3 do
                if list[i] == itemID then return { prevTime, list[i + 1], lastTime, list[i + 2] } end
            end
        end
    end
    local price, age = D.AuctionPrice(itemID)
    if price then return { time() - age, price } end
    return {}
end

-- newest price, the one before, lowest, highest, number of points, average
local function Summary(points)
    if not points or #points < 2 then return nil end
    local low, high, sum = nil, nil, 0
    for i = 2, #points, 2 do
        local p = points[i]
        if not low or p < low then low = p end
        if not high or p > high then high = p end
        sum = sum + p
    end
    local n = #points / 2
    return points[#points], points[#points - 2], low, high, n, sum / n
end

local function Money(copper)
    copper = math.floor(copper + 0.5)
    if copper >= 10000 then copper = copper - copper % 100 end
    return GetMoneyString(copper, true)
end

local function Age(seconds)
    if seconds < 3600 then return ("%d min"):format(math.max(1, math.floor(seconds / 60))) end
    if seconds < 86400 then return ("%d h"):format(math.floor(seconds / 3600)) end
    return ("%d d"):format(math.floor(seconds / 86400))
end

-- "+12%" in green, "-8%" in red, "=" in grey, "" without two prices
local function ChangeText(newest, before)
    if not (newest and before and before > 0) then return "" end
    if newest == before then return "|cff808080=|r" end
    local pct = (newest - before) / before * 100
    local shown = math.min(999, math.floor(math.abs(pct) + 0.5))
    if shown == 0 then return "|cff808080=|r" end
    return (pct > 0 and "|cff40d040+%d%%|r" or "|cffff5040-%d%%|r"):format(shown)
end

-------------------------------------------------------------------
-- The lists
-------------------------------------------------------------------
-- each entry: { id = itemID, price = copper shown, change = text,
--               count = pieces (My bags), stale = age of an unconfirmed price }
local TABS = {
    { key = "watched", text = "Watched" },
    { key = "movers",  text = "Movers" },
    { key = "bags",    text = "My bags" },
}
local tab = "watched"
local selected   -- the item on the right

local function WatchedEntries()
    local out = {}
    local scanAge = D.AuctionScanAge and D.AuctionScanAge()
    for _, id in ipairs(List()) do
        local price, age = D.AuctionPrice(id)
        local newest, before = Summary(History(id))
        out[#out + 1] = { id = id, price = price, change = ChangeText(newest, before),
            stale = price and scanAge and age > scanAge + FRESH and age or nil }
    end
    return out
end

local function MoverEntries()
    local out = {}
    local movers = D.AuctionMovers and D.AuctionMovers()
    if not movers then return out end
    for _, list in ipairs({ movers.up, movers.down }) do
        for i = 1, #list, 3 do
            out[#out + 1] = { id = list[i], price = list[i + 2], change = ChangeText(list[i + 2], list[i + 1]) }
        end
    end
    return out
end

local function BagEntries()
    local byID, out = {}, {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isBound then
                local price = D.AuctionPrice(info.itemID)
                if price then
                    local e = byID[info.itemID]
                    if not e then
                        e = { id = info.itemID, each = price, count = 0 }
                        byID[info.itemID] = e
                        out[#out + 1] = e
                    end
                    e.count = e.count + (info.stackCount or 1)
                end
            end
        end
    end
    for _, e in ipairs(out) do e.price = e.each * e.count end
    table.sort(out, function(a, b)
        if a.price ~= b.price then return a.price > b.price end
        return a.id < b.id
    end)
    return out
end

local EMPTY = {
    watched = "Drop an item here to watch its auction price.",
    movers  = "Movers appear after your second scan of the auction house.",
    bags    = "Nothing in your bags has an auction price yet.",
}
local HINTS = {
    watched = "Drop an item to add it. Click: details. Right-click: remove.",
    movers  = "Up and down between your last two scans. Click: details.",
    bags    = "What you carry, by auction value. Click: details.",
}

local function Entries()
    if tab == "movers" then return MoverEntries() end
    if tab == "bags" then return BagEntries() end
    return WatchedEntries()
end

-------------------------------------------------------------------
-- The window
-------------------------------------------------------------------
local win = CreateFrame("Frame", "DeckUIForeverAuctionWatch", UIParent)
win:SetSize(W, HEAD + ROWS * ROW + FOOT + 6)
win:SetFrameStrata("MEDIUM")
win:SetToplevel(true)
win:EnableMouse(true)
win:SetClampedToScreen(true)
win.defaultPoint = { "CENTER", UIParent, "CENTER", 0, 80 }
win:SetPoint(unpack(win.defaultPoint))
win:Hide()
tinsert(UISpecialFrames, "DeckUIForeverAuctionWatch")
D.FlatBox(win, 0.92)

local title = win:CreateFontString(nil, "OVERLAY")
title:SetFont(D.FONT, 13, "OUTLINE")
title:SetPoint("TOPLEFT", PAD + 2, -8)
title:SetText("Auction watch")
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

local scanned = win:CreateFontString(nil, "OVERLAY")
scanned:SetFont(D.FONT, 11, "OUTLINE")
scanned:SetPoint("TOPRIGHT", -28, -9)
scanned:SetTextColor(0.6, 0.6, 0.6)

local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)
close:SetScript("OnClick", function() win:Hide() end)

local hint = win:CreateFontString(nil, "OVERLAY")
hint:SetFont(D.FONT, 11, "OUTLINE")
hint:SetPoint("BOTTOMLEFT", PAD + 2, 7)
hint:SetPoint("RIGHT", -PAD, 0)
hint:SetJustifyH("LEFT")
hint:SetWordWrap(false)
hint:SetTextColor(0.5, 0.5, 0.5)

-- shown in the list's place while it is empty
local empty = win:CreateFontString(nil, "OVERLAY")
empty:SetFont(D.FONT, 12, "OUTLINE")
empty:SetPoint("TOPLEFT", PAD + 4, -HEAD - 6)
empty:SetWidth(LIST_W - 8)
empty:SetJustifyH("LEFT")
empty:SetTextColor(0.6, 0.6, 0.6)

local rows, tabButtons = {}, {}
local preview = false
local Draw

local function Remove(itemID)
    local list = List()
    for i = #list, 1, -1 do
        if list[i] == itemID then table.remove(list, i) end
    end
    GameTooltip_Hide()
    Draw()
    if D.DockUpdate then D.DockUpdate() end
end

-- true when the item is in the list afterwards
function D.AuctionWatchAdd(itemID)
    if type(itemID) ~= "number" then return false end
    local list = List()
    if not Watched(itemID) then
        if #list >= MAX then
            print(("DeckUIForever: the auction watch holds %d items - remove one to make room."):format(MAX))
            return false
        end
        -- what the scans know already is where the history starts
        local known = Points(itemID)
        list[#list + 1] = itemID
        local h = History(itemID)
        if not (h and #h > 0) then
            for i = 1, #known, 2 do AddPoint(itemID, known[i], known[i + 1]) end
        end
    end
    selected = itemID
    Draw()
    if D.DockUpdate then D.DockUpdate() end
    return true
end

-- an item dropped on the window: ClearCursor puts it back where it was
local function AddFromCursor()
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID then return end
    ClearCursor()
    tab = "watched"
    D.AuctionWatchAdd(itemID)
end
win:SetScript("OnReceiveDrag", AddFromCursor)
win:SetScript("OnMouseUp", AddFromCursor)

for i, t in ipairs(TABS) do
    local b = CreateFrame("Button", nil, win)
    b:SetSize(96, 20)
    b:SetPoint("TOPLEFT", PAD + (i - 1) * 100, -28)
    D.FlatBox(b, 0.6, 0.3)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(D.FONT, 12, "OUTLINE")
    b.text:SetPoint("CENTER")
    b.text:SetText(t.text)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    b:SetScript("OnClick", function()
        tab = t.key
        Draw()
    end)
    b:SetScript("OnReceiveDrag", AddFromCursor)
    tabButtons[t.key] = b
end

local function RowOnEnter(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetItemByID(self.itemID)
    if self.stale then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("Not on offer with a buyout in your last scan. The price is the last one seen, %s ago."):format(
            Age(self.stale)), 1, 0.6, 0.3, true)
    end
    if tab == "watched" then GameTooltip:AddLine("Right-click: stop watching", 0.5, 0.5, 0.5) end
    GameTooltip:Show()
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, win)
    r:SetSize(LIST_W, ROW)
    r:SetPoint("TOPLEFT", PAD, -HEAD - (i - 1) * ROW)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    -- the picked line
    r.lit = r:CreateTexture(nil, "BACKGROUND")
    r.lit:SetAllPoints()
    r.lit:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.16)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.icon:SetPoint("LEFT", 2, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- right to left: the change, the price, then the name takes the rest
    r.change = r:CreateFontString(nil, "OVERLAY")
    r.change:SetFont(D.FONT, 11, "OUTLINE")
    r.change:SetPoint("RIGHT", -4, 0)
    r.change:SetWidth(44)
    r.change:SetJustifyH("RIGHT")
    r.price = r:CreateFontString(nil, "OVERLAY")
    r.price:SetFont(D.FONT, 11, "OUTLINE")
    r.price:SetPoint("RIGHT", r.change, "LEFT", -4, 0)
    r.name = r:CreateFontString(nil, "OVERLAY")
    r.name:SetFont(D.FONT, 12, "OUTLINE")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetPoint("RIGHT", r.price, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r:SetScript("OnClick", function(self, mouse)
        if GetCursorInfo() == "item" then AddFromCursor() return end
        if not self.itemID then return end
        if mouse == "RightButton" then
            if tab == "watched" then Remove(self.itemID) end
        elseif IsModifiedClick() then
            local _, link = C_Item.GetItemInfo(self.itemID)
            if link then HandleModifiedItemClick(link) end
        else
            selected = self.itemID
            Draw()
        end
    end)
    r:SetScript("OnReceiveDrag", AddFromCursor)
    r:SetScript("OnEnter", RowOnEnter)
    r:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = r
    return r
end

-- true while the item's name has not arrived
local function FillRow(r, e)
    r.itemID, r.stale = e.id, e.stale
    r.icon:SetTexture(C_Item.GetItemIconByID(e.id) or 134400)
    local name = C_Item.GetItemNameByID(e.id)
    local quality = C_Item.GetItemQualityByID(e.id)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local text = name or "Loading item..."
    if e.count and e.count > 1 then text = text .. (" |cffaaaaaax%d|r"):format(e.count) end
    r.name:SetText(text)
    if name and color then
        r.name:SetTextColor(color.r, color.g, color.b)
    else
        r.name:SetTextColor(0.7, 0.7, 0.7)
    end
    if e.price then
        r.price:SetText(Money(e.price) .. (e.stale and (" |cff808080(%s)|r"):format(Age(e.stale)) or ""))
    else
        r.price:SetText("|cff808080no price yet|r")
    end
    r.change:SetText(e.change or "")
    r.lit:SetShown(e.id == selected)
    return name == nil
end

-------------------------------------------------------------------
-- The right side: one item
-------------------------------------------------------------------
local pane = CreateFrame("Frame", nil, win)
pane:SetPoint("TOPLEFT", PAD + LIST_W + PAD, -HEAD)
pane:SetSize(PANE_W, ROWS * ROW)

pane.icon = pane:CreateTexture(nil, "ARTWORK")
pane.icon:SetSize(24, 24)
pane.icon:SetPoint("TOPLEFT", 0, 0)
pane.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local watchButton = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
watchButton:SetSize(96, 20)
watchButton:SetPoint("TOPRIGHT", 0, -2)
watchButton:GetFontString():SetFont(D.FONT, 11, "OUTLINE")
if D.FlattenButton then D.FlattenButton(watchButton) end
watchButton:SetScript("OnClick", function()
    if not selected then return end
    if Watched(selected) then Remove(selected) else D.AuctionWatchAdd(selected) end
end)

pane.name = pane:CreateFontString(nil, "OVERLAY")
pane.name:SetFont(D.FONT, 13, "OUTLINE")
pane.name:SetPoint("LEFT", pane.icon, "RIGHT", 6, 0)
pane.name:SetPoint("RIGHT", watchButton, "LEFT", -6, 0)
pane.name:SetJustifyH("LEFT")
pane.name:SetWordWrap(false)

local chart = CreateFrame("Frame", nil, pane)
chart:SetPoint("TOPLEFT", 0, -30)
chart:SetSize(PANE_W, CHART_H)
D.FlatBox(chart, 0.5, 0.25)

local function ChartText(point, x, y, justify)
    local fs = chart:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, 10, "OUTLINE")
    fs:SetPoint(point, x, y)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(0.65, 0.65, 0.65)
    return fs
end
chart.high  = ChartText("TOPLEFT", 4, -3)
chart.low   = ChartText("BOTTOMLEFT", 4, 3)
chart.first = ChartText("TOPLEFT", 0, -CHART_H - 3)
chart.last  = ChartText("TOPRIGHT", 0, -CHART_H - 3, "RIGHT")
chart.note  = chart:CreateFontString(nil, "OVERLAY")
chart.note:SetFont(D.FONT, 11, "OUTLINE")
chart.note:SetPoint("CENTER")
chart.note:SetWidth(PANE_W - 24)
chart.note:SetTextColor(0.6, 0.6, 0.6)
-- the average, a faint line across
chart.average = chart:CreateTexture(nil, "ARTWORK", nil, 1)
chart.average:SetColorTexture(1, 1, 1, 0.25)
chart.average:SetHeight(1)

local chartLines, chartDots = {}, {}

-- the price over the scans: a dot per scan, joined, time running to the right
local function Plot(points)
    for _, l in ipairs(chartLines) do l:Hide() end
    for _, d in ipairs(chartDots) do d:Hide() end
    chart.average:Hide()
    chart.high:SetText("")
    chart.low:SetText("")
    chart.first:SetText("")
    chart.last:SetText("")
    local n = #points / 2
    if n < 1 then
        chart.note:SetText("No price yet. Scan the auction house while this item is on offer.")
        return
    end
    chart.note:SetText(n == 1 and "One scan so far - the line starts with the next one." or "")
    local _, _, low, high, _, average = Summary(points)
    local t0, t1 = points[1], points[#points - 1]
    local w, h = PANE_W - 2 * MX, CHART_H - 2 * MY
    local function X(t)
        if t1 <= t0 then return MX + w end
        return MX + (t - t0) / (t1 - t0) * w
    end
    local function Y(p)
        if high <= low then return MY + h / 2 end
        return MY + (p - low) / (high - low) * h
    end
    local lastX, lastY
    for i = 1, n do
        local x, y = X(points[i * 2 - 1]), Y(points[i * 2])
        local d = chartDots[i]
        if not d then
            d = chart:CreateTexture(nil, "OVERLAY")
            d:SetColorTexture(1, 0.9, 0.5, 1)
            chartDots[i] = d
        end
        local size = i == n and 6 or 4   -- the newest stands out
        d:SetSize(size, size)
        d:ClearAllPoints()
        d:SetPoint("CENTER", chart, "BOTTOMLEFT", x, y)
        d:Show()
        if lastX and chart.CreateLine then
            local l = chartLines[i - 1]
            if not l then
                l = chart:CreateLine(nil, "ARTWORK", nil, 2)
                l:SetThickness(1.5)
                l:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
                chartLines[i - 1] = l
            end
            l:SetStartPoint("BOTTOMLEFT", chart, lastX, lastY)
            l:SetEndPoint("BOTTOMLEFT", chart, x, y)
            l:Show()
        end
        lastX, lastY = x, y
    end
    if n >= 3 and high > low then
        chart.average:ClearAllPoints()
        chart.average:SetPoint("LEFT", chart, "BOTTOMLEFT", MX, Y(average))
        chart.average:SetPoint("RIGHT", chart, "BOTTOMRIGHT", -MX, Y(average))
        chart.average:Show()
    end
    chart.high:SetText(Money(high))
    if high > low then chart.low:SetText(Money(low)) end
    local now = time()
    if n > 1 then chart.first:SetText(Age(now - t0) .. " ago") end
    chart.last:SetText(Age(now - t1) .. " ago")
end

-- the figures under the chart: a grey label left, the value right
local STATS = { "Now", "Average", "Lowest / highest", "You hold", "Merchant pays" }
local stats = {}
for i, label in ipairs(STATS) do
    local y = -CHART_H - 50 - (i - 1) * 16
    local l = pane:CreateFontString(nil, "OVERLAY")
    l:SetFont(D.FONT, 11, "OUTLINE")
    l:SetPoint("TOPLEFT", 2, y)
    l:SetTextColor(0.65, 0.65, 0.65)
    l:SetText(label)
    local v = pane:CreateFontString(nil, "OVERLAY")
    v:SetFont(D.FONT, 11, "OUTLINE")
    v:SetPoint("TOPRIGHT", -2, y)
    v:SetJustifyH("RIGHT")
    stats[i] = { label = l, value = v }
end

local verdict = pane:CreateFontString(nil, "OVERLAY")
verdict:SetFont(D.FONT, 12, "OUTLINE")
verdict:SetPoint("BOTTOMLEFT", 2, 2)
verdict:SetPoint("RIGHT", -2, 0)
verdict:SetJustifyH("LEFT")
verdict:SetWordWrap(false)

local function Stat(i, text, label)
    stats[i].value:SetText(text or "|cff808080-|r")
    if label then stats[i].label:SetText(label) end
end

-- true while the item's name has not arrived
local function FillPane()
    local id = selected
    pane:SetShown(id ~= nil)
    if not id then return false end
    local name = C_Item.GetItemNameByID(id)
    local quality = C_Item.GetItemQualityByID(id)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    pane.icon:SetTexture(C_Item.GetItemIconByID(id) or 134400)
    pane.name:SetText(name or "Loading item...")
    if name and color then
        pane.name:SetTextColor(color.r, color.g, color.b)
    else
        pane.name:SetTextColor(0.7, 0.7, 0.7)
    end
    watchButton:SetText(Watched(id) and "Stop watching" or "Watch")

    local points = Points(id)
    Plot(points)
    local newest, before, low, high, n, average = Summary(points)
    local price, age = D.AuctionPrice(id)
    Stat(1, price and (Money(price) .. " " .. ChangeText(newest, before)) or nil)
    Stat(2, n and n > 1 and Money(average) or nil, n and n > 1 and ("Average of %d scans"):format(n) or "Average")
    Stat(3, n and n > 1 and (Money(low) .. " / " .. Money(high)) or nil)
    local held = C_Item.GetItemCount(id) or 0
    Stat(4, held > 0 and (price and ("%d = %s"):format(held, Money(price * held)) or tostring(held)) or nil)
    local vendor = select(11, C_Item.GetItemInfo(id))
    Stat(5, type(vendor) == "number" and vendor > 0 and Money(vendor) or nil)

    -- a word on the price, from three scans on: against their average
    if not price then
        verdict:SetText("|cff808080No auction price known.|r")
    elseif type(vendor) == "number" and vendor >= price then
        verdict:SetText("|cffffd100The merchant pays as much or more.|r")
    elseif n and n >= 3 and average > 0 then
        local ratio = price / average
        if ratio <= CHEAP then
            verdict:SetText(("|cff40d040Cheap right now: %d%% under its average.|r"):format(math.floor((1 - ratio) * 100 + 0.5)))
        elseif ratio >= DEAR then
            verdict:SetText(("|cffff5040Dear right now: %d%% over its average.|r"):format(math.floor((ratio - 1) * 100 + 0.5)))
        else
            verdict:SetText("|cffc0c0c0Around its average.|r")
        end
    elseif age and age > 86400 then
        verdict:SetText(("|cff808080The price is %s old.|r"):format(Age(age)))
    else
        verdict:SetText("|cff808080Watch it over three scans for a verdict.|r")
    end
    return name == nil
end

-------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------
local retry = false
function Draw()
    if not win:IsShown() then return end
    for key, b in pairs(tabButtons) do
        local on = key == tab
        b.text:SetTextColor(on and GOLD[1] or 0.7, on and GOLD[2] or 0.7, on and GOLD[3] or 0.7)
        b:SetAlpha(on and 1 or 0.75)
    end
    local entries = Entries()
    -- the picked item stays while it is anywhere to be found, else the
    -- list's first line is picked
    if selected == nil and entries[1] then selected = entries[1].id end
    local shown, loading = 0, false
    for i = 1, math.min(#entries, ROWS) do
        shown = i
        local r = Row(i)
        if FillRow(r, entries[i]) then loading = true end
        r:Show()
    end
    for i = shown + 1, #rows do
        rows[i].itemID = nil
        rows[i]:Hide()
    end
    empty:SetText(shown == 0 and EMPTY[tab] or "")
    hint:SetText(HINTS[tab])
    local age = D.AuctionScanAge and D.AuctionScanAge()
    scanned:SetText(age and ("scanned %s ago"):format(Age(age)) or "no scan yet")
    if FillPane() then loading = true end
    -- names arrive from the server a moment after they are first asked for
    if loading and not retry then
        retry = true
        C_Timer.After(0.5, function()
            retry = false
            Draw()
        end)
    end
end

win:SetScript("OnShow", function() Draw() end)
win:SetScript("OnHide", GameTooltip_Hide)
-- the D-pad on the Steam Deck (gamepad.lua); after the scripts above
if D.GamepadWindow then D.GamepadWindow(win, { close = close }) end

function D.ToggleAuctionWatch()
    win:SetShown(not win:IsShown())
end

-------------------------------------------------------------------
-- Every scan adds a point for each watched item it saw
-------------------------------------------------------------------
D.OnAuctionPrices(function()
    local now = time()
    for _, itemID in ipairs(List()) do
        local price, age = D.AuctionPrice(itemID)
        if price and age < FRESH then AddPoint(itemID, now, price) end
    end
    Draw()
end)

-------------------------------------------------------------------
-- Dock button, move, /df watch
-------------------------------------------------------------------
if D.DockButton then
    D.DockButton("auctionwatch", {
        order = 4,
        icon = "Interface\\Minimap\\Tracking\\Auctioneer",
        texCoord = { 0, 1, 0, 1 },
        title = "Auction watch",
        tip = function()
            local n = DeckUIForeverDB and DeckUIForeverDB.ahWatchItems and #DeckUIForeverDB.ahWatchItems or 0
            return { n == 0 and "Click: follow the auction prices of items you pick"
                or ("Click: the prices of your %d watched item%s"):format(n, n == 1 and "" or "s") }
        end,
        onClick = function() D.ToggleAuctionWatch() end,
        available = function() return DeckUIForeverDB and DeckUIForeverDB.ahWatchDock and true or false end,
    })
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE_DELAYED" then
        -- "My bags" and "You hold" follow the bags
        if win:IsShown() then Draw() end
        return
    end
    D.MakeMovable(win, "Auction watch", DeckUIForeverDB)
    D.MakeDraggable(win)
    -- MakeDraggable took the drag scripts: a drop of an item still lands
    win:SetScript("OnReceiveDrag", AddFromCursor)
    D.OnUnlock(function(state, only)
        if only and not only["Auction watch"] then state = false end
        if state and not win:IsShown() then
            preview = true
            win:Show()
        elseif not state and preview then
            preview = false
            win:Hide()
        end
    end)
    if D.DockUpdate then D.DockUpdate() end
end)

-- /df watch: open or close; /df watch <item link or ID>: add it
function D.AuctionWatchCommand(rest)
    local id = rest and (rest:match("item:(%d+)") or rest:match("^(%d+)$"))
    if id then
        tab = "watched"
        if not win:IsShown() then win:Show() end
        D.AuctionWatchAdd(tonumber(id))
        return
    end
    D.ToggleAuctionWatch()
end
