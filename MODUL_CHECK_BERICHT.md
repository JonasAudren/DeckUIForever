# DeckUIForever – Modul-Check (17.11.2026)

Stand: Arbeitskopie nach 1.5.3 mit den heutigen, noch nicht committeten Änderungen für 1.5.4
(Schalter für Spieler- und Zielrahmen, Heilvorhersage).

## Kurzfassung

- Alle zwölf Module wurden vollständig gelesen (96 eigene Lua-Dateien, rund 33.000 Zeilen).
  **Nichts davon wurde im Spiel ausgeführt** – alle Funde stammen aus dem Lesen des Codes.
- Das Skript-Audit ist sauber: keine Syntaxfehler, jede toc-Zeile hat ihre Datei, keine verwaiste
  Lua-Datei, alle Module in der Release-Liste, überall Version 1.5.3.
- Der Gesamtzustand ist gut. Kampfsperren, geheime Werte und Taint sind fast überall sauber
  behandelt; einen Absturz bei einer frischen Installation hat kein Prüfer gefunden.
- Es gibt **acht Fehler, die ich selbst im Code nachgeprüft habe** und die vor dem nächsten Release
  behoben werden sollten (Abschnitt 1). Einer davon steckt in der heutigen Arbeit.
- Die größten Baustellen jenseits einzelner Fehler: der Quest-Autopilot ohne Schutz vor
  wiederholbaren Abgaben, das HoT-Fenster mit voller Arbeit in jedem Tick, toter Retail-Code in
  Week und Quests, und `panel.lua` / `hots.lua` als sehr große Dateien.

### Wie geprüft wurde

Acht Prüfer haben parallel je einen Bereich komplett gelesen (Hub in zwei Teilen, Orbs in zwei
Teilen, Questing, Bags/Bars/Pad/Spec, Map/Nav/Tooltip, Quests/Week). Die schwersten Funde habe ich
danach selbst an der Codestelle nachgelesen. In den Modulabschnitten gilt:

- **[bestätigt]** – von mir an der Stelle nachgeprüft.
- ohne Marke – vom Prüfer gemeldet und mit Stelle belegt, von mir nicht einzeln nachgeprüft.
- **[offen]** – hängt davon ab, was der Forever-Client tut; nur ein Test im Spiel klärt es.

Aufwand: **K** klein (unter einer Stunde), **M** mittel, **G** groß.

---

## 1. Zuerst beheben (alle bestätigt)

> **Nachtrag vom selben Tag:** Alle acht sind im Code behoben (für 1.5.4, nicht committet, im Spiel
> ungetestet). Nr. 1 über `ns.SpawnQuiet` in Orbs `core.lua`; Nr. 4 über den neuen Schalter
> „Repeatable quests too“ (aus) und eine Sperre für Abgaben, die Gold kosten; bei Nr. 5 zusätzlich
> `IsVisible` statt `IsShown` in `restock.lua`. Die übrigen Abschnitte sind unverändert offen.

| # | Modul | Stelle | Was passiert |
|---|-------|--------|--------------|
| 1 | Orbs (heute) | `buffs.lua:251`, auch `party.lua:329`, `raid.lua:451`, `layout.lua:581` | „Player frame“ aus und eigene Buff-Leiste an: Blizzards Spielerrahmen verschwindet trotzdem. Jedes `oUF:Spawn("player"/"target")` schaltet Blizzards Rahmen stumm – auch die Testmodi `/orbs test`, `/orbs raid`, `/orbs boss`. |
| 2 | Bags | `core.lua:210-211` | „Gold coin on valuable items“ aus: Rechnung mit `false`, Lua-Fehler beim ersten Platz mit Gegenstand, das Taschenfenster bleibt stehen. |
| 3 | Hub | `panel.lua:1489-1492` | Die beiden UI-Skalierungsregler speichern nie. `D.Slider` ruft nur `apply`, und dieses `apply` schreibt den Wert nicht. Der Regler springt beim nächsten Öffnen zurück. |
| 4 | Questing | `dialog.lua:88-93, 160-172` | Der Autopilot kennt keine wiederholbaren Abgaben. Eine wiederholbare Quest (Stoff, Rufmarken) kann in Schleife abgegeben werden, bis die Gegenstände weg sind. Ob das Gossip-Fenster in Forever wirklich wieder aufgeht, ist **[offen]**. |
| 5 | Hub | `restock.lua:58` | Das Budget ist für jeden Artikel `GetMoney()` und wird nie um das schon Gekaufte verringert. Reicht das Gold nur für einen von drei Artikeln, meldet der Chat trotzdem alle drei als gekauft. |
| 6 | Orbs | `ffstyle.lua:449, 581, 915, 984, 1099` | `health.colorTapped = true` wirkt nicht; oUF heißt die Option `colorTapping`. Von anderen angeschlagene Gegner werden auf Ziel, Fokus und Boss nie grau. |
| 7 | Hub | `panel.lua:383` und `:385` | „Defaults“ lässt Schlüssel liegen: `ahScan` und `ahStyle` fehlen in `LOOT_KEYS`, `groupStyle` fehlt in `GroupKey` (und wird dafür von der Orbs-Seite still zurückgesetzt). |
| 8 | Week | `view_forever.lua:108` | Liest `snap.worldBosses`, aber kein Sammler schreibt es. Sobald `ns.WORLD_BOSSES` gefüllt wird, steht jeder Boss für immer auf „offen“. Heute noch ohne Wirkung. |

Vorschlag zu Nr. 1: eine Hilfsfunktion `ns.SpawnQuiet(unit, name)`, die `oUF.DisableBlizzard` um den
Spawn herum stilllegt, wenn der passende Schalter aus ist.

---

## 2. Hub (`DeckUIForever`)

### 2.1 Grundgerüst und Einstellungen

**Zustand:** gut. SavedVariables werden erst nach ADDON_LOADED angefasst, Kampfsperren sind
einheitlich, nichts rechnet mit geheimen Werten. Die Schwächen liegen an den Nahtstellen.

**Fehler und Risiken**

- **[bestätigt]** UI-Skalierungsregler speichern nicht (`panel.lua:1489-1492`), siehe Abschnitt 1.
- **[bestätigt]** `LOOT_KEYS` ohne `ahScan`/`ahStyle` (`panel.lua:383`), siehe Abschnitt 1.
- `errors.lua:62-67`: `debuglocals` und `debugstack` laufen für jeden Fehler, bevor Duplikate
  erkannt werden; ein offenes Fenster baut seinen Text pro Fehler neu. Bei einer Flut wie den
  1.047 oder 1.514 Fehlern in einem Kampf kostet das jedes Mal. Erst auf bekannte Meldung prüfen.
- `core.lua:561-562` mit `panel.lua:969, 1032`: Ein im Kampf eingeschaltetes Modul meldet „wird nach
  dem Kampf geladen“, aber nichts lädt es und kein Reload-Knopf erscheint.
- `core.lua:166-176`: Gerätewechsel (`D.SetDevice`) gilt sofort, während alles für das alte Gerät
  geladen ist. Mit `keepBars` kann die nächste Leistenänderung im Layout des anderen Geräts landen.
  Besser erst beim Reload anwenden, wie `SetDeckTest`.
- `core.lua:698-711`: Entsperrte Rahmen werden bei Kampfbeginn nicht gesperrt; die Overlays liegen
  dann über Einheitenrahmen und Leisten.
- `widgets.lua:246-248`: `D.Dialog` ersetzt eine offene Frage still. Die Reload-Frage des Edit Mode
  beim Login kann so verloren gehen.
- `core.lua:150-158`: Das automatische Gerät wird erst bei PLAYER_LOGIN gemerkt, Module laden aber
  schon vorher. Auf einem angedockten Deck könnten Positionen im falschen Gerätesatz landen. **[offen]**
- `core.lua:796-798`: Die Skalierung erlaubt 0,5; Retails CVar `uiScale` endet bei 0,64. **[offen]**

**Verbesserungen**

- `D.Slider` soll `db()[key]` selbst schreiben wie `D.Checkbox` – beseitigt die Falle hinter dem
  Skalierungsfehler dauerhaft. **M**
- `/df help`: rund zwanzig Befehle sind nirgends auffindbar; `/df overview` aus CLAUDE.md gibt es
  nicht mehr. **K**
- `/df reset` löscht alle Positionen ohne Rückfrage, der Knopf fragt vorher. **K**
- Fremde Fehler kennzeichnen: Der Sammler meldet Fehler aller Addons unter DeckUIForevers Namen. **K**
- Fehlerfenster bei `D.GamepadWindow` anmelden – das einzige Hub-Fenster ohne Steuerkreuz, auf dem
  Gerät, auf dem Kopieren am schwersten ist. **K**
- Suchindex cachen (`panel.lua:729-777`), er wird bei jedem Tastendruck neu gebaut. **K**
- Toter Code: `D.MODULE_TITLES`, die `migratedCrossPC`-Migration, ungenutztes `live` in `panel.lua:958`. **K**
- Cross nicht mehr bewerben: Die toc-Notiz verspricht eine „cross hotbar“, `modules.Cross` steht
  auf an, das Modul existiert nicht. **K**
- `panel.lua` (1.632 Zeilen) teilen: Fenster/Seitenleiste, Suche, Start/Presets, Hub-Seiten. Die
  Reset-Schlüssel aus den aufgezeichneten Seiteneinträgen ableiten, damit sie nicht wieder
  auseinanderlaufen. **G**

### 2.2 Loot, Händler, Namensplaketten, Infoleisten, Menü, Auktion, Helfer

**Zustand:** sorgfältig. Die schwächsten Dateien sind die beiden aus Mists übernommenen Helfer
`restock.lua` und `mail.lua`.

**Fehler und Risiken**

- **[bestätigt]** `restock.lua:58`: Budget wird nicht verringert, siehe Abschnitt 1.
- **[bestätigt]** `restock.lua:221`: `win:IsShown()` bleibt nach dem ersten Öffnen wahr, weil das
  Fenster Kind des versteckten Händlerfensters ist. `Refresh()` läuft dann bei jedem Taschenereignis,
  auch beim Plündern im Kampf. `IsVisible()` nehmen.
- `restock.lua:49`: nutzt das globale `GetMerchantItemInfo`, das Retail durch
  `C_MerchantFrame.GetItemInfo` ersetzt hat. Fehlt es in Forever, wirft jeder Händlerbesuch. **[offen]**
- `mail.lua:120`, `restock.lua:34`: `GetCoinTextureString` global – genau der Fehler, der in
  `rewards.lua` schon behoben wurde. Gleiche Abfrage übernehmen.
- `lfglisting.lua:97-98`: zählt nur Spieler und party1-4; ein Schlachtzug-Eintrag zeigt „5/40“.
- `loot.lua:357-378`: Die Beuteliste nennt auch Gegenstände, die wegen voller Taschen gar nicht
  aufgenommen wurden.
- `auction.lua:246-251`: `ahLastScan` wird vor dem Lesen geschrieben; nach einer leeren Antwort
  zeigt das Fenster 15 Minuten weder Status noch Knopf.
- `merchant.lua:96` mit `restock.lua:220`: Nachkauf läuft vor dem zweiten Reparaturversuch; ein
  knapper Charakter gibt das Schrottgeld für Reagenzien aus, die Reparatur scheitert.
- `softtarget.lua:99-112`: Der Ring füllt sich bei jedem eigenen Zauber, auch wenn man neben einem
  Kraut heilt.
- `loot.lua:128-135`: kein Plündermeister-Pfad. **[offen]** (ob Forever Plündermeister hat)

**Verbesserungen**

- Würfelfenster aufs Deck bringen: `lootroll.lua` ist nicht bei `D.GamepadWindow` angemeldet,
  Würfeln braucht den Trackpad-Zeiger. **M**
- Goldleiste zeigt nur ganzes Gold; ein niedriger Charakter sieht „0“. Unter 1 Gold Silber und
  Kupfer zeigen. **K**
- Namensplaketten: Das Ausblenden entfernt auch Blizzards Zauberleiste und Debuffs ohne Ersatz.
  Mindestens eine Zauberleiste, oder es im Tooltip sagen. **M**
- Charakterfenster: Kopf-, Schulter- und Beinverzauberungen sind Stufe-60-Inhalt; ein
  Levelcharakter sieht dauernd rote Marken. Nach Stufe filtern. **K**
- Händler: Taste zum einmaligen Überspringen von Verkauf und Reparatur. **K**
- Hauptmenü zeichnet Porträt und Knöpfe zweimal pro Sekunde neu; `UNIT_PORTRAIT_UPDATE` nehmen. **K**
- Doppelter Code: `NoMouse` plus Ausblenden per `SetAlpha`-Hook steht in vier Dateien, der
  Vier-Linien-Kasten in drei. In gemeinsame Helfer legen. **M**

---

## 3. Orbs (`DeckUIForever_Orbs`)

### 3.1 Einheitenrahmen, Gruppe, Schlachtzug, Buff-Leiste, Gegner, Debuff-Fenster

**Zustand:** gut. Die heutigen Schalter sind in `layout.lua`, `ffstyle.lua` und `debuffs.lua`
nil-sicher. Die Lücke liegt außerhalb dieser Dateien (Abschnitt 1, Nr. 1).

**Fehler und Risiken**

- **[bestätigt]** Andere Spawns schalten Blizzards Rahmen stumm (`buffs.lua:251` u. a.).
- **[bestätigt]** `colorTapped` wirkt nicht (`ffstyle.lua`, fünf Stellen).
- **[bestätigt]** `groupStyle` fehlt im Reset der Gruppen-Seite (`panel.lua:385`).
- `debuffs.lua:345-362`: Mit `dotAttach` an und „Target frame“ aus bleibt `attached` wahr – die
  Zielspalte fällt ins Fenster zurück, aber ohne Titel und ohne behaltene Spalten.
- `buffs.lua:188`: `ns.ApplyBuffBar` ändert die Größe eines geschützten Rahmens; ein Regler der
  Buff-Leiste im Kampf gibt „Aktion blockiert“. Gleiches Muster in `party.lua:355`.
- `raid.lua:254` und `:261`: Lebenstext und Statustext teilen den Anker; ein Toter zeigt „0%“ und
  „Dead“ übereinander.
- `layout.lua:658-665`: Die Zielansage greift ohne Geheim-Prüfung auf die Klassenfarbe zu. **[offen]**
- `debuffs.lua:913`: Eine geheime Antwort auf „Fokus gleich Ziel“ blendet die Fokusspalte den
  ganzen Kampf aus – gegen die eigene Regel der Datei.
- Heilvorhersage: Die Maske gehört dem Elternrahmen, nicht dem Balken. Ob das im Client schneidet,
  ist **[offen]** – das ist der Punkt, den du bei den Orbs testen solltest.

**Verbesserungen**

- Heilvorhersage auch auf Gruppen- und Schlachtzugrahmen – dort liest ein Heiler sie. Dazu
  `Health.DamageAbsorb` für Machtwort: Schild, das oUF schon kann. **M**
- Bereitschaftscheck, Wiederbelebung, Beschwörung, Anführer und Zielmarken auf Gruppe und
  Schlachtzug; die oUF-Elemente liegen schon in `libs/oUF/elements`. **M**
- Der Orb-Zielrahmen zeigt nur den Namen (keine Stufe, kein Rang); kein Reichweiten-Ausblenden auf
  Ziel und Fokus; keine Kampf-, Ruhe- oder PvP-Marke am Spieler. **K/M**
- Seiten „Player“, „Target“, „Target of target“ sagen nicht, wenn der Rahmen aus ist oder der Stil
  „Orbs“ gilt, wo nichts davon wirkt. **K**
- `ffstyle.lua:1230`: Mit „Player frame“ aus ersetzt die EXP-Leiste im XIV-Stil weiter Blizzards.
  Entscheiden, ob sie dem Schalter folgen soll. **K**
- `enemies.lua:186-205` fragt alle 0,15 s 40 Plaketten ab, auch außerhalb des Kampfes. Über
  NAME_PLATE_UNIT_ADDED/REMOVED führen. **K**
- `party.lua:84-88`: Das Klassensymbol wird bei jedem UNIT_HEALTH neu berechnet. **K**
- `buffBarCombatKeep` hat eine Checkbox, aber keinen Eintrag in `DEFAULTS`. **K**
- Doppelter Code: `BuildBoss` und `BuildBossXIV` sind fast gleich; der einfache Balken existiert
  dreimal. **M**

### 3.2 HoT-Fenster und Deck Heal

**Zustand:** sorgfältig für die Grenzen der Engine gebaut. Schwach sind das späte Anlegen der
Plätze im Heilermodus und Zustand, der in jedem 0,25-s-Tick neu angewendet wird.

**Fehler und Risiken**

- `hots.lua:1264` (mit `:715`, `:1752`): Im Heilermodus entstehen Plätze nur für Einheiten, die
  außerhalb des Kampfes existieren. Wer mitten im Kampf dazukommt, bekommt eine Zeile ohne Knöpfe.
  Alle Plätze für jede Zeile vorab anlegen.
- `hots.lua:1265`: Solange `pendingSpell` gesetzt ist, läuft `Assign` jeden Tick. Ein
  Zauberbuch-Ereignis im Kampf lässt dann unter anderem die Warnung alle 0,25 s neu starten.
- `layout.lua:413` über `padheal.lua:258, 896, 970`: Mit Deck Heal an schreibt jede
  Gruppenänderung im Kampf „takes effect after combat.“ in den Chat, ohne dass du etwas geändert hast.
- `hots.lua:581-586`: Die Steuerkreuz-Bilder von Deck Heal hängen an der CVar
  `GamepadUsePartyTargeting` und verschwinden im Schlachtzug, obwohl Deck Heal beides nicht braucht.
- `hots.lua:394`: Ein niedriger Rang in der eigenen Liste (`hotCustom`) wirkt den höchsten Rang;
  Deck Heal respektiert die ID. Die beiden Funktionen widersprechen sich.
- `padheal.lua:989-992`: Nach dem Umbelegen der Tasten bleibt die Ebene bis zum Reload auf den
  alten Tasten.
- `hots.lua:1383-1411`: Ein Schlachtzugmitglied, das im Kampf dazukommt, ist im Heilermodus bis
  Kampfende unsichtbar.
- `hots.lua:1773`: Die unsichtbare Fremden-Zeile (du selbst als Ziel, solo) fängt weiter Klicks
  und wirkt Zauber.
- `padheal.lua:804`: Im Umschaltmodus bleibt das Zielen auf Freunde dauerhaft an. **[offen]**

**Verbesserungen**

- `Finish` und `Stack` ankern jeden Tick alles neu; auf ein Änderungsflag umstellen. **M**
- `BuffState` kostet bis zu 42 geschützte Aufrufe pro Buff, Einheit und Tick; mit `hotRaid` sind
  das Tausende pro Sekunde. Über `UNIT_AURA` je Einheit treiben. **M**
- `HotRoundNext` fragt zweimal pro Sekunde ab, auch wenn die Ebene ruht. **K**
- Zweiter Zauber je Platz auf Rechtsklick, für das Herunterstufen in Classic. **M**
- Deck Heal: eine Wahl für das aktuelle Ziel, und Ring plus Bilder auch in der Schlachtzugtabelle. **M**
- Buff-Runde: einen Toten überspringen, der schon eine Wiederbelebung offen hat. **K**
- Gemeinsame Helfer mit `debuffs.lua` und `padheal.lua` (Abklingzeit, Listenparser, Bildfabrik,
  `Secret`/`Ask`/`RankIDs`). **M**
- `hots.lua` (2.131 Zeilen) teilen: Zauberdaten, Zeilen und Plätze, Layout, Manaregeneration,
  Abklingzeiten. **G**

---

## 4. Bags (`DeckUIForever_Bags`)

**Zustand:** solide Architektur – Blizzards Gegenstandsknopf ohne eigenes OnClick, Ereignisse zu
einem Durchlauf pro Bild gebündelt.

**Fehler und Risiken**

- **[bestätigt]** `core.lua:210-211`: Lua-Fehler mit „Gold coin on valuable items“ aus.
- `bank.lua:519-523`: Lehnt die Bank den Gegenstand ab oder ist sie voll, läuft danach Blizzards
  Klick auf dem entsperrten Platz. Ein Rechtsklick auf einen Trank könnte ihn dann trinken statt
  einlagern. Vorher prüfen, ob die Bank den Gegenstand nimmt. **[offen]**
- `bags.lua:90`: Die „Neu“-Markierung wird nie gelöscht; die Kategorie schrumpft nur pro
  überfahrenem Gegenstand. **[offen]**
- `bags.lua:121-139`: Der freie Platz zählt Spezialtaschen (Köcher, Seelentasche) mit; ein
  Ablegen dort wird abgelehnt. **[offen]**
- `bank.lua:359-361`: Wechsel des Banktyps im Kampf lässt „Buy tab“ auf dem alten Typ.

**Verbesserungen**

- „Schrott verkaufen“-Knopf beim Händler: Münze und Kategorie gibt es, die Aktion nicht. **K**
- Teilstapel beim Einlagern (bestehenden Stapel füllen, Rest auf freien Platz). **M**
- Taschenplätze hervorheben, wenn man über das Taschenquadrat fährt. **K**
- `ITEM_LOCK_CHANGED` nennt Tasche und Platz, löst aber einen vollen Neuaufbau aus. **K**
- Kategorien sind fest; keine eigene Reihenfolge, keine Gruppe für Munition oder Seelensplitter. **M**

---

## 5. Bars (`DeckUIForever_Bars`)

**Zustand:** LibActionButton trägt die Hauptlast; die Kampfsperren im Layout sind einheitlich.

**Fehler und Risiken**

- `core.lua:427-442` mit `config.lua:31-37`: „Recast timer“ oder „Hide the keys“ im Kampf
  umschalten setzt Attribute ohne Kampfsperre – bis zu 96 blockierte Aktionen.
- `stance.lua:82-83`, `pet.lua:115-116`: Die Abklingzeiten werden entgegen dem Kommentar doch
  verglichen. Sind sie im Kampf geheim, wirft jedes Abklingzeit-Ereignis. **[offen]**
- Leisten 2 bis 8 haben keinen Sichtbarkeitstreiber und bleiben mit der Fahrzeugleiste sichtbar,
  wo Blizzard die eigenen ausblendet.
- `core.lua:480-482`: `CleanButton` läuft bei jeder Knopfaktualisierung und erzeugt jedes Mal
  Tabellen, obwohl längst alles entfernt ist.
- `core.lua:326-335`: Welche Leisten Blizzard zeigt, wird sehr früh gelesen; eine frische
  Installation könnte nur Leiste 1 übernehmen. **[offen]**

**Verbesserungen**

- Ausblenden außerhalb des Kampfes, Einblenden bei Mausberührung, Durchklicken – je Leiste. **M**
- Makronamen sind fest aus, ohne Option. **K**
- Tastenbelegungsmodus (LibKeyBound einbetten; das Ziel ist schon gesetzt). **M**
- Das Slot-Aussehen existiert dreimal (Bars, Totemleiste, Pad) samt zwei Kopien der Textur; in den
  Hub legen. **M**
- `stance.lua` und `pet.lua` teilen sich Knopfbau und Treiber; eine gemeinsame Zeilenfabrik. **M**
- Totemleiste bekommt die Abklingzeit-Schrift nicht. **K**

---

## 6. Pad (`DeckUIForever_Pad`)

**Zustand:** sauberes Nur-Hooks-Design; kein Schreiben in etwas, das Blizzards Stilpfad liest.

**Fehler und Risiken**

- `core.lua:377-389`: `ns.Apply()` läuft einmal beim Laden und nie wieder. Erscheint Blizzards
  Controllerleiste später (Stil mitten in der Sitzung eingeschaltet, Deck-Test), wird nichts
  eingekleidet, und PC-Nutzer bekommen bei jedem Login die „nicht gefunden“-Zeile. **[offen]**
- `core.lua:353-359`: Mit der Option aus verschwinden die Tastenbilder auch auf der gehaltenen
  Leiste; der Tooltip verspricht das Gegenteil.
- `core.lua:153-154`: Blizzards Hervorhebungen (neuer Zauber, Zauberhinweis) werden ohne Ersatz
  ausgeblendet.

**Verbesserungen**

- `D.NeedReload("pad:emptyGlyph")` ohne Rücknahme beim Zurückschalten. **K**
- Abklingzeit-Schrift von Bars übernehmen, damit beide Leisten gleich zählen. **K**
- Slot-Aussehen und Textur über den Hub mit Bars teilen. **M**

---

## 7. Spec (`DeckUIForever_Spec`)

**Zustand:** klein und richtig für das, was es tut; als Umschalter dünn.

**Fehler und Risiken**

- `core.lua:151-160, 176`: Unter Stufe 40 oder ohne Dualtalente zeigt die Leiste ein einzelnes,
  wirkungsloses Klassensymbol. Ausblenden, solange es nur eine Gruppe gibt.
- `core.lua:130`: Beginnt innerhalb der 0,5 s Verzögerung ein Kampf, entfällt der Ausrüstungswechsel
  still und wird nie nachgeholt.
- `core.lua:187-198`: Feuert das Ereignis doppelt oder am Ladebildschirm, wird das Set über von
  Hand gewechselte Teile gelegt. **[offen]**

**Verbesserungen**

- Sagen, welche Gruppe welche ist: Punkte je Baum im Tooltip oder ein eigener Name je Gruppe. **M**
- Tastenbelegung „Talentgruppe wechseln“ und ein Fortschrittshinweis. **K**
- Die Set-Auswahl „Secondary“ ausblenden, solange es nur eine Gruppe gibt. **K**

---

## 8. Map (`DeckUIForever_Map`)

**Zustand:** vorsichtig beim Taint – nur Nach-Hooks, Alpha und Anker. Gefunden wurde veralteter
Zustand und Layout, kein Absturz.

**Fehler und Risiken**

- `minimap.lua:124-130, 170-176`: Der Zonentext hat einen Anker und keine Breite.
  „Stranglethorn Vale 30-45“ läuft auf der 150 px breiten Deck-Karte über.
- `minimap.lua:303-308`: Später erzeugte Addon-Knöpfe bleiben sichtbar, bis die Maus die Minimap
  zum ersten Mal kreuzt.
- `minimap.lua:400-408`: Beim Stufenaufstieg bleibt die Farbe des Stufenbereichs bis zum nächsten
  Zonenwechsel alt; die Weltkarte wird gar nicht aufgefrischt.
- `worldmap.lua:26-32`: Der Größenregler verschiebt das Kartenfenster, weil die gespeicherten
  Abstände in skalierten Einheiten stehen.
- `worldmap.lua:347-350`, `config.lua:63`: `questLogOpen` wird bei jedem Login auf 0 gezwungen;
  die Checkbox hat keine Wirkung ohne Reload.

**Verbesserungen**

- Die quadratische Karte lässt sich nur am 2-px-Rand greifen; den oberen Streifen zum Griff machen. **K**
- `rotateMinimap` wird jedes Bild gelesen; im vorhandenen Hook merken. **K**
- Die Sammlung der Addon-Knöpfe erfasst nur `LibDBIcon*`; andere Knöpfe ergänzen und cachen. **K**
- Im Spiel prüfen, ob Forevers Warteschlangen-Anzeige mit ausgeblendet wird. **K**
- Felder nicht auf Blizzards Kartenrahmen schreiben (`defaultPoint`, `deckMovable`, `deckStyled`),
  sondern in eine eigene schwache Tabelle wie im Tooltip-Modul. **K**

---

## 9. Nav (`DeckUIForever_Nav`)

**Zustand:** stimmiges Design, alles läuft über die Zielverfolgung des Spiels. Schwach sind
Randfälle der Wegpunktliste und Daueraufwand pro Bild.

**Fehler und Risiken**

- `core.lua:325-327`: TomTom wird beim Laden der Datei gesucht, Nav lädt aber vor TomTom. Beide
  beanspruchen dann `/way`, der Gewinner ist Zufall, und der Hinweis „nimm /dway“ stimmt nicht.
  Erst bei PLAYER_LOGIN entscheiden. **[bestätigt an der Stelle]**
- `waypoints.lua:411-420`: Der erste Klick eines Doppelklicks zum Umbenennen macht den Wegpunkt
  jedes Mal zum Navigationsziel.
- `waypoints.lua:519-520`: Das „aktiv“-Flag wird nie gelöscht und die Liste gilt kontoweit. Jeder
  Login setzt den Wegpunkt neu und verdrängt eine verfolgte Quest – auch auf Twinks.
- `waypoints.lua:399-408`: Verschiebt sich die Liste beim Tippen, benennt Enter einen anderen
  Wegpunkt um.
- `waypoints.lua:490`: Bei offener Weltkarte kostet jeder der bis zu 50 Wegpunkte pro Bild zwei
  Kartenumrechnungen.

**Verbesserungen**

- `/way Elwynn Forest 45 67` und `/way 45.2,67.8` werden abgelehnt; Zonenname und Komma-Paare
  ergänzen. **M**
- Der Kompass ankert rund 32 Marken jedes Bild neu, auch im Stehen. Bei unveränderter Blickrichtung
  überspringen. **K**
- `GetQuestsOnMap` baut zehnmal pro Sekunde eine Tabelle; je Quest und Karte merken. **K**
- Minimap-Marken bewegen sich mit 5 Hz und ruckeln auf drehender Karte; Wegpunkte in anderen Zonen
  haben weder Entfernung noch Kompassmarke. **M**
- Tote Mists-Zweige, ein doppelter `FlatBox`, zwei Goldwerte. **K**

---

## 10. Tooltip (`DeckUIForever_Tooltip`)

**Zustand:** das strengste der drei Kartenmodule; keine Felder auf Tooltips, Zeilen nur aus
Nach-Aufrufen.

**Fehler und Risiken**

- `lines.lua:66`: `UnitIsUnit(unit, "player")` ungeschützt in einer Bedingung; dieselbe Datei
  schützt den Aufruf an anderer Stelle. Über einen Spieler im Kampf fahren könnte werfen. **[offen]**
- `lines.lua:119-121`: Nach der Inspektionsantwort baut das Addon den Tooltip selbst neu auf, was
  `core.lua` als eigene Regel verbietet – auch im Kampf und ohne zu prüfen, ob noch dieselbe
  Einheit gezeigt wird.
- `lines.lua:111-115`: Eine Antwort 0 wird 300 s gemerkt und als „Item level 0“ gezeigt. **[offen]**
- `extras.lua:71`: Die Quest-ID erscheint mit Umschalt auch bei ausgeschalteter ID-Option.
- `extras.lua:119`: Ohne ersten Beruf wird der zweite nie geprüft.
- `core.lua:181-186`: Die Skalierung gilt nicht für das angeheftete Tooltip (ItemRef) und dessen
  Vergleichstooltips.

**Verbesserungen**

- Tooltip am Mauszeiger als Modus neben dem festen Anker. **M**
- Option „Einheiten-Tooltips im Kampf ausblenden“. **K**
- Jedes Streifen über einen Spieler schickt eine Inspektion; etwa 0,5 s auf derselben Einheit
  verlangen. **K**
- „Knowledge“ und „Ensembles“ ausblenden, wo Forever die Inhalte nicht hat. **K**
- IDs auch auf Aura-, Reittier- und Quest-Tooltips. **K**

---

## 11. Quests (`DeckUIForever_Quests`)

**Zustand:** der Aktualisierungspfad ist bereits gebündelt (ein Neuzeichnen pro Bild, gepoolte
Zeilen). Schwach sind Mausbehandlung, die Platzierung des Questgegenstand-Knopfs und zu breite
Cache-Löschung.

**Fehler und Risiken**

- `core.lua:84-91`: Die Liste fängt Mausrad und Klicks über ihrem ganzen Rechteck ab. Im XIV-Look
  ohne Kasten kann man dort weder zoomen noch in die Welt klicken.
- `core.lua:691-693`: Der Questgegenstand-Knopf sitzt immer links der Liste. Am linken
  Bildschirmrand liegt er außerhalb des Bildes.
- `core.lua:404` mit `:771-775`: Eingeklappt während eines Timers läuft jede Sekunde ein volles
  Neuzeichnen, auch nach Ende des Timers.
- `quests.lua:232`, `world.lua:160`, `scenario.lua:217`: Jedes Questereignis verwirft alle elf
  Abschnitts-Caches statt nur der betroffenen.
- `core.lua:620-627`: Der Logindex des Gegenstandsknopfs friert im Kampf ein; nach einer
  Annahme mitten im Kampf zeigt er Abklingzeit und Ladungen einer anderen Quest.
- Hub `core.lua:646-649`: Nach dem Verschieben über `/df unlock` bleiben die Gegenstandsknöpfe am
  alten Ort bis zum nächsten Questereignis.
- `quests.lua:128-129`: Auto-Quest-Hinweise (Blizzards Popup) liest niemand mehr. **[offen]**

**Verbesserungen**

- Questmarken und Stufe im Titel ([Elite]/[Dungeon]/[Gruppe]) – heute nur über das standardmäßig
  ausgeschaltete Questing-Modul. In Classic wichtig. **K**
- Reicherer Tooltip: Ziele, Beschreibung, Fortschritt der Gruppe. **K**
- „Im Kampf / in Instanzen ausblenden“ und eine Hintergrund-Deckkraft. **K**
- Rückmeldung bei Abschluss: Ton oder kurzes Aufblitzen. **M**
- Klick auf die bereits verfolgte Quest hebt die Verfolgung auf. **K**
- Toter Retail-Code: `HuntEntry` und der „campaign“-Abschnitt (läuft die Liste doppelt durch),
  Delve-Zauber, ungenutztes `Requirement`, vermutlich die Abschnitte Sammlungen und Rezepte. **K**

---

## 12. Questing (`DeckUIForever_Questing`)

**Zustand:** sauber geschichtet und defensiv; kein Absturz ohne Questie. Die echten Risiken liegen
im Autopiloten und im zu häufigen Neuzeichnen des Kompendiums.

**Fehler und Risiken**

- **[bestätigt]** `dialog.lua`: kein Schutz vor wiederholbaren oder kostenpflichtigen Abgaben,
  siehe Abschnitt 1. Vorschlag: Wiederholbare nur auf Wunsch; aussetzen, wenn Geld oder
  Gegenstände verlangt werden.
- **[bestätigt an der Stelle]** `dialog.lua:103-111`: `autoGossip` wählt jede einzelne
  Gesprächsoption mit Sprechblasen-Symbol, auch in Instanzen. Eine einzelne „Ereignis starten“-
  oder „Bring mich hin“-Option löst beim ersten Ansprechen aus. In Instanzen abschalten, eine
  Auswahl je Gespräch.
- `dialog.lua:144-150, 176-181`: Geteilte und Eskortquests werden unabhängig von `autoAccept` und
  Ignorierliste bestätigt. Der Eskortstart eines Gruppenmitglieds bindet dich ohne Rückfrage.
- `record.lua:229-258`: Die Folgequest-Erkennung verknüpft jede Quest, die der NPC innerhalb von
  20 s nach einer Abgabe anbietet – auch solche, die er vorher schon anbot. Auf Twinks erscheinen
  sie ohne Questie als „gesperrt“. Das schreibt falsche Voraussetzungen in die kontoweiten Daten.
- `compendium.lua:839`: Jedes Ladeergebnis löst ein volles Neuzeichnen aus – bei laufendem Scan und
  offenem Fenster bis zu 40-mal pro Sekunde.
- `compendium.lua:763-768`: Quest annehmen oder abgeben bei offenem Fenster leert die gewählte
  Kette bis zum nächsten Öffnen.
- **[bestätigt]** `zone.lua:44`: `/questing track` hebt die Verfolgung aller anderen Quests auf,
  auch wenn „die anderen nicht mehr verfolgen“ aus ist.
- `scan.lua:73-77, 127-131`: Abgelaufene IDs werden nie wiederholt, und der Scan setzt in der
  nächsten Sitzung entgegen dem Tooltip nicht von selbst fort.
- `questdata.lua:610-622`: Ein noch nicht geladener Gegenstandsname wird als „fehlt“ gemerkt; es
  bleibt die ganze Sitzung bei „Item 1234“.
- `record.lua:312-317`: Eine Karte gilt als abgeerntet, bevor die Antwort da ist; eine leere erste
  Antwort heißt: diese Sitzung nie wieder. **[offen]**

**Verbesserungen**

- Questie nur noch für den Import: den Live-Pfad aus `questdata.lua` entfernen (mehrere fast
  doppelte Zweige, die Dauerabfrage alle 5 s). Kostet die ausführlichen Gründe von Questie. **G**
- `Data.Quest` baut pro Aufruf eine Tabelle – auch in Sortiervergleichen. Pro Aktualisierung merken. **M**
- Suche entprellen und indexieren; sie baut pro Tastendruck alles neu und nimmt „die ersten 300“
  in zufälliger Reihenfolge. **K**
- SavedVariables verschlanken (heute rund 2 MB): Zonenname an jedem NPC ist ableitbar, `x`
  spiegelt `p`. **M**
- Wegpunkt zum nächstgelegenen Questgeber statt zum Gebiet mit der kleinsten ID. **M**
- Waffenpfeile: Bei leerer Nebenhand gilt jede Einhandwaffe als Verbesserung, was auch die
  automatische Belohnung blockiert. **K**
- Pause vor der automatischen Belohnung noch einmal prüfen. **K**
- Auffangknoten im Baum für importierte Quests ohne bekannte Kategorie. **K**
- Toter Code: `Data.Trivial`, `Chains.Count`, `Chains.Before`, `Own.Line`. **K**

---

## 13. Week (`DeckUIForever_Week`)

**Zustand:** klein und robust. Die Hauptkosten sind rund 330 Zeilen Retail-Code, die nie laufen,
und Momentaufnahmen, die bei sehr häufigen Ereignissen alles neu bauen.

**Fehler und Risiken**

- **[bestätigt]** `view_forever.lua:108`: `snap.worldBosses` wird nie geschrieben, siehe Abschnitt 1.
- `core.lua:288-291`: Ein Sammler, der wirft, überschreibt seinen Teil still mit nichts. Ein
  Fehler beim Ausloggen speichert eine Aufnahme ohne Ruf. Den alten Teil behalten und einmal melden.
- `core.lua:337-341`: Währungs- und Rufereignisse lösen je eine volle Aufnahme aus – beim Farmen
  mit Ruf alle 2 s, auch im Kampf.
- `window.lua:587-591`: Beim Öffnen wird zweimal aufgefrischt; die Questliste wird pro
  Charakterzeile neu gebaut und sortiert.
- `collect_forever.lua:103-105`: Ein eingeklappter Ruf-Abschnitt lässt dessen Fraktionen aus der
  Aufnahme verschwinden. **[offen]**
- `core.lua:32-34`: Schlüssel ist Name-Realm; Umbenennen oder Neuerstellen hinterlässt Waisen.
- Gelernte tägliche Quests wachsen kontoweit, ohne Weg, eine zu vergessen.

**Verbesserungen**

- Retail-Reste löschen (rund 330 Zeilen in `core.lua` und `window.lua`: Vault, Keystone, Season,
  Crests, Delves, Prey …) samt ihrer Ereignisse. Sicher, solange `Plain`, `CharKey`, `Locks`,
  `Currency`, `Done`, `Weeklies` bleiben. **M**
- Veraltete Texte in `config.lua:15, 18` (Vault-Marke, „Shift-Klick auf den Minimap-Knopf“). **K**
- Spalten für Stufe und Gold, Realm in der Zeile; die Gegenstandsstufe sagt auf Classic-Stufen wenig. **K**
- Countdown bis zum täglichen Reset. **K**
- Sortieren per Klick auf den Spaltenkopf, Filter „Charaktere unter Stufe N ausblenden“. **M**

---

## 14. Was modulübergreifend auffällt

- **Doppelter Code für dasselbe Aussehen:** Slot-Look (Bars, Totemleiste, Pad), flacher Kasten
  (Loot, Würfeln, Schadensanzeige, Nav), Balken (drei Varianten in Orbs), `Secret`/`Ask`/`Plain`
  in fast jedem Modul. Ein kleiner gemeinsamer Satz im Hub (`D.SlotLook`, `D.FlatBox`, `D.Plain`)
  würde mehrere hundert Zeilen sparen und Abweichungen verhindern.
- **Toter Retail- und Mists-Code** in Week, Quests und Nav – zusammen grob 500 Zeilen.
- **Reset-Listen von Hand gepflegt** (`PAGE_RESET`): Drei Lücken in diesem Check. Aus den
  aufgezeichneten Seiteneinträgen ableiten.
- **Abfragen statt Ereignisse:** Gegnerliste, HoT-Fenster, Hauptmenü, Kompass arbeiten pro Tick
  oder Bild, auch wenn sich nichts ändert. Einzeln klein, auf dem Deck zusammen spürbar.
- **Alte globale Funktionen** in den Mists-Helfern (`GetMerchantItemInfo`, `GetCoinTextureString`):
  einmal mit `/df errors` beim Händler und am Briefkasten prüfen.

## 15. Vorgeschlagene Reihenfolge

1. Die acht Fehler aus Abschnitt 1 – alle klein, zusammen wenige Stunden.
2. Autopilot absichern (wiederholbare Abgaben, `autoGossip` in Instanzen, Eskorten).
3. Die übrigen kleinen Fehler mit sicherer Ursache: `restock.lua` (`IsVisible`),
   `debuffs.lua` (`attached`), Bars im Kampf, Spec unter Stufe 40, TomTom-Erkennung, Zonentext.
4. Im Spiel klären, was als **[offen]** markiert ist – vor allem Bankeinlagerung, alte globale
   Funktionen, die Maske der Heilvorhersage.
5. Leistung im HoT-Fenster (Änderungsflag, `UNIT_AURA`) – wichtig, sobald `hotRaid` genutzt wird.
6. Aufräumen: toter Code, gemeinsame Helfer im Hub, danach `panel.lua` und `hots.lua` teilen.
7. Neue Funktionen nach Wunsch – am meisten Wirkung pro Aufwand: Questmarken im Tracker,
   Heilvorhersage auf Gruppe und Schlachtzug, „Schrott verkaufen“, Würfelfenster aufs Deck,
   `/df help`.
