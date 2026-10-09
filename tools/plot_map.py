#!/usr/bin/env python3
"""Zeichnet aus der .miz eine Uebersicht aller Zonen, Einheiten und Strukturen (PNG) und schreibt eine Objektliste.

Aufruf (im Repo-Hauptverzeichnis):
    pip install pydcs matplotlib
    python3 tools/plot_map.py [mission/DCS_CaucasusStrike.miz]

Ausgabe in mission/map/:
    01_uebersicht.png, 02_west_georgien.png, 03_schwarzes_meer.png, 04_ost_sead.png, 05_nord_konvoi.png
    objekte.md   (alle Namen mit Typ, Position und Breite/Laenge)

Hintergrund: Es gibt keine Gelaendekarte. Eingezeichnet sind nur die Flugplaetze als Orientierung.
Positionen sind die Platzhalter aus tools/build_miz.py.
"""

import sys
from collections import OrderedDict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from adjustText import adjust_text
from matplotlib.lines import Line2D
from matplotlib.patches import Circle

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import types_extra  # noqa: F401,E402  (registriert den CH-47F-Typ fuer pydcs)
from dcs.mission import Mission
from dcs.terrain import Caucasus

MIZ = ROOT / "mission" / "DCS_CaucasusStrike.miz"
OUT = ROOT / "mission" / "map"

# Kategorie -> (Beschriftung, Farbe)
CAT = OrderedDict([
    ("zone_train", ("Zonen: SEAD/DEAD, Strike, Air-to-Ground, Combined (Exercise zones)", "#d62728")),
    ("range", ("Range-Ziele (feste Einheiten)", "#9467bd")),
    ("tpl_ground", ("Vorlagen Bodenziele (Late Activation)", "#e377c2")),
    ("tpl_sam", ("Vorlagen SAM (Late Activation)", "#b22222")),
    ("tpl_air", ("Vorlagen Luftziele (Late Activation)", "#17becf")),
    ("jtac", ("JTAC und JTAC-Ziele", "#bcbd22")),
    ("tpl_conv", ("Vorlagen Konvois (Late Activation)", "#7f7f7f")),
    ("tpl_rat", ("Vorlagen Flugverkehr (Late Activation)", "#1f77b4")),
    ("csar", ("CSAR-Pilot (Vorlage)", "#ff9896")),
    ("ctld_logi", ("CTLD-Logistikobjekte", "#98df8a")),
    ("ship", ("Träger, Begleitschiffe, Handelsschiffe", "#0b3d91")),
    ("scene", ("Flugplatz-Kulisse (Statics, Fahrzeuge)", "#aaaaaa")),
    ("slots", ("Spieler-Slots (Client)", "#000000")),
])

def categorize(name, client=False):
    if client:
        return "slots"
    n = name
    if n.startswith("TRN_RANGE_") and "ZONE" not in n:
        return "range"
    if n.startswith("TRN_GA_"):
        return "tpl_ground"
    if n.startswith("TRN_SAM_"):
        return "tpl_sam"
    if n.startswith("TRN_BANDIT_"):
        return "tpl_air"
    if n.startswith("TRN_JTAC"):
        return "jtac"
    if n.startswith("TRN_CONVOY_"):
        return "tpl_conv"
    if n.startswith("TRN_RAT_"):
        return "tpl_rat"
    if n.startswith("TRN_CSAR_PILOT"):
        return "csar"
    if n.startswith("TRN_CTLD_LOGI"):
        return "ctld_logi"
    if n.startswith(("TRN_CARRIER", "TRN_ESCORT", "TRN_SHIP")):
        return "ship"
    if n.startswith(("TRN_STATIC_", "TRN_AIRFIELD_")):
        return "scene"
    return "scene"

def zone_cat(name):
    if name.startswith(("TRN_CTLD_",)):
        return "zone_ctld"
    if name.startswith(("TRN_CSAR_", "TRN_MASH")):
        return "zone_csar"
    if name.startswith("TRN_CONV_"):
        return "zone_conv"
    return "zone_train"

def load(miz_path=None):
    m = Mission(Caucasus())
    m.load_file(str(miz_path or MIZ))
    items = []   # dict(name, cat, kind, e, n, lat, lng, side, types, late, route)

    def add(name, cat, kind, pos, side, types="", late=False, route=None, radius=None):
        ll = pos.latlng()
        items.append(dict(name=name, cat=cat, kind=kind, e=pos.y, n=pos.x, lat=ll.lat, lng=ll.lng, side=side,
                          types=types, late=late, route=route or [], radius=radius))

    for z in m.triggers.zones():
        add(z.name, zone_cat(z.name), "zone", z.position, "-", radius=z.radius)

    for side, coal in m.coalition.items():
        for country in coal.countries.values():
            for g in country.vehicle_group:
                types = ", ".join(sorted({u.type for u in g.units}))
                if g.name.startswith("TRN_RANGE_"):
                    for u in g.units:
                        add(u.name, "range", "vehicle", u.position, side, u.type)
                else:
                    add(g.name, categorize(g.name), "vehicle", g.units[0].position, side, f"{len(g.units)}x {types}", g.late_activation)
            for g in list(country.plane_group) + list(country.helicopter_group):
                client = g.units[0].skill.value == "Client" if hasattr(g.units[0].skill, "value") else str(g.units[0].skill) == "Client"
                route = [p.position for p in g.points]
                add(g.name, categorize(g.name, client), "air", g.units[0].position, side, f"{len(g.units)}x {g.units[0].type}",
                    g.late_activation, route)
            for g in country.ship_group:
                add(g.units[0].name, categorize(g.units[0].name), "ship", g.units[0].position, side, g.units[0].type,
                    False, [p.position for p in g.points])
            for g in country.static_group:
                add(g.units[0].name, categorize(g.units[0].name), "static", g.units[0].position, side, g.units[0].type)

    airports = [(a.name, a.position) for a in m.terrain.airports.values()]
    return items, airports

def cluster(items, radius_m):
    """Fasst nahe beieinander liegende Marker zusammen, damit Beschriftungen lesbar bleiben."""
    groups = []
    for it in items:
        for g in groups:
            if abs(g[0]["e"] - it["e"]) < radius_m and abs(g[0]["n"] - it["n"]) < radius_m:
                g.append(it)
                break
        else:
            groups.append([it])
    return groups

def short_label(names):
    names = sorted(names)
    if len(names) <= 3:
        return "\n".join(names)
    base = names[0]
    for n in names[1:]:
        while not n.startswith(base):
            base = base[:-1]
    base = base.rstrip("_") if len(base) > 6 else ""
    if base:
        rest = [n[len(base):].lstrip("_") for n in names]
        return f"{base}_ + " + ", ".join(rest)
    return "\n".join(names)

MARKER = {"vehicle": "o", "air": "^", "ship": "D", "static": "s"}

def draw(items, airports, bounds, title, fname, label_zones=True, label_items=True, cluster_m=None, figsize=(15, 11),
         kb=False, outpath=None):
    e0, e1, n0, n1 = bounds
    fig, ax = plt.subplots(figsize=figsize)
    ax.set_facecolor("#f4f1ea")
    ax.set_xlim(e0, e1)
    ax.set_ylim(n0, n1)
    ax.set_aspect("equal")
    ax.grid(True, color="#d9d4c7", linewidth=0.6)
    span = max(e1 - e0, n1 - n0)
    cl = cluster_m if cluster_m is not None else span / 40

    inb = lambda it: e0 <= it["e"] <= e1 and n0 <= it["n"] <= n1

    texts = []
    # Flugplaetze
    for name, pos in airports:
        if e0 <= pos.y <= e1 and n0 <= pos.x <= n1:
            ax.plot(pos.y, pos.x, marker="*", color="#555555", markersize=14, zorder=3)
            texts.append(ax.text(pos.y, pos.x, name, fontsize=9, color="#333333", fontweight="bold", zorder=8))

    # Routen (Schiffe, Luftziele)
    for it in items:
        if it["route"] and len(it["route"]) > 1 and (it["kind"] == "ship" or (it["kind"] == "air" and it["late"])):
            xs = [p.y for p in it["route"]]
            ys = [p.x for p in it["route"]]
            if any(e0 <= x <= e1 for x in xs) or any(n0 <= y <= n1 for y in ys):
                ax.plot(xs, ys, color=CAT[it["cat"]][1], linewidth=1.2, linestyle="--", alpha=0.8, zorder=2)

    # Zonen
    for it in items:
        if it["kind"] != "zone" or not inb(it):
            continue
        col = CAT[it["cat"]][1]
        ax.add_patch(Circle((it["e"], it["n"]), it["radius"], fill=True, facecolor=col, alpha=0.12, edgecolor=col,
                            linewidth=1.5, linestyle="--", zorder=1))
        ax.plot(it["e"], it["n"], marker="=", color=col, markersize=7, zorder=4)

    zone_items = [it for it in items if it["kind"] == "zone" and inb(it)]
    if label_zones:
        for g in cluster(zone_items, cl):
            e = sum(i["e"] for i in g) / len(g)
            n = sum(i["n"] for i in g) / len(g)
            col = CAT[g[0]["cat"]][1]
            label = short_label([i["name"].replace("TRN_", "") if kb else i["name"] for i in g])
            texts.append(ax.text(e, n, label, ha="center", va="top", fontsize=8 if kb else 7.5, color=col,
                                 fontweight="bold", bbox=dict(boxstyle="round,pad=0.15", fc="white", ec=col, alpha=0.9, lw=0.6),
                                 zorder=6))

    # Einheiten und Strukturen
    pts = [it for it in items if it["kind"] != "zone" and inb(it)]
    for it in pts:
        col = CAT[it["cat"]][1]
        hollow = it["late"]
        ax.plot(it["e"], it["n"], marker=MARKER.get(it["kind"], "o"), color=col, markersize=7,
                markerfacecolor="none" if hollow else col, markeredgewidth=1.5, zorder=5)
    if label_items and not kb:
        for g in cluster(pts, cl):
            e = sum(i["e"] for i in g) / len(g)
            n = sum(i["n"] for i in g) / len(g)
            col = CAT[g[0]["cat"]][1]
            texts.append(ax.text(e, n, short_label([i["name"] for i in g]), ha="left", va="bottom", fontsize=7, color=col,
                                 bbox=dict(boxstyle="round,pad=0.12", fc="white", ec=col, alpha=0.9, lw=0.5), zorder=7))

    if texts:
        adjust_text(texts, ax=ax, arrowprops=dict(arrowstyle="-", color="#666666", lw=0.6), expand=(1.3, 1.5),
                    force_text=(0.6, 0.8), max_move=(40, 40))

    # Legende
    used = {it["cat"] for it in items if inb(it)}
    handles = []
    for key, (label, col) in CAT.items():
        if key in used:
            if key.startswith("zone"):
                handles.append(Line2D([0], [0], color=col, lw=2, ls="--", label=label))
            else:
                handles.append(Line2D([0], [0], marker="o", color=col, lw=0, markersize=7, label=label))
    handles.append(Line2D([0], [0], marker="o", color="#444", lw=0, markerfacecolor="none", markersize=7, label="hohl = Late Activation (Vorlage)"))
    handles.append(Line2D([0], [0], marker="*", color="#555", lw=0, markersize=12, label="Flugplatz"))
    if kb:
        ax.tick_params(labelsize=7)
        ax.ticklabel_format(style="plain")
        fig.tight_layout(pad=0.4)
        fig.savefig(outpath, dpi=100)
        plt.close(fig)
        return outpath

    ax.legend(handles=handles, loc="upper left", fontsize=8, framealpha=0.9)

    ax.set_title(title + "\n(keine Gelaendekarte; Kueste und Strassen nicht eingezeichnet; Positionen sind Platzhalter)", fontsize=11)
    ax.set_xlabel("Ost (DCS y, Meter)")
    ax.set_ylabel("Nord (DCS x, Meter)")
    ax.ticklabel_format(style="plain")
    fig.tight_layout()
    fig.savefig(OUT / fname, dpi=130)
    plt.close(fig)
    print("geschrieben:", OUT / fname)

def write_table(items):
    lines = ["# Objektliste der Trainingsmission", "",
             "Alle Positionen sind **Platzhalter** (siehe README, Kapitel 9). DCS-Koordinaten: x = Nord, y = Ost (Meter).", ""]
    titles = {
        "zone": "Triggerzonen", "vehicle": "Bodeneinheiten", "air": "Luftfahrzeuge", "ship": "Schiffe", "static": "Statische Objekte",
    }
    for kind, title in titles.items():
        rows = [i for i in items if i["kind"] == kind]
        if not rows:
            continue
        lines += [f"## {title} ({len(rows)})", ""]
        if kind == "zone":
            lines += ["| Name | Gruppe | Radius (m) | x (Nord) | y (Ost) | Breite | Laenge |", "|---|---|---|---|---|---|---|"]
            for i in sorted(rows, key=lambda r: r["name"]):
                lines.append(f"| `{i['name']}` | {CAT[i['cat']][0].split(':')[1].strip()} | {int(i['radius'])} | {i['n']:.0f} | {i['e']:.0f} | {i['lat']:.4f} | {i['lng']:.4f} |")
        else:
            lines += ["| Name | Verwendung | Koalition | Typ | Late Act. | x (Nord) | y (Ost) | Breite | Laenge |", "|---|---|---|---|---|---|---|---|---|"]
            for i in sorted(rows, key=lambda r: (r["cat"], r["name"])):
                lines.append(f"| `{i['name']}` | {CAT[i['cat']][0]} | {i['side']} | {i['types']} | {'ja' if i['late'] else ''} | {i['n']:.0f} | {i['e']:.0f} | {i['lat']:.4f} | {i['lng']:.4f} |")
        lines.append("")
    (OUT / "objekte.md").write_text("\n".join(lines), encoding="utf-8")
    print("geschrieben:", OUT / "objekte.md")

def render_all(items, airports):
    OUT.mkdir(parents=True, exist_ok=True)
    # Grenzen: (Ost min, Ost max, Nord min, Nord max)
    draw(items, airports, (360000, 960000, -380000, -100000), "Uebersicht: alle Zonen", "01_uebersicht.png",
         label_items=False, cluster_m=14000, figsize=(17, 9))
    draw(items, airports, (600000, 715000, -365000, -240000), "West-Georgien: Range, Bodenangriff, JTAC, CTLD, CSAR, Konvois, Flugplaetze",
         "02_west_georgien.png", cluster_m=2600, figsize=(15, 13))
    draw(items, airports, (370000, 640000, -370000, -150000), "Schwarze Meer: Traeger, Schiffe, Intercept-Gebiet",
         "03_schwarzes_meer.png", cluster_m=9000, figsize=(15, 12))
    draw(items, airports, (665000, 775000, -318000, -252000), "Osten von Kutaisi: SEAD/DEAD-Gebiet (ca. 30 nm)",
         "04_ost_sead.png", cluster_m=2500, figsize=(15, 9))
    draw(items, airports, (740000, 860000, -160000, -115000), "Norden (Beslan bis Nalchik): feindlicher Konvoi",
         "05_nord_konvoi.png", cluster_m=3000, figsize=(14, 9))
    write_table(items)

def render_kneeboard_maps(items, airports, outdir):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    result = {}
    for key, (bounds, cl) in {
        "overview": ((380000, 850000, -370000, -110000), 6000),
        "west": ((600000, 715000, -365000, -240000), 2800),
        "sea": ((370000, 640000, -370000, -150000), 9000),
    }.items():
        e0, e1, n0, n1 = bounds
        w_in = 7.48
        h_in = w_in * (n1 - n0) / (e1 - e0) + 0.3
        result[key] = draw(items, airports, bounds, "", "", cluster_m=cl, figsize=(w_in, h_in), kb=True,
                           outpath=outdir / f"map_{key}.png")
    return result

def main():
    miz = Path(sys.argv[1]) if len(sys.argv) > 1 else MIZ
    items, airports = load(miz)
    render_all(items, airports)

if __name__ == "__main__":
    main()
