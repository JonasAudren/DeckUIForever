local D = DeckUIForever

-------------------------------------------------------------------
-- Blizzard's Cooldown Manager in DeckUIForever's look
-------------------------------------------------------------------
-- Owner's wish 2026-11-22 ("können wir den Cooldown Manager bei uns
-- einbauen?"). Read in the forever branch of Gethe/wow-ui-source,
-- Blizzard_CooldownViewer (loads for standard and camelot): four Edit
-- Mode systems - EssentialCooldownViewer, UtilityCooldownViewer,
-- BuffIconCooldownViewer, BuffBarCooldownViewer - each with a frame pool
-- of item frames (CooldownViewerEssentialItemTemplate and so on). The
-- game fills them, secrets and all; an addon could not rebuild that in
-- a fight, so nothing is rebuilt: the items are dressed.
--
-- What is done to an item, once (the pool reuses the frames):
--   * Blizzard's round mask is taken off the icon and the ring art
--     (atlas UI-HUD-CoolDownManager-IconOverlay) goes to alpha 0 - both
--     are anonymous regions, found by type and atlas
--   * the icon is trimmed, a black edge and a light one-pixel outline of
--     ours frame it (the Bars module's slot look)
--   * the Cooldown widget gets a square swipe and our countdown font;
--     Blizzard keeps setting the swipe's colour and whether it draws
--   * a tracked-buff bar gets a flat green fill, a flat dark track and
--     our font - and round ends when the Orbs module is there (Caps)
--
-- Rules (the HoT window's lessons): no script and no HookScript on an
-- item frame - Blizzard sets OnUpdate scripts there with secret values
-- around; no field of ours on Blizzard's frames (a weak table remembers
-- what is dressed); nothing Blizzard's layout reads is written (size,
-- scale, anchors, layoutIndex). The viewers stay Edit Mode's to move.
-- Only post-hooks on the viewers' OnAcquireItemFrame and RefreshLayout.
-- Undoing the look needs a reload.
--
-- DeckUIForeverDB.cdManager (off). Switching it on also switches
-- Blizzard's manager on (CVar cooldownViewerEnabled) when it was off.
-- /df cooldowns prints what the client reports.
-------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8x8"
local RING = "UI-HUD-CoolDownManager-IconOverlay"
local CVAR = "cooldownViewerEnabled"
local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local FONT_BIG, FONT_SMALL = "DeckUIForeverCooldownManagerFont", "DeckUIForeverCooldownManagerFontSmall"
do
    local big = CreateFont(FONT_BIG)
    big:SetFont(D.FONT, 18, "THICKOUTLINE")
    big:SetTextColor(1, 1, 1)
    local small = CreateFont(FONT_SMALL)
    small:SetFont(D.FONT, 12, "OUTLINE")
    small:SetTextColor(1, 1, 1)
end

local dressed = setmetatable({}, { __mode = "k" })
local hooked = {}
local active = false
local stats = { items = 0, errors = 0, last = nil }

local function Edge(holder)
    -- a black edge one pixel outside the icon ...
    local back = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    back:SetPoint("TOPLEFT", -1, 1)
    back:SetPoint("BOTTOMRIGHT", 1, -1)
    back:SetColorTexture(0, 0, 0, 1)
    -- ... and the slot look's light outline on it
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = holder:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(1, 1, 1, 0.3)
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
end

-- The tracked-buff bars as capsules (2026-11-22, so they and the debuff
-- window read as one): the Orbs module's cap masks, square at each end of
-- the bar (ffstyle.lua's Caps). The textures lie in that module's folder,
-- so without it the bars stay flat. 19: the bar's height in Blizzard's
-- template (the item's scale scales the caps with it).
local RUN = { 0.5, 0.75, 0.3 }
local BAR_H = 19
local CAP_L = "Interface\\AddOns\\DeckUIForever_Orbs\\textures\\bar_cap_left"
local CAP_R = "Interface\\AddOns\\DeckUIForever_Orbs\\textures\\bar_cap_right"

local function OrbsLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DeckUIForever_Orbs") or false
end

local function Caps(bar, height, grow)
    local size = height + 2 * grow
    local l = bar:CreateMaskTexture()
    l:SetTexture(CAP_L, "CLAMPTOWHITE", "CLAMPTOWHITE")
    l:SetSize(size, size)
    l:SetPoint("LEFT", bar, "LEFT", -grow, 0)
    local r = bar:CreateMaskTexture()
    r:SetTexture(CAP_R, "CLAMPTOWHITE", "CLAMPTOWHITE")
    r:SetSize(size, size)
    r:SetPoint("RIGHT", bar, "RIGHT", grow, 0)
    return function(texture)
        texture:AddMaskTexture(l)
        texture:AddMaskTexture(r)
    end
end

local function SetFontOf(fs, size)
    if fs and fs.SetFont then fs:SetFont(D.FONT, size, "OUTLINE") end
end

local function DressIcon(holder, tex)
    if not (holder and tex and tex.SetTexCoord) then return end
    for _, region in ipairs({ holder:GetRegions() }) do
        if region ~= tex then
            if region:IsObjectType("MaskTexture") then
                tex:RemoveMaskTexture(region)
            elseif region:IsObjectType("Texture") and region.GetAtlas and region:GetAtlas() == RING then
                region:SetAlpha(0)
            end
        end
    end
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Edge(holder)
end

local function DressItem(item, small)
    if dressed[item] then return end
    dressed[item] = true
    stats.items = stats.items + 1
    local bar = item.Bar
    if bar then
        -- a tracked buff as a bar: the icon sits in a frame of its own
        local holder = item.Icon
        DressIcon(holder, holder and holder.Icon)
        SetFontOf(holder and holder.Applications, 11)
        bar:SetStatusBarTexture(WHITE)
        -- the debuff window's green: Blizzard colours the bar once, in the template
        bar:SetStatusBarColor(RUN[1], RUN[2], RUN[3])
        if bar.BarBG then
            bar.BarBG:SetAtlas(nil)
            bar.BarBG:SetColorTexture(0, 0, 0, 0.55)
            bar.BarBG:ClearAllPoints()
            bar.BarBG:SetPoint("TOPLEFT", -1, 1)
            bar.BarBG:SetPoint("BOTTOMRIGHT", 1, -1)
        end
        -- a capsule like the debuff window's rows, when its cap textures are there
        if OrbsLoaded() then
            Caps(bar, BAR_H, 0)(bar:GetStatusBarTexture())
            if bar.BarBG then Caps(bar, BAR_H, 1)(bar.BarBG) end
            -- the spark at the fill's end: Blizzard shows and hides it, so alpha
            if bar.Pip then bar.Pip:SetAlpha(0) end
        end
        SetFontOf(bar.Name, 12)
        SetFontOf(bar.Duration, 12)
        return
    end
    DressIcon(item, item.Icon)
    local cd = item.Cooldown
    if cd then
        cd:SetSwipeTexture(WHITE)
        cd:SetCountdownFont(small and FONT_SMALL or FONT_BIG)
    end
    SetFontOf(item.ChargeCount and item.ChargeCount.Current, small and 10 or 12)
    SetFontOf(item.Applications and item.Applications.Applications, 12)
end

local function Safe(item, small)
    local ok, err = pcall(DressItem, item, small)
    if not ok then
        stats.errors = stats.errors + 1
        stats.last = tostring(err)
    end
end

local function DressViewer(viewer, small)
    local pool = viewer.itemFramePool
    if not (pool and pool.EnumerateActive) then return end
    for item in pool:EnumerateActive() do Safe(item, small) end
end

local function Hook(name)
    local viewer = _G[name]
    if not viewer or hooked[name] then return end
    hooked[name] = true
    local small = name == "UtilityCooldownViewer"
    if viewer.OnAcquireItemFrame then
        hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, item)
            if active then Safe(item, small) end
        end)
    end
    if viewer.RefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", function(self)
            if active then DressViewer(self, small) end
        end)
    end
    DressViewer(viewer, small)
end

function D.CooldownManagerAvailable()
    return C_CooldownViewer ~= nil and _G.EssentialCooldownViewer ~= nil
end

function D.ApplyCooldownManager()
    local on = DeckUIForeverDB.cdManager and true or false
    if on and not D.CooldownManagerAvailable() then return end
    if on then
        active = true
        -- Blizzard's own switch: without it the four bars never show
        if C_CVar and C_CVar.GetCVar(CVAR) == "0" and not InCombatLockdown() then
            C_CVar.SetCVar(CVAR, "1")
            print("DeckUIForever: Blizzard's Cooldown Manager is switched on.")
        end
        for _, name in ipairs(VIEWERS) do Hook(name) end
        if D.NeedReload then D.NeedReload("cdManager", false) end
    elseif active then
        -- the dressed frames keep the look until the interface is loaded again
        active = false
        if D.NeedReload then D.NeedReload("cdManager") end
    end
end

-- Blizzard's own window: which spells stand in which bar
function D.OpenCooldownSettings()
    if InCombatLockdown() then
        print("DeckUIForever: not possible in combat.")
        return
    end
    local settings = _G.CooldownViewerSettings
    if settings and settings.TogglePanel then
        settings:TogglePanel()
    else
        print("DeckUIForever: Blizzard's Cooldown Manager settings were not found.")
    end
end

-------------------------------------------------------------------
-- What the manager shows, for the debuff window (Orbs, debuffs.lua)
-------------------------------------------------------------------
-- Blizzard's two tracked-buff viewers look for an item's aura on the
-- player first and then on the target - on an enemy your own debuffs
-- (CooldownViewerItemData.lua: scanUnits, "HARMFUL|PLAYER"). So a DoT
-- that sits in one of those bars is shown there for the current target,
-- and the debuff window can leave it out (its option dotManager).
--
-- Read, never written, and only out of a fight: each item frame's
-- cooldownID (a plain field) and what C_CooldownViewer says about it.
-- Matched by spell name, since Classic has ranks: the item's spell, its
-- override and its linked spells. A viewer counts while Blizzard's switch
-- is on and its Edit Mode visibility is not "hidden". Independent of the
-- look above (DeckUIForeverDB.cdManager).
local TRACKED = { "BuffBarCooldownViewer", "BuffIconCooldownViewer" }
local SCAN_EVERY = 5
local scan = { time = -100, stamp = 0, shown = {} }

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Info(cooldownID)
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then return nil end
    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
    return ok and type(info) == "table" and info or nil
end

local function AddNames(set, info, value)
    local function add(id)
        id = Plain(id)
        local name = id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if name and not set[name] then set[name] = value end
    end
    add(info.spellID)
    add(info.overrideSpellID)
    if type(info.linkedSpellIDs) == "table" then
        for _, id in ipairs(info.linkedSpellIDs) do add(id) end
    end
end

local function Displays(viewer)
    if not (viewer and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive) then return false end
    if not C_CVar or C_CVar.GetCVar(CVAR) ~= "1" then return false end
    local hidden = Enum.CooldownViewerVisibleSetting and Enum.CooldownViewerVisibleSetting.Hidden
    return not (hidden ~= nil and viewer.visibleSetting == hidden)
end

local function ScanShown()
    local shown = {}
    for _, name in ipairs(TRACKED) do
        local viewer = _G[name]
        if Displays(viewer) then
            for item in viewer.itemFramePool:EnumerateActive() do
                local id = Plain(item.cooldownID)
                local info = id and Info(id)
                if info then AddNames(shown, info, name) end
            end
        end
    end
    return shown
end

-- reads the two viewers again, at most every SCAN_EVERY seconds (force: now)
function D.CooldownManagerScan(force)
    if InCombatLockdown() or not D.CooldownManagerAvailable() then return end
    local now = GetTime()
    if not force and now - scan.time < SCAN_EVERY then return end
    scan.time = now
    local ok, shown = pcall(ScanShown)
    if not ok then
        stats.errors = stats.errors + 1
        stats.last = tostring(shown)
        return
    end
    local same = true
    for name, viewer in pairs(shown) do
        if scan.shown[name] ~= viewer then same = false break end
    end
    if same then
        for name in pairs(scan.shown) do
            if not shown[name] then same = false break end
        end
    end
    if not same then
        scan.shown = shown
        scan.stamp = scan.stamp + 1
    end
end

-- the viewer's name when a spell of that name sits in a tracked-buff bar
function D.CooldownManagerShows(name)
    return name and scan.shown[name] or nil
end

-- changes whenever the answer of CooldownManagerShows may have changed
function D.CooldownManagerStamp()
    return scan.stamp
end

-- every spell name Blizzard's data knows for this character, with the
-- category it stands in by default; out of a fight, for /df cooldowns
function D.CooldownManagerOffers()
    local offered = {}
    if InCombatLockdown() then return offered end
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet and Enum.CooldownViewerCategory) then return offered end
    for key, category in pairs(Enum.CooldownViewerCategory) do
        if type(category) == "number" and category >= 0 then
            local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category, true)
            if ok and type(ids) == "table" then
                for _, id in ipairs(ids) do
                    local info = Info(id)
                    if info then AddNames(offered, info, key) end
                end
            end
        end
    end
    return offered
end

-- /df cooldowns
function D.PrintCooldownManager()
    print(("DeckUIForever cooldown manager: option %s, look %s, %d items dressed, %d errors"):format(
        DeckUIForeverDB.cdManager and "on" or "off", active and "active" or "not active", stats.items, stats.errors))
    if stats.last then print("  last error: " .. stats.last) end
    if not C_CooldownViewer then
        print("  C_CooldownViewer: missing")
        return
    end
    local ok, available, reason = pcall(C_CooldownViewer.IsCooldownViewerAvailable)
    print(("  available: %s%s; Blizzard's switch (%s): %s"):format(tostring(ok and available),
        (ok and reason and reason ~= "") and (" (" .. tostring(reason) .. ")") or "", CVAR, tostring(C_CVar.GetCVar(CVAR))))
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        if viewer then
            local pool = viewer.itemFramePool
            print(("  %s: %s, %s items, %s"):format(name, viewer:IsShown() and "shown" or "hidden",
                tostring(pool and pool.GetNumActive and pool:GetNumActive()), hooked[name] and "hooked" or "not hooked"))
        else
            print("  " .. name .. ": missing")
        end
    end
    -- the buff bars' spells, and what the debuff window makes of them
    if InCombatLockdown() then
        print("  in the buff bars (read before this fight):")
    else
        D.CooldownManagerScan(true)
        print("  in the buff bars:")
    end
    local names = {}
    for name, viewer in pairs(scan.shown) do names[#names + 1] = name .. " (" .. viewer .. ")" end
    table.sort(names)
    print("    " .. (#names > 0 and table.concat(names, ", ") or "nothing"))
    if D.CooldownReport then D.CooldownReport() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if DeckUIForeverDB and DeckUIForeverDB.cdManager then D.ApplyCooldownManager() end
end)
