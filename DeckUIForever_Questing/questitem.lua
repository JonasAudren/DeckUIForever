local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The quest item key
-------------------------------------------------------------------
-- One secure button with the quest item that matters now: the item of
-- the navigation target, else the nearest tracked quest's, else the
-- nearest quest's in the log (GetQuestLogSpecialItemInfo, as the
-- tracker's buttons). The key "Quest item: use it" in Keybindings >
-- AddOns > DeckUIForever clicks it (a CLICK binding on the frame's name,
-- DeckQuestingItem; the hub's Bindings.xml declares it, so the key is
-- there before this module loads). The button shows the icon, the
-- count, the cooldown and the key; it hides when no quest has an item.
--
-- Secure: the item attribute changes out of combat only; in a fight the
-- button keeps the item it had, and catches up when the fight ends.
-- Movable "Quest item" (/df unlock), size per device.
-------------------------------------------------------------------
local SIZE = 36

local button = CreateFrame("Button", "DeckQuestingItem", UIParent, "SecureActionButtonTemplate")
button:SetSize(SIZE, SIZE)
button:SetFrameStrata("MEDIUM")
button:RegisterForClicks("AnyUp", "AnyDown")
button:SetAttribute("type", "item")
button.defaultPoint = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -320, 140 }
button:SetPoint(unpack(button.defaultPoint))
button:Hide()

button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetPoint("TOPLEFT", 2, -2)
button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
D.FlatBox(button, 0.6, 0.35)

button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
button.cooldown:SetAllPoints(button.icon)
button.cooldown:SetDrawEdge(false)

button.count = button:CreateFontString(nil, "OVERLAY")
button.count:SetFont(D.FONT, 12, "OUTLINE")
button.count:SetPoint("BOTTOMRIGHT", -3, 3)

button.key = button:CreateFontString(nil, "OVERLAY")
button.key:SetFont(D.FONT, 10, "OUTLINE")
button.key:SetPoint("TOPLEFT", 2, -2)
button.key:SetTextColor(0.9, 0.9, 0.9)

button:SetScript("OnEnter", function(self)
    if self.logIndex then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetQuestLogSpecialItem(self.logIndex)
        GameTooltip:Show()
    end
end)
button:SetScript("OnLeave", GameTooltip_Hide)

local current   -- { link, icon, logIndex, questID }
local pending = false

-------------------------------------------------------------------
-- Which item
-------------------------------------------------------------------
local function ItemOf(questID)
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex then return nil end
    local link, icon, _, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
    if not link then return nil end
    if C_QuestLog.IsComplete(questID) and not showWhenComplete then return nil end
    return { link = link, icon = icon, logIndex = logIndex, questID = questID }
end

local function Distance(questID)
    local distSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
    if onContinent and distSq and ns.Plain(distSq) then return distSq end
    return math.huge
end

local function Pick()
    local super = C_SuperTrack.GetSuperTrackedQuestID()
    if super and super > 0 then
        local item = ItemOf(super)
        if item then return item end
    end
    local best, bestDist
    -- tracked quests first, then the whole log
    local function Consider(questID, bonus)
        local item = ItemOf(questID)
        if item then
            local dist = Distance(questID) - (bonus or 0)
            if not best or dist < bestDist then best, bestDist = item, dist end
        end
    end
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if id then Consider(id, 1e12) end
    end
    if best then return best end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then Consider(info.questID) end
    end
    return best
end

-------------------------------------------------------------------
-- Showing
-------------------------------------------------------------------
local function KeyText()
    local key = GetBindingKey("CLICK DeckQuestingItem:LeftButton")
    if not key then return "" end
    key = key:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("BUTTON", "M")
    return key
end

local function Cooldown()
    if not current then return end
    local start, duration, enable = GetQuestLogSpecialItemCooldown(current.logIndex)
    if start and duration and ns.Plain(start, duration) and duration > 0 and enable ~= 0 then
        button.cooldown:SetCooldown(start, duration)
    else
        button.cooldown:Clear()
    end
    local count = C_Item.GetItemCount(current.link)
    button.count:SetText(count and count > 1 and tostring(count) or "")
end

local function Apply()
    if InCombatLockdown() then pending = true return end
    pending = false
    local d = ns.db()
    current = d.questItem and Pick() or nil
    if current then
        button:SetAttribute("item", current.link)
        button.icon:SetTexture(current.icon)
        button.logIndex = current.logIndex
        button.key:SetText(KeyText())
        button:Show()
        Cooldown()
    else
        button.logIndex = nil
        button.cooldown:Clear()
        button.count:SetText("")
        -- unlocked, the button stays to be moved
        if D.IsUnlocked and D.IsUnlocked("Quest item") then
            button.icon:SetTexture(134400)   -- the question mark
            button.key:SetText(KeyText())
            button:Show()
        else
            button:Hide()
        end
    end
end
ns.ApplyQuestItem = Apply

local timer
local function Soon()
    if timer then return end
    timer = C_Timer.NewTimer(0.2, function()
        timer = nil
        Apply()
    end)
end

function ns.ItemDebug()
    local item = Pick()
    print(("  quest item: %s%s, key %s, shown %s"):format(item and item.link or "none",
        item and (" (quest " .. item.questID .. ")") or "", KeyText() ~= "" and KeyText() or "none", tostring(button:IsShown())))
end

function ns.InitQuestItem()
    D.MakeMovable(button, "Quest item", DeckUIForeverQuestingDB)
    local function Scale() button:SetScale(ns.DeviceDB().itemScale or 1) end
    Scale()
    ns.ApplyQuestItemScale = Scale
    if D.OnUnlock then D.OnUnlock(function() Soon() end) end
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "QUEST_ACCEPTED",
                         "QUEST_REMOVED", "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "BAG_UPDATE_DELAYED",
                         "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS" }) do
        ns.On(e, Soon)
    end
    ns.On("BAG_UPDATE_COOLDOWN", Cooldown)
    ns.On("PLAYER_REGEN_ENABLED", function() if pending then Apply() end end)
    Soon()
end
