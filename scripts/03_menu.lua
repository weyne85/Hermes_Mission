-- 03_menu.lua
-- F10-Funkmenue pro Spielergruppe (nicht global). Wird fuer jede neue Spielergruppe automatisch aufgebaut,
-- egal ob Singleplayer oder Multiplayer, und nach einem Respawn neu erstellt.
-- Abhaengigkeiten: Moose (MENU_GROUP, MENU_GROUP_COMMAND, GROUP), 01_core.lua, 02_audio.lua

TRN = TRN or {}
local CFG = TRN.CFG

TRN.Menu = {}
TRN.Menu.hooks = {}
local known = {}   -- Gruppenname -> true, solange die Gruppe als Spielergruppe existiert

local HELP_TEXT = table.concat({
  "CAUCASUS STRIKE - HELP",
  "1) F10 > Training Zones > pick a zone > pick a difficulty (EASY / MEDIUM / HARD).",
  "2) Fly the exercise. Calls and results are announced on your own group only.",
  "3) When a round is finished, a new one starts automatically.",
  "4) Use 'Stop / Reset' to end the exercise and clean up the zone.",
  "5) 'Info' shows location, frequencies and notes of the zone.",
  "Each zone serves one flight at a time.",
}, "\n")

-- Registriert eine Funktion fn(groupName, dcsUnit), die einmal fuer jede neue Spielergruppe aufgerufen wird.
-- Noetig, weil Moose AIRBOSS und RANGE ihre F10-Menues nur beim Birth-Ereignis anlegen. Sitzt der Spieler beim
-- Missionsstart schon im Flugzeug, kam dieses Ereignis VOR dem Laden der Skripte und das Menue fehlt.
function TRN.Menu.OnNewPlayer(fn)
  TRN.Menu.hooks[#TRN.Menu.hooks + 1] = fn
end

local function say(groupName, text)
  TRN.Audio.Text(groupName, text)
end

local function startZone(groupName, id, level, mode)
  local z = TRN.Zones[id]
  if not z then return end
  z:Start(groupName, level, mode)
end

local function stopZone(groupName, id)
  local z = TRN.Zones[id]
  if not z then return end
  if z:Owner() == groupName then
    z:Stop()
  elseif z:IsBusy() then
    TRN.Audio.Say(groupName, "zone_busy")
  else
    say(groupName, "Nothing to stop - this zone is not running.")
  end
end

local function showInfo(groupName, id)
  local z = TRN.Zones[id]
  if z and z.def.info then
    local ok, text = pcall(z.def.info, groupName)
    say(groupName, ok and text or ("Info not available: " .. tostring(text)))
  end
end

local function buildMenu(groupName)
  local g = GROUP:FindByName(groupName)
  if not g then return false end

  local root = MENU_GROUP:New(g, CFG.MENU_ROOT)
  MENU_GROUP_COMMAND:New(g, "Help", root, function() say(groupName, HELP_TEXT) end)

  for _, id in ipairs(TRN.ZoneOrder) do
    local z = TRN.Zones[id]
    local def = z.def
    local zm = MENU_GROUP:New(g, def.title, root)

    if def.info then
      MENU_GROUP_COMMAND:New(g, "Info", zm, showInfo, groupName, id)
    end

    if def.startable ~= false then
      for _, level in ipairs(CFG.LEVELS) do
        if def.modes then
          local lm = MENU_GROUP:New(g, "Start " .. level, zm)
          for _, mode in ipairs(def.modes) do
            MENU_GROUP_COMMAND:New(g, mode, lm, startZone, groupName, id, level, mode)
          end
        else
          MENU_GROUP_COMMAND:New(g, "Start " .. level, zm, startZone, groupName, id, level, nil)
        end
      end
    end

    for _, extra in ipairs(def.extras or {}) do
      MENU_GROUP_COMMAND:New(g, extra.text, zm, function() extra.fn(groupName) end)
    end

    if def.startable ~= false then
      MENU_GROUP_COMMAND:New(g, "Stop / Reset", zm, stopZone, groupName, id)
    end
  end
  return true
end

local function scan()
  local current = TRN.PlayerGroups()

  -- Gruppen, die nicht mehr existieren, vergessen (Menue verschwindet mit der Unit)
  for name in pairs(known) do
    if not current[name] then
      known[name] = nil
      TRN.Debug("menu: group %s gone", name)
    end
  end

  -- neue Spielergruppen: Menue aufbauen
  for name in pairs(current) do
    if not known[name] then
      local ok, built = pcall(buildMenu, name)
      if ok and built then
        known[name] = true
        TRN.Log("menu built for group %s", name)
        TRN.Audio.Say(name, "welcome")
      elseif not ok then
        TRN.Error("menu build failed for %s: %s", name, tostring(built))
        known[name] = true   -- nicht endlos wiederholen
      end
      if known[name] then
        for _, hook in ipairs(TRN.Menu.hooks) do
          local hok, herr = pcall(hook, name, current[name].unit)
          if not hok then TRN.Error("player hook failed for %s: %s", name, tostring(herr)) end
        end
      end
    end
  end
end

function TRN.Menu.Start()
  TRN.Every(CFG.MENU_SCAN, scan, 1)
end
