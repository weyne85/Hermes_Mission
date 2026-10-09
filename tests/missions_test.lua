-- tests/missions_test.lua
-- Prueft die erzeugten Missionsdateien scripts/missions/<ID>.lua gegen scripts/00_config.lua:
-- Aufgaben verweisen auf vorhandene Zonen, Stufen und Modi. Start (im Repo-Hauptverzeichnis): lua5.1 tests/missions_test.lua
-- Die Dateien erzeugt tools/build_missions.py aus tools/missions.py.

local failures, checks = 0, 0
local function check(cond, label)
  checks = checks + 1
  if cond then print("  ok   " .. label) else failures = failures + 1; print("  FAIL " .. label) end
end

dofile("scripts/00_config.lua")
local CFG = TRN.CFG

local levels = {}
for _, l in ipairs(CFG.LEVELS) do levels[l] = true end

local p = io.popen("ls scripts/missions")
local files = {}
for line in p:lines() do if line:match("%.lua$") then files[#files + 1] = line end end
p:close()
check(#files > 0, "Missionsdateien vorhanden (" .. #files .. ")")

for _, file in ipairs(files) do
  TRN.MISSION = nil
  local chunk, err = loadfile("scripts/missions/" .. file)
  check(chunk ~= nil, file .. ": laedt (" .. tostring(err) .. ")")
  if chunk then
    chunk()
    local M = TRN.MISSION
    check(M and M.id .. ".lua" == file, file .. ": Id passt zum Dateinamen")
    check(M and type(M.autostart) == "boolean" and type(M.startDelay) == "number", file .. ": autostart und startDelay")
    check(M and type(M.objectives) == "table" and (M.autostart == false or #M.objectives > 0),
      file .. ": hat Aufgaben (Tutorials ohne)")
    for _, ev in ipairs(M and M.events or {}) do
      check(type(ev.after) == "number" and type(ev.action) == "string", file .. ": Ereignis " .. tostring(ev.action))
    end
    for i, o in ipairs(M and M.objectives or {}) do
      if o.forTypes then check(type(o.forTypes[1]) == "string", string.format("%s: Aufgabe %d forTypes", file, i)) end
      local zc = CFG[o.zone]
      check(zc ~= nil and zc.id == o.zone, string.format("%s: Aufgabe %d Zone %s existiert", file, i, tostring(o.zone)))
      check(levels[o.level] == true and zc and zc.levels and zc.levels[o.level] ~= nil,
        string.format("%s: Aufgabe %d Stufe %s", file, i, tostring(o.level)))
      if o.mode then
        local ok = false
        for _, m in ipairs(zc and zc.modes or {}) do if m == o.mode then ok = true end end
        check(ok, string.format("%s: Aufgabe %d Modus %s", file, i, o.mode))
      end
    end
  end
end

print(string.format("\n===== %d Pruefungen, %d Fehler =====", checks, failures))
if failures > 0 then error("missions_test failed") end
