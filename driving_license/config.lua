-- ============================================================
--  PERMIS DE CONDUIRE — CONFIG
--  PNJ auto-école + quiz code de la route + épreuve pratique
--  Interaction via pnj_interact (ALT / troisième oeil)
-- ============================================================

DrivingConfig = {}

-- ─── PNJ Auto-école ──────────────────────────────────────────────────────────
DrivingConfig.Ped = {
    model   = 'a_f_y_business_01',
    coords  = vector3(240.83, -1379.07, 32.7),
    heading = 160.0,
    name    = 'Auto-Ecole',
    tag     = 'Moniteur Auto-École',
}

-- ─── Dialogues ──────────────────────────────────────────────────────────────
DrivingConfig.DialogueCode     = "Bonjour ! Je suis le moniteur de l'auto-école. Souhaitez-vous passer votre examen du code de la route ? Il comporte 10 questions. Il faut au moins 7 bonnes réponses pour réussir."
DrivingConfig.DialoguePratique = "Bravo pour le code ! Vous pouvez maintenant passer l'épreuve pratique. Vous conduirez un véhicule et devrez respecter les limitations de vitesse sur le parcours. Attention : 5 infractions et c'est l'échec !"
DrivingConfig.DialogueAlready  = "Vous possédez déjà votre permis de conduire. Bonne route !"

-- ─── Paramètres du quiz (code) ──────────────────────────────────────────────
DrivingConfig.RequiredScore    = 7
DrivingConfig.QuestionsPerExam = 10
DrivingConfig.ExamCooldown     = 60  -- secondes entre deux tentatives

-- ─── Paramètres de l'épreuve pratique ───────────────────────────────────────
DrivingConfig.PracticalMaxErrors = 5

-- Véhicule de l'épreuve pratique
DrivingConfig.Vehicle = {
    model   = 'blista',
    spawn   = vector4(219.45, -1384.71, 30.57, 160.0),
}

-- ─── Apparence des markers au sol ───────────────────────────────────────────
DrivingConfig.Marker = {
    type       = 1,                          -- cylindre
    scale      = vector3(4.0, 4.0, 1.5),     -- taille du marker
    colorNext  = {r=66,  g=135, b=245, a=120}, -- bleu — checkpoint actif
    colorAhead = {r=255, g=255, b=255, a=40},  -- blanc discret — prochain
    bobUpDown  = false,
    rotate     = false,
    drawDist   = 80.0,                        -- distance d'affichage
}

-- Points de passage de l'épreuve pratique
DrivingConfig.PracticalCheckpoints = {
    { coords = vector3(-218.75, -1027.67, 29.29), maxSpeed = 50,  radius = 8.0 },
    { coords = vector3(-179.07, -1063.38, 27.78), maxSpeed = 50,  radius = 8.0 },
    { coords = vector3(-134.80, -1098.20, 26.03), maxSpeed = 60,  radius = 8.0 },
    { coords = vector3(-69.50,  -1122.88, 26.54), maxSpeed = 60,  radius = 8.0 },
    { coords = vector3(11.53,   -1102.43, 29.79), maxSpeed = 50,  radius = 8.0 },
    { coords = vector3(38.97,   -1049.13, 29.36), maxSpeed = 50,  radius = 8.0 },
    { coords = vector3(-7.31,   -1024.81, 28.97), maxSpeed = 40,  radius = 8.0 },
    { coords = vector3(-89.60,  -974.71,  29.42), maxSpeed = 50,  radius = 8.0 },
    { coords = vector3(-156.13, -959.52,  29.27), maxSpeed = 50,  radius = 8.0 },
    { coords = vector3(-227.85, -985.10,  29.29), maxSpeed = 30,  radius = 10.0 },
}

-- ─── Questions du code de la route ───────────────────────────────────────────
DrivingConfig.Questions = {
    {
        question = "Que signifie un feu rouge ?",
        choices  = { "Accélérer", "S'arrêter", "Ralentir", "Faire demi-tour" },
        answer   = 2,
    },
    {
        question = "Quelle est la vitesse maximale en agglomération ?",
        choices  = { "30 km/h", "50 km/h", "70 km/h", "90 km/h" },
        answer   = 2,
    },
    {
        question = "Que signifie un panneau triangulaire bordé de rouge ?",
        choices  = { "Interdiction", "Danger", "Obligation", "Indication" },
        answer   = 2,
    },
    {
        question = "Qui est prioritaire sur un rond-point ?",
        choices  = { "Celui qui entre", "Celui qui est déjà engagé", "Le plus rapide", "Personne" },
        answer   = 2,
    },
    {
        question = "Que devez-vous faire à un passage piéton ?",
        choices  = { "Klaxonner", "Accélérer", "Laisser passer les piétons", "Rouler au pas" },
        answer   = 3,
    },
    {
        question = "Que signifie un feu orange fixe ?",
        choices  = { "Foncez vite", "Arrêtez-vous si possible", "Priorité à droite", "Cédez le passage" },
        answer   = 2,
    },
    {
        question = "Quelle est la distance de sécurité recommandée sur autoroute ?",
        choices  = { "1 seconde", "2 secondes", "5 secondes", "10 secondes" },
        answer   = 2,
    },
    {
        question = "Dans quel cas pouvez-vous dépasser par la droite ?",
        choices  = { "Jamais", "Quand le véhicule devant tourne à gauche", "Quand on est pressé", "Sur autoroute" },
        answer   = 2,
    },
    {
        question = "Que signifie un panneau rond à fond bleu ?",
        choices  = { "Interdiction", "Danger", "Obligation", "Information" },
        answer   = 3,
    },
    {
        question = "Quand doit-on allumer ses feux de croisement ?",
        choices  = { "Uniquement la nuit", "La nuit et par mauvaise visibilité", "Uniquement sous la pluie", "Jamais en ville" },
        answer   = 2,
    },
    {
        question = "Que faire en cas de panne sur autoroute ?",
        choices  = { "Rester dans le véhicule", "Se ranger sur la bande d'arrêt d'urgence et sortir", "Faire demi-tour", "Appeler un ami" },
        answer   = 2,
    },
    {
        question = "Quel est le taux d'alcoolémie maximal autorisé pour un conducteur ?",
        choices  = { "0.2 g/L", "0.5 g/L", "0.8 g/L", "1.0 g/L" },
        answer   = 2,
    },
    {
        question = "Que signifie une ligne blanche continue au sol ?",
        choices  = { "Dépassement autorisé", "Interdiction de dépasser", "Zone de stationnement", "Voie réservée" },
        answer   = 2,
    },
    {
        question = "À quelle distance devez-vous vous arrêter d'un passage à niveau ?",
        choices  = { "1 mètre", "5 mètres", "Au niveau du panneau STOP ou de la barrière", "10 mètres" },
        answer   = 3,
    },
    {
        question = "Quel document devez-vous toujours avoir dans votre véhicule ?",
        choices  = { "Le carnet de santé", "La carte grise du véhicule", "Un GPS", "Une carte routière" },
        answer   = 2,
    },
    -- Questions supplémentaires
    {
        question = "Que devez-vous faire avant de changer de direction ?",
        choices  = { "Klaxonner", "Mettre le clignotant", "Accélérer", "Freiner brusquement" },
        answer   = 2,
    },
    {
        question = "En cas de verglas, que devez-vous faire ?",
        choices  = { "Freiner fort", "Accélérer pour passer vite", "Réduire la vitesse et éviter les gestes brusques", "Rouler normalement" },
        answer   = 3,
    },
    {
        question = "Que signifie un panneau carré à fond bleu avec une flèche blanche ?",
        choices  = { "Sens interdit", "Direction obligatoire", "Impasse", "Zone piétonne" },
        answer   = 2,
    },
    {
        question = "À quelle vitesse maximale peut-on rouler sur autoroute par temps de pluie ?",
        choices  = { "130 km/h", "110 km/h", "90 km/h", "70 km/h" },
        answer   = 2,
    },
    {
        question = "Que signifie un panneau rond rouge barré ?",
        choices  = { "Fin d'interdiction", "Interdiction", "Obligation", "Danger" },
        answer   = 1,
    },
}
