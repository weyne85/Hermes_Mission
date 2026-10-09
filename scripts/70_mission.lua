-- 70_mission.lua
-- Missionsmodus fuer Kampagnenmissionen. Eine Datei scripts/missions/<ID>.lua setzt TRN.MISSION:
--   TRN.MISSION = {
--     id = "S1", title = "Auftakt",
--     autostart = true,                      -- false: Menuemodus (Tutorials), diese Datei tut dann nichts
--     startDelay = 15,                       -- Sekunden zwischen erstem Spieler und Start der Aufgaben
--     objectives = { { zone = "COMBINED", level = "EASY", mode = "STRIKE", forTypes = { "FA-18C_hornet" } },
--                    { zone = "AG", level = "EASY" } },
--     events = { { after = 300, action = "shootdown" } },   -- optional, Sekunden nach Aufgabenstart (TRN.MissionActions)
--   }
-- forTypes (optional): die Aufgabe gilt nur, wenn beim Start ein Spieler mit einem dieser DCS-Typnamen da ist
-- (so bleibt eine gemeinsame Mission auch mit einem einzelnen Jet oder Hubschrauber loesbar).
-- Alle Aufgaben starten ohne Besitzer (eine Runde). Erfolg = alle Aufgaben erfuellt, Misserfolg = eine Aufgabe
-- scheitert (Ziel entkommen, Timeout, Fehler) oder alle Spieler sind verloren.
-- Ergebnis: User-Flag TRN_<ID>_WIN bzw. TRN_<ID>_FAIL wird auf 1 gesetzt (Mission Goals / Kampagne werten es aus).
-- Abhaengigkeiten: 01_core.lua, 02_audio.lua, Zonenmodule

TRN = TRN or {}
local CFG = TRN.CFG

local runId = 0
local LOST_TICKS = 3   -- Pruefungen ohne Spielergruppe bis "alle verloren"

local REASON = {
  fail = "an objective failed",
  timeout = "time expired",
  error = "mission setup error (see dcs.log)",
  lost = "all flights lost",
}

local function setFlag(name)
  if trigger and trigger.action and trigger.action.setUserFlag then
    trigger.action.setUserFlag(name, 1)
  end
end

function TRN.Mission_Init()
  local M = TRN.MISSION
  if not M then return end
  if M.autostart == false then
    TRN.Log("Mission %s: menu mode", tostring(M.id))
    return
  end

  runId = runId + 1
  local myRun = runId
  local state = { started = false, done = false, wins = 0, needed = #(M.objectives or {}), lost = 0, result = nil }
  TRN.Mission = { id = M.id, state = state }

  local objectives = M.objectives or {}

  local function finishMission(win, why)
    if state.done then return end
    state.done = true
    state.result = win and "WIN" or "FAIL"
    setFlag("TRN_" .. M.id .. (win and "_WIN" or "_FAIL"))
    TRN.Log("Mission %s: %s%s", M.id, state.result, why and (" (" .. why .. ")") or "")
    if win then
      TRN.Audio.TextAll("MISSION COMPLETE: " .. tostring(M.title or M.id) .. ".")
    else
      TRN.Audio.TextAll("MISSION FAILED: " .. tostring(M.title or M.id) .. " - " .. (REASON[why] or tostring(why)) .. ".")
    end
    -- laufende Aufgaben einfrieren (Timer aus, Wracks bleiben)
    for _, o in ipairs(objectives) do
      local z = TRN.Zones[o.zone]
      if z and z.session then z:Finish("aborted") end
    end
  end

  local function onObjective(result)
    if state.done then return end
    if result == "win" then
      state.wins = state.wins + 1
      if state.wins >= state.needed then finishMission(true) end
    else
      finishMission(false, result)
    end
  end

  -- DCS-Typnamen der anwesenden Spieler
  local function presentTypes()
    local set = {}
    for _, p in pairs(TRN.PlayerGroups()) do
      local ok, t = pcall(function() return p.unit:getTypeName() end)
      if ok and t then set[t] = true end
    end
    return set
  end

  local function isActive(o, present)
    if not o.forTypes then return true end
    for _, t in ipairs(o.forTypes) do
      if present[t] then return true end
    end
    return false
  end

  local function scheduleEvents()
    for _, ev in ipairs(M.events or {}) do
      TRN.After(ev.after or 0, function()
        if state.done then return end
        local fn = TRN.MissionActions and TRN.MissionActions[ev.action]
        if not fn then
          TRN.Error("Mission %s: unknown event action '%s'", tostring(M.id), tostring(ev.action))
          return
        end
        local ok, err = pcall(fn, M, ev)
        if not ok then TRN.Error("Mission %s: event '%s' failed: %s", tostring(M.id), tostring(ev.action), tostring(err)) end
      end)
    end
  end

  local function startObjectives()
    if state.done then return end
    local present = presentTypes()
    local active = {}
    for _, o in ipairs(objectives) do
      if isActive(o, present) then active[#active + 1] = o end
    end
    state.needed = #active
    if #active == 0 then
      TRN.Error("Mission %s: no objective applies to the present aircraft types", tostring(M.id))
      finishMission(false, "error")
      return
    end
    TRN.Audio.TextAll("MISSION START: " .. tostring(M.title or M.id) .. ".")
    for _, o in ipairs(active) do
      if state.done then return end
      local z = TRN.Zones[o.zone]
      if not z then
        TRN.Error("Mission %s: zone '%s' unknown", tostring(M.id), tostring(o.zone))
        finishMission(false, "error")
        return
      end
      local ok = z:Start(nil, o.level, o.mode, { single = true, onFinish = onObjective })
      if not ok then
        finishMission(false, "error")
        return
      end
    end
    scheduleEvents()
  end

  -- Start, sobald der erste Spieler da ist
  TRN.Every(2, function()
    if myRun ~= runId or state.done then return false end
    if next(TRN.PlayerGroups()) then
      state.started = true
      TRN.After(M.startDelay or 10, startObjectives)
      return false
    end
  end, 1)

  -- Totalverlust: keine Spielergruppe mehr
  TRN.Every(CFG.TICK, function()
    if myRun ~= runId or state.done then return false end
    if not state.started then return end
    if next(TRN.PlayerGroups()) then
      state.lost = 0
    else
      state.lost = state.lost + 1
      if state.lost >= LOST_TICKS then finishMission(false, "lost") return false end
    end
  end)

  TRN.Log("Mission %s armed (%d objective(s))", tostring(M.id), #objectives)
end
