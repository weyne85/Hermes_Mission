-- 20_strike.lua
-- Zone 2: STRIKE. F/A-18C + F-16C.
-- Feste, zufaellig positionierte Ziel-Vorlagen in TRN_ST_ZONE.
-- Bombenwerfen mit Trefferradius (goodHitM). Assistenten (AAA) als Gelegenheitsziele.
-- Ablauf: Start > Ziel-Positionen einladen (MGRS) > abwuerfen > "Targets remaining"
--         > alle Zerstoert: Abschlussmeldung, nach 20s neue Runde.

TRN = TRN or {}
local CFG = TRN.CFG
local C = CFG.STRIKE

local def = { id = C.id, title = C.title, cfg = C }

function def.info()
  local z = TRN.ZoneInfo(C.zone)
  if not z then return "Zone '" .. C.zone .. "' is missing in the mission." end
  local sample = C.levels.EASY.targets and #C.levels.EASY.targets or C.numTargets
  return string.format(
    "STRIKE\nTarget area (MGRS): %s, radius %.1f nm.\nTargets: %d per round depending on difficulty." ..
    "EASY: %d, MEDIUM: %d, HARD: %d (adds AAA escort).\nRelease bombs in the target area (radius %.0f m).",
    TRN.MGRS(z.point, 3), TRN.ToNm(z.radius), sample,
    #C.levels.EASY.targets or C.numTargets,
    #C.levels.MEDIUM.targets or C.numTargets,
    #C.levels.HARD.targets or C.numTargets,
    C.goodHitM)
end

-- Map difficulty -> target count
local function countTargets(level)
  if not level then return C.numTargets end
  local lvl = C.levels[level]
  if not lvl then return C.numTargets end
  if lvl.targets then return #lvl.targets end
  return C.numTargets
end

function def.OnRound(s)
  local lv = s.lv
  s.data.targets = {}
  local lines = { "TARGETS:" }
  local num = countTargets(s.level)

  -- Zufaellige Ziel-Positionen
  for i = 1, num do
    local vec2 = TRN.RandomPointInZone(C.zone)
    if not vec2 then return false, "Trigger zone '" .. C.zone .. "' is missing" end
    local name, err = TRN.Spawn(TRN.Pick(lv.targets), vec2)
    if not name then return false, err end
    s:Track(name)
    s.data.targets[#s.data.targets + 1] = name
    lines[#lines + 1] = string.format("Target %d: %s, MGRS %s", i, targetType(name),
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

  s:Say("st_briefing", s:RoundTag() .. table.concat(lines, "\n"))
  return true
end

local function targetType(groupName)
  local units = TRN.GroupAliveUnits(groupName)
  if units[1] then return units[1]:getTypeName() end
  return "unknown"
end

function def.OnTick(s)
  local alive = s:CountAlive(s.data.targets, function(left)
    s:Say("st_hit", string.format("Targets remaining: %d.", left))
  end)
  if alive == 0 then
    s:Say("st_complete", string.format("Round %d finished in %s.", s.rounds, s:ElapsedText()))
    return "done"
  end
end

TRN.RegisterZone(def)
