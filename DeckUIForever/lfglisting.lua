local D = DeckUIForever

-------------------------------------------------------------------
-- The group listing as a small window: how long, who is there
-------------------------------------------------------------------
-- Owner's wish (2026-11-05): "just a window that shows the time and what
-- it has found". Forever has no dungeon queue - its group finder is
-- Classic's listing tool (Blizzard_GroupFinder_VanillaStyle): you list
-- yourself or your group for one or more activities, others browse and
-- whisper or invite. So this window shows, while a listing of yours is
-- up: the activity, how long it has been listed, the roles you offered
-- and the group so far - tanks, healers and damage dealers found of the
-- activity's size, from the roles the members picked in the tool
-- (UnitGroupRolesAssigned). DeckUIForeverDB.listingWindow, off by
-- default, Windows page; movable "Group listing", dragged directly while
-- it shows. A right click offers to unlist. Blizzard's eye stays.
--
-- The entry (C_LFGList.GetActiveEntryInfo) carries no age, so the clock
-- starts when the entry first appears to us - at login with a listing
-- already up it starts then. Ticks once a second while shown.
-------------------------------------------------------------------
local W, PAD = 230, 8
local ROLE_FILE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLES = { { "TANK", "tank" }, { "HEALER", "healer" }, { "DAMAGER", "dps" } }

local function Enabled() return DeckUIForeverDB and DeckUIForeverDB.listingWindow end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
    end
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function RoleIcon(role)
    if not GetTexCoordsForRoleSmallCircle then return role:sub(1, 1) end
    local l, r, t, b = GetTexCoordsForRoleSmallCircle(role)
    return ("|T%s:14:14:0:0:64:64:%d:%d:%d:%d|t"):format(ROLE_FILE, l * 64, r * 64, t * 64, b * 64)
end

local function Listed()
    return C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()
end

-------------------------------------------------------------------
-- The window
-------------------------------------------------------------------
local win = CreateFrame("Frame", "DeckUIForeverListing", UIParent)
win:SetSize(W, 76)
win.defaultPoint = { "TOPRIGHT", UIParent, "TOPRIGHT", -230, -220 }
win:SetPoint(unpack(win.defaultPoint))
win:SetFrameStrata("MEDIUM")
win:Hide()
D.FlatBox(win, 0.9)

local function Text(size)
    local fs = win:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, size, "OUTLINE")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetWidth(W - 2 * PAD)
    return fs
end
local title = Text(12)
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetTextColor(1, 0.82, 0)
local time = Text(11)
time:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
local roles = Text(12)
roles:SetPoint("TOPLEFT", time, "BOTTOMLEFT", 0, -4)
local group = Text(12)
group:SetPoint("TOPLEFT", roles, "BOTTOMLEFT", 0, -4)

local listedAt   -- GetTime() when the listing appeared to us

-- the activities' names and the largest group they take
local function Activities()
    local entry = C_LFGList.GetActiveEntryInfo()
    if not entry or not entry.activityIDs then return "Listed", 5 end
    local names, max = {}, 0
    for _, id in ipairs(entry.activityIDs) do
        local info = C_LFGList.GetActivityInfoTable(id)
        if info then
            names[#names + 1] = info.shortName ~= "" and info.shortName or info.fullName
            max = math.max(max, info.maxNumPlayers or 0)
        end
    end
    local name = names[1] or "Listed"
    if #names > 1 then name = name .. (" |cff888888+%d|r"):format(#names - 1) end
    return name, max > 0 and max or 5
end

-- what the group has: members by the role they picked in the tool
local function GroupRoles()
    local count = { TANK = 0, HEALER = 0, DAMAGER = 0, NONE = 0 }
    local units = { "player" }
    for i = 1, 4 do units[#units + 1] = "party" .. i end
    local n = 0
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            n = n + 1
            local role = UnitGroupRolesAssigned(unit) or "NONE"
            count[role] = (count[role] or 0) + 1
        end
    end
    return count, n
end

local function Update()
    if not Enabled() then win:Hide() return end
    local listed = Listed()
    if not listed and not D.IsUnlocked("Group listing") then
        win:Hide()
        listedAt = nil
        return
    end
    if listed and not listedAt then listedAt = GetTime() end

    local name, max = "Listed", 5
    if listed then name, max = Activities() end
    title:SetText(name)
    time:SetText(listedAt and ("Listed for " .. Clock(GetTime() - listedAt)) or "|cff888888not listed|r")

    local mine = C_LFGListRoles and C_LFGListRoles.GetRoles and C_LFGListRoles.GetRoles() or {}
    local offered = {}
    for _, r in ipairs(ROLES) do
        if mine[r[2]] then offered[#offered + 1] = RoleIcon(r[1]) end
    end
    roles:SetText("You: " .. (#offered > 0 and table.concat(offered, " ") or "|cff888888no role picked|r"))

    local count, n = GroupRoles()
    local parts = {}
    for _, r in ipairs(ROLES) do
        parts[#parts + 1] = RoleIcon(r[1]) .. " " .. count[r[1]]
    end
    group:SetText(("Group %d/%d   %s"):format(n, max, table.concat(parts, "  ")))
    win:Show()
end

local elapsed = 0
win:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 1 then return end
    elapsed = 0
    Update()
end)

win:SetScript("OnMouseUp", function(self, button)
    if button ~= "RightButton" or not MenuUtil or not Listed() then return end
    MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle("Group listing")
        root:CreateButton("Unlist", function() C_LFGList.RemoveListing() end)
    end)
end)

function D.ApplyListingWindow()
    Update()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "LFG_LIST_ACTIVE_ENTRY_UPDATE", "LFG_LIST_ROLE_UPDATE", "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        D.MakeMovable(win, "Group listing", DeckUIForeverDB)
        D.MakeDraggable(win)
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" and not Listed() then
        listedAt = nil
    end
    if Enabled() then Update() end
end)

-- shown while unlocked, so it can be placed without a listing
if D.OnUnlock then
    D.OnUnlock(function() if Enabled() then Update() end end)
end
