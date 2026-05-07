-- shared/config.lua
Config = {}

Config.MaxSlots       = 30   -- nombre de slots dans l'inventaire
Config.MaxWeight      = 30   -- poids max en kg
Config.OpenKey        = 0x23  -- TAB (hash FiveM)

-- ═══════════════════════════════════════════════════════════════════════════════
--  MUNITIONS : quantité de munitions par boîte
--  Configurable par catégorie d'arme ou par arme spécifique.
-- ═══════════════════════════════════════════════════════════════════════════════

-- Munitions par défaut selon la catégorie
Config.AmmoPerBox = {
    default  = 30,
    handgun  = 24,
    smg      = 30,
    rifle    = 30,
    shotgun  = 12,
    sniper   = 10,
    heavy    = 5,
}

-- Override par arme spécifique (optionnel, prioritaire sur la catégorie)
-- Exemple : Config.AmmoPerWeapon['WEAPON_MINIGUN'] = 100
Config.AmmoPerWeapon = {
    -- ['WEAPON_MINIGUN'] = 100,
    -- ['WEAPON_RPG']     = 3,
}

-- ═══════════════════════════════════════════════════════════════════════════════
--  COFFRE DE VÉHICULE & BOÎTE À GANTS
-- ═══════════════════════════════════════════════════════════════════════════════

Config.TrunkSlots       = 20     -- nombre de slots dans le coffre
Config.TrunkMaxWeight   = 50     -- poids max du coffre (kg)
Config.TrunkDistance     = 2.5   -- distance max pour accéder au coffre (arrière du véhicule)

Config.GloveboxSlots    = 5      -- nombre de slots dans la boîte à gants
Config.GloveboxMaxWeight = 5     -- poids max de la boîte à gants (kg)
