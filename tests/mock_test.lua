-- tests/mock_test.lua
-- Logik-Test der Skripte OHNE DCS: DCS-, Moose-, MIST- und CTLD-Funktionen werden durch einfache Attrappen ersetzt.
-- Prueft laesst sich damit der Ablauf (Menue, Zonen-Sessions, Ansagen, Auto-Restart, Aufraeumen),
-- NICHT das Verhalten im Spiel.
-- Start (im Repo-Hauptverzeichnis):  lua5.1 tests/mock_test.lua

local failures, checks = 0, 0
local function check(cond, label)
  checks = checks + 1
  if cond then
    print("  ok   " .. label)
  else
    failures = failures + 1
    print("  FAIL " .. label)
  end
end

-- DCS-Sandbox: math.randomseed und os fehlen dort (Fehler aus dem Spiel: "attempt to call field randomseed")
math.randomseed = nil
local real_os = os
os = nil

-- ------------------------------------------------------------------ Uhr / Timer
local clock, jobs = 100, {}
timer = {
  getTime = function() return clock end,
  getAbsTime = function() return 30000 + clock end,
  scheduleFunction = function(fn, arg, t) jobs[#jobs + 1] = { fn = fn, arg = arg, t = t } end,
}
local function advance(seconds)
  local target = clock + seconds
  while true do
    local idx, best
    for i, j in ipairs(jobs) do
      if j.t <= target and (not best or j.t < best.t) then idx, best = i, j end
    end
    if not best then break end
    table.remove(jobs, idx)
    clock = math.max(clock, best.t)
    local nextT = best.fn(best.arg, clock)
    if nextT then jobs[#jobs + 1] = { fn = best.fn, arg = best.arg, t = nextT } end
  end
  clock = target
end

-- ------------------------------------------------------------------ Welt-Modell
local units, groups = {}, {}
local outputs = {}          -- Ansagen: { id=, text=, sound= }
local logs = {}
env = { info = function(m) logs[#logs + 1] = m end, error = function(m) logs[#logs + 1] = "ERROR " .. m; print("  [env.error] " .. m) end }

local function lastText() return outputs[#outputs] and outputs[#outputs].text or "" end
local function outputCount() return #outputs end

local nextGroupId = 100
local function newGroup(name)
  nextGroupId = nextGroupId + 1
  local g = { name = name, id = nextGroupId, units = {}, alive = true }
  groups[name] = g
  return g
end

local function newUnit(groupName, name, typeName)
  local g = groups[groupName]
  if not g then g = newGroup(groupName) end
  local u = { name = name, group = g, type = typeName, alive = true, life = 100 }
  g.units[#g.units + 1] = u
  units[name] = u
  return u
end

local function destroyUnit(name)
  local u = units[name]
  if u then u.alive = false; u.life = 0 end
end

local function groupByName(name)
  return groups[name]
end

-- ------------------------------------------------------------------ Trigger und Koalition
world = { event = { S_EVENT_SHOT = 1 }, addEventHandler = function(h) end }
trigger = {
  misc = { getZone = function(name)
    local zones = {
      TRN_SE_ZONE = { point = { x = 0, y = 0 }, radius = 3000 },
      TRN_ST_ZONE = { point = { x = 5000, y = 0 }, radius = 3000 },
      TRN_AG_ZONE = { point = { x = 10000, y = 0 }, radius = 3000 },
      TRN_AG_START = { point = { x = 10000, y = 0 }, radius = 500 },
      TRN_AG_END = { point = { x = 18000, y = 0 }, radius = 500 },
      TRN_CC_ZONE = { point = { x = 20000, y = 0 }, radius = 8000 },
    }
    return zones[name]
  end },
}

coalition = {
  side = { BLUE = 2, RED = 1 },
  getPlayers = function(side)
    local out = {}
    for _, g in pairs(groups) do
      for _, u in ipairs(g.units) do
        if u.type and (u.type:match("Client") or u.type:match("Client.*")) then
          out[#out + 1] = u
        end
      end
    end
    return out
  end,
  getGroup = function(name) return groups[name] end,
}

-- ------------------------------------------------------------------ Spawn / Gruppe
SPAWN = {
  New = function(template)
    return { template = template, spawned = false }
  end,
}
SPAWN.prototype = {}
function SPAWN.prototype:SpawnFromVec2(vec2, minH, maxH)
  local name = "SPAWNED_" .. self.template .. "_" .. (nextGroupId - 100)
  local u = newUnit(self.template, name, "Client_" .. self.template)
  u.position = { x = vec2.x, y = 0, z = vec2.y }
  self.spawned = true
  return u
end

TriggerOnce = function(comment) return { comment = comment, conditions = {}, actions = {} } end
TriggerStart = function(comment) return { comment = comment, actions = {} } end
DoScriptFile = function(key) return function() end end
SoundToAll = function(key) return function() end end
FlagIsTrue = function(v) return function() return v end end

MISSION = { triggers = { zones = function() return {} end },
           add_triggerzone = function(z, radius, name) end,
           country = function(side) return { countries = { USA = {}, Russia = {} } } end,
           coalition = { blue = { add_country = function() end }, red = { add_country = function() end } },
           start_time = 0,
           weather = { clouds_density = 0, enable_fog = false, enable_dust = false, qnh = 760,
                       visibility_distance = 80000, wind_at_ground = 0, season_temperature = 22 },
           terrain = { airports = {} }, }

-- ------------------------------------------------------------------ Core (TRN.CFG / Zonen)
TRN = TRN or {}
TRN.CFG = {}
TRN.Zones = {}
TRN.ZoneOrder = {}

local Session = {}
Session.__index = Session
function Session:Say() end
function Session:Track() end
function Session:Cleanup() end
function Session:Elapsed() return 0 end
function Session:ElapsedText() return "0 min 00 s" end
function Session:RoundTag(word) return "" end

local Zone = {}
Zone.__index = Zone
function Zone:Start() end
function Zone:Stop() end
function Zone:Owner() return nil end

TRN.RegisterZone = function(def)
  TRN.ZoneOrder[#TRN.ZoneOrder + 1] = def.id
  TRN.Zones = TRN.Zones or {}
  TRN.Zones[def.id] = def
end

TRN.Every = function() return { Stop = function() end } end
TRN.After = function(f) f() end

TRN.PlayerGroups = function()
  local out = {}
  for name, g in pairs(groups) do
    if g.units and #g.units > 0 then out[name] = true end
  end
  return out
end

TRN.InZone = function(vec3, zoneName)
  local z = trigger.misc.getZone(zoneName)
  if not z then return false end
  return TRN.Dist2D(vec3, z.point) <= z.radius
end

TRN.RandomPointInZone = function(zoneName)
  local z = trigger.misc.getZone(zoneName)
  if not z then return nil end
  return { x = z.point.x, y = 0, z = z.point.y }
end

TRN.Spawn = function(template, vec2)
  if not template then return nil, "template missing" end
  return "SPAWNED_" .. template, nil
end

TRN.GroupAliveUnits = function(groupName)
  local g = groupByName(groupName)
  if not g then return {} end
  local out = {}
  for _, u in ipairs(g.units) do
    if u.alive and (u.life or 100) > 0 then out[#out + 1] = u end
  end
  return out
end

TRN.DestroyGroup = function(groupName)
  local g = groupByName(groupName)
  if g then
    for _, u in ipairs(g.units) do
      units[u.name] = nil
    end
    g.alive = false
  end
end

TRN.MGRS = function(v) return "GGNN NNUU" end
TRN.Bearing = function() return 0 end
TRN.Dist2D = function(a, b) return 1000 end
TRN.ToNm = function(m) return m / 1852 end
TRN.ToFt = function(m) return m * 3.28084 end
TRN.ZoneInfo = function(name) return trigger.misc.getZone(name) end
TRN.Pick = function(t) return t[1] end
TRN.RandomIn = function(r) return r[1] end

-- ------------------------------------------------------------------ Audio
TRN.Audio = {}
TRN.Audio.Say = function(groupName, key, extra) end
TRN.Audio.Text = function(groupName, text) outputs[#outputs + 1] = { id = groupName, text = text } end
TRN.Audio.TextAll = function(text) end

-- ------------------------------------------------------------------ Menu
TRN.Menu = {}
TRN.Menu.Start = function() end
TRN.Menu.OnNewPlayer = function(f) f() end

-- ------------------------------------------------------------------ Zones laden (modul-artig)
local function load_zone(file, expectZone)
  local chunk = loadfile(file)
  if not chunk then
    print("  FAIL failed to load " .. file)
    failures = failures + 1
    return
  end
  chunk()
  if expectZone then
    local zoneName = type(expectZone) == "string" and expectZone or expectZone.id
    check(TRN.Zones and TRN.Zones[zoneName] ~= nil, "zone registered: " .. zoneName)
  end
end

local function run_zones()
  load_zone("scripts/00_config.lua", nil)
  load_zone("scripts/01_core.lua", nil)
  load_zone("scripts/02_audio.lua", nil)
  load_zone("scripts/03_menu.lua", nil)
  load_zone("scripts/10_sead.lua", { id = "SEAD" })
  load_zone("scripts/20_strike.lua", { id = "STRIKE" })
  load_zone("scripts/30_ag.lua", { id = "AG" })
  load_zone("scripts/40_cc.lua", { id = "COMBINED" })
  load_zone("scripts/80_ambient.lua", nil)
  load_zone("scripts/99_init.lua", nil)
end

-- ------------------------------------------------------------------ Ablauf-Test
local function test_zone_sessions()
  print("\n-- Test 1: Zone-Sessions (Start, Round, Tick, Stop)")
  local function new_session(zoneId)
    local s = setmetatable({ id = zoneId, group = "G1", level = "EASY", mode = nil, cfg = TRN.CFG[zoneId],
                             tracked = {}, rounds = 0, roundStart = 100, state = "RUN", data = {} }, Session)
    return s
  end

  TRN.Zones = TRN.Zones or {}
  TRN.Zones.SEAD = setmetatable({ def = TRN.Zones.SEAD, session = nil, timer = nil, id = "SEAD" }, Zone)
  local ok, err = pcall(function()
    TRN.Zones.SEAD:Start("G1", "EASY")
    check(TRN.Zones.SEAD.session ~= nil, "SEAD session started")
    check(TRN.Zones.SEAD.session.group == "G1", "SEAD session group correct")
    advance(10)
    TRN.Zones.SEAD:Stop()
    check(TRN.Zones.SEAD.session == nil, "SEAD session stopped")
  end)
  if not ok then print("  FAIL SEAD session: " .. tostring(err)) end

  TRN.Zones.STRIKE = setmetatable({ def = TRN.Zones.STRIKE, session = nil, timer = nil, id = "STRIKE" }, Zone)
  ok, err = pcall(function()
    TRN.Zones.STRIKE:Start("G2", "EASY")
    check(TRN.Zones.STRIKE.session ~= nil, "STRIKE session started")
    TRN.Zones.STRIKE:Stop()
  end)
  if not ok then print("  FAIL STRIKE session: " .. tostring(err)) end
end

local function test_audible_messages()
  print("\n-- Test 2: Ansagen")
  TRN.Audio.Say("G1", "welcome")
  TRN.Audio.Text("G1", "Test text")
  check(outputCount() == 2, "audio queue 2 items")
  check(lastText() == "Test text", "last text correct")
end

local function test_busy_zone()
  print("\n-- Test 3: Besetzt-Meldung")
  local z1 = setmetatable({ def = TRN.Zones.SEAD, session = { group = "G1" }, timer = nil, id = "SEAD" }, Zone)
  TRN.Zones.SEAD = z1
  local said = false
  local origSay = TRN.Audio.Say
  TRN.Audio.Say = function(g, k, e)
    if k == "zone_busy" then said = true end
    origSay(g, k, e)
  end
  local ok, _ = pcall(function()
    z1:Start("G2", "EASY")
  end)
  check(ok == false, "zone refuses if busy")
  check(said, "busy message sent")
end

local function test_zone_registration()
  print("\n-- Test 4: Zonen-Registrierung")
  check(#TRN.ZoneOrder == 6, "6 zones registered")
  for _, id in ipairs({ "SEAD", "STRIKE", "AG", "COMBINED" }) do
    check(TRN.Zones[id] ~= nil, "zone: " .. id)
  end
end

run_zones()
test_zone_registration()
test_zone_sessions()
test_audible_messages()
test_busy_zone()

print(string.format("\n===== %d checks, %d failures =====", checks, failures))
if failures > 0 then os.exit(1) end
