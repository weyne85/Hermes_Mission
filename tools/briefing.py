#!/usr/bin/env python3
"""Briefing-Texte, Spieler-Routen (Wegpunkte) und Kneeboard-Seiten fuer die Trainingsmission
"Caucasus Strike".

Wird von tools/build_miz.py benutzt. Alle Frequenzen, Codes und Namen kommen aus
scripts/00_config.lua (einzige Quelle); Positionen kommen aus build_miz.POS; Flugplatzdaten
(UHF/VHF ATC, Pistenrichtung) aus pydcs.
"""

import json
import re
import subprocess
import textwrap
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import mgrs as mgrs_lib
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
_MGRS = mgrs_lib.MGRS()

M_TO_FT = 3.28084
KMH_TO_KT = 0.539957

LUA_DUMP = r'''
coalition = { side = { BLUE = 2, RED = 1 } }
dofile("scripts/00_config.lua")
local function dump(v)
  local t = type(v)
  if t == "table" then
    local isArray = (#v > 0)
    local parts = {}
    if isArray then
      for _, x in ipairs(v) do parts[#parts + 1] = dump(x) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, x in pairs(v) do parts[#parts + 1] = string.format("%q:%s", tostring(k), dump(x)) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then return string.format("%q", v)
  elseif t == "number" or t == "boolean" then return tostring(v)
  end
  return "null"
end
print(dump(TRN.CFG))
'''

def load_cfg():
    """Liest scripts/00_config.lua mit Lua und liefert die Konfiguration als dict."""
    out = subprocess.run(["lua5.1", "-e", LUA_DUMP], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return json.loads(out)


# ---------------------------------------------------------------------------------------------- Format
def mgrs(lat, lng, prec=3):
    s = _MGRS.toMGRS(lat, lng, MGRSPrecision=prec)
    m = re.match(r"(\d{2}[A-Z])([A-Z]{2})(\d+)", s)
    if not m:
        return s
    digits = m.group(3)
    h = len(digits) // 2
    return f"{m.group(1)} {m.group(2)} {digits[:h]} {digits[h:]}"


def ddm(lat, lng):
    def one(v, pos, neg, deg_width):
        hemi = pos if v >= 0 else neg
        v = abs(v)
        d = int(v)
        return f"{hemi} {d:0{deg_width}d}°{(v - d) * 60:06.3f}'"
    return one(lat, "N", "S", 2) + " " + one(lng, "E", "W", 3)


def freq(mhz):
    return f"{mhz:.3f}"


def hz_to_mhz(hz):
    return hz / 1e6


# ---------------------------------------------------------------------------------------------- Routen
# Eintrag: (Name, Hoehe in m, Geschwindigkeit in km/h, Hoehentyp, Kommentar)
JET_FA18 = [
    ("SEAD ZONE", 3000, 650, "BARO", "Zone 1: SEAD/DEAD area 30 nm E Kutaisi"),
    ("ST STRIKE", 2500, 600, "BARO", "Zone 2: strike target area"),
    ("AND ZONE", 2000, 550, "BARO", "Zone 3: air-to-ground column"),
    ("CC ZONE", 2500, 600, "BARO", "Zone 4: combined area (SEAD + strike)"),
]

ROUTES = {
    "FA-18C_hornet": JET_FA18,
    "F-16C_50": JET_FA18,
    "AH-64D_BLK_II": [
        ("AND", 400, 200, "RADIO", "Zone 3: air-to-ground"),
        ("SEAD ZONE", 600, 250, "RADIO", "Zone 1: SEAD/DEAD"),
        ("ST STRIKE", 800, 300, "RADIO", "Zone 2: strike"),
        ("CC ZONE", 600, 250, "RADIO", "Zone 4: combined"),
    ],
    "Mi-24P": [
        ("AND", 400, 200, "RADIO", "Zone 3: air-to-ground"),
        ("SEAD ZONE", 600, 250, "RADIO", "Zone 1: SEAD/DEAD"),
        ("ST STRIKE", 800, 300, "RADIO", "Zone 2: strike"),
        ("CC ZONE", 600, 250, "RADIO", "Zone 4: combined"),
    ],
}


def point_table(pos):
    """Name -> (x, y) in DCS-Koordinaten."""
    rx, ry = pos["sead"]
    sx, sy = pos["strike"]
    ax, ay = pos["ag_zone"]
    cx, cy = pos["cc_zone"]
    return {
        "SEAD ZONE": (rx, ry), "ST STRIKE": (sx, sy), "AND ZONE": (ax, ay), "CC ZONE": (cx, cy),
    }


# ---------------------------------------------------------------------------------------------- Typen
TYPES = {
    "FA-18C_hornet": dict(name="F/A-18C", zones="1,2,3,4", proc=["sead", "strike", "ag", "cc"],
                          maps=["overview", "west", "sea"]),
    "F-16C_50": dict(name="F-16C", zones="1,2,3,4", proc=["sead", "strike", "ag", "cc"],
                     maps=["overview", "west"]),
    "AH-64D_BLK_II": dict(name="AH-64D", zones="1,2,3,4", proc=["sead", "ag", "cc", "strike"],
                          maps=["west"]),
    "Mi-24P": dict(name="Mi-24P", zones="1,2,3,4", proc=["sead", "ag", "cc", "strike"],
                   maps=["west"]),
}


# ---------------------------------------------------------------------------------------------- Geografie
class Geo:
    """Positionen mit Breite/Laenge und MGRS (aus pydcs)."""

    def __init__(self, terrain, pos):
        from dcs.mapping import Point
        self.terrain = terrain
        self.pos = pos
        self.points = point_table(pos)
        self._Point = Point

    def ll(self, xy):
        p = self._Point(xy[0], xy[1], self.terrain).latlng()
        return p.lat, p.lng

    def mgrs(self, xy, prec=3):
        return mgrs(*self.ll(xy), prec)

    def ddm(self, xy):
        return ddm(*self.ll(xy))


# ---------------------------------------------------------------------------------------------- Seiten
W, H, DPI = 768, 1024, 100
INK = "#111111"


def _page(title, subtitle, blocks, path):
    """blocks: Liste von (stil, text). stil: 'h' Ueberschrift, 'n' Text, 'm' Monospace-Zeile, 's' klein, '-' Leerzeile."""
    fig = plt.figure(figsize=(W / DPI, H / DPI), dpi=DPI, facecolor="white")
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, W)
    ax.set_ylim(H, 0)
    ax.axis("off")
    ax.add_patch(plt.Rectangle((0, 0), W, 64, color="#1f3b5c"))
    ax.text(18, 24, title, color="white", fontsize=17, fontweight="bold", va="center", family="DejaVu Sans")
    ax.text(18, 49, subtitle, color="#cfd9e6", fontsize=10.5, va="center", family="DejaVu Sans")
    y = 88
    for style, text in blocks:
        if style == "-":
            y += 10
            continue
        if style == "h":
            y += 6
            ax.text(18, y, text, fontsize=13.5, fontweight="bold", color="#1f3b5c", va="top", family="DejaVu Sans")
            ax.plot([18, W - 18], [y + 24, y + 24], color="#1f3b5c", lw=1)
            y += 32
        elif style == "n":
            for line in textwrap.wrap(text, 66) or [""]:
                ax.text(18, y, line, fontsize=11.5, color=INK, va="top", family="DejaVu Sans")
                y += 19
        elif style == "s":
            for line in textwrap.wrap(text, 92) or [""]:
                ax.text(18, y, line, fontsize=9, color="#444444", va="top", family="DejaVu Sans")
                y += 15
        elif style == "m":
            ax.text(18, y, text, fontsize=10.2, color=INK, va="top", family="DejaVu Sans Mono")
            y += 18
        elif style == "mb":
            ax.text(18, y, text, fontsize=10.2, color=INK, va="top", family="DejaVu Sans Mono", fontweight="bold")
            y += 18
    if y > H - 10:
        raise ValueError(f"Kneeboard-Seite '{title}' ist zu lang ({y} > {H})")
    fig.savefig(path, dpi=DPI, facecolor="white")
    plt.close(fig)
    return path


def _map_page(title, subtitle, map_path, path):
    """Setzt eine bestehende Karte mittig auf eine Hochformat-Seite (ohne Verzerrung)."""
    src = Image.open(map_path).convert("RGB")
    scale = min((W - 20) / src.width, (H - 100) / src.height)
    img = src.resize((int(src.width * scale), int(src.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H), "white")
    canvas.paste(img, ((W - img.width) // 2, 80))
    fig = plt.figure(figsize=(W / DPI, H / DPI), dpi=DPI)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.imshow(canvas)
    ax.add_patch(plt.Rectangle((0, 0), W, 64, color="#1f3b5c"))
    ax.text(18, 24, title, color="white", fontsize=17, fontweight="bold", va="center")
    ax.text(18, 49, subtitle, color="#cfd9e6", fontsize=10.5, va="center")
    ax.axis("off")
    fig.savefig(path, dpi=DPI)
    plt.close(fig)
    return path


def frequency_page(tname, info, cfg, airports, path):
    c = cfg
    blocks = [("h", "AIRFIELDS (UHF / VHF AM, runway)")]
    for n in ("Kobuleti", "Senaki-Kolkhi", "Kutaisi", "Batumi"):
        a = airports[n]
        r = a.runways[0]
        blocks.append(("m", f"{n:<14} {hz_to_mhz(a.atc_radio.uhf_hz):7.3f} {hz_to_mhz(a.atc_radio.vhf_high_hz):7.3f}  RWY {r.name}"))
    blocks.append(("s", "TACAN/ILS of the airfields: see aircraft database/F10 map (not listed here)."))
    blocks.append(("-", ""))
    se, st, ag, cc = c["SEAD"], c["STRIKE"], c["AG"], c["COMBINED"]
    if "sead" in info["proc"]:
        blocks += [("h", "SEAD / DEAD"),
                   ("m", f"SEAD EASY: SA-2 / SA-3. SEAD MEDIUM: SA-6 / SA-11 + AAA. SEAD HARD: SA-8 + SA-15 + AAA."),
                   ("s", "Threat radar: 'Threat radar detected' within 45 km (bearing, range)."),
                   ("s", "Missile launch: 'Missile launch' on every SAM launch."),
                   ("s", "F10 > Training Zones > 1 SEAD / DEAD > Start <level> > SEAD or DEAD."),
                   ("s", "EASY: 2 groups, SA-2/SA-3. MEDIUM: 4 groups, SA-6/SA-11 + AAA. HARD: 6 groups, SA-8 + SA-15 + AAA."),
                   ("-", "")]

    if "strike" in info["proc"]:
        blocks += [("h", "STRIKE"),
                   ("m", f"STRIKE EASY: 2 targets, no escorts. STRIKE MEDIUM: 4 + AAA. STRIKE HARD: 6 + 2 AAA."),
                   ("s", "Targets are fixed. Fly the preloaded strike route, mark the target, release bombs."),
                   ("s", "Hit radius 25 m. Good hit when within 25 m."),
                   ("s", "F10 > Training Zones > 2 Strike > Start <level>."),
                   ("-", "")]

    if "ag" in info["proc"]:
        blocks += [("h", "AIR-TO-GROUND"),
                   ("m", f"AG EASY: 1 vehicle, no escort. AG MEDIUM: 2 vehicles, no escort. AG HARD: 2 + AAA escort."),
                   ("s", "Vehicles drive from AG_START to AG_END on the road."),
                   ("s", "Destroy the column. Watch out for AAA escort."),
                   ("s", "F10 > Training Zones > 3 Air-to-Ground > Start <level>."),
                   ("-", "")]

    if "cc" in info["proc"]:
        blocks += [("h", "COMBINED"),
                   ("m", f"CC EASY: 2 targets + 1 SAM. CC MEDIUM: 3 targets + AAA. CC HARD: 4 targets + 2 AAA."),
                   ("s", "Choose your role in the F10 menu: SEAD suppress the SAM, or STRIKE the targets."),
                   ("s", "F10 > Training Zones > 4 Combined > Start <level> > SEAD or STRIKE."),
                   ("s", "SEAD: suppress/destroy the SAM site. STRIKE: destroy the targets."),
                   ("-", "")]

    blocks += [("h", "F10 MENUS"),
               ("m", "Training Zones: Info / Start EASY|MEDIUM|HARD / Stop"),
               ("s", "Each zone serves one flight at a time. Rounds restart automatically.")]
    return _page(f"{info['name']}  FREQUENCIES", "Training Mission Caucasus", blocks, path)


def zones_page(tname, info, geo, cfg, path):
    z = set(info["zones"].split(","))
    P = geo.pos
    blocks = [("h", "ZONES AND TARGETS (MGRS 100 m, lat/long)")]

    def add(name, key, note=""):
        blocks.append(("m", f"{name:<11} {geo.mgrs(P[key]):<16} {note}"))
        blocks.append(("s", "            " + geo.ddm(P[key])))

    def head(t):
        blocks.append(("mb", t))

    if "1" in z:
        head("ZONE 1 SEAD / DEAD")
        add("SEAD ZONE", "sead", "site area")
    if "2" in z:
        head("ZONE 2 STRIKE")
        add("ST STRIKE", "strike", "target area")
    if "3" in z:
        head("ZONE 3 AIR-TO-GROUND")
        add("AG ZONE", "ag_zone", "target area")
        add("AG START", "ag_start", "start point")
        add("AG END", "ag_end", "end point")
    if "4" in z:
        head("ZONE 4 COMBINED")
        add("CC ZONE", "cc_zone", "combined area")
    return _page(f"{info['name']}  ZONES", "Positions are mission placeholders - verify in the ME", blocks, path)


def route_page(tname, info, geo, path):
    route = ROUTES[tname]
    blocks = [("h", "WAYPOINTS (preloaded in the flight plan)")]
    blocks.append(("mb", f"{'WP':<3} {'NAME':<10} {'ALT ft':>7} {'KT':>4}  MGRS"))
    n = 2
    blocks.append(("m", f"{1:<3} {'TAKEOFF':<10} {'':>7} {'':>4}  {'Kobuleti' if tname in ('FA-18C_hornet','F-16C_50','AH-64D_BLK_II','Mi-24P') else 'Senaki-Kolkhi'}"))
    for name, alt, spd, atype, note in route:
        alt_txt = f"{alt * M_TO_FT:.0f}" + ("R" if atype == "RADIO" else "")
        blocks.append(("m", f"{n:<3} {name:<10} {alt_txt:>7} {spd * KMH_TO_KT:>4.0f}  {geo.mgrs(geo.points[name])}"))
        blocks.append(("s", f"    {note}"))
        n += 1
    blocks.append(("m", f"{n:<3} {'LAND':<10} {'':>7} {'':>4}  {'Kobuleti' if tname in ('FA-18C_hornet','F-16C_50','AH-64D_BLK_II','Mi-24P') else 'Senaki-Kolkhi'}"))
    blocks.append(("-", ""))
    blocks.append(("s", "R = radar altitude (AGL). Altitudes of jets are barometric (MSL). All points are optional: fly the zones you need, skip the rest."))
    return _page(f"{info['name']}  ROUTE", "Flight plan waypoints", blocks, path)


PROC = {
    "sead": [
        ("h", "ZONE 1 - SEAD / DEAD"),
        ("n", "Start: Training Zones > 1 SEAD / DEAD > Start <level> > SEAD or DEAD."),
        ("n", "SEAD: all search/track radars destroyed. DEAD: whole site destroyed (if no radar is detected, SEAD counts as DEAD)."),
        ("n", "Calls: 'Threat radar detected' within 45 km (bearing, range); 'Missile launch' on every SAM launch."),
        ("m", "EASY   SA-2 or SA-3"),
        ("m", "MEDIUM SA-6 or SA-11 + AAA"),
        ("m", "HARD   SA-8 + SA-15 + AAA"),
    ],
    "strike": [
        ("h", "ZONE 2 - STRIKE"),
        ("n", "Start: Training Zones > 2 Strike > Start <level>. Targets are fixed."),
        ("n", "Lay your bomb run along the known compass bearing of the target."),
        ("n", "Hit radius 25 m. Watch the drop count."),
        ("m", "EASY   2 targets, no escorts"),
        ("m", "MEDIUM 4 targets + AAA"),
        ("m", "HARD   6 targets + 2 AAA"),
    ],
    "ag": [
        ("h", "ZONE 3 - AIR-TO-GROUND"),
        ("n", "Start: Training Zones > 3 Air-to-Ground > Start <level>."),
        ("n", "Vehicles drive from AG_START to AG_END on the road."),
        ("n", "Destroy the column. Watch out for AAA escort."),
        ("m", "EASY   1 vehicle, no escort"),
        ("m", "MEDIUM 2 vehicles, no escort"),
        ("m", "HARD   2 vehicles + AAA escort"),
    ],
    "cc": [
        ("h", "ZONE 4 - COMBINED"),
        ("n", "Start: Training Zones > 4 Combined > Start <level>. Choose your role in the F10 menu."),
        ("n", "SEAD: suppress/destroy the Red SAM site."),
        ("n", "STRIKE: destroy the ground targets."),
        ("m", "EASY   2 targets + 1 SAM"),
        ("m", "MEDIUM 3 targets + AAA"),
        ("m", "HARD   4 targets + 2 AAA"),
    ],
}


def procedure_pages(tname, info, path_fn):
    pages = []
    keys = list(info["proc"])
    for i in range(0, len(keys), 2):
        blocks = []
        for k in keys[i:i + 2]:
            blocks += PROC[k] + [("-", "")]
        pages.append(_page(f"{info['name']}  PROCEDURES {i // 2 + 1}", "Zones and how to fly them", blocks, path_fn(i // 2 + 1)))
    return pages


MAP_TITLES = {"overview": "Overview", "west": "West Georgia", "sea": "Black Sea"}


def build_kneeboards(outdir, geo, cfg, airports, map_paths):
    """Erzeugt alle Seiten. map_paths: dict Kartenname -> PNG. Rueckgabe: dict Typ-ID -> Liste von Pfaden."""
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    result = {}
    for tname, info in TYPES.items():
        base = tname.replace("/", "_")
        pages = []
        pages.append(frequency_page(tname, info, cfg, airports, outdir / f"{base}_1_freq.png"))
        pages.append(zones_page(tname, info, geo, cfg, outdir / f"{base}_2_zones.png"))
        pages.append(route_page(tname, info, geo, outdir / f"{base}_3_route.png"))
        pages += procedure_pages(tname, info, lambda n, b=base: outdir / f"{b}_4_proc{n}.png")
        for j, mp in enumerate(info["maps"], start=1):
            pages.append(_map_page(f"{info['name']}  MAP {j}", MAP_TITLES[mp] + " (no terrain, zones only)", map_paths[mp],
                                   outdir / f"{base}_5_map{j}.png"))
        result[tname] = pages
    return result


# ---------------------------------------------------------------------------------------------- Briefing
def briefing_texts(geo, cfg):
    c = cfg
    P = geo.pos
    se, st, ag, cc = c["SEAD"], c["STRIKE"], c["AG"], c["COMBINED"]

    def m(key):
        return geo.mgrs(P[key])

    situation = (
        "CAUCASUS STRIKE - TRAINING MISSION\n\n"
        "Four compact, fast training ranges on the Caucasus map. Each zone is played in a single round "
        "(EASY / MEDIUM / HARD), and rounds restart automatically. All zones are used from the F10 menu "
        "'Training Zones'. Each zone serves one flight at a time.\n\n"
        "ZONES\n"
        "1 SEAD / DEAD - enemy air defence site, 30 nm east of Kutaisi at MGRS " + m("sead") + ". "
        "Choose SEAD (suppress the radars) or DEAD (destroy the whole site).\n"
        "2 STRIKE - fixed targets, 30 nm east of Kutaisi at MGRS " + m("strike") + ". "
        "Drop bombs on the target set (2, 4, or 6 targets per round).\n"
        "3 AIR-TO-GROUND - enemy armoured column, road-bound at MGRS " + m("ag_zone") + ". "
        "Destroy the column (1, 2, or 2+ vehicles per round).\n"
        "4 COMBINED - a small box in the centre of the map. "
        "Choose your role (SEAD suppress the SAM, or STRIKE the targets).\n\n"
        "FREQUENCIES\n"
        "All aircraft use UHF/VHF ATC on the airfields. JTAC laser code 1688, JTAC FM 40.40 FM. "
        "Marshal/LSO if carrier present; Range/ATC control if applicable.\n\n"
        "NAVIGATION\n"
        "Waypoints for each zone are preloaded in the client flight plans. Kneeboard pages: "
        "frequencies, zones, route, procedures and maps."
    )
    blue = (
        "Pick a zone, start it from F10 > Training Zones and fly the exercise.\n"
        "F/A-18C and F-16C: SEAD / DEAD, Strike, and Combined roles.\n"
        "AH-64D and Mi-24P: Air-to-Ground and Combined roles; the AH-64D also escorts the JTAC.\n"
        "Stay clear of other zones when their SAM sites are active."
    )
    red = "Hostile SAM sites, ground units, fighters, AAA and convoys appear in the zones when a round starts."
    return situation, blue, red
