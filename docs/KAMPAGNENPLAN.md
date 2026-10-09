# Kampagnenplan — "Operation Iron Arrow" (DCS World, Caucasus)

Status: **Entwurf zur Freigabe**. Alle Koordinaten sind Vorschläge und müssen im Mission Editor bestätigt werden.

## 1. Eckdaten (aus dem Interview)

| Punkt | Festlegung |
|-------|-----------|
| Karte / Version | Caucasus, DCS Stable |
| Module | F/A-18C, F-16C, A-10C II (Jet-Pfad); AH-64D, Mi-24P (Heli-Pfad) |
| Modus | Solo und Koop |
| Aufbau | Linear, zwei Pfade mit 3 gemeinsamen Schlüsselmissionen; Misserfolg = Wiederholung |
| Gegner | SAM/AAA, Bodentruppen und Konvois (keine Luftgegner, keine Marine) |
| Realismus | Mittel; feste Schwierigkeit, über die Kampagne ansteigend |
| Bedingungen | Heißer Start, Tag, klares Wetter (Sommer) |
| Sprache | Deutsch (Briefing, Ansagen, Kneeboards) |
| Technik | `.miz` + `.cmp`, gebaut mit pydcs; Moose, MIST, CTLD, CSAR |
| Inhalte | Briefings mit Karten/Bildern, Kneeboards je Flugzeug, Tutorials |

### Offener Punkt (bitte bestätigen)
"Je 4–5 Missionen, 3 gemeinsam, ca. 8–9 gesamt" lässt zwei Lesarten zu. Dieser Plan nimmt an:
**Jeder Spieler fliegt 8 Missionen** (5 pfadspezifische + 3 gemeinsame). Zu bauen sind damit **13 Missionen** (5 Jet + 5 Heli + 3 gemeinsam) plus 2 Tutorials.
Alternative: 3 + 3 + 3 = 9 Missionen, jeder Pfad fliegt 6. Weniger Aufwand, kürzere Kampagne.

## 2. Story (ernst, militärisch-realistisch)

- **Ausgangslage:** Eine rote Kampfgruppe ("Southern Task Force") hat sich im Westen Georgiens eingenistet. Kern ist eine integrierte Flugabwehr (SA-2/3/6/11, SA-8/15, ZSU-23) mit gepanzertem Nachschub über Straßenachsen. Die Lufthoheit der Koalition (CJTF Caucasus) über dem Ostteil der Karte ist verloren.
- **Auftrag:** Phasenweise Wiedergewinnung des Luftraums: Luftabwehr ausschalten, Nachschub unterbinden, Bodentruppen zerschlagen, Brückenkopf sichern.
- **Phasen:**
  1. **Erkundung und Durchbruch** (S1, J1/H1, J2/H2): Lage klären, erste Schläge.
  2. **Nachschub trennen** (J3/H3, S2): Wendepunkt. Ein Verlustereignis (abgeschossene Besatzung) verändert die Prioritäten.
  3. **Zerschlagung** (J4/H4, J5/H5): Gegner ist zur Verteidigung gezwungen.
  4. **Entscheidung** (S3): Gemeinsamer Großeinsatz aller Module.
- **Ton:** Nachrichtenlage und Briefings im Stil echter Einsatzbefehle (Lage, Auftrag, Durchführung, Bedrohung, Funk, Notverfahren). Keine übertriebene Dramatik.

## 3. Kampagnenstruktur

```
S1 (alle) ──► Jet: J1 → J2 → J3 ─┐                 ┌─► J4 → J5 ─┐
                                  ├─► S2 (alle) ───┤            ├─► S3 (alle)
              Heli: H1 → H2 → H3 ─┘                 └─► H4 → H5 ─┘
```

- Linear je Pfad; Erfolg schaltet die nächste Mission frei, Misserfolg wiederholt sie.
- Schlüsselmissionen S1/S2/S3 sind für alle fünf Typen spielbar (Koop-Slots gemischt).
- Koop und Solo nutzen dieselben Missionen. Slots sind mit KI-Flügelmännern bzw. zweiten Spielern besetzbar.

## 4. Missionsliste

Schwierigkeit: 1 = leicht, 10 = Finale. Gegnerstärke und Anzahl der Ziele steigen; Wetter bleibt gleich.

| Nr. | Name (Arbeitstitel) | Pfad | Typen | Aufgabe | Bedrohung | Stufe |
|-----|--------------------|------|-------|---------|-----------|-------|
| T-J | Tutorial Jets | Jet | F/A-18C, F-16C, A-10C II | Waffeneinsatz, Zielzuweisung, SEAD-Grundlagen | gering, Range-Umgebung | – |
| T-H | Tutorial Helis | Heli | AH-64D, Mi-24P | Schweben, Raketen/Kanone, Sensor | gering | – |
| S1 | Auftakt | alle | alle | Erste Schläge: Jets Vorposten/Radar, Helis Kolonnenspitze (baut auf Zone "Combined" auf) | 1 SAM (SA-2), leichte AAA | 1 |
| J1 | Radarblindheit | Jet | F/A-18C, F-16C (A-10 als Eskorte-CAS möglich) | SEAD/DEAD gegen SA-2/SA-3 | SA-2, SA-3 | 2 |
| J2 | Nachschubbrücke | Jet | F/A-18C, F-16C, A-10C II | Strike: Brücke/Depot | AAA, ZSU-23 | 3 |
| J3 | Panzerjäger | Jet | A-10C II (Lead), F-16C, F/A-18C | CAS gegen Kolonne auf Straße | ZSU-23, SA-8 (selten) | 4 |
| H1 | Tal der Kolonne | Heli | AH-64D, Mi-24P | Kolonne im Tal bekämpfen (Zone "Air-to-Ground") | ZSU-23 | 2 |
| H2 | Frontlogistik | Heli | Mi-24P (Transport-Variante in CTLD), AH-64D (Eskorte) | CTLD: Truppen/Fracht zum Vorposten | leichte AAA | 3 |
| H3 | Falke down | Heli | AH-64D, Mi-24P | CSAR: abgeschossene Besatzung bergen | mobile Flak | 4 |
| S2 | Wendepunkt | alle | alle | Durchbruch an Nachschubknoten (SEAD + Strike + Kolonne) | SA-6/SA-11, ZSU-23 | 5 |
| J4 | Eiserner Vorhang | Jet | F/A-18C, F-16C | DEAD gegen integriertes SAM-Netz | SA-6, SA-11, SA-15 | 7 |
| J5 | Hammerschlag | Jet | alle drei | Strike auf Kommandoknoten, A-10 räumt Flak | SA-8, SA-15, ZSU-23 | 8 |
| H4 | Bergbastion | Heli | AH-64D, Mi-24P | Flak/AAA in Berglage unterdrücken | ZSU-23, SA-8 | 7 |
| H5 | Brückenkopf | Heli | AH-64D, Mi-24P | CTLD-Verteidigung des Brückenkopfs gegen Gegenangriff | Kolonnen, ZSU-23 | 8 |
| S3 | Entscheidung | alle | alle | Großeinsatz: SEAD, Strike, Kolonne, Brückenkopf | alle Typen aus Kap. 6 | 10 |

Hinweis: Positionen und Pfadzuordnung der A-10C II (J1–J3, J5) folgen der Entscheidung "Jet-Pfad inkl. A-10C II". CAS-Rolle der A-10C II ist Schwerpunkt, SEAD bleibt F/A-18C und F-16C vorbehalten.

## 5. Realismus (Stufe "mittel")

- **Briefings:** Fünf-Absatz-Befehl, Bedrohungslage mit SAM-Typen und Standorten, Funk-/Rufzeichentabelle, Notverfahren (Ausstieg, CSAR-Frequenz).
- **Gegner:** Realistische Einsatzkonfigurationen (SAM-Batterie plus Radar plus Flak), Kolonnen mit gemischten Fahrzeugen. Keine übermäßige Verstärkung für Schwierigkeit.
- **Aktive Hilfen:** F10-Menü (bestehendes `03_menu.lua`), Bedrohungsmeldungen, Rundenende/Timeout.
- **Bewusst vereinfacht:** Kein Wetterwechsel, keine Luftgegner, keine Navigation ohne GPS.

## 6. Gegnerkatalog (nur SAM/AAA, Boden)

Basis sind die vorhandenen Templates in `scripts/00_config.lua` (SA-2, SA-3, SA-6, SA-11, SA-8, SA-15, ZSU-23). Neue Templates (z. B. SA-3-Radarvariante, schwere Kolonnen, Nachschubfahrzeuge) werden pro Mission in `00_config.lua` ergänzt und im Editor mit exakt gleichem Namen angelegt.

## 7. Koordinatenvorschläge (zur Bestätigung)

Alle Angaben sind Referenzräume, keine Koordinaten. Exakte Zonenmitten lege ich nach deiner Freigabe fest. Du prüfst sie im Mission Editor (Gelände, Straßenverlauf, Entfernungen).

| Zone | Vorschlag | Hinweis |
|------|-----------|---------|
| Startbasen Jets | Kobuleti | wie im Repo |
| Startbasen Helis | Senaki-Kolkhi | wie im Repo |
| SAM-Stellung (J1, S1) | ca. 30 NM östlich von Kutaisi | wie bestehende Zone 1; offenes Gelände |
| Strike-Ziel (J2, J5) | zwischen Senaki und Kutaisi | wie bestehende Zone 2 |
| Kolonnenstraße (H1, J3) | Straße im Tal, ≥ 8 km Strecke | Start/Ziel auf derselben Straße |
| Berglage (H4) | Vorberge nördlich von Zugdidi | Zugang aus Südwesten, Hubschrauber-tauglich |
| Brückenkopf (H5, S3) | Raum Poti/Samtredia | Küstennähe, Straßenknoten |

Wo die Karte nicht passt (Gebirge, Wasser, keine Straße), verschiebe ich die Zone, die Zonennamen bleiben gleich.

## 8. Technische Architektur

Bestehender Code wird weiterverwendet, nicht ersetzt:

| Bestandteil | Zweck | Änderung |
|-------------|-------|----------|
| `scripts/00_config.lua` | Namen, Stufen, Zeiten | Mission-Abschnitte für neue Missionen |
| `scripts/01_core.lua` | Zonen-Manager, Sessions | unverändert, Erweiterung über `TRN.RegisterZone` |
| `scripts/10_sead.lua` … `40_cc.lua` | Zonenmodule | Wiederverwendung in S1, J1, J2, H1, S2, S3 |
| neu `scripts/50_ctld.lua` | CTLD-Einbindung (H2, H5) | Anbindung an Zonen/Ziele |
| neu `scripts/60_csar.lua` | CSAR-Einbindung (H3, ggf. S2) | Besatzung, Rettungsfunk |
| neu `scripts/70_campaign.lua` | Siegbedingung, Fortschrittsflags pro Mission | Fortschritt für die Kampagnenverkettung |
| `tools/build_miz.py` | Mission bauen | je Mission parametrierbar (Zonen, Slots, Gegner) |
| neu `tools/build_campaign.py` | `.cmp` aus Missionsliste erzeugen | Verkettung gemäß Abschnitt 3 |
| `tools/briefing.py` | Briefings, Kneeboards | deutsche Textbausteine pro Mission |
| `tests/mock_test.lua` | Logiktest ohne DCS | zusätzliche Fälle für neue Module |

Dateistruktur (Ziel):

```
campaign/
  missions/       ← je Mission eine Definition (Python/Lua)
  briefing/       ← Texte, Bilder, Kneeboard-Seiten
  build/          ← generierte .miz und .cmp (nicht eingecheckt)
libs/             ← mist.lua, Moose.lua, CTLD*.lua (nicht eingecheckt, siehe Risiken)
```

## 9. Risiken und Annahmen

- **Bibliotheken:** `mist.lua`, `Moose.lua` und `CTLD.lua` liegen nicht im Repo. Beschaffung von GitHub ist nur eingeschränkt möglich (Zugriff begrenzt). Ob die neueste Version mit DCS Stable läuft, zeigt erst dein Test.
- **Nicht testbar hier:** Kein DCS, kein `lua5.1`, und pydcs ist in dieser Umgebung nicht installiert. Ich kann hier weder bauen noch den Mock-Test ausführen. Ich installiere pydcs und Lua, soweit verfügbar, und melde, was funktioniert.
- **A-10C II in pydcs:** Ob die installierte pydcs-Version (README nennt 0.15) die A-10C II kennt, ist ungeprüft. Falls nicht, ist ein Upgrade oder eine Typ-Erweiterung in `tools/types_extra.py` nötig.
- **`.cmp`-Format:** Das genaue Format der Kampagnendatei und die Art, wie eine Mission "Sieg" meldet, muss ich vor dem Bau gegen DCS-Dokumentation oder eine Beispielkampagne prüfen. Bis dahin ist `build_campaign.py` nur ein Entwurf.
- **Koop-Balance:** Slot-Zahl je Mission (2–4 Spieler) wird nach deinem Test angepasst.
- **Praxistest:** Du testest in DCS und gibst Feedback. Zonen, Straßen und Spawn-Positionen sind die häufigsten Fehlerquellen.

## 10. Meilensteine

1. **M0 – Plan freigeben** (dieses Dokument).
2. **M1 – Werkzeuge:** pydcs und Libs klären, `.cmp`-Format verifizieren, `build_campaign.py` als Gerüst.
3. **M2 – Prototyp:** T-J, T-H und S1 bauen und von dir testen lassen.
4. **M3 – Phase 1:** J1/J2/H1/H2.
5. **M4 – Wendepunkt:** J3/H3 und S2.
6. **M5 – Phase 3:** J4/J5/H4/H5.
7. **M6 – Finale:** S3, Balance, Feinschliff, Kneeboards und Karten.

Nach jedem Meilenstein: Test durch dich, Korrektur, dann nächster Schritt.
