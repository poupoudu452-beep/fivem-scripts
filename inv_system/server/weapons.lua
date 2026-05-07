-- server/weapons.lua
--
-- Gestion des armes côté serveur :
--   • Stockage en mémoire + persistance BDD
--   • Synchronisation client
--   • Exports pour autres ressources (commande, etc.)
--
-- STANDALONE : ne dépend ni d'ESX ni de QBCore.
-- La commande /giveweapon est dans la ressource "commande".
--

local PlayerWeapons = {}   -- [src] = { [category] = { weapon = 'WEAPON_...', ammo = n } }

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function GetIdentifierWeapons(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

local function SerializeWeapons(weapons)
    local out = {}
    for cat, data in pairs(weapons or {}) do
        out[cat] = data
    end
    return out
end

-- ─── Déconnexion : sauvegarder les armes ──────────────────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    local identifier = GetIdentifierWeapons(src)
    if identifier and PlayerWeapons[src] then
        DB_SaveWeapons(identifier, PlayerWeapons[src])
    end
    PlayerWeapons[src] = nil
end)

-- ─── Envoi des armes au client (lazy-load depuis la BDD si besoin) ────────────
RegisterNetEvent('weapons:request', function()
    local src = source
    local identifier = GetIdentifierWeapons(src)

    if PlayerWeapons[src] then
        TriggerClientEvent('weapons:receive', src, SerializeWeapons(PlayerWeapons[src]))
    elseif identifier then
        DB_LoadWeapons(identifier, function(weapons)
            PlayerWeapons[src] = weapons or {}
            TriggerClientEvent('weapons:receive', src, SerializeWeapons(PlayerWeapons[src]))
        end)
    else
        PlayerWeapons[src] = {}
        TriggerClientEvent('weapons:receive', src, {})
    end
end)

-- ─── Fonction interne : donner une arme ───────────────────────────────────────
function GiveWeaponToPlayer(src, target, weaponName, ammo)
    local weaponDef = Weapons[weaponName]
    if not weaponDef then
        return false, 'Arme inconnue: ' .. tostring(weaponName)
    end

    local targetPed = GetPlayerPed(target)
    if not targetPed or targetPed == 0 then
        return false, 'Joueur ID ' .. target .. ' introuvable.'
    end

    if not PlayerWeapons[target] then
        PlayerWeapons[target] = {}
    end

    local category = weaponDef.category
    PlayerWeapons[target][category] = {
        weapon = weaponName,
        ammo   = ammo,
    }

    local identifier = GetIdentifierWeapons(target)
    if identifier then
        DB_SaveWeapons(identifier, PlayerWeapons[target])
    end

    TriggerClientEvent('weapons:receive', target, SerializeWeapons(PlayerWeapons[target]))
    TriggerClientEvent('weapons:weaponGiven', target, weaponName, ammo)

    return true, weaponDef.label or weaponName
end

-- ─── Retirer une arme ─────────────────────────────────────────────────────────
RegisterNetEvent('weapons:removeWeapon', function(category)
    local src = source
    if not PlayerWeapons[src] then return end

    PlayerWeapons[src][category] = nil

    local identifier = GetIdentifierWeapons(src)
    if identifier then
        DB_SaveWeapons(identifier, PlayerWeapons[src])
    end

    TriggerClientEvent('weapons:receive', src, SerializeWeapons(PlayerWeapons[src]))
end)

-- ─── Mise à jour munitions ────────────────────────────────────────────────────
RegisterNetEvent('weapons:updateAmmo', function(category, ammo)
    local src = source
    ammo = tonumber(ammo) or 0

    -- Mettre à jour le slot arme si présent
    if PlayerWeapons[src] and PlayerWeapons[src][category] then
        PlayerWeapons[src][category].ammo = ammo
        local identifier = GetIdentifierWeapons(src)
        if identifier then
            MySQL.query(
                'UPDATE character_weapons SET ammo = ? WHERE identifier = ? AND category = ?',
                { ammo, identifier, category }
            )
        end
    end

    -- Mettre à jour l'item inventaire si l'arme est dans l'inventaire (cas hotbar)
    local inv = PlayerInventories and PlayerInventories[src]
    if inv then
        for slot, data in pairs(inv) do
            local itemDef = Items[data.item]
            if itemDef and itemDef.isWeapon and itemDef.weaponCategory == category then
                local newAmount = math.max(ammo, 0)
                if newAmount ~= data.amount then
                    data.amount = newAmount
                    local identifier = GetIdentifier(src)
                    if identifier then
                        -- UPDATE direct pour ne pas supprimer l'arme si ammo = 0
                        MySQL.query(
                            'UPDATE character_inventory SET amount = ? WHERE identifier = ? AND slot = ?',
                            { newAmount, identifier, slot }
                        )
                    end
                    -- Envoyer l'inventaire mis à jour pour sync NUI
                    TriggerClientEvent('inv:receiveInventory', src,
                        SerializeInventory(inv), GetNearGroundForPlayer(src))
                end
                break
            end
        end
    end
end)

-- ─── Fonction globale : ajouter des munitions à une arme (utilisé par inv:useAmmo) ──
function AddAmmoToPlayerWeapon(src, weaponName, ammoToAdd)
    if not PlayerWeapons[src] then return false, 0 end
    for cat, data in pairs(PlayerWeapons[src]) do
        if data.weapon == weaponName then
            data.ammo = (data.ammo or 0) + ammoToAdd
            local identifier = GetIdentifierWeapons(src)
            if identifier then
                DB_SaveWeapons(identifier, PlayerWeapons[src])
            end
            return true, data.ammo
        end
    end
    return false, 0
end

-- ─── Fonction globale : obtenir les munitions actuelles d'une arme ─────────────
function GetPlayerWeaponAmmo(src, weaponName)
    if not PlayerWeapons[src] then return 0 end
    for cat, data in pairs(PlayerWeapons[src]) do
        if data.weapon == weaponName then
            return data.ammo or 0
        end
    end
    return 0
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  ÉQUIPER DEPUIS L'INVENTAIRE (drag & drop : inv → slot arme)
--  Le joueur drag un item arme depuis l'inventaire vers un slot arme.
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('weapons:equipFromInv', function(invSlot)
    local src = source
    local inv = PlayerInventories[src]
    if not inv or not inv[invSlot] then return end

    local data    = inv[invSlot]
    local itemDef = Items[data.item]
    if not itemDef or not itemDef.isWeapon then return end

    local weaponName = itemDef.weaponName   -- ex: 'WEAPON_PISTOL'
    local category   = itemDef.weaponCategory
    local ammo       = data.amount or 1

    -- Initialise PlayerWeapons si nécessaire
    if not PlayerWeapons[src] then
        PlayerWeapons[src] = {}
    end

    -- Si un slot arme de cette catégorie est déjà occupé, remettre l'ancienne arme dans l'inventaire
    if PlayerWeapons[src][category] then
        local oldWeapon = PlayerWeapons[src][category]
        local oldItemName = string.lower(oldWeapon.weapon)
        local oldAmmo = oldWeapon.ammo or 1
        local remaining = AddItemToInventory(inv, oldItemName, oldAmmo)
        if remaining > 0 then
            -- Inventaire plein, on ne peut pas échanger
            TriggerClientEvent('inv:chatNotify', src, '~r~Inventaire plein — impossible d\'échanger l\'arme.')
            return
        end
    end

    -- Retirer l'item arme de l'inventaire
    inv[invSlot] = nil

    -- Mettre l'arme dans le slot
    PlayerWeapons[src][category] = {
        weapon = weaponName,
        ammo   = ammo,
    }

    -- Sauvegarder
    local identifier = GetIdentifier(src)
    if identifier then
        DB_SaveInventory(identifier, inv)
        DB_SaveWeapons(identifier, PlayerWeapons[src])
    end

    -- Envoyer les mises à jour au client
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv), GetNearGroundForPlayer(src))
    TriggerClientEvent('weapons:receive', src, SerializeWeapons(PlayerWeapons[src]))
    TriggerClientEvent('weapons:weaponGiven', src, weaponName, ammo)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
--  DÉSÉQUIPER VERS L'INVENTAIRE (drag & drop : slot arme → inv)
--  Le joueur drag une arme depuis le slot arme vers l'inventaire.
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('weapons:unequipToInv', function(category)
    local src = source
    if not PlayerWeapons[src] or not PlayerWeapons[src][category] then return end

    local inv = PlayerInventories[src]
    if not inv then
        PlayerInventories[src] = {}
        inv = PlayerInventories[src]
    end

    local weaponData = PlayerWeapons[src][category]
    local itemName   = string.lower(weaponData.weapon)
    local ammo       = math.max(weaponData.ammo or 1, 1)  -- minimum 1 pour que l'item existe

    -- Ajouter l'item arme dans l'inventaire
    local remaining = AddItemToInventory(inv, itemName, ammo)
    if remaining > 0 then
        TriggerClientEvent('inv:chatNotify', src, '~r~Inventaire plein — impossible de ranger l\'arme.')
        return
    end

    -- Retirer du slot arme
    PlayerWeapons[src][category] = nil

    -- Sauvegarder
    local identifier = GetIdentifier(src)
    if identifier then
        DB_SaveInventory(identifier, inv)
        DB_SaveWeapons(identifier, PlayerWeapons[src])
    end

    -- Envoyer les mises à jour au client
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv), GetNearGroundForPlayer(src))
    TriggerClientEvent('weapons:receive', src, SerializeWeapons(PlayerWeapons[src]))
    TriggerClientEvent('weapons:weaponRemoved', src, category)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
--  EXPORTS (déclarés aussi dans fxmanifest.lua)
-- ═══════════════════════════════════════════════════════════════════════════════

exports('giveWeapon', function(target, weaponName, ammo)
    return GiveWeaponToPlayer(0, target, string.upper(weaponName), ammo or 250)
end)

exports('getPlayerWeapons', function(src)
    return PlayerWeapons[src] or {}
end)

exports('removeWeapon', function(src, category)
    if not PlayerWeapons[src] then return end
    PlayerWeapons[src][category] = nil
    local identifier = GetIdentifierWeapons(src)
    if identifier then
        DB_SaveWeapons(identifier, PlayerWeapons[src])
    end
    TriggerClientEvent('weapons:receive', src, SerializeWeapons(PlayerWeapons[src]))
end)

exports('getWeaponList', function()
    local list = {}
    for name, def in pairs(Weapons) do
        list[#list + 1] = { name = name, label = def.label, category = def.category }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end)

exports('getWeaponCategories', function()
    return WeaponCategories
end)
