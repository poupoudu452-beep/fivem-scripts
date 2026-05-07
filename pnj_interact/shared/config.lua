Config = {}

-- Touche pour activer le troisième œil (ALT = 19)
Config.ActivateKey = 19

-- Distance max de détection des PNJ
Config.MaxDistance = 5.0

-- Prénoms masculins
Config.MaleFirstNames = {
    "Jean", "Pierre", "Lucas", "Hugo", "Nathan",
    "Thomas", "Alexandre", "Antoine", "Nicolas", "Maxime",
    "Louis", "Gabriel", "Raphaël", "Arthur", "Jules",
    "Paul", "Victor", "Théo", "Adam", "Samuel",
}

-- Prénoms féminins
Config.FemaleFirstNames = {
    "Marie", "Sophie", "Emma", "Chloé", "Léa",
    "Julie", "Camille", "Manon", "Sarah", "Clara",
    "Louise", "Alice", "Jade", "Lina", "Charlotte",
    "Juliette", "Inès", "Anna", "Eva", "Noémie",
}

-- Noms de famille (communs)
Config.LastNames = {
    "Dupont", "Laurent", "Martin", "Bernard", "Moreau",
    "Petit", "Leroy", "Roux", "Fournier", "Girard",
    "Mercier", "Bonnet", "Blanc", "Guérin", "Faure",
    "Rousseau", "Clément", "Lambert", "Fontaine", "Chevalier",
    "Durand", "Lefebvre", "Garcia", "Morel", "Simon",
    "Michel", "Lefèvre", "André", "David", "Bertrand",
}

-- Phrases de dialogue par défaut (le PNJ dit)
Config.DefaultDialogues = {
    "Bonjour ! Belle journée, n'est-ce pas ?",
    "Salut ! Tu as besoin de quelque chose ?",
    "Hey ! Fais attention où tu marches...",
    "Qu'est-ce que tu veux ? Je suis occupé.",
    "Ah, encore toi... Qu'est-ce qu'il y a ?",
    "Bienvenue ! Je peux t'aider ?",
    "Hmm ? Tu me parles à moi ?",
    "Passe une bonne journée !",
    "Tu n'as pas l'air d'ici, toi...",
    "Je n'ai pas le temps pour ça.",
    "Oh, salut ! Ça faisait longtemps !",
    "Fais gaffe, le quartier n'est pas sûr.",
}

-- Options de réponse par défaut (le ligoter est généré dynamiquement avec le nom du PNJ)
Config.DefaultResponses = {
    { label = "Salut, comment ça va ?",  icon = "chat" },
    { label = "Au revoir",               icon = "wave" },
}
