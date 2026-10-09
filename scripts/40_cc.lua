-- 40_cc.lua
-- Zone 4: COMBINED. Alle 4 Flugzeuge (F/A-18C, F-16C, AH-64D, Mi-24P).
-- Ganzes Kampfbox (TRN_CC_ZONE): Red SAM-System (SEAD) + Zielobjekte (Strike) + Konvois.
--
-- Ablauf:
--   1. Jede Spielergruppe waehlt ueber das F10-Menue einen Modus: SEAD (Radare zauschen/zerstroeren)
--      oder STRIKE (Bodenziele bombardieren).
--   2. Runde: der Red SAM startet am Zonenrand im Ring, die Strike-Ziele treffen sich im Zentrum.
--   3. In der aktiv gewaehlten Runde zielt man zuerst auf die SAM (SEAD) oder die Ziele (STRIKE).
--   4. Wenn das aktive Ziel erreicht ist, wird der Erfolg angekundigt und auf "WAIT" fuer 20 s geschaltet.
--      Danach startet automatisch die naechste Runde.
--   5. Wenn beide Modi in einer Runde beendet sind (oder der Spieler beide abschliesslich abschliesst),
--      wird eine Abschliessungsmeldung gegeben und nach 20 s die Runde neu gestartet.
--
-- Jede Spielergruppe hat eine eigene Session; die Zonen-Uebersicht fuer alle wird angekündigt.
-- Die Konvois (Bewegliche Ziele) sind zusaetzliche Gelegenheitsziele und werden allen Gruppen angezeigt.

TRN = TRN or {}
local CFG = TRN.CFG
local C = CFG.COMBINED

local def = { id = C.id, title = C.title, cfg = C, modes = C.modes }

function def.info()
  local z = TRN.ZoneInfo(C.zone)
  if not z then return "Zone '" .. C.zone .. "' is missing in the mission." end
  return string.format(
    "COMBINED\nKampfbox (MGRS): %s, radius %.1f nm.\n" ..
    "Choose a mode via F10 menu: SEAD (suppress/destroy SAM) or STRIKE (bomb targets).\n" ..
    "EASY: %d target(s). MEDIUM: %d, HARD: %d (adds AAA escort).%s",
    TRN.MGRS(z.point, 3), TRN.ToNm(z.radius),
    #C.levels.EASY.targets or 2, #C.levels.MEDIUM.targets or 3, #C.levels.HARD.targets or 4,
    "\nBeware: Red SAM may launch. AWACS gives bogey dope every " .. C.awacsInterval .. " s.")
end

-- Map difficulty -> number of strike targets
local function numTargets(level)
  local lvl = C.levels[level]
  if not lvl then return #C.levels.EASY.targets or 2 end
  if lvl.targets then return #lvl.targets end
  return #C.levels.EASY.targets or 2
end

function def.OnRound(s)
  local lv = s.lv
  s.data.seadDone = false
  s.data.strikeDone = false
  s.data.seadTarget = nil
  s.data.strikeTargets = {}
  s.data.convoy = nil

  -- SEAD-Ziel (SAM-System) - startet im Ring
  local vec2 = TRN.RandomPointInZone(C.zone)
  if not vec2 then return false, "Trigger zone '" .. C.zone .. "' is missing" end

  local sead, err = TRN.Spawn(TRN.Pick(lv.sead), vec2)
  if not sead then return false, err end
  s:Track(sead)
  s.data.seadTarget = sead
  s.data.warned = false
  s.data.activeMode = s.mode or "STRIKE"   -- standardmäßig STRIKE, falls kein Modus gewaehlt

  -- Begleit-Einheiten für SEAD
  for _, tpl in ipairs(lv.escorts or {}) do
    local p = mist.getRandPointInCircle({ x = vec2.x, y = 0, z = vec2.y }, 1500, 300)
    local name = TRN.Spawn(tpl, p)
    if name then s:Track(name) end
  end

  -- Strike-Ziele
  local num = numTargets(s.level)
  for i = 1, num do
    local tvec = TRN.RandomPointInZone(C.zone)
    if not tvec then return false, "Trigger zone '" .. C.zone .. "' is missing" end
    local name, err = TRN.Spawn(TRN.Pick(lv.targets), tvec)
    if not name then return false, err end
    s:Track(name)
    s.data.strikeTargets[#s.data.strikeTargets + 1] = name
  end

  -- Konvois (Bewegliche Ziele, Gelegenheitsziele)
  for i = 1, (lv.convoyPool and 1 or 0) do   -- 1 Konvoi pro Runde, nur wenn die Stufe einen Pool definiert
    local cv = TRN.RandomPointInZone(C.zone)
    if not cv then return false, "Trigger zone '" .. C.zone .. "' is missing" end
    local name, err = TRN.Spawn(TRN.Pick(lv.convoyPool), cv)
    if not name then return false, err end
    s:Track(name)
    s.data.convoy = name
  end

  s:Say("cc_briefing", s:RoundTag("Round") ..
    string.format(" Active mode: %s. SEAD target + %d strike target(s).", s.data.activeMode,
    #s.data.strikeTargets))
  return true
end

-- Hilfsfunktionen
local function typeList(groupName)
  local seen, out = {}, {}
  for _, u in ipairs(TRN.GroupAliveUnits(groupName)) do
    local t = u:getTypeName()
    if not seen[t] then seen[t] = true; out[#out + 1] = t end
  end
  return table.concat(out, ", ")
end

function def.OnTick(s)
  if #TRN.SessionPlayers(s) == 0 then return end

  -- ---- SEAD ----
  if not s.data.seadDone then
    if #TRN.GroupAliveUnits(s.data.seadTarget) == 0 then
      s:Say("cc_sead_complete", string.format("SEAD destroyed. Round %d in %s.", s.rounds, s:ElapsedText()))
      s.data.seadDone = true
    end
  end

  -- ---- STRIKE ----
  if not s.data.strikeDone then
    local alive = s:CountAlive(s.data.strikeTargets, function(left)
      s:Say("st_hit", string.format("Strike targets remaining: %d.", left))
    end)
    if alive == 0 then
      s:Say("cc_strike_complete", string.format("Strike complete. Round %d in %s.", s.rounds, s:ElapsedText()))
      s.data.strikeDone = true
    end
  end

  -- ---- Konvois (Bewegliche Gelegenheitsziele) ----
  if s.data.convoy then
    if #TRN.GroupAliveUnits(s.data.convoy) == 0 then
      s:Say("cc_splash", "Convoy destroyed.")
    end
  end

  -- ---- Abschluss ----
  if s.data.seadDone and s.data.strikeDone then
    s:Say("cc_complete", string.format("All objectives complete. Round %d finished in %s.", s.rounds, s:ElapsedText()))
    return "done"
  end
end

TRN.RegisterZone(def)
