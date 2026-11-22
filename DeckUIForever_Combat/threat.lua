local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- Your threat on the target
-------------------------------------------------------------------
-- UnitDetailedThreatSituation("player", "target") gives: whether you
-- are the one it attacks, a status from 0 to 3, and your threat in
-- percent of what it takes to pull it (100 = it turns to you). A bar
-- shows the percent, in the status' colour: grey, yellow, orange, red.
-- Only on a target you can attack that has you on its list, and - unless
-- threatSolo is on - only in a group, where threat means something.
--
-- In a fight the numbers were readable on 2026-11-21 (/df apis: true, 3,
-- 100, 255, 85). Should they come secret, the percent goes to the bar
-- and the text as it is and the bar stays in one colour.
-------------------------------------------------------------------
local W, H = 140, 12
local COLORS = {
    [0] = { 0.69, 0.69, 0.69 },
    [1] = { 1.00, 1.00, 0.47 },
    [2] = { 1.00, 0.60, 0.00 },
    [3] = { 1.00, 0.20, 0.15 },
}
local PLAIN = { 0.9, 0.8, 0.5 }

local holder = ns.Holder("DeckUIForeverThreat", "Threat", W, H, { "CENTER", UIParent, "CENTER", 0, -250 })
local bar = ns.Bar(holder, W, H)
bar:SetPoint("CENTER")
bar:SetMinMaxValues(0, 100)
bar.left:SetText("Threat")
holder:Hide()

local preview = false
local ev = CreateFrame("Frame")

local function On() return DeckUIForeverCombatDB.threat and true or false end

local function Update()
    if preview then return end
    if not On() or not UnitDetailedThreatSituation or not UnitExists("target")
        or not (DeckUIForeverCombatDB.threatSolo or IsInGroup()) then
        holder:Hide()
        return
    end
    local attackable = UnitCanAttack("player", "target")
    if not ns.Secret(attackable) and not attackable then
        holder:Hide()
        return
    end
    local ok, _, status, percent = pcall(UnitDetailedThreatSituation, "player", "target")
    if not ok or percent == nil then
        -- not on its list: no fight with it
        holder:Hide()
        return
    end
    local c = (not ns.Secret(status) and COLORS[status]) or PLAIN
    bar:SetStatusBarColor(c[1], c[2], c[3])
    if not pcall(bar.SetValue, bar, percent) then
        holder:Hide()
        return
    end
    if not pcall(bar.right.SetFormattedText, bar.right, "%d%%", percent) then bar.right:SetText("") end
    holder:Show()
end

ev:SetScript("OnEvent", Update)

local function Apply()
    if On() then
        pcall(ev.RegisterUnitEvent, ev, "UNIT_THREAT_LIST_UPDATE", "target")
        pcall(ev.RegisterUnitEvent, ev, "UNIT_THREAT_SITUATION_UPDATE", "player")
        for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
            "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
            pcall(ev.RegisterEvent, ev, event)
        end
    else
        ev:UnregisterAllEvents()
    end
    Update()
end

local function Preview(state)
    preview = state and On() or false
    if preview then
        local c = COLORS[2]
        bar:SetStatusBarColor(c[1], c[2], c[3])
        bar:SetValue(72)
        bar.right:SetText("72%")
        holder:Show()
    else
        Update()
    end
end

ns.pieces.threat = {
    key = "Threat",
    Init = function() D.MakeMovable(holder, "Threat", DeckUIForeverCombatDB) end,
    Apply = Apply,
    Preview = Preview,
    Print = function()
        local function Show(v) return ns.Secret(v) and "hidden by the game" or tostring(v) end
        local tanking, status, percent
        if UnitDetailedThreatSituation then
            local _, a, b, c = pcall(UnitDetailedThreatSituation, "player", "target")
            tanking, status, percent = a, b, c
        end
        print(("  threat: option %s, alone too %s, in a group %s, on the target: tanking %s, status %s, percent %s, shown %s"):format(
            tostring(DeckUIForeverCombatDB.threat), tostring(DeckUIForeverCombatDB.threatSolo), tostring(IsInGroup()),
            Show(tanking), Show(status), Show(percent), tostring(holder:IsShown())))
    end,
}
