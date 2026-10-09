# Caucasus Strike (CAUCASUS_STRIKE) — Training Mission for DCS World

A fast, compact, and deliberately non-boring strike campaign for **Digital Combat Simulator** on the **Caucasus** map.
Four independent zones, built with **Moose** + **MIST** + **CTLD**, all on **BLUE/USA** vs **RED/Russia**:

| Zone | Exercise | Aircraft | Difficulty |
|------|----------|----------|------------|
| 1 | **SEAD / DEAD** (suppress/destroy a Red SAM site) | F/A-18C, F-16C | EASY / MEDIUM / HARD |
| 2 | **Strike** (bomb a fixed target set, 2/4/6 targets) | F/A-18C, F-16C | EASY / MEDIUM / HARD |
| 3 | **Air-to-Ground** (destroy a Red armoured column on the road) | AH-64D, Mi-24P | EASY / MEDIUM / HARD |
| 4 | **Combined** (choose SEAD or STRIKE; live Red defence) | F/A-18C, F-16C, AH-64D, Mi-24P | EASY / MEDIUM / HARD |

## Story — "Operation Iron Arrow"

The Caucasus has been quiet for months. Then, three weeks ago, a Red **fire-group** — SA-2/3, SA-6/SA-11, and a ZSU-23 AAA battery — slipped across the border near Senaki and began shooting intelligence and search aircraft into Georgian airspace. The pilots called it "the Iron Triangle": a SAM site on the high plateau, a radar picket in the hills, and a heavy AAA battery in a mountain bowl, all feeding on each other. The Western command withdrew the AWACS, and for a week there was no air traffic over the whole eastern half of the range.

Now the command wants it back.

**Day 1 – The Decapitation.** Four flights, all from the same base, fly in on the same morning. The F/A-18C and F-16C strike first at the **SEAD/DEAD** site: whichever of them elects SEAD must silence the radars before the mission can continue. The commander wants it done in one pass, but he knows the SAMs will fight back — "Threat radar detected" at 45 km, "Missile launch" when the site fires. If the site gets through, the strike flight loses the window.

**Day 1 – The Bearer.** The AH-64D and Mi-24P go next, into the **Air-to-Ground** zone. Red has split a heavy armoured column and driven it along a road that runs between two hills, hidden in the morning fog. The helicopters hover in the valley, sting the column with rockets and cannons, and push it toward the end line. This zone is unforgiving: every vehicle destroyed is a momentum point, and the last vehicle to cross the end line ends the round. Friends call it "the column run."

**Day 2 – The Foreign Legion.** The **Strike** zone is the school exercise: two aircraft, six pre-programmed targets, and no mercy. The targets are fixed: a radar junction, a fuel depot, a bridge, a landing strip, a command post, and a logistics point. Each is worth one of the "six marks." The pilots remember the Iron Arrow's price — three strike missions, six targets each, no rescues, no second chances. It is the teacher's lesson before the real war.

**Day 2 – The Old Guard.** The **Combined** zone is the capstone and the most dangerous. A small box in the centre of the map: a Red SAM site, a moving armoured column, and a AAA battery, all inside ~8 km. Each flight chooses its role — one SEADs the site, the other bombs the column — and the zone turns live: Red SAMs launch, the column advances, the AAA returns fire. It is the mission you fly for the real thing. "If you survive this one, you own the Western Caucasus."

### The Golden Rules

1. **SEAD first.** The SAM site is always the choke point. Silence it, or the strike and ground attack zones are bought with blood.
2. **One flight per zone.** The zone is yours until you stop it or the round times out.
3. **Watch the road.** In Air-to-Ground, the column will drift off the road. A vehicle off the road is a vehicle that walks free.
4. **Combined is a team game.** You can't win by bombing everything at once. Coordinate with your wingman: one distracts, one bombs.

### Frequencies (all aircraft, fixed clear weather)

- All airfields: UHF/VHF ATC on the airfields (see kneeboard).
- JTAC laser code **1688**, JTAC FM **40.40 FM**.
- Marshal **305.0 AM** / LSO **264.0 AM** (only if carrier status is used).
- Range Control **256.0 AM**, Instructor **257.0 AM** (for Zone 1 Range).

### Aircraft roles

| Aircraft | Role | Zones |
|----------|------|-------|
| F/A-18C Hornet | SEAD / DEAD, Strike, Combined | 1, 2, 4 |
| F-16C 50 | SEAD / DEAD, Strike, Combined | 1, 2, 4 |
| AH-64D Block II | Air-to-Ground, Combined | 3, 4 |
| Mi-24P | Air-to-Ground, Combined | 3, 4 |

## Mission Editor Guide (README)

### 0. Prerequisites

- **DCS World** with the map **Caucasus** (not empty).
- **pydcs** + **matplotlib** + **adjustText** + **mgrs** + **pillow** (to build the mission offline):
  `pip install pydcs matplotlib adjustText mgrs pillow`
- **lua5.1** (the build tool reads `scripts/00_config.lua`);
- **`libs/mist.lua` and `libs/Moose.lua`** (not in the repo; download them from `mrSkortch/MissionScriptingTools` and
  `FlightControl-Master/MOOSE_INCLUDE`). CTLD and CSAR come from Moose itself, no separate `CTLD.lua` is needed.
- Moose sound packages (optional): clone `https://github.com/FlightControl-Master/MOOSE_SOUND` and pass
  `--sounds-dir /path/to/MOOSE_SOUND` to rebuild the sound folders into the `.miz` zip.

### 1. Layout of the package

```
caucasus-strike/
├── README.md                          ← this file
├── scripts/
│   ├── 00_config.lua                  ← single source of truth (names, freqs, levels, timeouts, messages)
│   ├── 01_core.lua                    ← logging, geometry, player groups, spawn, zone manager
│   ├── 02_audio.lua                   ← announcement queue
│   ├── 03_menu.lua                    ← F10 menu per player group
│   ├── 10_sead.lua                    ← Zone 1 SEAD/DEAD
│   ├── 20_strike.lua                  ← Zone 2 Strike
│   ├── 30_ag.lua                      ← Zone 3 Air-to-Ground
│   ├── 40_cc.lua                      ← Zone 4 Combined
│   ├── 50_ctld.lua                    ← Zone 5 Transport (Moose CTLD)
│   ├── 60_csar.lua                    ← Zone 6 CSAR (Moose CSAR), mission action "shootdown"
│   ├── 70_mission.lua                 ← mission mode: autostart, win/fail flags
│   ├── missions/<ID>.lua              ← generated by tools/build_missions.py (TRN.MISSION)
│   ├── 80_ambient.lua                 ← KI-Flugverkehr (RAT) und Konvois
│   └── 99_init.lua                    ← initializer (loads last)
├── libs/                              ← mist.lua, Moose.lua (not in the repo)
├── tools/
│   ├── build_miz.py                   ← build the training .miz, render maps, check_names gate
│   ├── build_missions.py              ← build the campaign missions (.miz), verify them
│   ├── missions.py                    ← mission definitions (single source for slots, briefing, goals)
│   ├── mission_builder.py             ← script trigger, slots, goals for one mission
│   ├── kneeboards.py                  ← German kneeboard pages per mission and aircraft
│   ├── briefing.py                    ← briefing text, flight plans, kneeboard pages (training mission)
│   ├── plot_map.py                    ← zone/unit maps + objekte.md
│   └── types_extra.py                 ← type extensions (CH-47F placeholder)
├── mission/
│   ├── DCS_CaucasusStrike.miz         ← built mission (positions are placeholders)
│   ├── map/                           ← overview maps + objekte.md
│   └── kneeboard/                     ← per-aircraft PNG pages
└── tests/
    ├── mock_test.lua                  ← no-DCS logic test → expect "0 Fehler"
    ├── ambient_test.lua               ← RAT and convoys
    └── missions_test.lua              ← generated mission files vs. config
```

### 2. Load order (Mission Editor trigger)

`tools/build_missions.py` creates a **Trigger → MISSION START** with **16 × DO SCRIPT FILE** in exactly this order:

1. `libs/mist.lua`
2. `libs/Moose.lua`
3. `scripts/00_config.lua`
4. `scripts/01_core.lua`
5. `scripts/02_audio.lua`
6. `scripts/03_menu.lua`
7. `scripts/10_sead.lua`
8. `scripts/20_strike.lua`
9. `scripts/30_ag.lua`
10. `scripts/40_cc.lua`
11. `scripts/50_ctld.lua`
12. `scripts/60_csar.lua`
13. `scripts/missions/<ID>.lua`  ← sets `TRN.MISSION`
14. `scripts/70_mission.lua`
15. `scripts/80_ambient.lua`
16. `scripts/99_init.lua`  ← **must run last**


`99_init.lua` checks that the libraries are loaded and seeds the random generator; it then initializes the
RAT (KI flight traffic) and Convoys. All zone modules register themselves via `TRN.RegisterZone(def)`.
Any failure before `99_init.lua` aborts the mission.

### 3. Player slots (BLUE/USA, 2 per aircraft)

`tools/build_missions.py` creates the client slots (hot start) with preloaded flight plans for the types of each mission:

| Label | Aircraft | Airbase |
|-------|----------|---------|
| F-18C Client 1–2 | F/A-18C Hornet | Kobuleti |
| F-16C Client 1–2 | F-16C 50 | Kobuleti |
| A-10C II Client 1–2 | A-10C II | Kobuleti |
| AH-64D Client 1–2 | AH-64D Block II | Senaki-Kolkhi |
| Mi-24P Client 1–2 | Mi-24P | Senaki-Kolkhi |

All slots belong to **BLUE/USA**. The helicopter slot names start with `Mi-24P Client` / `AH-64D Client`; the CTLD and
CSAR prefixes in `00_config.lua` (`pilotPrefixes`, `heliPrefixes`) depend on that.

### 4. Mission Editor checklist (the object-presence oracle)

The build tool `check_names()` asserts that every `TRN_` name from `scripts/00_config.lua` appears in the
mission. Before you save, verify in the Mission Editor:

**Trigger zones** (Right-click → Trigger Zone; exact names, case-sensitive):

| Name | Radius (m) | Context |
|------|-----------|---------|
| `TRN_SE_ZONE` | 3000 | SEAD/DEAD site area |
| `TRN_ST_ZONE` | 3000 | Strike target area |
| `TRN_AG_ZONE` | 3000 | Air-to-Ground target area |
| `TRN_AG_START` | 1000 | Convoy start (on a road) |
| `TRN_AG_END` | 1000 | Convoy end (on a road, ≥ 8 km from start) |
| `TRN_CC_ZONE` | 8000 | Combined campaign box |
| `TRN_CTLD_LOAD` | 400 | Zone 5: troops are loaded here (near Senaki-Kolkhi) |
| `TRN_CTLD_DROP` | 400 | Zone 5: troops are deployed here (outpost) |
| `TRN_CSAR_ZONE` | 1500 | Zone 6: the downed crew is placed here |
| `TRN_MASH` | 500 | Zone 6: rescue station (prefix used by Moose CSAR) |

**Late Activation template groups** (check the Late Activation box; the **group name** matters, not the unit name):

- Zone 1 SEAD: `TRN_SAM_SA2`, `TRN_SAM_SA3`, `TRN_SAM_SA6`, `TRN_SAM_SA11`, `TRN_SAM_SA8`, `TRN_SAM_SA15`, `TRN_SAM_ZSU23`
- Zone 2 Strike: `TRN_ST_OBJ_1`…`TRN_ST_OBJ_6`, `TRN_ST_AAA_1`, `TRN_ST_AAA_2`
- Zone 3 Air-to-Ground: `TRN_AG_VEH_1`…`TRN_AG_VEH_4`, `TRN_AG_AAA_1`
- Zone 4 Combined: `TRN_CC_OBJ_1`…`TRN_CC_OBJ_4`, `TRN_CC_AAA_1`, `TRN_CC_AAA_2`
- Zone 5 Transport: `TRN_CTLD_TROOPS` (infantry, troops template)
- Zone 6 CSAR: `TRN_CSAR_PILOT` (single infantry, downed crew template)
- Ambient: `TRN_CONVOY_BLUE_1/2`, `TRN_CONVOY_RED_1/2`, `TRN_RAT_C130`, `TRN_RAT_AN26`

**Static objects** (the name is the unit name):

- Airfield static scene: `TRN_STATIC_*`, `TRN_AIRFIELD_*`

**Units** (the name is the unit name):

- `TRN_CARRIER` (the Stennis carrier — used only for position; the carrier route is in the build tool)
- Player slot aircraft use the slot names, not unit names.

### 5. Coordinates and landscape notes

All coordinates in the build tool are **placeholders**. Open the built `.miz` and verify each zone:

| Zone | Location | Check |
|------|----------|-------|
| 1 SEAD | ~30 nm east of Kutaisi | Open terrain, ~3 km radius; SAM radar range (≤ 32 km) must not reach the other zones |
| 2 Strike | Between Senaki and Kutaisi (NE of the Range) | Open terrain; ≥ 15 km from the Range zone |
| 3 Air-to-Ground | Zone 3, on a road | `TRN_AG_START` and `TRN_AG_END` on the **same road**; start/end ≥ 8 km apart |
| 4 Combined | Small box in the west / centre | ~8 km radius; everything inside one compact area |

If a zone falls in mountains or water, move it in the Mission Editor. **The zone names must not change.**

### 6. Flight plans (preloaded)

Flight plan route per aircraft (A = radar altitude AGL, BARO = barometric MSL):

| Aircraft | Route |
|----------|-------|
| F/A-18C | SEAD ZONE → ST STRIKE → AND ZONE → CC ZONE |
| F-16C | SEAD ZONE → ST STRIKE → AND ZONE → CC ZONE |
| AH-64D | AND ZONE → SEAD ZONE → ST STRIKE → CC ZONE |
| Mi-24P | AND ZONE → SEAD ZONE → ST STRIKE → CC ZONE |

Takeoff/landing at Koboulti (F/A-18C, F-16C) or Senaki-Kolkhi (AH-64D, Mi-24P). All points are optional:
fly the zones you need, skip the rest.

### 7. Kneeboards (in the `.miz`)

Each aircraft has a kneeboard with **5–6 pages**:

- **Page 1 – Frequencies**: airfields (UHF/VHF ATC), frequencies of the zones, ST, AG, CC.
- **Page 2 – Zones**: MGRS (100 m) and lat/long for every zone, AG_START, AG_END.
- **Page 3 – Route**: preloaded flight plan, with altitudes, speed, MGRS.
- **Pages 4–5 – Procedures**: how to fly the zone (SEAD, STRIKE, AG, CC) and the difficulty table.
- **Page 6 – Maps**: overview (full Caucasus) and west (Georgia).

### 8. Sounds

No custom sounds. The mission uses the Moose sound packages where they exist (Range and Airboss).
All other announcements are on-screen English text. If you rebuild the mission with `--sounds-dir`, the
`Range Soundfiles/` and `Airboss Soundfiles/` folders are appended to the `.miz` zip.

### 9. Verification

- **Logic test without DCS:** `lua5.1 tests/mock_test.lua` → expect `0 Fehler`.
- **Object-presence check:** `python3 tools/build_miz.py --sounds-dir MOOSE_SOUND` → prints
  `Namenspruefung: N von M TRN_-Namen aus 00_config.lua in der Mission` and exits 1 if any `TRN_` name is missing.
- **Map regeneration:** `python3 tools/plot_map.py` → `mission/map/*.png` + `objekte.md`.

### 10. Known limitations and assumptions

- No custom sounds; no weather change (fixed clear).
- Weather/time are fixed (21.06.2024, 10:00, clear, light wind).
- The carrier (TRN_CARRIER) is placed only as a positional aid; the mission does not use Carrier recovery.
- Difficulty levels scale target count, escort presence, and speed. Timeouts: Zone 1 = 1800 s,
  Zone 2 = 1800 s, Zone 3 = 1500 s, Zone 4 = 2400 s.
- Names are exact (case-sensitive) in config, editor, and builder. One typo skips a zone or spawns the wrong template.

## Campaign missions (Operation Iron Arrow)

Single missions of the campaign, built by `python3 tools/build_missions.py` into `mission/missions/`. The campaign
file (`.cmp`) is **not** generated; chain the missions yourself in the DCS Campaign Builder.

| ID | Mission | Aircraft | Objectives |
|----|---------|----------|------------|
| T-J | Tutorial Jets | F/A-18C, F-16C, A-10C II | exercise from the F10 menu (no goals) |
| T-H | Tutorial Helis | AH-64D, Mi-24P | exercise from the F10 menu (no goals) |
| S1 | Auftakt | all | Combined EASY (jets), Air-to-Ground EASY |
| J1 | Radarblindheit | jets | SEAD EASY |
| J2 | Nachschubbrücke | jets | Strike MEDIUM, Air-to-Ground MEDIUM |
| J3 | Hammerschlag | jets | SEAD HARD, Strike HARD |
| H1 | Tal der Kolonne | helicopters | Air-to-Ground EASY |
| H2 | Frontlogistik | helicopters | Transport (CTLD) MEDIUM: 8 troops |
| S2 | Wendepunkt | all | Combined MEDIUM (jets), Air-to-Ground MEDIUM; a crew is shot down after 7 min |
| H3 | Falke down | helicopters | CSAR HARD |
| S3 | Entscheidung | all | Combined HARD (jets), Air-to-Ground HARD, Transport MEDIUM (helicopters) |

- **Mission mode:** objectives start automatically after the first player is present (`startDelay`), one round, no
  restart, no F10 start menu. Objectives with `forTypes` only apply if a player of such an aircraft type is present,
  so shared missions stay solvable solo.
- **Result for your campaign:** user flag `TRN_<ID>_WIN` or `TRN_<ID>_FAIL` is set to 1 (failure: an objective failed,
  a vehicle reached the end line, time expired, or all players are lost). Every mission has a Mission Goal
  (BLUE, score 100) on `TRN_<ID>_WIN` (`c_flag_is_true`). The mission does not end by itself; end it from the
  F10/ESC menu after the debrief message.
- **Not verified in DCS:** whether DCS evaluates the string flag in the goal, the Moose CTLD/CSAR behaviour and all
  coordinates (placeholders in `tools/build_miz.py`, `POS`).

## Build and verification

```bash
# 0. Dependencies and libraries (libs/mist.lua, libs/Moose.lua)
pip install pydcs matplotlib adjustText mgrs pillow

# 1. Build the campaign missions (writes scripts/missions/<ID>.lua, mission/missions/*.miz, mission/kneeboard/)
python3 tools/build_missions.py

# 2. Optional: the older single training mission with maps
python3 tools/build_miz.py --sounds-dir /path/to/MOOSE_SOUND
python3 tools/plot_map.py

# 3. Logic tests without DCS
lua5.1 tests/mock_test.lua
lua5.1 tests/ambient_test.lua
lua5.1 tests/missions_test.lua
```
