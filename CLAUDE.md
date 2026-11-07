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
  them. **Untested in game.**
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
