# DeckForever – Prüfbericht: DeckUI gegen den WoW-Forever-Client

Stand: 02.11.2026. Der Client ist installiert (`C:\Spiele\World of Warcraft\_forever_`, Produkt
`wowf`, Version **1.60.1.70707**), aber noch nicht spielbar. **Im Spiel ist deshalb nichts
geprüft** – alles hier stammt aus dem, was sich ohne Login lesen lässt:

1. **Die Spiel-Exe** (`_forever_\Wow.exe`, 85 MB): alle lesbaren Zeichenketten gezogen und mit
   Retail 12.1.5 (`_retail_\Wow.exe`) und MoP 5.5.4 verglichen. Darin stehen API-Namen,
   Ereignisse, CVars, Bindungsbefehle und Konstanten des Clients – genau das Build, das auf
   der Platte liegt.
2. **Blizzards UI-Quellen für Forever**: GitHub `Gethe/wow-ui-source`, Zweig `forever`,
   Build **1.60.1.70532** (22.10.2026). Das ist zwei Wochen älter als der installierte Client
   (70707); Blizzard hat seitdem noch Feinschliff gemacht, die Struktur ändert sich so kurz vor
   dem Start aber nicht mehr. Dazu `live` (12.1.5.70688) als Vergleich.
3. **Der MoP-Werkzeugkasten** (`tools/mists`): `mopscan.py` auf Forever umgestellt und jeden
   Blizzard-Namen, den DeckUI benutzt (314 API-Funktionen, 112 Enums, 249 Ereignisse, 2003
   Globals, 20 Templates, 20 CVars), gegen beide Quellbäume geprüft.
4. Warcraft Wiki für Toc-Endung und Interface-Nummer.

Was sich nur im Spiel klären lässt, steht in Abschnitt 6 – das wird die Probe am Starttag,
wie bei MoP in Phase 0.

---

## 1. Kurzfassung

**Forever ist technisch Retail 12.1.5 mit Classic-Inhalt.** Die dokumentierte API ist eine
Obermenge von Retail (9331 gegen 9080 Einträge; nur 8 Retail-Einträge fehlen, alle belanglos:
Transmog-Waffenoptionen, ein Haustier-Ereignis). **Jedes der 249 Ereignisse und 20 CVars, die
DeckUI benutzt, steht in der Forever-Exe**, jede API-Funktion ebenso. Secret Values,
Aura-Container, Edit Mode, Cooldown-Manager, Schadensmesser: alles da.

Was sich unterscheidet, ist **Inhalt**, nicht Technik: keine Spezialisierungen (aber
Doppel-Talentgruppen ab Stufe 40), kein Ein-Knopf-Assistent, keine Schatzkammer, kein
Mythisch+, keine Tiefen, keine Jagden, kein Abenteuerhandbuch, kein Talking Head, kein Housing.
Dafür neu: Schlüsselbund, Legacy-System statt Erfolge, Day/Night-Zyklus, Schwungtimer,
Totemleiste, klassischer Gruppensucher – und **Blizzards eigene Controller-Oberfläche**
(sieben Addons `Blizzard_Gamepad*`, eine eigene Gamepad-Aktionsleiste mit eigenen Slots).

Für DeckForever heißt das:

| Modul | Portieren? | Aufwand | Kern |
|---|---|---|---|
| Hub | ja | mittel | Erkennung, Talentgruppe statt Spec, Talking Head raus, Legacy-Knopf |
| Orbs | ja | klein | Combo-Punkte am Ziel (wie MoP), 9 Klassen, Max-Stufe 60 |
| Cross | **offen** | – | hängt an Blizzards Gamepad-Modus, siehe Abschnitt 3 |
| Spec | ja | klein | ist in MoP schon gebaut (`core_mists.lua`) |
| Bags | ja | mittel | Schlüsselbund neu, Bank hat 9+6 Tabs, Alt-Filter weg |
| Quests | ja | mittel | Abschnitte abschalten, Questtimer und Legacy neu |
| Map | ja | klein | Retail-Code, Camelot-Art |
| Tooltip | ja | klein–mittel | Spec-Zeile weg, Ruf-Daten aus Forever |
| Nav | ja | keiner | Retail-Pfad läuft unverändert |
| Week | ja, zuletzt | groß | alles Midnight raus, Legacy/Sperren/Dailies rein, Daten neu |

**Grobe Schätzung: 4–6 Sitzungen** ohne Cross; Cross kommt dazu, sobald die Entscheidung steht.

---

## 2. Der Client in Zahlen

| Punkt | Befund | Quelle |
|---|---|---|
| Ordner | `_forever_`, Daten im gemeinsamen `Data\` (`Data\wowf`) | Platte |
| Version / Build | 1.60.1.70707 | `.build.info`, `.product.db` |
| Spiel-Kennung | `WOW_PROJECT_CAMELOT = 18`, `WOW_PROJECT_ID = WOW_PROJECT_CAMELOT` | `Blizzard_ProjectConstants/Camelot/ProjectConstants.lua` |
| Spieltyp (Toc-Gate) | `camelot`; Blizzards Tocs tragen `## AllowLoadGameType: ... camelot` | 349 Blizzard-Tocs |
| Toc-Endung für Addons | `Name_Forever.toc` **oder** `Name_Camelot.toc`; `Name_Mainline.toc` lädt auch (Familie); sonst `Name.toc`. Wiki: „Camelot may be changed to Forever“ | Warcraft Wiki TOC_format |
| Interface-Nummer | **16001** (für Beta und Test belegt, Release-Zeile im Wiki leer) – am Starttag mit `/deck build` bestätigen | Warcraft Wiki |
| Eigene Standardbelegung | `WTF\DefaultForeverBindings.wtf` wird vom Client erwähnt | Exe |
| Erfahrungs-Voreinstellung | `C_GameRules.GetForeverExperiencePreset` / `SetForeverExperiencePreset`, Enum `ForeverExperiencePreset` | Exe, Docs |
| Oberflächenstil | `C_InputInterfaceStyle.GetCurrentStyle()` → `Enum.InputDeviceInterfaceType.Mkb` oder `.Gamepad`; `InputUtil.IsGamepadUIEnabled()` | `Blizzard_SharedXML/Mainline/InputUtil.lua` |
| Klassen | Warrior, Paladin, Priest, Shaman, Druid, Rogue, Mage, Warlock, Hunter (9) | `Blizzard_FrameXMLBase/Camelot/Constants.lua` |
| Max-Stufe | 60 | Wiki |
| Doppel-Talentgruppe | ab 40 beim Lehrer, `C_SpecializationInfo.GetActiveSpecGroup` / `SetActiveSpecGroup`, `GetNumSpecGroups`, Ereignis `ACTIVE_TALENT_GROUP_CHANGED` | `Blizzard_PlayerSpells/Camelot/ClassTalents/...lua:124-382`, Wiki |
| Assistent | **aus**: `InterfaceOverrides.HasAssistedCombat()` liefert `false` | `Blizzard_SettingsDefinitions_Frame/Camelot/InterfaceOverrides.lua:40` |
| Sichere Schnipsel | `SecureHandlers.lua`, `SecureStateDriver.lua`, `SecureTemplates` werden geladen; der Beta-Fehler (`loadstring_untainted`) ist aus den Quellen nicht ablesbar – **Probe** | `ui-code-list.txt` |

### Blizzard-Addons, die Forever nicht lädt (Auswahl, nach `AllowLoadGameType`)

`Blizzard_ChallengesUI` (standard, mists), `Blizzard_EncounterJournal` (standard, classic),
`Blizzard_ExpansionLandingPage` (standard), `Blizzard_HousingDashboard` / `Blizzard_HouseEditor`
(standard), `Blizzard_GenericShoppingCart` (standard). **Gar nicht im Build**:
`Blizzard_TalkingHeadUI`, `Blizzard_DelvesDashboardUI`. Geladen, aber ohne Inhalt:
`Blizzard_WeeklyRewards` (kein Gate; die Schatzkammer gibt es im Spiel nicht),
`Blizzard_MajorFactions` (vom Legacy-System für den Belohnungspfad genutzt).

### Neu in Forever (für uns relevant)

- `Blizzard_Gamepad`, `Blizzard_GamepadActionBars`, `Blizzard_GamepadTargeting`,
  `Blizzard_GamepadSmartNavigation`, `Blizzard_GamepadSoftCursor`, `Blizzard_GamepadSharedUtility(+Secure)`
  – siehe Abschnitt 3.
- `Blizzard_LegacySystem` (drei Bäume über `C_Traits`: Berufe, Abenteuer, Fortschritt; „Legacy
  Challenges“ sind Erfolge unter neuer Oberfläche – `GetCategoryInfo`, Erfolgs-IDs) und
  `Blizzard_LegacyChallengeTracker`; Währungen `CURRENCY_ID_RENOWN_LEGACY`, `CURRENCY_ID_RENOWN_PVP_RANK`.
- `Blizzard_SwingTimer` (Edit-Mode-System, `C_SwingTimer`), `Blizzard_Statistics`,
  `Blizzard_GroupFinder_VanillaStyle` (`LFGParentFrame`), `Blizzard_QuestTimer` (klassische
  Questtimer), Totemleiste `MultiCastActionBarFrame`, Tierzufriedenheit (`PetHappiness.lua`,
  `C_PetInfo.GetPetHappiness`), Schlüsselbund (`Enum.BagIndex.Keyring = -1`, CVar `showKeyring`,
  `C_ActionBar.ShouldShowKeyring`), Day/Night (`DIEL_CYCLE_CHANGED`, `C_DateAndTime.IsDayTime`).
- Beute: `C_LootFrame.TryAutoLoot`, `C_AutoLoot.SetUseAutoLootToggle`, `C_Loot.IsLegacyLootModeEnabled`
  (Plündermeister ist zurück), Enums `LootRollType` / `LootRollDisabledReason`.
- Edit Mode kennt **Layouts pro Oberflächenstil**: `layoutInfo.interfaceStyle` = Mkb/Gamepad,
  Voreinstellungen je Stil, und die Liste zeigt nur die Layouts des aktiven Stils
  (`Blizzard_EditMode/Shared/EditModeManager.lua:887-900, 1365-1387`).

---

## 3. Die Kernfrage: Blizzards Controller-Oberfläche und DeckUI Cross

Die sieben Addons `Blizzard_Gamepad*` (alle `AllowLoadGameType: camelot`, keines abschaltbar,
kein LoadOnDemand) wurden ganz gelesen. Das Ergebnis ist klarer als erwartet:

### 3.1 Zwei Oberflächenstile, ein Schalter

- Der Stil ist die CVar **`InputDeviceInterfaceStyle`** (0 = Tastatur/Maus „Mkb“, 1 =
  Gamepad), gelesen über `C_InputInterfaceStyle.GetCurrentStyle()`. Im Spiel: Einstellungen →
  Kategorie „Gamepad“, Haken „Gamepad-Oberfläche“ (`Blizzard_SettingsDefinitions_Shared/Gamepad.lua:276-292`).
  **Voreinstellung = `PlatformIsHandheld()`** – auf dem Steam Deck startet Forever also im
  Gamepad-Stil, am PC im Tastatur-Stil. Der Wechsel ist live (Ereignis
  `INPUT_DEVICE_INTERFACE_TRANSITION`), kein Reload. **Nichts** schaltet den Stil beim
  Anstecken eines Pads automatisch um; `GAME_PAD_ACTIVE_CHANGED` wird vom Gamepad-Stapel nicht
  benutzt.
- Die alten CVars `GamePadEnable`, `GamePadEmulateShift/Ctrl/Alt` kommen in den sieben Addons
  **nicht vor** – sie sind vom Stil unabhängig. Blizzards eigene Konstanten setzen
  `GAMEPAD_MOD_LEFT = "SHIFT"`, `GAMEPAD_MOD_RIGHT = "CTRL"`, also dieselbe Emulation wie
  DeckUI (`Blizzard_SharedXML/Shared/GamepadConstants.lua:3-37`).

### 3.2 Tastatur-Stil (Mkb): DeckUI Cross läuft wie in Retail

Mit Stil 0 ist der ganze Gamepad-Stapel still: Bindungskontext aus,
`GamepadMainActionBarFrame` versteckt, alle Override-Bindungen gelöscht
(`Blizzard_Gamepad/Core.lua:98-107`), die normalen Leisten und `ACTIONBUTTONn` unberührt. Unsere
Kreuze (Override-Bindungen `SHIFT-PADDUP` → `ACTIONBUTTON1` auf einem Secure-Header,
LibActionButton-Spiegel der Leisten 1/2) hätten **nichts, womit sie streiten**. Einziger Zusatz:
die Einstellungsseite „Gamepad“ und der Stil-Schalter, den DeckForever auf dem Deck selbst auf
0 stellen müsste (sonst landet der Deck im Gamepad-Stil).

### 3.3 Gamepad-Stil: Blizzards Leiste **ist** ein Cross-Hotbar

- **Vier Leisten je Seite, genau wie unsere Kreuze**: keine Modifikatortaste = obere Leiste,
  LT (`GAMEPADLEFTMOD`) = linke, RT (`GAMEPADRIGHTMOD`) = rechte, **beide = untere Leiste**
  (`PageUnit.lua:546-599`). Jede Leiste hat 8 Knöpfe: Steuerkreuz-Gruppe (links/oben/rechts/unten)
  und Face-Gruppe (`GAMEPADACTIONBUTTON1-8`, `Blizzard_GamepadActionBars/Bindings.xml:3-31`).
  Drei Seiten (`CycleActionBarPages`), eine vierte Sonderseite für Fahrzeuge/Besitz.
- **Fest verdrahtet**: die Face-Gruppe der oberen Leiste ohne Modifikator – 5 = Interagieren /
  Angriff, 6 = Inspizieren / Zielmenü / Marker, 7 = Zurück (Zauber abbrechen, Ziel löschen),
  8 = Springen (`MainActionBarFrame.lua:565-580`). Also 28 belegbare Slots je Seite, 84 gesamt.
- **Eigener Speicher**: die Knöpfe sitzen auf Gamepad-Slots ab
  `C_GamepadUI.GetFirstGamepadActionStorageSlotIndex()` (`ActionBindingUtil.lua:88-111`) –
  **nicht** auf 1–180; `Enum.ActionBarSet { Mkb=1, Gamepad=2 }`. Was der Spieler im
  Tastatur-Stil auf die Leisten legt, liegt im Gamepad-Stil nicht auf dem Kreuz.
- **Bindung über einen Bindungskontext**: `C_KeyBindings.ActivateBindingContext(GamepadModeInGameCore)`
  – **restricted**, aus Addon-Code nicht schaltbar (`Core.lua:44-54`,
  `KeyBindingsDocumentation.lua:11-31`). Die Pad-Standardtasten stehen nicht in Lua (Engine,
  vermutlich `DefaultForeverBindings.wtf`); die Klassen-Flyouts fragen `PADLTRIGGER`/`PADLSHOULDER`
  aber **physisch** per `IsKeyDown` ab (`ClassActionFlyout.lua:60-77`).
- **Schultertasten = Zielwahl**: L1 Verbündete, R1 Gegner (`C_GamepadTargeting.Enable/SetFilter`,
  Tastentipp beim Loslassen); beide Schultern = Kurzbefehl-Leiste (Seitenwechsel, Questtracker,
  Chat, Buffs, Waffe, Taschen). L1+LT / R1+RT = Klassen-Flyouts als Ring.
- **Menüs legen Override-Bindungen auf `SHIFT-`/`CTRL-`/`CTRL-SHIFT-` + D-pad/Face** (der
  Bindungs-Stapel in `Blizzard_GamepadSharedUtility`, `BindingSetFactory.lua:85-107`) – exakt die
  Tastennamen unserer Kreuze. Solange ein Fenster den Fokus hat, ist die Leiste „nicht
  benutzbar“ (`AreActionBarsUsable`, `MainActionBarFrame.lua:10-12`).
- **Die normalen Leisten verschwinden**: `MainActionBar_InitializeGamepad` versteckt
  `MainActionBar`, `StanceBar`, `MicroMenu`, `BagsBar` (`Blizzard_ActionBar/Shared/MainActionBar.lua:31-40`);
  `SetShowGrid` weigert sich („The standard action bars should never be shown with gamepad UI“,
  `ActionBar.lua:149-151`); das Gamepad-Preset von Edit Mode enthält weder `MainActionBar` noch
  `MultiBar*`, Edit Mode versteckt alles, was im Layout fehlt (`EditModeManager.lua:1490-1506`).
  Die Haltungsleiste und die Tierleiste werden als **Override** einer der Leisten auf einer
  Seite angezeigt (CVars `GamepadStanceBarOverride` / `GamepadPossessBarOverride`, 1–12).
- **Edit-Mode-System**: `Enum.EditModeSystem.GamepadMainActionBar = 30`, Einstellungen
  Kompakt / leere Leisten / Tastensymbole / Hervorhebung / Ausklappen
  (`Enum.EditModeGamepadMainActionBarSetting`), eigenes Preset `Gamepad`; beim Wechsel zurück
  auf Mkb erzwingt der Stapel das Modern-Layout (`Core.lua:101-102`).
- **Keine sicheren Schnipsel, keine Zustandstreiber** im ganzen Stapel – alles sind
  `SecureActionButton`s, die aus normalem Lua per `Click` gedrückt werden; `useOnKeyDown`,
  Press-and-hold über `SecureTemplates.lua:802-826` wie bei Tastaturbefehlen.
- Weitere Teile: HUD-Modus (Cursor über Tracker & Co.), Ringmenü `OPENRADIAL` (Taschen, Buffs,
  Kalender, Menüs, Emotes; rechter Stick wählt), Fadenkreuz mit Schwungtimer
  (`GamepadEnableReticleSwingTimer`), Soft-Cursor nur für Karte und Farbwähler, Tastenlegende
  (`GamepadShowPersistentInputLegend`), Smart Navigation in allen Fenstern (D-pad, A, B, Trigger
  wechseln Fenster). Im Gamepad-Stil werden außerdem die Soft-Target-CVars als temporäre Werte
  gesetzt (`SoftTargetInteract=1`, `SoftTargetIconGameObject=1`, Kamera-Follow …).

### 3.4 Was ein Addon dort darf – und was nicht

Darf: die `GAMEPAD*`-Befehle umbinden (gewöhnliche, nur versteckte Bindungsbefehle),
`GamepadMainActionBarFrame` verstecken (wird bei jedem Init und Layout wieder gezeigt; die
Bindungen feuern trotzdem), `C_GamepadTargeting.Disable()` rufen, Edit-Mode-Einstellungen
setzen. **Darf nicht**: den Bindungskontext abschalten, die Leiste auf Slots 1–180 umstellen,
in `PressActionButton` eingreifen (Taint auf dem Secure-Pfad).

### 3.5 Die Entscheidung, die bleibt

Aus den Quellen folgt: **Beides zugleich geht nicht.** Entweder

- **A – Tastatur-Stil auf dem Deck + DeckForever Cross** (so wie DeckUI heute in Retail): volle
  Kontrolle, unsere Kreuze, Schnellmenü, Fähigkeiten-Menü, Haltungsreihe; dafür keine Smart
  Navigation in Blizzards Fenstern, keine Schulter-Zielwahl, Taschen/Menüs wie am PC
  (Trackpad). DeckForever setzt `InputDeviceInterfaceStyle = 0` auf dem Deck und warnt, wenn
  der Stil wechselt. Risiko: der Beta-Fehler bei sicheren Schnipseln (Schnellmenü, B-Menü) –
  Probe.
- **B – Gamepad-Stil, DeckForever ohne Cross-Hotbar**: Blizzard liefert den Cross-Hotbar
  (LT/RT + D-pad/Face, vier Leisten, drei Seiten), die Zielwahl, Ringmenüs und die Navigation
  in allen Fenstern; DeckForever bringt nur noch Anzeige-Module (Orbs, Karte, Quests,
  Tooltip, Nav, Bags, Week) und allenfalls Optik auf Blizzards Leiste (Edit-Mode-Settings,
  Texturen). Die drei Sonderteile von Cross haben dort Blizzard-Gegenstücke (Ringmenü statt
  RB-Schnellmenü, Kurzbefehl-Leiste und Flyouts statt B-Menü, Stance-Override statt
  Haltungsreihe).
- Ein **Hybrid** (Blizzards Menüs/Zielwahl plus unsere Leiste) scheitert am restricted
  Bindungskontext: Blizzards Leiste lässt sich nicht stummschalten, nur verstecken.

Das ist eine Frage des Spielgefühls, nicht der Technik – Notiz vom 26.10.: erst mit dem
Live-Client beide Stile auf dem Deck ausprobieren, dann gemeinsam entscheiden. Phase 4 hängt
daran; die anderen Module nicht. Konstanten und Schalter oben sind die Probe-Liste dafür.

Unabhängig davon: Der **Ein-Knopf-Assistent ist in Forever aus** (`HasAssistedCombat() = false`,
`AssistedCombatManager.lua` lädt nur `mainline`-standard). `assist.lua`, die Assistent-Erkennung
über `C_ActionBar.IsAssistedCombatAction`, der gemalte Icon, die „kein Ziel“-Ringfarbe und das
Zurücklegen in `actionbars.lua` entfallen in jedem Fall. Und der Client kennt den Steam-Deck-Treiber
(`SDL_JOYSTICK_HIDAPI_STEAMDECK` in der Exe, in Retail nicht) sowie `PlatformIsHandheld()`.

---

## 4. Modul für Modul

Legende: ✅ läuft nach Quellenlage wie in Retail · 🔧 Anpassung nötig · ❓ erst im Spiel
klärbar · ❌ entfällt in Forever. Jede Zeile nennt, worauf der Befund fußt.

### 4.1 Hub `DeckUI/` → `DeckForever/`

**Verdict: portieren, mittlerer Aufwand.** Das Gerüst (Einstellungsfenster, Widgets,
`D.Dialog`, bewegliche Rahmen, Geräteerkennung, Minikarten-Knopf, Fehlerfenster) ist reines
Lua und läuft. Die Erkennung wird einfacher: DeckForever hat nur **ein** Spiel, also fallen die
`D.IsMists`/`D.IsRetail`-Weichen weg – wo heute verzweigt wird, bleibt der Retail-Zweig.
`D.IsForever = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` nur als
Schutz, falls das Addon versehentlich in einem anderen Client landet.

| Teil | Befund | Status |
|---|---|---|
| Geräteerkennung, Tastenbelegung pro Gerät | 1280x800, `C_GamePad`, CVar `synchronizeBindings` in der Exe | ✅ |
| Leisteninhalt pro Gerät (`actionbars.lua`) | Slots 1–180 gleich; Schlüssel „pro Spezialisierung“ → **Talentgruppe** (`GetActiveSpecGroup`, Ereignis `ACTIVE_TALENT_GROUP_CHANGED`), wie in MoP. Assistent-Slot entfällt. `C_PetJournal.PickupPet` / `C_ToyBox.PickupToyBoxItem` stehen in der Exe, `Blizzard_Collections` lädt (Sammlungen sind accountweit) | 🔧 |
| Edit-Mode-Layout pro Gerät (`editmode.lua`) | Edit Mode hat **Layouts pro Oberflächenstil** (Mkb/Gamepad). Läuft der Deck mit Blizzards Gamepad-Stil, wechselt der Client das Layout selbst; unser Namens-Abgleich muss den Stil kennen (`EditModeManagerFrame.layoutInfo.layouts[i].interfaceStyle`). Hängt an der Cross-Entscheidung | 🔧❓ |
| Händler (`merchant.lua`) | `C_MerchantFrame.SellAllJunkItems`, Reparatur, Gildenbank in Exe und Docs | ✅ |
| Beute (`loot.lua`), Beutewürfe (`lootroll.lua`) | `LootFrame.lua` / `GroupLootFrame.lua` sind Retails (Mainline-Ordner). Neu: Blizzards Auto-Loot-Schalter (`C_AutoLoot`) und **Plündermeister** (`C_Loot.IsLegacyLootModeEnabled`) – unser Fenster muss Master-Loot-Fälle nicht anfassen, Blizzards Dialoge bleiben | ✅❓ |
| Rangmarken (`rankmark.lua`) | `UnitClassification` da; Blizzards Camelot-Plaketten zeigen selbst keinen Elite-Indikator (`showClassificationIndicator = false`) – unsere Marke ist dort mehr wert als in Retail | ✅ |
| Interaktionsziel (`softtarget.lua`) | CVars `SoftTargetIconInteract`/`-Enemy`/`-Friend` in `Blizzard_NamePlates/Camelot/Blizzard_NamePlateConstants.lua` | ✅ |
| Zielpfeil, FFXIV-Plaketten (`targetarrow.lua`, `nameplates.lua`) | gleiche `Blizzard_NamePlates`; Camelot hängt eine **Stufenanzeige** neben den Balken (`NameplateLevelFrame`), die unter unserer Ausblendung mit verschwindet (wir blenden `plate.UnitFrame` als Ganzes). CVars `nameplateMotion`, `nameplateOverlapV/H` in der Exe | ✅ |
| Talking Head (`talkinghead.lua`) | `Blizzard_TalkingHeadUI` fehlt im Build, Edit Mode versteckt den Haken (`EditModeManagerOverrides.lua:8`), `C_TalkingHead.GetCurrentLineInfo` undokumentiert | ❌ raus |
| Server-Info, Gold, Taschen (`infobars.lua`) | `C_AddOnProfiler` dokumentiert, `MinimapCluster.IndicatorFrame.MailFrame` auch in Camelots Template (`MinimapIndicatorFrameTemplate.xml`), `MainMenuBarBackpackButton` in `BagsBar` | ✅ |
| Hauptmenü rund (`mainmenu.lua`) | Knöpfe laut `MicroMenuContainerOverrides.lua`: Character, Profession (öffnet `ProfessionsFrame`), Spellbook, Talent, **Legacy** (neu, `LegacyMicroButton`), QuestLog, Housing (per Spielregel aus), Guild, LFD (öffnet `LFGParentFrame`), Collections, EJ (aus), Help, Store, MainMenu. Fehlende lässt der Code weg; für Legacy fehlt unser Atlas-Name | 🔧 klein |
| Auktionspreise, AH-Stil (`auction.lua`, `auctionstyle.lua`) | `Blizzard_AuctionHouseUI` lädt (Gate `mainline` = Familie), eigene `Camelot/Blizzard_AuctionData.lua`; `C_AuctionHouse.ReplicateItems` dokumentiert | ✅❓ |
| Schadensmesser-Stil (`damagemeter.lua`) | `Blizzard_DamageMeter` Gate `standard, camelot`; Camelot-Override nur „keine Klassifikation“ | ✅ |
| Questbuch-Scanner (`questbook.lua`) | war für MoPs altes Questlog; Forever hat `C_QuestLog` von Retail | ❌ nicht nötig |
| Charakterfenster, Postfach, Nachkauf (`charpanel.lua`, `mail.lua`, `restock.lua`) | gebaut für MoP; in Forever zählen Verzauberungen/Sockel wieder (Classic-Raids), „Alle öffnen“ hat Retails Postfach schon. Charakterfenster: Camelot hat ein eigenes `PaperDollFrame.lua` – Slots neu prüfen | 🔧 später |
| Dungeon-Warteschlange (`lfgqueue.lua`) | Forever hat den **klassischen Gruppensucher** (`Blizzard_GroupFinder_VanillaStyle`, `LFGParentFrame`), dazu `C_LFGListRoles`; ob es eine Warteschlange mit Auge gibt, zeigt das Spiel | ❓ |

### 4.2 Orbs `DeckUI_Orbs/`

**Verdict: portieren, kleiner Aufwand.** oUF läuft auf Retail-Basis; `Blizzard_AuraContainer`
(Aura-Container mit Verzauberungs-Slots) wird in Forever geladen, der MoP-Ersatz
`auras_mists.lua` ist nicht nötig. Die oUF-Patches für MoP (`-- DeckUI: Mists`) können im
Forever-Baum entfallen – oUF unverändert wie in Retail.

| Teil | Befund | Status |
|---|---|---|
| Klassenressourcen | 9 Classic-Klassen: Combo-Punkte **liegen am Ziel** (`GetComboPoints(unit, "target")`, Ereignis `COMBO_TARGET_CHANGED`, `Blizzard_UnitFrame/Camelot/TargetBoundComboPointBar.lua`) – genau die Regel aus `classpower_mists.lua:62`. Keine Runen, kein Chi, keine Orbs, kein Eclipse-Balken (Forever-Druiden haben Classic-Mana). `classpower_mists.lua` wird zu `classpower_forever.lua` mit nur dem Combo-Teil | 🔧 klein |
| Tier | Jäger-Pets haben wieder **Zufriedenheit** (`UNIT_HAPPINESS`, `C_PetInfo.GetPetHappiness`) – Chance für den FF-Pet-Balken (Farbe/Symbol) | Idee |
| FF-Stile, Boss-Rahmen, Enemy-List, Gruppe, Raid | Secure-Header, Nameplates, `UnitThreatSituation`, `AbbreviateNumbers` alle da | ✅ |
| Buff-Leiste | Retail-Container, `AddItemEnchantment` (Waffenöle/-steine gibt es in Classic reichlich) | ✅ |
| EXP-Leiste (XIV-Stil) | Max-Stufe 60 über `GetMaxLevelForPlayerExpansion` (dokumentiert); am Cap beobachteter Ruf über `C_Reputation.GetWatchedFactionData` → `D.FactionStatus`; Forever hat auch **Renown** (Legacy-Belohnungspfad, PvP-Rang über `C_MajorFactions`) – `D.FactionStatus` kennt das schon | ✅❓ |
| Deine Debuffs (`debuffs.lua`) | Listen sind nach **Spec-ID** geschlüsselt – Forever hat keine Specs. Neu schlüsseln nach Klasse (ggf. Talentgruppe), Zauber-IDs aus Forevers Spieldaten | 🔧 Daten |
| Blizzard-Rahmen parken | `BuffFrame`/`DebuffFrame`, `CompactRaidFrameManager`, Party-Frames: gleiche Namen (Camelot hat eigene `PlayerFrame.lua`/`TargetFrame.lua`, aber dieselben Frames) | ✅ |

### 4.3 Cross `DeckUI_Cross/` – offen (Abschnitt 3)

Unabhängig von der Entscheidung gilt:

| Teil | Befund | Status |
|---|---|---|
| Kreuze, Seitenwechsel, Leisten 3–8 | Slots, `GetOverrideBarIndex`, `MainActionBar`/`MultiBar*`, `OverrideActionBar`, LibActionButton auf Retail-Templates – im **Tastatur-Stil** alles wie Retail | ✅ (Mkb-Stil) |
| Assistent-Anzeige (`assist.lua`), Assistent-Teile in `core.lua` | abgeschaltet in Forever | ❌ raus |
| Haltungsleiste (`stance.lua`) | `StanceBar` (Shared) da; **neu: Totemleiste** `MultiCastActionBarFrame` für Schamanen (Cata-Leiste), die unsere Leisten-Ausblendung heute nicht kennt | 🔧 |
| Schnellmenü RB, Fähigkeiten-Menü B, LB-Zoom | sichere Schnipsel + Override-Bindungen; die Dateien werden geladen, der Beta-Fehler ist aus den Quellen nicht sichtbar | ❓ Probe |
| `EnsureGamepad`, `BindPadDefaults` | die CVars gibt es; Forever hat aber eine **eigene Standardbelegung** (`DefaultForeverBindings.wtf`) und eigene Gamepad-Befehle – unsere Tastenvorgaben (A springt, X interagiert …) könnten mit Blizzards kollidieren | ❓ |
| LibActionButton-Atlas `!UI-HUD-ActionBar-IconFrame-FlyoutMid` | in beiden Quellbäumen nicht als Zeichenkette (Atlas-Datenbank, nicht Lua) – kein Befund | – |

### 4.4 Spec `DeckUI_Spec/`

**Verdict: portieren, kleiner Aufwand – fertig vorhanden.** Forever hat keine
Spezialisierungen, aber die Doppel-Talentgruppe ab 40: `C_SpecializationInfo.GetActiveSpecGroup`,
`SetActiveSpecGroup`, `GetCombatConfigIDForSpecGroup`, `GetNumSpecGroups() > 1`
(`Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua:124-382`). Das ist
die MoP-Variante `core_mists.lua` (ein Knopf je Talentgruppe). Blizzards Camelot-Talentfenster
hat keinen Kopier-Knopf (`HasCopyButton = false`) und keine Loadouts – also auch bei uns keine.

### 4.5 Bags `DeckUI_Bags/`

**Verdict: portieren, mittlerer Aufwand.**

| Teil | Befund | Status |
|---|---|---|
| Taschenfenster | `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua` (Retail-Code) + 17 Zeilen Camelot-Override; `ContainerFrameItemButtonTemplate`, kombinierte Taschen, **Reagenzientasche** (`Enum.BagIndex.ReagentBag = 5`, `CharacterReagentBag0Slot`) | ✅ |
| **Schlüsselbund** | `Enum.BagIndex.Keyring = -1` = `KEYRING_CONTAINER`, CVar `showKeyring`, `C_ActionBar.ShouldShowKeyring()`, `KeyRingButton` in `BagsBar`, `GetKeyRingSize()` (`Blizzard_MainMenuBarBagButtons/Camelot/MainMenuBarBagButtons.lua:44-80`). Für DeckForever: ein eigener Abschnitt „Schlüssel“ im Taschenfenster (Container -1) und ein Knopf in der Taschenslot-Reihe | 🔧 neu |
| Bank | **Retail-Bank mit Tabs**: `BankFrame` (`Blizzard_UIPanels_Game/Camelot/BankFrame.xml`), Charakter-Tabs **1–9** (Bag 6–14) und Account-Tabs **1–6** (Bag 15–20, Icons `UI_Warbands`) – mehr als Retail (6+5). `bank.lua` zählt über `C_Bank.FetchPurchasedBankTabData`, nicht über feste Namen – passt. Neu: `C_Bank.ShouldUsePlayerBagsInBank()` – dann zeigt Blizzard die Tabs als **Seiten** (`GetNumPagesForBankType`, `BankPageTabTemplate`), und `C_Bank.BankBagTypeAndIDToInvSlot` nennt den Inventar-Slot eines Banktabs (Bank-Taschen wie in Classic?). Welcher Zweig in Forever aktiv ist, zeigt das Spiel | ✅❓ |
| Kategorien, Tracked Items, Taschenslots | `C_Item.GetItemInfoInstant`, `PutItemInBag`, Cursor-APIs da | ✅ |
| Alt-Erweiterungs-Filter | eine Erweiterung | ❌ raus |
| Auktionsfilter | `C_AuctionHouse.IsSellItemValid` dokumentiert | ✅ |

### 4.6 Quests `DeckUI_Quests/`

**Verdict: portieren, mittlerer Aufwand – vor allem Abschalten.** `Blizzard_ObjectiveTracker`
ist Retails (alle Module da, kein Gate); Camelot ändert nur zwei Dinge:
`QuestObjectiveTrackerMixin:CanShowTimerBar() = false` und den Quest-Tag-Text
(`Camelot/Blizzard_QuestObjectiveTrackerOverride.lua`). Der Kiosk-Weg (`SetCanAddModules(false)`)
bleibt gangbar; neu gibt es die Spielregel `Enum.GameRule.ObjectiveTrackerDisabled`.

| Abschnitt | Forever | Status |
|---|---|---|
| Quests, Zonen-Widgets, Questgegenstände (sichere Knöpfe) | ✓ | ✅ |
| **Questtimer** | klassische Timer kommen als `Blizzard_QuestTimer` (Gate `classic, camelot`) mit eigenem `QuestTimerFrame`; unser Tracker braucht eine Timer-Zeile oder lässt Blizzards Frame stehen | 🔧 neu |
| Szenario / Mythisch+ / Tiefen-Kopf | `Blizzard_ChallengesUI` lädt nicht, `C_DelvesUI` nur in nicht geladenen Addons; `C_Scenario` dokumentiert – Abschnitt behalten, M+-/Tiefen-Teile raus | 🔧 |
| Kampagne, Kampagnen-Führer (`guide.lua`) | `C_CampaignInfo` wird nur von `Blizzard_ObjectAPI`/`UIPanels` angefasst; Classic-Quests haben keine Kampagnen | ❌ |
| Weltquests, Bonusziele | Module da, Inhalt nicht; Abschnitte abschalten (oder leer lassen) | 🔧 |
| Erfolge → **Legacy** | `Blizzard_LegacyChallengeTracker` verfolgt Legacy-Herausforderungen (Erfolge unter neuer Oberfläche, `GetCategoryInfo`, `C_ContentTracking`); unser Erfolgs-Abschnitt wird „Legacy“ | 🔧 |
| Reisetagebuch (Trading Post), Initiativen (Housing), Jagd (`GetActivePreyQuest`) | `C_PerksActivities` nur in nicht geladenen/irrelevanten Addons, Housing aus, Prey nur in `Blizzard_UIWidgets` | ❌ |
| Rezepte | `Blizzard_Professions` lädt (Gate `mainline`), Camelot-Berufsfenster | ✅❓ |
| „Gruppe finden“-Auge | Gruppensucher ist Vanilla-Stil; ob `QuestUtil.CanCreateQuestGroup` dort je wahr wird, zeigt das Spiel | ❓ |
| FFXIV-Aufgabenliste, Bewegen, `/quests` | reines Lua | ✅ |
| Delve-Macht, Jagdtisch-Sterne (`delves.lua`, `hunt.lua`) | – | ❌ raus |

### 4.7 Map `DeckUI_Map/`

**Verdict: portieren, kleiner Aufwand.** `Blizzard_Minimap` und `Blizzard_WorldMap` sind
Retails mit Camelot-Ordnern (25 bzw. 7 Dateien): neue Atlanten (`UI-HUD-Minimap-Frame`,
Maske `ui-hud-minimap-frame-generic-mask`), die Knöpfe (Zone, Kalender, Tracking,
Addon-Fach) mit eigener Art, **keine Instanz-Schwierigkeit** am Minikarten-Rand
(`MinimapInstanceDifficulty.lua`), dafür der **Day/Night-Anzeiger** (`Diel.lua`, ein Kind von
`MinimapCluster.MinimapContainer` – bleibt beim Parken des Clusters mit zurück; wer ihn will,
holt ihn in unseren Rahmen). `MinimapCluster` ist weiter das Edit-Mode-System, `Minimap`
weiter frei. Weltkarte: oberste Ebene ist „World“, Filter nur Queststufe und
Schwierigkeitsfarbe (`Camelot/Blizzard_WorldMapTemplates.lua`), `WorldMapFrame` unverändert ein
UI-Panel. CVars `rotateMinimap`, `miniWorldMap`, `questLogOpen`, `worldMapShowPlayerCoords`,
`worldMapShowCursorCoords`, `mapFade` stehen in der Exe. Die Mists-Sonderwege (altes
`MinimapBackdrop`, Cata-Karte) sind nicht nötig.

### 4.8 Tooltip `DeckUI_Tooltip/`

**Verdict: portieren, klein bis mittel.** `TooltipDataProcessor`, `GameTooltip`-Regeln,
`SharedTooltip_SetBackdropStyle`: Retail. Änderungen:

- **Inspect**: keine Spezialisierungen – nur Itemlevel (`C_PaperDollInfo.GetInspectItemLevel`
  dokumentiert), Spec-Zeile und `GetInspectSpecialization` raus.
- **Berufswissen**: `C_ProfSpecs` ist dokumentiert und `Blizzard_Professions` lädt mit
  Camelot-Dateien – ob Forever-Berufe Spezialisierungsbäume haben, zeigt das Spiel ❓.
- **Tiefen-Truhe** ❌.
- **Ruf-Gegenstände**: `repdata.lua` ist aus Retails Spieldaten erzeugt; Forever braucht eine
  eigene Tabelle (wago.tools: ob es dort einen Forever-Zweig gibt, war ohne Login nicht
  lesbar – prüfen; sonst `/week record`-artig aus dem Spiel lernen) 🔧.
- **Ensembles**: `Blizzard_Collections` lädt, `C_TransmogSets` da ✅❓ (ob Forever Ensembles
  verkauft, ist Inhalt).
- Quest-Start-Gegenstand ✅.

### 4.9 Nav `DeckUI_Nav/`

**Verdict: portieren, kein Umbau.** `C_SuperTrack` und `C_Navigation` sind dokumentiert (27
Funktionen), `Blizzard_QuestNavigation` mit `SuperTrackedFrame` wird ohne Gate geladen,
`C_Map.GetMapWorldSize` / `GetWorldPosFromMapPos` da. Der Retail-Pfad (Leuchtfeuer,
Wegpunktliste, Routen, Kompass, `/way`) läuft; der MoP-Ersatz `nav_mists.lua` wird nicht
gebraucht. Die Bindungen (`Bindings.xml`) wandern in den DeckForever-Hub.

### 4.10 Week `DeckUI_Week/`

**Verdict: sinnvoll, aber zuletzt und mit neuer Datenbasis – größter Posten.** Fast alles in
der Retail-Woche ist Midnight-Inhalt:

| Teil | Forever | Status |
|---|---|---|
| Große Schatzkammer | `Blizzard_WeeklyRewards` lädt, aber die Schatzkammer existiert als Spielinhalt nicht; `C_WeeklyRewards.GetActivities` dürfte leer sein | ❌ (Probe) |
| Mythisch+ / Schlüsselstein | kein `Blizzard_ChallengesUI` | ❌ |
| Tiefen, Jagden, Berufswissen, Marken/Sparks | – | ❌ |
| Schlachtzugs-Sperren | `GetSavedInstanceInfo` dokumentiert, `C_RaidLocks.IsRaidLockExtendFeatureSupported` neu; Classic-Raids plus Forevers neue | ✅ |
| Weltbosse | `GetNumSavedWorldBosses` – ob Forever welche hat: Inhalt | ❓ |
| Renown | **neu**: Legacy-Belohnungspfad (`LEGACY_REWARD_TRACK_FACTION_ID`) und PvP-Rang über `C_MajorFactions` (von `Blizzard_LegacySystem` genutzt) | 🔧 neu |
| Legacy-Punkte / Herausforderungen | `C_Traits`-Bäume (Berufe, Abenteuer, Fortschritt), Erfolge als „Challenges“ | 🔧 neu |
| Währungen | `Blizzard_TokenUI` mit Camelot-Ordner; welche, zeigt das Spiel | ❓ |
| Weekly/Daily-Quests | das MoP-Lernen (`ns.LearnWeeklies`, Frequenz aus dem Questlog, Dailies mit eigenem Reset) passt eins zu eins | ✅ |
| Datenbasis (`data.lua`) | alle IDs neu; `check-game-data.py` braucht einen Forever-Zweig auf wago.tools (offen) – sonst `/week record` im Spiel | 🔧 Daten |

Das MoP-Gerüst (`collect_mists.lua`, `view_mists.lua`, `data_mists.lua`) ist die Vorlage.

---

## 5. DeckForever als eigenes Addon

- **Ordner**: ein Paket `DeckForever/` mit Modulen `DeckForever_Orbs/` … – gleiche Zuschnitte,
  neuer Präfix. Slash-Befehle und SavedVariables-Namen neu (`/df`, `DeckForeverDB` …), damit
  nichts mit DeckUI in Retail/MoP kollidiert, falls jemand beide installiert.
- **Toc**: je Addon eine `Name.toc` mit `## Interface: 16001` reicht – nur ein Spiel, keine
  Varianten. Kein `_Mists`/`_Mainline`-Gewirr mehr.
- **Was mitkommt**: das ganze Hub-Gerüst (panel, widgets, core, movable, device), oUF ohne
  MoP-Patches, LibActionButton, die Retail-Zweige der Module. Nur die Mists-Dateien, die
  Forever braucht (`core_mists.lua` → Spec, `classpower_mists.lua` → Combo-Punkte,
  `collect_mists.lua`/`view_mists.lua` als Week-Vorlage).
- **Was wegfällt**: talkinghead, assist, delves/hunt/guide, Alt-Erweiterungs-Filter,
  Scenario-M+-Teile, `questbook`, alle `IsMists`/`IsRetail`-Weichen.
- **Release**: eigenes CurseForge-Projekt; die Spielversion (vermutlich „1.60.1“) sieht man erst
  im Upload-Dialog. `package.ps1`/`bump-version.ps1`/`upload-curseforge.ps1` lassen sich mit
  neuer Ordnerliste übernehmen (`release-common.ps1`).
- **Junctions**: `_forever_\Interface\AddOns\DeckForever*` → Repo, wie bei den anderen Clients.
  Der Ordner `_forever_\Interface` existiert noch nicht (Spiel nie gestartet).

---

## 6. Was nur das Spiel beantwortet (Probe am Starttag)

**Vorbereitet (02.11.2026):** `tools/forever/DeckUI_Probe/` liegt als Junction unter
`_forever_\Interface\AddOns\DeckUI_Probe`. Namensliste frisch aus DeckUI 2.1.2 (`names.lua`),
dazu `forever.lua` mit den Fragen unten (Ergebnis in `DeckUIProbeDB.forever`), vier Tocs mit
Interface 16001 und verschiedenen Titeln (`.toc`, `_Forever`, `_Camelot`, `_Mainline`) – welcher
Titel in der Addon-Liste steht, beantwortet die Endungsfrage; `X-Toc` landet in `meta.toc`.
Ablauf am Starttag: einloggen, 5 s warten (oder `/deckprobe`), `/reload`, dann
`python -I tools/forever/readprobe.py <scratch>` (der Scratch-Ordner braucht `foreverscan.json`
aus `tools/forever/foreverscan.py`, siehe dessen Kopf). Beide Oberflächenstile einmal
durchlaufen lassen: Haken „Gamepad-Oberfläche“ in den Einstellungen umschalten, `/deckprobe`,
`/reload` – die Datei hält nur den letzten Lauf, also dazwischen `DeckUI_Probe.lua` aus
`WTF\Account\...\SavedVariables` wegkopieren.

Die Fragen, die kein Quelltext beantwortet:

1. `GetBuildInfo()`: Interface-Nummer (16001?) und `WOW_PROJECT_ID` (18?).
2. Welche Toc-Endung der Client zuerst nimmt (`_Forever` oder `_Camelot`) – ein Addon mit
   beiden Dateien und verschiedenen Titeln.
3. **Sichere Schnipsel**: `SecureHandlerWrapScript`, `RegisterStateDriver`, `SetOverrideBinding`
   auf einem Secure-Header – läuft es, oder kommt der Beta-Fehler?
4. **Controller**: `C_InputInterfaceStyle.GetCurrentStyle()` am Deck und am PC; lässt sich der
   Gamepad-Stil bei angeschlossenem Pad auf Mkb stellen (Einstellung/CVar)? Welche Layouts
   listet Edit Mode je Stil? Was passiert mit `MainActionBar` im Gamepad-Stil?
5. `C_Bank.ShouldUsePlayerBagsInBank()`, Zahl der Banktabs, Schlüsselbund-Slots.
6. `C_WeeklyRewards.GetActivities()` leer? `GetNumSavedWorldBosses()`? Währungsliste?
7. `C_ProfSpecs.GetSpecTabIDsForSkillLine` für einen Beruf – gibt es Spezialisierungsbäume?
8. `GetMaxLevelForPlayerExpansion()` = 60? `C_Reputation.GetWatchedFactionData()` Form?
9. Gruppensucher: `LFGParentFrame`, Warteschlangen-Auge, `C_LFGList`-Antworten.
10. wago.tools: Forever-Produkt für `check-game-data.py` und `repdata`.

---

## 7. Vorgeschlagene Reihenfolge

| Phase | Inhalt |
|---|---|
| 0 | 04.11.: Client starten, Probe laden, Abschnitt 6 abarbeiten; diesen Bericht zum Plan machen |
| 1 | Gerüst: DeckForever-Hub aus dem DeckUI-Hub (ohne Mists/Retail-Weichen, ohne Talking Head/Assistent), Tocs, Junctions, Release-Skripte |
| 2 | Orbs (Combo-Punkte, 9 Klassen), Map, Nav, Tooltip (ohne Spec/Tiefen) – läuft fast so |
| 3 | Spec (Talentgruppen), Bags (Schlüsselbund, Bank-Zweig), Quests (Abschalten, Questtimer, Legacy) |
| 4 | **Cross**: Entscheidung mit dem Live-Client, dann umsetzen (Totemleiste, Standardbelegung) |
| 5 | Week mit Forever-Daten (Sperren, Legacy, Dailies/Weeklies) |
| 6 | Release, danach Deck-Test |

---

## 8. Phase 0: die Probe am 05.11.2026

Gelaufen am 05.11.2026 mit dem Live-Client (Build **70790**, zwei Builds neuer als der oben
geprüfte 70707), Priester Stufe 2, am PC. Rohdaten in `tools/probe_2026-11-05.json`.
Die Fragen aus Abschnitt 6, beantwortet:

| Frage | Antwort |
|---|---|
| 1. Interface, Kennung | **16001**, `WOW_PROJECT_ID = WOW_PROJECT_CAMELOT = 18`. Bestätigt. |
| 2. Toc-Endung | Der Client nahm die **`_Camelot.toc`** (beide lagen da). Eine schlichte `Name.toc` lädt ebenso - DeckForever bleibt dabei. `GetAddOnMetadata(name, "Interface")` liefert nil, dafür gibt es `C_AddOns.GetAddOnInterfaceVersion` (in `/df build` eingebaut). |
| 3. Sichere Schnipsel | `RegisterStateDriver` läuft (`state-probe=0`), `SecureHandlerExecute` läuft (42), `SetOverrideBinding` auf einem Secure-Header läuft. Der Fehler der Probe an Zeile 159 war die Probe selbst: `GetBindingByKey` gibt es in Forever nur als `C_KeyBindings.GetBindingByKey`. **Offen**: der Wrap-Test (`SecureHandlerWrapScript` + `Click()`) setzte sein Attribut nicht (`probe-wrap=nil`); der Wrapper prüft nicht auf `issecure`, also keine Erklärung aus den Quellen. Ob Schnellmenü und B-Menü laufen, zeigt Phase 4 im Spiel. |
| 4. Controller | Am PC: `InputDeviceInterfaceStyle` 0, `GetCurrentStyle()` 0 (Mkb), `IsGamepadUIEnabled` false, `IsGamepadUISupported` true, `PlatformIsHandheld` false, Bindungskontext 9 nicht aktiv. Pad erkannt (Gerät 5), `GamePadEnable` 1, `GamePadEmulateShift` = PADLTRIGGER, `Ctrl` = PADLSHOULDER (Forevers Voreinstellung, nicht RT!), `Alt` none. Alle `GAMEPAD*`-Befehle im Mkb-Stil ohne Taste; nur JUMP, MINIMAPZOOM, TOGGLERUN, VEHICLEEXIT tragen Pad-Tasten. Gamepad-Slots ab **181**, Tier-Slots ab 11. `GamepadMainActionBarFrame` versteckt, `MainActionBar` sichtbar. Edit Mode: Systeme GamepadMainActionBar 30, SwingTimer 29; `C_EditMode.GetLayouts()` listet nur gespeicherte Layouts (eins, Stil 0), `activeLayout` 4 zählt die Voreinstellungen mit. Der Deck-Lauf im Gamepad-Stil steht noch aus. |
| 5. Bank, Schlüsselbund | **`C_Bank.ShouldUsePlayerBagsInBank()` = true** - Blizzard zeigt die Tabs als Seiten; 9 Charakter-Tabs (Bag 6-14), Account-Tabs 15-20 (`FetchMaxNumBankTabs(Account)` meldet 9). Schlüsselbund: Container **-1**, `ShouldShowKeyring` true, **32 Slots**, `GetKeyRingSize` 4. Taschen: `NUM_BAG_SLOTS` 4, `NUM_TOTAL_EQUIPPED_BAG_SLOTS` 5, Reagenzientasche = Bag 5. `ContainerFrameItemButtonTemplate` ist ein ItemButton, `BankPanelPurchaseButtonScriptTemplate` da; `ItemButtonTemplate` und `BankItemButtonGenericTemplate` fehlen. |
| 6. Schatzkammer, Bosse, Währungen | `C_WeeklyRewards.GetActivities()` leer, keine Belohnungen; 0 Sperren, 0 Weltbosse, Sperren-Verlängerung nicht unterstützt; Währungsliste leer (Stufe 2 - erst mit einem höheren Charakter aussagekräftig). `C_MajorFactions`: **2800 PvP Rank Points, 2802 Legacy Track** (beide Renown 0). Legacy-Konstanten: Bäume 1187/1188/1189, Punkte-Währung 4225, je Klasse eine Standard-Kategorie (Priester 15581). `GetTotalAchievementPoints` 0, 29 Kategorien; Spielregel `TrackAchievementsDisabled` aktiv. |
| 7. Berufe | Keine gelernt (Stufe 2); `C_ProfSpecs` da, 11 Skill-Lines. Offen. |
| 8. Max-Stufe, Ruf | `GetMaxLevelForPlayerExpansion()` **60**, `GetMaxPlayerLevel` 60, Expansion 0. Nichts beobachtet; `GetWatchedFactionData` liefert nil. |
| 9. Gruppensucher | `IsGroupFinderEnabled` true, `QuestUtil.CanCreateQuestGroup` da, `C_LFGList` da, `LFGParentFrame` existiert (versteckt), **`PVEFrame` fehlt**. Spielregel `PremadeGroupFinderStyle` aktiv. |
| 10. wago.tools | nicht geprüft (braucht Login). |

Weitere Befunde, die den Plan ändern:

- **Auktionshaus: Retails Fenster.** Die Probe meldete `AuctionHouseFrame` = nil und
  `IsUsingLegacyAuctionClient()` = true, und der erste Schluss daraus (05.11., altes Auktionshaus) war
  **falsch**: `Blizzard_AuctionHouseUI` lädt erst am Auktionator (LoadOnDemand, Ladefamilie `mainline`
  schließt Camelot ein), es gibt kein `Blizzard_AuctionUI` in Forevers Quellen, und der Legacy-Schalter
  ist ein Classic-Global, das kein Auktions-Code liest. Camelot bringt nur eine eigene
  `Blizzard_AuctionData.lua` (Classic-Kategorien, benötigte Stufe statt Itemlevel). `auction.lua` und
  `auctionstyle.lua` des Hubs passen unverändert; `C_AuctionHouse.ReplicateItems` ist dokumentiert.
  Nachgeprüft 05.11. in den Quellen, im Spiel noch nicht.
- **Minikarte**: `MinimapBackdrop` existiert wieder (Kind von `Minimap`, trägt `MinimapCompassTexture`) -
  wie in Mists - **und** der Retail-Cluster (`MinimapCluster` mit `IndicatorFrame.MailFrame`, `GameTimeFrame`,
  `AddonCompartmentFrame`, `TimeManagerClockButton` direkt darunter; `MinimapContainer` hält `Minimap` und den
  `DielFrame`). Map-Phase: Camelots Aufbau neu lesen, nicht Retails `PIECES` blind übernehmen.
- **CVar `nameplateMotion` fehlt** (`nameplateOverlapH/V` da). `nameplates.lua` überspringt sie schon.
  `nameplateShowFriends` fehlt ebenfalls.
- **Micro-Menü**: `EJMicroButton` und `HousingMicroButton` existieren, sind "shown", hängen aber nicht im
  Menü (Spielregeln `EncounterJournalDisabled`, `HousingDashboardDisabled`); `HelpMicroButton` im Menü,
  versteckt; `MainMenuMicroButton` im Menü. `mainmenu.lua` lässt EJ und Housing seit dem 05.11. aus.
- **Talking Head**: `TalkingHeadFrame` und `C_TalkingHead.GetCurrentLineInfo` gibt es in 70790 doch
  (Abschnitt 2 sagte "nicht im Build"). Bleibt draußen - Classic-Inhalt hat keine Talking Heads.
- `ObjectiveTrackerFrame:GetModules` fehlt (`canAddModules` true, Spielregel `ObjectiveTrackerDisabled`
  inaktiv); `QuestTimerFrame` hängt am Tracker. Quests-Phase: den Kiosk-Weg gegen Camelots Tracker prüfen.
- `ComboFrame` (Kind von `TargetFrame`) ist Blizzards Combo-Anzeige am Ziel; Spielregel
  `SingleTargetComboPoints` aktiv. `MultiCastActionBarFrame` (Totemleiste) existiert, versteckt;
  `SwingTimerFrame` heißt anders (`C_SwingTimer` da). `PlayerSpellsFrame` fehlt (Zauberbuch und
  Talente sind getrennte Fenster).
- `C_SpecializationInfo.GetActiveSpecGroup()` = 1, `GetSpecialization` nil, Talent-Config 1791341 -
  der Talentgruppen-Schlüssel des Hubs passt. `C_AssistedCombat.IsAvailable()` false,
  `HasAssistedCombat()` false. `GetComboPoints("player", "target")` da. `C_PetInfo.GetPetHappiness` nil
  beim Priester.
- Secret Values aktiv (`issecretvalue(UnitHealth("player"))` = true). `AuraContainerMixin` und
  `BuffFrame.AuraContainer` da, `CustomAuraContainerMixin` nicht. `C_DamageMeter`,
  `DamageMeterSessionWindowMixin`, `DamageMeterEntryMixin` da - `damagemeter.lua` passt.
- `C_Loot.IsLegacyLootModeEnabled()` false, `C_AutoLoot` und `C_LootFrame` da, `GetLootMethod` nil.
- Fehlende Bindungsbefehle (für das Schnellmenü in Phase 4): TOGGLEACHIEVEMENT, TOGGLECALENDAR,
  TOGGLEDUNGEONSANDRAIDS, TOGGLEENCOUNTERJOURNAL, TOGGLELFGPARENT, TOGGLEMOUNTJOURNAL, TOGGLEPETJOURNAL,
  TOGGLEPVP. Fehlende API: `C_QuestLog.GetQuestInfo` (nur ein Mists-Rückfall; `GetTitleForQuestID` da),
  `C_ChallengeMode.*`, `C_MythicPlus.*` (erwartet). oUFs `SelectionType` ist oUFs eigene Tabelle, kein Befund.
- Hub im Spiel (Phase 1): geladen ohne Lua-Fehler über vier Logins; Fenster, Optionen, Plaketten, Beute,
  Server-Info vom Besitzer angehakt. `/df build` meldet 16001.

## Quellen

- Client: `C:\Spiele\World of Warcraft\.build.info`, `.product.db`, `_forever_\Wow.exe`
  (Zeichenketten-Vergleich mit `_retail_\Wow.exe` und `_classic_\WowClassic.exe`)
- Blizzard-UI: https://github.com/Gethe/wow-ui-source, Zweige `forever` (1.60.1.70532) und
  `live` (12.1.5.70688); Dateilisten `ui-code-list.txt`, `ui-toc-list.txt`
- Scan: `tools/mists/mopscan.py` (Pfade auf `forever-src`/`live-src` umgestellt)
- https://warcraft.wiki.gg/wiki/TOC_format, https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID,
  https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever
- Vorgänger: `FOREVER_BERICHT.md` (26.10.2026, nur Recherche)
