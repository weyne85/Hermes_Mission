-- 80_ambient.lua
-- Belebte Umgebung: KI-Transportverkehr an den Flugplaetzen (Moose RAT) und schwache Konvois
-- (BLUE Logistik, RED Raids). Alle Werte stehen in TRN.CFG.AMBIENT (00_config.lua).
-- Stellt TRN.Rat_Init und TRN.Convoys_Init bereit; 99_init.lua ruft beide auf.
-- Registriert KEINE Zone (kein Eintrag im F10-Menue).
-- Abhaengigkeiten: Moose (RAT), 00_config.lua, 01_core.lua, 02_audio.lua

TRN = TRN or {}
local CFG = TRN.CFG
local AMB = CFG.AMBIENT or {}

local KMH_TO_MS = 1 / 3.6

-- ----------------------------------------------------------------------
-- Flugplatzbetrieb (RAT)
-- ----------------------------------------------------------------------
function TRN.Rat_Init()
  local R = AMB.rat
  if not R or not R.enabled then
    TRN.Log("RAT disabled")
    return
  end
  if not RAT then
    TRN.Error("RAT (Moose) not loaded - air traffic skipped")
    return
  end

  local started = 0
  for _, f in ipairs(R.flights or {}) do
    local ok, err = pcall(function()
      local rat = RAT:New(f.template, f.alias)
      rat:SetDeparture(R.airfields)
      rat:SetDestination(R.airfields)
      rat:SetSpawnDelay(f.delaySec or 0)
      rat:SetSpawnInterval(f.intervalSec or 600)
      rat:Spawn(f.count or 1)
    end)
    if ok then
      started = started + 1
    else
      TRN.Error("RAT '%s' failed: %s", tostring(f.template), tostring(err))
    end
  end
  TRN.Log("RAT started: %d of %d flight types", started, #(R.flights or {}))
end

-- ----------------------------------------------------------------------
-- Konvois
-- ----------------------------------------------------------------------
local states = {}

-- Entfernt zerstoerte oder abgelaufene Konvois aus der Liste, Rueckgabe: Anzahl aktiver Konvois
local function activeCount(state)
  local alive = {}
  for _, name in ipairs(state.active) do
    if #TRN.GroupAliveUnits(name) > 0 then alive[#alive + 1] = name end
  end
  state.active = alive
  return #alive
end

local function spawnConvoy(state)
  local d = state.def
  if activeCount(state) >= (d.maxActive or 1) then return end

  -- Start- und Zielzone: zwei verschiedene Zonen (Zielzone = naechster Eintrag in der Liste)
  local n = #d.zones
  if n < 2 then
    if not state.warned then TRN.Error("Convoy '%s': needs at least 2 zones", d.id); state.warned = true end
    return
  end
  local i = math.random(1, n)
  local startZone, endZone = d.zones[i], d.zones[i % n + 1]

  local from = TRN.RandomPointInZone(startZone)
  local to = TRN.RandomPointInZone(endZone)
  if not from or not to then
    if not state.warned then
      TRN.Error("Convoy '%s': trigger zone '%s' or '%s' is missing", d.id, startZone, endZone)
      state.warned = true
    end
    return
  end

  local name, err = TRN.Spawn(TRN.Pick(d.templates), from)
  if not name then
    if not state.warned then TRN.Error("Convoy '%s': %s", d.id, tostring(err)); state.warned = true end
    return
  end
  state.warned = false

  local speed = TRN.RandomIn(d.speedKmh) * KMH_TO_MS
  local okRoute, routeErr = TRN.SendRoute(name, from, to, speed)
  if not okRoute then TRN.Error("Convoy '%s' route failed: %s", d.id, tostring(routeErr)) end

  state.active[#state.active + 1] = name
  TRN.Log("Convoy %s spawned: %s (%s -> %s)", d.id, name, startZone, endZone)

  if d.announce then
    TRN.Audio.TextAll(string.format("Hostile convoy spotted, MGRS %s, moving towards %s.",
      TRN.MGRS({ x = from.x, y = 0, z = from.y }, 3), endZone))
  end

  -- Aufraeumen nach Ablauf der Lebensdauer
  TRN.After(d.ttlSec or 1800, function() TRN.DestroyGroup(name) end)
end

local function schedule(state, delay)
  TRN.After(delay, function()
    local ok, err = pcall(spawnConvoy, state)
    if not ok then TRN.Error("Convoy '%s' error: %s", state.def.id, tostring(err)) end
    schedule(state, TRN.RandomIn(state.def.intervalSec))
  end)
end

function TRN.Convoys_Init()
  local list = AMB.convoys or {}
  for _, d in ipairs(list) do
    local state = { def = d, active = {}, warned = false }
    states[d.id] = state
    schedule(state, TRN.RandomIn(d.firstDelaySec))
  end
  TRN.Log("Convoys scheduled: %d type(s)", #list)
end
