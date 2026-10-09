-- 30_ag.lua
-- Zone 3: Air-to-Ground. AH-64D + Mi-24P.
-- Konvois (BWP) fahren auf StraBen von TRN_AG_START nach TRN_AG_END.
-- Der Hehler/Stryker spawnt in der Zielzone und muessen die Konvois austragen.
-- Ablauf: Start > Konvois erscheinen auf StraBen > helen die Einsaetze > Bewegung beobachten
--         > "Targets remaining" > alle zerstroet: Abschluss, neue Runde.

TRN = TRN or {}
local CFG = TRN.CFG
local C = CFG.AG

local def = { id = C.id, title = C.title, cfg = C }

function def.info()
  local z = TRN.ZoneInfo(C.zone)
  if not z then return "Zone '" .. C.zone .. "' is missing in the mission." end
  local lv = C.levels.EASY
  if s and s.level and C.levels[s.level] then lv = C.levels[s.level] end
  local count = lv and (lv.pool and #lv.pool or C.numTargets or 0)
  return string.format(
    "AIR-TO-GROUND\nTarget area (MGRS): %s, radius %.1f nm.\n" ..
    "Convoy tempo: EASY 20 km/h, MEDIUM 35 km/h, HARD 50 km/h.\n" ..
    "EASY: %d vehicle group, MEDIUM: %d, HARD: %d groups + AAA escort.\n" ..
    "Your helicopters must destroy the moving targets.",
    TRN.MGRS(z.point, 3), TRN.ToNm(z.radius), #C.levels.EASY.pool or 1,
    #C.levels.MEDIUM.pool or 1, #C.levels.HARD.pool or 1)
end

local function typeList(groupName)
  local seen, out = {}, {}
  for _, u in ipairs(TRN.GroupAliveUnits(groupName)) do
    local t = u:getTypeName()
    if not seen[t] then seen[t] = true; out[#out + 1] = t end
  end
  return table.concat(out, ", ")
end

function def.OnRound(s)
  local lv = s.lv
  s.data.targets = {}
  s.data.escorts = {}
  local lines = { "CONVOY TARGETS:" }

  for i = 1, lv.count do
    local vec2 = TRN.RandomPointInZone(C.zone)
    if not vec2 then return false, "Trigger zone '" .. C.zone .. "' is missing" end
    local name, err = TRN.Spawn(TRN.Pick(lv.pool), vec2)
    if not name then return false, err end
    s:Track(name)
    s.data.targets[#s.data.targets + 1] = name
    lines[#lines + 1] = string.format("Target %d: %s, MGRS %s", i, typeList(name),
      TRN.MGRS({ x = vec2.x, y = 0, z = vec2.y }, 4))
  end

  -- Begleit-Einheiten (AAA) - kein Ziel, nur Gelegenheitsziel
  for _, tpl in ipairs(lv.escorts or {}) do
    local vec2 = TRN.RandomPointInZone(C.zone)
    if vec2 then
      local name = TRN.Spawn(tpl, vec2)
      if name then s:Track(name) end
    end
  end

  s:Say("ag_briefing", s:RoundTag() .. table.concat(lines, "\n"))
  return true
end

local function targetType(groupName)
  local units = TRN.GroupAliveUnits(groupName)
  if units[1] then return units[1]:getTypeName() end
  return "unknown"
end

function def.OnTick(s)
  local alive = s:CountAlive(s.data.targets, function(left)
    s:Say("ag_hit", string.format("Targets remaining: %d.", left))
  end)
  if alive == 0 then
    s:Say("ag_complete", string.format("Round %d finished in %s.", s.rounds, s:ElapsedText()))
    return "done"
  end
end

TRN.RegisterZone(def)
