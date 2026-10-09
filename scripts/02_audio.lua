-- 02_audio.lua
-- Einzige Stelle, die Ansagen ausgibt. Alle Ansagen sind Bildschirmtexte (englisch) an die betroffene
-- Spielergruppe. Ueberlappende Ansagen an dieselbe Gruppe werden nacheinander angezeigt.

TRN = TRN or {}
local CFG = TRN.CFG

TRN.Audio = {}
local nextFree = {}   -- Gruppenname -> Zeitpunkt, ab dem die naechste Ansage moeglich ist

local function groupId(groupName)
  local p = TRN.PlayerGroups()[groupName]
  return p and p.id or nil
end

local function output(groupName, text)
  local id = groupId(groupName)
  if not id or not text or text == "" then return end
  local secs = math.max(8, math.min(30, math.floor(#text / 12) + 4))
  trigger.action.outTextForGroup(id, text, secs, false)
end

-- Reiht eine Ausgabe fuer eine Gruppe ein.
local function enqueue(groupName, text, dur)
  local now = timer.getTime()
  local at = math.max(now, nextFree[groupName] or 0)
  nextFree[groupName] = at + (dur or 3) + 0.5
  if at <= now then
    output(groupName, text)
  else
    TRN.After(at - now, function() output(groupName, text) end)
  end
end

-- Ereignis-Ansage. extra: optionaler dynamischer Text, wird an den festen Text angehaengt.
function TRN.Audio.Say(groupName, key, extra)
  local def = CFG.MESSAGES[key]
  if not def then
    TRN.Error("Unknown message key '%s'", tostring(key))
    return
  end
  local text = def.text
  if extra and extra ~= "" then text = text .. " " .. extra end
  enqueue(groupName, text, def.dur)
end

-- Ereignis-Ansage an alle Spielergruppen (Missionsmodus ohne Besitzer)
function TRN.Audio.SayAll(key, extra)
  for name in pairs(TRN.PlayerGroups()) do TRN.Audio.Say(name, key, extra) end
end

-- Freier Text (dynamische Werte wie BRAA, 9-Line)
function TRN.Audio.Text(groupName, text)
  enqueue(groupName, text, 3)
end

-- Freier Text an alle Spielergruppen (z. B. Lagemeldung zu einem Konvoi)
function TRN.Audio.TextAll(text)
  for name in pairs(TRN.PlayerGroups()) do
    TRN.Audio.Text(name, text)
  end
end
