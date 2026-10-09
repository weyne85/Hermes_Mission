"""Missionsdefinitionen der Kampagne "Operation Iron Arrow" (reine Daten, keine DCS-Imports).

Einzige Quelle fuer:
  * scripts/missions/<ID>.lua   (wird von build_missions.py erzeugt: TRN.MISSION fuer 70_mission.lua)
  * Spieler-Slots und Wegpunkte, Briefing, Mission Goals in der .miz (tools/mission_builder.py)

Felder:
  id, title, slug     Kennung, Anzeigename, Dateiname-Anteil
  types               spielbare Muster (Schluessel aus mission_builder.TYPES)
  objectives          Aufgaben: zone = CFG-Zonen-ID (SEAD, STRIKE, AG, COMBINED), level = EASY/MEDIUM/HARD, mode (optional)
  startDelay          Sekunden zwischen erstem Spieler und Start der Aufgaben
  situation, task     Briefingtexte (Deutsch); threat wird an die Lage angehaengt
"""

JETS = ["FA-18C", "F-16C", "A-10C II"]
HELIS = ["AH-64D", "Mi-24P"]
ALL = JETS + HELIS

MISSIONS = {
    "S1": dict(
        id="S1", slug="Auftakt", title="Auftakt", types=ALL, startDelay=20,
        objectives=[dict(zone="COMBINED", level="EASY", mode="STRIKE"), dict(zone="AG", level="EASY")],
        situation=(
            "Operation Iron Arrow, Tag 1. Eine rote Kampfgruppe hat sich im Westen Georgiens eingenistet und "
            "beschiesst seit Wochen die Luftueberwachung. Die Koalition will den Luftraum zurueckgewinnen."),
        task=(
            "Gemeinsamer Einsatz aller Flugzeuge:\n"
            "- Jets: Kampfbox (Combined) bekaempfen. SAM-Stellung ausschalten und die Bodenziele zerstoeren.\n"
            "- Hubschrauber: Panzerkolonne auf der Strasse (Air-to-Ground) aufhalten, bevor sie die Endlinie erreicht.\n"
            "Die Mission ist erfolgreich, wenn alle Ziele zerstoert sind. Sie scheitert, wenn ein Fahrzeug die "
            "Endlinie erreicht, die Zeit ablaeuft oder alle Besatzungen verloren sind."),
        threat="Bedrohung: ein SAM-System (SA-2), leichte Flak.",
    ),
    "J1": dict(
        id="J1", slug="Radarblindheit", title="Radarblindheit", types=JETS, startDelay=15,
        objectives=[dict(zone="SEAD", level="EASY", mode="SEAD")],
        situation=(
            "Die rote Luftverteidigung blendet die Aufklaerung. Bevor die Kolonnen angegriffen werden koennen, "
            "muss die SAM-Stellung im Hochland ausgeschaltet werden."),
        task=(
            "SEAD/DEAD: Radare der SAM-Stellung ausschalten oder zerstoeren. F/A-18C und F-16C fliegen SEAD, "
            "die A-10C II sichert als Eskorte und bekaempft Flak. Abflug heiss in Kobuleti."),
        threat="Bedrohung: SA-2 oder SA-3. Warnung bei Radarerfassung und Raketenstart.",
    ),
    "J2": dict(
        id="J2", slug="Nachschubbruecke", title="Nachschubbruecke", types=JETS, startDelay=15,
        objectives=[dict(zone="STRIKE", level="MEDIUM"), dict(zone="AG", level="MEDIUM")],
        situation=(
            "Der rote Nachschub laeuft ueber eine Bruecke und ein Depot im Hinterland. Gleichzeitig rollt eine "
            "Kolonne auf der Strasse heran."),
        task=(
            "Strike auf Bruecke und Depot (Zielgebiet Strike). Die A-10C II bekaempft die Kolonne auf der Strasse "
            "(Air-to-Ground). Mission erfolgreich, wenn alle Ziele zerstoert sind."),
        threat="Bedrohung: Flak, ZSU-23. Fahrzeuge fahren mit 35 km/h.",
    ),
    "J3": dict(
        id="J3", slug="Hammerschlag", title="Hammerschlag", types=JETS, startDelay=15,
        objectives=[dict(zone="SEAD", level="HARD", mode="SEAD"), dict(zone="STRIKE", level="HARD")],
        situation=(
            "Die rote Kampfgruppe ist zur Verteidigung gezwungen. Das integrierte Luftabwehrnetz muss fallen, "
            "damit der Kommandoknoten bombardiert werden kann."),
        task=(
            "Zwei Aufgaben: SEAD/DEAD gegen das SAM-Netz und Strike auf den Kommandoknoten. F/A-18C und F-16C "
            "fuehren SEAD und Strike, die A-10C II raeumt die Flak."),
        threat="Bedrohung: SA-8, SA-15, ZSU-23 (dicht, niedrige Hoehe).",
    ),
    "H1": dict(
        id="H1", slug="Tal_der_Kolonne", title="Tal der Kolonne", types=HELIS, startDelay=15,
        objectives=[dict(zone="AG", level="EASY")],
        situation=(
            "Eine schwere Kolonne faehrt durch ein Tal, verdeckt vom Morgendunst. Sie darf die Endlinie nicht "
            "erreichen."),
        task=(
            "Air-to-Ground: Kolonne mit Raketen und Kanone zerstoeren, bevor ein Fahrzeug die Endlinie erreicht. "
            "Abflug heiss in Senaki-Kolkhi."),
        threat="Bedrohung: ZSU-23 in der Kolonne. Fahrzeuge fahren mit 20 km/h.",
    ),
}

ORDER = ["S1", "J1", "J2", "J3", "H1"]
