-- ============================================================
--  VEHICLE LOCKPICK — CONFIG
-- ============================================================

Config = {}

-- Distance d'interaction pour voir le prompt "E"
Config.InteractDist = 3.0

-- Nombre de goupilles a lever correctement
Config.PinCount = 7

-- Duree de l'alarme si le crochetage echoue (ms)
Config.AlarmDuration = 8000

-- Nombre max de tentatives avant que le vehicule declenche l'alarme
Config.MaxAttempts = 3

-- Delai avant de pouvoir re-essayer apres un echec (ms)
Config.RetryCooldown = 5000

-- Verrouiller aussi les vehicules des joueurs ? (false = seulement PNJ)
Config.LockPlayerVehicles = false

-- Distance max pour detecter les vehicules a verrouiller
Config.LockRadius = 80.0

-- Types de vehicules a ignorer (ne pas verrouiller)
-- Voir : https://docs.fivem.net/natives/?_0x29439776AAA00A62
Config.IgnoredVehicleClasses = {
    13, -- Cycles (velos)
    14, -- Bateaux
    15, -- Helicopteres
    16, -- Avions
    21, -- Trains
}

-- Afficher une notification quand le joueur essaie d'ouvrir un vehicule verrouille
Config.ShowLockedNotif = true

-- ─── ITEM REQUIS ────────────────────────────────────────────────────────
-- Nom de l'item dans l'inventaire (shared/items.lua de inv_system)
-- L'item sera consomme a chaque tentative de crochetage
Config.RequireLockpickItem = true
Config.LockpickItemName = 'lockpick'

-- ─── HOTWIRE (cablage) ──────────────────────────────────────────────────
-- Nombre de fils a connecter
Config.HotwireWireCount = 4

-- Duree de l'animation de branchement apres le mini-jeu (ms)
Config.HotwireDuration = 5000
