local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The bank window: character bank and warband bank
-------------------------------------------------------------------
-- Since 11.2 the bank is one BankFrame with two bank types, and its slots
-- are ordinary bag IDs: CharacterBankTab_1..6 (6-11) and
-- AccountBankTab_1..5 (12-16). The old Bank (-1), BankBag_1..7 and the
-- reagent bank are gone. Read in Blizzard's 12.1.0 source, 2026-09-29.
--
-- Blizzard's BankFrame cannot simply be replaced: it is a UI panel the
-- game shows and hides, so it is parked like the bag frames - shown, under
-- a hidden parent.
--
-- A right click on a bag item at the bank: Blizzard's click handler calls
-- UseContainerItem(bag, slot, nil, BankFrame:GetActiveBankType(), ...)
-- (Mainline/ContainerFrame.lua:1611), and GetActiveBankType is
-- "BankPanel:IsShown() and BankPanel.bankType". Until 1.4.1 we showed the
-- panel and wrote the bank type we display into BankPanel.bankType (what
-- Inventorian does). A field written by an addon is tainted, the click
-- read it, and the protected UseContainerItem was refused: "DeckUIForever_
-- Bags tried to call UseContainerItem()" (owner 2026-11-11). Nothing of
-- ours can write that field cleanly, so now nothing writes it: the panel
-- stays hidden, GetActiveBankType is a clean nil, and the deposit is ours
-- (ns.BankDeposit below, from the item button's PreClick): the item is
-- picked up and put into the bank we show, before Blizzard's handler runs.
--
-- The window shows one bank tab at a time, like Blizzard's: a tab holds
-- 98 slots, and six of them in one grid would be 2000 pixels tall.
--
-- Forever keeps retail's API over a Classic bank (probe 2026-11-05:
-- C_Bank.ShouldUsePlayerBagsInBank() is true; Blizzard_UIPanels_Game/
-- Camelot/BankFrame.lua): a "tab" is a bank bag slot the player buys and
-- then puts a bag into, nine for the character (bags 6-14, the first one
-- free and the bank's own slots), six for the account (15-20). The bag
-- items live in two pseudo containers, Enum.BagIndex.Characterbanktab (-2)
-- and Accountbanktab (-3), slot n for tab n - that is what Blizzard's own
-- BankItemButtonBagMixin picks up with C_Container.PickupContainerItem. So
-- here a tab icon is that slot: it shows the bag, takes a dropped bag, and
-- its tooltip is the bag's. An unbought slot is not listed by
-- FetchPurchasedBankTabData; the "Buy tab" button buys the next one.
-- Not yet tested in game.
-------------------------------------------------------------------
local CHARACTER = Enum.BankType.Character
local ACCOUNT   = Enum.BankType.Account
local TYPES     = { CHARACTER, ACCOUNT }
local TYPE_NAMES = {
    [CHARACTER] = BANK or "Bank",
    [ACCOUNT]   = ACCOUNT_BANK_PANEL_TITLE or "Warband Bank",
}

local BANKER_INTERACTIONS = {
    [Enum.PlayerInteractionType.Banker]          = true,
    [Enum.PlayerInteractionType.CharacterBanker] = true,
    [Enum.PlayerInteractionType.AccountBanker]   = true,
}

local TAB_SIZE = 30

-- the bag slots behind the tabs (see the note on top), when the client
-- keeps bags in its bank
local playerBags = C_Bank.ShouldUsePlayerBagsInBank and C_Bank.ShouldUsePlayerBagsInBank()
local BAG_SLOTS = {
    [CHARACTER] = { pseudo = Enum.BagIndex.Characterbanktab, first = Enum.BagIndex.CharacterBankTab_1 },
    [ACCOUNT]   = { pseudo = Enum.BagIndex.Accountbanktab,   first = Enum.BagIndex.AccountBankTab_1 },
}

-- the pseudo container and slot of a tab's bag, or nil where tabs are not bags
local function BagSlotOf(bankType, tabID)
    local s = playerBags and tabID and BAG_SLOTS[bankType]
    if not (s and s.pseudo and s.first) then return nil end
    return s.pseudo, tabID - s.first + 1
end

local atBank     = false
local activeType = CHARACTER
local selected   = {}   -- [bankType] -> bank tab bag ID

local window = ns.NewWindow("DeckBankWindow", TYPE_NAMES[CHARACTER], {
    extraHeader = TAB_SIZE + 8,
    extraFooter = 30,
    minWidth    = 500,   -- the footer row: deposit, reagents, two gold buttons
    -- the warband bank keeps gold of its own; the character bank has none
    money = function()
        if activeType == ACCOUNT then return C_Bank.FetchDepositedMoney(ACCOUNT) end
        return GetMoney()
    end,
})
window.defaultPoint = { "TOPLEFT", UIParent, "TOPLEFT", 40, -120 }
window:SetPoint(unpack(window.defaultPoint))
window.title:Hide()   -- the bank type buttons say which bank this is
tinsert(UISpecialFrames, "DeckBankWindow")
ns.bank = window

-------------------------------------------------------------------
-- Tabs of the active bank type
-------------------------------------------------------------------
local function TabData(bankType)
    return C_Bank.FetchPurchasedBankTabData(bankType) or {}
end

local function SelectedTab(bankType)
    local tabs = TabData(bankType)
    for _, tab in ipairs(tabs) do
        if tab.ID == selected[bankType] then return tab end
    end
    selected[bankType] = tabs[1] and tabs[1].ID
    return tabs[1]
end

local function Locked(bankType)
    return C_Bank.FetchBankLockedReason(bankType) ~= nil
end

function window.Layout()
    local d = ns.DeviceDB()
    local tab = not Locked(activeType) and SelectedTab(activeType)
    local sections = {}
    if tab then
        sections[1] = { title = tab.name, bags = { tab.ID } }
    end
    return sections, d.bankColumns, d.scale
end

-------------------------------------------------------------------
-- Title row: which bank
-------------------------------------------------------------------
local typeButtons = {}
local SetType

for i, bankType in ipairs(TYPES) do
    local b = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    b:SetSize(140, 22)
    b:SetText(TYPE_NAMES[bankType])
    b:GetFontString():SetFont(D.FONT, 13, "OUTLINE")
    b:SetPoint("TOPLEFT", 12 + (i - 1) * 144, -8)
    b:SetScript("OnClick", function() SetType(bankType) end)
    typeButtons[bankType] = b
end

-------------------------------------------------------------------
-- Tab row: one icon per bought tab
-------------------------------------------------------------------
local tabButtons = {}

local function TabButton(i)
    local b = tabButtons[i]
    if b then return b end
    b = CreateFrame("Button", nil, window)
    b:SetSize(TAB_SIZE, TAB_SIZE)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * (TAB_SIZE + 6), -62)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- a bag on the cursor goes into the slot (or swaps with the bag there),
    -- the way Blizzard's bank bag button does it; otherwise the tab is picked
    local function Drop(self)
        local pseudo, slot = BagSlotOf(activeType, self.tabID)
        if pseudo and GetCursorInfo() == "item" then
            C_Container.PickupContainerItem(pseudo, slot)
            return true
        end
    end
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnReceiveDrag", Drop)
    b:SetScript("OnClick", function(self)
        if Drop(self) then return end
        selected[activeType] = self.tabID
        window.needLayout = true
        ns.RefreshBankChrome()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local pseudo, slot = BagSlotOf(activeType, self.tabID)
        -- the bag's own tooltip where a bag sits in the slot
        if not (pseudo and GameTooltip:SetBagItem(pseudo, slot)) then
            GameTooltip:SetText(self.tabName or "")
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    tabButtons[i] = b
    return b
end

-------------------------------------------------------------------
-- Footer row: deposit everything, buy a tab, move gold
-------------------------------------------------------------------
local ACTION_Y = 34

local deposit = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
deposit:SetSize(170, 22)
deposit:SetPoint("BOTTOMLEFT", 12, ACTION_Y)

-- Blizzard warns before refundable items go into the warband bank, where
-- they stop being refundable. Same check as BankPanelItemDepositButtonMixin.
local function HasRefundable()
    return ItemUtil.IteratePlayerInventory(function(itemLocation)
        return C_Bank.IsItemAllowedInBankType(ACCOUNT, itemLocation) and C_Item.CanBeRefunded(itemLocation)
    end)
end

deposit:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    if activeType == ACCOUNT and HasRefundable() then
        -- Blizzard's own question, in DeckUIForever's dialog (see MoneyDialog)
        D.Dialog({
            text = ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM or "Some items are still refundable. Deposit anyway?",
            onAccept = function() C_Bank.AutoDepositItemsIntoBank(ACCOUNT) end,
        })
    else
        C_Bank.AutoDepositItemsIntoBank(activeType)
    end
end)

-- The warband bank's "include reagents" choice is a CVar Blizzard's own
-- checkbox writes, so ours reads and writes the same one.
local reagents = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
reagents:SetSize(24, 24)
reagents:SetPoint("LEFT", deposit, "RIGHT", 6, 0)
reagents.text = reagents:CreateFontString(nil, "OVERLAY")
reagents.text:SetFont(D.FONT, 12, "OUTLINE")
reagents.text:SetPoint("LEFT", reagents, "RIGHT", 2, 0)
reagents.text:SetText("Include reagents")
reagents:SetScript("OnClick", function(self)
    SetCVar("bankAutoDepositReagents", self:GetChecked() and "1" or "0")
end)

-- Buying a tab goes through Blizzard's script-only template, which exists
-- for exactly this: an addon button that opens the purchase dialog without
-- tainting it. It wants the bank type as an attribute. It sits at the end
-- of the tab row, where the next tab would appear.
local purchase = CreateFrame("Button", nil, window,
    "BankPanelPurchaseButtonScriptTemplate, UIPanelButtonTemplate")
purchase:SetSize(120, 22)
purchase:SetText(BANKSLOTPURCHASE or "Buy tab")

local withdraw = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
withdraw:SetSize(90, 22)
withdraw:SetPoint("BOTTOMRIGHT", -12, ACTION_Y)
withdraw:SetText(BANK_WITHDRAW_MONEY_BUTTON_LABEL or "Withdraw")

local depositMoney = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
depositMoney:SetSize(90, 22)
depositMoney:SetPoint("RIGHT", withdraw, "LEFT", -4, 0)
depositMoney:SetText(BANK_DEPOSIT_MONEY_BUTTON_LABEL or "Deposit")

-- Blizzard's texts and C_Bank calls, in DeckUIForever's own dialog (widgets.lua):
-- BANK_MONEY_DEPOSIT / _WITHDRAW are StaticPopups, and showing one from
-- our code would leave the shared dialog frame tainted for whatever
-- Blizzard shows on it next. A second click on the same button closes it.
local function MoneyDialog(key, text, move)
    return function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        if D.DialogShown(key) then
            D.HideDialog(key)
            return
        end
        local bankType = activeType
        D.Dialog({
            key = key,
            text = text,
            money = true,
            onAccept = function(copper)
                if copper and copper > 0 then move(bankType, copper) end
            end,
        })
    end
end

-- a question about one bank type goes when the type or the window does
function ns.HideBankDialogs()
    for _, key in ipairs({ "BANK_MONEY_DEPOSIT", "BANK_MONEY_WITHDRAW", "BANK_SORT" }) do
        D.HideDialog(key)
    end
end
withdraw:SetScript("OnClick", MoneyDialog("BANK_MONEY_WITHDRAW",
    BANK_MONEY_WITHDRAW_PROMPT or "Amount to withdraw", C_Bank.WithdrawMoney))
depositMoney:SetScript("OnClick", MoneyDialog("BANK_MONEY_DEPOSIT",
    BANK_MONEY_DEPOSIT_PROMPT or "Amount to deposit", C_Bank.DepositMoney))

-- shown instead of the grid while a bank type is locked
local lockedText = window:CreateFontString(nil, "OVERLAY")
lockedText:SetFont(D.FONT, 13, "OUTLINE")
lockedText:SetPoint("TOPLEFT", 20, -110)
lockedText:SetPoint("RIGHT", -20, 0)
lockedText:SetJustifyH("LEFT")
lockedText:SetTextColor(1, 0.4, 0.4)

local LOCKED_TEXT = {
    [Enum.BankLockedReason.BankConversionFailed]   = BANK_LOCKED_REASON_BANK_CONVERSION_FAILED,
    [Enum.BankLockedReason.BankDisabled]           = BANK_LOCKED_REASON_BANK_DISABLED,
    [Enum.BankLockedReason.NoAccountInventoryLock] = BANK_LOCKED_REASON_NO_ACCOUNT_INVENTORY_LOCK,
}

-------------------------------------------------------------------
-- Everything around the grid that depends on bank type and tabs
-------------------------------------------------------------------
function ns.RefreshBankChrome()
    for bankType, b in pairs(typeButtons) do
        b:SetShown(C_Bank.CanViewBank(bankType))
        b:SetEnabled(bankType ~= activeType)
    end

    local locked = Locked(activeType)
    local reason = C_Bank.FetchBankLockedReason(activeType)
    lockedText:SetText(locked and (LOCKED_TEXT[reason] or "This bank is locked.") or "")

    local tabs = locked and {} or TabData(activeType)
    SelectedTab(activeType)
    for i, tab in ipairs(tabs) do
        local b = TabButton(i)
        b.tabID, b.tabName = tab.ID, tab.name
        local icon = tab.icon
        -- a bank bag slot shows its bag; the first character slot is the
        -- bank's own, with no bag to show
        local pseudo, slot = BagSlotOf(activeType, tab.ID)
        if pseudo then
            local bag = C_Container.GetContainerItemInfo(pseudo, slot)
            icon = bag and bag.iconFileID or (slot == 1 and 413587) or icon   -- 413587: a bank chest
            if not (b.tabName and b.tabName ~= "") then
                b.tabName = slot == 1 and (BANK or "Bank") or ("Bank bag slot %d"):format(slot)
            end
        end
        b.icon:SetTexture(icon or 134400)   -- 134400: the question mark icon
        -- the chosen tab in full colour, the others greyed, like the spec bar
        local isSelected = tab.ID == selected[activeType]
        b.icon:SetDesaturated(not isSelected)
        b:SetAlpha(isSelected and 1 or 0.6)
        b:Show()
    end
    for i = #tabs + 1, #tabButtons do tabButtons[i]:Hide() end

    deposit:SetText(activeType == ACCOUNT and ACCOUNT_BANK_DEPOSIT_BUTTON_LABEL
        or CHARACTER_BANK_DEPOSIT_BUTTON_LABEL or "Deposit all")
    deposit:SetEnabled(not locked and C_Bank.DoesBankTypeSupportAutoDeposit(activeType))
    reagents:SetShown(activeType == ACCOUNT and not locked)
    reagents:SetChecked(GetCVarBool("bankAutoDepositReagents"))

    local canBuy = not locked and C_Bank.CanPurchaseBankTab(activeType)
    purchase:ClearAllPoints()
    purchase:SetPoint("LEFT", window, "TOPLEFT", 16 + #tabs * (TAB_SIZE + 6), -62 - TAB_SIZE / 2)
    purchase:SetShown(canBuy)

    local money = not locked and C_Bank.DoesBankTypeSupportMoneyTransfer(activeType)
    withdraw:SetShown(money)
    depositMoney:SetShown(money)
    withdraw:SetEnabled(money and C_Bank.CanWithdrawMoney(activeType))
    depositMoney:SetEnabled(money and C_Bank.CanDepositMoney(activeType))
end

window.OnRefresh = ns.RefreshBankChrome

SetType = function(bankType)
    activeType = bankType
    -- BankPanel.bankType is never written: see the note on top
    if not InCombatLockdown() then
        purchase:SetAttribute("overrideBankType", bankType)
    end
    ns.HideBankDialogs()
    window.needLayout = true
    ns.RefreshBankChrome()
end

-------------------------------------------------------------------
-- Sorting, with Blizzard's confirmation when the player keeps it on
-------------------------------------------------------------------
window.sort:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
    if C_Bank.FetchNumPurchasedBankTabs(activeType) == 0 then return end
    if GetCVarBool("bankConfirmTabCleanUp") then
        local bankType = activeType
        D.Dialog({
            key = "BANK_SORT",
            text = BANK_CONFIRM_CLEANUP_PROMPT or "Sort the bank?",
            onAccept = function() C_Container.SortBank(bankType) end,
        })
    else
        C_Container.SortBank(activeType)
    end
end)
window.sort:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(activeType == ACCOUNT and BAG_CLEANUP_ACCOUNT_BANK or BAG_CLEANUP_BANK or "Clean up bank")
    GameTooltip:Show()
end)

-------------------------------------------------------------------
-- Opening and closing with the banker
-------------------------------------------------------------------
local hider = CreateFrame("Frame", "DeckBankBlizzardHider", UIParent)
hider:SetAllPoints()
hider:Hide()

-- Parked: shown when the game says so, never drawn. It stays a UI panel:
-- the first version took it out of the panel manager by writing
-- "UIPanelLayout-defined" and clearing "UIPanelLayout-area", and an
-- attribute written by addon code is tainted - ShowUIPanel reads it at
-- every visit to the banker, so the whole opening ran tainted. The same
-- trick on the world map tainted GameTooltip's widget container for the
-- session (2026-10-01, see DeckUIForever_Map/worldmap.lua). The price: while at
-- the bank the invisible frame holds the left panel slot, so the character
-- window and friends open one slot further right.
--
-- It needs a place before the panel manager gives it one: whenever a bag
-- opens while the bank counts as shown, Blizzard's GetContainerScale reads
-- BankFrame:GetRight() to keep the bags clear of it, and a frame never
-- placed has no right edge - "attempt to perform arithmetic on a nil
-- value" in ContainerFrame.lua (reported 2026-09-29). Our OpenBank may run
-- before Blizzard's own handler for the same event, so it is parked with
-- its right edge on the screen's left edge until then.
local function ParkBankFrame()
    if BankFrame:GetParent() == hider then return end
    BankFrame:SetParent(hider)
    BankFrame:ClearAllPoints()
    BankFrame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", 0, 0)
end

local function FirstViewable(preferred)
    if preferred and C_Bank.CanViewBank(preferred) then return preferred end
    for _, bankType in ipairs(TYPES) do
        if C_Bank.CanViewBank(bankType) then return bankType end
    end
    return CHARACTER
end

local function OpenBank(interaction)
    atBank = true
    -- Blizzard's OnShow never runs under the hidden parent, so what it
    -- would do is done here: open the bags. The panel stays hidden (the
    -- note on top).
    BankFrame.BankPanel:Hide()
    local prefer = interaction == Enum.PlayerInteractionType.AccountBanker and ACCOUNT or activeType
    SetType(FirstViewable(prefer))
    window:Show()
    ns.Flush(window)
    OpenAllBags(BankFrame)
end

local function CloseBank()
    atBank = false
    window:Hide()
    BankFrame.BankPanel:Hide()
    -- The bag-cost money display (BankPanel.MoneyDisplay) was seen
    -- listening to PLAYER_MONEY with the panel hidden (1.4.0, 2026-11-09):
    -- its Refresh read a bank type we had written, passed its guard and
    -- handed Blizzard's own code a nil (Camelot/BankFrame.lua:43). The
    -- type is no longer written at all (the note on top), so the guard
    -- holds; the listener is still dropped in case the hidden parent
    -- swallowed its OnHide.
    local money = BankFrame.BankPanel.MoneyDisplay
    if money then money:UnregisterEvent("PLAYER_MONEY") end
    CloseAllBags(BankFrame)
end

-- A right click on a bag item at the bank puts it into the bank we show
-- (the note on top has the why). Called from every item button's PreClick
-- (core.lua): our own code, so only what an addon may do - pick the item
-- up and put it down. Onto a stack of the same item with room for all of
-- it, else into the first free slot, the tab on show first. Blizzard's
-- click handler runs after this and finds the slot locked or empty.
-- Nothing happens with a modifier held (those clicks are Blizzard's:
-- split, link, compare), with something on the cursor, at a merchant, or
-- when the bank is full - then the click is Blizzard's alone, as before.
local function BankPlace(bankType, itemID, amount)
    local tabs, first = {}, SelectedTab(bankType)
    if first then tabs[1] = first.ID end
    for _, tab in ipairs(TabData(bankType)) do
        if not first or tab.ID ~= first.ID then tabs[#tabs + 1] = tab.ID end
    end
    local max = C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(itemID) or 1
    local freeBag, freeSlot
    for _, bag in ipairs(tabs) do
        for slot = 1, ns.NumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if not info then
                if not freeBag then freeBag, freeSlot = bag, slot end
            elseif max > 1 and info.itemID == itemID and not info.isLocked
                and (info.stackCount or 1) + amount <= max then
                return bag, slot
            end
        end
    end
    return freeBag, freeSlot
end

function ns.BankDeposit(button, mouse)
    if not atBank or mouse ~= "RightButton" or IsModifiedClick() then return end
    if GetCursorInfo() or (MerchantFrame and MerchantFrame:IsShown()) then return end
    local bag, slot = button:GetBagID(), button:GetID()
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    if not bag or bag < 0 or bag > last then return end   -- your bags only: a bank item's click withdraws
    if Locked(activeType) or not C_Bank.CanUseBank(activeType) then return end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or info.isLocked or not info.itemID then return end
    local toBag, toSlot = BankPlace(activeType, info.itemID, info.stackCount or 1)
    if not toBag then return end
    C_Container.PickupContainerItem(bag, slot)
    C_Container.PickupContainerItem(toBag, toSlot)
    if GetCursorInfo() then ClearCursor() end   -- the bank did not take it: back where it was
end

-- Closing our window (X, Escape) ends the conversation with the banker;
-- the game answers with the interaction's HIDE event, which cleans up.
window:SetScript("OnHide", function(self)
    self.search:ClearFocus()
    ns.HideBankDialogs()
    if atBank then C_Bank.CloseBankFrame() end
end)

-- the D-pad on the Steam Deck (hub, gamepad.lua); the parked BankFrame is
-- still a UI panel and would be an empty second stop for LT and RT
if D.GamepadWindow then
    D.GamepadWindow(window, { close = window.close, evict = { BankFrame } })
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
ev:SetScript("OnEvent", function(_, event, interaction)
    if not BANKER_INTERACTIONS[interaction] then return end
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        OpenBank(interaction)
    else
        CloseBank()
    end
end)

function ns.InitBank()
    ParkBankFrame()
    BankFrame.BankPanel:Hide()   -- hidden for good: GetActiveBankType then never reads a field
    D.MakeMovable(window, "Bank", DeckUIForeverBagsDB)
    D.MakeDraggable(window)
end

-- /bags bank: what the bank window is built from
function ns.PrintBank()
    print(("DeckUIForever Bags bank: at bank=%s, active=%s, Blizzard says %s, BankFrame parked=%s shown=%s"):format(
        tostring(atBank), TYPE_NAMES[activeType] or tostring(activeType),
        tostring(BankFrame:GetActiveBankType()), tostring(BankFrame:GetParent() == hider),
        tostring(BankFrame:IsShown())))
    -- nil here is the ContainerFrame.lua:1167 error waiting to happen
    print(('  BankFrame right edge: %s'):format(tostring(BankFrame:GetRight())))
    local money = BankFrame.BankPanel.MoneyDisplay
    print(("  BankPanel shown=%s bankType=%s, money display listens to PLAYER_MONEY=%s"):format(
        tostring(BankFrame.BankPanel:IsShown()), tostring(BankFrame.BankPanel.bankType),
        tostring(money and money:IsEventRegistered("PLAYER_MONEY"))))
    for _, bankType in ipairs(TYPES) do
        local reason = C_Bank.FetchBankLockedReason(bankType)
        print(("  %s: view=%s use=%s locked=%s tabs=%d"):format(TYPE_NAMES[bankType],
            tostring(C_Bank.CanViewBank(bankType)), tostring(C_Bank.CanUseBank(bankType)),
            tostring(reason), #TabData(bankType)))
        for _, tab in ipairs(TabData(bankType)) do
            print(("    tab %d %s: %d slots, %d free"):format(tab.ID, tab.name or "?",
                C_Container.GetContainerNumSlots(tab.ID), C_Container.GetContainerNumFreeSlots(tab.ID) or 0))
        end
    end
end
