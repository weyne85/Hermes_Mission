-- GENERIERT von tools/build_missions.py aus tools/missions.py - nicht von Hand aendern.
TRN = TRN or {}
TRN.MISSION = {
  id = "S1", title = "Auftakt", autostart = true, startDelay = 20,
  objectives = {
    { zone = "COMBINED", level = "EASY", mode = "STRIKE", forTypes = { "FA-18C_hornet", "F-16C_50", "A-10C_2" } },
    { zone = "AG", level = "EASY" },
  },
}
