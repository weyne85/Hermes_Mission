-- GENERIERT von tools/build_missions.py aus tools/missions.py - nicht von Hand aendern.
TRN = TRN or {}
TRN.MISSION = {
  id = "S2", title = "Wendepunkt", autostart = true, startDelay = 20,
  objectives = {
    { zone = "COMBINED", level = "MEDIUM", mode = "STRIKE", forTypes = { "FA-18C_hornet", "F-16C_50", "A-10C_2" } },
    { zone = "AG", level = "MEDIUM" },
  },
  events = {
    { after = 420, action = "shootdown" },
  },
}
