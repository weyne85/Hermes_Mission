"""Kneeboard-Seiten der Kampagnenmissionen (Deutsch), je Mission und Flugzeugmuster.

Seiten: 1 Funk (Flugplaetze), 2 Einsatz (Aufgaben, Zonenpositionen, Bedrohung), 3 Route (Wegpunkte).
Nutzt die Seitenzeichner aus briefing.py. Wird von mission_builder.add_kneeboards aufgerufen.
"""

from pathlib import Path

import briefing

ZONE_TEXT = {
    "SEAD": "SEAD/DEAD: Radare der SAM-Stellung ausschalten bzw. die Stellung zerstören.",
    "STRIKE": "Strike: Bodenziele im Zielgebiet zerstören (Trefferradius 25 m).",
    "AG": "Air-to-Ground: Kolonne zerstören, bevor ein Fahrzeug die Endlinie (AG END) erreicht.",
    "COMBINED": "Combined: SAM-Stellung ausschalten und die Bodenziele zerstören.",
    "TRANSPORT": "Transport: Truppen im Ladegebiet aufnehmen (F10 > CTLD), im Abwurfgebiet absetzen.",
    "RESCUE": "CSAR: Besatzung finden (Funkbake), aufnehmen und zum Flugplatz bzw. MASH bringen.",
}
KNOWN_AIRFIELDS = ("Kobuleti", "Senaki-Kolkhi", "Kutaisi", "Batumi")


def _frequency_page(label, base, mission, airports, path):
    blocks = [("h", "FLUGPLÄTZE (UHF / VHF AM, Piste)")]
    for n in KNOWN_AIRFIELDS:
        a = airports[n]
        r = a.runways[0]
        mark = "*" if n == base else " "
        blocks.append(("m", f"{mark}{n:<14} {briefing.hz_to_mhz(a.atc_radio.uhf_hz):7.3f} {briefing.hz_to_mhz(a.atc_radio.vhf_high_hz):7.3f}  RWY {r.name}"))
    blocks.append(("s", f"* = dein Startflugplatz ({base}). TACAN/ILS siehe Flugzeugdatenbank."))
    blocks.append(("-", ""))
    blocks.append(("h", "ABLAUF"))
    if mission.get("autostart", True):
        blocks += [("n", "Die Aufgaben starten automatisch kurz nach dem Start des ersten Flugzeugs. "
                         "Ansagen kommen als Text an alle."),
                   ("n", "Erfolg und Misserfolg werden am Missionsende angesagt.")]
    else:
        blocks += [("n", "Übungsmission: F10 > Training Zones > Zone wählen > Start EASY/MEDIUM/HARD. "
                         "'Stop / Reset' beendet die Übung.")]
    if any(o["zone"] in ("TRANSPORT", "RESCUE") for o in mission["objectives"]) or not mission.get("autostart", True):
        blocks += [("-", ""), ("h", "HUBSCHRAUBER-MENÜS"),
                   ("n", "CTLD (Truppen) und CSAR (Rettung) erscheinen im F10-Menü der Hubschrauber-Slots, "
                         "sobald die Aufgabe läuft.")]
    return briefing._page(f"{label}  FUNK", f"{mission['id']} {mission['title']}", blocks, path)


def _mission_page(label, tid, mission, geo, waypoints, path):
    blocks = [("h", "AUFGABEN")]
    for o in mission["objectives"]:
        text = ZONE_TEXT[o["zone"]]
        mode = f" ({o['mode']})" if o.get("mode") else ""
        blocks.append(("n", f"{o['zone']} {o['level']}{mode}"))
        blocks.append(("s", text))
        if o.get("for_types") and tid not in o["for_types"]:
            blocks.append(("s", "Gilt für andere Muster; hilf bei Bedarf als Unterstützung."))
    if not mission["objectives"]:
        blocks.append(("n", "Keine feste Aufgabe: Übung im F10-Menü."))
    blocks.append(("-", ""))
    blocks.append(("h", "ZONEN (MGRS 100 m, Breite/Länge)"))
    for name, _alt, _speed, _alt_type, xy in waypoints:
        blocks.append(("m", f"{name:<11} {geo.mgrs(xy)}"))
        blocks.append(("s", "            " + geo.ddm(xy)))
    blocks.append(("-", ""))
    blocks.append(("h", "LAGE UND BEDROHUNG"))
    blocks.append(("n", mission["threat"]))
    blocks.append(("s", "Koordinaten sind Platzhalter - im Mission Editor prüfen."))
    return briefing._page(f"{label}  EINSATZ", f"{mission['id']} {mission['title']}", blocks, path)


def _route_page(label, base, waypoints, geo, path):
    blocks = [("h", "FLUGPLAN"), ("mb", "NR NAME       HÖHE   KT  MGRS")]
    blocks.append(("m", f"1   TAKEOFF    {'':>6} {'':>4}  {base}"))
    for n, (name, alt, speed, alt_type, xy) in enumerate(waypoints, start=2):
        alt_txt = f"{alt * briefing.M_TO_FT:.0f}{'R' if alt_type == 'RADIO' else 'B'}"
        blocks.append(("m", f"{n:<3} {name:<10} {alt_txt:>7} {speed * briefing.KMH_TO_KT:>4.0f}  {geo.mgrs(xy)}"))
    blocks.append(("m", f"{len(waypoints) + 2:<3} LAND       {'':>7} {'':>4}  {base}"))
    blocks.append(("-", ""))
    blocks.append(("s", "R = Radarhöhe (AGL), B = barometrisch (MSL), Höhen in Fuß. Alle Punkte sind optional."))
    return briefing._page(f"{label}  ROUTE", "Flugplan", blocks, path)


def build_pages(mission, tid, label, base, waypoints, geo, airports, outdir):
    """waypoints: Liste (Name, Hoehe m, km/h, Hoehentyp, (x, y)). Rueckgabe: Liste der PNG-Pfade."""
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    safe = f"{mission['id']}_{label}".replace("/", "_").replace(" ", "_")
    return [
        _frequency_page(label, base, mission, airports, outdir / f"{safe}_1_funk.png"),
        _mission_page(label, tid, mission, geo, waypoints, outdir / f"{safe}_2_einsatz.png"),
        _route_page(label, base, waypoints, geo, outdir / f"{safe}_3_route.png"),
    ]

