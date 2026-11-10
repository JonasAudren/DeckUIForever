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
DeckUIForever_Questing/ 2026-11-07, owner's wish: the NPC dialog on autopilot, reward marks, zone tracking,
                    the quest item key, the quest compendium on Questie's database (/questing, /compendium)
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

- **Renamed on 2026-11-05 from DeckForever to DeckUIForever**: the CurseForge name DeckForever was taken.
  Folders, toc files, the global table, SavedVariables, frame names, bindings, scripts, docs, the logo and
  the GitHub repository (`JonasAudren/DeckUIForever`) carry the new name; `/df` stays. **The repository
  folder on disk is still `C:\Users\Gottl\Desktop\TitelX\DeckForever`** (a Claude session was running
  in it) and the client's junctions point there - rename it when nothing runs in it, then make the ten
  junctions again. Old `DeckForever*` SavedVariables in the client's WTF folder are orphans, harmless.
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
  **Recast timer (2026-11-09, owner: "CD Timer im FFXIV Stil")**: `CooldownLook` in core.lua styles every
  slot's Cooldown widget (via `Style`, so stance and pet too; the totem bar's Blizzard buttons not):
  the game's own countdown (`SetCountdownFont` with a font object, 18 px THICKOUTLINE white, centered,
  milliseconds threshold 0, minimum duration 2000 ms so the GCD shows the sweep only). Nothing reads
  start/duration - they can be secret, LAB passes duration objects. LAB's `config.cooldownCount` follows
  `cdNumbers` (default on) instead of the `countdownForCooldowns` CVar; `ns.ApplyCooldownNumbers` is live.
  Owner's test 2026-11-09: "läuft gut".
  The nil `DeckUIForeverBarsDB` of the first test is fixed (made on ADDON_LOADED, as Week does).
  Second LAB patch (owner's test 2026-11-05): `GetFlyoutInfo(id)` returns nothing for an unknown
  flyout in Forever where retail errors, so the two flyout loops skip a nil `numSlots` (marked
  "DeckUIForever" in the lib). Both patches must be carried over on a library update.
  Owner's test the same day after the two LAB patches: "very good" (PC, level 6 priest; paging on a
  form or vehicle and Edit Mode with parked bars not yet seen). When Cross is ported, both modules would park bars 1 and 2 -
  decide then which owns them on the PC. The module is not gated to the PC; what the Deck's gamepad style
  does with a parked `MainActionBar` is part of the postponed Deck run.
- **Stance, pet and totem bars** (2026-11-05, owner: "complete the bars", for 1.1.0): `stance.lua` is
  DeckUI Cross's stance.lua as a row of square slots (SecureActionButtons of type "spell" with the form's
  spell ID; keys stay Blizzard's SHAPESHIFTBUTTONn, which run `StanceBar:Select` whether the bar is
  visible or not, so no override bindings). `pet.lua` is new: SecureActionButtons of type "pet"
  (`type1` only, `action` = slot), right click `TogglePetAutocast` in PostClick on the release, the
  visuals read from `GetPetActionInfo` as Blizzard's PetActionBarMixin does, guarded with `Plain` for
  secrets; shown by a state driver `[pet,nopetbattle,novehicleui,nooverridebar,nopossessbar]`; keys are
  BONUSACTIONBUTTONn (Blizzard's hidden buttons, pushed state mirrored). `totem.lua` does not rebuild
  Blizzard's `MultiCastActionBarFrame` (an Edit Mode system with secure buttons, flyouts and its own
  anchoring): it fades the ring art and adds the slot look to the 12 action, 4 slot and 2 spell buttons
  (`Dress`), nothing of Blizzard's is wrapped - taint-safe; undo needs a reload. `ns.StyleSlot`,
  `ns.ShowPushed`, `ns.KeyText`, `ns.KeyLabel`, `ns.extraRows` in core.lua are what the three share;
  `stanceBar`, `petBar`, `totemBar` default to on. Blizzard's StanceBar and PetActionBar are parked through
  `ns.SetBlizzardBarHidden`. **Untested in game** (the owner's priest has no forms, no pet, no totems -
  a druid, hunter or shaman is needed).

## Pad (2026-11-07, owner's wish after the first Steam Deck run: "all square, like FFXIV")

- The Deck run happened on 2026-11-07: everything ran, and the owner switched some modules off because
  Blizzard's native controller support serves better there - so the Deck keeps **Blizzard's gamepad
  style** (option B of the report's section 3.5), and Cross stays a keyboard-style thing. Which
  modules the owner switched off is not recorded yet.
- `DeckUIForever_Pad` dresses Blizzard's `GamepadMainActionBarFrame` in the Bars module's slot look
  and changes nothing of the input. Read against the `forever` branch of Gethe/wow-ui-source
  (`Blizzard_GamepadActionBars`: ActionBarButton.xml/.lua, ActionBarStyles.lua, ActionBarTemplates.xml,
  PageUnit.lua, MainActionBarFrame.xml): every button is a `GamepadActionBarButtonTemplate`
  (ActionBarButtonTemplate plus circle/square masks, shadows, focus glows, a `SlotArt` glyph as the
  empty slot, a `ButtonIcon` glyph frame), and Blizzard calls `SetShapeToSquare` (D-pad group) or
  `SetShapeToCircle` (face group) on **every** expand, collapse and press through
  `GamepadActionBarStyleUtil.ApplyExtraButtonStyles`, which also sizes and anchors the protected
  button. **Never write into `GamepadActionBarStyleUtil.circleStyleParams` or any field Blizzard's
  style path reads**: that path runs `SetSize`/`SetPoint` on secure buttons in combat and would be
  blocked when tainted. The module only post-hooks (`hooksecurefunc`) the buttons' own
  `SetShapeToCircle`/`SetShapeToSquare` (hide both masks, our rounded mask on the icon, cooldown swipe,
  glyph to the top-left), `SetCircleCastingTextures` (square cast atlases), `SetButtonState`
  (our gold pushed glow; a pad press is no mouse press) and `SetChecked`; the bar's `HideButtonIcons`
  (glyphs on every bar); the textures' `SetTexture`/`SetAtlas` keep the faded art faded. The focus
  shadows' alpha is animated by Blizzard, so their texture is removed, not faded. `BackgroundFocus`
  becomes a flat black panel anchored to the bar with a 1 px outline that follows its Show/Hide.
  Bars dressed: the page unit's `actionBars` (top, left, right, bottom, possess, stance, the two
  targeting bars, shortcuts) and the two class action buttons; the radial flyouts, the page tracker,
  the shoulder badges and the input legend are untouched. `DeckUIForeverPadDB`: `glyphs`, `emptyGlyph`
  (reload), `focusPanel`, `slotAlpha`. Hub: `Pad` in `MODULE_ADDONS`/`MODULE_ORDER`/`OFF_BY_DEFAULT`,
  page "Controller bar" under Actions, `/df pad`, `release-common.ps1`. The slot mask is a copy of
  the Bars module's `slot_rounded.tga`. **Untested in game** (needs the Deck in the gamepad style).

## Gamepad windows (2026-11-07, the owner's pick from the Deck-support ideas: "Steuerkreuz in Fenstern")

- `DeckUIForever/gamepad.lua` hands our windows to Blizzard's window navigation in the gamepad style.
  Read in the `forever` branch of Gethe/wow-ui-source: `Blizzard_GamepadSharedUtility/FrameControlsManager.lua`
  ("A frame can subscribe to this by ... manually calling FrameShown on their OnShow event"),
  `Blizzard_GamepadSmartNavigation/SmartNavigation.lua`, `Utility.lua` (`Utility.FindButtons` takes every
  Button, CheckButton, EditBox or frame with an OnMouseUp/OnMouseDown script under the panel, scroll
  frames as groups of their own; Sliders are not buttons) and `SecureHelper.lua` (`WrapFunction`:
  an insecure caller is run through a SetAttribute "invoke" round trip, allowed by
  `IsSecureOrOutOfCombatRestriction`, refused with "interface action blocked" in combat).
- `D.GamepadWindow(frame, { close = button-or-function, popup = true, evict = { BlizzardFrame } })`
  hooks OnShow/OnHide: `GamepadMode.FrameControlsManager:FrameShown(frame)` / `FrameHidden(frame)`
  (`HandlePopupShown`/`HandlePopupHide` for a popup, so the cursor returns to the window it came
  from), only when `InputUtil.IsGamepadUIEnabled()`, the option `DeckUIForeverDB.gamepadNav` is on and
  neither `InCombatLockdown()` nor `C_RestrictedActions.IsAddOnRestrictionActive(Combat)`; what
  happened in combat is synced on PLAYER_REGEN_ENABLED, the style switch
  (INPUT_DEVICE_INTERFACE_TRANSITION) clears our `registered` set and syncs a frame later.
  `evict` withdraws Blizzard's own frame behind ours (the Bags module parks `ContainerFrameCombinedBags`
  and `BankFrame` under hidden parents; the manager still lists them from its OpenBag callback and
  ShowUIPanel, an empty second stop for LT/RT). **Call it after the file's own SetScript("OnShow"/
  "OnHide")**: SetScript drops hooks.
- The optional callbacks the manager looks up with `securecallfunction` are set on the frame:
  `FocusGamepad`/`UnfocusGamepad` (a gold 1 px outline, `frame.DeckPadFocus`), `Show/HideLeft/Right/
  FocusJumpHint` (`frame.DeckPadHints`: Blizzard's glyph frames, `InputIconTextureFrameTemplate` with
  `SetInputKey(GAMEPAD_TRIGGER_LEFT/RIGHT/GAMEPAD_MENU_LEFT)`, hanging above the top edge; our text
  badge if the template were missing) and `SmartNavigationCloseHandler` (B: the window's own close
  button is clicked, so each window closes as it always has - the bags through CloseAllBags, the
  loot window through CloseLoot; returns true). All frames are made at registration, never inside a
  manager callback.
- Registered: `DeckUIForeverPanel` (panel.lua), `DeckUIForeverDialog` as popup (widgets.lua),
  `DeckUIForeverLootWindow` (loot.lua), `DeckBagsWindow` and `DeckBankWindow` (Bags), `DeckWeekWindow`
  (Week). Hub: `gamepadNav` in DEFAULTS, checkbox "D-pad in DeckUIForever's windows" under Controller
  on the Devices page (`D.SyncGamepadWindows` applies it live), `/df gamepad` (`D.PrintGamepad`).
  **Untested in game** (needs the Deck in the gamepad style); the sliders of the /df window stay the
  trackpad's, and the Quests module's tracker is not Blizzard's `ObjectiveTrackerFrame`, so the HUD
  mode's first stop is missing with Quests on - both open.

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
  The lists were read against Classic's spell IDs on 2026-11-05 (all base IDs right) and grew by Faerie
  Fire (Feral) 16857 (a name of its own), Stormstrike 17364, Fire Vulnerability 22959 (from Scorch 2948),
  Winter's Chill 12579 (talent 11180), Judgement of the Crusader 20188 (Seal 21082). Still to confirm
  with `/orbs dots` on a warlock, rogue or mage.
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
  the slot IDs. **A piece handed to the engine's button is forbidden to us afterwards**: `SetText` on
  the live name threw "forbidden object" when a row was reassigned (owner 2026-11-05), so the engine
  names every row (`SetSpellName`), and `Assign` touches only the static layer and the slot filter. **Tested in game 2026-11-05**: Shadow Word: Pain filled its capsule with the time, in and
  out of combat. The window lost its box, edges and tag the same day (owner: like the player frame) -
  only the unit's name in gold over the capsules.
  **`hots.lua` (2026-11-06, owner: "an overview in the same style for healers and HoTs", for 1.2.0; rebuilt
  around the party on 2026-11-07 for 1.3.0, owner: "Ziele nicht in unserer Party nur im Target, aber für alle
  Party-Ziele, auch mich, alle Daten in einem Fenster - welche HoTs und Buffs drauf sind", and made compact
  the same evening, owner: "viel kompakter, keine Balken sondern Kreise die sich schließen")**: debuffs.lua's
  container build with `HELPFUL|PLAYER` slots, but **a line per unit with round icons, no capsules** - lists
  `DRUID` 774 Rejuvenation, 8936 Regrowth; `PRIEST` 139 Renew, 17 Power Word: Shield (Classic has no other
  HoTs; the other classes get the buff icons alone). **One line per party token** (`PARTY` = player, party1-4,
  made once on that token, `members`, you first) shown while the token exists, and a **`stranger` line on
  `target`** shown while the target is friendly (`Friendly`) and its GUID matches none of the five (`InTable`;
  GUIDs, not `UnitIsUnit`, which may be secret in a fight). A line: the name (`NAME_W` 64, "You" for the
  player), one `SlotFrame` per list entry in a fixed place (so the heals line up across the members), the
  buff group after them. **A slot's engine button gets a Cooldown frame of ours** (`LiveButton`:
  `SetDurationCooldown`, the engine runs `SetCooldownFromDurationObject`; swipe texture `D.MASK` so the clock
  is a circle, `SetReverse(true)` as Blizzard's buff frame, countdown font `ns.CountdownFont`), the round
  icon (`Round`: a portrait-mask MaskTexture on the texture), the count on the cooldown frame and a gold
  disc behind the icon as the pandemic rim (`Rim`, `AddPandemicRegion`); every piece is anchored to the
  button before the hand-over, so the slots follow a size change live. Under it our static icon with a
  grey or red rim (`SetStatic`: red in a fight, dimmed with `hotIdle`, else hidden - the slot stays empty).
  Lines stack or go side by side (device `hotAcross`, `Stack`), the icon size is device `hotScale` as a
  percentage of `ICON` 22 (`Size`, `ns.ApplyHotSize`; the buff icons were sized by the engine at creation and
  follow at the next reload, `D.NeedReload`). `Update` runs every 0.25 s and on PLAYER_TARGET_CHANGED
  (`RefreshUnit(stranger)`), GROUP_ROSTER_UPDATE and PLAYER_ENTERING_WORLD (every member's containers
  re-read their token). The buff icons (`Others`, group "others", one unwrapped horizontal line sized for
  `MAX_ALL`) are `HELPFUL|PLAYER` with `maxDuration = 60` and 6 icons, or with `hotAllBuffs` `HELPFUL`, no cap,
  10 icons (`SetAuraGroupFilterString`/`SetAuraGroupMaxFrameCount`/`SetAuraGroupCandidateFilters` live,
  `ns.ApplyHotBuffs`); the list's IDs are excluded either way. The list's IDs leave the target frame's buff
  icons through **`ns.targetBuffs`** (layout.lua registers the orb's buff containers with their `base`
  filters, ffstyle.lua's `AuraRows` with `registerBuffs`; `Merged` adds our IDs to the base exclusions) -
  those icons show everyone's buffs, hence the `hotExclude` switch (on). Keys `hot*` (`hotTracker`,
  `hotAllBuffs`, `hotExclude`, `hotIdle`, `hotPreview`, device `hotScale`, `hotAcross`), movable "HoTs", page
  "HoTs" ("Your HoTs") under Orbs, `/orbs hots` prints every line. **Gone in 1.3.0**: `hotSelf`, `hotKeep`,
  `hotAttach`, `hotAbove`, `hotNames` (the focus column, the kept columns, the rows at the target frame, the
  capsules' names; old saved values are ignored). The 1.2.0 window (capsules; target, focus, "You" fallback)
  was seen in game on 2026-11-06; **the party lines were seen in game the same evening, 2026-11-07** (owner:
  "viel besser"; the first table with capsules and gaps had been "gefällt mir gar nicht").
  **The debuff window's icon mode (2026-11-07, owner: "das selbe mit den DoTs, aber optional, ich will die
  Balken auch behalten")**: `dotIcons` (off, `/reload`; config.lua compares against `loaded.dotIcons`). The
  round-icon pieces live in debuffs.lua since it loads before hots.lua: `ns.RoundIcon(tex)`, `ns.IconRim(parent,
  r, g, b, a)`, `ns.AuraIconButton(button, size)` (the engine button's icon, Cooldown, count and pandemic rim);
  hots.lua calls them. debuffs.lua reads the mode once in its factory (`icons`) and branches in `Row`
  (`IconRow`: a slot of `Size()` = `ICON_SIZE` 22 scaled by device `dotScale`), `SetStatic` (`SetStaticIcon`),
  `Others` (`IconOthers`: one unwrapped horizontal line of `MAX_ICONS` 8), `Finish` (`FinishIcons`: the name
  at the left, `NAME_W` 64, the slots after it, `attached` drops the name; the column is one line high and
  sets `c.width` itself), `ApplyDotWidth` (icon mode resizes the slots and flags a reload for the others' icons),
  `ApplyDotNames` (nothing), `Update` (the holder's width follows the lines) and the preview. Columns, focus,
  kept columns, attach, idle, keep: unchanged. **Untested in game.**
  **The HoT window's click to cast (2026-11-07, owner: "Healer-Modus, aber mit An und Aus")**: `hotHealer`
  (off, `/reload`, `loaded.hotHealer` in config.lua), read once in the factory (`healer`) before `MakeLines()`
  makes the six lines (they are no longer made at file load). With it every slot gets a
  `SecureActionButtonTemplate` over the engine's button (`SecureButton`: type spell, `unit` = the line's
  token, `spell` = the entry's name set in `Assign` out of combat, `pendingSpell` until then; `AnyDown` +
  `AnyUp`, the template picks one; our OnEnter shows `GameTooltip:SetSpellByID`), the name a target button
  (`c.target`), and each line a state driver (`[@partyN,exists] show; hide`, the stranger
  `[@target,help,nodead,noparty] show; hide` - solo, targeting yourself shows you twice; the restricted
  environment cannot compare units). **A secure child protects its parents**: slot, line and holder may not
  be moved, sized, shown or hidden by us in combat, so `Locked()` (`healer and InCombatLockdown()`) returns
  early from `Finish`, `Stack`, `SlotFrame` (no new slot in a fight; `FillLine` breaks) and the holder's
  Show; `ApplyHotSize` and the tracker's Hide go through `ns.OutOfCombat`; `FillLine`/`Update` never call
  Show/Hide on a line in this mode, and `ShowPreview` only shows the holder. `Stack(count, extra)` now gives
  every member a fixed row (party tokens are contiguous) and the stranger row `count`, in both modes. The
  static layer always shows in this mode (`SetStatic`). PLAYER_REGEN_ENABLED runs `Update`, which lays out
  what the fight left. **Untested in game.**
  **The rows follow the game's group order (2026-11-08, owner: "die HoT-Liste an die Gruppe anpassen ... ich bin
  an erster Stelle, ich will in meiner Gruppenstelle sein", asked which order and picked "Raidgruppe")**: `Rows()`
  gives the present members rows 0..count-1 - in a raid sorted by `UnitInRaid(token)` (the raid index; Blizzard's
  `CompactRaidGroup_UpdateUnits` fills a raid group's five frames in `GetRaidRosterInfo` order, so the player
  sits at their place in their raid group, and in a raid party1-4 are that group's other members), in a party
  by token (you first, party1-4 - `CRFSort_Group` puts the player first too; the game has no join position for
  you in a party) - the gone ones from row `count` on, where the stranger also sits; `Stack` places by `Rows()`
  (`c.row`). `UnitInRaid` is `SecretWhenUnitIdentityRestricted`: a secret keeps the last order (`lastRows`). In
  the healer mode `Stack` still runs out of combat only, so a roster change mid-fight sorts after the fight.
  `/orbs hots` prints "order: raid group/you first" and each line's row and raid index; the window switch's
  tooltip in config.lua says the order. No option. **Untested in game.**
  **The target line is an option (2026-11-08, owner's screenshot: "komischerweise wurde immer ein 6ter in der
  Gruppe angezeigt obwohl kein NPC in der Nähe war" - the sixth line was "Thom Filch", an NPC he had targeted;
  a target stays at any distance)**: `hotStranger` (on, layout.lua default; `StrangerWanted`). Off,
  `StrangerOn` is false, and in the healer mode `ns.ApplyHotStranger` (through `ns.OutOfCombat`) unregisters
  the line's state driver (`STRANGER_SHOWN`) and hides it; on again, it registers the driver. `Line` registers
  it only when the key is on. `/orbs hots` prints "target line on/off". **Untested in game.**
  **Controller glyphs (2026-11-07, owner: "in die native Controller-Steuerung einbinden, als Option")**: read in
  the `forever` source - `Blizzard_GamepadTargeting` (GroupTargeting.lua: `GroupTargeting:StartTargeting(container)`
  runs SmartNavigation over frames with a `.unit` and clicks the chosen one; RaidTargetDPAD.lua starts it on
  `CompactPartyFrame`/`CompactRaidFrameContainer`), `Blizzard_GamepadActionBars/TargetActionBars/
  FriendlyTargetingActionBar.lua` (friendly target modifier held: D-pad top/right/bottom/left = `party1-4` as
  secure target buttons when CVar `GamepadUsePartyTargeting`, else SmartNavigation over the raid frames; face
  bottom = player, left = pet, right = targettarget, top = raid marker), `Blizzard_Gamepad/Utility/Bindings/
  HoldBindings.lua` (`GamepadMode.RegisterTargetModifierStateChanged(cb, owner)`, `GamepadMode.IsTargetingModifierDown
  (GamepadTargetingState.FRIENDLY)`), SmartNavigation.lua/SecureHelper.lua (addon frames only out of combat, and
  a registered window counts as open - `RaidTargetingFreeSelection:CanUseFocusButton` needs
  `GetShownFrameCount() == 0`). **So the HoT window never registers with the window manager**; `hotPadHints`
  (on) only draws Blizzard's key pictures (`InputIconTextureFrameTemplate`, `SetInputKey`; keys from the
  legend's globals `GAMEPAD_DPAD_TOP` etc., fallback binding names) before the names (`Glyph`, `PlaceTitle`
  shifts the title), alpha 0.4, 1 while the modifier is held (`UpdateHints`, every Update and from the modifier
  callback), 0 outside the gamepad style, in a raid or with the CVar off (`HintsOn`). Alpha only, never
  Show/Hide: the lines may be protected (healer mode). Event INPUT_DEVICE_INTERFACE_TRANSITION is registered
  for the style switch. **Untested in game** (needs the Deck in the gamepad style).
  **The extensions of 2026-11-10 (owner: "den HoT-Monitor erweitern, aber alles immer als Option"; picked from a
  list, plus "alle Healerspells und Buffs, die ich casten kann, solange diese nicht auf dem Spieler sind")**: twelve
  keys, all off, hots.lua's header lists them. Entries now carry a `kind`: `hot` (the engine's slot, as before),
  `buff` (`hotBuffSlots`, table `BUFFS` priest/druid/mage with the group versions under `also`: our static icon
  shows only while `BuffMissing` says so - `GetAuraDataBySpellName(unit, name, "HELPFUL")`, the truth out of a
  fight; in a fight only a hit counts and the last answer stands; never for the dead, the invisible or a targeted
  NPC, nor ever on a pet line - a pet is an invalid target for them in Forever (owner's test; `C_Spell.IsSpellInRange`
  answering nil was tried as the test and did not catch it); paladin blessings are left out on purpose), `cast` (`hotCastSlots`, table `CASTS`, only with `hotHealer`: a
  plain button; **`need`** since the same day, owner: "Debuff-Knöpfe nur wenn man wirklich etwas debuffen kann
  und Resurrect nur bei Toten" - `need = "cure"`: `CureFrame`, a one-slot container on `DISPEL_FILTER` whose
  engine button carries our spell icon, so it shows in a fight too; out of a fight `DebuffTypes`
  (`GetAuraDataByIndex`, `dispelName`) hides a cure for another kind by alpha; the secure button under it still
  takes a click. `need = "dead"`: `DeadOnly`, a visibility state driver `[@unit,dead]` on the secure button, which
  carries the icon itself; that slot keeps full alpha on a dead line). `hotCustom` (a string, names or IDs between commas, edit box on the page, `CustomList`) adds
  `hot` entries; `ns.ApplyHotList` rebuilds. A slot's container is hidden for the non-hot kinds (`Assign`).
  `hotRegen` (same day, owner: "meine aktuelle Manareg ... als Option im HoTs-Fenster"): a text above the holder,
  no row of it (`UpdateRegen` in `Update`) - `GetManaRegen()` times five as MP5, the rate that holds now and the
  other in grey; the five-second rule is our own clock (`lastSpend`, UNIT_SPELLCAST_SUCCEEDED on a frame of its
  own, `SpendsMana` via `C_Spell.GetSpellPowerCost`; fixed the same day after the owner's fight left the line stuck at
  "in 5 s" - a secret cost had counted as a spend, wand shots too: now a drop of readable mana on UNIT_POWER_UPDATE
  decides, else the cast by its cost as last read out of a fight (`costKnown`), never Shoot/Auto Shot/Attack, and
  an unknown cost or a secret spell ID is no spend); a secret rate keeps the last text; `/orbs hots` prints the
  raw values. Untested: whether Forever's `GetManaRegen` gives both rates and stays readable in a fight.
  `hotCooldown` (same day, owner: "bei Spells ein CD-Timer, wenn gebraucht"): a Cooldown frame of ours per slot
  (`SlotCooldown`/`StyleCooldown`), fed as LibActionButton's retail path - `C_Spell.GetSpellCooldown(name)` for
  `isActive`/`isOnGCD` (no GCD), `C_Spell.GetSpellCooldownDuration` into `SetCooldownFromDurationObject`
  (`EntryCooldown`, asked once per spell in `ApplyCooldowns`); `cdDirty` (SPELL_UPDATE_COOLDOWN, `Assign`, size,
  the switch) makes `Update` apply. Cast slots: sweep and time in the middle; hot slots: a small number on the
  top edge, no sweep; a resurrection's clock is parented to its secure button; none for cures and buffs. Untested.
  Per line: `hotHealth` (in the FF look since the same day, owner: "in FFO-Stil" - `ns.PillBar`, a capsule `HEALTH_H` 5
  high under the name, which `PlaceTitle` lifts by `HEALTH_LIFT` while `c.lifted`; `hotHealthBlock` brings back the flat bar behind the whole name, `c.healthBlock`, both are made
  and `UpdateHealth` shows one; fed secrets and all, UNIT_HEALTH updates the bar alone; the
  name moved onto a child frame above it), `hotStatus` (`Status`: words on a frame above the slots, slots at alpha
  0.25), `hotRange` (`UnitInRange` into `SetAlphaFromBoolean`, not for you or the target line; pets too since the same day, and a readable `checked == false` keeps the line lit), `hotDispel`
  (`Dispels`: an aura group of two with raid.lua's dispel filter between name and slots, `DispelWidth` in
  `LineWidth`). `hotPets` and `hotRaid` are read at the factory (`petsOn`, `raidOn`, reload): lines `pet`,
  `partypet1-4`, each in the row under its owner (`pets[i]` is `members[i]`'s; `Stack`), the whole line scaled to
  `PET_SCALE` 0.8 (`SetScale` in `Line`; `Stack`'s `Put` works in holder pixels and divides a pet's offsets by
  the scale), stepped in by `PET_SHIFT` and the name pale blue (`PET`), owner: "klar zum Hunter oder Hexer
  zuordnen", "kleiner und leicht versetzt"; `Finish`'s `At` keeps a pet's slots centred in the members' columns all the same; `raid1-40` with `RaidMode()` (option and `IsInRaid`) - `Stack` then lays a
  column per raid group in use (`GetRaidRosterInfo`, a secret freezes the table), four to a band, no "others"
  icons, the party lines hide (`[group:raid] hide;` in their healer-mode drivers, the target line's driver gets
  `noraid`), `InTable` asks `UnitInRaid("target")`. `hotWarn`/`hotWarnSound`/`hotWarnAt`: `Remaining` reads the
  HoT by name each tick, a red pulse frame per slot (`SetWarn`) and one sound a second at most - where the times
  are secret in a fight nothing happens. `/orbs hots` prints the switches and every slot with its kind.
  **All untested in game**; first things to see: whether the times and a friend's buffs are readable in a fight,
  and whether Forever knows `RaidPlayerDispellable`.
  **The unlock preview is an option since 2026-11-06** (owner: "take the HoT and DoT preview out, as an
  option"): `dotPreview` / `hotPreview` (off) decide whether `ShowPreview` fills the three sample rows;
  off, the holder shows as an empty box three rows high so the Move overlay has something to drag.
  **The empty capsules out of combat are an option since 2026-11-06 too** (owner's screenshot: "turn this
  off, as an option"): `dotIdle` / `hotIdle` (off) - `SetStatic` hides the static layer's pieces out of a
  fight unless asked for (or forced by the preview), and a column's title (`Title`) shows only when
  `Running(c)` finds one of the list on the unit by name (`C_UnitAuras.GetAuraDataBySpellName`, out of a
  fight nothing is secret; pcall, a secret or a throw counts as none). In a fight the red missing
  capsules always show. **Never put a script on the engine's button, not even a HookScript**: the
  first build tracked OnShow/OnHide on it, and the engine's `SetShown` with a secret then threw
  "Cannot be called with secrets due to existing script handlers" inside `AddAuraSlot` for every row
  (1514 errors, owner 2026-11-06), so no row was ever made and both windows stayed empty. `/orbs dots`
  and `/orbs hots` print "running by name" and whether the title is shown.
  **Kept columns (2026-11-06, owner: "keep the DoTs and HoTs on targets when I switch targets")**:
  `dotKeep` (on; hots.lua had `hotKeep` until the party table of 1.3.0 made it moot). A left unit needs a
  unit token of its own for the containers: debuffs.lua takes `nameplate1-40` (`TOKENS`, `TokenFor(guid)`
  each tick). `Update` notes the target column's GUID (`lastGUID`) and whether the lookup ever saw one of
  the list on it (`lastRunning`); on a change `Keep` makes a column (pooled, `allKept`, focus width,
  newest first, at most `MAX_KEEP` 4) when that or a cast of ours on it (`UNIT_SPELLCAST_SUCCEEDED`
  for `player`, IDs in `allIDs`, `castOn[guid]`) says it carries one. `UpdateKept` fills each with
  `FillColumn(column, token)` (`SetColumnUnit`), drops it without a token,
  dead, out of a fight with nothing running (the lookup, a second after a cast) or `KEEP` 30 s after
  the last cast or sighting, and stacks them under the target column (`GAP`); the holder's height is
  the stack. Window only (`attached` drops them); `SetDotTracker(false)` drops all. `/orbs dots` lists
  them. **In a fight an enemy's GUID is secret** (owner 2026-11-08, 1.3.0: `UnitGUID("target")` came back
  secret - 239 errors: a secret as `castOn`'s key, in `k.guid == guid` and in `guid ~= lastGUID`), so
  every GUID goes through `GUID(unit)` (`Ask(UnitGUID)`, nil when secret; debuffs.lua and hots.lua each
  have one) and `CastOn` drops a secret: a secret unit is unknown - no kept column for it, no match on a
  nameplate (`TokenFor`), the hots stranger line stays off while its GUID is secret. So the kept columns
  work out of a fight and wherever the game shows the GUIDs; whether a hostile target's GUID is secret in
  every fight or only for some units is **to be seen in game**.
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
- Left out of the toc: `talkinghead.lua`, `questbook.lua`, `meter.lua`, `lfgqueue.lua`. **Forever has no
  dungeon queue** (checked 2026-11-05): `Blizzard_GroupFinder`'s `PVEFrame.lua` loads for wrath, cata,
  mists and mainline but not camelot; the LFD micro button opens `Blizzard_GroupFinder_VanillaStyle`
  (`LFGParentFrame`, a listing browser on `C_LFGList`, Classic Era's tool). `GetLFGQueueStats` exists as
  an API without a finder behind it, `QueueStatusButton` exists for battleground queues. So DeckUI's
  queue window has nothing to show. **In its place `lfglisting.lua`** (owner 2026-11-05: "a window with
  the time and what it has found"): shown while `C_LFGList.HasActiveEntryInfo()`, the activity names
  (`GetActiveEntryInfo().activityIDs` -> `GetActivityInfoTable`, `maxNumPlayers` as the group's size),
  a clock of ours from the entry's first appearance (the entry carries no age), the offered roles from
  `C_LFGListRoles.GetRoles()` and the party's roles from `UnitGroupRolesAssigned` (the tool assigns
  them, `PLAYER_ROLES_ASSIGNED`). `listingWindow`, Windows page, movable "Group listing"
  (`PAGE_FRAMES.Windows`). Blizzard's eye stays. Untested in game.
- **The Mists helpers are in since 2026-11-05 (for 1.1.0)**: `mail.lua` and `restock.lua` unchanged but
  for the names (Forever's mail frame is retail's `Blizzard_MailFrame` with `OpenAllMail`; the merchant
  API is retail's). `charpanel.lua` lost Mists' gems and belt buckle (Classic has no sockets) and checks
  Classic's enchant slots: head, shoulders, back, chest, wrists, hands, legs, feet, main hand, an
  off-hand weapon or shield (`C_Item.GetItemInfoInstant` class/subclass, a held frill takes none), a bow,
  crossbow or gun in the ranged slot; rings never. Slot buttons are Camelot's `PaperDollFrame.xml`
  (`CharacterHeadSlot` ... `CharacterRangedSlot`, `CharacterAmmoSlot` ignored); the summary line sits
  6 px under `CharacterFrame`, whose tabs are at the side (`ModeTabs`). Options: `charPanel` on the
  Windows page, `restock` and `mailHelper` on Loot and merchant; all off by default. Untested in game.
- Kept as they were, with their feature checks: `merchant.lua` (falls back to selling one by one
  without `C_MerchantFrame.SellAllJunkItems`), `reputation.lua`, `lootroll.lua`.

## Questing (2026-11-07, owner: "ein Modul um das Questen zu erleichtern", then the level range on the map and "ein
## Kompendium aller Quests nach Gebieten, Klassen, Questreihen, abgeschlossen oder nicht, wo annehmen, Voraussetzungen")

- `DeckUIForever_Questing`, LoadOnDemand, `DeckUIForeverQuestingDB`, page "Questing" under World, off by default.
  `core.lua`: DEFAULTS, `ns.Paused()` (held pause key `pauseKey` shift|ctrl|alt|none - Forever maps Shift to LT and
  Ctrl to LB on the Deck - or `/questing pause`), the NPC ignore list `ignoredNPCs` (data, kept on Defaults;
  `/questing ignore` at the NPC), `ns.On(event, fn)` one shared event frame, `/questing` (pause, ignore, ignored,
  forget, track, debug, else the page), `/compendium`, `D.PrintQuesting` for `/df questing`, `D.compendiumToggle`
  for the hub binding `DECKUIFOREVER_COMPENDIUM`.
- `dialog.lua`: GOSSIP_SHOW / QUEST_GREETING (finished quests first via `C_GossipInfo.SelectActiveQuest(questID)`
  / `SelectActiveQuest(i)`, then one quest to take, then a single plain-talk option - icon 132053, not
  `selectOptionWhenOnlyOption` - when the NPC has no quests), QUEST_DETAIL (`AcceptQuest`; a player as `questnpc`
  is a shared quest, `acceptShared`; a start item or `QuestGetAutoAccept` is left to Blizzard's pop-up),
  QUEST_PROGRESS (`CompleteQuest` when `IsQuestCompletable`), QUEST_COMPLETE (`GetQuestReward(1)` with at most one
  choice), QUEST_ACCEPT_CONFIRM (`ConfirmAcceptQuest`), QUEST_ACCEPTED (`QuestUtil.ShareQuest` with `autoShare`).
  `shouldRun` goes false for the rest of a conversation once the pause key or the ignore list said no, and comes
  back 0.5 s after every quest/gossip panel is hidden (Questie's AutoQuesting pattern). **Stands down** when
  QuickQuest or Immersion is loaded or Questie's profile has `autoAccept.enabled`/`autocomplete` on
  (`ns.OtherHelper`). Read against the forever branch of Gethe/wow-ui-source: Camelot loads
  `Blizzard_UIPanels_Game/Mainline/QuestFrame.lua`, `QuestInfo.lua`, `GossipFrame.lua` (their own gamepad bindings,
  A = accept/complete); nothing of them is hooked.
- `rewards.lua`: QUEST_COMPLETE with 2+ choices - `GetQuestItemLink("choice", i)`, `C_Item.GetItemInfo` (sell price,
  equipLoc, class/subclass), `C_Item.GetDetailedItemLevelInfo`; an upgrade is usable, for a slot in `SLOTS`, of the
  class's armour kind at its level (`BestArmor`: cloth casters, leather druid/rogue, hunter/shaman mail from 40,
  warrior/paladin plate from 40; misc armour always, shields warrior/paladin/shaman) and above the lowest worn item
  level in those slots (or the slot is empty). Marks are frames of ours parented to Blizzard's
  `rewardsFrame.RewardButtons` with `type == "choice"` and `GetID()` = choice index: coin (UI-GoldIcon) on the
  priciest, arrow (atlas `bags-greenarrow`, fallback UI-MicroStream-Green) on an upgrade, the price in the corner.
  Not-yet-loaded items redraw through `Item:ContinueOnItemLoad` and QUEST_ITEM_UPDATE. `rewardAuto` (off): with
  everything loaded and no arrow, `GetQuestReward(best)` 0.2 s later, only if `ns.DialogAllowed()`.
- `zone.lua`: `ns.TrackZone(byHand)` on ZONE_CHANGED_NEW_AREA (+1 s), PLAYER_ENTERING_WORLD (+3 s) and a
  QUEST_POI_UPDATE shortly after: quests of the log in `C_QuestLog.GetQuestsOnMap(mapID)` get `AddQuestWatch`, the
  others `RemoveQuestWatch` with `zoneUntrack` (never the super-tracked one). `D.DecorateQuestTitle(questID, title)`
  - "[12+] Title" in `GetQuestDifficultyColor` - which **DeckUIForever_Quests/quests.lua asks for in `QuestEntry`**
  (the one line changed there); `ns.RedrawTracker` is `C_QuestLog.SortQuestWatches` (fires the watch event).
  Blizzard's tracker and the quest log's list are not touched (a hook on the map runs tainted into its pins).
- `questitem.lua`: `DeckQuestingItem`, a `SecureActionButtonTemplate` of type item, attribute set out of combat
  only (`pending` until PLAYER_REGEN_ENABLED); the pick is the super-tracked quest's item, else the nearest tracked
  quest's (`GetDistanceSqToQuest`), else the nearest in the log (`GetQuestLogSpecialItemInfo`, complete quests only
  with showWhenComplete). Icon, count, `GetQuestLogSpecialItemCooldown`, key text from
  `GetBindingKey("CLICK DeckQuestingItem:LeftButton")` - **the hub's Bindings.xml declares that CLICK binding** and
  core.lua names it (`BINDING_NAME_CLICK DeckQuestingItem:LeftButton`), so the key exists before the module loads.
  Movable "Quest item" (shows a question mark while unlocked), device `itemScale`.
- `questdata.lua` (`ns.Data`): the source. **Questie's Forever build** (Questie/Questie, `Questie_Forever.toc`,
  Interface 16001, read 2026-11-07) keeps its data in the separate `QuestieDB` addon (`LibQuestieDB`) and binds it in
  `Database/QuestieDB.lua`: `QuestieDB.QueryQuest(id, keys)` returns the fields packed in key order,
  `QuestieDB.QuestPointers` is every quest id, `QueryNPC`/`QueryObject` give `name`, `spawns` ({[areaId] = {{x,y}}}),
  `zoneID`; `ZoneDB:GetUiMapIdByAreaId`/`GetAreaIdByUiMapId`; `QuestiePlayer.HasRequiredRace/Class`;
  `QuestieDB.IsDoableVerbose(id, false, true, true)` returns brief text, bool, `DoableStates` code (mapped to our
  states done/log/available/locked/blocked/foreign in `Data.State`); `QuestieJourney.zoneMap` / `.zones` are the
  Journey's groups by zoneOrSort (areaId, or Questie's negative sort keys: -1 Epic, -344 Legendary, classes,
  professions, events) already filtered to the player's race and class, built from `l10n.zoneCategoryLookup`
  (1 EK, 2 Kalimdor, 8 Zephras Isle, 9 Dungeons, 10 Battlegrounds, 11 Class, 12 Professions, 13 Events). Everything
  is reached through `QuestieLoader:ImportModule` and pcall'd; the module waits for `Questie.started` (polled once a
  second, two minutes at most) and goes without Questie otherwise (`Data.MapQuestLines` on `C_QuestLine`,
  `GetAllCompletedQuestIDs`). Completion is always the game's `C_QuestLog.IsQuestFlaggedCompleted`. **No Questie
  data is copied into the package** (GPL against our MIT); Questie is an OptionalDep.
- `chains.lua` (`ns.Chains`): links from `nextQuestInChain`, `preQuestSingle` (each) and `preQuestGroup`, read 300
  quests per frame (`C_Timer.NewTicker(0)`), components joined and ordered (Kahn, ties by level), length = longest
  path; long = 5+ steps, epic = Questie's Epic/Legendary sort or 4+ steps reaching level 50 with an elite/dungeon/raid
  tag or a class restriction. Built when the compendium first opens with Questie.
- `compendium.lua`: `DeckCompendiumWindow` 840x540, three panes (tree / list by state / details with waypoint
  buttons via `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint`), pooled row buttons, search
  box (name substring over every quest, first 300), filters `hideDone`/`onlyMine`, opens on the player's zone,
  movable "Compendium", device `scale`, `D.GamepadWindow` with its close button. **Untested in game**, and never
  seen with Questie's Forever build live - the first run should be `/compendium` with Questie installed and
  `/df questing`.
- Hub: `Questing` in `MODULE_ADDONS`/`MODULE_ORDER`/`MODULE_TITLES`/`MODULE_OFF_BY_DEFAULT`, World group,
  `PAGE_FRAMES.Questing` ("Quest item", "Compendium"), `PAGE_RESET.Questing` keeps `ignoredNPCs`, description,
  `/df questing`, two bindings, `release-common.ps1`.
- **Map, the same day**: "Level range at zone names" (`zoneLevels`, on) - `ns.ZoneLevels(mapID)` on
  `C_Map.GetMapLevels` in Map's core.lua with an empty `ZONE_LEVEL_FALLBACK` by mapID for Forever zones the game
  gives no range for, after the last NavBar crumb of the world map (worldmap.lua, in the `NavBar_CheckLength` hook
  and `WorldMapFrame.OnMapChanged`) and after our minimap zone text (minimap.lua), coloured with
  `GetQuestDifficultyColor`. The hover label over a zone on a continent map shows the range already: Blizzard's
  `AreaLabelDataProvider` does that itself in Forever. Untested in game.
- **Our own quest data (2026-11-07, owner: "ich möchte nicht abhängig sein")**: `questdata.lua` is a layer over
  three sources - the game, our own data, Questie - and the window never knows which. `data_forever.lua` defines
  the shape (`ns.SHIPPED`: `quests[id] = { n, l, r, t, m, g, f, p, x, c, o, d }`, `npcs[id] = { n, m, x, y }`,
  `lines[id] = { n, m, q }`; givers as keys `n<npc>`, `i<item>`, `s<map>:<x>:<y>`) and ships the owner's record for a
  release: copy the tables of `DeckUIForeverQuestDataDB` (account-wide SavedVariables, second entry in the toc) from
  `WTF\Account\<account>\SavedVariables\DeckUIForever_Questing.lua` in there. `record.lua` (`ns.Own`: Quest/Touch,
  NPC/TouchNPC, Line/Lines, All, Link, HarvestLines, Stats) writes at GOSSIP_SHOW and QUEST_GREETING (every quest
  offered - `C_GossipInfo.GetAvailableQuests` / `GetAvailableQuestInfo(i)` whose fifth return is the questID - and
  every one taken back, `GetActiveQuestID(i)`), QUEST_DETAIL (giver: NPC with name and the player's position, start
  item, or a spot; `GetObjectiveText`), QUEST_ACCEPTED (level, tag, objectives from the log) and QUEST_TURNED_IN
  (finisher); a quest offered or taken within 20 s after a hand-in at the same giver key is linked as its follow-up
  (`Own.Link`: `x` on the one before, `p` on the one after). `Own.HarvestLines(mapID)` reads
  `C_QuestLine.GetAvailableQuestLines` on zone change, login and compendium open: consecutive quests of a line are
  linked, a line's quest gets a spot giver at the entry's x, y when no NPC is known. `scan.lua` (`ns.Scan`:
  Start/Stop/Reset/Status/Running): `C_QuestLog.RequestLoadQuestByID` for ids 1..100000, two per 50 ms tick, at
  most 12 in flight, 3 s timeout, pauses in combat and instances, position in `DeckUIForeverQuestDataDB.scan`
  (resumes next session); QUEST_DATA_LOAD_RESULT stores title, tag, objectives, repeatable. Option `record` (on),
  page buttons "Start/Stop the scan" and "What is known", `/questing scan [stop|reset|status]`, `/questing record`.
  `Data.Quest(id)` merges Questie's part (cached) with our own (read fresh) - own `p` stands in for preGroup, own
  `m` gives `zoneName` through `Data.ZoneMap`; `Data.Links(id)` joins both for chains.lua (which now builds from
  any source and is invalidated on quest events); `Data.Starters/Finishers` return places with `mapID`, `zone`, `x`,
  `y` from either source; `Data.State` without Questie: done/log, locked by own links or level, available when
  seen offered, else "Known by name". `Data.Categories` without Questie: zones by the zone map of the giver's map
  grouped by continent (`Data.ZoneMap`, `Data.ContinentName`), dungeons by map type, the game's quest lines,
  "Known by name only" (the list caps at 400 rows, the search box finds the rest), "This character: Done"; with
  Questie the Journey groups plus "Recorded by you, new to Questie". **Untested in game.** Open questions for the
  first run: whether Forever's `C_QuestLine` returns lines for Classic maps (`/questing record` counts them), and
  how fast the server answers the scan.
- **The Questie import (2026-11-08, owner: "Weg 2", then "Questie-Import" over the game-only way)**: `import.lua`
  (`ns.Import`: Start/Stop/Clear/Status/Running/Available) copies Questie's data into `DeckUIForeverQuestDataDB`
  once, with Questie loaded and started (`Data.HasQuestie()`): `/questing import [clear|status]`, page buttons
  "Import Questie's data" / "Forget the import". Five stages on a `C_Timer.NewTicker(0)`, 150 a frame: quests
  (every id of `QDB.QuestPointers` through `Data.QuestieQuest` = the cached `FromQuestie`), then the NPCs, objects
  and start items those quests named, then every zone-or-sort key seen. The shape grew (data_forever.lua): quest
  `i` imported, `s` zoneOrSort, `h` max level, `a` preQuestSingle (any one; `p` stays preQuestGroup, all), `e`
  exclusiveTo, `v` parent, `b` breadcrumb target, `k`/`y` class and race sets (`Data.ClassSet`/`RaceSet` turn
  Questie's masks - `QDB.classKeys`/`raceKeys`, fallback tables - into the game's tokens, nil when every classic
  class or race is in), `t` Questie's corrected tag; giver keys gain `o<object>`; new tables `objs` (like `npcs`,
  with `z` zone name), `items` (names the game lacks), `sorts[id] = { n, c = Journey category, m = map }`;
  `d.imported = { at, quests, npcs, objects, questie = version }`. Questie's links replace the inferred `p`;
  `g`/`f` merge (Questie's first), a recorded NPC position stays. **questdata.lua reads it all without Questie**:
  `Data.Quest` fills preSingle/exclusiveTo/parent/breadcrumb/maxLevel/classOnly/raceOnly/zone from own, `imported`
  flag; `Data.State`'s own path knows exclusive-done, breadcrumb moved on, parent not in log, max level, and says
  "available" for an imported quest; `Data.ForPlayer` checks `classOnly`/`raceOnly` (chains.lua reads `classOnly`
  too); `Data.ZoneName`, `MapForArea`, `AreaForMap`, `ItemName` fall back to `sorts`/`items`; `Data.Categories` has
  a third branch (`HasImport()`): the Journey's six categories from `sorts` + `ImportedMap()` (class groups only
  with a quest for this character), the game's lines, and "Recorded by you, not in the import" (`OwnGroups(skip)`
  takes a predicate now). The compendium's search works without Questie (the `HasQuestie` condition was a
  leftover). `Own.Object/TouchObject/Item/Sort/Sorts/ImportInfo/Reload` in record.lua. The import is the account's
  private copy of GPL data; nothing of it ships (data_forever.lua stays the owner's record only - decide before
  ever copying imported tables in there). **Untested in game**; the first run needs Questie starting (owner's
  QuestieDB 1.0.12 Forever + `## Dependencies: QuestieDB` by hand, see memory), then `/questing import`,
  `/questing record`, `/compendium`, then Questie off and `/compendium` again.
- **Questie on the owner's client, checked on disk 2026-11-08**: `Questie` 12.6.3 (CurseForge; `Questie_Camelot.toc` is what the
  client loads, `## Dependencies: QuestieDB` added by hand - harmless, the OptionalDeps line orders the load anyway), `QuestieDB`
  1.0.12 (GitHub, the **baked** build: its 15 MB `QuestieDB_Camelot.toc` holds the whole database as 116k `## X-...` metadata
  lines read with `C_AddOns.GetAddOnMetadata`, `X-Flavor: Forever`, contract 4 = Questie's 4; `_G.LibQuestieDB` is set in the
  last line of `src/api.lua`, so any load error before it leaves Questie's `zoneDB.lua` without the global and
  `QuestieInit.lua:425` calls a nil `ZoneDB.Initialize` - that is the owner's old error, which fits the earlier Mists
  QuestieDB package not loading at all), `QuestieTrace` 1.9.1. Every toc entry exists on disk; QuestieDB guards `C_Seasons`;
  `C_EncodingUtil` (CBOR, deflate, base64) is in Forever's API docs. The hub's saved error list (errors.lua keeps this and the
  previous session, pending ones from file load too) held **no Questie error** in the two sessions after the install - only our
  `rewards.lua:162` (`GetCoinTextureString` is gone in Forever; `CoinText` uses `C_CurrencyInfo.GetCoinTextureString` now).
  `/questing questie` (`ns.QuestieDebug`, also in `/questing debug`) prints the client's view: enable state and load reason of
  both addons, `LibQuestieDB` mode/flavor/contract/Support and the three `C_EncodingUtil` functions, then **how far
  Questie's start has come** - QuestieInit runs three stages in a ThreadLib coroutine after PLAYER_LOGIN: 1 binds the
  database (`QuestieDB.QuestPointers`), 2 builds `QuestieJourney.zoneMap`, 3 sets `Questie.started` (false = a stage
  failed, `QuestieStatus` holds the report, printed too) - and `/questing questie watch` repeats that line every 15 s.
  (There is no `X-QuestIDS` metadata key; an earlier version of the line reported it "MISSING" wrongly.) Reinstalled from
  CurseForge 2026-11-08: Questie 12.6.4, same QuestieDB 1.0.12 Forever baked - correct.
- **Questie did not start while the Questing module was on (owner, 2026-11-08: "sobald ich das Quest modul deaktiviert habe
  hat questie geladen")**: `Questie.started` stayed nil, no error, config saved. The module's toc listed
  `## OptionalDeps: Questie, QuestieDB`; the hub loads its LoadOnDemand modules inside its own ADDON_LOADED (core.lua, long
  before the game reaches "Q" in the addon list), so the game loaded Questie and QuestieDB right then, nested and out of order,
  and Questie's start never ran through. The OptionalDeps line is gone (questdata.lua polls Questie at runtime, no load order
  needed). **Rule: a module toc never lists a third-party addon as OptionalDeps** - the hub's early LoadAddOn would drag it in.
  Confirmed in game the same day: with the line gone and the module on, Questie 12.6.4 reaches stage 3 49 s after login
  (5233 quests, 103 zones, API ready). The import then ran clean: 5233 quests, 1936 NPCs, 307 objects, 384 item names,
  130 zones/sorts; the SavedVariables file grew from 0.2 to 2.2 MB; with Questie off the compendium showed every zone.
- **The guided import (2026-11-08, owner: "vereinfachten Import ... um es den Nutzern zu erleichtern")**: `Import.Guided()`
  is what the button and `/questing import` call. `Import.QuestieState()`: ready → `Import.Start()`; starting → sets
  `DeckUIForeverQuestingDB.importPending`, questdata's `Try()` calls `Import.OnQuestieUp()` when Questie is up and that
  starts it; disabled (`C_AddOns.GetAddOnEnableState` 0 for Questie or QuestieDB) → `D.Dialog` "Reload and import" that
  enables both, sets `importPending` + `importEnabledQuestie`, `ReloadUI()`; notloaded (enabled, not loaded) → the same
  dialog without enabling; missing / nodb → a chat line saying what to install. `Finish()` clears `importPending` and, when
  `importEnabledQuestie`, asks "Off and reload" (`C_AddOns.DisableAddOn` both). `InitData` without Questie calls
  `Import.QuestieAbsent()` (forgets a pending import, says so). `OnQuestieUp` also prints once per account
  (`importHinted`) that the import exists, when nothing was imported yet. Untested in game at the time of writing.
- **Shipping rule for `data_forever.lua`**: when the owner's record is copied in for a release, every quest and NPC with
  `i = true` is stripped, and `objs`, `items`, `sorts` and `imported` are left out entirely - they are the import's, Questie's
  GPL data, the account's private copy. Only what was recorded at NPCs, scanned or harvested from quest lines ships.
- **The dock (2026-11-07, owner: the week button plus the hub and compendium buttons, "eleganter im FFXIV-Stil")**:
  `DeckUIForever/dock.lua`, `DeckUIForeverDock` - a flat dark panel with a one-pixel edge and a gold line along
  the top, round buttons in mainmenu.lua's Dress (gold ring, dark disc, masked icon, 28 px). `D.DockButton(key,
  { order, icon, texCoord, title, tip (table or function), onClick, onRightClick, badge, available })`,
  `D.DockUpdate()` re-reads badges and availability, `D.ApplyDock()` the switch `DeckUIForeverDB.dock` (on,
  Screen page, `SCREEN_KEYS`, movable "Dock" in `PAGE_FRAMES.Screen`). The hub registers "settings" (order 1,
  the logo face_a, right click = `D.SetUnlocked`), Week "week" (order 2, the old orb's icon and vault badge;
  `DeckWeekButton` and the movable "Week button" are gone, `showButton` now means "in the dock",
  `ns.UpdateButton` calls `D.DockUpdate`), Questing "compendium" (order 3, in `ns.InitCompendium`). Any button
  drags the dock (its OnDragStart/Stop hand to the dock's, which `D.MakeDraggable` set, so the position
  saves); a drag is no click. Shown while a button is available or the frames are unlocked. Untested in game.
- Syntax checks without a Lua binary: `python -c "from luaparser import ast; ast.parse(open(f).read())"`
  (`pip install luaparser`, plain `python`, not `python -I`).

## The settings window (menu review 2026-11-07, owner: "das komplette Menü, Aufbau und Texte einfacher")

- `D.PAGE_GROUPS` in panel.lua: General (Modules = key `General`, Devices, Screen, Targets, Windows - the
  three hub pages are top-level now, no `PAGE_PARENT`; as sub-pages of the Overview they were listed only
  while it was on show), Frames (Orbs = "Unit frames" with its sub-pages Player, Target, Target of target,
  Buff bar, Enemies and bosses, Your debuffs, Your HoTs; Group; Raid), Actions (Bars, Pad, Spec, Cross),
  World (Quests, Map = "Maps" with the minimap's settings on it and World map as its sub-page), Inventory
  (Bags, Loot), Info (Tooltip with the extra lines on it, Week). The pages `MapMinimap` and `TooltipExtras`
  are gone (their keys reset with the parent: `PAGE_RESET.Map` matches everything but the world map's keys,
  `PAGE_RESET.Tooltip` the whole DB); `/df overview` is `/df modules`.
- Texts: a label is a few words, an explanation two or three plain sentences about what the player sees;
  "Needs a reload." closes it where it does; no engine words (secure, state driver, CVar, taint) and no
  Final Fantasy lore beyond what names the look. Keep that style for new options.

- **"Stop syncing UI and keys" (2026-11-10, owner: "einen Knopf, damit UI und Tastenkombis nicht mehr mit dem
  Server synchronisiert werden")**: a toggle button on the Devices page above the "Key bindings" checkbox.
  `D.SYNC_CVARS` in core.lua (`synchronizeConfig`, `synchronizeChatFrames`, `synchronizeBindings`),
  `D.SyncIsOff()`, `D.SetServerSync(on)` (off: `SaveBindings` of the loaded set; refuses in combat),
  `/df sync` (`D.PrintSync`). The master CVar `synchronizeSettings` and `synchronizeMacros` are left alone so
  macros stay synced. Only `synchronizeBindings` is confirmed to exist in the client; an unknown CVar is
  skipped. Edit Mode layouts and action bar contents have no CVar - their checkboxes stay. **Untested in game.**

## Audit

A scripted pass over the repo (2026-11-05, script in the session's scratchpad, easy to rewrite): syntax of
every Lua file, toc entries against the folders and orphans, the toc headers, old names in code, `ns.`/`D.`
names used but never defined, `D.MODULE_ADDONS` against the folders and `release-common.ps1`,
`D.MakeMovable` keys against `D.PAGE_FRAMES`, hub options against `DEFAULTS`. What it still lists is
meant: Cross's placeholders (`DeckUIForever_Cross` folder, "Cross Hotbar" frame, `DeckUIForeverCrossDB`),
Week's retail fallbacks (`RetailTop`/`RetailRight` and the data they read, only run without
`ns.DetailsTop`/`ns.DetailsRight`), Quests' guarded `ns.ApplyGuide`/`ns.ShowJourney`, and `ns.oUF`, which
the embedded oUF sets.

## Release

`release-common.ps1` lists the addon folders (`$addons` - add a module there and
to `D.MODULE_ADDONS` when it is ported), `package.ps1` builds `dist\DeckUIForever-<version>.zip` with the
folders at the top level, `bump-version.ps1 <version> [-Interface 16002]` raises the `.toc` headers,
`changelog.ps1` takes the `## <version>` section of `CHANGELOG.md`. The workflow
(`.github/workflows/release.yml`) uploads on a `v*` tag through `upload-curseforge.ps1`; it needs the
secret `CF_API_TOKEN` and the repository variable `CF_PROJECT_ID`. The repository is
`https://github.com/JonasAudren/DeckUIForever` (public, made 2026-11-05, `origin`); the CurseForge project
is `https://www.curseforge.com/wow/addons/deckuiforever`, id **1784984** (`## X-Curse-Project-ID` in the
hub's toc, made 2026-11-05); the secret and the variable in the GitHub repo are the owner's to set. The tag's suffix decides the release type (`-beta`, `-alpha`, none = full release).

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
6. **Released**: v1.0.0 on 2026-11-05 (tag, Release workflow, CurseForge file id 9452977, game version
   1.60.1 id 17053 / type 88568). Next versions: `bump-version.ps1`, a `## x.y.z` section in CHANGELOG.md,
   commit, tag. Then the Deck test.
   **Released**: v1.1.0 on 2026-11-05 (the stance, pet and totem bars, the Classic helpers, the group
   listing, five debuffs; tag push, Release workflow run 42079272178, CurseForge file id 9456774). The bars,
   the helpers and the listing window were not yet seen in game (the priest has no forms, pet or totems).
   **Released**: v1.2.0 on 2026-11-06 (your HoTs, the kept columns, the idle and preview switches; tag
   push, Release workflow run 42253563550, CurseForge file id 9477126). The HoT window, the idle switch
   and the "forbidden hook" fix were seen in game by the owner that day ("seems to all work"); the kept
   columns were not yet.
   **Released**: v1.3.0 on 2026-11-07 (the Pad module, the D-pad in our windows, the party HoT window with
   round icons, click to cast, the controller glyphs, the debuff icon mode, the simpler settings window; tag
   push, Release workflow run 42391059063, CurseForge file id 9495157). Seen in game before the release: only
   the HoT window's round icons ("viel besser"); Pad, the D-pad windows, the healer mode, the glyphs, the
   debuff icon mode and the new menu were not.
   **Released**: v1.4.0 on 2026-11-08 (the Questing module with the compendium, own quest data, the scanner and
   the Questie import, the dock, the map level ranges, the HoT window's raid order and the stranger switch,
   the fixes for the kept columns, the parchment ink beside the map and the healer mode's self-target line;
   tag push, Release workflow run 42503430872, CurseForge file id 9513060, game version id 17053). Seen in game before:
   Questie's start with the module on, the import, the compendium with and without Questie, the light quest
   details, the transparent self-target line. Not seen: the guided import's dialogs, the NPC dialog autopilot,
   the reward marks, zone tracking, the quest item key, the dock, the map level range.
