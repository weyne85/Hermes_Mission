-- 10_sead.lua
-- Zone 1: SEAD/DEAD. Zufaelliges SAM-System (je Schwierigkeit) in TRN_SE_ZONE.
-- SEAD  = Radare (Such- und Feuerleitradar) ausschalten bzw. zerstoeren.
-- DEAD  = das komplette SAM-System zerstoeren.
-- Ansagen: "Threat radar" beim Annaehern, "Missile launch" bei jedem Raketenstart eines SAM der Runde.

TRN = TRN or {}
local CFG = TRN.CFG
local C = CFG.SEAD

local def = { id = C.id, title = C.title, cfg = C, modes = C.modes }

function def.info()
  local z = TRN.ZoneInfo(C.zone)
  if not z then return "Zone '" .. C.zone .. "' is missing in the mission." end
  return string.format(
    "SEAD / DEAD\nSite area (MGRS): %s, radius %.1f nm.\nSEAD: shut down or destroy the radars.\n" ..
    "DEAD: destroy the whole SAM site.\nEASY: SA-2/SA-3. MEDIUM: SA-6/SA-11 plus AAA.\n" ..
    "HARD: SA-8 plus SA-15 and AAA (dense, low altitude).\n" ..
    "Warnings: 'Threat radar' when you approach, 'Missile launch' on every SAM launch.",
    TRN.MGRS(z.point, 3), TRN.ToNm(z.radius))
end

local function hasRadarAttribute(unit)
  for _, attr in ipairs(C.radarAttributes) do
    if unit:hasAttribute(attr) then return true end
  end
  return false
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

  local vec2 = TRN.RandomPointInZone(C.zone)
  if not vec2 then return false, "Trigger zone '" .. C.zone .. "' is missing" end

  local main, err = TRN.Spawn(TRN.Pick(lv.main), vec2)
  if not main then return false, err end
  s:Track(main)
  s.data.main = main
  s.data.warned = false

  -- Begleitschutz in der Nahe
  for _, tpl in ipairs(lv.escorts or {}) do
    local p = mist.getRandPointInCircle({ x = vec2.x, y = 0, z = vec2.y }, 1500, 300)
    local name = TRN.Spawn(tpl, p)
    if name then s:Track(name) end
  end

  -- Radar-Units merken (fuer SEAD)
  s.data.radars = {}
  for _, u in ipairs(TRN.GroupAliveUnits(main)) do
    if hasRadarAttribute(u) then s.data.radars[#s.data.radars + 1] = u:getName() end
  end

  s.data.mode = s.mode or "DEAD"
  if s.data.mode == "SEAD" and #s.data.radars == 0 then
    s.data.mode = "DEAD"   -- kein Radar erkannt: Ziel wie DEAD werten
  end

  local center = { x = vec2.x, y = 0, z = vec2.y }
  s:Say("se_briefing", string.format("%s%s. Site: %s, MGRS %s.", s:RoundTag(),
    s.data.mode, typeList(main), TRN.MGRS(center, 3)))
  return true
end

local function mainAlive(s)
  return #TRN.GroupAliveUnits(s.data.main) > 0
end

local function radarsAlive(s)
  for _, name in ipairs(s.data.radars) do
    local u = Unit.getByName(name)
    if u and u:isExist() and u:getLife() > 0 then return true end
  end
  return false
end

function def.OnTick(s)
  local player = TRN.PlayerUnit(s.group)

  -- Radar-Warnung (einmalig je Runde)
  if player and not s.data.warned then
    local first = TRN.GroupAliveUnits(s.data.main)[1]
    if first then
      local pp, sp = player:getPoint(), first:getPoint()
      local dist = TRN.Dist2D(pp, sp)
      if dist <= C.threatWarnRangeKm * 1000 then
        s.data.warned = true
        s:Say("se_radar", string.format("Bearing %03d, %d nm.", TRN.Bearing(pp, sp), math.floor(TRN.ToNm(dist) + 0.5)))
      end
    end
  end

  local done
  if s.data.mode == "SEAD" then
    done = not radarsAlive(s)
  else
    done = not mainAlive(s)
  end
  if done then
    s:Say("se_complete", string.format("Mode %s, round %d finished in %s.", s.data.mode, s.rounds, s:ElapsedText()))
    return "done"
  end
end

-- Raketenstart-Warnung
local handler = {}
function handler:onEvent(e)
  if not e or e.id ~= world.event.S_EVENT_SHOT then return end
  local zone = TRN.Zones[C.id]
  local s = zone and zone.session
  if not s then return end

  local ok, err = pcall(function()
    local shooter = e.initiator
    if not shooter or not shooter.getGroup then return end
    local grp = shooter:getGroup()
    if not grp then return end
    local gname = grp:getName()
    local mine = false
    for _, n in ipairs(s.tracked) do
      if n == gname then mine = true; break end
    end
    if not mine then return end
    if e.weapon and e.weapon.getDesc and e.weapon:getDesc().category ~= Weapon.Category.MISSILE then return end

    local player = TRN.PlayerUnit(s.group)
    if not player then return end
    local pp, sp = player:getPoint(), shooter:getPoint()
    s:Say("se_launch", string.format("Bearing %03d, %d nm.", TRN.Bearing(pp, sp), math.floor(TRN.ToNm(TRN.Dist2D(pp, sp)) + 0.5)))
  end)
  if not ok then TRN.Error("SEAD shot handler: %s", tostring(err)) end
end
world.addEventHandler(handler)

TRN.RegisterZone(def)
