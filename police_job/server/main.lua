-- ============================================================
--  POLICE JOB — SERVER MAIN
-- ============================================================

local PoliceOfficers = {} -- [src] = { identifier, grade_name, grade_level, on_duty, badge }

-- ─── Utilitaire ─────────────────────────────────────────────
local function getIdentifier(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, 8) == 'license:' then return id end
    end
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, 6) == 'steam:' then return id end
    end
    return nil
end

-- ─── Charger les donnees police d'un joueur ─────────────────
function LoadPoliceData(src)
    local identifier = getIdentifier(src)
    if not identifier then return end

    MySQL.query([[
        SELECT po.identifier, po.grade_id, po.badge, po.on_duty,
               pg.name as grade_name, pg.level as grade_level, pg.salary
        FROM police_officers po
        JOIN police_grades pg ON po.grade_id = pg.id
        WHERE po.identifier = ?
    ]], { identifier }, function(rows)
        if rows and rows[1] then
            local row = rows[1]
            PoliceOfficers[src] = {
                identifier  = row.identifier,
                grade_name  = row.grade_name,
                grade_level = row.grade_level,
                salary      = row.salary,
                on_duty     = row.on_duty == 1,
                badge       = row.badge,
            }
            TriggerClientEvent('police:loadData', src, PoliceOfficers[src])
        end
    end)
end

-- ─── Connexion joueur ───────────────────────────────────────
AddEventHandler('playerConnecting', function()
    local src = source
    Citizen.SetTimeout(2000, function()
        LoadPoliceData(src)
    end)
end)

RegisterNetEvent('police:requestData')
AddEventHandler('police:requestData', function()
    local src = source
    if PoliceOfficers[src] then
        TriggerClientEvent('police:loadData', src, PoliceOfficers[src])
    else
        LoadPoliceData(src)
    end
end)

-- ─── Deconnexion joueur ─────────────────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    PoliceOfficers[src] = nil
end)

-- ─── Verifier si un joueur est police ───────────────────────
function IsPoliceOfficer(src)
    return PoliceOfficers[src] ~= nil
end

function IsCommander(src)
    local data = PoliceOfficers[src]
    return data and data.grade_name == PoliceConfig.CommanderGrade
end

function GetPoliceData(src)
    return PoliceOfficers[src]
end

-- ─── Toggle service (on/off duty) ──────────────────────────
RegisterNetEvent('police:toggleDuty')
AddEventHandler('police:toggleDuty', function()
    local src = source
    local data = PoliceOfficers[src]
    if not data then return end

    data.on_duty = not data.on_duty
    local dutyVal = data.on_duty and 1 or 0

    MySQL.query('UPDATE police_officers SET on_duty = ? WHERE identifier = ?',
        { dutyVal, data.identifier })

    TriggerClientEvent('police:dutyChanged', src, data.on_duty)
    TriggerClientEvent('police:notify', src,
        data.on_duty and 'Vous etes maintenant en service.' or 'Vous etes hors service.',
        data.on_duty and 'success' or 'warning')

    -- Notifier tous les policiers en ligne
    RefreshOnlineOfficers()
end)

-- ─── Liste des policiers en ligne ───────────────────────────
function GetOnlineOfficers()
    local officers = {}
    for src, data in pairs(PoliceOfficers) do
        officers[#officers + 1] = {
            id         = src,
            name       = GetPlayerName(src),
            grade_name = data.grade_name,
            grade_level= data.grade_level,
            on_duty    = data.on_duty,
            badge      = data.badge,
        }
    end
    return officers
end

function GetOnDutyOfficers()
    local officers = {}
    for src, data in pairs(PoliceOfficers) do
        if data.on_duty then
            officers[#officers + 1] = src
        end
    end
    return officers
end

function RefreshOnlineOfficers()
    local officers = GetOnlineOfficers()
    for src, _ in pairs(PoliceOfficers) do
        TriggerClientEvent('police:updateOfficers', src, officers)
    end
end

RegisterNetEvent('police:getOnlineOfficers')
AddEventHandler('police:getOnlineOfficers', function()
    local src = source
    if not IsPoliceOfficer(src) then return end
    TriggerClientEvent('police:updateOfficers', src, GetOnlineOfficers())
end)

-- ─── Recrutement ────────────────────────────────────────────
RegisterNetEvent('police:recruit')
AddEventHandler('police:recruit', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    if not IsCommander(src) then
        TriggerClientEvent('police:notify', src, 'Seul le Commandant peut recruter.', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        TriggerClientEvent('police:notify', src, 'Joueur introuvable.', 'error')
        return
    end

    local targetIdentifier = getIdentifier(targetId)
    if not targetIdentifier then
        TriggerClientEvent('police:notify', src, 'Identifiant du joueur introuvable.', 'error')
        return
    end

    -- Verifier si deja police
    MySQL.query('SELECT id FROM police_officers WHERE identifier = ?', { targetIdentifier }, function(rows)
        if rows and rows[1] then
            TriggerClientEvent('police:notify', src, 'Ce joueur est deja dans la police.', 'error')
            return
        end

        -- Trouver le grade Recrue
        MySQL.query('SELECT id FROM police_grades WHERE name = ?', { 'Recrue' }, function(gradeRows)
            if not gradeRows or not gradeRows[1] then
                TriggerClientEvent('police:notify', src, 'Grade Recrue introuvable en BDD.', 'error')
                return
            end
            local recrueId = gradeRows[1].id

            -- Inserer dans police_officers
            MySQL.query(
                'INSERT INTO police_officers (identifier, grade_id) VALUES (?, ?)',
                { targetIdentifier, recrueId },
                function()
                    -- Mettre a jour job1 dans characters
                    MySQL.query(
                        'UPDATE characters SET job1 = ? WHERE identifier = ?',
                        { PoliceConfig.JobName, targetIdentifier }
                    )

                    -- Charger les donnees pour le nouveau recrute
                    LoadPoliceData(targetId)

                    local targetName = GetPlayerName(targetId) or 'Inconnu'
                    TriggerClientEvent('police:notify', src,
                        targetName .. ' a ete recrute en tant que Recrue.', 'success')
                    TriggerClientEvent('police:notify', targetId,
                        'Vous avez ete recrute dans la Police en tant que Recrue !', 'success')

                    RefreshOnlineOfficers()
                end
            )
        end)
    end)
end)

-- ─── Renvoyer un agent ──────────────────────────────────────
RegisterNetEvent('police:fire')
AddEventHandler('police:fire', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    if not IsCommander(src) then
        TriggerClientEvent('police:notify', src, 'Seul le Commandant peut renvoyer.', 'error')
        return
    end

    local targetIdentifier = getIdentifier(targetId)
    if not targetIdentifier then return end

    MySQL.query('DELETE FROM police_officers WHERE identifier = ?', { targetIdentifier }, function()
        MySQL.query('UPDATE characters SET job1 = ? WHERE identifier = ?',
            { 'Chomage', targetIdentifier })

        PoliceOfficers[targetId] = nil
        TriggerClientEvent('police:fired', targetId)
        TriggerClientEvent('police:notify', targetId,
            'Vous avez ete renvoye de la Police.', 'error')
        TriggerClientEvent('police:notify', src,
            'Agent renvoye avec succes.', 'success')
        RefreshOnlineOfficers()
    end)
end)

-- ─── Promouvoir / changer de grade ──────────────────────────
RegisterNetEvent('police:setGrade')
AddEventHandler('police:setGrade', function(targetId, gradeName)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or not gradeName then return end
    if not IsCommander(src) then
        TriggerClientEvent('police:notify', src, 'Seul le Commandant peut changer les grades.', 'error')
        return
    end

    local targetIdentifier = getIdentifier(targetId)
    if not targetIdentifier then return end

    MySQL.query('SELECT id, name, level, salary FROM police_grades WHERE name = ?',
        { gradeName }, function(rows)
        if not rows or not rows[1] then
            TriggerClientEvent('police:notify', src, 'Grade introuvable.', 'error')
            return
        end
        local grade = rows[1]

        MySQL.query('UPDATE police_officers SET grade_id = ? WHERE identifier = ?',
            { grade.id, targetIdentifier }, function()
            -- Recharger les donnees
            LoadPoliceData(targetId)
            local targetName = GetPlayerName(targetId) or 'Inconnu'
            TriggerClientEvent('police:notify', src,
                targetName .. ' est maintenant ' .. grade.name .. '.', 'success')
            TriggerClientEvent('police:notify', targetId,
                'Vous avez ete promu au grade de ' .. grade.name .. ' !', 'success')
            RefreshOnlineOfficers()
        end)
    end)
end)

-- ─── Gestion des grades (ajouter / supprimer) ──────────────
RegisterNetEvent('police:addGrade')
AddEventHandler('police:addGrade', function(gradeName, gradeLevel, gradeSalary)
    local src = source
    if not IsCommander(src) then
        TriggerClientEvent('police:notify', src, 'Seul le Commandant peut gerer les grades.', 'error')
        return
    end

    gradeName   = tostring(gradeName or '')
    gradeLevel  = tonumber(gradeLevel) or 1
    gradeSalary = tonumber(gradeSalary) or 200

    if #gradeName < 2 then
        TriggerClientEvent('police:notify', src, 'Nom de grade invalide.', 'error')
        return
    end

    MySQL.query(
        'INSERT INTO police_grades (name, level, salary) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE level = VALUES(level), salary = VALUES(salary)',
        { gradeName, gradeLevel, gradeSalary },
        function()
            TriggerClientEvent('police:notify', src, 'Grade "' .. gradeName .. '" ajoute/mis a jour.', 'success')
            SendGradesToClient(src)
        end
    )
end)

RegisterNetEvent('police:removeGrade')
AddEventHandler('police:removeGrade', function(gradeName)
    local src = source
    if not IsCommander(src) then return end

    if gradeName == 'Recrue' or gradeName == PoliceConfig.CommanderGrade then
        TriggerClientEvent('police:notify', src, 'Impossible de supprimer ce grade.', 'error')
        return
    end

    MySQL.query('SELECT COUNT(*) as cnt FROM police_officers po JOIN police_grades pg ON po.grade_id = pg.id WHERE pg.name = ?',
        { gradeName }, function(rows)
        if rows and rows[1] and rows[1].cnt > 0 then
            TriggerClientEvent('police:notify', src, 'Des agents ont encore ce grade. Changez-les d\'abord.', 'error')
            return
        end

        MySQL.query('DELETE FROM police_grades WHERE name = ?', { gradeName }, function()
            TriggerClientEvent('police:notify', src, 'Grade "' .. gradeName .. '" supprime.', 'success')
            SendGradesToClient(src)
        end)
    end)
end)

-- ─── Modifier le salaire d'un grade ─────────────────────────
RegisterNetEvent('police:setSalary')
AddEventHandler('police:setSalary', function(gradeName, newSalary)
    local src = source
    if not IsCommander(src) then return end
    newSalary = tonumber(newSalary) or 0
    if newSalary < 0 then return end

    MySQL.query('UPDATE police_grades SET salary = ? WHERE name = ?',
        { newSalary, gradeName }, function()
        TriggerClientEvent('police:notify', src,
            'Salaire de "' .. gradeName .. '" mis a jour : $' .. newSalary, 'success')
        SendGradesToClient(src)
    end)
end)

-- ─── Envoyer la liste des grades au client ──────────────────
function SendGradesToClient(src)
    MySQL.query('SELECT id, name, level, salary FROM police_grades ORDER BY level ASC', {},
        function(rows)
            TriggerClientEvent('police:receiveGrades', src, rows or {})
        end
    )
end

RegisterNetEvent('police:requestGrades')
AddEventHandler('police:requestGrades', function()
    SendGradesToClient(source)
end)

-- ─── Joueurs a proximite (pour recrutement / amendes) ───────
RegisterNetEvent('police:getNearbyPlayers')
AddEventHandler('police:getNearbyPlayers', function()
    local src = source
    if not IsPoliceOfficer(src) then return end

    local myPed = GetPlayerPed(src)
    local myPos = GetEntityCoords(myPed)
    local nearby = {}

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid ~= src then
            local ped2 = GetPlayerPed(pid)
            local pos2 = GetEntityCoords(ped2)
            local dist = #(vector3(myPos.x, myPos.y, myPos.z) - vector3(pos2.x, pos2.y, pos2.z))
            if dist <= 10.0 then
                nearby[#nearby + 1] = {
                    id   = pid,
                    name = GetPlayerName(pid) or ('Joueur ' .. pid),
                    dist = math.floor(dist * 10) / 10,
                }
            end
        end
    end

    TriggerClientEvent('police:receiveNearbyPlayers', src, nearby)
end)

-- ─── Fouille / Frisk ────────────────────────────────────────
RegisterNetEvent('police:friskPlayer')
AddEventHandler('police:friskPlayer', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    if not IsPoliceOfficer(src) then return end

    local data = PoliceOfficers[src]
    if not data or not data.on_duty then
        TriggerClientEvent('police:notify', src, 'Vous devez etre en service.', 'error')
        return
    end

    -- Verifier la distance
    local myPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then return end

    local myPos = GetEntityCoords(myPed)
    local targetPos = GetEntityCoords(targetPed)
    local dist = #(vector3(myPos.x, myPos.y, myPos.z) - vector3(targetPos.x, targetPos.y, targetPos.z))
    if dist > PoliceConfig.FriskDistance then
        TriggerClientEvent('police:notify', src, 'Joueur trop loin.', 'error')
        return
    end

    -- Charger l'inventaire de la cible
    local targetInv = exports['inv_system']:getPlayerInventory(targetId)
    if not targetInv then
        TriggerClientEvent('police:notify', src, 'Inventaire inaccessible.', 'error')
        return
    end

    -- Geler la cible
    TriggerClientEvent('police:freezePlayer', targetId, true)
    TriggerClientEvent('police:notify', targetId, 'Vous etes fouille par un policier. Ne bougez pas.', 'warning')

    -- Envoyer l'inventaire au policier
    local serialized = {}
    for slot, d in pairs(targetInv) do
        serialized[tostring(slot)] = d
    end
    TriggerClientEvent('police:openFrisk', src, targetId, serialized)
end)

-- ─── Retirer un item pendant la fouille ─────────────────────
RegisterNetEvent('police:confiscateItem')
AddEventHandler('police:confiscateItem', function(targetId, slot, amount)
    local src = source
    targetId = tonumber(targetId)
    slot = tonumber(slot)
    amount = tonumber(amount)
    if not targetId or not slot or not amount then return end
    if not IsPoliceOfficer(src) then return end
    if amount <= 0 then return end

    local targetInv = exports['inv_system']:getPlayerInventory(targetId)
    if not targetInv or not targetInv[slot] then return end

    local data = targetInv[slot]
    local itemName = data.item
    local removeAmount = math.min(amount, data.amount)

    local ok = exports['inv_system']:RemoveItem(targetId, itemName, removeAmount)
    if ok then
        TriggerClientEvent('police:notify', src, 'x' .. removeAmount .. ' ' .. itemName .. ' confisque(s).', 'success')
        TriggerClientEvent('police:notify', targetId, 'Un policier vous a confisque x' .. removeAmount .. ' ' .. itemName .. '.', 'warning')

        -- Refresh l'inventaire de la cible pour le policier
        local newInv = exports['inv_system']:getPlayerInventory(targetId)
        local serialized = {}
        if newInv then
            for s, d in pairs(newInv) do
                serialized[tostring(s)] = d
            end
        end
        TriggerClientEvent('police:updateFriskInventory', src, serialized)
    end
end)

-- ─── Fin de la fouille ──────────────────────────────────────
RegisterNetEvent('police:endFrisk')
AddEventHandler('police:endFrisk', function(targetId)
    targetId = tonumber(targetId)
    if targetId then
        TriggerClientEvent('police:freezePlayer', targetId, false)
        TriggerClientEvent('police:notify', targetId, 'La fouille est terminee.', 'success')
    end
end)

-- ─── Menottage ──────────────────────────────────────────────
local HandcuffedPlayers = {} -- [targetId] = officerSrc

RegisterNetEvent('police:handcuff')
AddEventHandler('police:handcuff', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    if not IsPoliceOfficer(src) then return end

    local data = PoliceOfficers[src]
    if not data or not data.on_duty then
        TriggerClientEvent('police:notify', src, 'Vous devez etre en service.', 'error')
        return
    end

    if HandcuffedPlayers[targetId] then
        -- Demenotter
        HandcuffedPlayers[targetId] = nil
        TriggerClientEvent('police:setHandcuffed', targetId, false)
        TriggerClientEvent('police:notify', src, 'Joueur demenotte.', 'success')
        TriggerClientEvent('police:notify', targetId, 'Vous avez ete demenotte.', 'success')
    else
        -- Menotter
        HandcuffedPlayers[targetId] = src
        TriggerClientEvent('police:setHandcuffed', targetId, true)
        TriggerClientEvent('police:notify', src, 'Joueur menotte.', 'success')
        TriggerClientEvent('police:notify', targetId, 'Vous avez ete menotte par un policier.', 'warning')
    end
end)

-- ─── Escorter (drag) ────────────────────────────────────────
RegisterNetEvent('police:escort')
AddEventHandler('police:escort', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    if not IsPoliceOfficer(src) then return end
    if not HandcuffedPlayers[targetId] then
        TriggerClientEvent('police:notify', src, 'Le joueur doit etre menotte.', 'error')
        return
    end

    TriggerClientEvent('police:startEscort', targetId, src)
    TriggerClientEvent('police:notify', src, 'Vous escortez le joueur.', 'success')
end)

-- ─── Mettre / sortir du vehicule ────────────────────────────
RegisterNetEvent('police:putInVehicle')
AddEventHandler('police:putInVehicle', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    if not IsPoliceOfficer(src) then return end
    if not HandcuffedPlayers[targetId] then
        TriggerClientEvent('police:notify', src, 'Le joueur doit etre menotte.', 'error')
        return
    end

    TriggerClientEvent('police:enterVehicle', targetId, src)
end)

-- ─── Prison ─────────────────────────────────────────────────
RegisterNetEvent('police:jailPlayer')
AddEventHandler('police:jailPlayer', function(targetId, minutes)
    local src = source
    targetId = tonumber(targetId)
    minutes = tonumber(minutes) or 5
    if not targetId then return end
    if not IsPoliceOfficer(src) then return end
    if minutes < 1 then minutes = 1 end
    if minutes > PoliceConfig.MaxJailMinutes then minutes = PoliceConfig.MaxJailMinutes end

    local data = PoliceOfficers[src]
    if not data or not data.on_duty then
        TriggerClientEvent('police:notify', src, 'Vous devez etre en service.', 'error')
        return
    end

    local targetIdentifier = getIdentifier(targetId)
    if not targetIdentifier then return end

    -- Demenotter si menotte
    if HandcuffedPlayers[targetId] then
        HandcuffedPlayers[targetId] = nil
        TriggerClientEvent('police:setHandcuffed', targetId, false)
    end

    MySQL.query(
        'INSERT INTO police_jail (identifier, minutes) VALUES (?, ?) ON DUPLICATE KEY UPDATE minutes = ?, jailed_at = CURRENT_TIMESTAMP',
        { targetIdentifier, minutes, minutes },
        function()
            TriggerClientEvent('police:goToJail', targetId, minutes)
            TriggerClientEvent('police:notify', src,
                'Joueur emprisonne pour ' .. minutes .. ' minutes.', 'success')
            TriggerClientEvent('police:notify', targetId,
                'Vous avez ete emprisonne pour ' .. minutes .. ' minutes.', 'warning')
        end
    )
end)

-- ─── Liberation de prison ───────────────────────────────────
RegisterNetEvent('police:unjailPlayer')
AddEventHandler('police:unjailPlayer', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    if not IsPoliceOfficer(src) then return end

    local targetIdentifier = getIdentifier(targetId)
    if not targetIdentifier then return end

    MySQL.query('DELETE FROM police_jail WHERE identifier = ?', { targetIdentifier }, function()
        TriggerClientEvent('police:releaseFromJail', targetId)
        TriggerClientEvent('police:notify', src, 'Joueur libere.', 'success')
        TriggerClientEvent('police:notify', targetId, 'Vous avez ete libere de prison.', 'success')
    end)
end)

-- ─── Verifier prison a la connexion ─────────────────────────
RegisterNetEvent('police:checkJail')
AddEventHandler('police:checkJail', function()
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return end

    MySQL.query(
        'SELECT minutes, jailed_at FROM police_jail WHERE identifier = ?',
        { identifier },
        function(rows)
            if rows and rows[1] then
                local jailedAt = rows[1].jailed_at
                local minutes = rows[1].minutes
                -- Calculer le temps restant
                MySQL.query(
                    'SELECT TIMESTAMPDIFF(MINUTE, ?, NOW()) as elapsed',
                    { jailedAt },
                    function(timeRows)
                        if timeRows and timeRows[1] then
                            local elapsed = timeRows[1].elapsed or 0
                            local remaining = minutes - elapsed
                            if remaining > 0 then
                                TriggerClientEvent('police:goToJail', src, remaining)
                            else
                                -- Temps ecoule, liberer
                                MySQL.query('DELETE FROM police_jail WHERE identifier = ?', { identifier })
                            end
                        end
                    end
                )
            end
        end
    )
end)

-- ─── Fourriere ──────────────────────────────────────────────
RegisterNetEvent('police:impoundVehicle')
AddEventHandler('police:impoundVehicle', function()
    local src = source
    if not IsPoliceOfficer(src) then return end
    local data = PoliceOfficers[src]
    if not data or not data.on_duty then
        TriggerClientEvent('police:notify', src, 'Vous devez etre en service.', 'error')
        return
    end

    TriggerClientEvent('police:doImpound', src)
end)

-- ─── Herses ─────────────────────────────────────────────────
RegisterNetEvent('police:deploySpikeStrip')
AddEventHandler('police:deploySpikeStrip', function(coords, heading)
    local src = source
    if not IsPoliceOfficer(src) then return end
    -- Broadcast spike strip to all clients
    TriggerClientEvent('police:spawnSpikeStrip', -1, coords, heading, src)
end)

RegisterNetEvent('police:removeSpikeStrip')
AddEventHandler('police:removeSpikeStrip', function(netId)
    TriggerClientEvent('police:deleteSpikeStrip', -1, netId)
end)

-- ─── Go Fast Alert (recoit de go_fast) ──────────────────────
RegisterNetEvent('police:goFastAlert')
AddEventHandler('police:goFastAlert', function(vehicleNetId, coords)
    local onDuty = GetOnDutyOfficers()
    for _, officerSrc in ipairs(onDuty) do
        TriggerClientEvent('police:goFastAlertClient', officerSrc, vehicleNetId, coords)
    end
end)

-- ─── Mise a jour position go_fast pour le blip ──────────────
RegisterNetEvent('police:updateGoFastPosition')
AddEventHandler('police:updateGoFastPosition', function(coords)
    local onDuty = GetOnDutyOfficers()
    for _, officerSrc in ipairs(onDuty) do
        TriggerClientEvent('police:updateGoFastBlip', officerSrc, coords)
    end
end)

RegisterNetEvent('police:goFastEnded')
AddEventHandler('police:goFastEnded', function()
    local onDuty = GetOnDutyOfficers()
    for _, officerSrc in ipairs(onDuty) do
        TriggerClientEvent('police:removeGoFastBlip', officerSrc)
    end
end)

-- ─── Radar de vitesse ───────────────────────────────────────
RegisterNetEvent('police:speedCheck')
AddEventHandler('police:speedCheck', function(targetId, speed)
    local src = source
    if not IsPoliceOfficer(src) then return end
    local targetName = GetPlayerName(targetId) or ('Joueur ' .. targetId)
    TriggerClientEvent('police:notify', src,
        targetName .. ' roule a ' .. math.floor(speed) .. ' km/h', 'warning')
end)

-- ─── Radio police (chat) ────────────────────────────────────
RegisterNetEvent('police:radioMessage')
AddEventHandler('police:radioMessage', function(message)
    local src = source
    if not IsPoliceOfficer(src) then return end
    local data = PoliceOfficers[src]
    if not data or not data.on_duty then return end

    local senderName = GetPlayerName(src) or 'Inconnu'
    local formattedMsg = '[Radio Police] ' .. data.grade_name .. ' ' .. senderName .. ': ' .. message

    for officerSrc, officerData in pairs(PoliceOfficers) do
        if officerData.on_duty then
            TriggerClientEvent('police:radioReceive', officerSrc, formattedMsg, data.grade_name, senderName)
        end
    end
end)

-- ─── Commande Admin : /setjob1 [id] [job] [grade] ─────────
-- Modifie le job1 (entreprise legale) d'un joueur dans la BDD
RegisterCommand('setjob1', function(source, args)
    local src = source
    if src > 0 then
        -- Verifier si le joueur est admin ou commandant
        if not IsPlayerAceAllowed(src, 'command.setjob1') and not IsCommander(src) then
            TriggerClientEvent('police:notify', src, 'Vous n\'avez pas la permission.', 'error')
            return
        end
    end

    local targetId = tonumber(args[1])
    local jobName = args[2]
    local gradeName = args[3]

    if not targetId or not jobName then
        if src > 0 then
            TriggerClientEvent('police:notify', src, 'Usage: /setjob1 [id] [job] [grade]', 'error')
        else
            print('[PoliceJob] Usage: /setjob1 [id] [job] [grade]')
        end
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        if src > 0 then
            TriggerClientEvent('police:notify', src, 'Joueur ID ' .. targetId .. ' introuvable.', 'error')
        else
            print('[PoliceJob] Joueur ID ' .. targetId .. ' introuvable.')
        end
        return
    end

    local targetIdentifier = getIdentifier(targetId)
    if not targetIdentifier then return end

    -- Mettre a jour job1 dans la table characters
    MySQL.query('UPDATE characters SET job1 = ? WHERE identifier = ?',
        { jobName, targetIdentifier }, function(result)
        if result and result.affectedRows and result.affectedRows > 0 then
            local msg = 'Job1 de ' .. (GetPlayerName(targetId) or ('ID ' .. targetId)) .. ' => ' .. jobName
            if gradeName then
                msg = msg .. ' (grade: ' .. gradeName .. ')'
            end

            -- Si le job est Police, gerer l'insertion dans police_officers
            if jobName == PoliceConfig.JobName then
                local gradeToSet = gradeName or 'Recrue'
                MySQL.query('SELECT id FROM police_grades WHERE name = ?', { gradeToSet }, function(gradeRows)
                    if gradeRows and gradeRows[1] then
                        MySQL.query(
                            'INSERT INTO police_officers (identifier, grade_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE grade_id = ?',
                            { targetIdentifier, gradeRows[1].id, gradeRows[1].id },
                            function()
                                LoadPoliceData(targetId)
                                RefreshOnlineOfficers()
                            end
                        )
                    end
                end)
            else
                -- Si on retire du job Police, supprimer de police_officers
                MySQL.query('DELETE FROM police_officers WHERE identifier = ?', { targetIdentifier }, function()
                    if PoliceOfficers[targetId] then
                        PoliceOfficers[targetId] = nil
                        TriggerClientEvent('police:fired', targetId)
                        RefreshOnlineOfficers()
                    end
                end)
            end

            if src > 0 then
                TriggerClientEvent('police:notify', src, msg, 'success')
            else
                print('[PoliceJob] ' .. msg)
            end
            TriggerClientEvent('police:notify', targetId,
                'Votre job a ete modifie : ' .. jobName .. (gradeName and (' - ' .. gradeName) or ''), 'warning')
        else
            if src > 0 then
                TriggerClientEvent('police:notify', src, 'Echec : joueur introuvable en BDD.', 'error')
            else
                print('[PoliceJob] Echec : joueur introuvable en BDD.')
            end
        end
    end)
end, true) -- true = restricted (ace permission)

-- ─── Commande Admin : /setjob2 [id] [job] ─────────────────
-- Modifie le job2 (groupe illegal) d'un joueur dans la BDD
RegisterCommand('setjob2', function(source, args)
    local src = source
    if src > 0 then
        if not IsPlayerAceAllowed(src, 'command.setjob2') and not IsCommander(src) then
            TriggerClientEvent('police:notify', src, 'Vous n\'avez pas la permission.', 'error')
            return
        end
    end

    local targetId = tonumber(args[1])
    local jobName = args[2]

    if not targetId or not jobName then
        if src > 0 then
            TriggerClientEvent('police:notify', src, 'Usage: /setjob2 [id] [job]', 'error')
        else
            print('[PoliceJob] Usage: /setjob2 [id] [job]')
        end
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        if src > 0 then
            TriggerClientEvent('police:notify', src, 'Joueur ID ' .. targetId .. ' introuvable.', 'error')
        else
            print('[PoliceJob] Joueur ID ' .. targetId .. ' introuvable.')
        end
        return
    end

    local targetIdentifier = getIdentifier(targetId)
    if not targetIdentifier then return end

    -- Mettre a jour job2 dans la table characters
    MySQL.query('UPDATE characters SET job2 = ? WHERE identifier = ?',
        { jobName, targetIdentifier }, function(result)
        if result and result.affectedRows and result.affectedRows > 0 then
            local targetName = GetPlayerName(targetId) or ('ID ' .. targetId)
            local msg = 'Job2 de ' .. targetName .. ' => ' .. jobName

            if src > 0 then
                TriggerClientEvent('police:notify', src, msg, 'success')
            else
                print('[PoliceJob] ' .. msg)
            end
            TriggerClientEvent('police:notify', targetId,
                'Votre groupe a ete modifie : ' .. jobName, 'warning')
        else
            if src > 0 then
                TriggerClientEvent('police:notify', src, 'Echec : joueur introuvable en BDD.', 'error')
            else
                print('[PoliceJob] Echec : joueur introuvable en BDD.')
            end
        end
    end)
end, true) -- true = restricted (ace permission)

-- ─── Exports ────────────────────────────────────────────────
exports('IsPoliceOfficer', IsPoliceOfficer)
exports('IsCommander', IsCommander)
exports('GetPoliceData', GetPoliceData)
exports('GetOnDutyOfficers', GetOnDutyOfficers)
exports('GetOnlineOfficers', GetOnlineOfficers)

print('[PoliceJob] Server script charge.')
