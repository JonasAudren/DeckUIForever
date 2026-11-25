# Changelog

## 1.5.6

- New module: Chat (off until you switch it on, page "Chat" under Info).
  Blizzard's chat keeps its tabs, channels and settings and gets:
  - the look: a flat dark panel behind every chat window, plain tabs
    with the picked one in gold, a plain input line, the buttons beside
    the chat faded out, DeckUIForever's font;
  - thin coloured tabs over the chat in place of Blizzard's (option
    "Thin coloured tabs", on): one per kind of chat in that chat's
    colour - All, Guild, Party, Raid, Whisper, Say, Channels - and a grey
    one for the combat log and every other docked window. A tab shows
    only its lines and lights up when a new one came; All shows
    everything but the whispers, which have their own tab; a click on Guild,
    Party, Raid or Say also starts the input line there. A right click
    opens the chat's own menu. Off, Blizzard's tabs are back;
  - a font size and an input line size per device - larger on the Steam
    Deck;
  - short channel names ([1], [P], [G], [R]), web addresses as links
    that open a box to copy them from, the game's time stamps, the arrow
    keys for what you typed before, and a button that sets class
    colours for names in every channel;
  - keywords: your words in gold, and a sound when one of them or your
    name is said by someone else; optionally the same line from the same
    player is shown only once a minute;
  - quick phrases: a row of small buttons that say a prepared sentence
    to your party or raid, for a Deck without a keyboard. Each button
    wears a short word (Hi, Thx, Ready, Wait, Mana, Bye), the tooltip
    shows the sentence; the settings page has a row per phrase to change
    the short word and the sentence, six at most;
  - whisper windows: a whisper you get or send opens a small window
    with that conversation alone and a line to answer in - up to four at
    once, Battle.net friends too. Drag a window by its title bar and it
    stays where you drop it. The chat shows the whisper as before (with
    our tabs: in the Whisper tab).
    Optionally a new window waits until a fight is over.
  /df chat prints what the module is doing.
- New: the auction watch, a small broker's desk for auction prices. Open
  it with its button in the dock or /df watch. Three lists: "Watched" -
  items you drop on the window (or /df watch with an item link), up to
  twelve, each with its price from your last auction scan and how it
  moved against the scan before; "Movers" - what rose and fell most
  between your last two scans; "My bags" - what you carry that can be
  traded, by auction value. A click on a line shows the item on the
  right: a chart of its price over your scans, the average, lowest and
  highest, what you hold, the merchant's price and whether it is cheap
  or dear right now. Every scan at the auction house adds a point; a
  watched item keeps its last thirty.
- Bags: the gold coin on valuable items now starts at a stack value of
  5 gold instead of 100, and the slider goes down to 1 gold. A saved
  100 is lowered once.
- Bags: a new group "For the auction house" in the category view - what
  you can trade and whose stack is worth at least one gold in your last
  auction scan. Option and the limit under Bags, Auction prices.
- Bags: the bank shows everything at once - its own slots and every bank
  bag below each other, each under the bag's name - instead of one bag at
  a time. The icons at the top are still the bank's bag slots: drop a bag
  on one to put it in. Option "Whole bank in one window", on by default.
- New: "Sell junk" keeps grey items the auction house pays more for (at
  least twice the merchant's price in your last scan) and names them in
  the chat. Option "Keep junk the auction house pays more for" under
  Loot and merchant, on by default.
- New: the auction value on loot. DeckUIForever's loot window, the list
  of what auto loot took and the loot rolls show what an item sells for
  at the auction house, from your last scan - handy for Need or Greed.
  Option "Auction value on loot" under Loot and merchant, on by default;
  it shows nothing until you have scanned an auction house.
- Auction prices: a new scan no longer throws away what it did not see.
  An item that was not on offer at that moment keeps its last price for
  30 days, shown with its own age.
- Auction prices are kept per faction, and a scan much smaller than the
  one before (the neutral auction house) is kept apart instead of
  replacing your prices. A character without prices of its own still
  sees the realm's other scans. /df ah lists what is stored.
- Fixed: the auction scan could read the list before the game had sent
  all of it. Each scan then held only a part of the auction house, and a
  price was the cheapest of the few listings that happened to be there -
  often far too high. The scan now waits until the list has stopped
  growing ("Receiving the listings ...") and says how many listings it
  read. /df ah with an item link shows that item's listings from the
  scan, to check a price.
- Fixed: loading a profile on a new character could do nothing and
  leave the error "DeckUIForever tried to call Reload()". The game
  refused the reload when the profile's modules had to be switched on
  first. A "Reload now" question follows the load now.
- Bags: a right click at the bank no longer uses an item the bank cannot
  take. When the bank is full or does not accept the item, nothing
  happens and a red line says why - before, a potion could be drunk
  instead of put away.
- Bags: the "New" group empties when you close the bags. It used to keep
  every item you had not pointed at.
- Bags: the free slots of a quiver, ammo pouch or soul bag are counted
  on a stand-in of their own ("special", in blue) instead of among the
  ordinary free slots, and the bank deposit no longer aims at them.
- Bags: the bank's sort button is hidden where the game has no bank
  sorting, instead of throwing an error on a click.
- Combat: with our loss-of-control display on, Blizzard's own alert no
  longer shows beside it, and ours counts the time down on the icon.

## 1.5.5

- New: profiles (page "Profiles" under General, /df profiles). A profile
  is a copy of all your DeckUIForever settings - which modules are on,
  every option, and where the frames stand on the PC and on the Steam
  Deck. Save as many as you like under names of your own and load one
  with a click; the game reloads. What you had before a load is kept as
  the profile "Before the last load", so you can go back.
- Profiles can be shared: "Share" shows a profile as a text to copy,
  "Import a profile" takes such a text from someone else. An imported
  profile is only added to your list; nothing changes until you load it.
  Waypoints, tracked items, auction prices, the week overview's
  characters and the device you play on are never part of a profile.
- New module: Combat (off until you switch it on). Four small pieces,
  each on its own switch and movable on its own: a swing timer (a bar
  per weapon from one auto attack to the next, red while the target is
  out of reach), breath, fatigue and feign death timers in
  DeckUIForever's look, an alert with icon and time when you are
  stunned, feared or silenced, and your threat on the target in
  percent. /df combat prints what the game reports.
- New for shamans: totem timers (GitHub issue 2). A small row of icons
  for your standing totems - fire, earth, water, air - each with the
  time it has left; a totem that is recalled, destroyed, replaced or
  runs out leaves the row. Off by default: General - Screen - "Totem
  timers"; move it with Move on that page. /df totems prints what the
  game reports for each slot.
- New: Blizzard's Cooldown Manager in DeckUIForever's look. The game's
  own bars for your cooldowns and tracked buffs get square icons, our
  numbers and flat bars in place of the round frames. Off by default:
  General - Screen - "Blizzard's Cooldown Manager in DeckUIForever's
  look"; switching it on also switches the manager itself on. "Choose
  the spells" opens the game's window for what stands in which bar; the
  bars are moved in the game's Edit Mode. Switching the look off needs
  a reload. /df cooldowns prints what the game reports. With the Orbs
  module the manager's buff bars are green capsules like the debuff
  window's rows.
- New: the debuff window works with Blizzard's Cooldown Manager. Two
  options, both off by default, under Orbs - Debuffs - More -
  "Blizzard's Cooldown Manager": "Leave the target's debuffs to the
  Cooldown Manager" takes a debuff that sits in the manager's buff bars
  out of the window's target column (focus, the enemies you switched
  away from and every debuff the manager does not offer stay; the red
  "missing" capsule goes with it), and "Hang the window below the
  Cooldown Manager's bars" makes the window follow those bars. /df
  cooldowns and /orbs dots print, for each of your debuffs, whether
  Blizzard offers it and whether it sits in a buff bar.
- HoT window: two new sliders under "Layout (this device)" - "Health
  bar height" (4 to 12 pixels) and "Name and bar width" (48 to 160
  pixels). Both need a reload. In place of the party list the bars are
  larger by default now: 8 pixels high and 96 wide instead of 5 and 64.
- HoT window: new switch "Incoming heals on the health bar" (off). A
  lighter piece ahead of each member's health shows how much the heals
  being cast on them will bring back. Direct heals only.
- Fixed: a HoT window dropped in the lower half of the screen grew
  upwards, so the line for a target outside the group pushed your own
  line away and stood in its place. The window now grows from its top
  edge wherever it stands.
- Fixed: DeckUIForever's loot roll window could not be moved (GitHub
  issue 1). Unlocked, the window lay over its own drag area. It moves
  now with Move on the Loot page or Devices - Unlock frames, and you can
  also drag it by its title while a roll is open. The same fix helps the
  loot window.
- Fixed: "Incoming heals on the health bar" could show nothing (GitHub
  issue 1). The bar now also reads the game's incoming heal the same
  way Blizzard's own player frame does. Where the game reports nothing for
  a heal you are casting yourself, an estimate read from the spell's
  description stands in. /orbs heals prints for every cast what the
  game reports and what we estimate.

## 1.5.4

- Unit frames: the player frame and the target frame each have a switch
  of their own now ("Player frame", "Target frame" at the top of the
  Unit frames page, both on). Off, DeckUIForever does not build that
  frame and leaves the game's own alone, so Blizzard's frame or another
  addon's can stand there while you keep our party and raid frames. The
  pet's frame goes with the player's, the target of target with the
  target's. Needs a reload. (GitHub issue 1)
- Unit frames: new switch "Incoming heals on the health bar" (off). A
  lighter piece ahead of your health, and your target's, shows how much
  the heals being cast right now will bring back - in all three styles,
  the orbs included. Needs a reload. (GitHub issue 1)
- New: the buff window ("Missing buffs" under Unit frames, off). A line
  for you and each party member with one round icon per buff of yours
  they lack - Fortitude, Mark of the Wild, Arcane Intellect and the
  like - no matter who cast it. Click an icon to cast the buff on that
  member. A fully buffed party leaves the window empty. The missing
  buffs are no longer part of the HoT window; who had them on there
  gets the new window switched on. /orbs buffs prints what it sees.
- Your HoTs: the icons of a line stand in a new order - first your HoTs
  and the shield (the instant ones), then the heals, then the cures and
  the resurrection.
- Questing: repeatable quests (cloth, reputation tokens) are no longer
  taken and handed in on their own - the autopilot could hand them in
  over and over until the items were gone. New switch "Repeatable quests
  too" (off) for those who want that. A hand-in that costs gold is
  always left to you.
- Fixed: Your HoTs: the mana line could stay away for party members
  whose mana the game keeps to itself; the class decides then (every
  class but warriors and rogues). /orbs hots prints what it sees.
- Fixed: the two UI scale sliders on the Devices page did not keep their
  value.
- Fixed: bags threw an error with "Gold coin on valuable items" off.
- Fixed: Restock could report purchases the merchant had refused when
  the gold did not reach for the whole list.
- Fixed: enemies tapped by someone else are grey again on the target,
  focus and boss bars of the Final Fantasy styles.
- Fixed: "Defaults" on the Loot page missed the two auction switches,
  and on the Group page the look of party and raid.
- Fixed: the own buff bar and the test frames (/orbs test, raid, boss)
  no longer take Blizzard's player or target frame away while "Player
  frame" or "Target frame" is off.

## 1.5.3

- Deck Heal picks by role now. Holding the Deck Heal key alone heals the
  tank (you, in a group without a tank). D-pad left picks the healer,
  up, right and down the three damage dealers in the order of the HoT
  window. The picked member's direction again goes back to the tank. In
  a group without roles nothing changes: it starts on you and the D-pad
  picks party member 1 to 4. The key pictures in the HoT window follow.
- Deck Heal: the second set of spells with R is on from the start now
  (it was a switch you had to find first). Hold the Deck Heal key and R,
  and A, X, Y, B cast spells five to eight. The buttons also answer when
  the two held keys count as Ctrl, Shift or Alt together.
- Deck Heal: holding the Deck Heal key (L) aims at friends again, as the
  game does without Deck Heal - turn towards someone and they become
  your target. The heals still go to the member picked with the D-pad.
  New switch "Aim at friends while holding the key" (on).
- Your HoTs: new switch "In place of the party list (this device)". The
  party list hides and the HoT window takes over - a quarter bigger,
  with the health bar, the debuffs you can remove, dead or offline and
  the range dimming on every line. Made for the Steam Deck, where both
  windows took too much of the screen.
- Deck Heal: the bar is a cockpit now. Under the picked member's name
  sits their health, and after the four spells a debuff you can remove
  and your HoTs on them with their clocks - no more looking over to the
  HoT window in a fight. Switch "Health, HoTs and debuffs on the bar".
- Deck Heal: the four spell icons say what is possible - a closing clock
  with the time while on cooldown, grey without the mana, red while the
  picked member is out of range. Switch "Spell icons show what is
  possible".
- Deck Heal: the buff and resurrection round. Out of combat, hold the
  Deck Heal key and click the right stick: one cast per click on whoever
  needs it next - your resurrection on a dead member first, then your
  buffs where they are missing. A line above the bar names the next
  cast. Switch "Buff and resurrection round".
- Deck Heal: a list of your own no longer leaves buttons empty. What you
  do not name is filled with your HoTs, heals and cures - with four
  names of yours, the second set carries your class's other spells.
- Your HoTs: a mana bar. A thin blue line under each name shows how
  much mana the member has left; members without mana get none. Switch
  "Mana bar" (on).
- For testing: /df vibrate tries the controller's rumble and says
  whether the game took the call. Nothing uses it yet.

## 1.5.2

- Deck Heal: a second set of spells. New switch "Second set of spells
  with R" on the Deck Heal page (off): while you hold the Deck Heal key,
  hold R as well and A, X, Y, B cast spells five to eight; let go of R
  and the first four are back. The spell list takes up to eight names,
  and the small bar shows which set is on the buttons.
- Deck Heal: without a list of your own, the heals after your HoTs now
  come from the weakest to the strongest, each in its highest rank - a
  priest's Lesser Heal, Flash Heal, Heal, Greater Heal. Until now the
  strongest came first.

## 1.5.1

- The settings window is easier to find your way in:
  - A new first page, "Start": three steps - pick how you play
    (Keyboard and mouse, Steam Deck, I am a healer; each asks before it
    changes anything), switch modules on and off right there with a line
    on what each does, then move frames and find help.
  - Every page shows its important options first. "All options" at the
    bottom of the window, or the gold line at the end of a page, shows
    the fine-tuning too. `/df all` does the same.
  - A search field above the page list: type a word such as "buff" and
    every matching option of every page is listed; a click takes you
    there and marks it.
  - The page list on the left shows only the modules that are on.
- Deck Heal needs no key of its own on a controller any more: the button
  you hold to pick a friend (L) opens the layer. Hold it, pick with the
  D-pad, heal with A, X, Y, B. The game's own friend targeting on that
  button rests while Deck Heal is on; the new switch "Use the
  friend-targeting button (L)" on the Deck Heal page turns this off.
- Devices page: "Test the Steam Deck here". This device then counts as
  the Steam Deck and the game switches to its controller interface, so
  the Deck's side can be tried at the PC; the button again puts
  everything back. While it runs, Deck Heal also listens to the keyboard:
  hold Tab, pick with the arrow keys, heal with 1 to 4. `/df decktest`.
- Your HoTs: the controller key pictures before the names no longer lie
  on the health bar - bar and name start after the picture.
- Your HoTs: the lines are always sorted tank, healer, damage - by the
  role the group gave each member, the group order within a role. A
  group without roles keeps the old order. In the raid table the same
  within each raid group.
- Your HoTs, "Your buffs while they are missing": the check no longer
  takes "the game does not say" for "missing". A buff counts as missing
  only when the member's whole buff list could be read and it is not in
  it - in a fight too. `/orbs hots` prints the answer for every member.
- Nameplates: in dungeons and raids the game lets no addon touch a
  friend's nameplate, so the Final Fantasy look cannot be drawn there.
  New switch "In dungeons: friends as names only" (Targets page, on):
  Blizzard's plate there shrinks to the bare name. `/df plates` says how
  many plates the game keeps to itself.
- Bank: the error `BankFrame.lua:43: bad argument #1 to
  'FetchNumPurchasedBankTabs'` whenever your gold changed is gone.
  Blizzard's hidden bag-cost display no longer listens for it.

## 1.5.0

- Deck Heal (new page under "Your HoTs", off until you tick it): heal
  with the controller, without mouse or target change. Bind a key under
  Key Bindings, AddOns, "Deck Heal: healing layer" - on the Steam Deck a
  back paddle works well. While you hold it, D-pad up, right, down, left
  picks party member 1 to 4 and A, X, Y, B cast four spells on the picked
  member; it starts on you, and the picked member's direction again goes
  back to you. Let go and every key is back to normal. The four spells
  are your HoTs and heals, or a list of your own. A small bar shows who
  is picked and what each button casts, and the member's line in the HoT
  window gets a gold frame; both can be switched off, and the key can
  switch the layer instead of holding it. /orbs deckheal prints what the
  layer sees.
- Screen: a button "Camera: maximum distance". The camera then zooms out
  further than the game's own slider allows, and does so at once; the
  same button puts the game's default limit back. /df camera prints the
  value.
- Bags: no more "DeckUIForever_Bags tried to call UseContainerItem()" on
  a right click at the bank. The bank window no longer writes into
  Blizzard's bank frame; a right click on a bag item at the bank now
  puts the item into the bank on show itself - onto a matching stack
  with room, else into the first free slot.
- Your HoTs: with "Click to cast" on, a click now casts the highest rank
  you know - it could cast a lower one. Deck Heal does the same; give a
  spell ID in its list if you want one fixed rank. `/orbs hots` names the
  rank each spell casts.
- Party and raid frames: no more "tried to call SetSize /
  RegisterForClicks" when a member joins during a fight. The new
  member's frame is finished when the fight ends; until then a left
  click on it targets, the right-click menu waits.
- Nameplates: with the Final Fantasy XIV nameplates on, friends now get
  the same look in green - until now only enemies did, so the friend
  your next heal would go to (the soft friendly target) showed
  Blizzard's nameplate. "Friendly nameplates too" on the Targets page
  switches it off.
- A new page "Hidden settings" under General: settings the game has but
  does not show in its own menu, as switches, sliders and buttons with a
  short explanation each - healing without a target on the friend you
  face, always comparing items, leaving a form or a mount to cast, the
  controller's camera speed and vibration, the over-the-shoulder camera,
  looting speed, nameplate distance and spacing, the combat numbers, the
  glow and weather effects, and two helpers for bug reports. Only what
  this game knows is listed; one button puts them all back to the game's
  defaults. /df cvars prints every name and value.

## 1.4.1

- Bags: no more error from Blizzard's bank code (BankFrame.lua:43,
  FetchNumPurchasedBankTabs) when gold changes hands after a bank visit.
  Closing the bank now leaves Blizzard's parked bank frame the way its
  own closed bank is: no bank type, no listener for gold.
- Bars: a recast timer in Final Fantasy's look - the seconds left on a
  cooldown, large and white in the middle of the slot, no decimals, the
  global cooldown with the sweep only. On by default ("Recast timer" on
  the Bars page); it replaces Blizzard's cooldown numbers on our slots.
- Your HoTs: the window can do more, every part a switch of its own on
  the "Your HoTs" page and off until you tick it. A thin health capsule
  under each name, as the FF frames' bars, or a flat bar behind the
  name; dead, ghost or offline in words; members and pets out of range
  dimmed; the debuffs you can remove; your buffs as icons that show only
  while someone lacks them; your direct heals and cures as buttons (with
  click to cast; a cure only while there is something to remove, the
  resurrection only on the dead); a list of your own spells; the time
  left while a spell is on cooldown; your mana regeneration (MP5) above
  the window; lines for pets, smaller and each under its owner; the
  whole raid as a table by raid group; and a blink or a sound before a
  HoT runs out.
- Auction house: the price scan no longer gives up after ten seconds
  and then ignores the late answer. It waits up to 90 seconds, counts
  the seconds in the status line, and still reads an answer that comes
  later.
- Devices: a button "Stop syncing UI and keys" under "Keep on this
  device". Interface settings, chat windows and key bindings then stay on
  the device instead of going through Blizzard's server; a second click
  syncs them again. Macros stay synced. /df sync prints the state.

## 1.4.0

Questing made easier: a compendium of every quest, the NPC dialog on
autopilot, a mark on the reward worth taking, a key for the quest item,
and the level range at zone names.

- Questing: a new module (page "Questing" under World, off by default,
  /questing). At an NPC it takes the quests offered, hands in the finished
  ones, takes the reward when there is nothing to choose, and skips a
  single line of small talk; a party member's shared quest or escort is
  accepted too, and new quests can be shared with the party. Held Shift
  (the left trigger on the Steam Deck) pauses it, /questing pause stops it
  for good, /questing ignore at an NPC leaves that NPC alone. It stands
  down when Questie's own autopilot, QuickQuest or Immersion is on.
- Questing: with a choice of rewards, a coin marks the item that sells for
  the most and a green arrow one that would be an upgrade for your slot
  and your class's armour kind; the vendor price stands in the corner.
  Optional: take the most valuable when nothing is an upgrade.
- Questing: the compendium (/compendium, a key under Keybindings): every
  quest by zone and continent, dungeon, your class, profession,
  battleground and event, and the quest chains - epic and long ones apart
  - each with its state for this character (in your log, available,
  something missing, done, not available), where it starts with a
  waypoint button, where it ends, what it needs first, what it leads to,
  the whole chain with your place in it, and its objectives. A search box
  and two filters (hide done, only my class and race). The knowledge is
  Questie's database, read when Questie is installed; without Questie the
  window shows the game's quest lines of the map and your finished
  quests, and says so.
- Questing: the tracker can follow the zone (track the quests of the zone
  you enter, stop tracking the others; the navigation target stays), and
  the Quests module's tracker can show "[12+] Title" in the quest log's
  colours.
- Questing: a quest item button with the item that matters now (the
  navigation target's, else the nearest tracked quest's), with count,
  cooldown and its key; "Quest item: use it" under Keybindings > AddOns.
- Questing: the compendium keeps its own quest data, shared by all your
  characters and independent of Questie: it records every quest an NPC
  offers or takes back, the giver and its place, the objectives and
  which quest follows which; it reads the game's quest lines of each
  map; and a scan ("Start the scan" on the page, /questing scan) asks
  the server for every quest's name, id by id, pausing in combat and
  carrying on next session. With Questie installed its database comes
  on top - or once and for good: "Import Questie's data" on the page
  (/questing import) copies every quest, giver, chain, class and race
  restriction and zone from Questie into your own record, so the
  compendium has it all afterwards without Questie; "Forget the
  import" takes it out again. Questie installed but switched off? The
  button switches it on for one login, imports, and offers to switch it
  off again. What the owner records ships with the module in later
  versions.
- Hub: the dock - a small flat panel with round buttons for the settings
  (right click unlocks the frames), the week overview and the quest
  compendium, each as its module is on. Drag it by any button. The week
  button on screen moved into it, with its vault badge; "Button in the
  dock" on the Week page keeps it out. Screen page, on by default.
- Map: the level range after the zone name on the minimap and after the
  last breadcrumb of the world map, coloured by your level like quest
  levels ("Level range at zone names", on). The world map's hover label
  over a zone shows the range already, Blizzard's own.
- Orbs: the HoT window lists your group in the order of the game's own
  group frames: in a raid your raid group in raid order, you at your
  place in it instead of always on top; in a party you first, as before.
  /orbs hots prints the order and each line's row.
- Orbs: "A line for a target outside the group" on the HoTs page (on, as
  before): off, the HoT window shows your group alone, no line for a
  targeted NPC or a raid member of another group.
- Fixed: Map: the quest details beside the world map were written in
  parchment ink on the dark panel, barely readable (since 1.0.0); the
  text is light now, a finished objective's grey and other colours stay.
- Fixed: Orbs: with "Click to cast" on, the HoT window kept the line of
  your last friendly target when you targeted yourself while solo (the
  game's own show rule cannot tell you from a stranger there); the line
  is transparent for you or a party member now, in a fight too.
- Orbs: no more errors from the debuff window's kept columns in a fight,
  where the game hides an enemy's identity: such a unit is not kept and
  not matched to a nameplate, instead of throwing on every target change.

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
