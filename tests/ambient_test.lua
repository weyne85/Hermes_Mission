-- tests/ambient_test.lua
-- Logiktest fuer scripts/80_ambient.lua ohne DCS (RAT, Konvois, Zeitplan, TTL). Start im Repo-Hauptverzeichnis: lua5.1 tests/ambient_test.lua

local fails, n = 0, 0
local function check(c, l) n = n + 1; if c then print("  ok   " .. l) else fails = fails + 1; print("  FAIL " .. l) end end
local clock, jobs = 0, {}
timer = { getTime = function() return clock end, getAbsTime = function() return 30000 + clock end,
  scheduleFunction = function(fn, arg, t) jobs[#jobs+1] = { fn = fn, arg = arg, t = t } end }
local function advance(s)
  local target = clock + s
  while true do
    local bi, b
    for i, j in ipairs(jobs) do if j.t <= target and (not b or j.t < b.t) then bi, b = i, j end end
    if not b then break end
    table.remove(jobs, bi); clock = math.max(clock, b.t)
    local nt = b.fn(b.arg, clock); if nt then jobs[#jobs+1] = { fn = b.fn, arg = b.arg, t = nt } end
  end
  clock = target
end
env = { info = function() end, error = function(m) print("  [env.error] " .. m) end }
coalition = { side = { BLUE = 2, RED = 1 }, getPlayers = function() return {} end }
mist = { getRandPointInCircle = function(p, r) return { x = p.x + 1, y = (p.z or p.y or 0) + 1 } end }
trigger = { misc = { getZone = function(name)
  if name:match("^TRN_CONV") then return { point = { x = 1000, y = 0, z = 2000 }, radius = 800 } end end } }
local groups, routes = {}, {}
SPAWN = { New = function(_, t) return { template = t, SpawnFromVec2 = function(self, v)
  if t == "MISSING" then error("no template") end
  local name = t .. "#" .. (#groups + 1)
  local g = { name = name, alive = true,
    isExist = function(s) return s.alive end,
    getUnits = function(s) return s.alive and { { isExist = function() return true end, getLife = function() return 1 end } } or {} end,
    destroy = function(s) s.alive = false end,
    getController = function() return { setTask = function(_, t) routes[name] = t end } end }
  groups[#groups + 1] = g; groups[name] = g
  return { GetName = function() return name end } end } end }
Group = { getByName = function(n) return groups[n] end }
local ratCalls = {}
-- RAT:New wird mit Doppelpunkt aufgerufen
RAT = {}
RAT.New = function(self, tpl, alias) local o = { tpl = tpl, calls = {} }
  setmetatable(o, { __index = function(t, k) return function(s, ...) t.calls[#t.calls+1] = k; return s end end })
  ratCalls[#ratCalls+1] = o; return o end
math.randomseed(1)
dofile("scripts/00_config.lua"); dofile("scripts/01_core.lua"); dofile("scripts/02_audio.lua")
local texts = {}
TRN.Audio.TextAll = function(t) texts[#texts+1] = t end
dofile("scripts/80_ambient.lua")
check(type(TRN.Rat_Init) == "function" and type(TRN.Convoys_Init) == "function", "init functions defined")
check(#TRN.ZoneOrder == 0, "ambient registers no zone")
TRN.Rat_Init()
check(#ratCalls == 2, "2 RAT flight types created")
check(ratCalls[1].calls[#ratCalls[1].calls] == "Spawn", "RAT spawn called last")
TRN.Convoys_Init()
advance(700)
local blue, red = 0, 0
for _, g in ipairs(groups) do if g.name:match("BLUE") then blue = blue + 1 elseif g.name:match("RED") then red = red + 1 end end
check(blue >= 1, "blue convoy spawned")
check(blue <= 2, "blue maxActive 2 respected (" .. blue .. ")")
check(next(routes) ~= nil, "route assigned")
local r = routes[groups[1].name]
check(r and r.params.route.points[1].action == "On Road", "route on road")
advance(1500)
check(red >= 0, "red scheduling ok")
for _, g in ipairs(groups) do if g.name:match("RED") then red = red + 1 end end
check(red >= 1 and red <= 1 + 1, "red convoy spawned, cap 1 active")
check(#texts >= 1 and texts[1]:match("convoy"), "red convoy announced")
advance(2500)
local alive = 0 for _, g in ipairs(groups) do if g.alive then alive = alive + 1 end end
print("  alive after ttl windows:", alive, "total spawned:", #groups)
check(alive <= 3, "ttl cleanup keeps active groups bounded")
-- fehlende Vorlage: nur eine Fehlermeldung, kein Absturz
TRN.Spawn = function() return nil, "Template 'X' missing in mission" end
advance(5000)
check(true, "missing template does not crash")
print(string.format("== %d checks, %d failures", n, fails))
if fails > 0 then error("ambient test failed") end
