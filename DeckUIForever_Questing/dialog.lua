local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The NPC dialog on autopilot
-------------------------------------------------------------------
-- Blizzard's QuestFrame and GossipFrame keep running; this file only
-- listens to the same events and calls the quest API they would call on
-- a click (read in the forever branch of Gethe/wow-ui-source,
-- Blizzard_UIPanels_Game/Mainline/QuestFrame.lua and GossipFrame.lua,
-- 2026-11-07; Camelot loads retail's frames). Nothing of Blizzard's is
-- hooked or clicked, so the frames stay clean and the gamepad style's
-- own prompts (A accepts, A completes) are untouched - they simply find
-- the quest already taken.
--
-- GOSSIP_SHOW and QUEST_GREETING: finished quests first (hand in), then
-- one quest to take, then - with no quests at all and a single plain
-- "talk" option - that option. QUEST_DETAIL accepts, QUEST_PROGRESS
-- continues when the quest is complete, QUEST_COMPLETE takes the reward
-- when there is nothing to choose (rewards.lua handles a choice).
--
-- Held pause key, /questing pause, an NPC on the ignore list: nothing
-- happens, and nothing happens for the rest of that conversation either
-- (shouldRun), so a window the player opened on purpose is not run over
-- by the next event. Questie's own autopilot or QuickQuest/Immersion
-- installed: this file stands down, two helpers at one NPC double up.
-------------------------------------------------------------------
local TALK_ICON = 132053   -- the gossip bubble: plain talk, not vendor, trainer, taxi or bank

local shouldRun = true

local function db() return ns.db() end

-- another helper doing the same job?
local function OtherHelper()
    if C_AddOns.IsAddOnLoaded("QuickQuest") then return "QuickQuest" end
    if C_AddOns.IsAddOnLoaded("Immersion") then return "Immersion" end
    local Q = _G.Questie
    local p = Q and Q.db and Q.db.profile
    if p and ((p.autoAccept and p.autoAccept.enabled) or p.autocomplete) then return "Questie's automatic questing" end
    return nil
end
ns.OtherHelper = OtherHelper

-- may this file act at the unit ("npc" in gossip and greeting, "questnpc" after)?
local function Allowed(unit)
    if OtherHelper() then return false end
    if ns.Paused() or ns.Ignored(unit) then return false end
    return true
end

-- what dialog.lua would do at the NPC right now - rewards.lua asks
function ns.DialogAllowed()
    return shouldRun and Allowed("questnpc")
end

local function Trivial(questID)
    if not questID or questID == 0 then return false end
    local ok, trivial = pcall(C_QuestLog.IsQuestTrivial, questID)
    return ok and trivial == true
end

local function AcceptOK(questID, trivial)
    local d = db()
    if not d.autoAccept then return false end
    if trivial and not d.acceptTrivial then return false end
    return true
end

local function QuestName(questID)
    local title = questID and questID > 0 and C_QuestLog.GetTitleForQuestID(questID)
    if title and title ~= "" then return title end
    return GetTitleText and GetTitleText() or "the quest"
end

-------------------------------------------------------------------
-- The events
-------------------------------------------------------------------
local function Stop()
    shouldRun = false
end

local function OnGossip()
    if not Allowed("npc") then Stop() return end
    if not shouldRun then return end
    local d = db()
    if d.autoTurnIn then
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if q.isComplete and q.questID then
                C_GossipInfo.SelectActiveQuest(q.questID)
                return
            end
        end
    end
    if d.autoAccept then
        for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            if q.questID and AcceptOK(q.questID, q.isTrivial) then
                C_GossipInfo.SelectAvailableQuest(q.questID)
                return
            end
        end
    end
    if d.autoGossip then
        local options = C_GossipInfo.GetOptions() or {}
        if C_GossipInfo.GetNumActiveQuests() == 0 and C_GossipInfo.GetNumAvailableQuests() == 0 and #options == 1 then
            local o = options[1]
            -- Blizzard picks an only option itself when the option says so
            if o.gossipOptionID and o.icon == TALK_ICON and not o.selectOptionWhenOnlyOption then
                C_GossipInfo.SelectOption(o.gossipOptionID)
            end
        end
    end
end

local function OnGreeting()
    if not Allowed("npc") then Stop() return end
    if not shouldRun then return end
    local d = db()
    if d.autoTurnIn then
        for i = 1, GetNumActiveQuests() do
            local _, isComplete = GetActiveTitle(i)
            if isComplete then
                SelectActiveQuest(i)
                return
            end
        end
    end
    if d.autoAccept then
        for i = 1, GetNumAvailableQuests() do
            local trivial = IsAvailableQuestTrivial and IsAvailableQuestTrivial(i)
            if AcceptOK(nil, trivial) then
                SelectAvailableQuest(i)
                return
            end
        end
    end
end

local function OnDetail(_, questStartItemID)
    -- a quest from an item or an area goes to the tracker's pop-up, Blizzard's way
    if questStartItemID and questStartItemID ~= 0 then return end
    if QuestGetAutoAccept() then return end
    local questID = GetQuestID()
    if UnitIsPlayer("questnpc") then
        -- shared by a party member
        if db().acceptShared and not ns.Paused() and not OtherHelper() then
            AcceptQuest()
            ns.Say(("accepted %s, shared by %s."):format(QuestName(questID), UnitName("questnpc") or "a party member"))
        end
        return
    end
    if not Allowed("questnpc") then Stop() return end
    if not shouldRun then return end
    if AcceptOK(questID, Trivial(questID)) then
        AcceptQuest()
        ns.Say("accepted " .. QuestName(questID) .. ".")
    end
end

local function OnProgress()
    if not Allowed("questnpc") then Stop() return end
    if not shouldRun or not db().autoTurnIn then return end
    if IsQuestCompletable() then CompleteQuest() end
end

local function OnComplete()
    if not Allowed("questnpc") then Stop() return end
    if not shouldRun or not db().autoTurnIn then return end
    local choices = GetNumQuestChoices()
    if choices > 1 then return end   -- rewards.lua marks them, and picks only if asked to
    GetQuestReward(1)
    ns.Say("handed in " .. QuestName(GetQuestID()) .. ".")
end

-- a party member started an escort or a shared quest asks for a yes
local function OnAcceptConfirm(_, name, questTitle)
    if not db().acceptShared or ns.Paused() or OtherHelper() then return end
    ConfirmAcceptQuest()
    pcall(StaticPopup_Hide, "QUEST_ACCEPT")
    ns.Say(("accepted %s from %s."):format(questTitle or "the quest", name or "a party member"))
end

-- every window closed: the next conversation starts fresh
local function AllClosed()
    for _, name in ipairs({ "GossipFrame", "QuestFrameGreetingPanel", "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel" }) do
        local f = _G[name]
        if f and f:IsVisible() then return false end
    end
    return true
end

local function OnClosed()
    C_Timer.After(0.5, function()
        if not shouldRun and AllClosed() then shouldRun = true end
    end)
end

-- share a new quest with the party, a moment after taking it
local function OnAccepted(_, questID)
    if not db().autoShare or not questID or not IsInGroup() then return end
    C_Timer.After(0.5, function()
        if C_QuestLog.IsPushableQuest(questID) and QuestUtil and QuestUtil.ShareQuest then
            QuestUtil.ShareQuest(questID)
        end
    end)
end

function ns.InitDialog()
    ns.On("GOSSIP_SHOW", OnGossip)
    ns.On("QUEST_GREETING", OnGreeting)
    ns.On("QUEST_DETAIL", OnDetail)
    ns.On("QUEST_PROGRESS", OnProgress)
    ns.On("QUEST_COMPLETE", OnComplete)
    ns.On("QUEST_ACCEPT_CONFIRM", OnAcceptConfirm)
    ns.On("QUEST_FINISHED", OnClosed)
    ns.On("GOSSIP_CLOSED", OnClosed)
    ns.On("QUEST_ACCEPTED", OnAccepted)
    local other = OtherHelper()
    if other then
        ns.Print(other .. " is handling the NPC dialog, so DeckUIForever Questing leaves it alone.")
    end
end
