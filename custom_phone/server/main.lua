-- server/main.lua - Custom Phone (Contacts + Messages)
-- Utilise MySQL.query / MySQL.insert (API synchrone de @oxmysql/lib/MySQL.lua)

-- ==================== UTILITAIRES ====================

-- Recuperer l'identifier du joueur (license, steam, etc.)
local function GetPlayerIdent(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if string.find(id, 'license:') then
            return id
        end
    end
    if GetNumPlayerIdentifiers(src) > 0 then
        return GetPlayerIdentifier(src, 0)
    end
    return nil
end

-- Recuperer le nom RP du joueur depuis la table characters (charCreate)
local function GetPlayerRPName(src)
    local identifier = GetPlayerIdent(src)
    if not identifier then return GetPlayerName(src) or 'Joueur' end

    local result = MySQL.query.await('SELECT firstname, lastname FROM characters WHERE identifier = ?', {identifier})
    if result and #result > 0 then
        local first = result[1].firstname or ''
        local last = result[1].lastname or ''
        if first ~= '' and last ~= '' then
            return first .. ' ' .. last
        elseif first ~= '' then
            return first
        end
    end
    return GetPlayerName(src) or 'Joueur'
end

-- ==================== GIVEPHONE ====================

RegisterCommand('givephone', function(source, args)
    local target = tonumber(args[1]) or source
    local ok, result = pcall(function()
        return exports['inv_system']:addItem(target, 'phone', 1)
    end)
    if ok and result then
        TriggerClientEvent('inv:chatNotify', target, '~g~Tu as recu un telephone !')
        if target ~= source and source > 0 then
            TriggerClientEvent('inv:chatNotify', source, '~g~Telephone donne au joueur ' .. target)
        end
    else
        if source > 0 then
            TriggerClientEvent('inv:chatNotify', source, '~r~Erreur : impossible de donner le telephone.')
        end
        print('[custom_phone] Erreur givephone: ' .. tostring(result))
    end
end, false)

-- ==================== VERIFICATION TELEPHONE ====================

RegisterNetEvent('phone:checkHasPhone')
AddEventHandler('phone:checkHasPhone', function()
    local src = source
    local hasPhone = false
    local ok, result = pcall(function()
        return exports['inv_system']:HasItem(src, 'phone', 1)
    end)
    if ok and result then
        hasPhone = true
    end
    TriggerClientEvent('phone:hasPhoneResult', src, hasPhone)
end)

-- ==================== CONFIGURATION INITIALE ====================

-- Verifier si le joueur a deja configure son telephone
RegisterNetEvent('phone:checkSetup')
AddEventHandler('phone:checkSetup', function()
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier then
        TriggerClientEvent('phone:setupStatus', src, false, nil, GetPlayerRPName(src) or 'Joueur')
        return
    end

    local result = MySQL.query.await('SELECT phone_number, display_name FROM phone_numbers WHERE identifier = ?', {identifier})
    if result and #result > 0 then
        local displayName = result[1].display_name or GetPlayerRPName(src) or 'Joueur'
        TriggerClientEvent('phone:setupStatus', src, true, result[1].phone_number, displayName)
    else
        TriggerClientEvent('phone:setupStatus', src, false, nil, GetPlayerRPName(src) or 'Joueur')
    end
end)

-- Verifier si un numero est disponible
RegisterNetEvent('phone:checkNumberAvailable')
AddEventHandler('phone:checkNumberAvailable', function(number)
    local src = source
    if not number or number == '' then
        TriggerClientEvent('phone:numberAvailableResult', src, false, 'Numero invalide')
        return
    end

    number = string.sub(number, 1, 15)

    local result = MySQL.query.await('SELECT id FROM phone_numbers WHERE phone_number = ?', {number})
    if result and #result > 0 then
        TriggerClientEvent('phone:numberAvailableResult', src, false, 'Ce numero est deja pris')
    else
        TriggerClientEvent('phone:numberAvailableResult', src, true, nil)
    end
end)

-- Enregistrer le numero choisi par le joueur
RegisterNetEvent('phone:registerNumber')
AddEventHandler('phone:registerNumber', function(chosenNumber)
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier then
        TriggerClientEvent('phone:registerResult', src, false, 'Erreur identification')
        return
    end

    if not chosenNumber or chosenNumber == '' then
        TriggerClientEvent('phone:registerResult', src, false, 'Numero invalide')
        return
    end

    chosenNumber = string.sub(chosenNumber, 1, 15)
    local playerName = GetPlayerRPName(src) or 'Joueur'

    -- Verifier que le joueur n'a pas deja un numero
    local existing = MySQL.query.await('SELECT id FROM phone_numbers WHERE identifier = ?', {identifier})
    if existing and #existing > 0 then
        TriggerClientEvent('phone:registerResult', src, false, 'Tu as deja un numero')
        return
    end

    -- Verifier que le numero n'est pas deja pris
    local taken = MySQL.query.await('SELECT id FROM phone_numbers WHERE phone_number = ?', {chosenNumber})
    if taken and #taken > 0 then
        TriggerClientEvent('phone:registerResult', src, false, 'Ce numero est deja pris')
        return
    end

    -- Inserer le numero
    local insertId = MySQL.insert.await('INSERT INTO phone_numbers (identifier, phone_number, display_name) VALUES (?, ?, ?)',
        {identifier, chosenNumber, playerName})
    if insertId then
        TriggerClientEvent('phone:registerResult', src, true, nil)
        TriggerClientEvent('phone:setupStatus', src, true, chosenNumber, playerName)
    else
        TriggerClientEvent('phone:registerResult', src, false, 'Erreur base de donnees')
    end
end)

-- ==================== NUMERO DE TELEPHONE ====================

-- Recuperer le numero du joueur (pour les contacts/messages)
RegisterNetEvent('phone:getMyNumber')
AddEventHandler('phone:getMyNumber', function()
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier then
        TriggerClientEvent('phone:myNumberResult', src, nil, 'Joueur')
        return
    end

    local result = MySQL.query.await('SELECT phone_number, display_name FROM phone_numbers WHERE identifier = ?', {identifier})
    if result and #result > 0 then
        local displayName = result[1].display_name or GetPlayerRPName(src) or 'Joueur'
        TriggerClientEvent('phone:myNumberResult', src, result[1].phone_number, displayName)
    else
        TriggerClientEvent('phone:myNumberResult', src, nil, GetPlayerRPName(src) or 'Joueur')
    end
end)

-- ==================== CONTACTS ====================

-- Recuperer la liste des contacts
RegisterNetEvent('phone:getContacts')
AddEventHandler('phone:getContacts', function()
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier then
        TriggerClientEvent('phone:contactsList', src, {})
        return
    end

    local result = MySQL.query.await('SELECT id, contact_name, contact_number FROM phone_contacts WHERE owner_identifier = ? ORDER BY contact_name ASC', {identifier})
    TriggerClientEvent('phone:contactsList', src, result or {})
end)

-- Ajouter un contact
RegisterNetEvent('phone:addContact')
AddEventHandler('phone:addContact', function(name, number)
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier or not name or not number or name == '' or number == '' then
        TriggerClientEvent('phone:contactAdded', src, false, 'Donnees invalides')
        return
    end

    name = string.sub(name, 1, 64)
    number = string.sub(number, 1, 15)

    local insertId = MySQL.insert.await('INSERT INTO phone_contacts (owner_identifier, contact_name, contact_number) VALUES (?, ?, ?)',
        {identifier, name, number})
    if insertId then
        TriggerClientEvent('phone:contactAdded', src, true, nil)
        -- Renvoyer la liste mise a jour
        local contacts = MySQL.query.await('SELECT id, contact_name, contact_number FROM phone_contacts WHERE owner_identifier = ? ORDER BY contact_name ASC', {identifier})
        TriggerClientEvent('phone:contactsList', src, contacts or {})
    else
        TriggerClientEvent('phone:contactAdded', src, false, 'Erreur base de donnees')
    end
end)

-- Supprimer un contact
RegisterNetEvent('phone:deleteContact')
AddEventHandler('phone:deleteContact', function(contactId)
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier or not contactId then
        TriggerClientEvent('phone:contactDeleted', src, false)
        return
    end

    local affectedRows = MySQL.update.await('DELETE FROM phone_contacts WHERE id = ? AND owner_identifier = ?',
        {contactId, identifier})
    if affectedRows and affectedRows > 0 then
        TriggerClientEvent('phone:contactDeleted', src, true)
    else
        TriggerClientEvent('phone:contactDeleted', src, false)
    end
end)

-- ==================== MESSAGES ====================

-- Recuperer les conversations (dernier message de chaque contact)
RegisterNetEvent('phone:getConversations')
AddEventHandler('phone:getConversations', function()
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier then
        TriggerClientEvent('phone:conversationsList', src, {})
        return
    end

    local numResult = MySQL.query.await('SELECT phone_number FROM phone_numbers WHERE identifier = ?', {identifier})
    if not numResult or #numResult == 0 then
        TriggerClientEvent('phone:conversationsList', src, {})
        return
    end

    local myNumber = numResult[1].phone_number

    local conversations = MySQL.query.await([[
        SELECT m.*, 
            CASE 
                WHEN m.sender_number = ? THEN m.receiver_number 
                ELSE m.sender_number 
            END as other_number
        FROM phone_messages m
        INNER JOIN (
            SELECT 
                CASE 
                    WHEN sender_number = ? THEN receiver_number 
                    ELSE sender_number 
                END as contact_number,
                MAX(id) as max_id
            FROM phone_messages 
            WHERE sender_number = ? OR receiver_number = ?
            GROUP BY contact_number
        ) latest ON m.id = latest.max_id
        ORDER BY m.created_at DESC
    ]], {myNumber, myNumber, myNumber, myNumber})

    if not conversations or #conversations == 0 then
        TriggerClientEvent('phone:conversationsList', src, {})
        return
    end

    -- Compter les messages non lus pour chaque conversation
    for i, conv in ipairs(conversations) do
        local unreadResult = MySQL.query.await(
            'SELECT COUNT(*) as unread FROM phone_messages WHERE sender_number = ? AND receiver_number = ? AND is_read = 0',
            {conv.other_number, myNumber})
        conversations[i].unread_count = (unreadResult and #unreadResult > 0) and unreadResult[1].unread or 0
    end

    TriggerClientEvent('phone:conversationsList', src, conversations)
end)

-- Recuperer les messages d'une conversation
RegisterNetEvent('phone:getMessages')
AddEventHandler('phone:getMessages', function(otherNumber)
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier or not otherNumber then
        TriggerClientEvent('phone:messagesList', src, {}, otherNumber)
        return
    end

    local numResult = MySQL.query.await('SELECT phone_number FROM phone_numbers WHERE identifier = ?', {identifier})
    if not numResult or #numResult == 0 then
        TriggerClientEvent('phone:messagesList', src, {}, otherNumber)
        return
    end

    local myNumber = numResult[1].phone_number

    local messages = MySQL.query.await(
        'SELECT * FROM phone_messages WHERE (sender_number = ? AND receiver_number = ?) OR (sender_number = ? AND receiver_number = ?) ORDER BY created_at ASC',
        {myNumber, otherNumber, otherNumber, myNumber})
    TriggerClientEvent('phone:messagesList', src, messages or {}, otherNumber)

    -- Marquer les messages recus comme lus
    MySQL.update.await(
        'UPDATE phone_messages SET is_read = 1 WHERE sender_number = ? AND receiver_number = ? AND is_read = 0',
        {otherNumber, myNumber})
end)

-- Envoyer un message
RegisterNetEvent('phone:sendMessage')
AddEventHandler('phone:sendMessage', function(receiverNumber, messageText)
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier or not receiverNumber or not messageText or messageText == '' then
        TriggerClientEvent('phone:messageSent', src, false)
        return
    end

    messageText = string.sub(messageText, 1, 500)

    local numResult = MySQL.query.await('SELECT phone_number FROM phone_numbers WHERE identifier = ?', {identifier})
    if not numResult or #numResult == 0 then
        TriggerClientEvent('phone:messageSent', src, false)
        return
    end

    local myNumber = numResult[1].phone_number

    local insertId = MySQL.insert.await(
        'INSERT INTO phone_messages (sender_number, receiver_number, message) VALUES (?, ?, ?)',
        {myNumber, receiverNumber, messageText})

    if insertId then
        TriggerClientEvent('phone:messageSent', src, true)

        -- Notifier le destinataire s'il est en ligne
        local destResult = MySQL.query.await('SELECT identifier FROM phone_numbers WHERE phone_number = ?', {receiverNumber})
        if destResult and #destResult > 0 then
            local destIdentifier = destResult[1].identifier

            -- Chercher le nom du contact dans les contacts du destinataire
            local contactName = nil
            local contactResult = MySQL.query.await(
                'SELECT contact_name FROM phone_contacts WHERE owner_identifier = ? AND contact_number = ?',
                {destIdentifier, myNumber})
            if contactResult and #contactResult > 0 then
                contactName = contactResult[1].contact_name
            end

            -- Recuperer le display_name de l'expediteur comme fallback
            local senderDisplayName = nil
            local senderResult = MySQL.query.await(
                'SELECT display_name FROM phone_numbers WHERE phone_number = ?', {myNumber})
            if senderResult and #senderResult > 0 then
                senderDisplayName = senderResult[1].display_name
            end

            for _, playerId in ipairs(GetPlayers()) do
                local pid = tonumber(playerId)
                local pIdentifier = GetPlayerIdent(pid)
                if pIdentifier == destIdentifier then
                    TriggerClientEvent('phone:newMessageNotification', pid, myNumber, messageText, contactName, senderDisplayName)
                    break
                end
            end
        end
    else
        TriggerClientEvent('phone:messageSent', src, false)
    end
end)

-- ==================== APPELS ====================

-- Table des appels en cours : activeCalls[srcServerId] = { target = targetServerId, state = 'ringing'/'active' }
local activeCalls = {}

-- Trouver le serverId d'un joueur par son numero de telephone
local function FindPlayerByNumber(phoneNumber)
    local result = MySQL.query.await('SELECT identifier FROM phone_numbers WHERE phone_number = ?', {phoneNumber})
    if not result or #result == 0 then return nil end

    local destIdentifier = result[1].identifier
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        local pIdentifier = GetPlayerIdent(pid)
        if pIdentifier == destIdentifier then
            return pid
        end
    end
    return nil
end

-- Recuperer le numero de telephone d'un joueur
local function GetPlayerPhoneNumber(src)
    local identifier = GetPlayerIdent(src)
    if not identifier then return nil end
    local result = MySQL.query.await('SELECT phone_number FROM phone_numbers WHERE identifier = ?', {identifier})
    if result and #result > 0 then
        return result[1].phone_number
    end
    return nil
end

-- Initier un appel
RegisterNetEvent('phone:initiateCall')
AddEventHandler('phone:initiateCall', function(targetNumber)
    local src = source
    if activeCalls[src] then return end

    local myNumber = GetPlayerPhoneNumber(src)
    if not myNumber then return end

    local targetPlayer = FindPlayerByNumber(targetNumber)
    if not targetPlayer then
        TriggerClientEvent('phone:callFailed', src, 'Joueur hors ligne')
        return
    end

    if activeCalls[targetPlayer] then
        TriggerClientEvent('phone:callFailed', src, 'Le joueur est deja en appel')
        return
    end

    -- Enregistrer l'appel
    activeCalls[src] = { target = targetPlayer, state = 'ringing' }
    activeCalls[targetPlayer] = { target = src, state = 'ringing' }

    -- Recuperer le nom de l'appelant
    local callerName = GetPlayerRPName(src) or 'Inconnu'

    -- Notifier le destinataire
    TriggerClientEvent('phone:incomingCall', targetPlayer, myNumber, callerName, src)
    -- Confirmer a l'appelant que ca sonne
    TriggerClientEvent('phone:callRinging', src)
end)

-- Accepter un appel
RegisterNetEvent('phone:acceptCall')
AddEventHandler('phone:acceptCall', function()
    local src = source
    local call = activeCalls[src]
    if not call or call.state ~= 'ringing' then return end

    local caller = call.target
    local callerCall = activeCalls[caller]

    -- Si c'est un appel service, annuler pour les autres agents
    if callerCall and callerCall.state == 'service_ringing' and callerCall.agents then
        for _, agentId in ipairs(callerCall.agents) do
            if agentId ~= src then
                activeCalls[agentId] = nil
                TriggerClientEvent('phone:callRejected', agentId)
            end
        end
        callerCall.agents = nil
    end

    activeCalls[src].state = 'active'
    activeCalls[caller] = { target = src, state = 'active' }

    -- Notifier les deux parties
    TriggerClientEvent('phone:callAccepted', src, caller)
    TriggerClientEvent('phone:callAccepted', caller, src)
end)

-- Refuser un appel
RegisterNetEvent('phone:rejectCall')
AddEventHandler('phone:rejectCall', function()
    local src = source
    local call = activeCalls[src]
    if not call then return end

    local other = call.target
    local otherCall = activeCalls[other]

    activeCalls[src] = nil
    TriggerClientEvent('phone:callRejected', src)

    -- Si c'est un appel service, verifier s'il reste des agents
    if otherCall and otherCall.state == 'service_ringing' and otherCall.agents then
        local remaining = {}
        for _, agentId in ipairs(otherCall.agents) do
            if agentId ~= src then
                table.insert(remaining, agentId)
            end
        end
        otherCall.agents = remaining
        if #remaining == 0 then
            -- Plus aucun agent disponible
            activeCalls[other] = nil
            TriggerClientEvent('phone:callFailed', other, 'Aucun employé disponible')
        end
    else
        activeCalls[other] = nil
        TriggerClientEvent('phone:callRejected', other)
    end
end)

-- Raccrocher
RegisterNetEvent('phone:hangupCall')
AddEventHandler('phone:hangupCall', function()
    local src = source
    local call = activeCalls[src]
    if not call then return end

    -- Si l'appelant raccroche pendant que ca sonne (appel service)
    if call.state == 'service_ringing' and call.agents then
        for _, agentId in ipairs(call.agents) do
            activeCalls[agentId] = nil
            TriggerClientEvent('phone:callEnded', agentId)
        end
        activeCalls[src] = nil
        TriggerClientEvent('phone:callEnded', src)
        return
    end

    local other = call.target
    activeCalls[src] = nil

    if other then
        -- Si l'autre partie avait un appel service en cours de sonnerie
        local otherCall = activeCalls[other]
        if otherCall and otherCall.state == 'service_ringing' and otherCall.agents then
            for _, agentId in ipairs(otherCall.agents) do
                activeCalls[agentId] = nil
                TriggerClientEvent('phone:callEnded', agentId)
            end
        end
        activeCalls[other] = nil
        TriggerClientEvent('phone:callEnded', other)
    end

    TriggerClientEvent('phone:callEnded', src)
end)

-- Nettoyer quand un joueur se deconnecte
AddEventHandler('playerDropped', function()
    local src = source
    local call = activeCalls[src]
    if call then
        -- Si c'etait un appel service en cours de sonnerie
        if call.state == 'service_ringing' and call.agents then
            for _, agentId in ipairs(call.agents) do
                activeCalls[agentId] = nil
                TriggerClientEvent('phone:callEnded', agentId)
            end
        end
        local other = call.target
        activeCalls[src] = nil
        if other and activeCalls[other] then
            -- Si l'autre partie avait un appel service
            local otherCall = activeCalls[other]
            if otherCall and otherCall.state == 'service_ringing' and otherCall.agents then
                for _, agentId in ipairs(otherCall.agents) do
                    activeCalls[agentId] = nil
                    TriggerClientEvent('phone:callEnded', agentId)
                end
            end
            activeCalls[other] = nil
            TriggerClientEvent('phone:callEnded', other)
        end
    end
end)

-- ==================== SERVICES ====================

-- Les services sont definis dans config.lua (Config.Services)

-- Creer la table service_messages au demarrage
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `service_messages` (
            `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `job` VARCHAR(50) NOT NULL,
            `sender_identifier` VARCHAR(60) NOT NULL,
            `sender_name` VARCHAR(100) NOT NULL,
            `message` TEXT NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_job (`job`),
            INDEX idx_created (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    print('[Phone] Table service_messages prete.')
end)

-- Trouver tous les joueurs en ligne avec un job specifique
local function GetPlayersWithJob(jobName)
    local players = {}
    local jobLower = string.lower(jobName)
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        local identifier = GetPlayerIdent(pid)
        if identifier then
            local result = MySQL.query.await('SELECT job1, job2 FROM characters WHERE identifier = ?', {identifier})
            if result and #result > 0 then
                local j1 = result[1].job1 and string.lower(result[1].job1) or ''
                local j2 = result[1].job2 and string.lower(result[1].job2) or ''
                if j1 == jobLower or j2 == jobLower then
                    table.insert(players, pid)
                end
            end
        end
    end
    return players
end

-- Compter les agents en service (via export job_police)
local function CountOnDutyForJob(jobName)
    local ok, count = pcall(function()
        return exports['job_police']:countOnDuty(jobName)
    end)
    if ok and count then return count end
    return 0
end

-- Ouvrir la liste des services
RegisterNetEvent('phone:openServices')
AddEventHandler('phone:openServices', function()
    local src = source
    local serviceList = {}
    for _, svc in ipairs(Config.Services) do
        local dutyCount = CountOnDutyForJob(svc.job)
        local statusText
        if dutyCount > 0 then
            statusText = 'En service (' .. dutyCount .. ')'
        else
            statusText = 'Personne n\'est en service'
        end
        table.insert(serviceList, {
            job = svc.job,
            label = svc.label,
            color = svc.color or '#5856d6',
            online = dutyCount > 0,
            statusText = statusText,
        })
    end
    TriggerClientEvent('phone:servicesList', src, serviceList)
end)

-- Appeler un service : notifier uniquement les joueurs EN SERVICE
RegisterNetEvent('phone:callService')
AddEventHandler('phone:callService', function(jobName, jobLabel)
    local src = source
    if activeCalls[src] then return end

    local callerName = GetPlayerRPName(src) or 'Inconnu'
    local myNumber = GetPlayerPhoneNumber(src)
    if not myNumber then return end

    -- Utiliser uniquement les joueurs EN SERVICE (pas tous ceux avec le job)
    local onDutyPlayers = {}
    local ok, result = pcall(function()
        return exports['job_police']:getOnDutyPlayers(jobName)
    end)
    if ok and result then
        onDutyPlayers = result
    end

    -- Filtrer : exclure l'appelant ET verifier que le joueur a bien le job demande (job1/job2)
    local jobLower = string.lower(jobName)
    local agents = {}
    for _, pid in ipairs(onDutyPlayers) do
        if pid ~= src then
            local ident = GetPlayerIdent(pid)
            if ident then
                local res = MySQL.query.await('SELECT job1, job2 FROM characters WHERE identifier = ?', {ident})
                if res and #res > 0 then
                    local j1 = res[1].job1 and string.lower(res[1].job1) or ''
                    local j2 = res[1].job2 and string.lower(res[1].job2) or ''
                    if j1 == jobLower or j2 == jobLower then
                        table.insert(agents, pid)
                    end
                end
            end
        end
    end

    if #agents == 0 then
        TriggerClientEvent('phone:callFailed', src, 'Aucun agent en service')
        return
    end

    -- Creer l'appel pour l'appelant
    activeCalls[src] = { target = nil, state = 'service_ringing', agents = agents }

    -- Creer les entrees activeCalls pour chaque agent et les notifier
    for _, pid in ipairs(agents) do
        activeCalls[pid] = { target = src, state = 'ringing' }
        TriggerClientEvent('phone:incomingServiceCall', pid, myNumber, callerName, jobLabel, src)
    end

    -- Confirmer a l'appelant que ca sonne
    TriggerClientEvent('phone:callRinging', src)
end)

-- Recuperer les messages d'un service
RegisterNetEvent('phone:getServiceMessages')
AddEventHandler('phone:getServiceMessages', function(jobName)
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier or not jobName then return end

    -- Verifier si le joueur est membre du job
    local isJobMember = false
    local jobResult = MySQL.query.await('SELECT job1, job2 FROM characters WHERE identifier = ?', {identifier})
    if jobResult and #jobResult > 0 then
        local j1 = jobResult[1].job1 and string.lower(jobResult[1].job1) or ''
        local j2 = jobResult[1].job2 and string.lower(jobResult[1].job2) or ''
        local jobLower = string.lower(jobName)
        if j1 == jobLower or j2 == jobLower then
            isJobMember = true
        end
    end

    local messages
    if isJobMember then
        -- Membre du job : voir tous les messages
        messages = MySQL.query.await(
            'SELECT * FROM service_messages WHERE job = ? ORDER BY created_at DESC LIMIT 50',
            {jobName})
    else
        -- Non-membre : voir uniquement ses propres messages
        messages = MySQL.query.await(
            'SELECT * FROM service_messages WHERE job = ? AND sender_identifier = ? ORDER BY created_at DESC LIMIT 50',
            {jobName, identifier})
    end

    -- Inverser pour avoir l'ordre chronologique
    local ordered = {}
    if messages then
        for i = #messages, 1, -1 do
            local msg = messages[i]
            msg.is_mine = (msg.sender_identifier == identifier)
            table.insert(ordered, msg)
        end
    end

    TriggerClientEvent('phone:serviceMessagesList', src, ordered)
end)

-- Envoyer un message a un service
RegisterNetEvent('phone:sendServiceMessage')
AddEventHandler('phone:sendServiceMessage', function(jobName, messageText)
    local src = source
    local identifier = GetPlayerIdent(src)
    if not identifier or not jobName or not messageText or messageText == '' then return end

    messageText = string.sub(messageText, 1, 500)
    local senderName = GetPlayerRPName(src)

    local insertId = MySQL.insert.await(
        'INSERT INTO service_messages (job, sender_identifier, sender_name, message) VALUES (?, ?, ?, ?)',
        {jobName, identifier, senderName, messageText})

    if insertId then
        TriggerClientEvent('phone:serviceMessageSent', src, true)

        -- Trouver le label du service pour la notification
        local serviceLabel = jobName
        for _, svc in ipairs(Config.Services) do
            if string.lower(svc.job) == string.lower(jobName) then
                serviceLabel = svc.label
                break
            end
        end

        -- Notifier tous les joueurs du job qui sont en ligne
        local players = GetPlayersWithJob(jobName)
        for _, pid in ipairs(players) do
            if pid ~= src then
                TriggerClientEvent('phone:newServiceMessage', pid, jobName, senderName, messageText, serviceLabel)
            end
        end

        -- Aussi rafraichir pour l'expediteur
        TriggerClientEvent('phone:refreshServiceChat', src, jobName)
    else
        TriggerClientEvent('phone:serviceMessageSent', src, false)
    end
end)
