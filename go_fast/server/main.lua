local dealers = {}
local trustData = {} -- { [identifier] = trustPercent }
local cooldowns = {} -- { [identifier] = os.time() de la dernière mission }
local dealerPaidData = {} -- { [identifier] = true }

-- Chemin du fichier de sauvegarde
local savePath = GetResourcePath(GetCurrentResourceName()) .. '/' .. Config.SaveFile
local trustSavePath = GetResourcePath(GetCurrentResourceName()) .. '/trust.json'
local dealerPaidPath = GetResourcePath(GetCurrentResourceName()) .. '/dealer_paid.json'

-- ═══════════════════════════════════════════
--  SAUVEGARDE / CHARGEMENT
-- ═══════════════════════════════════════════

function LoadDealers()
    local file = io.open(savePath, 'r')
    if file then
        local content = file:read('*a')
        file:close()
        if content and content ~= '' then
            dealers = json.decode(content) or {}
        end
    end
    print('[go_fast] ' .. #dealers .. ' dealer(s) chargé(s)')
end

function SaveDealers()
    local file = io.open(savePath, 'w')
    if file then
        file:write(json.encode(dealers))
        file:close()
    end
end

function LoadTrust()
    local file = io.open(trustSavePath, 'r')
    if file then
        local content = file:read('*a')
        file:close()
        if content and content ~= '' then
            trustData = json.decode(content) or {}
        end
    end
    local count = 0
    for _ in pairs(trustData) do count = count + 1 end
    print('[go_fast] Trust data chargé (' .. count .. ' joueur(s))')
end

function SaveTrust()
    local file = io.open(trustSavePath, 'w')
    if file then
        file:write(json.encode(trustData))
        file:close()
    end
    print('[go_fast] Trust data sauvegardé')
end

function LoadDealerPaid()
    local file = io.open(dealerPaidPath, 'r')
    if file then
        local content = file:read('*a')
        file:close()
        if content and content ~= '' then
            dealerPaidData = json.decode(content) or {}
        end
    end
    local count = 0
    for _ in pairs(dealerPaidData) do count = count + 1 end
    print('[go_fast] Dealer paid data chargé (' .. count .. ' joueur(s))')
end

function SaveDealerPaid()
    local file = io.open(dealerPaidPath, 'w')
    if file then
        file:write(json.encode(dealerPaidData))
        file:close()
    end
    print('[go_fast] Dealer paid data sauvegardé')
end

function HasPlayerPaidDealer(src)
    local id = GetPlayerLicense(src)
    return dealerPaidData[id] == true
end

function SetPlayerPaidDealer(src)
    local id = GetPlayerLicense(src)
    dealerPaidData[id] = true
    SaveDealerPaid()
end

function GetPlayerLicense(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if string.find(id, 'license:') then
            return id
        end
    end
    return 'unknown_' .. src
end

function GetPlayerTrust(src)
    local id = GetPlayerLicense(src)
    return trustData[id] or 0
end

function SetPlayerTrust(src, value)
    local id = GetPlayerLicense(src)
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end
    trustData[id] = value
    SaveTrust()
end

-- ═══════════════════════════════════════════
--  EVENTS
-- ═══════════════════════════════════════════

-- Quand un joueur rejoint, envoyer la liste des dealers
RegisterNetEvent('go_fast:requestDealers')
AddEventHandler('go_fast:requestDealers', function()
    local src = source
    TriggerClientEvent('go_fast:spawnAllDealers', src, dealers)
end)

-- Ajouter un nouveau dealer
RegisterNetEvent('go_fast:addDealer')
AddEventHandler('go_fast:addDealer', function(data)
    local src = source
    local dealer = {
        x = data.x,
        y = data.y,
        z = data.z,
        heading = data.heading,
    }
    table.insert(dealers, dealer)
    SaveDealers()

    -- Notifier tous les clients pour spawn le nouveau dealer
    TriggerClientEvent('go_fast:spawnDealer', -1, dealer, #dealers)
    TriggerClientEvent('chatMessage', src, '', {0, 255, 0}, 'Dealer placé ! (ID: ' .. #dealers .. ')')
end)

-- Supprimer un dealer par ID
RegisterNetEvent('go_fast:removeDealer')
AddEventHandler('go_fast:removeDealer', function(dealerId)
    local src = source
    if dealers[dealerId] then
        table.remove(dealers, dealerId)
        SaveDealers()

        -- Notifier tous les clients pour respawn la liste complète
        TriggerClientEvent('go_fast:despawnAll', -1)
        Citizen.Wait(500)
        TriggerClientEvent('go_fast:spawnAllDealers', -1, dealers)
        TriggerClientEvent('chatMessage', src, '', {255, 100, 0}, 'Dealer #' .. dealerId .. ' supprimé !')
    else
        TriggerClientEvent('chatMessage', src, '', {255, 0, 0}, 'Dealer #' .. dealerId .. ' introuvable.')
    end
end)

-- Définir le point de spawn de la voiture pour un dealer
RegisterNetEvent('go_fast:setVehicleSpawn')
AddEventHandler('go_fast:setVehicleSpawn', function(dealerId, spawnData)
    local src = source
    if dealers[dealerId] then
        dealers[dealerId].vehicleSpawn = {
            x = spawnData.x,
            y = spawnData.y,
            z = spawnData.z,
            heading = spawnData.heading,
        }
        SaveDealers()
        TriggerClientEvent('chatMessage', src, '', {0, 255, 0}, 'Point de spawn véhicule défini pour le dealer #' .. dealerId)
    else
        TriggerClientEvent('chatMessage', src, '', {255, 0, 0}, 'Dealer #' .. dealerId .. ' introuvable.')
    end
end)

-- Vérifier le cooldown d'un joueur (appelé par pnj_interact avant l'animation)
RegisterNetEvent('go_fast:checkCooldown')
AddEventHandler('go_fast:checkCooldown', function()
    local src = source

    -- Fondateur = pas de cooldown
    local founder = false
    local ok, result = pcall(function() return exports['admin_menu']:isFounder(src) end)
    if not ok then
        print('[go_fast] ERREUR isFounder (checkCooldown): ' .. tostring(result))
    end
    print('[go_fast] checkCooldown joueur ' .. src .. ' : ok=' .. tostring(ok) .. ' result=' .. tostring(result))
    if ok and result then founder = true end

    if founder then
        print('[go_fast] Joueur ' .. src .. ' est Fondateur -> pas de cooldown')
        TriggerClientEvent('go_fast:cooldownResult', src, false, 0)
        return
    end

    local id = GetPlayerLicense(src)
    local lastTime = cooldowns[id] or 0
    local now = os.time()
    local remaining = Config.MissionCooldown - (now - lastTime)

    if remaining > 0 then
        TriggerClientEvent('go_fast:cooldownResult', src, true, remaining)
    else
        TriggerClientEvent('go_fast:cooldownResult', src, false, 0)
    end
end)

-- Récupérer les infos d'un dealer par ses coordonnées (pour la mission)
RegisterNetEvent('go_fast:getDealerVehicleSpawn')
AddEventHandler('go_fast:getDealerVehicleSpawn', function(dx, dy, dz)
    local src = source

    -- Vérifier le cooldown (sauf Fondateur)
    local isFounder = false
    local ok, result = pcall(function() return exports['admin_menu']:isFounder(src) end)
    if not ok then
        print('[go_fast] ERREUR isFounder (getDealerVehicleSpawn): ' .. tostring(result))
    end
    print('[go_fast] getDealerVehicleSpawn joueur ' .. src .. ' : ok=' .. tostring(ok) .. ' result=' .. tostring(result))
    if ok and result then isFounder = true end
    if not isFounder then
        local id = GetPlayerLicense(src)
        local lastTime = cooldowns[id] or 0
        local now = os.time()
        local remaining = Config.MissionCooldown - (now - lastTime)
        if remaining > 0 then
            local mins = math.floor(remaining / 60)
            local secs = remaining % 60
            TriggerClientEvent('go_fast:cooldownRefused', src, mins, secs)
            return
        end
    end

    -- Enregistrer le timestamp du lancement (pas pour les fondateurs)
    if not isFounder then
        local id = GetPlayerLicense(src)
        cooldowns[id] = os.time()
    end

    local closestDealer = nil
    local closestDist = 5.0

    for _, dealer in ipairs(dealers) do
        local dist = math.sqrt((dealer.x - dx)^2 + (dealer.y - dy)^2 + (dealer.z - dz)^2)
        if dist < closestDist then
            closestDist = dist
            closestDealer = dealer
        end
    end

    -- Choisir le type de drogue et la quantité selon le palier de confiance
    local drugType = nil
    local drugAmount = 0
    if Config.DrugTypes and #Config.DrugTypes > 0 and Config.DrugAmountPerTier then
        local trust = GetPlayerTrust(src)
        local palier = math.floor(trust / 10)
        if palier > 10 then palier = 10 end
        drugAmount = Config.DrugAmountPerTier[palier] or 3
        drugType = Config.DrugTypes[math.random(#Config.DrugTypes)]
    end

    if closestDealer and closestDealer.vehicleSpawn then
        TriggerClientEvent('go_fast:startMissionWithSpawn', src, closestDealer.vehicleSpawn, drugType, drugAmount)
    else
        -- Pas de spawn défini, utiliser position par défaut (à côté du dealer)
        TriggerClientEvent('go_fast:startMissionWithSpawn', src, nil, drugType, drugAmount)
    end

    -- Alerter la police qu'un Go Fast vient de demarrer
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    TriggerEvent('police:goFastAlert', nil, {
        x = playerCoords.x,
        y = playerCoords.y,
        z = playerCoords.z,
    })
end)

-- Relayer l'attaque d'un dealer à tous les clients
RegisterNetEvent('go_fast:dealerAttack')
AddEventHandler('go_fast:dealerAttack', function(dx, dy, dz, targetServerId)
    TriggerClientEvent('go_fast:dealerAttackSync', -1, dx, dy, dz, targetServerId)
end)

-- ═══════════════════════════════════════════
--  CONFIANCE
-- ═══════════════════════════════════════════

-- Le client demande sa confiance actuelle
RegisterNetEvent('go_fast:requestTrust')
AddEventHandler('go_fast:requestTrust', function()
    local src = source
    local trust = GetPlayerTrust(src)
    TriggerClientEvent('go_fast:updateTrust', src, trust)
end)

-- Livraison réussie : augmenter la confiance + donner l'argent
RegisterNetEvent('go_fast:deliverySuccess')
AddEventHandler('go_fast:deliverySuccess', function()
    local src = source
    local trust = GetPlayerTrust(src)

    -- Calculer la récompense : base + bonus par palier de 10% de confiance
    local paliers = math.floor(trust / 10)
    local bonusPercent = paliers * Config.DeliveryTrustBonusPercent
    local reward = math.floor(Config.DeliveryBaseReward * (1 + bonusPercent / 100))

    -- Donner l'argent au joueur
    exports['inv_system']:addItem(src, 'money', reward)
    TriggerClientEvent('go_fast:rewardReceived', src, reward)

    -- Augmenter la confiance
    trust = trust + Config.TrustGainSuccess
    SetPlayerTrust(src, trust)
    TriggerClientEvent('go_fast:updateTrust', src, GetPlayerTrust(src))
end)

-- Livraison échouée : diminuer la confiance
RegisterNetEvent('go_fast:deliveryFail')
AddEventHandler('go_fast:deliveryFail', function()
    local src = source
    local trust = GetPlayerTrust(src)
    trust = trust - Config.TrustLossFail
    SetPlayerTrust(src, trust)
    TriggerClientEvent('go_fast:updateTrust', src, GetPlayerTrust(src))
end)

-- ═══════════════════════════════════════════
--  PAIEMENT (via inv_system)
-- ═══════════════════════════════════════════

RegisterNetEvent('go_fast:payMoney')
AddEventHandler('go_fast:payMoney', function(amount, purpose)
    local src = source
    local has = exports['inv_system']:HasItem(src, 'money', amount)
    if has then
        exports['inv_system']:RemoveItem(src, 'money', amount)
        -- Marquer le joueur comme ayant payé le dealer
        if purpose == 'dealer_5000' or purpose == 'dealer_4000' then
            SetPlayerPaidDealer(src)
            TriggerClientEvent('go_fast:updateDealerPaid', src, true)
        end
        TriggerClientEvent('go_fast:payMoneyResult', src, true, purpose)
    else
        TriggerClientEvent('go_fast:payMoneyResult', src, false, purpose)
    end
end)

-- Remettre la confiance à 0 (véhicule pas ramené)
RegisterNetEvent('go_fast:resetTrust')
AddEventHandler('go_fast:resetTrust', function()
    local src = source
    SetPlayerTrust(src, 0)
    TriggerClientEvent('go_fast:updateTrust', src, 0)
end)

-- Placer la drogue dans le coffre du véhicule de mission
RegisterNetEvent('go_fast:addDrugsToTrunk')
AddEventHandler('go_fast:addDrugsToTrunk', function(plate, drugType, drugAmount)
    if not plate or plate == '' then return end
    if not drugType or not drugAmount or drugAmount <= 0 then return end

    local ok, remaining = pcall(function()
        return exports['inv_system']:addItemToVehicle(plate, 'trunk', drugType, drugAmount)
    end)
    if not ok then
        print('[go_fast] ERREUR addItemToVehicle: ' .. tostring(remaining))
        return
    end
    if remaining and remaining > 0 then
        print('[go_fast] Attention : ' .. remaining .. ' kg de drogue n\'ont pas pu etre places (coffre plein)')
    end
    print('[go_fast] ' .. drugAmount .. 'kg de ' .. drugType .. ' places dans le coffre (' .. plate .. ')')
end)

-- Donner les clés de véhicule au joueur (avec la plaque pour vehicle_keys)
RegisterNetEvent('go_fast:giveVehicleKeyForPlate')
AddEventHandler('go_fast:giveVehicleKeyForPlate', function(plate)
    local src = source
    if not plate or plate == '' then return end
    exports['vehicle_keys']:giveKey(src, plate)
end)

-- Retirer les clés de véhicule du joueur
RegisterNetEvent('go_fast:removeVehicleKey')
AddEventHandler('go_fast:removeVehicleKey', function(plate)
    local src = source
    if not plate or plate == '' then return end
    exports['vehicle_keys']:removeKey(src, plate)
end)

-- Le client demande si le joueur a déjà payé le dealer
RegisterNetEvent('go_fast:requestDealerPaid')
AddEventHandler('go_fast:requestDealerPaid', function()
    local src = source
    local paid = HasPlayerPaidDealer(src)
    TriggerClientEvent('go_fast:updateDealerPaid', src, paid)
end)

-- ═══════════════════════════════════════════
--  COMMANDE /setreput [ID] [Pourcentage]
-- ═══════════════════════════════════════════

RegisterCommand('setreput', function(source, args, rawCommand)
    local src = source

    -- Vérifier que c'est un admin/fondateur (ou la console serveur si src == 0)
    if src ~= 0 then
        local isFounder = false
        local ok, result = pcall(function() return exports['admin_menu']:isFounder(src) end)
        if ok and result then isFounder = true end

        if not isFounder then
            TriggerClientEvent('chatMessage', src, '', {255, 0, 0}, '[go_fast] Tu n\'as pas la permission d\'utiliser cette commande.')
            return
        end
    end

    -- Vérifier les arguments
    if not args[1] or not args[2] then
        if src == 0 then
            print('[go_fast] Usage: /setreput [ID joueur] [Pourcentage 0-100]')
        else
            TriggerClientEvent('chatMessage', src, '', {255, 255, 0}, 'Usage: /setreput [ID joueur] [Pourcentage 0-100]')
        end
        return
    end

    local targetId = tonumber(args[1])
    local newTrust = tonumber(args[2])

    if not targetId or not newTrust then
        if src == 0 then
            print('[go_fast] Erreur: ID et pourcentage doivent être des nombres.')
        else
            TriggerClientEvent('chatMessage', src, '', {255, 0, 0}, 'Erreur: ID et pourcentage doivent être des nombres.')
        end
        return
    end

    -- Vérifier que le pourcentage est entre 0 et 100
    if newTrust < 0 then newTrust = 0 end
    if newTrust > 100 then newTrust = 100 end

    -- Vérifier que le joueur cible est connecté
    local targetName = GetPlayerName(targetId)
    if not targetName then
        if src == 0 then
            print('[go_fast] Erreur: Joueur ID ' .. targetId .. ' introuvable (pas connecté).')
        else
            TriggerClientEvent('chatMessage', src, '', {255, 0, 0}, 'Erreur: Joueur ID ' .. targetId .. ' introuvable (pas connecté).')
        end
        return
    end

    -- Mettre à jour la réputation
    SetPlayerTrust(targetId, newTrust)

    -- Synchroniser côté client du joueur cible
    TriggerClientEvent('go_fast:updateTrust', targetId, newTrust)

    -- Confirmer au joueur qui a exécuté la commande
    if src == 0 then
        print('[go_fast] Réputation de ' .. targetName .. ' (ID: ' .. targetId .. ') définie à ' .. newTrust .. '%')
    else
        TriggerClientEvent('chatMessage', src, '', {0, 255, 0}, '[go_fast] Réputation de ' .. targetName .. ' (ID: ' .. targetId .. ') définie à ' .. newTrust .. '%')
    end

    -- Notifier le joueur cible
    TriggerClientEvent('chatMessage', targetId, '', {0, 255, 255}, '[go_fast] Ta réputation a été définie à ' .. newTrust .. '% par un administrateur.')
end, true) -- true = commande restreinte (nécessite ace permission ou vérification interne)

-- ═══════════════════════════════════════════
--  INIT (chargé AVANT que les events soient traités)
-- ═══════════════════════════════════════════

LoadDealers()
LoadTrust()
LoadDealerPaid()

-- Sauvegarder toutes les données quand la ressource s'arrête
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[go_fast] Sauvegarde des données avant arrêt...')
        SaveDealers()
        SaveTrust()
        SaveDealerPaid()
        print('[go_fast] Données sauvegardées.')
    end
end)
