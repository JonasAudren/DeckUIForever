local D = DeckUIForever

-------------------------------------------------------------------
-- Hidden settings: what the game only takes through /console
-------------------------------------------------------------------
-- Owner 2026-11-11, after the camera button ("was es noch für Optionen
-- gibt, die nur per Befehl aktiviert werden können", then "ein neues
-- Untermenü unter General mit allen Codes, Reihenfolge nach deiner Prio
-- und kurzer prägnanter Erklärung"). A page of the General group that
-- puts the game's console variables on switches, sliders and buttons, in
-- the order of their use: healing and the Deck first, then the
-- controller, then looks, then what helps when an addon misbehaves.
--
-- Nothing here is ours to store: every widget reads and writes the CVar
-- itself (the client keeps it in Config.wtf), through two proxy tables
-- that stand in for the `db` the widgets expect. The list was written
-- from the retail engine's names and NOT checked against Forever: an
-- entry whose CVar this client does not know (GetCVar gives nil) is left
-- off the page, a section with none of its entries too. /df cvars prints
-- every name with its value, its default, or "unknown" - the first thing
-- to run in game. Some CVars may not change in a fight, so none is
-- written there.
-------------------------------------------------------------------
local function Exists(name) return GetCVar(name) ~= nil end

local function Default(name)
    return C_CVar and C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(name) or nil
end

-- false when it could not be written (a fight, or the client said no)
local function Set(name, value)
    if InCombatLockdown() then
        print("DeckUIForever: not in combat - try again after the fight.")
        return false
    end
    local ok = pcall(SetCVar, name, value)
    if not ok then print(("DeckUIForever: the game did not take %s = %s."):format(name, tostring(value))) end
    return ok
end

-- the widgets' `db`: the key is the CVar's name
local bools = setmetatable({}, {
    __index = function(_, name) return GetCVarBool(name) and true or false end,
    __newindex = function(_, name, v) Set(name, v and "1" or "0") end,
})
local numbers = setmetatable({}, {
    __index = function(_, name) return tonumber(GetCVar(name) or "") end,
})
local function Bools() return bools end
local function Numbers() return numbers end

local function Fixed(digits)
    local pattern = "%." .. digits .. "f"
    return function(v) return pattern:format(v) end
end
local whole, tenth, hundredth = Fixed(0), Fixed(1), Fixed(2)
local function Yards(v) return whole(v) .. " yd" end
local function Millis(v) return whole(v) .. " ms" end
local function Percent(v) return whole(v * 100) .. "%" end

-- kind "check": on/off. "slider": min, max, step, fmt. "cycle": values
-- and their names, one button that steps through them.
D.CONSOLE_SECTIONS = {
    { title = "Healing and the Deck", items = {
        { cvar = "SoftTargetFriend", kind = "cycle", label = "Soft friendly target",
          values = { 0, 1, 2, 3 }, names = { [0] = "off", [1] = "controller only", [2] = "keyboard only", [3] = "always" },
          tip = "Without a target, a heal goes to the friend you are facing. The game's menu offers this for enemies only." },
        { cvar = "SoftTargetFriendRange", kind = "slider", label = "Soft friendly target: range", min = 5, max = 60, step = 5, fmt = Yards,
          tip = "How far away a friend may be to become the soft target." },
        { cvar = "SoftTargetFriendArc", kind = "cycle", label = "Soft friendly target: where",
          values = { 0, 1, 2 }, names = { [0] = "straight ahead", [1] = "in front of you", [2] = "all around" },
          tip = "Where the friend has to stand: exactly ahead, anywhere in front, or anywhere near you." },
        { cvar = "SoftTargetIconFriend", kind = "check", label = "Icon over the soft friendly target",
          tip = "Marks the friend your next heal would go to." },
        { cvar = "SoftTargetNameplateFriend", kind = "check", label = "Nameplate for the soft friendly target",
          tip = "Shows that friend's nameplate even when friendly nameplates are off." },
        { cvar = "alwaysCompareItems", kind = "check", label = "Always compare items",
          tip = "An item's tooltip always shows what you wear beside it - no Shift needed." },
        { cvar = "autoUnshift", kind = "check", label = "Leave your form to cast",
          tip = "A spell you cannot cast in a form or stealth drops the form instead of failing." },
        { cvar = "autoStand", kind = "check", label = "Stand up to cast",
          tip = "Casting while you sit makes you stand up instead of failing." },
        { cvar = "autoDismount", kind = "check", label = "Dismount to cast",
          tip = "Casting on a mount dismounts you instead of failing." },
    } },
    { title = "Controller", items = {
        { cvar = "GamePadCameraYawSpeed", kind = "slider", label = "Camera stick: turning speed", min = 0.5, max = 4, step = 0.1, fmt = tenth,
          tip = "How fast the right stick turns the camera left and right." },
        { cvar = "GamePadCameraPitchSpeed", kind = "slider", label = "Camera stick: tilting speed", min = 0.5, max = 4, step = 0.1, fmt = tenth,
          tip = "How fast the right stick tilts the camera up and down." },
        { cvar = "GamePadVibrationStrength", kind = "slider", label = "Vibration", min = 0, max = 1, step = 0.1, fmt = Percent,
          tip = "How strongly the controller rumbles. 0% is off." },
        { cvar = "test_cameraOverShoulder", kind = "slider", label = "Camera over the shoulder", min = -1.5, max = 1.5, step = 0.1, fmt = tenth,
          tip = "Moves your character out of the screen's middle, as in action games. 0 is the normal camera. The game asks once at login whether to keep this experimental camera." },
        { cvar = "test_cameraDynamicPitch", kind = "check", label = "Camera looks ahead",
          tip = "Tilts the view up a little as you zoom out, so you see more of what lies ahead. Experimental, as the one above." },
        { cvar = "autoLootRate", kind = "slider", label = "Looting speed", min = 0, max = 300, step = 10, fmt = Millis,
          tip = "The pause between two items when you loot. Lower is faster." },
        { cvar = "nameplateMaxDistance", kind = "slider", label = "Nameplates: how far", min = 20, max = 60, step = 1, fmt = Yards,
          tip = "From how far away nameplates show. The debuff window's kept columns need the enemy's nameplate." },
    } },
    { title = "Looks", items = {
        { cvar = "nameplateOverlapV", kind = "slider", label = "Nameplates: vertical spacing", min = 0.3, max = 1.5, step = 0.1, fmt = tenth,
          tip = "How far stacked nameplates stand apart, one above the other." },
        { cvar = "nameplateOverlapH", kind = "slider", label = "Nameplates: horizontal spacing", min = 0.3, max = 1.5, step = 0.1, fmt = tenth,
          tip = "How far stacked nameplates stand apart, side by side." },
        { cvar = "nameplateOccludedAlphaMult", kind = "slider", label = "Nameplates behind walls", min = 0, max = 1, step = 0.1, fmt = Percent,
          tip = "How visible the nameplate of an enemy you cannot see is. 0% hides it." },
        { cvar = "nameplateSelectedScale", kind = "slider", label = "Nameplate of your target: size", min = 1, max = 1.6, step = 0.05, fmt = hundredth,
          tip = "How much larger your target's nameplate is than the others." },
        { cvar = "nameplateMinScale", kind = "slider", label = "Distant nameplates: size", min = 0.5, max = 1, step = 0.05, fmt = hundredth,
          tip = "How small a nameplate gets far away. 1 keeps every one the same size." },
        { cvar = "WorldTextScale", kind = "slider", label = "Combat numbers: size", min = 0.5, max = 2, step = 0.1, fmt = tenth,
          tip = "The size of the damage and healing numbers over heads." },
        { cvar = "floatingCombatTextCombatDamageDirectionalScale", kind = "cycle", label = "Combat numbers",
          values = { 1, 0 }, names = { [1] = "fly apart", [0] = "rise straight up" },
          tip = "Damage numbers fly off to the sides, or rise straight up as they used to." },
        { cvar = "cameraYawMoveSpeed", kind = "slider", label = "Camera keys: turning speed", min = 90, max = 360, step = 10, fmt = whole,
          tip = "How fast the camera turns with the keyboard or the mouse." },
        { cvar = "cameraPitchMoveSpeed", kind = "slider", label = "Camera keys: tilting speed", min = 45, max = 180, step = 5, fmt = whole,
          tip = "How fast the camera tilts with the keyboard or the mouse." },
        { cvar = "cameraZoomSpeed", kind = "slider", label = "Camera: zoom speed", min = 5, max = 50, step = 5, fmt = whole,
          tip = "How fast the camera zooms in and out." },
        { cvar = "ffxGlow", kind = "check", label = "Glow effect",
          tip = "The soft glow over the whole picture. Off, the picture is crisper." },
        { cvar = "ffxDeath", kind = "check", label = "Grey screen when dead",
          tip = "The grey, washed-out picture while you are a ghost." },
        { cvar = "weatherDensity", kind = "cycle", label = "Weather",
          values = { 0, 1, 2, 3 }, names = { [0] = "off", [1] = "light", [2] = "medium", [3] = "full" },
          tip = "How much rain, snow and sand the game draws." },
    } },
    { title = "When an addon misbehaves", items = {
        { cvar = "scriptErrors", kind = "check", label = "Show Lua errors",
          tip = "The game shows an addon's error the moment it happens. /df errors keeps DeckUIForever's either way." },
        { cvar = "taintLog", kind = "cycle", label = "Blocked actions log",
          values = { 0, 1, 2 }, names = { [0] = "off", [1] = "blocked actions", [2] = "everything" },
          tip = "Writes to Logs\\taint.log why the game blocked an addon's action in combat. For bug reports; leave it off otherwise." },
    } },
}

local function Number(name) return tonumber(GetCVar(name) or "") end

local function CycleText(item)
    local v = Number(item.cvar)
    return item.label .. ": " .. (item.names[v] or tostring(GetCVar(item.cvar)))
end

local function Build(c)
    local f = D.Flow(c)
    c.widgets = c.widgets or {}
    f:Hint("Settings the game has but does not show in its own menu. The game stores them itself. Only what this game knows is listed; /df cvars prints every name and value.")
    local shown = 0
    for _, section in ipairs(D.CONSOLE_SECTIONS) do
        local titled = false
        for _, item in ipairs(section.items) do
            if Exists(item.cvar) then
                if not titled then
                    f:Label(section.title)
                    titled = true
                end
                shown = shown + 1
                local tip = item.tip .. "\n\nConsole name: " .. item.cvar
                if item.kind == "check" then
                    f:Checkbox(item.label, Bools, item.cvar, function() D.RefreshWidgets(c) end, tip)
                elseif item.kind == "slider" then
                    f:Slider(item.label, item.min, item.max, item.step, item.fmt, Numbers, item.cvar,
                        function(v) Set(item.cvar, v) end, tip)
                else
                    local b = f:Button(CycleText(item), function()
                        local now, nextValue = Number(item.cvar), item.values[1]
                        for i, v in ipairs(item.values) do
                            if v == now then nextValue = item.values[i % #item.values + 1] end
                        end
                        Set(item.cvar, nextValue)
                        D.RefreshWidgets(c)
                    end, tip)
                    b:GetFontString():SetFont(D.FONT, 13, "OUTLINE")
                    function b:Refresh() self:SetText(CycleText(item)) end
                    table.insert(c.widgets, b)
                end
            end
        end
        if titled then f:Gap(6) end
    end
    if shown == 0 then
        f:Hint("This game knows none of them.")
        return
    end
    f:Label("All of the above")
    f:Button("Back to the game's defaults", function()
        D.ResetConsole()
        D.RefreshWidgets(c)
    end, "Puts every setting of this page back to what the game ships with. The camera distance button on the Screen page is not touched.")
end

-- every listed CVar the client knows, back to its default
function D.ResetConsole()
    if InCombatLockdown() then
        print("DeckUIForever: not in combat - try again after the fight.")
        return
    end
    local count = 0
    for _, section in ipairs(D.CONSOLE_SECTIONS) do
        for _, item in ipairs(section.items) do
            local default = Exists(item.cvar) and Default(item.cvar)
            if default ~= nil and GetCVar(item.cvar) ~= default and pcall(SetCVar, item.cvar, default) then
                count = count + 1
            end
        end
    end
    print(("DeckUIForever: %d hidden settings put back to the game's defaults."):format(count))
end

-- /df cvars
function D.PrintCVars()
    for _, section in ipairs(D.CONSOLE_SECTIONS) do
        print("DeckUIForever, " .. section.title .. ":")
        for _, item in ipairs(section.items) do
            local value = GetCVar(item.cvar)
            if value == nil then
                print(("  %s: unknown to this game"):format(item.cvar))
            else
                print(("  %s = %s (default %s)"):format(item.cvar, tostring(value), tostring(Default(item.cvar))))
            end
        end
    end
end

D.panel:AddTab("Console", {
    title = "Hidden settings",
    build = Build,
})
