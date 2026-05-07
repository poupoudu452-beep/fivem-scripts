-- shared/weapons.lua
--
-- Définition de toutes les armes GTA5 avec catégories.
-- Chaque catégorie a un raccourci clavier (1-8) pour équiper/déséquiper.
--

WeaponCategories = {
    { id = 'melee',    label = 'Armes Blanches',  icon = 'melee',    key = 1 },
    { id = 'handgun',  label = 'Armes de Poing',  icon = 'handgun',  key = 2 },
    { id = 'smg',      label = 'SMG',             icon = 'smg',      key = 3 },
    { id = 'rifle',    label = 'Fusils',          icon = 'rifle',    key = 4 },
    { id = 'shotgun',  label = 'Fusils à Pompe',  icon = 'shotgun',  key = 5 },
    { id = 'sniper',   label = 'Snipers',         icon = 'sniper',   key = 6 },
    { id = 'heavy',    label = 'Armes Lourdes',   icon = 'heavy',    key = 7 },
    { id = 'thrown',   label = 'Lancers',         icon = 'thrown',   key = 8 },
}

Weapons = {
    -- ═══ ARMES BLANCHES (melee) ═══
    ['WEAPON_KNIFE']          = { label = 'Couteau',           category = 'melee',   hash = `WEAPON_KNIFE` },
    ['WEAPON_NIGHTSTICK']     = { label = 'Matraque',          category = 'melee',   hash = `WEAPON_NIGHTSTICK` },
    ['WEAPON_HAMMER']         = { label = 'Marteau',           category = 'melee',   hash = `WEAPON_HAMMER` },
    ['WEAPON_BAT']            = { label = 'Batte',             category = 'melee',   hash = `WEAPON_BAT` },
    ['WEAPON_GOLFCLUB']       = { label = 'Club de Golf',      category = 'melee',   hash = `WEAPON_GOLFCLUB` },
    ['WEAPON_CROWBAR']        = { label = 'Pied de biche',     category = 'melee',   hash = `WEAPON_CROWBAR` },
    ['WEAPON_BOTTLE']         = { label = 'Bouteille',         category = 'melee',   hash = `WEAPON_BOTTLE` },
    ['WEAPON_DAGGER']         = { label = 'Dague',             category = 'melee',   hash = `WEAPON_DAGGER` },
    ['WEAPON_HATCHET']        = { label = 'Hachette',          category = 'melee',   hash = `WEAPON_HATCHET` },
    ['WEAPON_MACHETE']        = { label = 'Machette',          category = 'melee',   hash = `WEAPON_MACHETE` },
    ['WEAPON_SWITCHBLADE']    = { label = 'Couteau Papillon',  category = 'melee',   hash = `WEAPON_SWITCHBLADE` },
    ['WEAPON_WRENCH']         = { label = 'Clé à molette',     category = 'melee',   hash = `WEAPON_WRENCH` },
    ['WEAPON_BATTLEAXE']      = { label = 'Hache de guerre',   category = 'melee',   hash = `WEAPON_BATTLEAXE` },
    ['WEAPON_POOLCUE']        = { label = 'Queue de billard',  category = 'melee',   hash = `WEAPON_POOLCUE` },
    ['WEAPON_STONE_HATCHET']  = { label = 'Hachette de pierre',category = 'melee',   hash = `WEAPON_STONE_HATCHET` },

    -- ═══ ARMES DE POING (handgun) ═══
    ['WEAPON_PISTOL']         = { label = 'Pistolet',          category = 'handgun', hash = `WEAPON_PISTOL`,         clipSize = 12 },
    ['WEAPON_PISTOL_MK2']     = { label = 'Pistolet Mk2',     category = 'handgun', hash = `WEAPON_PISTOL_MK2`,     clipSize = 12 },
    ['WEAPON_COMBATPISTOL']   = { label = 'Pistolet de combat',category = 'handgun', hash = `WEAPON_COMBATPISTOL`,   clipSize = 12 },
    ['WEAPON_APPISTOL']       = { label = 'Pistolet AP',       category = 'handgun', hash = `WEAPON_APPISTOL`,       clipSize = 18 },
    ['WEAPON_PISTOL50']       = { label = 'Pistolet .50',      category = 'handgun', hash = `WEAPON_PISTOL50`,       clipSize = 9 },
    ['WEAPON_SNSPISTOL']      = { label = 'Pistolet SNS',      category = 'handgun', hash = `WEAPON_SNSPISTOL`,      clipSize = 6 },
    ['WEAPON_SNSPISTOL_MK2']  = { label = 'Pistolet SNS Mk2',  category = 'handgun', hash = `WEAPON_SNSPISTOL_MK2`,  clipSize = 6 },
    ['WEAPON_HEAVYPISTOL']    = { label = 'Pistolet lourd',    category = 'handgun', hash = `WEAPON_HEAVYPISTOL`,    clipSize = 18 },
    ['WEAPON_VINTAGEPISTOL']  = { label = 'Pistolet vintage',  category = 'handgun', hash = `WEAPON_VINTAGEPISTOL`,  clipSize = 7 },
    ['WEAPON_MARKSMANPISTOL'] = { label = 'Pistolet de tireur',category = 'handgun', hash = `WEAPON_MARKSMANPISTOL`, clipSize = 1 },
    ['WEAPON_REVOLVER']       = { label = 'Revolver',          category = 'handgun', hash = `WEAPON_REVOLVER`,       clipSize = 6 },
    ['WEAPON_REVOLVER_MK2']   = { label = 'Revolver Mk2',     category = 'handgun', hash = `WEAPON_REVOLVER_MK2`,   clipSize = 6 },
    ['WEAPON_DOUBLEACTION']   = { label = 'Revolver Double',   category = 'handgun', hash = `WEAPON_DOUBLEACTION`,   clipSize = 6 },
    ['WEAPON_CERAMICPISTOL']  = { label = 'Pistolet Céramique',category = 'handgun', hash = `WEAPON_CERAMICPISTOL`,  clipSize = 12 },
    ['WEAPON_NAVYREVOLVER']   = { label = 'Navy Revolver',     category = 'handgun', hash = `WEAPON_NAVYREVOLVER`,   clipSize = 6 },
    ['WEAPON_GADGETPISTOL']   = { label = 'Pistolet Gadget',   category = 'handgun', hash = `WEAPON_GADGETPISTOL`,   clipSize = 10 },

    -- ═══ SMG ═══
    ['WEAPON_MICROSMG']       = { label = 'Micro SMG',         category = 'smg',     hash = `WEAPON_MICROSMG`,       clipSize = 16 },
    ['WEAPON_SMG']            = { label = 'SMG',               category = 'smg',     hash = `WEAPON_SMG`,            clipSize = 30 },
    ['WEAPON_SMG_MK2']        = { label = 'SMG Mk2',           category = 'smg',     hash = `WEAPON_SMG_MK2`,        clipSize = 30 },
    ['WEAPON_ASSAULTSMG']     = { label = 'SMG d\'assaut',     category = 'smg',     hash = `WEAPON_ASSAULTSMG`,     clipSize = 30 },
    ['WEAPON_COMBATPDW']      = { label = 'PDW de combat',     category = 'smg',     hash = `WEAPON_COMBATPDW`,      clipSize = 30 },
    ['WEAPON_MACHINEPISTOL']  = { label = 'Pistolet mitrailleur', category = 'smg',  hash = `WEAPON_MACHINEPISTOL`,  clipSize = 12 },
    ['WEAPON_MINISMG']        = { label = 'Mini SMG',          category = 'smg',     hash = `WEAPON_MINISMG`,        clipSize = 20 },

    -- ═══ FUSILS D'ASSAUT (rifle) ═══
    ['WEAPON_ASSAULTRIFLE']       = { label = 'Fusil d\'assaut',       category = 'rifle', hash = `WEAPON_ASSAULTRIFLE`,       clipSize = 30 },
    ['WEAPON_ASSAULTRIFLE_MK2']   = { label = 'Fusil d\'assaut Mk2',   category = 'rifle', hash = `WEAPON_ASSAULTRIFLE_MK2`,   clipSize = 30 },
    ['WEAPON_CARBINERIFLE']       = { label = 'Carabine',              category = 'rifle', hash = `WEAPON_CARBINERIFLE`,       clipSize = 30 },
    ['WEAPON_CARBINERIFLE_MK2']   = { label = 'Carabine Mk2',         category = 'rifle', hash = `WEAPON_CARBINERIFLE_MK2`,   clipSize = 30 },
    ['WEAPON_ADVANCEDRIFLE']      = { label = 'Fusil avancé',         category = 'rifle', hash = `WEAPON_ADVANCEDRIFLE`,      clipSize = 30 },
    ['WEAPON_SPECIALCARBINE']     = { label = 'Carabine spéciale',    category = 'rifle', hash = `WEAPON_SPECIALCARBINE`,     clipSize = 30 },
    ['WEAPON_SPECIALCARBINE_MK2'] = { label = 'Carabine spéciale Mk2',category = 'rifle', hash = `WEAPON_SPECIALCARBINE_MK2`, clipSize = 30 },
    ['WEAPON_BULLPUPRIFLE']       = { label = 'Fusil Bullpup',        category = 'rifle', hash = `WEAPON_BULLPUPRIFLE`,       clipSize = 30 },
    ['WEAPON_BULLPUPRIFLE_MK2']   = { label = 'Fusil Bullpup Mk2',   category = 'rifle', hash = `WEAPON_BULLPUPRIFLE_MK2`,   clipSize = 30 },
    ['WEAPON_COMPACTRIFLE']       = { label = 'Fusil compact',        category = 'rifle', hash = `WEAPON_COMPACTRIFLE`,       clipSize = 30 },
    ['WEAPON_MILITARYRIFLE']      = { label = 'Fusil militaire',      category = 'rifle', hash = `WEAPON_MILITARYRIFLE`,      clipSize = 30 },
    ['WEAPON_HEAVYRIFLE']         = { label = 'Fusil lourd',          category = 'rifle', hash = `WEAPON_HEAVYRIFLE`,         clipSize = 30 },
    ['WEAPON_TACTICALRIFLE']      = { label = 'Fusil tactique',       category = 'rifle', hash = `WEAPON_TACTICALRIFLE`,      clipSize = 30 },

    -- ═══ FUSILS À POMPE (shotgun) ═══
    ['WEAPON_PUMPSHOTGUN']       = { label = 'Fusil à pompe',         category = 'shotgun', hash = `WEAPON_PUMPSHOTGUN`,      clipSize = 8 },
    ['WEAPON_PUMPSHOTGUN_MK2']   = { label = 'Fusil à pompe Mk2',    category = 'shotgun', hash = `WEAPON_PUMPSHOTGUN_MK2`,  clipSize = 8 },
    ['WEAPON_SAWNOFFSHOTGUN']    = { label = 'Fusil à canon scié',   category = 'shotgun', hash = `WEAPON_SAWNOFFSHOTGUN`,   clipSize = 8 },
    ['WEAPON_ASSAULTSHOTGUN']    = { label = 'Fusil d\'assaut à pompe', category = 'shotgun', hash = `WEAPON_ASSAULTSHOTGUN`,  clipSize = 8 },
    ['WEAPON_BULLPUPSHOTGUN']    = { label = 'Bullpup Shotgun',      category = 'shotgun', hash = `WEAPON_BULLPUPSHOTGUN`,   clipSize = 14 },
    ['WEAPON_MUSKET']            = { label = 'Mousquet',              category = 'shotgun', hash = `WEAPON_MUSKET`,           clipSize = 1 },
    ['WEAPON_HEAVYSHOTGUN']      = { label = 'Fusil à pompe lourd',  category = 'shotgun', hash = `WEAPON_HEAVYSHOTGUN`,     clipSize = 6 },
    ['WEAPON_DBSHOTGUN']         = { label = 'Double canon',         category = 'shotgun', hash = `WEAPON_DBSHOTGUN`,        clipSize = 2 },
    ['WEAPON_AUTOSHOTGUN']       = { label = 'Fusil auto',           category = 'shotgun', hash = `WEAPON_AUTOSHOTGUN`,      clipSize = 10 },
    ['WEAPON_COMBATSHOTGUN']     = { label = 'Fusil de combat',      category = 'shotgun', hash = `WEAPON_COMBATSHOTGUN`,    clipSize = 8 },

    -- ═══ SNIPERS ═══
    ['WEAPON_SNIPERRIFLE']       = { label = 'Fusil de sniper',      category = 'sniper', hash = `WEAPON_SNIPERRIFLE`,       clipSize = 10 },
    ['WEAPON_HEAVYSNIPER']       = { label = 'Sniper lourd',         category = 'sniper', hash = `WEAPON_HEAVYSNIPER`,       clipSize = 6 },
    ['WEAPON_HEAVYSNIPER_MK2']   = { label = 'Sniper lourd Mk2',    category = 'sniper', hash = `WEAPON_HEAVYSNIPER_MK2`,   clipSize = 6 },
    ['WEAPON_MARKSMANRIFLE']     = { label = 'Fusil de tireur',      category = 'sniper', hash = `WEAPON_MARKSMANRIFLE`,     clipSize = 8 },
    ['WEAPON_MARKSMANRIFLE_MK2'] = { label = 'Fusil de tireur Mk2',  category = 'sniper', hash = `WEAPON_MARKSMANRIFLE_MK2`, clipSize = 8 },
    ['WEAPON_PRECISIONRIFLE']    = { label = 'Fusil de précision',  category = 'sniper', hash = `WEAPON_PRECISIONRIFLE`,    clipSize = 6 },

    -- ═══ ARMES LOURDES (heavy) ═══
    ['WEAPON_RPG']                   = { label = 'Lance-roquettes',     category = 'heavy', hash = `WEAPON_RPG`,              clipSize = 1 },
    ['WEAPON_GRENADELAUNCHER']       = { label = 'Lance-grenades',      category = 'heavy', hash = `WEAPON_GRENADELAUNCHER`,  clipSize = 10 },
    ['WEAPON_MINIGUN']               = { label = 'Minigun',             category = 'heavy', hash = `WEAPON_MINIGUN`,          clipSize = 100 },
    ['WEAPON_FIREWORK']              = { label = 'Lance feu d\'artifice', category = 'heavy', hash = `WEAPON_FIREWORK`,       clipSize = 1 },
    ['WEAPON_RAILGUN']               = { label = 'Railgun',             category = 'heavy', hash = `WEAPON_RAILGUN`,          clipSize = 1 },
    ['WEAPON_HOMINGLAUNCHER']        = { label = 'Lance-missiles',      category = 'heavy', hash = `WEAPON_HOMINGLAUNCHER`,   clipSize = 1 },
    ['WEAPON_COMPACTLAUNCHER']       = { label = 'Lance-grenades compact', category = 'heavy', hash = `WEAPON_COMPACTLAUNCHER`, clipSize = 1 },

    -- ═══ LANCERS (thrown) ═══
    ['WEAPON_GRENADE']        = { label = 'Grenade',            category = 'thrown', hash = `WEAPON_GRENADE` },
    ['WEAPON_BZGAS']          = { label = 'Gaz lacrymogène',   category = 'thrown', hash = `WEAPON_BZGAS` },
    ['WEAPON_SMOKEGRENADE']   = { label = 'Fumigène',          category = 'thrown', hash = `WEAPON_SMOKEGRENADE` },
    ['WEAPON_MOLOTOV']        = { label = 'Cocktail Molotov',  category = 'thrown', hash = `WEAPON_MOLOTOV` },
    ['WEAPON_STICKYBOMB']     = { label = 'Bombe collante',    category = 'thrown', hash = `WEAPON_STICKYBOMB` },
    ['WEAPON_PROXMINE']       = { label = 'Mine de proximité', category = 'thrown', hash = `WEAPON_PROXMINE` },
    ['WEAPON_PIPEBOMB']       = { label = 'Bombe artisanale',  category = 'thrown', hash = `WEAPON_PIPEBOMB` },
    ['WEAPON_FLARE']          = { label = 'Fusée éclairante', category = 'thrown', hash = `WEAPON_FLARE` },
}

-- ═══════════════════════════════════════════════════════════════════════════════
--  Auto-génération des armes comme ITEMS d'inventaire
--  Chaque arme devient un item draggable dans l'inventaire.
--  amount = munitions (ou 1 pour les armes blanches)
-- ═══════════════════════════════════════════════════════════════════════════════

for weaponKey, weaponDef in pairs(Weapons) do
    local itemKey = string.lower(weaponKey)
    if not Items[itemKey] then
        Items[itemKey] = {
            name           = itemKey,
            label          = weaponDef.label,
            description    = weaponDef.label,
            weight         = 2.0,
            stackable      = true,
            maxStack       = 9999,
            icon           = 'img/weapons/' .. itemKey .. '.png',
            usable         = false,
            isWeapon       = true,
            weaponName     = weaponKey,
            weaponCategory = weaponDef.category,
        }
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  Auto-génération des BOÎTES DE MUNITIONS pour chaque arme (sauf melee/thrown)
--  Chaque arme à feu a son propre item de munitions.
--  Utilisable uniquement si l'arme correspondante est équipée dans les mains.
-- ═══════════════════════════════════════════════════════════════════════════════

local AMMO_CATEGORIES = { handgun = true, smg = true, rifle = true, shotgun = true, sniper = true, heavy = true }

for weaponKey, weaponDef in pairs(Weapons) do
    if AMMO_CATEGORIES[weaponDef.category] then
        local ammoKey = 'ammo_' .. string.lower(weaponKey)
        if not Items[ammoKey] then
            -- Priorité : override per-weapon > demi-chargeur (clipSize/2) > config par catégorie > défaut
            local ammoAmount = (Config.AmmoPerWeapon and Config.AmmoPerWeapon[weaponKey])
                or (weaponDef.clipSize and math.max(math.floor(weaponDef.clipSize / 2), 1))
                or (Config.AmmoPerBox and Config.AmmoPerBox[weaponDef.category])
                or (Config.AmmoPerBox and Config.AmmoPerBox.default)
                or 30
            Items[ammoKey] = {
                name           = ammoKey,
                label          = 'Munitions ' .. weaponDef.label,
                description    = 'Boîte de munitions pour ' .. weaponDef.label .. ' (x' .. ammoAmount .. ')',
                weight         = 0.5,
                stackable      = true,
                maxStack       = 20,
                icon           = '🔫',
                usable         = true,
                isAmmo         = true,
                ammoForWeapon  = weaponKey,
                ammoCategory   = weaponDef.category,
                ammoAmount     = ammoAmount,
            }
        end
    end
end

-- Modèles d'objets pour affichage dans le dos
-- Toutes les armes sauf armes blanches et armes de poing
WeaponBackModels = {
    -- Heavy
    ['WEAPON_RPG']               = 'w_lr_rpg',
    ['WEAPON_GRENADELAUNCHER']   = 'w_lr_grenadelauncher',
    ['WEAPON_MINIGUN']           = 'w_mg_minigun',
    ['WEAPON_HOMINGLAUNCHER']    = 'w_lr_homing',
    ['WEAPON_FIREWORK']          = 'w_lr_firework',
    ['WEAPON_RAILGUN']           = 'w_ar_railgun',
    ['WEAPON_COMPACTLAUNCHER']   = 'w_lr_compactgl',
    -- Snipers
    ['WEAPON_SNIPERRIFLE']       = 'w_sr_sniperrifle',
    ['WEAPON_HEAVYSNIPER']       = 'w_sr_heavysniper',
    ['WEAPON_HEAVYSNIPER_MK2']   = 'w_sr_heavysnipermk2',
    ['WEAPON_MARKSMANRIFLE']     = 'w_sr_marksmanrifle',
    ['WEAPON_MARKSMANRIFLE_MK2'] = 'w_sr_marksmanriflemk2',
    ['WEAPON_PRECISIONRIFLE']    = 'w_sr_precisionrifle',
    -- Rifles
    ['WEAPON_ASSAULTRIFLE']      = 'w_ar_assaultrifle',
    ['WEAPON_ASSAULTRIFLE_MK2']  = 'w_ar_assaultriflemk2',
    ['WEAPON_CARBINERIFLE']      = 'w_ar_carbinerifle',
    ['WEAPON_CARBINERIFLE_MK2']  = 'w_ar_carbineriflemk2',
    ['WEAPON_ADVANCEDRIFLE']     = 'w_ar_advancedrifle',
    ['WEAPON_SPECIALCARBINE']    = 'w_ar_specialcarbine',
    ['WEAPON_SPECIALCARBINE_MK2']= 'w_ar_specialcarbinemk2',
    ['WEAPON_BULLPUPRIFLE']      = 'w_ar_bullpuprifle',
    ['WEAPON_BULLPUPRIFLE_MK2']  = 'w_ar_bullpupriflemk2',
    ['WEAPON_COMPACTRIFLE']      = 'w_ar_assaultrifle',  -- même modèle compact
    ['WEAPON_MILITARYRIFLE']     = 'w_ar_bullpuprifleh4',
    ['WEAPON_HEAVYRIFLE']        = 'w_ar_heavyrifleh',
    ['WEAPON_TACTICALRIFLE']     = 'w_ar_carbinerifle',
    -- Shotguns
    ['WEAPON_PUMPSHOTGUN']       = 'w_sg_pumpshotgun',
    ['WEAPON_PUMPSHOTGUN_MK2']   = 'w_sg_pumpshotgunmk2',
    ['WEAPON_ASSAULTSHOTGUN']    = 'w_sg_assaultshotgun',
    ['WEAPON_BULLPUPSHOTGUN']    = 'w_sg_bullpupshotgun',
    ['WEAPON_HEAVYSHOTGUN']      = 'w_sg_heavyshotgun',
    ['WEAPON_DBSHOTGUN']         = 'w_sg_doublebarrel',
    ['WEAPON_AUTOSHOTGUN']       = 'w_sg_sweeper',
    ['WEAPON_MUSKET']            = 'w_ar_musket',
    ['WEAPON_SAWNOFFSHOTGUN']    = 'w_sg_sawnoff',
    ['WEAPON_COMBATSHOTGUN']     = 'w_sg_pumpshotgunh4',
    -- SMGs
    ['WEAPON_MICROSMG']          = 'w_sb_microsmg',
    ['WEAPON_SMG']               = 'w_sb_smg',
    ['WEAPON_SMG_MK2']           = 'w_sb_smgmk2',
    ['WEAPON_ASSAULTSMG']        = 'w_sb_assaultsmg',
    ['WEAPON_COMBATPDW']         = 'w_sb_pdw',
    ['WEAPON_MACHINEPISTOL']     = 'w_sb_compactsmg',
    ['WEAPON_MINISMG']           = 'w_sb_minismg',
    ['WEAPON_MG']                = 'w_mg_mg',
    ['WEAPON_COMBATMG']          = 'w_mg_combatmg',
    ['WEAPON_COMBATMG_MK2']      = 'w_mg_combatmgmk2',
    ['WEAPON_GUSENBERG']         = 'w_sb_gusenberg',
    -- Thrown
    ['WEAPON_GRENADE']           = 'w_ex_grenadefrag',
    ['WEAPON_MOLOTOV']           = 'w_ex_molotov',
    ['WEAPON_STICKYBOMB']        = 'w_ex_pe',
    ['WEAPON_PROXMINE']          = 'w_ex_proxmine',
    ['WEAPON_PIPEBOMB']          = 'w_ex_pipebomb',
    ['WEAPON_BZGAS']             = 'w_ex_teargas',
    ['WEAPON_SMOKEGRENADE']      = 'w_ex_smokegrenade',
    ['WEAPON_FLARE']             = 'w_am_flare',
}
