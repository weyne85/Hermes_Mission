"""Mission-spezifische Teile der .miz: Skript-Trigger, Spieler-Slots mit Wegpunkten, Briefing, Mission Goals.

Wird von build_miz.build(..., mission=...) aufgerufen. Missionsdaten stehen in tools/missions.py.
"""

from pathlib import Path

from dcs import helicopters, planes
from dcs.action import DoScriptFile
from dcs.condition import FlagIsTrue
from dcs.goals import Goal
from dcs.mapping import Point
from dcs.mission import StartType
from dcs.triggers import TriggerStart

ROOT = Path(__file__).resolve().parent.parent

# Muster -> (pydcs-Typ, Beschriftung, Startflugplatz, Art)
TYPES = {
    "FA-18C": (planes.FA_18C_hornet, "F-18C", "Kobuleti", "jet"),
    "F-16C": (planes.F_16C_50, "F-16C", "Kobuleti", "jet"),
    "A-10C II": (planes.A_10C_2, "A-10C II", "Kobuleti", "attack"),
    "AH-64D": (helicopters.AH_64D_BLK_II, "AH-64D", "Senaki-Kolkhi", "heli"),
    "Mi-24P": (helicopters.Mi_24P, "Mi-24P", "Senaki-Kolkhi", "heli"),
}
SLOTS_PER_TYPE = 2

# Reiseflug je Art: (Hoehe m, Geschwindigkeit km/h, Hoehentyp)
CRUISE = {
    "jet": (3000, 650, "BARO"),
    "attack": (2500, 450, "BARO"),
    "heli": (300, 220, "RADIO"),
}

# Zone -> Wegpunkte (Schluessel in build_miz.POS, Name des Wegpunkts)
ZONE_WAYPOINTS = {
    "SEAD": [("sead", "SEAD ZONE")],
    "STRIKE": [("strike", "STRIKE ZONE")],
    "AG": [("ag_zone", "AG ZONE")],
    "COMBINED": [("cc_zone", "CC ZONE")],
    "TRANSPORT": [("ctld_load", "LOAD ZONE"), ("ctld_drop", "DROP ZONE")],
    "RESCUE": [("csar_zone", "CSAR ZONE"), ("mash", "MASH")],
}

LIBS = ["mist.lua", "Moose.lua"]
SCRIPTS = ["00_config", "01_core", "02_audio", "03_menu", "10_sead", "20_strike", "30_ag", "40_cc", "50_ctld", "60_csar"]
SCRIPTS_AFTER = ["70_mission", "80_ambient", "99_init"]


def autostart(mission):
    return mission.get("autostart", True)


def mission_lua(mission):
    """Inhalt von scripts/missions/<ID>.lua."""
    objs = []
    for o in mission["objectives"]:
        fields = [f'zone = "{o["zone"]}"', f'level = "{o["level"]}"']
        if o.get("mode"):
            fields.append(f'mode = "{o["mode"]}"')
        if o.get("for_types"):
            ids = ", ".join(f'"{TYPES[k][0].id}"' for k in o["for_types"])
            fields.append(f"forTypes = {{ {ids} }}")
        objs.append("    { " + ", ".join(fields) + " },")
    events = ""
    if mission.get("events"):
        evs = "\n".join(f'    {{ after = {e["after"]}, action = "{e["action"]}" }},' for e in mission["events"])
        events = "  events = {\n" + evs + "\n  },\n"
    return (
        "-- GENERIERT von tools/build_missions.py aus tools/missions.py - nicht von Hand aendern.\n"
        "TRN = TRN or {}\n"
        "TRN.MISSION = {\n"
        f'  id = "{mission["id"]}", title = "{mission["title"]}", autostart = {str(autostart(mission)).lower()}, '
        f'startDelay = {mission.get("startDelay", 10)},\n'
        "  objectives = {\n" + "\n".join(objs) + "\n  },\n" + events + "}\n"
    )


def write_lua(mission):
    path = ROOT / "scripts" / "missions" / f"{mission['id']}.lua"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(mission_lua(mission), encoding="utf-8")
    return path


def script_files(mission, libs_dir, allow_missing_libs):
    """Ladereihenfolge der Mission als Liste von Pfaden. Fehlende Libs: Fehler oder (Option) uebersprungen."""
    files, missing = [], []
    for lib in LIBS:
        p = Path(libs_dir) / lib
        (files if p.is_file() else missing).append(p)
    if missing and not allow_missing_libs:
        raise FileNotFoundError(
            "Bibliotheken fehlen: " + ", ".join(str(p) for p in missing)
            + " (nach libs/ legen oder --libs-dir angeben; Option --allow-missing-libs baut ohne)")
    for p in missing:
        print(f"WARNUNG: {p} fehlt - wird nicht in die Mission eingebaut")
    files += [ROOT / "scripts" / f"{n}.lua" for n in SCRIPTS]
    files.append(write_lua(mission))
    files += [ROOT / "scripts" / f"{n}.lua" for n in SCRIPTS_AFTER]
    return files


def add_scripts(m, mission, libs_dir, allow_missing_libs):
    trig = TriggerStart(comment=f"Skripte laden ({mission['id']})")
    for p in script_files(mission, libs_dir, allow_missing_libs):
        trig.add_action(DoScriptFile(m.map_resource.add_resource_file(str(p))))
    m.triggerrules.triggers.append(trig)


def add_slots(m, usa, pos, mission):
    """Je Muster SLOTS_PER_TYPE Spielerflugzeuge, heisser Start, Wegpunkte zu den Aufgabenzonen, Landung am Start."""
    for tid in mission["types"]:
        ptype, label, base, kind = TYPES[tid]
        airport = m.terrain.airports[base]
        for n in range(1, SLOTS_PER_TYPE + 1):
            fg = m.flight_group_from_airport(usa, f"{label} Client {n}", ptype, airport,
                                             start_type=StartType.Warm, group_size=1)
            fg.units[0].set_client()
            for name, wp_alt, wp_speed, wp_alt_type, (x, y) in waypoint_list(mission, kind, pos):
                wp = fg.add_waypoint(Point(x, y, m.terrain), wp_alt, wp_speed, name=name)
                wp.alt_type = wp_alt_type
            fg.land_at(airport)


def waypoint_list(mission, kind, pos):
    """Wegpunkte der Mission fuer eine Art: Liste (Name, Hoehe m, km/h, Hoehentyp, (x, y))."""
    alt, speed, alt_type = CRUISE[kind]
    out, seen = [], set()
    for o in mission["objectives"]:
        if o["zone"] in seen:
            continue
        seen.add(o["zone"])
        for key, label in ZONE_WAYPOINTS[o["zone"]]:
            out.append((label, alt, speed, alt_type, tuple(pos[key])))
    return out


def add_kneeboards(m, pos, mission, outdir):
    import briefing
    import kneeboards
    geo = briefing.Geo(m.terrain, pos)
    for tid in mission["types"]:
        ptype, label, base, kind = TYPES[tid]
        pages = kneeboards.build_pages(mission, tid, label, base, waypoint_list(mission, kind, pos), geo,
                                       m.terrain.airports, Path(outdir) / mission["id"])
        for page in pages:
            m.add_aircraft_kneeboard(ptype, page)


def add_briefing(m, mission):
    m.set_description_text(f"{mission['title']}\n\n{mission['situation']}\n\n{mission['threat']}")
    m.set_description_bluetask_text(mission["task"])
    m.set_description_redtask_text("Verteidigung der Stellungen.")


def flag_names(mission):
    return f"TRN_{mission['id']}_WIN", f"TRN_{mission['id']}_FAIL"


def add_goals(m, mission):
    win, _ = flag_names(mission)
    goal = Goal(f"{mission['id']} {mission['title']}: Einsatzziel erfuellt", score=100)
    goal.rules.append(FlagIsTrue(win))
    m.goals.add_blue(goal)


def apply_mission(m, usa, pos, mission, libs_dir, allow_missing_libs=False):
    add_briefing(m, mission)
    add_slots(m, usa, pos, mission)
    if autostart(mission):
        add_goals(m, mission)
    add_kneeboards(m, pos, mission, ROOT / "mission" / "kneeboard")
    add_scripts(m, mission, libs_dir, allow_missing_libs)
