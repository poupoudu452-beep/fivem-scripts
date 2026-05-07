-- ============================================================
--  POLICE JOB — SHARED CONFIG
-- ============================================================

PoliceConfig = {}

-- ─── Nom du job dans la BDD ─────────────────────────────────
PoliceConfig.JobName = 'Police'

-- ─── Grades par défaut (level = hierarchie, plus haut = plus de pouvoir) ──
PoliceConfig.DefaultGrades = {
    { name = 'Recrue',      level = 1, salary = 200 },
    { name = 'Agent',       level = 2, salary = 300 },
    { name = 'Brigadier',   level = 3, salary = 400 },
    { name = 'Lieutenant',  level = 4, salary = 550 },
    { name = 'Capitaine',   level = 5, salary = 700 },
    { name = 'Commandant',  level = 6, salary = 1000 },
}

-- ─── Grade du commandant (le plus haut, peut tout faire) ────
PoliceConfig.CommanderGrade = 'Commandant'

-- ─── Salaire ────────────────────────────────────────────────
PoliceConfig.SalaryInterval = 30 -- minutes entre chaque salaire

-- ─── PNJ Police (commissariat Mission Row) ──────────────────
PoliceConfig.StationNPC = {
    model  = 's_m_y_cop_01',
    coords = vector4(441.89, -982.06, 30.69, 178.54),
    name   = 'Officier d\'accueil',
}

-- ─── Blip commissariat ─────────────────────────────────────
PoliceConfig.StationBlip = {
    coords = vector3(441.89, -982.06, 30.69),
    sprite = 60,
    color  = 29,
    scale  = 0.9,
    label  = 'Commissariat de Police',
}

-- ─── Fouille : distance max pour fouiller un joueur ─────────
PoliceConfig.FriskDistance = 3.0

-- ─── Menottage ──────────────────────────────────────────────
PoliceConfig.HandcuffDistance = 2.5

-- ─── Prison ─────────────────────────────────────────────────
PoliceConfig.JailCoords = vector3(1691.55, 2565.70, 45.56)
PoliceConfig.JailRadius = 80.0
PoliceConfig.MaxJailMinutes = 60

-- ─── Fourrière ──────────────────────────────────────────────
PoliceConfig.ImpoundCoords = vector3(409.09, -1623.23, 29.29)
PoliceConfig.ImpoundDistance = 5.0

-- ─── Herses (spike strips) ──────────────────────────────────
PoliceConfig.SpikeModel = 'p_ld_stinger_s'

-- ─── Amendes ────────────────────────────────────────────────
PoliceConfig.MaxFineAmount = 50000
PoliceConfig.FineDistance = 5.0

-- ─── Radar de vitesse ───────────────────────────────────────
PoliceConfig.SpeedRadarDistance = 50.0
PoliceConfig.SpeedLimit = 120 -- km/h

-- ─── Touches ────────────────────────────────────────────────
PoliceConfig.OpenMenuKey = 0x4CC0E2FE -- F7
PoliceConfig.DutyKey     = 0xCEFD9220 -- F6

-- ─── Couleurs du HUD ────────────────────────────────────────
PoliceConfig.Colors = {
    primary   = '#2563eb', -- bleu police
    secondary = '#1e40af',
    accent    = '#ef4444', -- rouge urgence
    success   = '#22c55e',
    warning   = '#f59e0b',
    dark      = '#0f172a',
    darker    = '#020617',
    text      = '#f8fafc',
    textDim   = '#94a3b8',
}
