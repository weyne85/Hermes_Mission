-- GENERIERT von tools/build_missions.py aus tools/missions.py - nicht von Hand aendern.
TRN = TRN or {}
TRN.MISSION = {
  id = "S3", title = "Entscheidung", autostart = true, startDelay = 20,
  objectives = {
    { zone = "COMBINED", level = "HARD", mode = "STRIKE", forTypes = { "FA-18C_hornet", "F-16C_50", "A-10C_2" } },
    { zone = "AG", level = "HARD" },
    { zone = "TRANSPORT", level = "MEDIUM", forTypes = { "AH-64D_BLK_II", "Mi-24P" } },
  },
}
