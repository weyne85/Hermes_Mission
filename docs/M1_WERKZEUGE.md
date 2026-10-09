# M1 — Werkzeuge klären (Ergebnis)

Geprüft in der Cloud-Umgebung (Linux, Python 3.13). Kein DCS verfügbar.

## Ergebnisse

| Punkt | Stand |
|-------|-------|
| pydcs | 0.15.0 installiert. Typen vorhanden: `A_10C_2` (`A-10C_2`), `FA_18C_hornet`, `F_16C_50`, `AH_64D_BLK_II`, `Mi_24P`. |
| Lua | `lua5.1` installiert (apt). |
| Bibliotheken | Von GitHub geladen (nicht im Repo): MIST 4.5.126, Moose (Commit-Stand 2026-02-06, ca. 11 MB), CTLD 1.6.1 plus `CTLD-i18n.lua`. |
| `.cmp`-Format | **Nicht verifiziert.** Keine offizielle Spezifikation gefunden. |

## Bibliotheken

- Quellen: `mrSkortch/MissionScriptingTools` (MIST), `FlightControl-Master/MOOSE_INCLUDE` (Moose), `ciribob/DCS-CTLD` (CTLD).
- Hinweis aus dem CTLD-Kopf: CTLD verlangt die **mitgelieferte MIST-Version**. Die MIST-Version aus dem CTLD-Repo und die von `mrSkortch` müssen vor dem Einbau abgeglichen werden.
- Nicht eingecheckt (Moose ca. 11 MB). `libs/` steht in `.gitignore`; ein Download-Skript fehlt noch.
- Ob diese Stände mit deinem DCS Stable laufen, zeigt erst dein Test.

## Gefundene Fehler im bestehenden Repo (inzwischen behoben, siehe unten)

Diese Fehler bestanden schon vor der Kampagnenarbeit:

1. **`tests/mock_test.lua` schlägt fehl** (15 Prüfungen, 8 Fehler, dann Absturz):
   - Zeile 262 lädt `scripts/80_ambient.lua`. Die Datei existiert nicht. `99_init.lua` ruft `TRN.Rat_Init` und `TRN.Convoys_Init`, die vermutlich dort stehen sollten. `00_config.lua` kennt dazu einen Abschnitt `AMBIENT`.
   - Der Test erwartet 6 registrierte Zonen, es sind 4.
   - Zeile 336 ruft `os.exit(1)`, obwohl `os` oben auf `nil` gesetzt wird. Das ergibt den Absturz. Richtig wäre `real_os.exit`.
   - README verspricht die Ausgabe `0 Fehler`. Das Skript gibt `failures` auf Englisch aus.
2. **`tools/build_miz.py` startet nicht:** `from types_extra import CH_47Fbl1, Mi_24P` schlägt fehl, weil `tools/types_extra.py` `Mi_24P` nicht definiert. pydcs 0.15.0 enthält `helicopters.Mi_24P`, der Import sollte also von dort kommen.
3. README und `mission/`, `libs/`: im README beschrieben, im Repo nicht vorhanden.

Der Mission-Build wurde deshalb noch nicht erfolgreich ausgeführt. `check_names()` ist ungeprüft.

## `.cmp`-Format (offen)

Aus Community-Quellen (nicht offiziell, nicht verifiziert):
- Fortschritt liegt im `logbook.lua` im Ordner `Saved Games\DCS\MissionEditor`.
- Das Ergebnis einer Mission kommt aus den Mission Goals (Punktzahl). Üblich: unter 50 Wiederholung, über 50 nächste Mission.
- Die Kampagne besteht aus Stufen (Stages) mit Missionsdatei.

Zur Verifikation nötig: eine mitgelieferte DCS-Kampagne (Ordner `Init` / Kampagnen-Dateien) oder ein Export aus dem DCS Campaign Builder. Ohne diese schreibe ich `build_campaign.py` nicht.

## Nächste Schritte

1. `.cmp`-Beispiel von dir erhalten, dann Format festlegen (Punkte 1 und 2 aus dem ersten Entwurf sind erledigt, siehe unten).

## Behoben (nach M1)

- `80_ambient.lua` neu geschrieben (RAT-Verkehr, Konvois), `tests/ambient_test.lua` ergänzt.
- `build_miz.py`: Import von `Mi_24P` entfernt; Konvoi-Vorlagen `TRN_CONVOY_*` und Zonenpositionen `conv_*` ergänzt; `80_ambient.lua` in der Ladereihenfolge. Der Build läuft durch (Namensprüfung 44 von 44).
- `plot_map.py`: ungültiger Marker `=` durch `+` ersetzt, Kategorien `zone_conv`, `zone_ctld`, `zone_csar` ergänzt.
- `briefing.py`: Routenpunkt `AND` der Hubschrauber heißt jetzt `AND ZONE` wie in der Punktetabelle. Der Name `AND` stammt vermutlich aus einem Tippfehler für `AG`; er wurde nicht umbenannt, weil das README ihn so führt.
- `mock_test.lua` neu geschrieben: lädt die echten Skripte und ersetzt nur DCS/Moose/MIST. 61 Prüfungen, 0 Fehler.
- Fehler in den Zonenmodulen, die der neue Test aufgedeckt hat:
  - `20_strike.lua`: `targetType` war vor der Definition aufgerufen, die Strike-Zone brach beim Start ab.
  - `40_cc.lua`: `startable = false` entfernt (Combined hatte keine Start-Einträge im Menü); der Konvoi-Spawn nutzt `convoyPool`, das in der Config fehlt, und wird jetzt übersprungen; SEAD-Abschluss prüfte `Unit.getByName` mit einem Gruppennamen und trat nie ein.
  - `00_config.lua`: Ansagen `cc_sead_complete` und `cc_strike_complete` fehlten.
