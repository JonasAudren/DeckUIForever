local ADDON, ns = ...

-------------------------------------------------------------------
-- World of Warcraft: Forever's week, by ID (in place of DeckUI's data.lua)
-------------------------------------------------------------------
-- Forever's week is raids and dungeons, the Legacy reward track, the PvP
-- rank, daily and weekly quests, reputation and whatever currencies the
-- game hands out - no vault, keystone, delves, hunts or knowledge
-- (DECKFOREVER_BERICHT.md 4.10). Little of it has fixed IDs worth
-- keeping here: the currencies and reputations come from the game's own
-- lists (collect_forever.lua), weekly and daily quests are learned from
-- the quest log. What is fixed:
--  - the two renown tracks the client reports (probe 2026-11-05,
--    C_MajorFactions.GetMajorFactionIDs): 2802 "Legacy Track", 2800
--    "PvP Rank Points", both at renown 0 on a level 2 character;
--  - the world bosses, once known: a kill flags a hidden weekly quest,
--    found with /week record (record.lua). None yet.
-- Everything here was read on a level 2 priest; a higher character and
-- /week record fill it in.
-------------------------------------------------------------------

-- the Legacy reward track and the PvP rank track (Constants.LegacyConsts
-- .LEGACY_REWARD_TRACK_FACTION_ID is 2802 in 1.60.1)
ns.RENOWN = {
    { id = 2802, key = "legacy", name = "Legacy" },
    { id = 2800, key = "pvp", name = "PvP rank" },
}

-- The world bosses: one kill a week counts for loot, flagged by a hidden
-- quest. None known yet - /week record names the quest the first kill
-- flags; add it here as { quest = id, name = "..." }.
ns.WORLD_BOSSES = {}

-- Week's shared code asks these; Forever has no fixed weeklies yet
ns.WEEKLIES = {}

-- Every quest ID above, so the learned list does not show them twice
ns.KNOWN_QUESTS = {}
for _, b in ipairs(ns.WORLD_BOSSES) do ns.KNOWN_QUESTS[b.quest] = true end
