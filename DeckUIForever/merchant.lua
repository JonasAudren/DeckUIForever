local D = DeckUIForever

-------------------------------------------------------------------
-- At the merchant: sell the junk, repair the gear
-------------------------------------------------------------------
-- Asked for by the owner (2026-10-01), as the first of the small comforts
-- every player wants. In the hub, so it works without the Bags module.
-- Both off by default: selling and paying on their own is nothing an
-- update should start doing unasked.
--
-- Only C APIs and Blizzard's legacy globals, called from our own event
-- handler - nothing of the MerchantFrame is touched or shown. Blizzard's
-- own "sell all junk" button asks first through a StaticPopup; we skip
-- the question (the player switched this on) and so never touch the
-- shared dialog frames (see D.Dialog in widgets.lua).
--
-- Repair comes first, while the gold is all there; guild funds first when
-- allowed and the player wants it. Then the junk goes - what Blizzard
-- counts as junk (C_MerchantFrame.GetNumJunkItems), so its rules decide,
-- and the buyback tab still holds the last twelve items.
-------------------------------------------------------------------
-- true when the gold was short, so a second try after the junk sale may work
local function Repair(quiet)
    if not (DeckUIForeverDB.autoRepair and CanMerchantRepair()) then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    if DeckUIForeverDB.repairGuild and IsInGuild() and CanGuildBankRepair() then
        local allowance = GetGuildBankWithdrawMoney()
        local guildMoney = GetGuildBankMoney()
        -- -1 is "no limit" (the guild master)
        if (allowance == -1 or allowance >= cost) and guildMoney >= cost then
            RepairAllItems(true)
            print("DeckUIForever: repaired for " .. GetMoneyString(cost, true) .. " from the guild bank.")
            return
        end
    end
    if GetMoney() >= cost then
        RepairAllItems(false)
        print("DeckUIForever: repaired for " .. GetMoneyString(cost, true) .. ".")
    else
        if not quiet then
            print("DeckUIForever: not enough gold to repair (" .. GetMoneyString(cost, true) .. ").")
        end
        return true
    end
end

-- Mists has no C_MerchantFrame.SellAllJunkItems: grey items are sold one
-- by one with a right click's call, as the bag buttons do at a merchant.
-- Twelve at most - the buyback tab's size, so each can still be bought back.
-- Items without a sell price (quest leftovers) stay.
local BUYBACK = 12
local function SellJunkFromBags()
    local sold = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue and not info.isLocked then
                C_Container.UseContainerItem(bag, slot)
                sold = sold + 1
                if sold >= BUYBACK then return sold end
            end
        end
    end
    return sold
end

-------------------------------------------------------------------
-- The guard: junk the auction house pays more for stays (2026-11-23)
-------------------------------------------------------------------
-- Owner's pick from the uses of the auction scan. A grey item whose price
-- per piece in the last scan (D.AuctionPrice, auction.lua) is at least
-- GUARD times the merchant's is not sold by itself. Blizzard's
-- SellAllJunkItems takes no exceptions, so while such an item is in the
-- bags the others are sold one by one - picked up and dropped on the
-- merchant (PickupMerchantItem(0) sells what the cursor holds), since
-- UseContainerItem is protected in Forever. If the game refuses that too,
-- the item is still on the cursor: it is put back and nothing is sold this
-- visit; the chat says so either way.
local GUARD = 2

local function Junk()
    local sell, keep = {}, {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue and not info.isLocked then
                local price = D.AuctionPrice and D.AuctionPrice(info.itemID)
                local vendor = price and select(11, C_Item.GetItemInfo(info.itemID))
                local entry = { bag = bag, slot = slot, link = info.hyperlink, count = info.stackCount or 1, price = price }
                if price and (type(vendor) ~= "number" or price >= GUARD * vendor) then
                    keep[#keep + 1] = entry
                else
                    sell[#sell + 1] = entry
                end
            end
        end
    end
    return sell, keep
end

-- true when something was sold
local function SellAround(sell, keep)
    local sold, refused = 0, false
    for _, e in ipairs(sell) do
        if sold >= BUYBACK then break end
        if GetCursorInfo() then ClearCursor() end
        C_Container.PickupContainerItem(e.bag, e.slot)
        if GetCursorInfo() then PickupMerchantItem(0) end
        if GetCursorInfo() then
            ClearCursor()
            refused = true
            break
        end
        sold = sold + 1
    end
    local names = {}
    for i, e in ipairs(keep) do
        if i > 4 then names[#names + 1] = ("and %d more"):format(#keep - 4) break end
        names[#names + 1] = ("%s (AH %s)"):format(e.link or "?", GetMoneyString(e.price * e.count, true))
    end
    print(("DeckUIForever: kept %d junk item%s the auction house pays more for: %s."):format(
        #keep, #keep == 1 and "" or "s", table.concat(names, ", ")))
    if refused then
        print("DeckUIForever: the game did not let the rest be sold one by one - sell it by hand this time.")
    elseif sold > 0 then
        print(("DeckUIForever: sold %d junk item%s%s."):format(sold, sold == 1 and "" or "s",
            #sell > sold and (", %d more at the next visit"):format(#sell - sold) or ""))
    end
    return sold > 0
end

local function SellJunk()
    if not DeckUIForeverDB.autoSellJunk then return end
    if DeckUIForeverDB.junkGuard then
        local sell, keep = Junk()
        if #keep > 0 then return SellAround(sell, keep) end
    end
    if not C_MerchantFrame.SellAllJunkItems then
        local count = SellJunkFromBags()
        if count == 0 then return end
        print(("DeckUIForever: sold %d junk item%s."):format(count, count == 1 and "" or "s"))
        return true
    end
    if not C_MerchantFrame.IsSellAllJunkEnabled() then return end
    local count = C_MerchantFrame.GetNumJunkItems()
    if count <= 0 then return end
    C_MerchantFrame.SellAllJunkItems()
    print(("DeckUIForever: sold %d junk item%s."):format(count, count == 1 and "" or "s"))
    return true
end

local atMerchant = false

local ev = CreateFrame("Frame")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
ev:SetScript("OnEvent", function(_, event)
    atMerchant = event == "MERCHANT_SHOW"
    if not atMerchant or not DeckUIForeverDB then return end
    local short = Repair(true)
    if SellJunk() and short then
        -- the sale's gold arrives a moment later
        C_Timer.After(1, function()
            if atMerchant then Repair() end
        end)
    elseif short then
        Repair()
    end
end)
