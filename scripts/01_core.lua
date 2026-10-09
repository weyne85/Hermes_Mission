-- 01_core.lua
-- Gemeinsame Hilfsfunktionen und Zonen-Verwaltung (Sessions, Aufraeumen, Logging).
-- Abhaengigkeiten: mist, Moose (SPAWN, ZONE), 00_config.lua

TRN = TRN or {}
local CFG = TRN.CFG

-- ----------------------------------------------------------------------
-- Logging
-- ----------------------------------------------------------------------
local function fmt(prefix, f, ...)
  local ok, msg = pcall(string.format, f, ...)
  return prefix .. (ok and msg or tostring(f))
end

function TRN.Log(f, ...)
  env.info(fmt("CAUCASUS_STRIKE: ", f, ...))
end
function TRN.Debug(f, ...)
  if CFG.DEBUG then env.info(fmt("CAUCASUS_STRIKE: [dbg] ", f, ...)) end
end
function TRN.Error(f, ...)
  env.error(fmt("CAUCASUS_STRIKE: ", f, ...))
end

-- ----------------------------------------------------------------------
-- Zeitgesteuerte Wiederholung. fn darf "false" zurueckgeben, um sich zu beenden.
-- Rueckgabe: Handle mit :Stop()
-- ----------------------------------------------------------------------
function TRN.Every(seconds, fn, firstDelay)
  local handle = { stopped = false }
  function handle:Stop() self.stopped = true end
  local function run(_, t)
    if handle.stopped then return nil end
    local ok, res = pcall(fn)
    if not ok then TRN.Error("Timer error: %s", tostring(res)) end
    if handle.stopped or res == false then return nil end
    return t + seconds
  end
  timer.scheduleFunction(run, nil, timer.getTime() + (firstDelay or seconds))
  return handle
end

function TRN.After(seconds, fn)
  timer.scheduleFunction(function()
    local ok, err = pcall(fn)
    if not ok then TRN.Error("Delayed call error: %s", tostring(err)) end
  end, nil, timer.getTime() + seconds)
end

-- ----------------------------------------------------------------------
-- Geometrie
-- ----------------------------------------------------------------------
-- DCS: x = Norden, z = Osten. Peilungen in Grad (0-359), plus CFG.MAG_VAR.
function TRN.Bearing(from, to)
  local dx = to.x - from.x
  local dz = to.z - from.z
  local deg = math.deg(math.atan2(dz, dx)) + (CFG.MAG_VAR or 0)
  return math.floor((deg % 360) + 0.5) % 360
end

function TRN.Dist2D(a, b)
  local dx, dz = a.x - b.x, a.z - b.z
  return math.sqrt(dx * dx + dz * dz)
end

local M_TO_NM, M_TO_FT = 1 / 1852, 3.28084
function TRN.ToNm(m) return m * M_TO_NM end
function TRN.ToFt(m) return m * M_TO_FT end

function TRN.MGRS(vec3, acc)
  local ok, res = pcall(function()
    return mist.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL(vec3)), acc or 4)
  end)
  return ok and res or "n/a"
end

function TRN.ZoneInfo(name)
  local z = trigger.misc.getZone(name)
  if not z then return nil end
  return { point = z.point, radius = z.radius }
end

function TRN.InZone(vec3, zoneName)
  local z = trigger.misc.getZone(zoneName)
  if not z then return false end
  return TRN.Dist2D(vec3, z.point) <= z.radius
end

function TRN.Pick(list)
  if not list or #list == 0 then return nil end
  return list[math.random(1, #list)]
end

-- Zufallszahl aus einem Bereich { min, max }
function TRN.RandomIn(range)
  return math.random(range[1], range[2])
end

-- ----------------------------------------------------------------------
-- Spieler
-- ----------------------------------------------------------------------
-- Liefert Tabelle: Gruppenname -> { group = DCS-Gruppe, unit = erste Spieler-Unit, id = Gruppen-ID }
function TRN.PlayerGroups()
  local out = {}
  local players = coalition.getPlayers(CFG.SIDE) or {}
  for _, unit in ipairs(players) do
    if unit and unit:isExist() then
      local grp = unit:getGroup()
      if grp then
        local name = grp:getName()
        if not out[name] then
          out[name] = { group = grp, unit = unit, id = grp:getID() }
        end
      end
    end
  end
  return out
end

function TRN.IsPlayerGroupAlive(groupName)
  return TRN.PlayerGroups()[groupName] ~= nil
end

function TRN.PlayerUnit(groupName)
  local p = TRN.PlayerGroups()[groupName]
  return p and p.unit or nil
end

-- ----------------------------------------------------------------------
-- Spawns (Moose SPAWN). Ein SPAWN-Objekt je Template, damit die Gruppen-Nummern hochzaehlen.
-- ----------------------------------------------------------------------
local spawners = {}

local function getSpawner(template)
  if not spawners[template] then
    spawners[template] = SPAWN:New(template)
  end
  return spawners[template]
end

-- vec2 = { x =, y = } (DCS Vec2). minH/maxH nur fuer Luftgruppen (Meter).
-- Rueckgabe: DCS-Gruppenname oder nil (Fehler wird geloggt, Grund als 2. Rueckgabewert)
function TRN.Spawn(template, vec2, minH, maxH)
  local ok, res = pcall(function()
    return getSpawner(template):SpawnFromVec2(vec2, minH, maxH)
  end)
  if not ok then
    TRN.Error("Spawn '%s' failed: %s", tostring(template), tostring(res))
    return nil, "Template '" .. tostring(template) .. "' missing in mission"
  end
  if not res then
    return nil, "Spawn of '" .. tostring(template) .. "' returned nothing"
  end
  return res:GetName()
end

function TRN.RandomPointInZone(zoneName)
  local z = trigger.misc.getZone(zoneName)
  if not z then return nil end
  return mist.getRandPointInCircle(z.point, z.radius * 0.9)
end

function TRN.GroupAliveUnits(groupName)
  local g = Group.getByName(groupName)
  if not g or not g:isExist() then return {} end
  local out = {}
  for _, u in ipairs(g:getUnits() or {}) do
    if u:isExist() and u:getLife() > 0 then out[#out + 1] = u end
  end
  return out
end

function TRN.DestroyGroup(groupName)
  local g = Group.getByName(groupName)
  if g and g:isExist() then pcall(function() g:destroy() end) end
end

-- ----------------------------------------------------------------------
-- Zonen-Verwaltung
--
-- def = {
--   id, title, cfg,                    -- cfg = TRN.CFG.<ZONE>
--   modes = { ... } (optional),
--   OnRound = function(session) return ok, errText end   -- Runde aufbauen (spawnen)
--   OnTick  = function(session) return "done" | nil end  -- alle CFG.TICK Sekunden
--   OnStop  = function(session) end (optional)
-- }
-- ----------------------------------------------------------------------
TRN.Zones = {}
TRN.ZoneOrder = {}

local Session = {}
Session.__index = Session

function Session:Say(key, extra)
  if TRN.Audio then TRN.Audio.Say(self.group, key, extra) end
end

function Session:Track(groupName)
  if groupName then self.tracked[#self.tracked + 1] = groupName end
end

function Session:Cleanup()
  for _, name in ipairs(self.tracked) do TRN.DestroyGroup(name) end
  self.tracked = {}
end

function Session:Elapsed()
  return timer.getTime() - self.roundStart
end

-- "3 min 07 s"
function Session:ElapsedText()
  local t = math.floor(self:Elapsed())
  return string.format("%d min %02d s", math.floor(t / 60), t % 60)
end

-- Ab der zweiten Runde "Round 2. " (word: z. B. "Wave", "Task")
function Session:RoundTag(word)
  return self.rounds > 1 and string.format("%s %d. ", word or "Round", self.rounds) or ""
end

-- Zaehlt die noch lebenden Gruppen aus names. Wenn seit dem letzten Aufruf Gruppen ausgefallen sind
-- und noch welche leben, wird onLost(anzahlLebend) einmal aufgerufen.
-- Rueckgabe: Anzahl lebender Gruppen.
function Session:CountAlive(names, onLost)
  local dead = self.data.dead
  if not dead then dead = {}; self.data.dead = dead end
  local alive, newlyDead = 0, 0
  for _, name in ipairs(names) do
    if #TRN.GroupAliveUnits(name) > 0 then
      alive = alive + 1
    elseif not dead[name] then
      dead[name] = true
      newlyDead = newlyDead + 1
    end
  end
  if newlyDead > 0 and alive > 0 and onLost then onLost(alive) end
  return alive
end

local Zone = {}
Zone.__index = Zone

function TRN.RegisterZone(def)
  local z = setmetatable({ def = def, session = nil, timer = nil }, Zone)
  TRN.Zones[def.id] = z
  TRN.ZoneOrder[#TRN.ZoneOrder + 1] = def.id
  return z
end

function Zone:IsBusy() return self.session ~= nil end

function Zone:_newRound()
  local s = self.session
  s:Cleanup()
  s.rounds = s.rounds + 1
  s.roundStart = timer.getTime()
  s.state = "RUN"
  s.data = {}
  if s.cfg and s.cfg.levels then            -- Schwierigkeitsstufe aufloesen (s.lv)
    s.lv = s.cfg.levels[s.level]
    if not s.lv then
      TRN.Audio.Text(s.group, "Setup error: unknown difficulty " .. tostring(s.level))
      self:Stop(true)
      return
    end
  end
  local ok, res, err = pcall(self.def.OnRound, s)
  if not ok then
    TRN.Error("OnRound %s: %s", self.def.id, tostring(res))
    if TRN.Audio then TRN.Audio.Text(s.group, "Setup error in zone " .. self.def.title .. ". See dcs.log.") end
    self:Stop(true)
  elseif res == false then
    if TRN.Audio then TRN.Audio.Text(s.group, "Setup error: " .. tostring(err or "unknown")) end
    self:Stop(true)
  end
end

function Zone:_tick()
  local s = self.session
  if not s then return false end

  if not TRN.IsPlayerGroupAlive(s.group) then
    TRN.Log("Zone %s: owner group %s gone, closing", self.def.id, s.group)
    self:Stop()
    return false
  end

  if s.state == "WAIT" then
    if timer.getTime() >= s.restartAt then self:_newRound() end
    return
  end

  local limit = s.cfg and s.cfg.roundTimeout
  if limit and s:Elapsed() > limit then
    s:Say("zone_timeout")
    self:Stop()
    return false
  end

  local ok, res = pcall(self.def.OnTick, s)
  if not ok then                            -- Fehler in der Zone: beenden statt jede Runde neu zu loggen
    TRN.Error("OnTick %s: %s", self.def.id, tostring(res))
    TRN.Audio.Text(s.group, "Error in zone " .. self.def.title .. ". Exercise stopped. See dcs.log.")
    self:Stop(true)
    return false
  end
  if res == "done" then
    s.state = "WAIT"
    s.restartAt = timer.getTime() + CFG.RESTART_DELAY
    -- Aufraeumen erst beim naechsten Rundenstart, damit Wracks/Ziele sichtbar bleiben
  end
end

-- Startet eine Session. Rueckgabe: true oder false, Grund
function Zone:Start(groupName, level, mode)
  if self.session then
    if self.session.group == groupName then
      -- eigene Session neu starten
      self:Stop(true)
    else
      TRN.Audio.Say(groupName, "zone_busy")
      return false, "busy"
    end
  end
  self.session = setmetatable({
    zone = self, id = self.def.id, group = groupName, level = level, mode = mode,
    cfg = self.def.cfg, tracked = {}, rounds = 0, roundStart = timer.getTime(),
    state = "RUN", data = {},
  }, Session)
  TRN.Log("Zone %s started by %s (level %s%s)", self.def.id, groupName, tostring(level), mode and (" " .. mode) or "")
  self:_newRound()
  if self.session then
    self.timer = TRN.Every(CFG.TICK, function() return self:_tick() end)
  end
  return true
end

function Zone:Stop(silent)
  local s = self.session
  if not s then return end
  if self.timer then self.timer:Stop(); self.timer = nil end
  if self.def.OnStop then pcall(self.def.OnStop, s) end
  s:Cleanup()
  self.session = nil
  if not silent and TRN.IsPlayerGroupAlive(s.group) then
    TRN.Audio.Say(s.group, "zone_stopped")
  end
  TRN.Log("Zone %s stopped", self.def.id)
end

function Zone:Owner()
  return self.session and self.session.group or nil
end
