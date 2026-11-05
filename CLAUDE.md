# DeckUIForever – project notes for Claude Code

DeckUI for **World of Warcraft: Forever** (client `C:\Spiele\World of Warcraft\_forever_`, product
`wowf`, 1.60.1, project `WOW_PROJECT_CAMELOT` = 18, Interface **16001** - the wiki's number for the
beta, to be confirmed in game with `/df build`). A separate addon package, carried over from
DeckUI (`..\DeckUI`, retail Midnight 12.1.5 and Mists of Pandaria Classic 5.5.4) one module at a time.
The plan and the findings are in `DECKUIFOREVER_BERICHT.md` (02.11.2026, read against the installed
client's exe and Blizzard's `forever` UI source); `FOREVER_BERICHT.md` (26.10.) is the research
that preceded it. The owner tests everything in game himself; Claude Code cannot run WoW.

**Forever is retail's engine and UI with Classic content.** Every API, event and CVar DeckUI uses is
in the Forever exe, so the retail branch of each DeckUI file is what runs here, and the
`D.IsMists` / `D.IsRetail` switches are gone. What Forever lacks is content: no specializations (dual
talent groups from level 40 instead, `C_SpecializationInfo.GetActiveSpecGroup`, event
`ACTIVE_TALENT_GROUP_CHANGED`), no one-button assistant, no Great Vault, Mythic+, delves, hunts,
talking head, housing. New: keyring, the Legacy system in place of achievements, a classic quest
timer, the totem bar, and **Blizzard's own gamepad UI** (`Blizzard_Gamepad*`, section 3 of the
report) - whether DeckUIForever Cross or Blizzard's gamepad style runs on the Deck is **the open
decision**, taken with the live client (phase 4).

## Layout

```
DeckUIForever/        hub (phase 1, 2026-11-05): device detection, settings window (/df), movable frames,
                    minimap button, loot, merchant, nameplates, info bars, main menu, auction, damage meter style
DeckUIForever_Orbs/   phase 2 (2026-11-05): unit frames on oUF (/orbs); classpower_forever.lua before oUF
DeckUIForever_Map/    phase 2: square or round minimap, smaller world map (/deckmap)
DeckUIForever_Nav/    phase 2: compass, navigation target, waypoints, /way (/decknav)
DeckUIForever_Tooltip/ phase 2: the mouse-over tooltip (/decktip)
DeckUIForever_Spec/   phase 3 (2026-11-05): talent group switcher (/spec), DeckUI's core_mists.lua
DeckUIForever_Bags/   phase 3: bags with the keyring, bank with bag slots behind the tabs (/bags)
DeckUIForever_Quests/ phase 3: objective tracker with quest timers (/quests)
DeckUIForever_Week/   phase 5 (2026-11-05): the week for every character (/week)
DeckUIForever_Bars/   2026-11-05, owner's wish outside the plan: the eight action bars in FFXIV's hotbar look
                    for keyboard and mouse (page "Bars", /df bars); LibActionButton as DeckUI Cross carries it
                    Cross (phase 4) follows; D.MODULE_ADDONS in core.lua names it already, and a module
                    whose folder does not exist shows "Not ported yet"
```
Module SavedVariables are `DeckUIForever<Module>DB` (`DeckUIForeverOrbsDB`, `DeckUIForeverMapDB`, ...), the
module slash commands stay DeckUI's (`/orbs`, `/deckmap`, `/decknav`, `/decktip`), frame names too
(`DeckMapMinimap`, which the hub's minimap button asks for). `libs\oUF` is **DeckUI's patched copy,
unchanged**, so a library update is done once in DeckUI and copied here; its Mists hooks
(`ns.MistsClassPower`, `ns.MistsComboPoints`) are what `classpower_forever.lua` answers to.
In `_forever_\Interface\AddOns\` the folders are directory junctions into this repo
(`New-Item -ItemType Junction` in PowerShell; `cmd /c mklink /J` from Git Bash fails on the quoting).
A `.lua` change is live after `/reload`; `.toc` changes or new folders/textures need a client restart.
The client took the `_Camelot.toc` of the probe when `_Forever.toc` lay beside it; a plain `Name.toc`
loads too, and DeckUIForever keeps to that. Interface **16001** is confirmed (`/df build`, 2026-11-05).

Probe facts the later phases build on (section 8 of the report has them all): the keyring is container
-1 with 32 slots and `C_Bank.ShouldUsePlayerBagsInBank()` is true (Blizzard shows bank tabs as pages);
the minimap has retail's `MinimapCluster` **and** a `MinimapBackdrop` child of `Minimap` carrying the
compass texture, as Mists had; `nameplateMotion` does not exist; `ObjectiveTrackerFrame:GetModules` does
not exist; the gamepad action storage starts at slot 181; Forever's default gamepad emulation is Shift =
PADLTRIGGER and **Ctrl = PADLSHOULDER** (not RT); `PVEFrame` and `PlayerSpellsFrame` do not exist.

## Naming

- Global table `DeckUIForever` (`local D = DeckUIForever`), SavedVariables `DeckUIForeverDB`, slash command
  **`/df`** (`/df build`, `/df unlock`, `/df bars`, `/df layout`, `/df errors`, `/df <page>`), key
  bindings `DECKUIFOREVER_*` in `DeckUIForever/Bindings.xml`, frame names `DeckUIForever*`. Module tables and
  commands get the same treatment when they are ported (`DeckUIForeverOrbsDB` or alike - decide at phase 2
  and keep to it). Frame keys for `D.MakeMovable` ("Main menu", "Loot") are unchanged, so DeckUI's
  positions could be carried over by hand if ever wanted.
- Everything in English: code, comments, menu texts, chat messages, README. The reports are German.

## What phase 5 changed against DeckUI's Week (2026-11-05; owner's first test the same day passed: renown
## tracks, reputation, empty currencies on a level 6 priest)

- DeckUI's Mists scaffold with Forever's content: `data_forever.lua` (the two renown tracks 2802 Legacy
  and 2800 PvP rank from the probe; no world bosses, weeklies or currencies by ID yet - `/week record`
  finds the hidden quests, a higher character the rest), `collect_forever.lua` (renown through
  `C_MajorFactions.GetMajorFactionData`, **every currency of the character's list** - collapsed headers
  hide theirs - and **every faction with standing** through `C_Reputation.GetFactionDataByIndex`, dailies
  and weeklies learned from `C_QuestLog.GetInfo`), `view_forever.lua` (columns Raids, Legacy, PvP rank,
  Dailies, Weeklies; details renown with progress, today's dailies by zone, reputation, currencies).
  `core.lua`'s retail collectors stay in the file unused (`ns.COLLECTORS` replaces them) and
  `C_MythicPlus` is guarded for a missing namespace; the button's Great Vault badge stays empty.

## Bars (2026-11-05, not in the report; owner: "action bars like FFXIV, but for the PC, not the controller")

- A module of its own, `DeckUIForever_Bars`, built from DeckUI Cross's `bars.lua` (the FFXIV slot look for
  bars 3-8) and `input.lua` (parking Blizzard's bars, the override bar fade, the leave-vehicle button):
  **all eight bars**, `ns.BARS` in core.lua with Blizzard's numbering (1 = ActionButton, 2 =
  MultiBarBottomLeft, 3 = MultiBarBottomRight, 4 = MultiBarRight, 5 = MultiBarLeft, 6-8 = MultiBar5-7).
  **Action Bar 1 pages** through the crosses' page state driver (`PageMacro`, states 1..NUM_PAGES on each
  button); the others hold their slot at state 0. Keys are Blizzard's commands (LAB `keyBoundTarget`
  shows them), the pushed glow mirrors Blizzard's hidden button. A number tag per bar (`barNumbers`),
  `hideKeys`, `barAlpha` shared, `barScale` per device, `bars[n].shown/perRow` - the first time a bar is
  seen, it is ours when Blizzard's was shown. **LibActionButton is patched in one line** (`WoWRetail`
  true for `WOW_PROJECT_CAMELOT`): Forever has secrets, duration objects, `C_LevelLink` and the
  assisted-combat API, so the retail paths are the right ones; the libs are otherwise DeckUI Cross's copy.
  The hub: `Bars` in `D.MODULE_ADDONS`/`MODULE_ORDER`, its description, `PAGE_FRAMES.Bars` (eight bars
  and "Leave vehicle"), `PAGE_RESET.Bars` on `DeckUIForeverBarsDB`, `/df bars` chains `D.PrintModuleBars`.
  **The slot look follows the owner's FFXIV hotbar screenshot** (2026-11-05): an empty slot is nearly
  transparent - a black shade at alpha 0.2 under a 1 px light outline (four WHITE8x8 lines at alpha 0.3)
  - the key sits white on the top-left corner (LAB hotkey at offset 0/+2, 11 px), the icon fills the slot
  behind the rounded mask. The dark edge and the dark fill of DeckUI's bars.lua are gone.
  The nil `DeckUIForeverBarsDB` of the first test is fixed (made on ADDON_LOADED, as Week does).
  Second LAB patch (owner's test 2026-11-05): `GetFlyoutInfo(id)` returns nothing for an unknown
  flyout in Forever where retail errors, so the two flyout loops skip a nil `numSlots` (marked
  "DeckUIForever" in the lib). Both patches must be carried over on a library update.
  Owner's test the same day after the two LAB patches: "very good" (PC, level 6 priest; paging on a
  form or vehicle and Edit Mode with parked bars not yet seen). When Cross is ported, both modules would park bars 1 and 2 -
  decide then which owns them on the PC. The module is not gated to the PC; what the Deck's gamepad style
  does with a parked `MainActionBar` is part of the postponed Deck run.

## What phase 3 changed against DeckUI's modules (2026-11-05; owner's first test the same day: "all good" after the two fixes below)

- **Spec**: `core.lua` is DeckUI's `core_mists.lua` (one button per talent group,
  `C_SpecializationInfo.SetActiveSpecGroup`, an equipment set per group). Forever has no spec inside a
  group, so a button shows the **class icon with the group's number** (`CLASS_ICON_TCOORDS` on the
  class circle sheet) instead of a spec icon. Page name "Talent groups".
- **Bags**: `ns.NumSlots(bag)` sizes the **keyring** (container -1) with `GetKeyRingSize`, as Blizzard's bag
  frame does - `GetContainerNumSlots(-1)` says 32; a "Keys" section in both views (`DeckUIForeverBagsDB.keyring`,
  on). No old-expansions filter (one expansion), no Mists item-button path. **The empty-slot background
  is drawn by hand** (file and texture coordinates of `ItemSlotBackgroundCombinedBagsTemplate`): the
  template is in Blizzard's 70532 source but not in the 70790 client (50 errors, owner 2026-11-05); the
  template is still tried first, through pcall. **The bank**: Forever keeps
  retail's `C_Bank` API over a Classic bank (`ShouldUsePlayerBagsInBank()` true): a tab is a bank bag
  slot (character 6-14, account 15-20), its bag item lives in the pseudo containers
  `Enum.BagIndex.Characterbanktab` (-2) / `Accountbanktab` (-3) at slot n. The tab icons in `bank.lua`
  show that bag, take a dropped bag (`C_Container.PickupContainerItem(pseudo, slot)`, what Blizzard's
  `BankItemButtonBagMixin` does) and carry its tooltip; "Buy tab" buys the next slot as before.
- **Quests**: no `delves.lua`, `hunt.lua`, `guide.lua`; `scenario.lua` lost the delve header, keystone and
  challenge-mode medals (no `C_ChallengeMode` in Forever); `tracking.lua` lost the Traveler's Log and the
  housing endeavors, and its achievements section is "Legacy challenges" (empty while the game rule
  `TrackAchievementsDisabled` holds). New `timers.lua`: Forever's classic quest timers from
  `C_QuestLog.GetQuestTimers()`, since Blizzard's `QuestTimerFrame` is a child of the hidden
  `ObjectiveTrackerFrame`. The kiosk path (`SetCanAddModules(false)`, `RemoveAllModules`) exists in
  Forever's manager; `ObjectiveTrackerFrame:GetModules` does not, which only the probe asked for.

## What phase 2 changed against DeckUI's modules (2026-11-05; owner's first test the same day passed after the EXP bar and debuff fixes)

- **Orbs**: `classpower_forever.lua` replaces `classpower_mists.lua` - rogues and cat druids have combo
  points, **on the target** (`GetComboPoints(unit, "target")`, as Blizzard's
  `Camelot/TargetBoundComboPointBar.lua`; oUF's Mists path listens to PLAYER_TARGET_CHANGED, the file adds
  COMBO_TARGET_CHANGED and force-updates every frame's ClassPower); the other seven classes show no dots.
  No `auras_mists.lua` (retail's AuraContainer is there). `debuffs.lua` keys its lists by **class token**
  with the Classic spells' base-rank IDs (matched by name, so higher ranks match too) - unverified guesses
  until `/orbs dots` says what the client knows; no poison rows (poisons are weapon enchants in Classic).
  Its spec events are `ACTIVE_TALENT_GROUP_CHANGED`, `PLAYER_TALENT_UPDATE`, `SPELLS_CHANGED`.
  **Countdown numbers**: Forever writes a Cooldown frame's countdown in a font far too big for a
  22 px status icon ("50m" filled the icon, owner 2026-11-05; retail picks a small one itself), so
  `ns.StyleCountdown(button)` in core.lua gives every aura icon's cooldown a font object of our own
  (`CreateFont`, 42% of the icon's width, min 7 px) - called from the aura styles in ffstyle.lua,
  layout.lua and party.lua. buffs.lua and raid.lua hide the numbers and need nothing. Owner saw it in
  game the same day: "much better".
  **Buff bar in combat**: `buffBarCombatKeep` (Buff bar page, "Keep the bar in combat", off by default)
  makes the bar ignore the combat limit and the combat hiding - owner's wish 2026-11-05, a low character's
  buffs are all long ones and the bar emptied in every fight. `Fighting(inCombat)` in buffs.lua is the
  one place that reads it. Untested in game.
  **An enemy's auras throw in combat** (`GetAuraDataByIndex`: "Auras cannot be accessed when secret while
  tainted", 1047 errors in the owner's first fight 2026-11-05): `Scan` in debuffs.lua pcalls the read, a
  throw marks the unit in `auraBlocked` (rows grey, not red) until PLAYER_REGEN_ENABLED. DeckUI's retail
  copy has the same hole - its debuff window was only ever tested in Mists. **The listed debuffs are then
  looked up by name** with `C_UnitAuras.GetAuraDataBySpellName(unit, name, "HARMFUL|PLAYER")` (`Lookup`):
  the one aura call without `RequiresUnitAuraAccess` in Forever's docs, it returns nil instead of throwing
  for a secret aura and may hand back secret times (`Left` keeps them out of the arithmetic, Paint draws a
  full bar). Whether a player's own DoT on an enemy stays readable in combat is Blizzard's per-spell
  flag - **and it is secret**: the owner's fight on 2026-11-05 gave "on target by name: no" for his own
  Shadow Word: Pain on a living target in combat. No Lua call of an addon reads a player's debuffs on an
  enemy in combat in Forever; only Blizzard's AuraContainer widgets (engine-filled, as on our FF target bar)
  and Blizzard's own Cooldown Manager show them. **So `debuffs.lua` was rebuilt on aura containers the
  same day** (owner's choice): every row is a `CustomAuraContainer` with one aura slot filtered to the
  debuff's spell IDs (the base ID plus every spellbook entry of that name, `RankIDs`), and the engine
  fills our pieces through `CustomAuraButtonSharedMixin` - `SetIcon`, `SetSpellName`, `SetDurationBar`
  (our PillBar, `StatusBarTimerDirection.RemainingTime`), `SetDurationText`, `SetApplicationCount`,
  `AddPandemicRegion` (a gold wash over the fill in the last 30%). A layer of ours underneath (same icon
  and name, empty capsule, red edge in a fight, dimmed out of it) shows while no button covers it. The
  "others" below the list are an aura group of four with `excludeSpellIDs`. Those pieces must be
  descendants of the engine's button and are laid out once at creation, so "Show the names" needs a
  reload; the bars stretch with the width. Nothing of ours reads an aura any more; `/orbs dots` prints
  the slot IDs. **Tested in game 2026-11-05**: Shadow Word: Pain filled its capsule with the time, in and
  out of combat. The window lost its box, edges and tag the same day (owner: like the player frame) -
  only the unit's name in gold over the capsules.
  **The XIV EXP bar fades Blizzard's `Main/SecondaryStatusTrackingBarContainer`, never parks them**
  (`FadeStatusBars` in ffstyle.lua): a container asks `GetParent()` for its manager, and under a parent
  of ours Edit Mode failed on entering (`CheckForLayoutChange` nil, owner's first test 2026-11-05). The
  same code is in retail - DeckUI's `ffstyle.lua` still parks them. A SetAlpha hook alone was not
  enough: Blizzard shows the container through `FadeInAnimation` (alpha 0 -> 1), which bypasses the
  hook, so both bars were on screen - the three alpha animations are set to run from 0 to 0.
- **Map**: retail's `PIECES`; `MinimapCluster.InstanceDifficulty` is nil in Forever (skipped), the
  day/night `MinimapCluster.DielFrame` is placed as a hover piece, `MinimapCompassTextureUnderlay`
  (the rotating map's second ring) goes to alpha 0, and a post-hook on `MinimapCluster.UpdateMinimapConfig`
  re-applies our mask and ring after Camelot's handler puts Blizzard's back on a rotateMinimap change.
  World map: retail's restyle, scale and CVars all on.
- **Nav**: `ns.ST`/`ns.UW`/`ns.NAV` are C_SuperTrack/C_Map/C_Navigation outright, no `nav_mists.lua`, no
  Ctrl-click handler of ours on the map (Blizzard's pin and USER_WAYPOINT_UPDATED do it).
- **Tooltip**: no spec name on players (item level alone, `AddLine`), no delve chest line and no
  `chestKeys` key, `repdata.lua` is retail's table (it holds the Classic-era reputation spells); the
  knowledge line stays guarded for professions that have no trees.

## What phase 1 changed against DeckUI's hub (so it is not "fixed" back)

- `core.lua`: `D.IsForever` as a guard only (named constant, never the number 18); `D.CharSpecKey`
  returns the **talent group** (1 before dual talents) where DeckUI returned the spec ID -
  `actionbars.lua` and `editmode.lua` key their per-device copies on it and listen to
  `ACTIVE_TALENT_GROUP_CHANGED` alone. `D.ModuleExists(key)` (`C_AddOns.DoesAddOnExist`) keeps the
  hub quiet about modules not ported yet. DEFAULTS lost the keys of the files left out.
- `actionbars.lua`: no assistant slot (`C_ActionBar.IsAssistedCombatAction` is in the exe, but
  `InterfaceOverrides.HasAssistedCombat()` is false in Forever), no Mists spellbook path.
- `editmode.lua`: Forever's Edit Mode keeps **layouts per interface style** (keyboard/mouse or
  gamepad, `layoutInfo.layouts[i].interfaceStyle`, nil = keyboard; EditModeManager.lua 887-900,
  1359-1387). `IndexOf` only finds a layout of the active style, so a saved name of the other style
  counts as missing and the active one is learned instead. Revisit with the Cross decision.
- `mainmenu.lua`: Camelot's micro buttons (`Blizzard_MicroMenu/Camelot/MicroMenuContainerOverrides.lua`):
  Spellbook and Talent are two buttons again, **LegacyMicroButton** stands where achievements were.
  `EJMicroButton` and `HousingMicroButton` are created, shown, yet never put into the menu (game rules),
  so they are left out of the row - `Available()` asks IsShown and would list them. No Mists
  direct-click path, no quest book bubble.
- `/df build` reads our interface number with `C_AddOns.GetAddOnInterfaceVersion`: `GetAddOnMetadata`
  hands out no `Interface` field in Forever (owner's test 2026-11-05).
- `panel.lua`: the Windows page keeps only the damage meter style; Cross's frames lose the assist
  indicator; the module descriptions name Forever's content.
- Left out of the toc: `talkinghead.lua`, `questbook.lua`, `meter.lua`, `lfgqueue.lua` (Forever's
  group finder is `Blizzard_GroupFinder_VanillaStyle`, no queue eye to replace - check in game),
  `charpanel.lua`, `mail.lua`, `restock.lua` (Mists helpers; enchants and gems matter again in
  Forever, so these are worth a later look against Camelot's own `PaperDollFrame.lua`).
- Kept as they were, with their feature checks: `merchant.lua` (falls back to selling one by one
  without `C_MerchantFrame.SellAllJunkItems`), `reputation.lua`, `lootroll.lua`.

## Release

`release-common.ps1` lists the addon folders (`$addons` - add a module there and
to `D.MODULE_ADDONS` when it is ported), `package.ps1` builds `dist\DeckUIForever-<version>.zip` with the
folders at the top level, `bump-version.ps1 <version> [-Interface 16002]` raises the `.toc` headers,
`changelog.ps1` takes the `## <version>` section of `CHANGELOG.md`. The workflow
(`.github/workflows/release.yml`) uploads on a `v*` tag through `upload-curseforge.ps1`; it needs the
secret `CF_API_TOKEN` and the repository variable `CF_PROJECT_ID`. The repository is
`https://github.com/JonasAudren/DeckUIForever` (public, made 2026-11-05, `origin`); the CurseForge project
does not exist yet - the owner makes it, then `## X-Curse-Project-ID` goes into the hub's toc. The tag's suffix decides the release type (`-beta`, `-alpha`, none = full release).

## Open, in order (DECKUIFOREVER_BERICHT.md section 7)

0. The probe ran on 2026-11-05 (build 70790, PC, keyboard style): section 8 of the report has the
   answers, `tools/probe_2026-11-05.json` the raw data. Still open from it: the Deck in the gamepad
   style, secure wrap scripts (the probe's test was inconclusive), professions and currencies on a
   higher character. To run it again: `..\DeckUI\tools\forever\DeckUI_Probe` is a junction in the
   client; log in, `/reload`, then `python ..\DeckUI\tools\forever\readprobe.py <scratch>` with
   `foreverscan.json` in that scratch folder (made by `foreverscan.py`, needs the two UI source trees).
1. Hub - done and loaded in game on 2026-11-05 without Lua errors (settings window, nameplates, loot,
   server info ticked by the owner). `auction.lua` and `auctionstyle.lua` hook `Blizzard_AuctionHouseUI`,
   and **that is Forever's auction house** (retail's frame, a Camelot `Blizzard_AuctionData.lua` for the
   categories); the probe's nil `AuctionHouseFrame` was the load-on-demand addon not loaded yet, and
   `IsUsingLegacyAuctionClient` is a Classic global nothing reads here. The first reading of 2026-11-05
   ("legacy auction house, dead weight") was wrong. The scan button at an auctioneer is untested in game.
2. Orbs, Map, Nav, Tooltip - done and tested in game 2026-11-05 (PC; the Deck and a rogue's combo
   points still untested).
3. Spec, Bags, Quests - done and tested in game 2026-11-05 (PC, a low-level priest: bags, keyring,
   bank bag slots, tracker; a timed quest and dual talents not yet seen).
4. Cross - after the style decision; totem bar, Forever's default bindings. **The Deck run (the probe in
   both interface styles) is postponed until the owner says so (2026-11-05) - do not ask for it.** The
   keyboard-style path (Cross as in retail, the PC's own bindings) can be ported before that; only what
   the Deck does with Blizzard's gamepad style waits.
5. Week - done and tested in game 2026-11-05 (level 6: Legacy 0/90, PvP rank 0/14, four factions).
   Still to see on a higher character: currencies, lockouts, dailies; world bosses by `/week record`.
6. Release, then the Deck test.
