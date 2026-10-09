-- 99_init.lua
-- Wird als LETZTES geladen: prueft die Abhaengigkeiten, initialisiert Flugplatzbetrieb (RAT) und
-- Konvois und startet das Menue.
--
-- Hinweis: Diese Mission verwendet keine Carrier (AIRBOSS), CTLD oder CSAR.
-- Die Zonen (SEAD, STRIKE, AG, COMBINED) werden in ihren Modulen ueber
-- TRN.RegisterZone(def) registriert. 99_init.lua ladt sie nicht erneut.
-- Range/Airboss-Soundordner und der CSAR-Funkfeuer-Ton sind nur in der .miz enthalten,
-- wenn das Build-Tool die Moose-Soundpakete erhaelt. Ohne sie laeuft die Mission mit Text-Ansagen.

TRN = TRN or {}
local CFG = TRN.CFG

local function fatal(msg)
  TRN.Error("%s", msg)
  -- Im Test-Hauptteil ist dies die Fehlerausgabe
end

if not mist then
  fatal("MIST not loaded (load mist.lua first).")
elseif not (SPAWN and MENU_GROUP and GROUP and COORDINATE) then
  fatal("Moose not loaded (load Moose.lua before the scripts).")
elseif not TRN.RegisterZone or not TRN.Audio or not TRN.Menu then
  fatal("Script order wrong: 00_config, 01_core, 02_audio, 03_menu, zones, 99_init.")
else
  -- Zufallsgenerator: In der DCS-Missionsandbox fehlen os und (je nach Version) math.randomseed.
  -- Deshalb nur wenn vorhanden seeden, sonst die Folge um eine zeitabhaengige Anzahl Werte weiterdrehen.
  if math.randomseed then
    math.randomseed(math.floor(timer.getTime() * 1000) + math.floor(timer.getAbsTime()))
  end
  for _ = 1, 5 + (math.floor(timer.getAbsTime()) % 89) do math.random() end

  -- Nur Groesseren Initialisierungen
  local ok, err = pcall(TRN.Rat_Init)
  if not ok then TRN.Error("RAT init: %s", tostring(err)) end

  ok, err = pcall(TRN.Convoys_Init)
  if not ok then TRN.Error("Convoys init: %s", tostring(err)) end

  -- Alles aufräumen? Nein -- alle Zonen registrieren (im Modulen via TRN.RegisterZone)
  TRN.Menu.Start()
  TRN.Log("Caucasus strike v%s ready (%d zones)", CFG.VERSION, #TRN.ZoneOrder)
end
