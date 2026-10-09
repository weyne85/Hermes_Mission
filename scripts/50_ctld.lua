-- 50_ctld.lua
-- Zone 5: Transport (Moose CTLD). Hubschrauber nehmen Truppen im Ladegebiet auf und setzen sie im Abwurfgebiet ab.
-- Erfuellt, sobald die geforderte Anzahl Soldaten im Abwurfgebiet abgesetzt ist.
-- Abhaengigkeiten: Moose (CTLD, CTLD_CARGO), 01_core.lua, 02_audio.lua. Die Moose-CTLD wird erst beim ersten
-- Rundenstart erzeugt, damit Missionen ohne Transportaufgabe kein CTLD-Menue bekommen.
-- Die Truppen-Vorlage TRN_CTLD_TROOPS (Late Activation) und die Zonen stehen in der Mission (build_miz.py).

TRN = TRN or {}
local CFG = TRN.CFG
local C = CFG.TRANSPORT

local def = { id = C.id, title = C.title, cfg = C }
local ctld   -- Moose-CTLD-Instanz

function def.info()
  local z = TRN.ZoneInfo(C.dropZone)
  local l = TRN.ZoneInfo(C.loadZone)
  if not z or not l then return "Zones '" .. C.loadZone .. "' / '" .. C.dropZone .. "' are missing in the mission." end
  return string.format(
    "TRANSPORT (CTLD)\nLoading area (MGRS): %s. Outpost (MGRS): %s, radius %.1f nm.\n" ..
    "Open the F10 CTLD menu, load troops in the loading area, fly to the outpost and deploy them.\n" ..
    "EASY: %d troops. MEDIUM: %d. HARD: %d plus AAA at the outpost.\n" ..
    "Mi-24P carries 8 troops, AH-64D only 2.",
    TRN.MGRS(l.point, 3), TRN.MGRS(z.point, 3), TRN.ToNm(z.radius),
    C.levels.EASY.troops, C.levels.MEDIUM.troops, C.levels.HARD.troops)
end

-- Wird von der CTLD aufgerufen, wenn Truppen abgesetzt wurden (troops = Moose-GROUP der abgesetzten Truppen)
function TRN.Transport_Deployed(unit, troops)
  local zone = TRN.Zones[C.id]
  local s = zone and zone.session
  if not s or s.state ~= "RUN" or not s.data.need then return end

  local ok, pos = pcall(function() return troops:GetVec3() end)
  if not ok or not pos then
    ok, pos = pcall(function() return unit:GetVec3() end)
  end
  if not ok or not pos then
    TRN.Error("Transport: no position for deployed troops")
    return
  end
  if not TRN.InZone(pos, C.dropZone) then
    if s.group then
      TRN.Audio.Text(s.group, "Troops deployed outside the outpost area.")
    else
      TRN.Audio.TextAll("Troops deployed outside the outpost area.")
    end
    return
  end
  local okSize, size = pcall(function() return troops:GetSize() end)
  s.data.delivered = s.data.delivered + ((okSize and size) or C.troopsPerLoad)
  s:Say("tr_delivered", string.format("%d of %d troops at the outpost.", s.data.delivered, s.data.need))
end

local function ensureCtld()
  if ctld then return true end
  if not (CTLD and CTLD_CARGO and SMOKECOLOR) then return false, "Moose CTLD not loaded" end
  ctld = CTLD:New(CFG.SIDE.BLUE, C.pilotPrefixes, "Transport")
  ctld.useprefix = true
  ctld:AddTroopsCargo(C.cargoName, { C.troopTemplate }, CTLD_CARGO.Enum.TROOPS, C.troopsPerLoad)
  ctld:AddCTLDZone(C.loadZone, CTLD.CargoZoneType.LOAD, SMOKECOLOR.Blue, true, false)
  ctld:AddCTLDZone(C.dropZone, CTLD.CargoZoneType.DROP, SMOKECOLOR.Red, true, false)
  function ctld:OnAfterTroopsDeployed(From, Event, To, Group, Unit, Troops)
    local ok, err = pcall(TRN.Transport_Deployed, Unit, Troops)
    if not ok then TRN.Error("Transport deploy handler: %s", tostring(err)) end
  end
  ctld:__Start(2)
  TRN.Log("CTLD started (prefixes: %s)", table.concat(C.pilotPrefixes, ", "))
  return true
end

function def.OnRound(s)
  local lv = s.lv
  for _, name in ipairs({ C.loadZone, C.dropZone }) do
    if not TRN.ZoneInfo(name) then return false, "Trigger zone '" .. name .. "' is missing" end
  end
  local ok, err = ensureCtld()
  if not ok then return false, err end

  s.data.need = lv.troops
  s.data.delivered = 0

  for _, tpl in ipairs(lv.escorts or {}) do
    local vec2 = TRN.RandomPointInZone(C.dropZone)
    if vec2 then
      local name = TRN.Spawn(tpl, vec2)
      if name then s:Track(name) end
    end
  end

  local load = TRN.ZoneInfo(C.loadZone)
  local drop = TRN.ZoneInfo(C.dropZone)
  s:Say("tr_briefing", s:RoundTag() .. string.format("Deliver %d troops. Load at MGRS %s, deploy at MGRS %s.",
    lv.troops, TRN.MGRS(load.point, 3), TRN.MGRS(drop.point, 3)))
  return true
end

function def.OnTick(s)
  if s.data.delivered >= s.data.need then
    s:Say("tr_complete", string.format("Round %d finished in %s.", s.rounds, s:ElapsedText()))
    return "done"
  end
end

TRN.RegisterZone(def)
