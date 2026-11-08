local ADDON, ns = ...

-------------------------------------------------------------------
-- Our own quest data, shipped with the module
-------------------------------------------------------------------
-- The game lists no quests it has not shown you. So the module records
-- what it sees (record.lua), asks the server for every quest's name by
-- id (scan.lua) and reads the quest lines of each map (C_QuestLine).
-- Everything lands in the account-wide SavedVariables
-- DeckUIForeverQuestDataDB, in the shape below. This file is the same
-- shape, filled by hand from that file for a release: open
--   WTF\Account\<account>\SavedVariables\DeckUIForever_Questing.lua
-- and copy the `quests`, `npcs` and `lines` tables of
-- DeckUIForeverQuestDataDB in here. What ships is the owner's own
-- record of the game, nothing of another addon's.
--
-- Shape (short keys, the file grows to thousands of quests):
--   quests[id] = {
--     n = "Name",            -- the title, from the server
--     l = 12,                -- the quest's level (0 unknown)
--     r = 10,                -- the level needed (0 unknown)
--     t = 81,                -- the tag id: 1 elite, 81 dungeon, 62 raid, 41 pvp, 21 class
--     m = 52,                -- the map where it was offered (uiMapID)
--     g = { "n823", "i6948", "s52:45.2:67.8" },   -- givers: NPC id, item id, or a spot on a map
--     f = { "n823" },        -- who takes it back
--     p = { 101, 102 },      -- quests done before it opened (prerequisites, inferred)
--     x = { 105 },           -- quests it opened (follow-ups, inferred)
--     c = { PRIEST = true }, -- classes it was offered to
--     o = { "Kill 10 boars" },   -- objective texts
--     d = true,              -- daily or repeatable
--     -- what the import (import.lua, /questing import) adds from Questie:
--     i = true,              -- imported
--     s = 12,                -- the zone-or-sort key: an area id, or a negative sort (class, profession, event)
--     h = 30,                -- the highest level it is offered at (0 none)
--     a = { 101, 102 },      -- any one of these done opens it (p: all of them)
--     e = { 110 },           -- quests that exclude it (one done, this one is gone)
--     v = 120,               -- the parent quest it belongs to
--     b = 130,               -- the quest this one is a breadcrumb for
--     k = { PRIEST = true }, -- only these classes (none: every class)
--     y = { Human = true },  -- only these races, the game's tokens (none: every race)
--   }
--   npcs[id]  = { n = "Name", m = 52, x = 45.2, y = 67.8, z = "Zone" }   -- map and position in percent
--   objs[id]  = { n = "Name", m = 52, x = 45.2, y = 67.8, z = "Zone" }   -- a game object giving a quest ("o<id>")
--   items[id] = "Name"                                                   -- a start item the game cannot name
--   sorts[id] = { n = "Name", c = 1, m = 52 }   -- a zone-or-sort key: name, Journey category, map
--   lines[id] = { n = "Line name", m = 52, q = { 101, 102, 103 } }   -- a quest line of the game
-------------------------------------------------------------------
ns.SHIPPED = {
    quests = {},
    npcs   = {},
    objs   = {},
    items  = {},
    sorts  = {},
    lines  = {},
}
