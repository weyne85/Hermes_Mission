#!/usr/bin/env python3
"""Baut die Einzelmissionen der Kampagne als .miz (ohne Kampagnendatei).

Aufruf (im Repo-Hauptverzeichnis):
    python3 tools/build_missions.py [--only S1 J1 ...] [--libs-dir libs] [--out-dir mission/missions]
                                    [--allow-missing-libs]

Je Mission: scripts/missions/<ID>.lua erzeugen, .miz bauen, Namenspruefung (alle TRN_-Namen aus 00_config.lua),
danach die .miz neu laden und Slots, Skript-Trigger und Mission Goals pruefen. Exit 1 bei Fehlern.
Voraussetzung: libs/mist.lua und libs/Moose.lua (nicht im Repo, siehe README).
"""

import argparse
import sys
from pathlib import Path

import build_miz
import mission_builder
import missions
from dcs.mission import Mission
from dcs.terrain import Caucasus

ROOT = Path(__file__).resolve().parent.parent


def verify(out, mission):
    """.miz neu laden und die missionsspezifischen Teile pruefen. Rueckgabe: Liste von Fehlertexten."""
    problems = []
    m = Mission(Caucasus())
    m.load_file(str(out))

    clients = []
    for coal in m.coalition.values():
        for country in coal.countries.values():
            for g in list(country.plane_group) + list(country.helicopter_group):
                if any(u.is_human() for u in g.units):
                    clients.append(g)
    want = len(mission["types"]) * mission_builder.SLOTS_PER_TYPE
    if len(clients) != want:
        problems.append(f"{len(clients)} Spielerflugzeuge statt {want}")
    for g in clients:
        if len(g.points) < 2 + len(mission["objectives"]):
            problems.append(f"{g.name}: zu wenige Wegpunkte ({len(g.points)})")

    actions = [a for t in m.triggerrules.triggers for a in t.actions]
    n_scripts = sum(1 for a in actions if a.__class__.__name__ == "DoScriptFile")
    if n_scripts < len(mission_builder.SCRIPTS) + len(mission_builder.SCRIPTS_AFTER) + 1:
        problems.append(f"nur {n_scripts} DoScriptFile-Aktionen")

    win, _ = mission_builder.flag_names(mission)
    goals = m.goals.goals["blue"]
    if not goals or not any(r.dict().get("flag") == win for gl in goals for r in gl.rules):
        problems.append(f"Mission Goal fuer Flag {win} fehlt")
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", help="nur diese Missions-IDs")
    ap.add_argument("--libs-dir", default=str(ROOT / "libs"))
    ap.add_argument("--out-dir", default=str(ROOT / "mission" / "missions"))
    ap.add_argument("--allow-missing-libs", action="store_true", help="ohne mist.lua/Moose.lua bauen (nur Test)")
    args = ap.parse_args()

    ids = args.only or missions.ORDER
    unknown = [i for i in ids if i not in missions.MISSIONS]
    if unknown:
        print("Unbekannte Missions-IDs:", ", ".join(unknown))
        return 1

    failed = False
    for mid in ids:
        mission = missions.MISSIONS[mid]
        out = Path(args.out_dir) / f"{mid}_{mission['slug']}.miz"
        try:
            build_miz.build(None, out, mission=mission, libs_dir=args.libs_dir,
                            allow_missing_libs=args.allow_missing_libs)
        except FileNotFoundError as e:
            print(f"{mid}: {e}")
            return 1
        wanted, missing, _ = build_miz.check_names(out)
        problems = verify(out, mission)
        if missing:
            problems.append("fehlende TRN_-Namen: " + ", ".join(missing))
        status = "OK" if not problems else "FEHLER"
        print(f"{mid} {mission['title']}: {out.name} ({out.stat().st_size / 1e6:.1f} MB), "
              f"Namen {len(wanted) - len(missing)}/{len(wanted)}, {status}")
        for p in problems:
            print("   -", p)
        failed = failed or bool(problems)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
