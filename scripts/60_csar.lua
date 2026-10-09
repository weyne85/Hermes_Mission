-- 60_csar.lua
-- Zone 6: CSAR (Moose CSAR). Eine abgeschossene Besatzung wird in TRN_CSAR_ZONE abgesetzt; Hubschrauber bergen sie
-- und bringen sie zum Flugplatz oder zur Rettungsstation (Zone mit Praefix TRN_MASH). Erfuellt bei "Rescued".
-- Zusaetzlich die Missions-Aktion "shootdown" (70_mission.lua, events): setzt eine Besatzung ab, ohne Pflichtziel.
-- Abhaengigkeiten: Moose (CSAR), 01_core.lua, 02_audio.lua. Die Moose-CSAR wird erst beim ersten Bedarf erzeugt.
-- Hinweis: Die Funkbake der Besatzung braucht beacon.ogg in der Mission (MOOSE_SOUND), sonst bleibt sie stumm.

TRN = TRN or {}
local CFG = TRN.CFG
local C = CFG.RESCUE

local def = { id = C.id, title = C.title, cfg = C }
local csar   -- Moose-CSAR-Instanz

function def.info()
  local z = TRN.ZoneInfo(C.pilotZone)
  local m = TRN.ZoneInfo(C.mash)
  if not z or not m then return "Zones '" .. C.pilotZone .. "' / '" .. C.mash .. "' are missing in the mission." end
  return string.format(
    "CSAR\nSearch area (MGRS): %s, radius %.1f nm. Rescue station (MGRS): %s.\n" ..
    "Find the downed crew, land close, let them board and bring them to the airfield or rescue station.\n" ..
    "MEDIUM and HARD: AAA around the crew.",
    TRN.MGRS(z.point, 3), TRN.ToNm(z.radius), TRN.MGRS(m.point, 3))
end

local function activeSession()
  local zone = TRN.Zones[C.id]
  local s = zone and zone.session
  if s and s.state == "RUN" then return s end
end

local function ensureCsar()
  if csar then return true end
  if not CSAR then return false, "Moose CSAR not loaded" end
  csar = CSAR:New(CFG.SIDE.BLUE, C.pilotTemplate, "Luftrettung")
  csar.useprefix = true
  csar.csarPrefix = C.heliPrefixes
  csar.mashprefix = { C.mash }
  csar.immortalcrew = true

  function csar:OnAfterPilotDown(From, Event, To, SpawnedGroup, Frequency, GroupName, CoordinatesText)
    local s = activeSession()
    if not s then return end
    if GroupName then
      s.data.pilotGroup = GroupName
      s:Track(GroupName)
    end
    s:Say("rs_down", string.format("%s. Frequency %s MHz. %s", C.pilotName,
      tostring(Frequency or "?"), tostring(CoordinatesText or "")))
  end

  function csar:OnAfterRescued(From, Event, To, HeliUnit, HeliName, PilotsSaved)
    local s = activeSession()
    if s then s.data.rescued = true end
  end

  csar:__Start(2)
  TRN.Log("CSAR started (prefixes: %s)", table.concat(C.heliPrefixes, ", "))
  return true
end

local function spawnPilot()
  csar:SpawnCSARAtZone(C.pilotZone, CFG.SIDE.BLUE, C.pilotName, true, false, C.pilotName, C.pilotType)
end

function def.OnRound(s)
  local lv = s.lv
  for _, name in ipairs({ C.pilotZone, C.mash }) do
    if not TRN.ZoneInfo(name) then return false, "Trigger zone '" .. name .. "' is missing" end
  end
  local ok, err = ensureCsar()
  if not ok then return false, err end

  s.data.rescued = false
  s.data.pilotGroup = nil
  for _, tpl in ipairs(lv.escorts or {}) do
    local vec2 = TRN.RandomPointInZone(C.pilotZone)
    if vec2 then
      local name = TRN.Spawn(tpl, vec2)
      if name then s:Track(name) end
    end
  end

  local okSpawn, spawnErr = pcall(spawnPilot)
  if not okSpawn then return false, "CSAR spawn failed: " .. tostring(spawnErr) end
  s:Say("rs_briefing", s:RoundTag())
  return true
end

function def.OnTick(s)
  if s.data.rescued then
    s:Say("rs_rescued", string.format("Round %d finished in %s.", s.rounds, s:ElapsedText()))
    return "done"
  end
  if s.data.pilotGroup and #TRN.GroupAliveUnits(s.data.pilotGroup) == 0 then
    s:Say("rs_lost")
    return "failed"
  end
end

TRN.RegisterZone(def)

-- Missions-Aktion: Besatzung wird abgeschossen (kein Pflichtziel)
TRN.MissionActions = TRN.MissionActions or {}
TRN.MissionActions.shootdown = function()
  local ok, err = ensureCsar()
  if not ok then TRN.Error("shootdown: %s", tostring(err)); return end
  if not TRN.ZoneInfo(C.pilotZone) then TRN.Error("shootdown: zone '%s' missing", C.pilotZone); return end
  TRN.Audio.TextAll(CFG.MESSAGES.mayday.text)
  local okSpawn, spawnErr = pcall(spawnPilot)
  if not okSpawn then TRN.Error("shootdown spawn: %s", tostring(spawnErr)) end
end
