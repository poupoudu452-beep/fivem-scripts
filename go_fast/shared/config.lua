Config = {}

-- Modèle du PNJ dealer (gangster)
Config.DealerModel = 'g_m_y_ballaorig_01'

-- Distance max pour supprimer un dealer avec /removedealer
Config.RemoveDistance = 5.0

-- Fichier de sauvegarde des dealers (côté serveur)
Config.SaveFile = 'dealers.json'

-- ═══════════════════════════════════════════
--  MISSION GO FAST
-- ═══════════════════════════════════════════

-- Modèle de la voiture pour la mission
Config.MissionVehicle = 'SENTINEL5S'

-- Distance de spawn de la voiture par rapport au dealer (en mètres)
Config.VehicleSpawnDistance = 8.0

-- ═══════════════════════════════════════════
--  PNJ CONDUCTEUR (amène la voiture au joueur)
-- ═══════════════════════════════════════════

-- Modèle du PNJ conducteur
Config.DriverModel = 'a_m_y_mexthug_01'

-- Point où le conducteur amène la voiture (configurable)
-- Le PNJ conduira la voiture du spawn jusqu'à ce point, puis descendra et s'enfuira en courant
Config.DriverDestination = { x = 391.14, y = 779.97, z = 186.25, heading = 123.12 }

-- Vitesse de conduite du PNJ (en m/s, ~60 km/h = 16.67, ~80 km/h = 22.22)
Config.DriverSpeed = 20.0

-- Style de conduite du PNJ (786603 = normal, respecte le code de la route)
-- Voir https://docs.fivem.net/natives/?_0x31F0B376
Config.DriverDrivingStyle = 786603

-- Distance (en mètres) à laquelle le PNJ est considéré comme arrivé au point
Config.DriverArrivalDistance = 5.0

-- Points de livraison possibles (un sera choisi aléatoirement)
Config.DeliveryLocations = {
    { x = 457.04, y = -1550.06, z = 29.28, label = "Livraison" },
}

-- PNJ receveur au point de livraison (homme d'affaires)
Config.ReceiverModel = 'a_m_y_business_02'
Config.ReceiverCoords = { x = 460.71, y = -1541.95, z = 29.28, heading = 195.40 }

-- Timer de la mission (en secondes) : 15 minutes
Config.MissionTimer = 15 * 60

-- Cooldown entre deux go fast par joueur (en secondes) : 45 minutes
Config.MissionCooldown = 45 * 60

-- ═══════════════════════════════════════════
--  SYSTÈME DE CONFIANCE (homme d'affaires)
-- ═══════════════════════════════════════════

-- Gain de confiance par livraison réussie (en %)
Config.TrustGainSuccess = 5

-- Perte de confiance par échec (en %)
Config.TrustLossFail = 10

-- Seuil (en %) à partir duquel le nom du PNJ est révélé
Config.TrustRevealThreshold = 30

-- Nom révélé du receveur (homme d'affaires)
Config.ReceiverRealName = "Tayler Mclain"

-- Nom révélé du dealer (gangster) après premier paiement
Config.DealerRealName = "Ghost"

-- ═══════════════════════════════════════════
--  RÉCOMPENSE DE LIVRAISON
-- ═══════════════════════════════════════════

-- Montant de base donné par l'homme d'affaires après une livraison réussie
Config.DeliveryBaseReward = 7000

-- Bonus en % par palier de 10% de confiance (ex: 8 = +8% par palier)
Config.DeliveryTrustBonusPercent = 8

-- ═══════════════════════════════════════════
--  DROGUE DANS LE COFFRE (voiture gangster)
-- ═══════════════════════════════════════════

-- Types de drogue possibles (un sera choisi aléatoirement à chaque mission)
Config.DrugTypes = { 'cocaine_brick', 'weed_brick', 'ecstasy_bag' }

-- Quantité de kg par palier de confiance (index = palier)
-- palier 0 = 0-9% confiance, palier 1 = 10-19%, palier 2 = 20-29%, etc.
Config.DrugAmountPerTier = {
    [0]  = 3,   -- 0-9%   : 3 kg
    [1]  = 5,   -- 10-19% : 5 kg
    [2]  = 8,   -- 20-29% : 8 kg
    [3]  = 12,  -- 30-39% : 12 kg
    [4]  = 16,  -- 40-49% : 16 kg
    [5]  = 20,  -- 50-59% : 20 kg
    [6]  = 25,  -- 60-69% : 25 kg
    [7]  = 30,  -- 70-79% : 30 kg
    [8]  = 36,  -- 80-89% : 36 kg
    [9]  = 42,  -- 90-99% : 42 kg
    [10] = 50,  -- 100%   : 50 kg
}
