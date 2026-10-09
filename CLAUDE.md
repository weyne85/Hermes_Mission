# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projekt

Trainingsmission "Caucasus Strike" für DCS World (Karte Caucasus, BLUE vs RED): vier Zonen (SEAD/DEAD, Strike, Air-to-Ground, Combined). Lua-Skripte laufen in der DCS-Mission-Sandbox (Moose + MIST + CTLD); Python-Tools (pydcs) bauen die .miz offline. Code-Kommentare und Log-/Testausgaben sind überwiegend Deutsch, Spieler-Ansagen Englisch.

## Befehle

- Logiktest ohne DCS (aus dem Repo-Root): `lua5.1 tests/mock_test.lua` → erwartet `0 Fehler`. Einzelne Tests gibt es nicht; die Datei ist ein einziges Skript mit `check(cond, label)`.
- Ambient-Test (RAT, Konvois; läuft ohne DCS): `lua5.1 tests/ambient_test.lua` → erwartet `0 failures`.
- Mission bauen + Namensprüfung: `python3 tools/build_miz.py --sounds-dir /path/to/MOOSE_SOUND` (Exit 1, wenn ein `TRN_`-Name aus `00_config.lua` in der Mission fehlt).
- Karten und `objekte.md` neu erzeugen: `python3 tools/plot_map.py`
- Abhängigkeiten: `pip install pydcs matplotlib adjustText mgrs pillow`; `lua5.1` muss installiert sein.
- Kein Linter und kein Build-System konfiguriert.
- `libs/` (mist.lua, Moose.lua, CTLD) und `mission/` (gebaute .miz, Karten, Kneeboards) werden im README erwähnt, sind aber nicht eingecheckt.

## Architektur

- **Ladereihenfolge ist Vertrag**: Der Mission-Editor-Trigger (MISSION START, DO SCRIPT FILE) lädt strikt: mist → Moose → CTLD-i18n → CTLD → `00_config` → `01_core` → `02_audio` → `03_menu` → `10_sead` → `20_strike` → `30_ag` → `40_cc` → `80_ambient` → `99_init`. Alle teilen den globalen Namespace `TRN`. `99_init.lua` muss zuletzt laufen: prüft Abhängigkeiten, seedet den Zufall (in der DCS-Sandbox fehlen `os` und teils `math.randomseed`) und initialisiert RAT/Konvois.
- **`00_config.lua` ist die einzige Quelle der Wahrheit** (`TRN.CFG`): alle `TRN_*`-Namen (Triggerzonen, Late-Activation-Gruppen, Statics), Frequenzen, Schwierigkeitsstufen (EASY/MEDIUM/HARD), Timeouts, Ansagetexte. Namen sind case-sensitiv; ein Tippfehler überspringt eine Zone oder spawnt das falsche Template.
- **`01_core.lua`**: Logging, Geometrie, Spielergruppen, Spawn-Helfer und Zonen-Manager. Jedes Zonenmodul (`10_sead`, `20_strike`, `30_ag`, `40_cc`) registriert sich über `TRN.RegisterZone(def)`; `Zone:Start/Stop/_tick/_newRound` und `Session` (Tracking, Cleanup, Ansagen) steuern den Rundenablauf (Timeout, Auto-Restart nach `RESTART_DELAY`).
- **`80_ambient.lua`** liefert `TRN.Rat_Init` (Moose RAT, KI-Transporter) und `TRN.Convoys_Init` (zufällige BLUE-/RED-Konvois aus `CFG.AMBIENT`); beides ruft `99_init.lua` auf. Es registriert keine Zone. Die Vorlagen `TRN_CONVOY_*` und Zonen `TRN_CONV_*` erzeugt `build_miz.py`.
- **`02_audio.lua`** (Ansage-Queue, Text; Moose-Range/Airboss-Sounds optional) und **`03_menu.lua`** (F10-Menü je Spielergruppe) hängen am Zonen-Manager.
- **`tools/`**: `build_miz.py` (pydcs → .miz, Trigger, Slots, `check_names()`), `briefing.py` (Briefing, Flugpläne, Kneeboards), `plot_map.py` (Karten), `types_extra.py` (Typ-Platzhalter, von Build- und Plot-Tool gemeinsam genutzt). Koordinaten im Build-Tool sind Platzhalter und müssen im Mission-Editor geprüft werden.
- **Namens-Synchronität**: Namen in `00_config.lua`, im Mission-Editor und in `build_miz.py` müssen exakt übereinstimmen; `check_names()` ist das Prüf-Gate. Neue Zone oder neues Template ⇒ Config, `build_miz.py` und die README-Checkliste anpassen.
- **`tests/mock_test.lua`** lädt die echten Skripte in Missionsreihenfolge und ersetzt nur DCS/Moose/MIST durch Attrappen (eigener Timer-Scheduler `advance(seconds)`, Welt-Modell) und prüft Menü, Sessions, Ansagen, Auto-Restart und Cleanup – nicht das Spielverhalten. `os` und `math.randomseed` werden bewusst auf `nil` gesetzt, um die DCS-Sandbox nachzubilden: im Skriptcode kein `os.*` verwenden.
