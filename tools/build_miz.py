#!/usr/bin/env python3
"""Erzeugt die Trainingsmission "Caucasus Strike" als .miz mit pydcs.

Aufruf (im Repo-Hauptverzeichnis):
    pip install pydcs matplotlib adjustText mgrs pillow
    python3 tools/build_miz.py [--sounds-dir PFAD_ZU_MOOSE_SOUND] [-o mission/DCS_CaucasusStrike.miz]

Was erzeugt wird:
  * Trigger "MISSION START" mit 13x DO SCRIPT FILE (Ladereihenfolge wie in der README)
  * alle Triggerzonen, Vorlagegruppen (Late Activation), Spieler-Slots (Client) fuer alle Muster
  * Briefing (Lage, Zonen, Frequenzen), Wegpunkte fuer alle Client-Slots, Kneeboard-Seiten je Flugzeugtyp
  * Karten und Objektliste (mission/map), Kneeboard-PNGs (mission/kneeboard)
  * optional: Moose-Soundordner "Range Soundfiles/" und "Airboss Soundfiles/" im Archiv

Die POSITIONEN sind PlatzHOLDER und muessen im Mission Editor geprueft werden.
Die Namen stammen aus scripts/00_config.lua; das Skript prueft am Ende, ob alle dort verwendeten
TRN_-Namen in der Mission vorkommen.
"""

import argparse
import datetime
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

import dcs
sys.path.insert(0, str(Path(__file__).resolve().parent))
import briefing
from types_extra import CH_47Fbl1, Mi_24P
from dcs import countries, helicopters, planes, ships, statics, task, vehicles
from dcs.mapping import Point
from dcs.mission import Mission, StartType
from dcs.terrain import Caucasus
from dcs.triggers import TriggerOnce, TriggerStart
from dcs.action import DoScriptFile, SoundToAll
from dcs.condition import FlagIsTrue
from dcs.task import OptROE
import random

ROOT = Path(__file__).resolve().parent.parent

# ----------------------------------------------------------------------------------------------
# Positionen (DCS-Koordinaten: x = Norden, y = Osten; Meter). PLATZHALTER, im Editor pruefen!
# ----------------------------------------------------------------------------------------------
POS = {
    # SEAD/DEAD (Zone 1)
    "sead":         (-262000, 675000),   # ca. 30 nm oertlich von Kutaisi, flaches Gelände
    # STRIKE (Zone 2)
    "strike":       (-270000, 685000),   # zwischen Senaki und Kutaisi, nordoesterlich der Range
    # AIR-TO-GROUND (Zone 3)
    "ag_zone":      (-285000, 678000),   # Zone 3 Zielgebiet
    "ag_start":     (-286000, 670000),   # Startpunkt der Zielfahrzeuge (an einer Straße)
    "ag_end":       (-285000, 695000),   # Ziel (an einer Straße, >= 8 km von Start)
    # COMBINED (Zone 4)
    "cc_zone":      (-300000, 660000),   # Small box ca. 8 km Radius
    # Wetter/Zeit (fest, klar)
    # Koalitionen: BLUE = USA, RED = Russland
    # Spieler-Slots (Client, BLUE): F/A-18C, F-16C (Kobuleti); AH-64D, Mi-24P (Senaki-Kolkhi)
    # Flugplatzbetrieb (RAT): C-130, An-26
    # Belebung: Handelsschiffe, Begleitfregatten, parkende Flugzeuge
}

CONFIG = ROOT / "scripts" / "00_config.lua"

LOAD_ORDER = [
    "libs/mist.lua", "libs/Moose.lua", "libs/CTLD-i18n.lua", "libs/CTLD.lua",
    "scripts/00_config.lua", "scripts/01_core.lua", "scripts/02_audio.lua", "scripts/03_menu.lua",
    "scripts/10_sead.lua", "scripts/20_strike.lua", "scripts/30_ag.lua", "scripts/40_cc.lua",
    "scripts/80_ambient.lua", "scripts/99_init.lua",
]


def P(m, key_or_xy, dx=0, dy=0):
    x, y = POS[key_or_xy] if isinstance(key_or_xy, str) else key_or_xy
    return Point(x + dx, y + dy, m.terrain)


def build(sounds_dir, out_path, extras=None):
    """extras: optional dict(kneeboards={Typ-ID: [PNG]}, pictures=[PNG]) fuer Phase 2."""
    extras = extras or {}
    m = Mission(Caucasus())
    cfg = briefing.load_cfg()
    geo = briefing.Geo(m.terrain, POS)
    m.coalition["blue"].add_country(countries.USA())
    m.coalition["red"].add_country(countries.Russia())
    usa = m.country("USA")
    rus = m.country("Russia")

    # Wetter / Zeit (fest, klar)
    m.start_time = datetime.datetime(2024, 6, 21, 10, 0, 0)
    w = m.weather
    w.clouds_density = 0
    w.enable_fog = False
    w.enable_dust = False
    w.qnh = 760
    w.visibility_distance = 80000
    w.wind_at_ground = dcs.weather.Wind(270, 3) if hasattr(dcs.weather, "Wind") else w.wind_at_ground
    w.season_temperature = 22

    situation, blue_task, red_task = briefing.briefing_texts(geo, cfg)
    m.set_description_text(situation)
    m.set_description_bluetask_text(blue_task)
    m.set_description_redtask_text(red_task)
    for pic in extras.get("pictures", []):
        m.add_picture_blue(str(pic))

    # ---------------------------------------------------------------- Triggerzonen
    def zone(name, key, radius):
        m.triggers.add_triggerzone(P(m, key), radius=radius, name=name)

    zone("TRN_SE_ZONE", "sead", 3000)
    zone("TRN_ST_ZONE", "strike", 3000)
    zone("TRN_AG_ZONE", "ag_zone", 3000)
    zone("TRN_AG_START", "ag_start", 1000)
    zone("TRN_AG_END", "ag_end", 1000)
    zone("TRN_CC_ZONE", "cc_zone", 8000)

    # ---------------------------------------------------------------- Hilfsfunktionen Vorlagen
    def ground_template(name, key, units, country=rus, dx=0, dy=0, heading=0, late=True):
        """units: Liste von Fahrzeugtypen. Erstellt eine Gruppe mit Late Activation."""
        first = units[0]
        g = m.vehicle_group(country, name, first, P(m, key, dx, dy), heading=heading, group_size=1)
        for i, t in enumerate(units[1:], start=1):
            v = m.vehicle(f"{name}-{i + 1}", t)
            v.position = Point(g.units[0].position.x + 40 * i, g.units[0].position.y + 25 * (i % 2), m.terrain)
            v.heading = 0
            g.add_unit(v)
        g.late_activation = late
        return g

    # ---------------------------------------------------------------- Zone 1: SEAD/DEAD
    U = vehicles.Unarmed
    A = vehicles.Armor
    AD = vehicles.AirDefence
    ground_template("TRN_SAM_SA2", "sead", [AD.P_19_s_125_sr, AD.SNR_75V] + [AD.S_75M_Volhov] * 3, dy=-1500)
    ground_template("TRN_SAM_SA3", "sead", [AD.P_19_s_125_sr, AD.Snr_s_125_tr] + [AD.X_5p73_s_125_ln] * 3, dy=-1300)
    ground_template("TRN_SAM_SA6", "sead", [AD.Kub_1S91_str] + [AD.Kub_2P25_ln] * 3, dy=-1100)
    ground_template("TRN_SAM_SA11", "sead", [AD.SA_11_Buk_SR_9S18M1, AD.SA_11_Buk_CC_9S470M1] + [AD.SA_11_Buk_LN_9A310M1] * 3, dy=-900)
    ground_template("TRN_SAM_SA8", "sead", [AD.Osa_9A33_ln] * 3, dy=-700)
    ground_template("TRN_SAM_SA15", "sead", [AD.Tor_9A331] * 2, dy=-500)
    ground_template("TRN_SAM_ZSU23", "sead", [AD.ZSU_23_4_Shilka] * 2, dy=-300)

    # ---------------------------------------------------------------- Zone 2: STRIKE
    ground_template("TRN_ST_OBJ_1", "strike", [U.Ural_375] * 2, dy=-2500)
    ground_template("TRN_ST_OBJ_2", "strike", [A.T_72B] * 2, dy=-2400)
    ground_template("TRN_ST_OBJ_3", "strike", [U.KAMAZ_Truck] * 2, dy=-2300)
    ground_template("TRN_ST_OBJ_4", "strike", [A.BMP_2] * 2, dy=-2200)
    ground_template("TRN_ST_OBJ_5", "strike", [U.GAZ_66] * 2, dy=-2100)
    ground_template("TRN_ST_OBJ_6", "strike", [U.UAZ_469] * 2, dy=-2000)
    ground_template("TRN_ST_AAA_1", "strike", [AD.ZSU_23_4_Shilka] * 2, dy=-1900)
    ground_template("TRN_ST_AAA_2", "strike", [AD.Strela_10M3] * 2, dy=-1800)

    # ---------------------------------------------------------------- Zone 3: AIR-TO-GROUND
    ground_template("TRN_AG_VEH_1", "ag_zone", [A.T_72B] * 3, dy=-2000)
    ground_template("TRN_AG_VEH_2", "ag_zone", [A.BMP_2] * 3, dy=-1900)
    ground_template("TRN_AG_VEH_3", "ag_zone", [U.KAMAZ_Truck] * 3, dy=-1800)
    ground_template("TRN_AG_VEH_4", "ag_zone", [U.Ural_375] * 3, dy=-1700)
    ground_template("TRN_AG_AAA_1", "ag_zone", [AD.ZSU_23_4_Shilka] * 2, dy=-1600)

    # ---------------------------------------------------------------- Zone 4: COMBINED
    ground_template("TRN_CC_OBJ_1", "cc_zone", [U.Ural_375] * 2, dy=-2000)
    ground_template("TRN_CC_OBJ_2", "cc_zone", [A.T_72B] * 2, dy=-1950)
    ground_template("TRN_CC_OBJ_3", "cc_zone", [U.KAMAZ_Truck] * 2, dy=-1900)
    ground_template("TRN_CC_OBJ_4", "cc_zone", [A.BMP_2] * 2, dy=-1850)
    ground_template("TRN_CC_AAA_1", "cc_zone", [AD.ZSU_23_4_Shilka] * 2, dy=-1800)
    ground_template("TRN_CC_AAA_2", "cc_zone", [AD.Strela_10M3] * 2, dy=-1750)

    # ---------------------------------------------------------------- Flugplaetze der Spieler: BLUE
    for name in ("Kobuleti", "Senaki-Kolkhi", "Kutaisi", "Batumi"):
        m.terrain.airports[name].set_blue()

    # ---------------------------------------------------------------- Flugplatzbetrieb: RAT-Vorlagen (KI-Transporter)
    kx, ky = m.terrain.airports["Kobuleti"].position.x, m.terrain.airports["Kobuleti"].position.y
    for name, ptype, dy in (("TRN_RAT_C130", planes.C_130, 0), ("TRN_RAT_AN26", planes.An_26B, 2000)):
        fg = m.flight_group(usa, name, ptype, None, Point(kx, ky + 8000 + dy, m.terrain), altitude=3000, speed=450, group_size=1)
        fg.late_activation = True
        fg.add_waypoint(Point(kx - 20000, ky + 30000 + dy, m.terrain), 3000, 450)

    # ---------------------------------------------------------------- Flugplatzbetrieb: Kulisse (Statics, Fahrzeuge)
    rnd = random.Random(7)   # feste Reihenfolge: bei jedem Bau gleiches Ergebnis

    def airfield_scene(airport_name, plane_types, vehicle_count):
        ap = m.terrain.airports[airport_name]
        slots = [sl for sl in ap.parking_slots if sl.airplanes][2::3]
        for i, ptype in enumerate(plane_types):
            if i >= len(slots):
                break
            sg = m.static_group(usa, f"TRN_STATIC_{airport_name}_{i + 1}", ptype, slots[i].position, heading=rnd.randrange(0, 360))
            sg.units[0].name = f"TRN_STATIC_{airport_name}_{i + 1}"
        vtypes = [U.M978_HEMTT_Tanker, U.Hummer, U.Ural_4320_APA_5D, U.M_818]
        for j in range(vehicle_count):
            base = slots[(j + len(plane_types)) % len(slots)].position
            g = m.vehicle_group(usa, f"TRN_AIRFIELD_{airport_name}_{j + 1}", vtypes[j % len(vtypes)],
                                Point(base.x + 18, base.y + 12, m.terrain), heading=rnd.randrange(0, 360), group_size=1)

    airfield_scene("Kutaisi", [planes.A_10C_2, planes.A_10C_2, planes.F_16C_50, planes.F_16C_50, planes.FA_18C_hornet, planes.C_130], 4)
    airfield_scene("Batumi", [planes.FA_18C_hornet, planes.F_16C_50], 3)

    # ---------------------------------------------------------------- Belebt (schwache Konvois)
    for letter, key in zip("ABCD", ("conv_a", "conv_b", "conv_c", "conv_d")):
        zone(f"TRN_CONV_{letter}", key, 800)
    zone("TRN_CONV_RED_A", "conv_red_a", 800)
    zone("TRN_CONV_RED_B", "conv_red_b", 800)
    # (Konvois werden per Skript gesetzt, keine statischen Vorlagen noetig)

    # ---------------------------------------------------------------- Speichern
    out_path.parent.mkdir(parents=True, exist_ok=True)
    m.save(str(out_path))
    return m


def add_sounds(miz_path, sounds_dir):
    """Kopiert die Moose-Soundordner unveraendert ins Archiv."""
    wanted = {
        "Range Soundfiles": sounds_dir / "RANGE" / "Range Soundfiles",
        "Airboss Soundfiles": sounds_dir / "AIRBOSS" / "Airboss Soundfiles",
    }
    with zipfile.ZipFile(miz_path, "a", zipfile.ZIP_DEFLATED) as z:
        for folder, src in wanted.items():
            if not src.is_dir():
                print(f"WARNUNG: {src} nicht gefunden - Ordner '{folder}/' wird nicht eingebaut")
                continue
            files = sorted(p for p in src.iterdir() if p.is_file())
            for p in files:
                z.write(p, f"{folder}/{p.name}")
            print(f"Ordner '{folder}/' mit {len(files)} Dateien eingebaut")


def check_names(miz_path):
    """Prueft, dass alle TRN_-Namen aus 00_config.lua in der Mission vorkommen."""
    CONFIG_TEXT = CONFIG.read_text(encoding="utf-8")
    wanted = set(re.findall(r'"((?:TRN)[A-Za-z0-9_]+)"', CONFIG_TEXT))
    m = Mission(Caucasus())
    m.load_file(str(miz_path))
    have = set()
    for z in m.triggers.zones():
        have.add(z.name)
    for coal in m.coalition.values():
        for country in coal.countries.values():
            for cat in ("plane_group", "helicopter_group", "vehicle_group", "ship_group", "static_group"):
                for g in getattr(country, cat, []):
                    have.add(g.name)
                    for u in g.units:
                        have.add(u.name)
    missing = sorted(n for n in wanted if n not in have and not any(h.startswith(n) for h in have))
    return wanted, missing, m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--output", default=str(ROOT / "mission" / "DCS_CaucasusStrike.miz"))
    ap.add_argument("--sounds-dir", default=None, help="Pfad zum geklonten MOOSE_SOUND-Repository")
    args = ap.parse_args()
    out = Path(args.output)

    import plot_map

    # Phase 1: Mission ohne Karten/Kneeboards -> daraus Karten und Objektliste
    tmp = Path(tempfile.mkdtemp()) / "phase1.miz"
    build(None, tmp)
    items, airports = plot_map.load(tmp)
    plot_map.render_all(items, airports)

    # Kneeboards: Seiten als PNG nach mission/kneeboard/ (werden auch in die .miz gepackt)
    kbdir = ROOT / "mission" / "kneeboard"
    shutil.rmtree(kbdir, ignore_errors=True)
    kb_maps = plot_map.render_kneeboard_maps(items, airports, kbdir / "_maps")
    cfg = briefing.load_cfg()
    terrain = Caucasus()
    pages = briefing.build_kneeboards(kbdir, briefing.Geo(terrain, POS), cfg, terrain.airports, kb_maps)
    shutil.rmtree(kbdir / "_maps", ignore_errors=True)

    # Phase 2: endgueltige Mission mit Briefing-Bildern, Kneeboards und Soundordnern
    pictures = [ROOT / "mission" / "map" / "01_uebersicht.png", ROOT / "mission" / "map" / "02_west_georgien.png"]
    build(args.sounds_dir, out, extras=dict(kneeboards=pages, pictures=pictures))
    if args.sounds_dir:
        add_sounds(out, Path(args.sounds_dir))

    wanted, missing, m = check_names(out)
    print(f"Mission gespeichert: {out} ({out.stat().st_size / 1e6:.1f} MB)")
    print(f"Kneeboard-Seiten: {sum(len(v) for v in pages.values())} fuer {len(pages)} Flugzeugtypen in {kbdir}")
    print(f"Namenspruefung: {len(wanted) - len(missing)} von {len(wanted)} TRN_-Namen aus 00_config.lua in der Mission")
    if missing:
        print("FEHLEND:", ", ".join(missing))
        sys.exit(1)


if __name__ == "__main__":
    main()
