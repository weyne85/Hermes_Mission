-- 00_config.lua
-- CAUCASUS STRIKE - campaign config
-- ALLE Namen (Zonen, Gruppen, Einheiten), Frequenzen, Schwierigkeitsstufen, Zeiten, Ansagen.
-- Aenderungen an der Mission erfordern nur Anpassungen in dieser Datei.
-- Laedt nach mist, Moose, CTLD-i18n, CTLD und vor allen anderen scripts/.

TRN = TRN or {}

TRN.CFG = {
  VERSION = "1.0",
  DEBUG = false,                      -- true: zusaetzliche Log-Eintraege in dcs.log

  SIDE = (coalition or {}).side or { BLUE = 2 },

  -- Sounds: nur Moose-Soundpakete (Range, Airboss). Alle anderen Ansagen als Text.
  -- Ordner stehen im .miz-Archiv (Range/Airboss Soundfiles, beacon.ogg).
  RANGE_SOUND_FOLDER = "Range Soundfiles/",
  AIRBOSS_SOUND_FOLDER = "Airboss Soundfiles/",

  MAG_VAR = 0,                        -- Korrektur in Grad, auf ALLE Peilungen addiert. 0 = rechtweisend (true)

  MENU_ROOT = "Training Zones",
  MENU_SCAN = 3,                      -- Sekunden zwischen den Pruefungen auf neue Spieler
  TICK = 5,                           -- Sekunden zwischen Zonen-Pruefungen
  RESTART_DELAY = 20,                 -- Sekunden nach erfolgreicher Runde bis zur naechsten
  LEVELS = { "EASY", "MEDIUM", "HARD" },

  -- ================================================================
  -- Zone 1: SEAD / DEAD  (F/A-18C oder F-16C)
  -- ================================================================
  SEAD = {
    id = "SEAD",
    title = "1 SEAD / DEAD",
    zone = "TRN_SE_ZONE",              -- Triggerzone: SAM-Stellung
    roundTimeout = 1800,               -- Sekunden je Runde, danach Abbruch
    modes = { "SEAD", "DEAD" },        -- SEAD: Radare ausschalten/zerstoeren, DEAD: alles zerstoeren
    spawnRingKm = 30,                  -- Distanz vom Zonenmittelpunkt, auf der der SAM-Template startet
    spawnAltM = { 4000, 8000 },        -- Starthoehe in Metern (min, max)
    threatWarnRangeKm = 45,            -- ab dieser Entfernung meldet "Threat radar" (einmalig je Runde)
    levels = {
      EASY   = { main = { "TRN_SAM_SA2", "TRN_SAM_SA3" }, escorts = {} },
      MEDIUM = { main = { "TRN_SAM_SA6", "TRN_SAM_SA11" }, escorts = { "TRN_SAM_ZSU23" } },
      HARD   = { main = { "TRN_SAM_SA8" }, escorts = { "TRN_SAM_SA15", "TRN_SAM_ZSU23" } },
    },
    radarAttributes = { "SAM SR", "SAM TR" },  -- Unit-Attribute, die als "Radar" zaehlen (SEAD-Ziel)
  },

  -- ================================================================
  -- Zone 2: Strike  (F/A-18C + F-16C)
  -- ================================================================
  STRIKE = {
    id = "STRIKE",
    title = "2 Strike",
    zone = "TRN_ST_ZONE",              -- Triggerzone: Zielgebiet
    roundTimeout = 1800,               -- Sekunden je Runde
    goodHitM = 25,                     -- Trefferradius der Bomben in Metern
    levels = {
      EASY   = { targets = { "TRN_ST_OBJ_1", "TRN_ST_OBJ_2" },   escorts = {} },
      MEDIUM = { targets = { "TRN_ST_OBJ_1", "TRN_ST_OBJ_2", "TRN_ST_OBJ_3", "TRN_ST_OBJ_4" },
                 escorts = { "TRN_ST_AAA_1" } },
      HARD   = { targets = { "TRN_ST_OBJ_1", "TRN_ST_OBJ_2", "TRN_ST_OBJ_3", "TRN_ST_OBJ_4",
                             "TRN_ST_OBJ_5", "TRN_ST_OBJ_6" },
                 escorts = { "TRN_ST_AAA_1", "TRN_ST_AAA_2" } },
    },
  },

  -- ================================================================
  -- Zone 3: Air-to-Ground  (AH-64D + Mi-24P)
  -- ================================================================
  AG = {
    id = "AG",
    title = "3 Air-to-Ground",
    zone = "TRN_AG_ZONE",              -- Triggerzone: Zielgebiet
    roundTimeout = 1500,               -- Sekunden je Runde
    startZone = "TRN_AG_START",        -- Triggerzone: Startpunkte der Zielfahrzeuge (an einer Straße)
    endZone = "TRN_AG_END",            -- Triggerzone: Ziel (an einer Straße, >= 8 km von Start)
    levels = {
      EASY   = { pool = { "TRN_AG_VEH_1", "TRN_AG_VEH_2" }, count = 1,  escorts = {} },
      MEDIUM = { pool = { "TRN_AG_VEH_1", "TRN_AG_VEH_2", "TRN_AG_VEH_3" }, count = 2, escorts = {} },
      HARD   = { pool = { "TRN_AG_VEH_1", "TRN_AG_VEH_2", "TRN_AG_VEH_3", "TRN_AG_VEH_4" }, count = 2,
                 escorts = { "TRN_AG_AAA_1" } },
    },
  },

  -- ================================================================
  -- Zone 4: Combined  (alle 4 Flugzeuge)
  -- ================================================================
  COMBINED = {
    id = "COMBINED",
    title = "4 Combined",
    zone = "TRN_CC_ZONE",              -- Triggerzone (ganzer Kampfbox)
    roundTimeout = 2400,               -- Sekunden je Runde
    modes = { "SEAD", "STRIKE" },      -- Farbe der Aufgabe: SEAD oder STRIKE
    spawnRingKm = 25,                  -- Distanz vom Zonenmittelpunkt, auf der die Gegner starten
    spawnAltM = { 3000, 6000 },        -- Starthoehe in Metern
    awacsCallsign = "Magic",           -- AWACS-Callsign
    awacsInterval = 30,                -- Sekunden zwischen "Bogey Dope"-Ansagen
    levels = {
      EASY   = { sead = { "TRN_SAM_SA2" }, targets = { "TRN_CC_OBJ_1", "TRN_CC_OBJ_2" },  escorts = {} },
      MEDIUM = { sead = { "TRN_SAM_SA6" }, targets = { "TRN_CC_OBJ_1", "TRN_CC_OBJ_2", "TRN_CC_OBJ_3" },
                 escorts = { "TRN_CC_AAA_1" } },
      HARD   = { sead = { "TRN_SAM_SA8" }, targets = { "TRN_CC_OBJ_1", "TRN_CC_OBJ_2", "TRN_CC_OBJ_3", "TRN_CC_OBJ_4" },
                 escorts = { "TRN_CC_AAA_1", "TRN_CC_AAA_2" } },
    },
    radarAttributes = { "SAM SR", "SAM TR" },
  },

  -- ================================================================
  -- Beleben: Flugplatzbetrieb (Moose RAT), Militaerkonvois
  -- Notwendig fuer eine belebte Umgebung und die Flugplätze der Spieler.
  -- ================================================================
  AMBIENT = {
    id = "AMBIENT",
    title = "5 Convoys and Traffic",
    rat = {
      enabled = true,
      airfields = { "Kobuleti", "Senaki-Kolkhi", "Kutaisi", "Batumi" },
      flights = {
        { template = "TRN_RAT_C130", alias = "RAT C-130", count = 2, intervalSec = 600, delaySec = 120 },
        { template = "TRN_RAT_AN26", alias = "RAT An-26", count = 1, intervalSec = 900, delaySec = 420 },
      },
    },
    convoys = {
      {
        id = "blue_log", side = "BLUE", announce = false,
        templates = { "TRN_CONVOY_BLUE_1", "TRN_CONVOY_BLUE_2" },
        zones = { "TRN_CONV_A", "TRN_CONV_B", "TRN_CONV_C", "TRN_CONV_D" },
        speedKmh = { 30, 50 }, intervalSec = { 420, 900 }, firstDelaySec = { 60, 180 }, maxActive = 2, ttlSec = 1800,
      },
      {
        id = "red_raid", side = "RED", announce = true,
        templates = { "TRN_CONVOY_RED_1", "TRN_CONVOY_RED_2" },
        zones = { "TRN_CONV_RED_A", "TRN_CONV_RED_B" },
        speedKmh = { 30, 45 }, intervalSec = { 900, 1500 }, firstDelaySec = { 300, 600 }, maxActive = 1, ttlSec = 2400,
      },
    },
  },

  -- ================================================================
  -- Ansagen: Ereignis -> englischer Text und Anzeigedauer in Sekunden (Ueberlappungsschutz).
  -- Nur Text, keine eigenen Sounddateien.
  -- ================================================================
  MESSAGES = {
    -- allgemein
    welcome         = { dur = 5, text = "Welcome to the Caucasus strike campaign. Open the F10 menu, Training Zones, to select an exercise." },
    zone_busy       = { dur = 4, text = "Zone is busy with another flight. Try again later." },
    zone_stopped    = { dur = 3, text = "Exercise stopped. Zone cleaned up." },
    zone_timeout    = { dur = 4, text = "Time expired. Exercise ended." },
    -- zone SE
    se_briefing     = { dur = 6, text = "SEAD target in the area. Suppress or destroy as briefed." },
    se_radar        = { dur = 3, text = "Threat radar detected." },
    se_launch       = { dur = 3, text = "Missile launch! Missile launch!" },
    se_complete     = { dur = 5, text = "Objective complete. Air defence neutralized." },
    -- zone ST
    st_briefing     = { dur = 6, text = "Strike targets in the area. Bomb them as briefed." },
    st_hit          = { dur = 3, text = "Good bomb run. Target hit." },
    st_complete     = { dur = 5, text = "All strike targets destroyed." },
    -- zone AG
    ag_briefing     = { dur = 6, text = "Ground targets in the area. Destroy the convoy as briefed." },
    ag_hit          = { dur = 3, text = "Vehicle destroyed." },
    ag_complete     = { dur = 5, text = "Column destroyed. Air-to-ground exercise finished." },
    -- zone CC
    cc_briefing     = { dur = 6, text = "Combined threat in the area. Select SEAD or STRIKE via the F10 menu." },
    cc_splash       = { dur = 3, text = "Splash one." },
    cc_complete     = { dur = 5, text = "Objective complete. New round starting shortly." },
  },
}
