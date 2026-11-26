local ADDON, ns = ...
local D = DeckUIForever

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
local min = function(v) return math.floor(v / 60 + 0.5) .. " min" end
local db  = function() return DeckUIForeverOrbsDB end

-- Moved to D.Flow 2026-10-02: explanations as tooltips, the two settings
-- that need a reload report to the panel's reload bar, and the boss frames
-- got their test button here (it was only /orbs boss). Every text
-- shortened in the menu review of 2026-11-07; the page is "Unit frames"
-- in the sidebar since then.
local loaded = {}   -- settings that need a reload, as this session loaded them

local function Refreshing(button, label)
    function button:Refresh() self:SetText(label()) end
    return button
end

D.RegisterModule("Orbs", {
    title = "Orbs",
    build = function(c)
        loaded.style = loaded.style or DeckUIForeverOrbsDB.style or "orbs"
        loaded.buff = loaded.buff or DeckUIForeverOrbsDB.buffMaxDuration
        if loaded.xivCast == nil then loaded.xivCast = DeckUIForeverOrbsDB.xivCastCenter and true or false end
        if loaded.dotIcons == nil then loaded.dotIcons = DeckUIForeverOrbsDB.dotIcons and true or false end
        if loaded.hotHealer == nil then loaded.hotHealer = DeckUIForeverOrbsDB.hotHealer and true or false end
        if loaded.showPlayer == nil then loaded.showPlayer = DeckUIForeverOrbsDB.showPlayer ~= false end
        if loaded.showTarget == nil then loaded.showTarget = DeckUIForeverOrbsDB.showTarget ~= false end
        if loaded.healPrediction == nil then loaded.healPrediction = DeckUIForeverOrbsDB.healPrediction and true or false end
        local function Built(key)
            return function(v) D.NeedReload("orbs:" .. key, (v and true or false) ~= loaded[key]) end
        end
        local f = D.Flow(c)
        c.widgets = c.widgets or {}

        -- player and target apart (GitHub issue 1, 2026-11-17); party, raid,
        -- focus and bosses have their switches on their own pages
        f:Label("Which frames")
        f:Checkbox("Player frame", db, "showPlayer", Built("showPlayer"),
            "Your own frame, with your pet's beside it. Off, the game's player frame stays as it is - for Blizzard's own or another addon's. Needs a reload.")
        f:Checkbox("Target frame", db, "showTarget", Built("showTarget"),
            "Your target's frame, with its target beside it. Off, the game's target frame stays as it is - for Blizzard's own or another addon's. Needs a reload.")
        f:Gap(4)

        f:Label("Size and look")
        f:Slider("Size (this device)", 0.6, 1.6, 0.05, pct, ns.DeviceDB, "scale", ns.SetScale)
        f:Slider("Opacity", 0.3, 1.0, 0.05, pct, db, "alpha", ns.SetAlpha)
        f:Slider("Brightness", 0.0, 0.5, 0.05, pct, db, "glow", ns.SetGlow,
            "How much the orbs glow from inside.")

        local STYLE_NAMES = { orbs = "Orbs", ff = "Final Fantasy", ffxiv = "Final Fantasy XIV" }
        local STYLE_NEXT = { orbs = "ff", ff = "ffxiv", ffxiv = "orbs" }
        local function HpLabel() return "Health: " .. ns.HP_TEXT_NAMES[DeckUIForeverOrbsDB.hpText or "percent"] end
        local function StyleLabel() return "Style: " .. STYLE_NAMES[DeckUIForeverOrbsDB.style or "orbs"] end
        local hpBtn, styleBtn = f:Pair(
            { text = "Health", title = "Health text", tip = "Percent, the full number, or short like 1.2M.",
              onClick = function(b) ns.CycleHpText(); b:SetText(HpLabel()) end },
            { text = "Style", title = "Style of player and target",
              tip = "Round orbs, Final Fantasy's bars on dark panels, or Final Fantasy XIV's capsule bars without a box. Needs a reload.",
              onClick = function(b)
                  DeckUIForeverOrbsDB.style = STYLE_NEXT[DeckUIForeverOrbsDB.style or "orbs"] or "orbs"
                  b:SetText(StyleLabel())
                  D.NeedReload("orbs:style", DeckUIForeverOrbsDB.style ~= loaded.style)
              end })
        table.insert(c.widgets, Refreshing(hpBtn, HpLabel))
        table.insert(c.widgets, Refreshing(styleBtn, StyleLabel))
        f:More()
        f:Checkbox("Final Fantasy XIV: your cast in the middle", db, "xivCastCenter", function(v)
            D.NeedReload("orbs:xivCast", (v and true or false) ~= loaded.xivCast)
        end, "In the Final Fantasy XIV style your cast shows in the middle of the screen instead of under your bar. Needs a reload.")

        f:Gap(4)
        f:Label("On the frames")
        f:Checkbox("Cast in the orb", db, "showCast", ns.SetCastShown)
        f:Checkbox("Buffs and debuffs", db, "showAuras", ns.SetAurasShown)
        f:More()
        f:Checkbox("Incoming heals on the health bar", db, "healPrediction", Built("healPrediction"),
            "A lighter piece ahead of your health, and your target's, shows how much the heals being cast right now will bring back. Needs a reload.")
        f:Checkbox("Only your own debuffs on the target", db, "ownDebuffsOnly", ns.SetOwnDebuffsOnly)
        f:Checkbox("Class resource dots on the player", db, "showClassPower", ns.SetClassPowerShown,
            "Combo points and the like as dots on your frame.")
        f:Checkbox("Announce a new target (big name)", db, "announceTarget", ns.SetAnnounceTarget)
        f:Slider("Buffs up to this duration", 60, 900, 60, min, db, "buffMaxDuration", function(v)
            ns.SetBuffMaxDuration(v)
            D.NeedReload("orbs:buffDuration", v ~= loaded.buff)
        end, "Longer buffs, like food and flasks, stay off your frame. Needs a reload.")

        f:Hint("Player, target, the buff bar, enemies, your debuffs and your HoTs have pages of their own below.")
    end,
})

-- The buff bar, and the enemies with the bosses: sub-pages of the unit
-- frames since the menu review (2026-10-28), which found that page at
-- ten checkboxes and six sliders.
D.RegisterModule("BuffBar", {
    title = "Buff bar",
    build = function(c)
        local f = D.Flow(c)
        local count = function(v) return tostring(v) end
        local px = function(v) return v .. " px" end
        for _, key in ipairs({ "buffSize", "buffPerRow" }) do
            if loaded[key] == nil then loaded[key] = ns.DeviceDB()[key] end
        end
        for _, key in ipairs({ "buffBar", "buffBarTime", "buffBarDispel" }) do
            if loaded[key] == nil then loaded[key] = DeckUIForeverOrbsDB[key] and true or false end
        end
        -- built in or not: the reload bar against what this session was built with
        local function Rebuild(key)
            return function(v) D.NeedReload("orbs:" .. key, (v and true or false) ~= loaded[key]) end
        end
        local live = function() ns.ApplyBuffBar() end
        local function Live(key)
            return function(v) DeckUIForeverOrbsDB[key] = v; ns.ApplyBuffBar() end
        end
        local seconds = function(v)
            if v <= 0 then return "all" end
            if v >= 60 then return math.floor(v / 60 + 0.5) .. " min" end
            return v .. " s"
        end
        f:Checkbox("Own buff bar in Final Fantasy style", db, "buffBar", Rebuild("buffBar"),
            "Replaces Blizzard's buffs at the top right: buffs from the right, debuffs from the left, the time under each icon. Right click cancels a buff. Needs a reload; move it with Move below.")
        f:More()
        f:Slider("Icon size (this device)", 18, 40, 1, px, ns.DeviceDB, "buffSize", function(v)
            ns.DeviceDB().buffSize = v
            D.NeedReload("orbs:buffSize", v ~= loaded.buffSize)
        end, "Needs a reload.")
        f:Slider("Icons per row (this device)", 6, 20, 1, count, ns.DeviceDB, "buffPerRow", function(v)
            ns.DeviceDB().buffPerRow = v
            D.NeedReload("orbs:buffPerRow", v ~= loaded.buffPerRow)
        end, "Needs a reload.")

        f:Gap(4)
        f:Label("What shows")
        f:Checkbox("Buffs", db, "buffBarBuffs", live, "Your buffs, from the right edge.")
        f:Checkbox("Debuffs", db, "buffBarDebuffs", live, "Your debuffs, from the left edge.")
        f:Checkbox("Weapon enchants", db, "buffBarEnchants", live,
            "Oils, stones and imbues, with their time left, before the buffs.")
        f:More()
        f:Checkbox("Keep the bar in combat", db, "buffBarCombatKeep", live,
            "In combat the bar stays as it is out of combat; the two limits below are ignored.")
        f:Slider("In combat: buffs up to", 0, 600, 10, seconds, db, "buffBarCombatMax", Live("buffBarCombatMax"),
            "In combat only buffs this short show, such as procs. 0 shows every buff.")
        f:Checkbox("Hide buffs in combat", db, "buffBarCombatHide", live,
            "In combat the buffs leave the bar; debuffs and weapon enchants stay.")
        f:Checkbox("Out of combat: every buff", db, "buffBarAllOut", live,
            "Out of combat the limit above is lifted and every buff shows.")
        f:Slider("Buff rows", 1, 3, 1, count, db, "buffRows", Live("buffRows"),
            "How many rows the buffs may fill.")
        f:Slider("Debuffs at most", 0, 16, 1, count, db, "buffDebuffMax", Live("buffDebuffMax"),
            "0 for none.")

        f:Gap(4)
        f:MoreSection("Look")
        f:Checkbox("Time below the icons", db, "buffBarTime", Rebuild("buffBarTime"),
            "The time left under each icon. Needs a reload.")
        f:Checkbox("Dispel colour above debuffs", db, "buffBarDispel", Rebuild("buffBarDispel"),
            "A short strip in the dispel colour above a debuff. Needs a reload.")
    end,
})

D.RegisterModule("Enemies", {
    title = "Enemies and bosses",
    build = function(c)
        local f = D.Flow(c)
        c.widgets = c.widgets or {}
        f:Label("Enemy list")
        f:Checkbox("Enemy list", db, "enemyList", ns.SetEnemyList,
            "Final Fantasy XIV's list of the enemies fighting you: name, health, a red square while one targets you. Needs enemy nameplates on. Move it with Move below.")

        f:Label("Focus and bosses")
        f:Checkbox("Focus frame", db, "showFocus", ns.SetFocusShown)
        f:Checkbox("Boss frames (hide Blizzard's)", db, "showBoss", ns.SetBossShown)
        loaded.bossStyle = loaded.bossStyle or DeckUIForeverOrbsDB.bossStyle or "auto"
        f:More()
        f:Cycles({ label = "Boss look", values = { "auto", "orbs", "ff", "xiv" },
            names = { auto = "Follows the style", orbs = "Orbs", ff = "Final Fantasy", xiv = "Final Fantasy XIV" },
            tip = "Orbs, dark panels or Final Fantasy XIV's capsules for the bosses. Needs a reload.",
            get = function() return DeckUIForeverOrbsDB.bossStyle or "auto" end,
            set = function(v)
                DeckUIForeverOrbsDB.bossStyle = v
                D.NeedReload("orbs:bossStyle", v ~= loaded.bossStyle)
            end })
        local bossBtn = f:Button("Test boss frames", function(b)
            ns.SetBossTest(not ns.bossTestOn)
            C_Timer.After(0, function() b:Refresh() end)
        end, "Five boss frames showing your target, to see size and place. Also /orbs boss.")
        table.insert(c.widgets, Refreshing(bossBtn, function()
            return ns.bossTestOn and "End boss test" or "Test boss frames"
        end))
    end,
})

-- Player, Target and Target of target: a page each under the unit frames
-- (owner's wish 2026-10-28) for the Final Fantasy frames' width, bar
-- height and where their buffs and debuffs go. oUF builds a frame once,
-- so every change here reports to the reload bar; `loaded` keeps what this
-- session was built with, so a value put back clears the request.
local function Snap(k, get) if loaded[k] == nil then loaded[k] = get() end end
local function Need(k, v) D.NeedReload("orbs:" .. k, v ~= loaded[k]) end
local px = function(v) return math.floor(v + 0.5) .. " px" end
local count = function(v) return tostring(v) end
local SIDES, SIDE_NAMES = { "below", "above", "off" }, { below = "Below", above = "Above", off = "Off" }

local function Side(label, key, tip)
    return { label = label, values = SIDES, names = SIDE_NAMES, tip = tip .. " Needs a reload.",
             get = function() return DeckUIForeverOrbsDB[key] or "below" end,
             set = function(v) DeckUIForeverOrbsDB[key] = v; Need(key, v) end }
end

local function Plain(key)
    return function(v) DeckUIForeverOrbsDB[key] = v; Need(key, v) end
end

-- width and bar height as a percentage of the style's own numbers: 100%
-- is the Final Fantasy look as shipped (owner, 2026-10-28)
local pct = function(v) return math.floor(v + 0.5) .. "%" end
local function SizeSliders(f, prefix)
    local sz = ns.FrameSizeDB
    Snap(prefix .. "Width", function() return sz()[prefix .. "Width"] end)
    Snap(prefix .. "Bar", function() return sz()[prefix .. "Bar"] end)
    f:Label("Size (this device)")
    f:Slider("Width", 50, 200, 5, pct, sz, prefix .. "Width", function(v)
        sz()[prefix .. "Width"] = v
        Need(prefix .. "Width", v)
    end, "100% is the style's own width. Needs a reload.")
    f:Slider("Bar height", 50, 250, 10, pct, sz, prefix .. "Bar", function(v)
        sz()[prefix .. "Bar"] = v
        Need(prefix .. "Bar", v)
    end, "The health bar's thickness. Needs a reload.")
end

D.RegisterModule("FramePlayer", {
    title = "Player",
    build = function(c)
        local f = D.Flow(c)
        for _, k in ipairs({ "playerBuffs", "playerDebuffs", "playerBuffsRight", "playerAuraShapes",
                             "playerAuraSize", "playerBuffMax", "playerDebuffMax" }) do
            Snap(k, function() return DeckUIForeverOrbsDB[k] end)
        end
        f:Hint("Your bar in the Final Fantasy styles. Everything here needs a reload.")
        SizeSliders(f, "player")
        f:Label("Buffs and debuffs")
        f:Cycles(
            Side("Buffs", "playerBuffs",
                "Your buffs above the bar, below the cast, or off. The buff bar replaces them while it is on."),
            Side("Debuffs", "playerDebuffs",
                "Your debuffs above the bar, below the cast, or off."))
        f:More()
        f:Checkbox("Buffs from the right edge", db, "playerBuffsRight", function(v) Need("playerBuffsRight", v) end,
            "The buffs start at the right edge and grow left, so they share a line with the debuffs. Needs a reload.")
        f:Checkbox("Final Fantasy XIV shapes", db, "playerAuraShapes", function(v) Need("playerAuraShapes", v) end,
            "Buff icons with a roof, debuff icons with a point, as on the target. Needs a reload.")
        f:Slider("Icon size", 14, 32, 1, px, db, "playerAuraSize", Plain("playerAuraSize"), "Needs a reload.")
        f:Slider("Buffs at most", 0, 20, 1, count, db, "playerBuffMax", Plain("playerBuffMax"), "Needs a reload.")
        f:Slider("Debuffs at most", 0, 20, 1, count, db, "playerDebuffMax", Plain("playerDebuffMax"), "Needs a reload.")
    end,
})

D.RegisterModule("FrameTarget", {
    title = "Target",
    build = function(c)
        local f = D.Flow(c)
        for _, k in ipairs({ "targetDebuffs", "targetBuffs", "targetBuffsRight", "targetAuraSize", "targetDebuffMax", "targetBuffMax" }) do
            Snap(k, function() return DeckUIForeverOrbsDB[k] end)
        end
        f:Hint("The target bar in the Final Fantasy styles. Everything here needs a reload.")
        SizeSliders(f, "target")
        f:Label("Buffs and debuffs")
        f:Cycles(
            Side("Debuffs", "targetDebuffs", "Its debuffs below the cast, above the bar, or off."),
            Side("Buffs", "targetBuffs", "Its buffs below the cast, above the bar, or off."))
        f:More()
        f:Checkbox("Buffs from the right edge", db, "targetBuffsRight", function(v) Need("targetBuffsRight", v) end,
            "The buffs start at the right edge and grow left, so they share a line with the debuffs. Needs a reload.")
        f:Slider("Icon size", 14, 32, 1, px, db, "targetAuraSize", Plain("targetAuraSize"), "Needs a reload.")
        f:Slider("Debuffs at most", 0, 16, 1, count, db, "targetDebuffMax", Plain("targetDebuffMax"), "Needs a reload.")
        f:Slider("Buffs at most", 0, 16, 1, count, db, "targetBuffMax", Plain("targetBuffMax"), "Needs a reload.")
    end,
})

D.RegisterModule("FrameToT", {
    title = "Target of target",
    build = function(c)
        local f = D.Flow(c)
        Snap("totDebuffs", function() return DeckUIForeverOrbsDB.totDebuffs end)
        f:Hint("The small bar beside the target in the Final Fantasy styles. Everything here needs a reload.")
        SizeSliders(f, "tot")
        f:Label("Debuffs")
        f:Checkbox("Your debuffs under it", db, "totDebuffs", function(v) Need("totDebuffs", v) end,
            "Up to six. Needs a reload.")
    end,
})

-- Your debuffs have a page of their own under the unit frames (owner's
-- wish 2026-10-28, easier to find; D.PAGE_PARENT indents it there).
D.RegisterModule("Debuffs", {
    title = "Debuffs",
    build = function(c)
        local f = D.Flow(c)
        f:Hint("The debuffs your class keeps on enemies - DoTs, bleeds, curses - for your target and your focus. /orbs dots prints what the window sees.")
        f:Label("Window")
        f:Checkbox("Show the debuff window", db, "dotTracker", ns.SetDotTracker,
            "A column for your target and a smaller one for your focus. One capsule per debuff, filled by the game while it runs. A debuff you have not cast is an empty capsule with a red edge in combat. Gold means the last third: refresh now and nothing is lost. Your other debuffs on the target follow below.")
        f:Checkbox("Round icons instead of capsules", db, "dotIcons", function(v)
            D.NeedReload("orbs:dotIcons", (v and true or false) ~= loaded.dotIcons)
        end, "The name, then one round icon per debuff with a clock that closes as it runs out, then your other debuffs as icons. Needs a reload.")
        f:More()
        f:Slider("Width, or icon size (this device)", 50, 175, 5, pct, ns.DeviceDB, "dotScale", function(v)
            ns.DeviceDB().dotScale = v
            ns.ApplyDotWidth()
        end, "Capsules: how wide the rows are, 100% is 240 pixels. Round icons: how big they are, 100% is 22 pixels.")
        f:Checkbox("Show the names", db, "dotNames", function() ns.ApplyDotNames() end,
            "Capsules only: the debuff's name between icon and capsule. Off, the capsule gets that room. Running capsules follow after a reload.")
        f:Checkbox("Empty capsules out of combat", db, "dotIdle", nil,
            "Out of combat, a dimmed empty capsule (or icon) for every debuff you have not cast. Off, only running debuffs show - nothing at all when none runs.")
        f:Checkbox("Keep enemies you switch away from", db, "dotKeep", nil,
            "An enemy you stop targeting keeps a small column while your debuffs run on it, up to four. Needs its nameplate on screen. Window only.")
        f:MoreSection("Place")
        f:Checkbox("At the target frame instead of a window", db, "dotAttach", function() ns.ApplyDotLayout() end,
            "The rows hang at your target frame, the focus column at your focus frame. Off, the debuffs have a window of their own - move it with Move below.")
        f:Checkbox("Above the frame instead of below", db, "dotAbove", function() ns.ApplyDotLayout() end,
            "With the rows at the target frame: above it rather than below.")
        f:Checkbox("Sample rows while moving", db, "dotPreview", nil,
            "With Move or /df unlock the window shows three example rows instead of an empty box.")
        if D.CooldownManagerAvailable and D.CooldownManagerAvailable() then
            f:MoreSection("Blizzard's Cooldown Manager")
            f:Checkbox("Leave the target's debuffs to the Cooldown Manager", db, "dotManager", nil,
                "A debuff that sits in one of the Cooldown Manager's two buff bars leaves this window's target column - the manager shows it for your target. Your focus, the enemies you switched away from and every debuff the manager does not offer stay here. The red empty capsule for a missing debuff goes with it. /df cooldowns prints which debuffs the manager shows.")
            f:Checkbox("Hang the window below the Cooldown Manager's bars", db, "dotUnderManager", nil,
                "The window follows the manager's buff bars - or its buff icons while the bars are hidden - instead of its own place. Move the manager's bars in the game's Edit Mode.")
        end
    end,
})

-- The healer's counterpart (owner 2026-11-06), rebuilt around the party
-- on 2026-11-07: a line per party member - name, a round icon per heal
-- with a closing clock, the buffs on them - a stranger only while
-- targeted. heals.lua.
-- The buff window (buffcheck.lua): the missing buffs, out of the HoT window
-- since 2026-11-17 (owner: "ein separates Buff-Fenster").
D.RegisterModule("BuffCheck", {
    title = "Missing buffs",
    build = function(c)
        local f = D.Flow(c)
        if loaded.buffCheck == nil then loaded.buffCheck = DeckUIForeverOrbsDB.buffCheck and true or false end
        if loaded.buffCheckScale == nil then loaded.buffCheckScale = ns.DeviceDB().buffCheckScale end
        f:Hint("A small window that says who in your party lacks a buff you can cast - Fortitude, Mark of the Wild, Arcane Intellect and the like. /orbs buffs prints what it sees.")
        f:Label("Window")
        f:Checkbox("Show the buff window", db, "buffCheck", function(v)
            D.NeedReload("orbs:buffCheck", (v and true or false) ~= loaded.buffCheck)
        end, "A line for you and each party member, with one round icon per buff they lack - no matter who cast it. Click an icon to cast the buff on that member. Whoever has everything shows nothing, so a fully buffed party leaves the window empty. Not for pets. During a fight a buff that drops may show late; it catches up when the fight ends. Needs a reload; move it with Move below.")
        f:Slider("Icon size (this device)", 50, 175, 5, function(v) return math.floor(v + 0.5) .. "%" end,
            ns.DeviceDB, "buffCheckScale", function(v)
                ns.DeviceDB().buffCheckScale = v
                D.NeedReload("orbs:buffCheckScale", v ~= loaded.buffCheckScale)
            end, "100% is 22 pixels. Needs a reload.")
    end,
})

-- Deck Heal (owner 2026-11-11: "als Option und Unterfenster von HoTs ...
-- alles muss ausschaltbar sein"): healing with the controller, a held key
-- turns the D-pad and the face buttons into a healing layer. padheal.lua.
D.RegisterModule("DeckHeal", {
    title = "Deck Heal",
    build = function(c)
        local f = D.Flow(c)
        c.widgets = c.widgets or {}
        f:Hint("Heal with the controller, without mouse or target change. Hold a key: the D-pad picks a party member, the four face buttons cast a spell on them. Let go and every key is back to normal.")
        f:Label("The layer")
        f:Checkbox("Use Deck Heal", db, "padHeal", function() ns.ApplyPadHeal() end,
            "While you hold the Deck Heal key: A, X, Y, B cast your four spells on the tank (on you in a group without one). D-pad left picks the healer, up, right, down the three damage dealers; press the picked member's direction again to go back to the tank. In a group without roles it starts on you and the D-pad picks party member 1 to 4. Your target stays as it is. Works in combat and without the HoT window. Off, nothing changes on your controller.")
        -- made with the longer text, so the page keeps room for two lines
        local NO_KEY = "No key yet: Options, Key Bindings, AddOns, \"Deck Heal: healing layer\"."
        local keyHint = f:Hint(NO_KEY)
        function keyHint:Refresh()
            local key = ns.PadHealKey()
            self:SetText(key and ("Deck Heal key: " .. key) or NO_KEY)
        end
        keyHint:Refresh()
        table.insert(c.widgets, keyHint)
        f:Checkbox("Use the friend-targeting button (L)", db, "padHealModifier", function()
                ns.ApplyPadHeal()
                keyHint:Refresh()
            end,
            "With a controller, the button you hold to pick a friend (L) is the Deck Heal key: hold it, pick with the D-pad, heal with A, X, Y, B. The game's own friend targeting on that button rests while Deck Heal is on. Off, only a key you bind yourself opens the layer.")
        f:More()
        f:Checkbox("Aim at friends while holding the key", db, "padHealAim", function() ns.ApplyPadHeal() end,
            "While you hold the Deck Heal key, the game picks friends as your target the way it does without Deck Heal: turn towards someone and they become your target. The heals on A, X, Y, B still go to the member picked with the D-pad, not to your target. Off, holding the key never changes your target.")
        f:Checkbox("Press to switch instead of hold", db, "padHealToggle", function() ns.ApplyPadHeal() end,
            "One press of the key turns the layer on, the next turns it off. For when holding a key is awkward, or if letting go is not noticed on your device.")
        f:Label("Spells")
        f:Checkbox("Second set of spells with R", db, "padHealR", function() ns.ApplyPadHeal() end,
            "Four more spells: while you hold the Deck Heal key, hold R as well and A, X, Y, B cast spells five to eight. Let go of R and the first four are back. Without the Deck Heal key, R does what it always does.")
        f:Hint("Up to four spells for A, X, Y, B - eight with the second set - by name or ID, separated by commas. Buttons you leave free get your HoTs first, then your heals from the weakest to the strongest, then your cures. Press Enter to save.")
        f:Add(30, function(parent, y)
            local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
            edit:SetSize(300, 20)
            edit:SetPoint("TOP", 0, y)
            edit:SetAutoFocus(false)
            edit:SetFontObject(ChatFontNormal)
            edit:SetScript("OnEnterPressed", function(self)
                DeckUIForeverOrbsDB.padHealSpells = strtrim(self:GetText() or "")
                self:ClearFocus()
                ns.ApplyPadHeal()
            end)
            edit:SetScript("OnEscapePressed", function(self)
                self:SetText(DeckUIForeverOrbsDB.padHealSpells or "")
                self:ClearFocus()
            end)
            edit:SetScript("OnShow", function(self) self:SetText(DeckUIForeverOrbsDB.padHealSpells or "") end)
            edit:SetText(DeckUIForeverOrbsDB.padHealSpells or "")
            D.Tip(edit, "Deck Heal spells", "For example: Renew, Power Word: Shield, Flash Heal, Dispel Magic. With the second set the fifth to eighth spell are the ones on R. Only spells your character knows are taken; /orbs deckheal lists what each button casts. A change during a fight takes effect after it.")
            return edit
        end)
        f:Label("After the fight")
        f:Checkbox("Buff and resurrection round", db, "padHealRound", function() ns.ApplyPadHeal() end,
            "Out of combat, hold the Deck Heal key and click the right stick: it casts the next thing your group needs - first your resurrection on a dead member, then your buffs on whoever lacks one. One cast per click; a small line above the bar says what the next click does. Never in combat.")
        f:Label("What you see")
        f:Checkbox("Bar with member and spells", db, "padHealBar", function() ns.ApplyPadHeal() end,
            "While the layer is on, a small bar shows who is picked and which button casts which spell. Move it with Move below.")
        f:Checkbox("Keys on the party row instead of the bar", db, "padHealRows", function() ns.ApplyPadHeal() end,
            "With the heals on the party list: while the layer is on, the picked member's row shows each button's picture on the icon it casts, and the bar stays away. If one of your own spells has no icon on the row, the bar shows as before.")
        f:Checkbox("Health, HoTs and debuffs on the bar", db, "padHealCockpit", function() ns.ApplyPadHeal() end,
            "The bar also shows the picked member's health under the name and, after the four spells, a debuff you can remove (red rim) and your HoTs on them with their clocks.")
        f:Checkbox("Spell icons show what is possible", db, "padHealFeedback", function() ns.ApplyPadHeal() end,
            "On the bar a spell on cooldown shows a closing clock with the time, a spell you lack the mana for turns grey, and a spell the picked member is too far away for turns red.")
        f:More()
        f:Checkbox("Gold frame around the picked member", db, "padHealFrame", function() ns.ApplyPadHeal() end,
            "While the layer is on, the picked member's row of the party list gets a gold frame (with the heals on the party list). Not in the raid.")
    end,
})

-- The party list has a tab of its own: the Orbs tab is full, and the
-- window cannot grow on the Deck's 800-pixel screen. The raid frames got
-- theirs when they gained their settings (2026-10-02).
-- A test button that says whether its test runs: label(on) gives the text
local function TestButton(f, c, label, isOn, toggle, tip)
    local b = f:Button(label(false), function(self)
        toggle()
        C_Timer.After(0, function() self:Refresh() end)
    end, tip)
    function b:Refresh() self:SetText(label(isOn())) end
    table.insert(c.widgets, b)
    return b
end

-- the look of party and raid alike, on both pages; needs a reload
local function GroupLook()
    return { label = "Look", values = { "panel", "xiv" },
             names = { panel = "Dark panels", xiv = "Final Fantasy XIV" },
             tip = "Dark panels with bars, or Final Fantasy XIV's capsules without a box. For the party list and the raid frames alike. Needs a reload.",
             get = function() return DeckUIForeverOrbsDB.groupStyle or "panel" end,
             set = function(v)
                 DeckUIForeverOrbsDB.groupStyle = v
                 if loaded.groupStyle == nil then loaded.groupStyle = "panel" end
                 D.NeedReload("orbs:groupStyle", v ~= loaded.groupStyle)
             end }
end

D.RegisterModule("Group", {
    title = "Group",
    build = function(c)
        if loaded.showParty == nil then loaded.showParty = DeckUIForeverOrbsDB.showParty end
        if loaded.groupStyle == nil then loaded.groupStyle = DeckUIForeverOrbsDB.groupStyle end
        local f = D.Flow(c)
        c.widgets = c.widgets or {}

        f:Label("Party list")
        f:Checkbox("Show the party list (hides Blizzard's)", db, "showParty", function(v)
            D.NeedReload("orbs:showParty", v ~= loaded.showParty)
        end, "Rows like Final Fantasy XIV: class icon, name, health and auras, tanks first. Party only; in a raid the raid frames take over. Needs a reload.")
        TestButton(f, c, function(on) return on and "End party test" or "Test: five rows of you" end,
            function() return ns.partyTest end, function() ns.SetPartyTest(not ns.partyTest) end,
            "Five rows of you, to see size and place. Also /orbs test.")

        f:Cycles(GroupLook())

        if loaded.partyHeal == nil then loaded.partyHeal = DeckUIForeverOrbsDB.partyHeal and true or false end
        f:Gap(4)
        f:Label("Healing")
        f:Checkbox("HoTs, heals and cures on the party list", db, "partyHeal", function(v)
            D.NeedReload("orbs:partyHeal", (v and true or false) ~= loaded.partyHeal)
        end, "The healer's window (it replaces the HoT window of earlier versions): after each row a round icon per HoT of yours - the clock closes as it runs out, gold in the last third, red in combat while it is missing - then your heals, a cure while there is something to remove, and the resurrection on a dead member. Click an icon to cast it on that member, in combat too. The game itself sorts and fills the rows during a fight, so nothing waits for the end of it. Deck Heal works on the rows. Needs the party list and a reload.")
        if loaded.hotPets == nil then loaded.hotPets = DeckUIForeverOrbsDB.hotPets and true or false end
        if loaded.hotStranger == nil then loaded.hotStranger = DeckUIForeverOrbsDB.hotStranger ~= false end
        f:Checkbox("Pets under their owners", db, "hotPets", function(v)
            D.NeedReload("orbs:hotPets", (v and true or false) ~= loaded.hotPets)
        end, "With the heals on the party list: a small line under each row for that member's pet - name, health and your HoTs, heals and cures a size smaller, in the same columns. The rows stand a little further apart for it. Needs a reload.")
        f:Checkbox("A line for a target outside the group", db, "hotStranger", function(v)
            D.NeedReload("orbs:partyStranger", (v and true or false) ~= loaded.hotStranger)
        end, "With the heals on the party list: a friendly target that is not in your group gets a line above the list while you target it, with the same icons to click. Needs a reload.")
        if loaded.hotRaid == nil then loaded.hotRaid = DeckUIForeverOrbsDB.hotRaid and true or false end
        f:Checkbox("Heal icons under the raid tiles", db, "hotRaid", function(v)
            D.NeedReload("orbs:hotRaid", (v and true or false) ~= loaded.hotRaid)
        end, "With the heals on the party list and our raid frames on: every raid tile gets the same icons to click in a line under it, as small as it takes to fit the tile's width - a wider tile gives bigger icons. The tiles stand a little further apart for it. Off, or with Blizzard's raid frames, the party list stays in a raid and lists your raid group. Needs a reload.")
        if loaded.hotAllBuffs == nil then loaded.hotAllBuffs = DeckUIForeverOrbsDB.hotAllBuffs and true or false end
        f:Checkbox("Every buff on the rows, not only yours", db, "hotAllBuffs", function(v)
            D.NeedReload("orbs:partyAllBuffs", (v and true or false) ~= loaded.hotAllBuffs)
        end, "With the heals on the party list: after the debuffs each row shows every buff on the member, up to ten, instead of your own four. Your HoTs stay out, they have their icons. Needs a reload.")
        f:Checkbox("Mana regeneration above the list", db, "hotRegen", nil,
            "Your mana per five seconds right now, and the other rate beside it in grey - above the party list, in a raid above the raid frames.")
        f:Checkbox("Hide your HoTs from the target frame", db, "hotExclude", function() ns.ApplyHotExclusion() end,
            "Your HoTs have their icons on the party list, so they leave the buff icons on the target frame. Off, the target frame keeps all its icons.")
        f:Checkbox("Controller keys on the rows (Steam Deck)", db, "hotPadHints", nil,
            "Shows at each row which controller key targets that member while you hold the target modifier - or, with Deck Heal on, which D-pad key picks them. Only in the gamepad style, not in a raid.")
        f:Hint("Your own spells for the heal icons, by name or ID, separated by commas. Each gets an icon like a HoT. Press Enter to save.")
        f:Add(30, function(parent, y)
            local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
            edit:SetSize(300, 20)
            edit:SetPoint("TOP", 0, y)
            edit:SetAutoFocus(false)
            edit:SetFontObject(ChatFontNormal)
            local function Save(self)
                DeckUIForeverOrbsDB.hotCustom = strtrim(self:GetText() or "")
                self:ClearFocus()
                if ns.PartyHealSync then ns.PartyHealSync() end
            end
            edit:SetScript("OnEnterPressed", Save)
            edit:SetScript("OnEscapePressed", function(self)
                self:SetText(DeckUIForeverOrbsDB.hotCustom or "")
                self:ClearFocus()
            end)
            edit:SetScript("OnShow", function(self) self:SetText(DeckUIForeverOrbsDB.hotCustom or "") end)
            edit:SetText(DeckUIForeverOrbsDB.hotCustom or "")
            D.Tip(edit, "Your own spells", "For example: Blessing of Might, Fear Ward. Only spells your character knows are taken; /orbs hots lists what was not recognised. Empty the box and press Enter to remove them.")
            return edit
        end)
        f:Checkbox("Cooldown timers on the heal icons", db, "hotCooldown", function()
            if ns.PartyHealCooldowns then ns.PartyHealCooldowns() end
        end, "A spell on cooldown shows it on its icon: the dark sweep with the time on a heal, a small number on the top edge of a HoT.")
        f:Checkbox("Blink before a HoT ends", db, "hotWarn", nil,
            "A red pulse over a HoT of yours in its last seconds. Where the game hides the time during a fight, the gold rim of the last third is the warning.")
        f:Checkbox("Sound before a HoT ends", db, "hotWarnSound", nil,
            "One short sound when a HoT of yours enters its last seconds, once a second at most.")
        f:Slider("Seconds before the end", 1, 10, 1, function(v) return v .. " s" end, db, "hotWarnAt",
            function(v) DeckUIForeverOrbsDB.hotWarnAt = v end)
        f:Slider("Heal icon size", 50, 175, 5, function(v) return v .. "%" end, ns.DeviceDB, "hotScale", function(v)
            ns.DeviceDB().hotScale = v
            if ns.ApplyPartyHealSize then ns.ApplyPartyHealSize() end
        end, "100% is 24 pixels. The places change at once out of combat, the icons after a reload.")

        f:Gap(4)
        f:Label("Layout (this device)")
        f:Checkbox("Side by side", ns.DeviceDB, "partyAcross", function()
            ns.ApplyPartyLayout()
            if ns.ApplyPartyHealSize then ns.ApplyPartyHealSize() end
        end, "The rows next to each other instead of one below the other.")
        f:Slider("Size", 0.6, 1.6, 0.05, pct, ns.DeviceDB, "partyScale", function(v)
            ns.DeviceDB().partyScale = v
            ns.ApplyPartyScale()
        end)
    end,
})

local look = function() ns.ApplyRaidLook() end
local layout = function() if ns.ApplyRaidLayout then ns.ApplyRaidLayout() end end

-- a shared raid setting for Flow:Cycles
local function RaidSetting(label, key, values, names, apply, tip)
    return { label = label, values = values, names = names, tip = tip,
             get = function() return DeckUIForeverOrbsDB[key] end,
             set = function(v) DeckUIForeverOrbsDB[key] = v; apply(v) end }
end

-- a raid setting that only takes effect after a reload
local function ReloadAfter(key)
    return function(v) D.NeedReload("orbs:" .. key, v ~= loaded[key]) end
end

local function Counts()
    local t = {}
    for i = 0, 6 do t[i] = tostring(i) end
    return { 0, 1, 2, 3, 4, 5, 6 }, t
end
local function Percents(list)
    local names = {}
    for _, v in ipairs(list) do names[v] = math.floor(v * 100 + 0.5) .. "%" end
    return list, names
end

D.RegisterModule("Raid", {
    title = "Raid",
    build = function(c)
        for _, key in ipairs({ "showRaid", "raidDebuffs", "raidBuffs", "raidDispelOnly" }) do
            if loaded[key] == nil then loaded[key] = DeckUIForeverOrbsDB[key] end
        end
        local f = D.Flow(c)
        c.widgets = c.widgets or {}
        local px = function(v) return math.floor(v + 0.5) .. " px" end

        f:Label("Raid frames")
        f:Checkbox("Show the raid frames (hides Blizzard's)", db, "showRaid", ReloadAfter("showRaid"),
            "A small tile per member. Blizzard's raid tools on the left stay. Needs a reload.")
        TestButton(f, c, function(on) return on and "End raid test" or "Test: a raid of you" end,
            function() return ns.raidTest end, function() ns.SetRaidTest(not ns.raidTest) end,
            "Forty tiles of you, to see size and place. Also /orbs raid.")

        f:Gap(4)
        f:Label("Size and arrangement (this device)")
        f:Slider("Size", 0.5, 1.4, 0.05, pct, ns.DeviceDB, "raidScale", function(v)
            ns.DeviceDB().raidScale = v
            ns.ApplyRaidScale()
        end)
        f:More()
        f:Slider("Width", 60, 140, 2, px, ns.DeviceDB, "raidW", function(v)
            ns.DeviceDB().raidW = v
            layout()
            if ns.ApplyPartyHealSize then ns.ApplyPartyHealSize() end   -- the heal icons under the tiles fit the width
        end)
        f:Slider("Height", 30, 60, 2, px, ns.DeviceDB, "raidH", function(v)
            ns.DeviceDB().raidH = v
            layout()
        end)
        f:Cycles(
            { label = "Groups", values = { false, true }, names = { [false] = "Columns", [true] = "Rows" },
              tip = "Each raid group as a column, or as a row.",
              get = function() return ns.DeviceDB().raidRows and true or false end,
              set = function(v) ns.DeviceDB().raidRows = v; layout() end },
            RaidSetting("Sort", "raidSort", { "group", "role", "class" },
                { group = "Group", role = "Role", class = "Class" }, layout,
                "By group as the raid leader set them, or by role or class."))

        f:Gap(4)
        f:Label("Look")
        if loaded.groupStyle == nil then loaded.groupStyle = DeckUIForeverOrbsDB.groupStyle end
        f:Cycles(GroupLook())
        f:More()
        f:Cycles(
            RaidSetting("Bar", "raidColor", { "ff", "class" }, { ff = "FF green", class = "Class" }, look),
            RaidSetting("Health", "raidHpText", { "none", "percent", "short" },
                { none = "None", percent = "Percent", short = "1.2M" }, look))
        local bgs, bgNames = Percents({ 0.5, 0.6, 0.7, 0.8, 0.9, 1 })
        local ranges, rangeNames = Percents({ 0.2, 0.3, 0.4, 0.5, 0.6, 0.8 })
        f:Cycles(
            RaidSetting("Background", "raidBgAlpha", bgs, bgNames, look),
            RaidSetting("Out of range", "raidRangeAlpha", ranges, rangeNames, look,
                "How faded a member out of your range is."))
        f:Checkbox("Frame the tile in the dispel colour", db, "raidDispelGlow", look,
            "Only for debuffs you can dispel.")
        f:Checkbox("Red edge while a member has aggro", db, "raidAggro", look)
        f:Checkbox("Mana bar for healers", db, "raidMana", look)
        f:Checkbox("Role icons for tanks and healers", db, "raidRoles", look)

        f:Gap(4)
        f:MoreSection("Auras (need a reload)")
        local counts, countNames = Counts()
        f:Cycles(
            RaidSetting("Debuffs", "raidDebuffs", counts, countNames, ReloadAfter("raidDebuffs"),
                "Top right of the tile."),
            RaidSetting("Own buffs", "raidBuffs", counts, countNames, ReloadAfter("raidBuffs"),
                "Bottom right: your HoTs and shields."))
        f:Checkbox("Only debuffs you can dispel", db, "raidDispelOnly", ReloadAfter("raidDispelOnly"))
    end,
})
