local D = DeckUIForever

-------------------------------------------------------------------
-- Auction house prices: a full scan, kept for when you are away
-------------------------------------------------------------------
-- Owner's wish (2026-10-08): know on the road what things sell for. The
-- game hands out auction data only at the auction house; its full scan is
-- C_AuctionHouse.ReplicateItems ("in place of an 'allItem' query",
-- Blizzard's API documentation), allowed once every 15 minutes. So:
--  - opening the auction house shows a line below it with "Scan now" when
--    the last scan is at least 15 minutes old (DeckUIForeverDB.ahScan, on). The
--    scan needs a click: started by itself when the window opened, it was
--    never answered (owner's test, 2026-10-08). Opening is AuctionHouseFrame's
--    OnShow: AUCTION_HOUSE_SHOW, which the first version waited for, no
--    longer exists - Midnight opens the window through the player
--    interaction manager (Blizzard_AuctionHouseUI_Bootstrap.lua), and no
--    scan ever started (owner's report, 2026-10-08). Should the game refuse
--    a scan that no click started, the status line offers "Scan now";
--  - REPLICATE_ITEM_LIST_UPDATE says the list is there; it is read in
--    slices of a few thousand entries a frame, so the game does not freeze;
--  - per item ID the lowest buyout per piece is kept, per realm and
--    faction, with the time of the scan ("Where the prices are kept" below).
-- Every item level of a piece of gear shares its item ID, so for gear the
-- price is the cheapest of them - "from".
-- D.AuctionPrice(itemID) -> copper per piece, seconds since the scan.
-- D.OnAuctionPrices(fn) is called after a scan (the bags refresh then).
-------------------------------------------------------------------
local INTERVAL = 15 * 60
local SLICE = 4000

local callbacks = {}
function D.OnAuctionPrices(fn) callbacks[#callbacks + 1] = fn end

local function RealmKey()
    return GetNormalizedRealmName() or GetRealmName() or "?"
end

-------------------------------------------------------------------
-- Where the prices are kept (2026-11-23: nothing is thrown away)
-------------------------------------------------------------------
-- DeckUIForeverDB.ahPrices[key] = {
--     time = <last scan>, prices = { [itemID] = copper },   -- that scan
--     old = { [itemID] = copper }, oldTimes = { [itemID] = <its scan> },
-- }
-- `old` holds what an earlier scan saw and the last one did not, for KEEP
-- days: before, an item not on offer at the moment of the scan lost its
-- price. The key is the realm and the character's faction, because Classic
-- keeps an auction house per faction and a neutral one - whether Forever
-- does is not known, so a lookup goes on to the realm's other stores when
-- its own has nothing: with one shared house every character still sees
-- every scan. "<realm>" alone is the store of before this change.
-- A scan far smaller than the store it would replace is taken for the
-- neutral house and kept apart, under "<realm>-Other" (SmallScan).
local KEEP = 30 * 86400
local SUFFIXES = { "-Alliance", "-Horde", "-Other" }

local function Faction()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return (faction == "Alliance" or faction == "Horde") and faction or "Other"
end

local function StoreKey() return RealmKey() .. "-" .. Faction() end

-- the realm's stores, the character's own first
local function Stores()
    local all = DeckUIForeverDB and DeckUIForeverDB.ahPrices
    if not all then return {} end
    local realm, own = RealmKey(), StoreKey()
    local list = {}
    if all[own] then list[1] = all[own] end
    if all[realm] then list[#list + 1] = all[realm] end
    for _, suffix in ipairs(SUFFIXES) do
        local key = realm .. suffix
        if key ~= own and all[key] then list[#list + 1] = all[key] end
    end
    return list
end

-- Stores() is asked for every bag slot, so the list is kept; the key is
-- part of the check because the realm's name is not there at file load
local storesFor, storesKey, storesList

local function CachedStores()
    local all = DeckUIForeverDB and DeckUIForeverDB.ahPrices
    local key = StoreKey()
    if storesFor ~= all or storesKey ~= key or not storesList then
        storesFor, storesKey, storesList = all, key, Stores()
    end
    return storesList
end

function D.AuctionPrice(itemID)
    if not itemID then return nil end
    local now = time()
    for _, store in ipairs(CachedStores()) do
        local price = store.prices and store.prices[itemID]
        if price then return price, now - (store.time or 0) end
        price = store.old and store.old[itemID]
        if price then return price, now - (store.oldTimes and store.oldTimes[itemID] or 0) end
    end
    return nil
end

-- "12g 40s" for a loot or roll row: what `count` of the linked item sell
-- for by the last scan, or nil - no price, the option off (ahLoot), or a
-- link or count the game keeps secret. Copper is dropped from a gold on.
function D.AuctionWorth(link, count)
    if not (DeckUIForeverDB and DeckUIForeverDB.ahLoot) or not link then return nil end
    if issecretvalue and (issecretvalue(link) or issecretvalue(count)) then return nil end
    local ok, itemID = pcall(C_Item.GetItemInfoInstant, link)
    if not ok or not itemID then return nil end
    local price = D.AuctionPrice(itemID)
    if not price then return nil end
    local value = price * (type(count) == "number" and count > 0 and count or 1)
    if value >= 10000 then value = value - value % 100 end
    return GetMoneyString(value, true)
end

-- for the auction watch (ahwatch.lua): the key its history is kept under,
-- and how long ago this character's store was last scanned (nil: never)
D.AuctionStoreKey = StoreKey
function D.AuctionScanAge()
    local store = Stores()[1]
    return store and store.time and (time() - store.time) or nil
end

local function Count(t)
    local n = 0
    if t then for _ in pairs(t) do n = n + 1 end end
    return n
end

-- a scan with less than a quarter of what the store holds, while that is
-- younger than a week: another, smaller house
local function SmallScan(prev, count, now)
    if not prev or now - (prev.time or 0) > 7 * 86400 then return false end
    local had = Count(prev.prices)
    return had >= 200 and count * 4 < had
end

-- What moved most between two scans, for the auction watch's "Movers"
-- list: MOVERS items up and as many down, each as id, price before, price
-- now in one flat list. Worked out once, when a scan is saved - the scan
-- before is gone afterwards. Pennies are left out (MOVER_MIN); the price is
-- the lowest buyout, so a single odd listing can top the list.
local MOVERS, MOVER_MIN = 6, 500

local function Movers(before, after)
    local list = {}
    for id, new in pairs(after) do
        local was = before[id]
        if was and was > 0 and new ~= was and math.max(was, new) >= MOVER_MIN then
            list[#list + 1] = { id, was, new, (new - was) / was }
        end
    end
    table.sort(list, function(a, b)
        if a[4] ~= b[4] then return a[4] > b[4] end
        return a[1] < b[1]
    end)
    local up, down = {}, {}
    for i = 1, math.min(MOVERS, #list) do
        local e = list[i]
        if e[4] > 0 then up[#up + 1], up[#up + 2], up[#up + 3] = e[1], e[2], e[3] end
    end
    for i = #list, math.max(1, #list - MOVERS + 1), -1 do
        local e = list[i]
        if e[4] < 0 then down[#down + 1], down[#down + 2], down[#down + 3] = e[1], e[2], e[3] end
    end
    return { up = up, down = down }
end

-- the movers of this character's last scan, the time of the scan before
-- it and its own time; nil before the second scan
function D.AuctionMovers()
    local store = Stores()[1]
    if not (store and store.movers) then return nil end
    return store.movers, store.prevTime, store.time
end

-- Writes a finished scan; returns the key it went to and how many older
-- prices stay beside it.
local function Save(prices, count)
    local all = DeckUIForeverDB.ahPrices or {}
    DeckUIForeverDB.ahPrices = all
    local now, realm, key = time(), RealmKey(), StoreKey()
    -- the store of before this change becomes this character's
    if not all[key] and all[realm] then all[key], all[realm] = all[realm], nil end
    if SmallScan(all[key], count, now) then key = realm .. "-Other" end
    local prev = all[key]
    local old, oldTimes, kept = {}, {}, 0
    local function Carry(from, times, stamp)
        for id, price in pairs(from or {}) do
            local at = times and times[id] or stamp or 0
            if not prices[id] and not old[id] and now - at < KEEP then
                old[id], oldTimes[id], kept = price, at, kept + 1
            end
        end
    end
    if prev then
        Carry(prev.prices, nil, prev.time)   -- the newer ones first
        Carry(prev.old, prev.oldTimes)
    end
    all[key] = { time = now, prices = prices, old = old, oldTimes = oldTimes,
        movers = prev and prev.prices and Movers(prev.prices, prices) or nil, prevTime = prev and prev.time }
    storesList = nil
    return key, kept
end

-------------------------------------------------------------------
-- A small status line at the top of the auction house window
-------------------------------------------------------------------
local status = CreateFrame("Frame", "DeckAuctionScanStatus", UIParent)
status:SetFrameStrata("HIGH")
status:Hide()
D.FlatBox(status, 0.85)
status:SetSize(340, 24)
local statusText = status:CreateFontString(nil, "OVERLAY")
statusText:SetFont(D.FONT, 12, "OUTLINE")
statusText:SetPoint("LEFT", 8, 0)
statusText:SetPoint("RIGHT", -84, 0)
statusText:SetJustifyH("LEFT")
statusText:SetWordWrap(false)

local scanButton = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
scanButton:SetSize(74, 18)
scanButton:SetPoint("RIGHT", -3, 0)
scanButton:SetText("Scan now")
scanButton:GetFontString():SetFont(D.FONT, 11, "OUTLINE")
D.FlattenButton(scanButton)

local function Say(text, seconds)
    local ah = _G.AuctionHouseFrame
    if not (ah and ah:IsShown()) then return end
    status:ClearAllPoints()
    -- below the window and its tabs: above it, a window near the top of the
    -- screen pushed the line off it and nobody saw it (2026-10-08)
    status:SetPoint("TOP", ah, "BOTTOM", 0, -34)
    statusText:SetText(text)
    status:Show()
    if seconds then
        C_Timer.After(seconds, function()
            if statusText:GetText() == text then status:Hide() end
        end)
    end
end

-------------------------------------------------------------------
-- The scan
-------------------------------------------------------------------
local requested = false
local reader = CreateFrame("Frame")
local prices, total, index

local function Finish()
    reader:SetScript("OnUpdate", nil)
    local count = Count(prices)
    local key, kept = Save(prices, count)
    DeckUIForeverDB.ahPrices[key].listings = total   -- for /df ah: how much the game sent
    prices = nil
    local text = ("Auction prices saved: %s items from %s listings"):format(BreakUpLargeNumbers(count), BreakUpLargeNumbers(total))
    if kept > 0 then text = text .. (", %s older kept"):format(BreakUpLargeNumbers(kept)) end
    if key ~= StoreKey() then text = text .. " (a small house, kept apart)" end
    Say(text, 6)
    for _, fn in ipairs(callbacks) do xpcall(fn, geterrorhandler()) end
end

local function ReadSlice()
    -- the list may still have grown (see BeginRead)
    local n = C_AuctionHouse.GetNumReplicateItems() or 0
    if n > total then total = n end
    local last = math.min(index + SLICE, total) - 1
    for i = index, last do
        -- 0-based; count is the 3rd, buyoutPrice the 10th, itemID the 17th return
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
        if itemID and buyout and buyout > 0 and count and count > 0 then
            local each = math.floor(buyout / count)
            local known = prices[itemID]
            if not known or each < known then prices[itemID] = each end
        end
    end
    index = last + 1
    if index >= total then
        Finish()
    else
        Say(("Reading the auction house ... %d%%"):format(math.floor(index / total * 100)))
    end
end

local function Since() return time() - (DeckUIForeverDB.ahLastScan or 0) end

local answered = 0   -- REPLICATE_ITEM_LIST_UPDATE seen this session (/df ah)

-- A full scan of a big auction house can take a minute or more. The first
-- version gave up after 10 seconds and then threw the late answer away as
-- "someone else's scan" - and since the server had counted that request,
-- every further click inside 15 minutes was ignored ("No answer" again and
-- again, owner 2026-11-09). Now:
--  - a request stays ours for LATE seconds: an answer that comes after the
--    wait gave up is still read;
--  - while waiting, the list's size is polled once a second, in case the
--    data is there without the event;
--  - the request waits for the throttle system when the game has one.
local WAIT = 90          -- seconds the status line waits before offering a retry
local LATE = 5 * 60      -- seconds an answer still counts as ours
local requestedAt        -- time() of the last ReplicateItems of ours
local waitTicker
local BeginRead          -- defined below, after the reader

local settling = false    -- the list is arriving and not read yet (BeginRead)

local function StopWaiting()
    if waitTicker then waitTicker:Cancel() waitTicker = nil end
    settling = false
end

local function Ours()
    return requested or (requestedAt and time() - requestedAt < LATE)
end

local function Ready()
    local ah = C_AuctionHouse
    if ah.IsThrottledMessageSystemReady then
        local ok, ready = pcall(ah.IsThrottledMessageSystemReady)
        if ok and ready == false then return false end
    end
    return true
end

local function Request()
    requested, requestedAt = true, time()
    C_AuctionHouse.ReplicateItems()
    local before = C_AuctionHouse.GetNumReplicateItems() or 0
    local waited = 0
    StopWaiting()
    waitTicker = C_Timer.NewTicker(1, function()
        if not requested then StopWaiting() return end
        waited = waited + 1
        -- the list may be there without the event
        local n = C_AuctionHouse.GetNumReplicateItems() or 0
        if n > 0 and before == 0 then
            BeginRead()
            return
        end
        if waited >= WAIT then
            StopWaiting()
            requested = false   -- an answer within LATE is still read (Ours)
            Say("No answer yet - it may still come. Leave the window open or try again.")
            scanButton:Show()
        else
            Say(("Asking the auction house for all listings ... %ds"):format(waited))
        end
    end)
end

-- ahLastScan is written when the list arrives, not when it is asked for:
-- an unanswered request must not lock the button for 15 minutes
local function StartScan()
    if prices then return end   -- already reading
    scanButton:Hide()
    Say("Asking the auction house for all listings ...")
    if Ready() then
        Request()
        return
    end
    -- the throttle system is busy: wait for it, a few seconds at most
    requested = true
    local tries = 0
    StopWaiting()
    waitTicker = C_Timer.NewTicker(0.5, function()
        tries = tries + 1
        if Ready() or tries >= 10 then
            StopWaiting()
            Request()
        end
    end)
end

scanButton:SetScript("OnClick", function()
    if Since() < INTERVAL and not requested then
        Say(("The game allows one scan every 15 minutes - %d min to go."):format(math.ceil((INTERVAL - Since()) / 60)), 5)
        return
    end
    StartScan()
end)

local function OnOpen()
    if not (DeckUIForeverDB and DeckUIForeverDB.ahScan) then return end
    scanButton:Hide()
    if Since() < INTERVAL then
        local store = Stores()[1]
        if store then
            Say(("Prices from %d min ago - next scan in %d min"):format(
                math.floor((time() - store.time) / 60), math.ceil((INTERVAL - Since()) / 60)), 6)
        end
        return
    end
    -- the scan needs a click: started from the window opening, the game
    -- never answered (owner's test, 2026-10-08) - so the button it is
    Say("Auction prices: scan the auction house")
    scanButton:Show()
end

local function OnClose()
    -- the list is gone with the window; a half-read scan is dropped
    if prices then
        reader:SetScript("OnUpdate", nil)
        prices = nil
    end
    requested, requestedAt = false, nil
    StopWaiting()
    status:Hide()
end

-- The list is not read the moment it shows up. Reading at the first sign
-- of it gave scans that each held a different part of the house: within
-- two days 2,600 items were "no longer on offer" beside 3,000 that were,
-- basic herbs among them, and an item's price was the cheapest of the few
-- listings that happened to be there - Earthroot at 25 silver a piece
-- (owner 2026-11-24: "völlig falsche Preise"). So the list's size is
-- watched and the reading starts once it has stood still for SETTLE
-- seconds; ReadSlice follows a list that grows even later.
local SETTLE, SETTLE_MAX = 3, 120

BeginRead = function()
    if prices or settling then return end   -- already arriving or reading (event and poll both fired)
    StopWaiting()
    requested, requestedAt = false, nil
    DeckUIForeverDB.ahLastScan = time()
    scanButton:Hide()
    settling = true
    local last, still, waited = -1, 0, 0
    waitTicker = C_Timer.NewTicker(1, function()
        local n = C_AuctionHouse.GetNumReplicateItems() or 0
        waited = waited + 1
        if n == last then still = still + 1 else last, still = n, 0 end
        if still < SETTLE and waited < SETTLE_MAX then
            Say(("Receiving the listings ... %s"):format(BreakUpLargeNumbers(n)))
            return
        end
        StopWaiting()
        if n == 0 then
            Say("The auction house sent no listings.", 5)
            return
        end
        total, prices, index = n, {}, 0
        reader:SetScript("OnUpdate", ReadSlice)
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
ev:SetScript("OnEvent", function()
    answered = answered + 1
    if not (DeckUIForeverDB and Ours()) then return end   -- someone else's scan
    BeginRead()
end)

-- the window arrives with Blizzard's load-on-demand addon; its OnShow is
-- the moment the auction house is open (a hook, nothing of the frame changed)
EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    AuctionHouseFrame:HookScript("OnShow", function()
        -- a frame later: the window has its place by then
        C_Timer.After(0.1, OnOpen)
    end)
    AuctionHouseFrame:HookScript("OnHide", OnClose)
end)

-- /df ah <item link or ID>: what the scan holds for one item, to check a
-- price against the auction house window (owner 2026-11-24: "das Scannen
-- zeigt völlig falsche Preise"). The kept price, and - while the auction
-- house is open and the scan's list is still in the client - the listings
-- themselves: how many, the cheapest ones as count x per piece = buyout,
-- and the middle one.
function D.AuctionCheck(rest)
    local id = rest and tonumber(rest:match("item:(%d+)") or rest:match("^%s*(%d+)%s*$"))
    if not id then
        print("DeckUIForever auction: /df ah and an item link (shift-click the item) or an item ID.")
        return
    end
    local name = C_Item.GetItemInfo(id) or ("item " .. id)
    local price, age = D.AuctionPrice(id)
    print(("DeckUIForever auction, %s (%d): kept price %s%s"):format(name, id,
        price and GetMoneyString(price) or "none",
        price and (", from " .. SecondsToTime(age) .. " ago") or ""))
    local total = C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems() or 0
    if total == 0 then
        print("  No scan list in the client: scan at the auction house and ask again before closing the window.")
        return
    end
    local list, noBuyout = {}, 0
    for i = 0, total - 1 do
        local _, _, count, _, _, _, _, minBid, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
        if itemID == id then
            if buyout and buyout > 0 and count and count > 0 then
                list[#list + 1] = { count, buyout, buyout / count, minBid or 0 }
            else
                noBuyout = noBuyout + 1
            end
        end
    end
    table.sort(list, function(a, b) return a[3] < b[3] end)
    print(("  %d listings in the scan's list of %d (%d more without a buyout)"):format(#list, total, noBuyout))
    for i = 1, math.min(8, #list) do
        local l = list[i]
        print(("  %d. %d x %s = %s (bid from %s)"):format(i, l[1], GetMoneyString(math.floor(l[3])),
            GetMoneyString(l[2]), GetMoneyString(l[4])))
    end
    if #list > 0 then
        print("  the middle listing: " .. GetMoneyString(math.floor(list[math.ceil(#list / 2)][3])) .. " per piece")
    end
end

-- /df ah: what is stored and when the next scan may run
function D.PrintAuction()
    local store = Stores()[1]
    print(("DeckUIForever auction: scan=%s store=%s items=%d from %s listings, scanned=%s ago, next scan allowed in %ds"):format(
        tostring(DeckUIForeverDB.ahScan), StoreKey(), Count(store and store.prices), tostring(store and store.listings or "?"),
        store and SecondsToTime(time() - store.time) or "never",
        math.max(0, INTERVAL - (time() - (DeckUIForeverDB.ahLastScan or 0)))))
    -- every store of this realm, in the order a price is looked up
    local realm = RealmKey()
    for key, s in pairs(DeckUIForeverDB.ahPrices or {}) do
        if key == realm or key:sub(1, #realm + 1) == realm .. "-" then
            print(("  %s: %d from the last scan (%s ago), %d older kept"):format(key, Count(s.prices),
                SecondsToTime(time() - (s.time or 0)), Count(s.old)))
        end
    end
    print(("  waiting for an answer=%s (asked %s ago), listings in the client=%d, answers this session=%d, reading=%s, style=%s (applied=%s)"):format(
        tostring(requested), requestedAt and (time() - requestedAt .. "s") or "never",
        C_AuctionHouse.GetNumReplicateItems and (C_AuctionHouse.GetNumReplicateItems() or 0) or -1,
        answered, tostring(prices ~= nil), tostring(DeckUIForeverDB.ahStyle), tostring(D.ahStyled or false)))
end
