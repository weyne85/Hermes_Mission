-- tests/mock_test.lua
-- Logik-Test der echten Skripte OHNE DCS: nur DCS-, Moose- und MIST-Funktionen werden durch Attrappen ersetzt,
-- die Skripte unter scripts/ laufen unveraendert in der Ladereihenfolge der Mission.
-- Geprueft wird der Ablauf (Menue, Zonen-Sessions, Ansagen, Auto-Restart, Timeout, Aufraeumen), NICHT das
-- Verhalten im Spiel.
-- Start (im Repo-Hauptverzeichnis):  lua5.1 tests/mock_test.lua   -> erwartet "0 Fehler"

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

-- DCS-Sandbox: os und math.randomseed fehlen dort. os wird fuer den Test nur zum Beenden gebraucht.
local real_os = os
math.randomseed = nil
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
local units, groups, players = {}, {}, {}
local outputs, logs, errors = {}, {}, {}
local nextGroupId = 100

env = {
  info = function(m) logs[#logs + 1] = m end,
  error = function(m) logs[#logs + 1] = "ERROR " .. m; errors[#errors + 1] = m; print("  [env.error] " .. m) end,
}

local Unit_mt = {}
Unit_mt.__index = Unit_mt
function Unit_mt:getName() return self.name end
function Unit_mt:isExist() return self.alive end
function Unit_mt:getLife() return self.alive and 100 or 0 end
function Unit_mt:getTypeName() return self.type end
function Unit_mt:getPoint() return self.point end
function Unit_mt:getGroup() return self.group end
function Unit_mt:hasAttribute(a) return self.attrs[a] == true end

local Group_mt = {}
Group_mt.__index = Group_mt
function Group_mt:getName() return self.name end
function Group_mt:getID() return self.id end
function Group_mt:isExist() return self.alive end
function Group_mt:getUnits() return self.units end
function Group_mt:destroy()
  self.alive = false
  for _, u in ipairs(self.units) do u.alive = false end
end
function Group_mt:getController()
  local g = self
  return { setTask = function(_, task) g.task = task end }
end

local function newGroup(name)
  nextGroupId = nextGroupId + 1
  local g = setmetatable({ name = name, id = nextGroupId, units = {}, alive = true }, Group_mt)
  groups[name] = g
  return g
end

local function newUnit(group, name, typeName, point, attrList)
  local attrs = {}
  for _, a in ipairs(attrList or {}) do attrs[a] = true end
  local u = setmetatable({ name = name, type = typeName, group = group, alive = true, point = point, attrs = attrs },
    Unit_mt)
  group.units[#group.units + 1] = u
  units[name] = u
  return u
end

local function killGroup(name)
  local g = groups[name]
  if g then for _, u in ipairs(g.units) do u.alive = false end end
end

-- Spielergruppe anlegen / entfernen
local function addPlayer(groupName, point)
  local g = newGroup(groupName)
  local u = newUnit(g, groupName .. "-1", "F/A-18C", point)
  players[#players + 1] = u
  return u
end
local function removePlayer(groupName)
  for i = #players, 1, -1 do
    if players[i].group.name == groupName then
      players[i].alive = false
      table.remove(players, i)
    end
  end
  if groups[groupName] then groups[groupName].alive = false end
end

-- Ansagen einer Gruppe (outTextForGroup)
local function sawText(groupName, pattern)
  local id = groups[groupName] and groups[groupName].id
  for _, o in ipairs(outputs) do
    if o.id == id and o.text:find(pattern, 1, true) then return true end
  end
  return false
end
local function countText(groupName, pattern)
  local id, n = groups[groupName] and groups[groupName].id, 0
  for _, o in ipairs(outputs) do
    if o.id == id and o.text:find(pattern, 1, true) then n = n + 1 end
  end
  return n
end

-- ------------------------------------------------------------------ DCS-Attrappen
coalition = {
  side = { BLUE = 2, RED = 1 },
  getPlayers = function() return players end,
}

local zoneTable = {
  TRN_SE_ZONE = { x = 0, z = 0, r = 3000 },
  TRN_ST_ZONE = { x = 5000, z = 0, r = 3000 },
  TRN_AG_ZONE = { x = 10000, z = 0, r = 3000 },
  TRN_AG_START = { x = 10000, z = 0, r = 500 },
  TRN_AG_END = { x = 18000, z = 0, r = 500 },
  TRN_CC_ZONE = { x = 20000, z = 0, r = 8000 },
}
trigger = {
  misc = { getZone = function(name)
    local z = zoneTable[name]
    if not z and name:match("^TRN_CONV") then z = { x = 30000, z = 1000, r = 800 } end
    if not z then return nil end
    return { point = { x = z.x, y = 0, z = z.z }, radius = z.r }
  end },
  action = { outTextForGroup = function(id, text) outputs[#outputs + 1] = { id = id, text = text } end },
}

mist = {
  getRandPointInCircle = function(p, r) return { x = p.x + 100, y = (p.z or p.y or 0) + 100 } end,
  tostringMGRS = function() return "37T GG 12345 67890" end,
}
coord = { LLtoMGRS = function() return {} end, LOtoLL = function() return {} end }

local handlers = {}
world = { event = { S_EVENT_SHOT = 1 }, addEventHandler = function(h) handlers[#handlers + 1] = h end }
Weapon = { Category = { MISSILE = 2 } }
Unit = { getByName = function(n) return units[n] end }
Group = { getByName = function(n) return groups[n] end }

-- ------------------------------------------------------------------ Moose-Attrappen
local function knownTemplate(name) return type(name) == "string" and name:match("^TRN_") ~= nil end

SPAWN = {}
SPAWN.__index = SPAWN
function SPAWN:New(template)
  return setmetatable({ template = template, n = 0 }, SPAWN)
end
function SPAWN:SpawnFromVec2(vec2)
  if not knownTemplate(self.template) then error("template '" .. tostring(self.template) .. "' missing") end
  self.n = self.n + 1
  local name = self.template .. "#" .. self.n
  local g = newGroup(name)
  local p = { x = vec2.x, y = 0, z = vec2.y }
  if self.template:match("^TRN_SAM_SA") then
    newUnit(g, name .. "-1", "search radar", p, { "SAM SR" })
    newUnit(g, name .. "-2", "track radar", p, { "SAM TR" })
    newUnit(g, name .. "-3", "launcher", p, { "SAM LL" })
  else
    newUnit(g, name .. "-1", "truck", p)
    newUnit(g, name .. "-2", "truck", p)
  end
  return { GetName = function() return name end }
end

GROUP = { FindByName = function(_, name)
  if groups[name] and groups[name].alive then return { name = name } end
end }
COORDINATE = {}

-- F10-Menue: Befehle werden unter ihrem Pfad abgelegt und koennen im Test aufgerufen werden
local menuCommands = {}
MENU_GROUP = {}
function MENU_GROUP:New(g, text, parent)
  return { group = g.name, path = parent and (parent.path .. "/" .. text) or text }
end
MENU_GROUP_COMMAND = {}
function MENU_GROUP_COMMAND:New(g, text, parent, fn, ...)
  local args = { ... }
  local path = parent.path .. "/" .. text
  menuCommands[g.name] = menuCommands[g.name] or {}
  menuCommands[g.name][path] = function() return fn(unpack(args)) end
end
local function press(groupName, path)
  local cmd = menuCommands[groupName] and menuCommands[groupName][path]
  if not cmd then return false end
  cmd()
  return true
end

local ratObjects = {}
RAT = {}
function RAT:New(template)
  local o = { template = template, calls = {} }
  setmetatable(o, { __index = function(t, k)
    return function(self) t.calls[#t.calls + 1] = k; return self end
  end })
  ratObjects[#ratObjects + 1] = o
  return o
end

-- ------------------------------------------------------------------ Skripte laden (Ladereihenfolge der Mission)
local SCRIPTS = {
  "00_config", "01_core", "02_audio", "03_menu", "10_sead", "20_strike", "30_ag", "40_cc", "80_ambient", "99_init",
}
local function loadScripts()
  for _, name in ipairs(SCRIPTS) do
    local chunk, err = loadfile("scripts/" .. name .. ".lua")
    if not chunk then
      check(false, "load " .. name .. ": " .. tostring(err))
    else
      local ok, runErr = pcall(chunk)
      check(ok, "run " .. name .. (ok and "" or (": " .. tostring(runErr))))
    end
  end
end

-- ------------------------------------------------------------------ Hilfen
local function settle(seconds) advance(seconds or 15) end   -- Ansagen werden nacheinander ausgegeben

local function stopAll()
  for _, id in ipairs(TRN.ZoneOrder) do
    local z = TRN.Zones[id]
    if z:IsBusy() then z:Stop(true) end
  end
end

local function killAlive(names)
  for _, n in ipairs(names) do killGroup(n) end
end

-- ------------------------------------------------------------------ Tests
local function test_load()
  print("\n-- Test 1: Laden und Registrierung")
  loadScripts()
  check(#TRN.ZoneOrder == 4, "4 Zonen registriert")
  for _, id in ipairs({ "SEAD", "STRIKE", "AG", "COMBINED" }) do
    check(TRN.Zones[id] ~= nil, "Zone registriert: " .. id)
  end
  check(type(TRN.Rat_Init) == "function" and type(TRN.Convoys_Init) == "function", "Ambient-Funktionen vorhanden")
  check(#ratObjects == 2, "2 RAT-Flugtypen gestartet")
  check(#errors == 0, "keine Fehler beim Laden und Initialisieren")
end

local function test_menu()
  print("\n-- Test 2: F10-Menue")
  addPlayer("F18-1", { x = 0, y = 5000, z = 8000 })
  advance(TRN.CFG.MENU_SCAN + 2)
  check(menuCommands["F18-1"] ~= nil, "Menue fuer neue Spielergruppe gebaut")
  check(menuCommands["F18-1"] and menuCommands["F18-1"]["Training Zones/1 SEAD / DEAD/Start EASY/SEAD"] ~= nil,
    "SEAD: Start EASY / SEAD vorhanden")
  check(menuCommands["F18-1"] and menuCommands["F18-1"]["Training Zones/2 Strike/Start MEDIUM"] ~= nil,
    "Strike: Start MEDIUM vorhanden")
  check(menuCommands["F18-1"] and menuCommands["F18-1"]["Training Zones/4 Combined/Start HARD/STRIKE"] ~= nil,
    "Combined: Start HARD / STRIKE vorhanden")
  settle()
  check(sawText("F18-1", "Welcome"), "Willkommensansage gesendet")
  advance(20)
  check(countText("F18-1", "Welcome") == 1, "Menue wird nicht doppelt gebaut")
end

local function test_sead()
  print("\n-- Test 3: SEAD (Start, Warnung, Abschluss, Neustart, Raketenstart, Stop)")
  local z = TRN.Zones.SEAD
  check(press("F18-1", "Training Zones/1 SEAD / DEAD/Start EASY/SEAD"), "Start per Menue")
  check(z:IsBusy() and z:Owner() == "F18-1", "Zone besetzt durch F18-1")
  local s = z.session
  check(s and s.data.mode == "SEAD" and #s.data.radars == 2, "SEAD-Modus, 2 Radare erkannt")
  settle()
  check(sawText("F18-1", "SEAD"), "Briefing-Ansage")
  check(sawText("F18-1", "Threat radar"), "Radarwarnung")

  -- Radare ausschalten -> Runde fertig
  for _, name in ipairs(s.data.radars) do units[name].alive = false end
  advance(TRN.CFG.TICK + 1)
  settle()
  check(sawText("F18-1", "Air defence neutralized"), "Abschlussmeldung")
  check(s.state == "WAIT", "Zustand WAIT nach Abschluss")

  -- Auto-Restart
  advance(TRN.CFG.RESTART_DELAY + TRN.CFG.TICK + 1)
  check(z.session and z.session.rounds == 2 and z.session.state == "RUN", "Neue Runde gestartet (Runde 2)")
  settle()
  check(sawText("F18-1", "Round 2."), "Runde 2 angesagt")

  -- Raketenstart eines Roten SAM
  local main = z.session.data.main
  local shooter = groups[main].units[1]
  for _, h in ipairs(handlers) do
    h:onEvent({ id = 1, initiator = shooter, weapon = { getDesc = function() return { category = 2 } end } })
  end
  settle()
  check(sawText("F18-1", "Missile launch"), "Raketenstart gemeldet")

  -- Stop und Aufraeumen
  local tracked = {}
  for _, n in ipairs(z.session.tracked) do tracked[#tracked + 1] = n end
  check(press("F18-1", "Training Zones/1 SEAD / DEAD/Stop / Reset"), "Stop per Menue")
  check(not z:IsBusy(), "Zone frei nach Stop")
  local allGone = #tracked > 0
  for _, n in ipairs(tracked) do if groups[n].alive then allGone = false end end
  check(allGone, "alle Ziele aufgeraeumt")
  settle()
  check(sawText("F18-1", "Exercise stopped"), "Stop-Ansage")
end

local function test_strike()
  print("\n-- Test 4: Strike")
  local z = TRN.Zones.STRIKE
  local ok = z:Start("F18-1", "EASY")
  check(ok and z:IsBusy(), "Start EASY")
  local s = z.session
  check(s and s.data.targets and #s.data.targets == #TRN.CFG.STRIKE.levels.EASY.targets, "Zielanzahl wie konfiguriert")
  settle()
  check(sawText("F18-1", "TARGETS"), "Zielliste angesagt")
  killGroup(s.data.targets[1])
  advance(TRN.CFG.TICK + 1)
  settle()
  check(sawText("F18-1", "Targets remaining: 1"), "Zwischenstand")
  killGroup(s.data.targets[2])
  advance(TRN.CFG.TICK + 1)
  settle()
  check(sawText("F18-1", "All strike targets destroyed"), "Abschlussmeldung")
  z:Stop(true)
  check(not z:IsBusy(), "Stop")
end

local function test_ag()
  print("\n-- Test 5: Air-to-Ground")
  local z = TRN.Zones.AG
  local ok = z:Start("F18-1", "EASY")
  check(ok and z:IsBusy(), "Start EASY")
  local s = z.session
  check(s and #s.data.targets > 0, "Ziele gespawnt")
  settle()
  check(sawText("F18-1", "CONVOY TARGETS"), "Zielliste angesagt")
  killAlive(s.data.targets)
  advance(TRN.CFG.TICK + 1)
  settle()
  check(sawText("F18-1", "Column destroyed"), "Abschlussmeldung")
  z:Stop(true)
end

local function test_combined()
  print("\n-- Test 6: Combined")
  local z = TRN.Zones.COMBINED
  local ok = press("F18-1", "Training Zones/4 Combined/Start EASY/STRIKE")
  check(ok and z:IsBusy(), "Start per Menue")
  local s = z.session
  check(s and s.data.seadTarget and #s.data.strikeTargets == #TRN.CFG.COMBINED.levels.EASY.targets,
    "SEAD-Ziel und Strike-Ziele gespawnt")
  settle()
  check(sawText("F18-1", "Active mode: STRIKE"), "Briefing mit Modus")
  killGroup(s.data.seadTarget)
  advance(TRN.CFG.TICK + 1)
  check(s.data.seadDone == true, "SEAD-Ziel zerstoert erkannt")
  killAlive(s.data.strikeTargets)
  advance(TRN.CFG.TICK + 1)
  settle()
  check(sawText("F18-1", "All objectives complete"), "Abschlussmeldung")
  z:Stop(true)
end

local function test_busy_timeout_owner()
  print("\n-- Test 7: Besetzt, Timeout, Spieler verlaesst die Zone")
  local z = TRN.Zones.SEAD
  addPlayer("F16-1", { x = 0, y = 5000, z = 9000 })
  advance(TRN.CFG.MENU_SCAN + 2)
  z:Start("F18-1", "EASY", "DEAD")
  local ok, reason = z:Start("F16-1", "EASY", "DEAD")
  check(ok == false and reason == "busy", "zweite Gruppe wird abgewiesen")
  settle()
  check(sawText("F16-1", "Zone is busy"), "Besetzt-Meldung")
  check(z:Owner() == "F18-1", "Besitzer bleibt F18-1")

  -- Timeout
  advance(TRN.CFG.SEAD.roundTimeout + 60)
  check(not z:IsBusy(), "Zone nach Timeout frei")
  check(sawText("F18-1", "Time expired"), "Timeout-Ansage")

  -- Spieler verlaesst die Zone
  local st = TRN.Zones.STRIKE
  st:Start("F16-1", "EASY")
  check(st:IsBusy(), "Strike durch F16-1 gestartet")
  removePlayer("F16-1")
  advance(TRN.CFG.TICK * 2)
  check(not st:IsBusy(), "Zone schliesst, wenn Besitzer weg ist")
end

local function test_final()
  print("\n-- Test 8: Gesamtlauf")
  stopAll()
  check(#errors == 0, "keine env.error-Meldungen im gesamten Lauf")
end

test_load()
test_menu()
test_sead()
test_strike()
test_ag()
test_combined()
test_busy_timeout_owner()
test_final()

print(string.format("\n===== %d Pruefungen, %d Fehler =====", checks, failures))
if failures > 0 then real_os.exit(1) end
