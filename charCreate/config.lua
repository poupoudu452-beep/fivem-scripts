-- ============================================================
--  CHARACTER CREATION — CONFIG
-- ============================================================

Config = {}

-- ─── Items donnés au joueur lors de sa première création ────
Config.StarterItems = {
    { item = 'bread',         amount = 5  },
    { item = 'water_bottle',  amount = 5  },
    -- { item = 'phone',      amount = 1  },
    -- { item = 'id_card',    amount = 1  },
}
Config.GiveStarterItems = true

-- ─── Jobs par défaut ────────────────────────────────────────
Config.DefaultJob1 = 'Chomage'
Config.DefaultJob2 = 'Chomage'

-- ─── Salaire chômage ────────────────────────────────────────
Config.UnemploymentPay      = 100       -- montant versé en $
Config.UnemploymentInterval = 30        -- intervalle en minutes
Config.UnemploymentJobName  = 'Chomage' -- nom du job qui déclenche le versement
Config.UnemploymentMessage  = 'Gouvernement : %d$ verse pour votre chomage'

-- ─── Argent de départ en banque ─────────────────────────────
Config.StarterBank = 0
