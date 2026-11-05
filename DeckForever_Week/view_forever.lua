local ADDON, ns = ...
local D = DeckForever

-------------------------------------------------------------------
-- Forever: the table's columns and details (before window.lua)
-------------------------------------------------------------------
-- window.lua keeps the frame, the rows, the lockouts and the weekly
-- quests; Forever brings what sits between them, after DeckUI's
-- view_mists.lua. Columns: raid bosses down this week, the Legacy renown
-- level, the PvP rank, today's dailies. The helpers (colours, Count,
-- Icon) come from window.lua as ns.Fmt, read when a row is filled -
-- window.lua loads after.
-------------------------------------------------------------------
ns.COLS = {
    { key = "name",    title = "Character", w = 150 },
    { key = "ilvl",    title = "ilvl",      w = 38, tip = "Average item level (equipped)." },
    { key = "raid",    title = "Raids",     w = 60, tip = "Raid bosses down this week, all raids and difficulties." },
    { key = "legacy",  title = "Legacy",    w = 70, tip = "Renown level of the Legacy reward track." },
    { key = "pvp",     title = "PvP rank",  w = 66, tip = "Renown level of the PvP rank track." },
    { key = "dailies", title = "Dailies",   w = 50, tip = "Daily quests done today (of the ones this character has seen in its log)." },
    { key = "quests",  title = "Weeklies",  w = 58, tip = "Weekly quests done, of the ones listed (hidden ones not counted)." },
}

local function Track(snap, key)
    for _, t in ipairs(snap.renown or {}) do
        if t.key == key then return t end
    end
end

-- "level" in green at the cap, "level / max" otherwise, "-" without the track
local function Level(snap, key)
    local F, t = ns.Fmt, Track(snap, key)
    if not t or not t.unlocked then return F.GREY .. "-|r" end
    if t.max > 0 and t.level >= t.max then return F.GREEN .. t.level .. "|r" end
    return ("%d%s"):format(t.level, t.max > 0 and (F.GREY .. " / " .. t.max .. "|r") or "")
end

local function LiveLocks(snap)
    local list = {}
    for _, l in ipairs(snap.locks or {}) do
        if not l.resetAt or l.resetAt > time() then list[#list + 1] = l end
    end
    return list
end

-- today's dailies; a snapshot from before the daily reset counts none
local function DailiesToday(snap)
    local d = snap.dailies
    if not d or (d.resetAt and time() >= d.resetAt) then return 0, {} end
    return d.total or 0, d.groups or {}
end

function ns.FillCells(c, snap, stale)
    local F = ns.Fmt
    local killed = 0
    for _, l in ipairs(LiveLocks(snap)) do
        if l.raid then killed = killed + (l.killed or 0) end
    end
    c.raid:SetText(killed > 0 and killed or (F.GREY .. "0|r"))
    c.legacy:SetText(Level(snap, "legacy"))
    c.pvp:SetText(Level(snap, "pvp"))
    local today = DailiesToday(snap)
    c.dailies:SetText(today > 0 and (F.GREEN .. today .. "|r") or (F.GREY .. "0|r"))
end

-- left, above the lockouts: the two renown tracks with their progress
function ns.DetailsTop(L, snap, stale)
    local F = ns.Fmt
    L:Heading("Renown")
    for _, track in ipairs(ns.RENOWN) do
        local t = Track(snap, track.key)
        if t and t.unlocked then
            local progress = (t.max > 0 and t.level >= t.max) and ""
                or ("  %s%s/%s|r"):format(F.GREY, BreakUpLargeNumbers(t.earned), BreakUpLargeNumbers(t.threshold))
            L:Line(t.name, Level(snap, track.key) .. progress)
        else
            L:Line(track.name, F.GREY .. "not unlocked|r")
        end
    end
end

-- right: today's dailies, reputation, currencies
function ns.DetailsRight(R, snap, stale)
    local F = ns.Fmt
    local today, groups = DailiesToday(snap)
    R:Heading("Today")
    R:Line("Daily quests done", today > 0 and (F.GREEN .. today .. "|r") or (F.GREY .. "none yet|r"))
    local names = {}
    for group in pairs(groups) do names[#names + 1] = group end
    table.sort(names)
    for _, group in ipairs(names) do
        R:Line(F.GREY .. "    " .. (group ~= "" and group or "Other") .. "|r", groups[group])
    end

    if snap.reputations and #snap.reputations > 0 then
        R:Heading("Reputation")
        for _, f in ipairs(snap.reputations) do
            local color = ("|cff%02x%02x%02x"):format(f.r * 255, f.g * 255, f.b * 255)
            local progress = f.cur >= f.max and "" or ("  %s%s/%s|r"):format(F.GREY,
                BreakUpLargeNumbers(f.cur), BreakUpLargeNumbers(f.max))
            R:Line(f.name, color .. (f.standing or "") .. "|r" .. progress)
        end
    end

    if #ns.WORLD_BOSSES > 0 then
        R:Heading("World bosses")
        for _, b in ipairs(ns.WORLD_BOSSES) do
            local done = not stale and snap.worldBosses and snap.worldBosses[b.quest]
            R:Line(b.name, done and (F.GREEN .. "done|r") or "open")
        end
    end

    R:Currencies("Currencies", snap.currencies, stale)
end
