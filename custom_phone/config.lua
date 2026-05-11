-- ==================== CONFIGURATION SERVICES ====================
-- Ajoute ou supprime des jobs ici. Chaque job aura automatiquement :
--   - Un bouton "Appeler" (tous les joueurs du job recoivent l'appel)
--   - Un bouton "Message" (chat partage entre tous les membres du job)
--
-- Format :
--   { job = 'NomDuJob',  label = 'Nom Affiche',  color = '#couleur' }
--
-- "job"   = le nom exact du job dans la colonne job1/job2 de la table characters
--           (la comparaison est insensible a la casse : Police = police = POLICE)
-- "label" = le nom affiche dans le telephone
-- "color" = couleur du logo (hex), optionnel (defaut: #5856d6)
--
-- Exemples :
--   { job = 'Police',   label = 'Police',         color = '#1a73e8' },
--   { job = 'SAMU',     label = 'SAMU',            color = '#e53935' },
--   { job = 'Mechano',  label = 'Garage Central',  color = '#43a047' },
-- ================================================================

Config = {}

Config.Services = {
    { job = 'Police',   label = 'Police',   color = '#1a73e8' },
}
