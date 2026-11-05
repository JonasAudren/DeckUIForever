# DeckUI für World of Warcraft: Forever – Machbarkeitsbericht

Stand: 26.10.2026. Grundlage: Blizzards Ankündigungen und Berichte aus der Beta (17.09.–23.10.2026).
**Im Spiel geprüft ist noch nichts.** Auf diesem PC ist kein Forever-Client installiert, die Beta ist
vorbei, der Start ist am **4. November 2026**. Vieles unten stammt von Fan-Seiten und Addon-Autoren,
die die Beta ausgelesen haben, und Blizzard will vor dem Start noch Namen ändern. Jede Zahl hier
gehört deshalb am Starttag mit einer Probe bestätigt, wie bei MoP in Phase 0.

---

## 1. Kurzfassung

**Forever ist für DeckUI viel näher an Retail als an MoP.** Das Spiel ist inhaltlich „Classic+“
(Stufe 60, neue Zonen, neue Rasse, eigene Talente), läuft aber technisch auf der **Retail-Oberfläche
von Midnight 12.1.5**: dieselben Schnittstellen, dieselben Regeln (Secret Values, Aura-Container,
kein Kampflog für Addons). Laut einem Blizzard-Mitarbeiter im WoW-UI-Discord ist Forevers API
weitgehend die von 12.1.5.

Das heißt für DeckUI:
- Der **Retail-Code läuft im Grundsatz**: kein Umbau wie bei MoP (kein Aura-Ersatz, keine alte
  Questlog-API, kein Nachbau der Navigation).
- Was fehlt, sind **Inhalte** von Midnight (Große Schatzkammer, Mythisch+, Tiefen, Jagden,
  Berufswissen, Ruf-Renown, Spezialisierungen, Abenteuerhandbuch). DeckUI muss diese Teile
  dort **abschalten**, statt sie nachzubauen – das ist der Hauptteil der Arbeit.
- **Das größte Risiko ist die eigene Controller-Steuerung von Forever.** Blizzard bringt dort
  erstmals eine echte Gamepad-Oberfläche mit (Fähigkeiten auf den hinteren Schultertasten,
  Ringmenüs). Das ist genau das Gebiet von DeckUI Cross. Ob beide nebeneinander laufen, ob man
  Blizzards Modus abschalten kann und wessen Tastenbelegung gewinnt, ist ungeklärt.

**Aufwand grob: 3–5 Sitzungen** (MoP war 11 Phasen). Empfehlung: am Starttag eine Probe laufen
lassen, dann Phase für Phase wie bei MoP.

---

## 2. Was über Forever bekannt ist

| Punkt | Stand | Sicherheit |
|---|---|---|
| Start | 4.11.2026 (Blizzard) | sicher |
| Inhalt | Stufe 60 dauerhaft, neue Zonen, Rasse „Skyborne“, neue Klassen-Rassen-Kombis, Talente überarbeitet, Doppelspezialisierung ab Stufe 40, „Legacy“ statt Erfolge, Sammlungen accountweit | sicher (Blizzard/Wiki) |
| Addons erlaubt | ja, mit den Midnight-Einschränkungen | sicher (Blizzard laut Icy Veins) |
| Interface-Nummer | **16001** (Version 1.60.1) | Beta-Berichte, am Start prüfen |
| Spiel-Kennung | `WOW_PROJECT_CAMELOT = 18` (Build 70338); in einem früheren Build meldete sie noch 1 wie Retail | unsicher, Blizzard will „Camelot“ noch umbenennen |
| API | Retail-Familie, Obermenge von 12.1.5 | mehrere Quellen, plausibel |
| Fehlt | `GetSpecialization*`, `EncounterJournal` (in Blizzards Addons für Forever abgeschaltet), Kampflog für Addons | Beta-Berichte |
| Vorhanden | Aura-Container, Secret Values, eigener Schadensmesser, Cooldown-Manager | Beta-Berichte |
| Beta-Problem | sichere Schnipsel (secure snippets) ließen sich in Build 69913 nicht übersetzen (`loadstring_untainted` fehlte) | **wichtig**, am Start prüfen |
| Ordner | Beta: `_classic_beta_`; für den Start unbekannt | unsicher |
| CurseForge | Addon-Autoren laden unter „1.60.1“ hoch | am Start prüfen |
| Controller | eingebaut, „Alpha“; Fähigkeiten auf den hinteren Schultertasten, Steuerkreuz frei belegbar (20+ Optionen), vordere Schultertasten zielen (links Verbündete, rechts Gegner), Menüs als Ringmenü; Umschalten Tastatur/Controller per Knopf | Messe- und Beta-Berichte |
| Steam Deck | nicht bestätigt, nur Spielerwunsch; ROG Xbox Ally lief gut | unsicher |

---

## 3. DeckUI Modul für Modul

Legende: ✅ läuft voraussichtlich wie in Retail · 🔧 braucht Abschalten/Anpassen · ❓ erst im Spiel klärbar · ❌ entfällt

### Hub `DeckUI/`
- **Erkennung** 🔧: `D.IsRetail` prüft `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` – auf Forever (18)
  wäre das falsch, sobald Blizzard die Kennung setzt. Neu: `D.IsForever` über die benannte
  Konstante (nicht über die Zahl), Module fragen weiter Fähigkeiten ab statt der Version.
- Einstellungsfenster, Widgets, Fehlerfenster, Minikarten-Knopf ✅.
- Leisten/Layout pro Gerät ✅❓: Edit Mode ist Retail-Oberfläche; Spezialisierungs-Ereignis
  (`ACTIVE_PLAYER_SPECIALIZATION_CHANGED`) gibt es ohne Spezialisierungen vermutlich nicht –
  Schlüssel „pro Spezialisierung“ auf die Talentgruppe umstellen wie in MoP.
- Händler, Beute, Infozeile, Zielpfeil, Namensplaketten, Interaktionsziel ✅.
- Hauptmenü rund ✅: Knöpfe, die es nicht gibt (Abenteuerhandbuch, Housing, Berufe?), lässt der
  Code schon weg.
- Auktionshaus-Preise ❓: hängt davon ab, ob Forever das moderne Auktionshaus hat.
- Schadensmesser-Stil ✅❓: Forever hat Blizzards Schadensmesser; der neue Aufbau aus 2.0.1 sollte passen.
- Talking Head ❓.

### Orbs `DeckUI_Orbs/` ✅
oUF und die Aura-Container laufen auf Retail-Grundlage. Klassenressourcen sind die von Classic
(Combo-Punkte, Wut, Energie, Mana) – die kennt oUF. Neue Fähigkeiten ändern daran nichts.
Gruppe/Raid ✅. Boss-Rahmen ✅. EXP-Leiste im XIV-Stil: Max-Stufe 60 über
`GetMaxLevelForPlayerExpansion` ❓, Ruf am Max-Level über klassischen Ruf (wie MoP) 🔧.

### Cross `DeckUI_Cross/` – **die Kernfrage**
- Kreuze, Seitenwechsel, Leisten 3–8, Haltungsleiste ✅ (Retail-Leisten).
- Assistent-Anzeige ❓: ob es den Ein-Knopf-Assistenten in Forever gibt.
- **Schnellmenü RB, Fähigkeiten-Menü B, Haltungen per LB, Vor/Zurück-Wechsel** ❓: Sie hängen an
  sicheren Schnipseln (`SecureHandlerWrapScript`, Zustandstreiber). Bleibt der Beta-Fehler bestehen,
  gehen genau diese Teile nicht.
- **Konflikt mit Blizzards Controller-Modus** ❓: Forever legt Fähigkeiten selbst auf die hinteren
  Schultertasten (LT/RT) – dort liegen unsere Kreuze. Drei mögliche Ausgänge:
  1. Blizzards Modus ist abschaltbar und unsere Überlagerungs-Tasten gewinnen → DeckUI wie bisher,
     mit Hinweis „Blizzards Controller-Modus aus“ (wie heute die ConsolePort-Warnung).
  2. Beide laufen gleichzeitig und streiten sich → DeckUI Cross in Forever nur ohne Blizzards Modus,
     Erkennung und Warnung beim Einloggen.
  3. Blizzards Modus ist gut genug, dass DeckUI Cross dort überflüssig ist → in Forever nur die
     Anzeige-Teile (Orbs, Karte, Quests …) anbieten.
  Das lässt sich erst im Spiel entscheiden – und ist auch eine Geschmacksfrage für dich.
  **Offen, wird mit dem Live-Client entschieden** (Besitzer, 26.10.2026): was mit Cross und der
  Tastenbelegung auf Forever passiert. Ein weiterer denkbarer Weg ist, Blizzards Modus zu nutzen
  und auf DeckUIs Belegung einzustellen. Damit das entschieden werden kann, braucht die Probe in
  Phase 0 einen eigenen Teil zum Controller-Modus: welche Einstellungen (CVars), Bindungs-Befehle
  und welches Leisten-Layout er mitbringt, ob er abschaltbar ist und was ein Addon daran ändern darf.

### Spec `DeckUI_Spec/` 🔧
Keine Spezialisierungen, aber Doppelspezialisierung (Talentgruppen) ab Stufe 40 → wie in MoP ein
Knopf je Talentgruppe. Ob `C_SpecializationInfo.SetActiveSpecGroup` dort die Funktion ist, zeigt die Probe.

### Bags `DeckUI_Bags/` 🔧❓
Retail-Taschen ✅. Offen: Gibt es Kriegsmeuten-Bank und Banktabs (Retail) oder die alte Bank?
Ein Addon-Autor berichtet von einem **Schlüsselbund** in Forever – den kennt DeckUI nicht.
Reagenzientasche ❓. Alt-Erweiterungs-Filter ❌ (eine Erweiterung).

### Quests `DeckUI_Quests/` 🔧
Tracker ✅ (Retail-Objective-Tracker). Abschalten: Tiefen, Jagd, Weltquests(?), Kampagnen-Führer,
Reisetagebuch, Initiativen; Mythisch+ und Szenario je nach Inhalt ❓.

### Map `DeckUI_Map/` ✅
Retail-Minikarte und -Weltkarte. Koordinaten-CVars ❓.

### Tooltip `DeckUI_Tooltip/` 🔧
Grundstil ✅. Abschalten: Berufswissen, Tiefen-Truhe; Spezialisierung anderer Spieler entfällt
(keine Specs) – nur Itemlevel. Ruf-Gegenstände: eigene Datei aus Forevers Spieldaten (wago, falls es
dort einen Forever-Zweig gibt) 🔧. Ensembles ❓.

### Nav `DeckUI_Nav/` ❓
Kompass, Wegpunktliste, Routen ✅. Ein Leitfaden rät auf Forever zu `C_Map.SetUserWaypoint` statt
Super-Tracking – ob `C_SuperTrack` und `C_Navigation` (Leuchtfeuer) da sind, zeigt die Probe.
Im schlechtesten Fall hilft der MoP-Ersatz `nav_mists.lua`, den es schon gibt.

### Week `DeckUI_Week/` 🔧
Fast alles in der Retail-Woche ist Midnight-Inhalt. Neu wie bei MoP: Schlachtzugs-Sperren
(Barrow Deeps, Hyjal-Gipfel, Onyxias Hort), Dungeons, Legacy-Punkte statt Erfolgen,
Wochenquests (werden ohnehin gelernt). Datenbasis erst, wenn Forevers Spieldaten bekannt sind.
Das MoP-Gerüst (`collect_*`/`view_*`) lässt sich direkt wiederverwenden.

---

## 4. Release

- **Toc:** Zwei Wege. (a) Eine Zeile `## Interface: 120105, 16001` in den Retail-Tocs – passt, weil
  der Code derselbe ist; `package.ps1` prüft heute „alle gleich“ und müsste Listen verstehen.
  (b) Eigene `_<Name>.toc` wie bei MoP (Endung hängt am endgültigen Spiel-Namen, ob „Camelot“
  oder anders). Empfehlung: (b), weil Forever andere Dateien laden soll (Week-Daten, Ruf-Daten,
  Abschaltungen) – genau wie MoP. Entscheidung erst mit dem Start-Client.
- **Upload:** `upload-curseforge.ps1` nimmt seit 2.0.0 Listen; Forever wäre die dritte Spielversion
  (vermutlich „1.60.1“). Probelauf zeigt, ob CurseForge sie führt.
- `release-common.ps1`, `package.ps1`, `bump-version.ps1`: dritte Toc-Variante wie die MoP-Variante.

---

## 5. Risiken

1. **Blizzards Controller-Modus** gegen DeckUI Cross (siehe oben) – noch offen, wird mit dem
   Live-Client entschieden; der Modus ist noch „Alpha“ und kann sich bis zum Start ändern.
2. **Sichere Schnipsel** in der Beta kaputt – trifft Schnellmenü, Fähigkeiten-Menü, Haltungen.
3. **Spiel-Kennung** wird umbenannt – darum Erkennung über benannte Konstante und Fähigkeiten,
   nie über die Zahl 18.
4. **Quellenlage**: fast alles Technische stammt aus der Beta, von Fans und Addon-Autoren. Blizzard
   selbst hat nur „Addons ja, mit Midnight-Regeln“ bestätigt.
5. **Steam Deck**: nicht bestätigt; über Proton wie Retail wahrscheinlich, aber ungetestet.

---

## 6. Vorschlag für das Vorgehen

| Phase | Inhalt |
|---|---|
| 0 | Am 4.11. Client installieren, `DeckUI_Probe` (aus der MoP-Arbeit, `tools/mists`) auf Forever umstellen und laufen lassen: Interface, Kennung, Ordner, fehlende APIs, sichere Schnipsel, Controller-CVars und -Bindungen. Danach diesen Bericht zum Plan machen. |
| 1 | Gerüst: `D.IsForever`, Toc-Variante, Release-Skripte, Junctions, `D.FOREVER_MODULES` |
| 2 | Orbs, Map, Tooltip, Quests mit Abschaltungen (läuft vermutlich fast so) |
| 3 | Cross und Tastenbelegung: mit den Probe-Ergebnissen gemeinsam entscheiden, dann umsetzen |
| 4 | Spec (Talentgruppen), Bags (Bank/Schlüsselbund), Nav |
| 5 | Week mit Forever-Daten |
| 6 | Release mit drei Spielversionen; danach Deck-Test |

---

## Quellen

- Blizzard: [Beta now live](https://news.blizzard.com/en-us/article/24304160/the-world-of-warcraft-forever-beta-now-live), [Pre-Purchase](https://news.blizzard.com/en-us/article/24301508/pre-purchase-world-of-warcraft-forever-upgrades-and-begin-your-next-journey-in-azeroth)
- [Warcraft Wiki: World of Warcraft: Forever](https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever)
- [Wowhead: Forever](https://www.wowhead.com/forever)
- [Icy Veins: Addons in WoW Forever](https://www.icy-veins.com/wow-forever/news/addons-in-wow-forever-blizzard-devs-just-addressed-the-big-question/)
- [wowforeverguides: Patterns](https://wowforeverguides.com/addons/patterns), [API-Cheatsheet](https://wowforeverguides.com/addons/api-cheatsheet), [Developer Guide](https://wowforeverguides.com/addons/developers)
- [nazumods/wow #951 – Forever-Port eines Addon-Pakets](https://github.com/nazumods/wow/issues/951)
- Controller: [Warcraft Tavern](https://www.warcrafttavern.com/forever/news/world-of-warcraft-forever-has-built-in-controller-support/), [MeinMMO](https://mein-mmo.de/en/wow-playing-forever-with-controller-this-apparently-works-really-well,1587811/), [GodIsAGeek](https://godisageek.com/2026/09/wow-forever-xbox-controller-support/)
