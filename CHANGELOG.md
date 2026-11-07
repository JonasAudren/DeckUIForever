# Changelog

## 1.3.0

The controller bar in our look, the D-pad in our windows, and your
party's HoTs and buffs in one window.

- Hub: on the Steam Deck (Blizzard's gamepad interface style) the bags,
  the bank, the loot window, the week overview, the /df window and its
  dialogs join Blizzard's window navigation, the way the game's own
  windows do: the D-pad moves the cursor between buttons, A clicks, B
  closes the window, LT and RT jump between the open windows, the right
  stick scrolls. The window that holds the cursor gets a gold outline,
  the windows left and right of it Blizzard's LT and RT glyphs. Out of
  combat; in combat the trackpad serves as before. Nothing of the input
  is ours - the windows only announce themselves to Blizzard's window
  manager. Devices page, "D-pad in DeckUIForever's windows", on by
  default; /df gamepad says who takes part.
- Pad: a new module for the Steam Deck. Blizzard's controller action bar
  (the gamepad interface style: LT, RT, the D-pad and face buttons, four
  bars and their pages) keeps all of its controls and gets the hotbar look
  of the Bars module - square slots with a thin outline on both groups,
  the icon behind rounded corners, the button glyph small in the top-left
  corner of every slot, a flat dark panel behind the bar you hold. Blizzard's
  borders, drop shadows and glows go; its pushed shrink, cast fill,
  cooldowns, targeting bars, stance and vehicle bars and the class action
  buttons wear the same slot. Nothing of the input, the bindings, the
  positions or Edit Mode is touched. Page "Controller bar" under Actions,
  off by default; /df pad says what it dressed.
- Orbs: the HoT window is your party's, and compact. A line per member,
  you first - solo, you alone - with the heals you keep up on them as
  round icons whose clock closes as the heal runs out, in the same place
  on every line, and the buffs on them after; every member is listed as
  long as you are in the party. A friendly target outside the party (a
  stranger, an NPC, a raid member of another group) gets a line at the
  end while you target it and loses it with the next target. New on the
  page: "Show every buff, not only yours" (off: your own buffs up to a
  minute, as before), "Side by side" and the icon size, per device. Gone
  with the table: the capsules and their names,
  the focus column, "You, when you have no friendly target", "Keep the
  friends you leave" and the rows at the target frame - a party member
  never leaves the window, and a table has no frame to hang from. The
  debuff window keeps its capsules and kept columns.
- Orbs: the debuff window can wear the same look - "Round icons instead
  of capsules" on its page, off by default, needs a reload. Each column is then one line: the unit's name, a round icon
  per listed debuff with the clock and the time, your other debuffs as
  icons after them; the focus column, the kept columns and the place at
  the target frame stay as they are. The width slider sizes the icons
  in that look.
- Orbs: the HoT window's healer mode - "Click to cast" on its page, off
  by default, needs a reload. A click on a heal's icon casts it on that
  member, missing or running; a click on the name targets them. In
  combat too, the way a key press works. In this mode the window stands
  still in a fight: the game shows and hides the lines itself, a member
  who joins mid-fight takes the next free row, and the layout catches
  up when the fight ends. The empty icons always show, so there is
  something to click.
- Orbs: on the Steam Deck the HoT window shows, before each name, the
  key that targets that member in Blizzard's own gamepad targeting - the
  D-pad for party members 1 to 4, the bottom face button for you - dim
  until you hold the friendly target modifier. "Controller keys at the
  names" on the page, on by default; nothing in the gamepad style's
  controls changes, the window only shows the keys where your HoTs are.
- The settings window, simpler. Screen, Targets and Windows are pages of
  their own in the General group (they were hidden under the Overview);
  the Overview is "Modules", the Units group is "Frames", and the Orbs
  page is "Unit frames". The minimap's settings sit on the Maps page,
  the tooltip's extra lines on the Tooltip page. Every label is shorter
  and every explanation is two or three plain sentences. The sidebar
  has a scrollbar.
- Fixed: the debuff window's kept columns threw an error as soon as a
  kept enemy's nameplate changed hands (since 1.2.0).

## 1.2.0

Your HoTs, and both windows remember the units you leave.

- Orbs: your HoTs as a window in the style of your debuffs - a druid's
  Rejuvenation and Regrowth, a priest's Renew and Power Word: Shield, one
  capsule each, filled by the game itself, in combat too. A column for
  the friend you target, a smaller one for your focus, and your own HoTs
  on you while you have no friendly target. What runs here as a bar
  leaves the target frame's buff icons (switchable). Page "Your HoTs"
  under Player and target, off by default; /orbs hots says what it sees.
- Orbs: the debuff and HoT windows keep the units you leave. An enemy
  whose nameplate is on screen, a friend in your group, or you: each
  keeps a smaller column under the target column while one of your
  listed debuffs or HoTs runs on it, up to four, newest first. "Keep the
  enemies you leave" and "Keep the friends you leave" on the two pages,
  on by default.
- Orbs: out of a fight both windows show only what is running - no
  dimmed empty capsules, no name over an empty column. "Empty capsules
  out of combat" on either page brings them back; in a fight the red
  missing ones stay.
- Orbs: no sample rows while the frames are unlocked - an empty box to
  drag instead. "Sample rows while moving" on either page brings them
  back.

## 1.1.0

- Bars: the stance bar (forms, stances, auras, stealth) and the pet bar
  as rows of the same square slots, in place of Blizzard's; a shaman's
  totem bar keeps its place and gets the slot look. Each switchable on
  the Bars page, on by default.
- Hub: DeckUI's helpers for Classic content are in - restock at merchants
  (arrows, reagents, water, food up to a count), the mail helper (your
  characters in the "To" field, what Open All took) and the character
  panel's item levels with missing enchants marked. All off by default.
- Hub: the group listing as a small window - the activity, how long you
  have been listed, your roles and the group so far. Off by default.
- Orbs: five more Classic debuffs in the per-class lists (Faerie Fire
  (Feral), Stormstrike, Fire Vulnerability, Winter's Chill, Judgement of
  the Crusader).

## 1.0.0

DeckUI, carried over to World of Warcraft: Forever (DECKUIFOREVER_BERICHT.md):
the hub and nine modules. First release.

- Settings window (/df), movable frames per device, Lua error window,
  minimap button, UI scale per device.
- Action bar layouts and Edit Mode layouts per device, kept per talent
  group (Forever has no specializations).
- Loot window, loot rolls, merchant (sell junk, repair), rank marks,
  FFXIV nameplates, target arrow, interact target name, server info, gold,
  bag overview, main menu as round buttons (with Forever's Legacy button,
  without the unused housing and encounter journal buttons),
  auction house prices and look, Blizzard's damage meter restyled.
- Orbs: round unit frames or Final Fantasy's bars, party and raid frames,
  buff bar, enemy list, your debuffs (listed per class). Combo points sit
  on the target in Forever; the other classes have no resource dots.
- Bars: the eight action bars in Final Fantasy XIV's hotbar look for
  keyboard and mouse - square slots, your keys in the corner, a number tag
  per bar, Action Bar 1 with its pages; Blizzard's bars parked meanwhile.
- Map: square or round minimap with Forever's day/night indicator, the
  smaller world map. Nav: compass, navigation target, beacon, waypoints.
  Tooltip: DeckUIForever's look, item level of players, quest items,
  reputation items, auction prices.
- Spec: the talent group switcher (dual talents from level 40), with an
  equipment set per group. Bags: the keyring as its own section, the bank
  with its bag slots behind the tab icons (drop a bag on one). Quests: the
  tracker with Forever's classic quest timers, scenarios and dungeons,
  collections and recipes; no delves, hunts, campaigns or Traveler's Log.
- Week: every character's raid lockouts, Legacy and PvP renown, today's
  dailies, weekly quests, reputation and currencies in one table.
- Left out: the talking head (Forever has none), the one-button assistant
  (switched off in Forever), the quest book, DeckUI's own damage meter, the
  dungeon queue window, and the Mists helpers for the character panel,
  mail and restocking.
