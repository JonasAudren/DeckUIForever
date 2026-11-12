local ADDON, ns = ...
local D = DeckUIForever

local db = function() return DeckUIForeverQuestingDB end
local device = function() return ns.DeviceDB() end
local nothing = function() end

-- Texts in the style of the menu review of 2026-11-07: a label of a few
-- words, two or three plain sentences on mouse-over.
D.RegisterModule("Questing", {
    title = "Questing",
    build = function(c)
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        f:Hint("Hold the pause key at an NPC and nothing happens by itself. /questing ignore at an NPC leaves that NPC alone for good.")

        f:Label("At the NPC")
        local other = ns.OtherHelper and ns.OtherHelper()
        if other then
            f:Hint(other .. " handles the NPC dialog already, so the switches below rest until it is off.")
        end
        f:Checkbox("Take the quests an NPC offers", db, "autoAccept", nothing,
            "Talking to a quest giver accepts the quest without a click. Grey quests are left unless the next switch is on.")
        f:More()
        f:Checkbox("Grey quests too", db, "acceptTrivial", nothing,
            "Quests far below your level are taken as well.")
        f:Checkbox("Shared and escort quests", db, "acceptShared", nothing,
            "A quest a party member shares, or an escort a party member starts, is accepted.")
        f:Basic()
        f:Checkbox("Hand in finished quests", db, "autoTurnIn", nothing,
            "A finished quest is handed in, and the reward taken when there is nothing to choose. With a choice the window stays open.")
        f:Checkbox("Skip the small talk", db, "autoGossip", nothing,
            "An NPC with one line of talk and no quest is talked to without a click. Vendors, trainers, flight masters and bankers are left alone.")
        f:More()
        f:Checkbox("Share new quests with the party", db, "autoShare", nothing,
            "Every quest you take is offered to your party.")
        f:Checkbox("Say what was done in the chat", db, "announce", nothing)
        f:Cycles({
            label = "Pause key", values = ns.PAUSE_KEYS, names = ns.PAUSE_NAMES,
            get = function() return db().pauseKey or "shift" end,
            set = function(v) db().pauseKey = v end,
            tip = "Held while talking to an NPC, nothing happens by itself. On the Steam Deck the left trigger is Shift, the left bumper Ctrl.",
        })

        f:Label("The reward")
        f:Checkbox("Mark the reward worth taking", db, "rewardMarks", nothing,
            "With a choice of rewards, a coin marks the one that sells for the most and a green arrow one that would be an upgrade. The vendor price stands in the corner.")
        f:More()
        f:Checkbox("Take the most valuable when nothing is an upgrade", db, "rewardAuto", nothing,
            "With no upgrade among the choices, the quest is handed in and the coin's item taken. Needs the hand-in switch above.")

        f:Label("The tracker")
        f:Checkbox("Track the quests of the zone you enter", db, "zoneTrack", function() ns.TrackZone(false) end,
            "Entering a zone, every quest in your log with something to do here goes into the tracker.")
        f:More()
        f:Checkbox("And stop tracking the others", db, "zoneUntrack", nothing,
            "Quests with nothing to do in this zone leave the tracker. The navigation target always stays.")
        f:Checkbox("Level in front of the title", db, "titleLevels", function() ns.RedrawTracker() end,
            "In DeckUIForever's quest tracker every quest reads \"[12] Title\", a + for elite, D for dungeon, R for raid, in the quest log's colours.")

        f:Label("The quest item key")
        f:Checkbox("Quest item button", db, "questItem", function() ns.ApplyQuestItem() end,
            "A button with the quest item that matters now: the navigation target's, else the nearest tracked quest's. Bind a key under Keybindings > AddOns > DeckUIForever. Move it with Move below.")
        f:More()
        f:Slider("Button size (this device)", 0.7, 1.6, 0.05, pct, device, "itemScale", function(v)
            ns.DeviceDB().itemScale = v
            ns.ApplyQuestItemScale()
        end)

        f:Label("The compendium")
        f:Button("Open the compendium", function() ns.ToggleCompendium() end,
            "Every quest by zone, dungeon, class, profession and chain, with what you have done, where each starts and what it needs. Also /compendium, or a key under Keybindings.")
        f:More()
        f:Slider("Window size (this device)", 0.6, 1.3, 0.05, pct, device, "scale", function(v)
            ns.DeviceDB().scale = v
            ns.ApplyCompendiumScale()
        end)

        f:MoreSection("Your quest data")
        f:Hint("The game lists no quest it has not shown you, so the module keeps its own record, shared by all your characters. Questie, when installed, adds everything it knows on top - or once, through the import below, for good.")
        f:Checkbox("Record what you see", db, "record", nothing,
            "Every quest an NPC offers or takes back, its giver and place, its objectives, and which quest follows which. Grows while you play.")
        f:Pair(
            { text = "Start the scan", onClick = function() ns.Scan.Start() end,
              tip = "Asks the server for every quest's name, id by id, a few a second. Takes an hour or two, pauses in combat, carries on next session. Afterwards the compendium can list and search every quest." },
            { text = "Stop the scan", onClick = function() ns.Scan.Stop() ns.Print(ns.Scan.Status()) end,
              tip = "Halts the scan where it is. Start continues from there." })
        f:Pair(
            { text = "Import Questie's data", onClick = function() ns.Import.Guided() end,
              tip = "Copies everything Questie knows about quests, givers and chains into your own record, once; takes a minute. Questie installed but switched off: the button switches it on for one login, imports, and offers to switch it off again. Not installed: it says what to install (Questie and QuestieDB for Forever). Afterwards the compendium has it all without Questie." },
            { text = "Forget the import", onClick = function() ns.Import.Clear() end,
              tip = "Takes the imported quests out of your record again. What you recorded yourself at those quests goes with them." })
        f:Button("What is known", function() ns.Print("quest data:") ns.Own.PrintStats() print("  " .. ns.Scan.Status()) print("  " .. ns.Import.Status()) end,
            "Prints in the chat how many quests, givers, links and quest lines the record holds, how far the scan is, and what was imported.")
    end,
})
