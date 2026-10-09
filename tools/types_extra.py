"""Typen, die pydcs 0.15 nicht kennt (damit build_miz.py und plot_map.py sie gemeinsam nutzen).

Für diese Mission (F/A-18C, F-16C, AH-64D, Mi-24P) sind keine zusätzlichen Typen nötig, weil alle
Flugzeug-/Hubschrauber-Typen in pydcs 0.15 vorhanden sind (FA_18C_hornet, F_16C_50, AH_64D_BLK_II,
Mi_24P). Dieses Modul ist ein Platzhalter für die Erweiterung (z. B. CH-47F).
"""

from dcs import helicopters, task

# Der CH-47F wird nicht benoetigt - nur als Dokumentation und Fallback fuer zukuenftige Module.
class CH_47Fbl1(helicopters.HelicopterType):
    id = "CH-47Fbl1"
    flyable = True
    large_parking_slot = True
    height = 5.9
    width = 18.3
    length = 30.1
    fuel_max = 2500
    max_speed = 300
    chaff = 120
    flare = 120
    charge_total = 240
    chaff_charge_size = 1
    flare_charge_size = 1
    pylons = set()
    tasks = [task.Transport]
    task_default = task.Transport

# Not needed: helicopters.helicopter_map["CH-47Fbl1"] = CH_47Fbl1
