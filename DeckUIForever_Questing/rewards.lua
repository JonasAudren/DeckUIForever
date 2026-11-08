local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The reward worth taking
-------------------------------------------------------------------
-- When a quest offers a choice, a coin marks the item that sells for the
-- most and a green arrow the one that would be an upgrade: a usable item
-- for a slot you wear, of your class's armour kind (cloth for a priest,
-- mail for a hunter from level 40, plate for a warrior from 40 ...), with
-- a higher item level than what you wear there. The vendor price stands
-- in the button's corner. The marks are frames of ours parented to
-- Blizzard's reward buttons (QuestInfo.lua: rewardsFrame.RewardButtons,
-- the choices first, type "choice", id = choice index); nothing of
-- Blizzard's is written to.
--
-- Item data is not always there when the window opens: a choice whose
-- item is not loaded yet is evaluated when the item arrives
-- (Item:ContinueOnItemLoad), and QUEST_ITEM_UPDATE redraws.
--
-- "Take the most valuable when nothing is an upgrade": then, with every
-- choice evaluated and no arrow, the coin's item is taken - dialog.lua's
-- rules apply (pause key, ignored NPC, hand-in on).
-------------------------------------------------------------------
local COIN  = "Interface\\MoneyFrame\\UI-GoldIcon"
local ARROW_ATLAS = "bags-greenarrow"
local ARROW_FALLBACK = "Interface\\Buttons\\UI-MicroStream-Green"

local marks = {}      -- choice index -> our frame
local pendingAuto     -- the quest id an automatic pick is waiting for

-- equipLoc -> inventory slots
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 },
}

-- Classic's armour kinds: subclass 1 cloth, 2 leather, 3 mail, 4 plate;
-- the kind a class should wear at its level
local function BestArmor(class, level)
    if class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then return 1 end
    if class == "DRUID" or class == "ROGUE" then return 2 end
    if class == "HUNTER" or class == "SHAMAN" then return level >= 40 and 3 or 2 end
    if class == "WARRIOR" or class == "PALADIN" then return level >= 40 and 4 or 3 end
    return 1
end

local function ArmorFits(classID, subclassID)
    if classID ~= 4 then return true end              -- a weapon: isUsable decides
    if subclassID == 0 then return true end            -- rings, trinkets, necks, cloaks
    if subclassID == 6 then                            -- shields
        local class = select(2, UnitClass("player"))
        return class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN"
    end
    return subclassID == BestArmor(select(2, UnitClass("player")), UnitLevel("player"))
end

-- the item level worn in the item's slots; nil for an empty slot
local function WornLevel(equipLoc)
    local slots = SLOTS[equipLoc]
    if not slots then return nil, false end
    local lowest
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        if not link then return nil, true end
        local ilvl = C_Item.GetDetailedItemLevelInfo(link) or 0
        if not lowest or ilvl < lowest then lowest = ilvl end
    end
    return lowest, true
end

-- what a choice is worth: { price, upgrade, loaded }
local function Evaluate(index)
    local link = GetQuestItemLink("choice", index)
    if not link then return { loaded = false } end
    local _, _, numItems, _, isUsable = GetQuestItemInfo("choice", index)
    local name, _, _, _, _, _, _, _, equipLoc, _, sellPrice, classID, subclassID = C_Item.GetItemInfo(link)
    if not name then return { loaded = false, link = link } end
    local ilvl = C_Item.GetDetailedItemLevelInfo(link) or 0
    local price = (sellPrice or 0) * math.max(numItems or 1, 1)
    local upgrade = false
    if isUsable and equipLoc and SLOTS[equipLoc] and ArmorFits(classID, subclassID) then
        local worn, wearable = WornLevel(equipLoc)
        if wearable and (worn == nil or ilvl > worn) then upgrade = true end
    end
    return { loaded = true, link = link, price = price, upgrade = upgrade, ilvl = ilvl }
end

-------------------------------------------------------------------
-- The marks
-------------------------------------------------------------------
local function Mark(button, index)
    local m = marks[index]
    if not m then
        m = CreateFrame("Frame", nil, button)
        m:SetFrameLevel(button:GetFrameLevel() + 5)
        m.coin = m:CreateTexture(nil, "OVERLAY")
        m.coin:SetSize(16, 16)
        m.coin:SetPoint("TOPRIGHT", -2, -2)
        m.coin:SetTexture(COIN)
        m.arrow = m:CreateTexture(nil, "OVERLAY")
        m.arrow:SetSize(16, 16)
        m.arrow:SetPoint("TOPLEFT", 2, -2)
        if not pcall(m.arrow.SetAtlas, m.arrow, ARROW_ATLAS) then m.arrow:SetTexture(ARROW_FALLBACK) end
        m.price = m:CreateFontString(nil, "OVERLAY")
        m.price:SetFont(D.FONT, 10, "OUTLINE")
        m.price:SetPoint("BOTTOMRIGHT", -3, 3)
        marks[index] = m
    end
    m:SetParent(button)
    m:ClearAllPoints()
    m:SetAllPoints(button)
    return m
end

local function HideMarks()
    for _, m in pairs(marks) do m:Hide() end
end

-- Blizzard's buttons for the choices, by choice index
-- the price as coin icons: Forever has the retail namespace, the old
-- global is gone (owner's error of 2026-11-08, rewards.lua:162)
local function CoinText(copper)
    local f = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
    if f then return f(copper) end
    return GetMoneyString and GetMoneyString(copper, true) or (copper .. "c")
end

local function ChoiceButtons()
    local frame = QuestInfoFrame and QuestInfoFrame.rewardsFrame or QuestInfoRewardsFrame
    local list = {}
    for _, b in ipairs(frame and frame.RewardButtons or {}) do
        if b:IsShown() and b.type == "choice" then list[b:GetID()] = b end
    end
    return list
end

local function Draw()
    HideMarks()
    if not ns.db().rewardMarks and not ns.db().rewardAuto then return end
    local choices = GetNumQuestChoices()
    if choices < 2 then return end
    local buttons = ChoiceButtons()
    local values, allLoaded, best, bestPrice, anyUpgrade = {}, true, nil, -1, false
    for i = 1, choices do
        local v = Evaluate(i)
        values[i] = v
        if not v.loaded then
            allLoaded = false
            if v.link then
                local item = Item:CreateFromItemLink(v.link)
                if not item:IsItemEmpty() then item:ContinueOnItemLoad(function() Draw() end) end
            end
        else
            if v.price > bestPrice then best, bestPrice = i, v.price end
            if v.upgrade then anyUpgrade = true end
        end
    end
    if ns.db().rewardMarks then
        for i = 1, choices do
            local b, v = buttons[i], values[i]
            if b and v.loaded then
                local m = Mark(b, i)
                m.coin:SetShown(i == best and bestPrice > 0)
                m.arrow:SetShown(v.upgrade)
                m.price:SetText(v.price > 0 and CoinText(v.price) or "")
                m:Show()
            end
        end
    end
    -- the automatic pick: everything known, nothing an upgrade
    if ns.db().rewardAuto and allLoaded and best and not anyUpgrade and ns.db().autoTurnIn
        and ns.DialogAllowed and ns.DialogAllowed() and pendingAuto == GetQuestID() then
        pendingAuto = nil
        local questID = GetQuestID()
        C_Timer.After(0.2, function()
            if QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() and GetQuestID() == questID then
                GetQuestReward(best)
                ns.Say(("handed in %s, took %s (the most valuable)."):format(
                    C_QuestLog.GetTitleForQuestID(questID) or "the quest", values[best].link or "the reward"))
            end
        end)
    end
end

function ns.InitRewards()
    ns.On("QUEST_COMPLETE", function()
        pendingAuto = GetQuestID()
        -- Blizzard lays the buttons out in this same event; our marks a frame later
        C_Timer.After(0, Draw)
    end)
    ns.On("QUEST_ITEM_UPDATE", function()
        if QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() then C_Timer.After(0, Draw) end
    end)
    ns.On("QUEST_FINISHED", function()
        pendingAuto = nil
        HideMarks()
    end)
end
