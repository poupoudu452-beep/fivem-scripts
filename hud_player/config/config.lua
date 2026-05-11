-- ═══════════════════════════════════════════════════════════════
--  hud_player — Configuration
-- ═══════════════════════════════════════════════════════════════

Config = {}

-- ── Intervalles de mise à jour (en ms) ──────────────────────
Config.TickInterval      = 500    -- tick principal (stats)
Config.VehicleTickInterval = 100  -- tick véhicule (vitesse / carburant)

-- ── Faim & Soif ─────────────────────────────────────────────
-- Diminution par intervalle (Config.TickInterval)
Config.HungerDecay  = 0.05   -- perte de faim par tick
Config.ThirstDecay  = 0.08   -- perte de soif par tick (plus rapide)

-- Valeurs de départ
Config.StartHunger  = 100.0
Config.StartThirst  = 100.0

-- Seuils de dégâts (dommages si en dessous ou égal)
-- 0.0 = dégâts uniquement quand la barre atteint zéro
Config.HungerDamageThreshold  = 0.0
Config.ThirstDamageThreshold  = 0.0
Config.HungerDamageAmount     = 1.0   -- dégâts HP par tick quand faim = 0
Config.ThirstDamageAmount     = 2.0   -- dégâts HP par tick quand soif = 0

-- ── Restauration par item ─────────────────────────────────
Config.WaterRestoreAmount = 25.0   -- soif restaurée par water_bottle
Config.BreadRestoreAmount = 25.0   -- faim restaurée par bread

-- ── Endurance ───────────────────────────────────────────────
Config.StaminaRegenRate  = 1.5   -- régénération par tick (au repos)
Config.StaminaSprintDrain= 2.0   -- drain par tick en sprint

-- ── HP ──────────────────────────────────────────────────────
-- GTA encode la vie entre 100 (vide) et 200 (plein)
-- On ramène ça sur 0-100 pour l'affichage
Config.MaxHealth     = 200
Config.MinHealth     = 100   -- en dessous = mort

-- ── HUD ─────────────────────────────────────────────────────
Config.ShowHUD       = true   -- afficher le HUD au démarrage
Config.HideInCutscene= true   -- cacher pendant les cutscenes

-- ── Debug ───────────────────────────────────────────────────
Config.Debug         = false
