-- ============================================================
--  CHARACTER CREATION — SERVER
-- ============================================================

local DEFAULT_SPAWN = { x = -1042.12, y = -2745.86, z = 21.36, heading = 0.0 }
local newlyCreated  = {}

-- ─── Création / migration de la table ─────────────────────────────────────
CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `characters` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60)   NOT NULL UNIQUE,
            `firstname`  VARCHAR(50)   NOT NULL,
            `lastname`   VARCHAR(50)   NOT NULL,
            `age`        TINYINT UNSIGNED NOT NULL DEFAULT 20,
            `height`     SMALLINT UNSIGNED NOT NULL DEFAULT 175,
            `gender`     VARCHAR(10)   NOT NULL DEFAULT 'male',
            `skin`       LONGTEXT      DEFAULT NULL,
            `appearance` LONGTEXT      DEFAULT NULL,
            `job1`       VARCHAR(50)   NOT NULL DEFAULT 'Chomage',
            `job2`       VARCHAR(50)   NOT NULL DEFAULT 'Chomage',
            `bank`       BIGINT        NOT NULL DEFAULT 0,
            `pos_x`      FLOAT NOT NULL DEFAULT 0,
            `pos_y`      FLOAT NOT NULL DEFAULT 0,
            `pos_z`      FLOAT NOT NULL DEFAULT 0,
            `pos_h`      FLOAT NOT NULL DEFAULT 0,
            `rank`       VARCHAR(50) NOT NULL DEFAULT 'Joueur',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function(ok)
        if ok ~= nil then
            print('[CharCreate] Table `characters` prete.')
        end
    end)

    -- Migrations colonnes
    exports.oxmysql:execute([[ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `skin` LONGTEXT DEFAULT NULL]], {}, function() end)
    exports.oxmysql:execute([[ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `appearance` LONGTEXT DEFAULT NULL]], {}, function() end)
    exports.oxmysql:execute([[ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `job1` VARCHAR(50) NOT NULL DEFAULT 'Chomage']], {}, function() end)
    exports.oxmysql:execute([[ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `job2` VARCHAR(50) NOT NULL DEFAULT 'Chomage']], {}, function() end)
    exports.oxmysql:execute([[ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `bank` BIGINT NOT NULL DEFAULT 0]], {}, function() end)
    exports.oxmysql:execute([[ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `rank` VARCHAR(50) NOT NULL DEFAULT 'Joueur']], {}, function() end)
end)

-- ─── Utilitaire : identifier un joueur ────────────────────────────────────
local function getIdentifier(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, 8) == 'license:' then return id end
    end
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, 6) == 'steam:' then return id end
    end
    return 'player:' .. GetPlayerName(source) .. '_' .. source
end

-- ─── Vérifier si le joueur a déjà un personnage ───────────────────────────
RegisterNetEvent('charCreate:checkCharacter')
AddEventHandler('charCreate:checkCharacter', function()
    local source = source
    local identifier = getIdentifier(source)

    exports.oxmysql:single(
        'SELECT * FROM `characters` WHERE `identifier` = ?',
        { identifier },
        function(row)
            if row then
                if row.appearance and row.appearance ~= '' then
                    row.appearance = json.decode(row.appearance)
                end
                if row.skin and row.skin ~= '' then
                    row.skin = json.decode(row.skin)
                end
                TriggerClientEvent('charCreate:showSelection', source, row)
            else
                TriggerClientEvent('charCreate:showCreation', source)
            end
        end
    )
end)

-- ─── Sauvegarder un nouveau personnage ────────────────────────────────────
RegisterNetEvent('charCreate:saveCharacter')
AddEventHandler('charCreate:saveCharacter', function(data)
    local source = source
    local identifier = getIdentifier(source)

    if type(data.firstname) ~= 'string' or #data.firstname < 2 or #data.firstname > 50 then
        TriggerClientEvent('charCreate:error', source, 'Prenom invalide.')
        return
    end
    if type(data.lastname) ~= 'string' or #data.lastname < 2 or #data.lastname > 50 then
        TriggerClientEvent('charCreate:error', source, 'Nom invalide.')
        return
    end

    local age    = math.max(18, math.min(80,  tonumber(data.age)    or 20))
    local height = math.max(150, math.min(220, tonumber(data.height) or 175))
    local gender = (data.gender == 'female') and 'female' or 'male'
    local job1   = Config.DefaultJob1 or 'Chomage'
    local job2   = Config.DefaultJob2 or 'Chomage'
    local bank   = Config.StarterBank or 0

    exports.oxmysql:insert(
        [[INSERT INTO `characters`
            (`identifier`,`firstname`,`lastname`,`age`,`height`,`gender`,`job1`,`job2`,`bank`,`pos_x`,`pos_y`,`pos_z`,`pos_h`)
          VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
          ON DUPLICATE KEY UPDATE
            `firstname`=VALUES(`firstname`), `lastname`=VALUES(`lastname`),
            `age`=VALUES(`age`), `height`=VALUES(`height`),
            `gender`=VALUES(`gender`)
        ]],
        {
            identifier,
            data.firstname, data.lastname,
            age, height, gender,
            job1, job2, bank,
            DEFAULT_SPAWN.x, DEFAULT_SPAWN.y, DEFAULT_SPAWN.z, DEFAULT_SPAWN.heading
        },
        function(insertId)
            if insertId then
                print(string.format('[CharCreate] Nouveau personnage — %s %s (%s) — %s',
                    data.firstname, data.lastname, gender, identifier))

                local charData = {
                    identifier = identifier,
                    firstname  = data.firstname,
                    lastname   = data.lastname,
                    age        = age,
                    height     = height,
                    gender     = gender,
                    job1       = job1,
                    job2       = job2,
                    bank       = bank,
                    appearance = nil,
                    pos_x      = DEFAULT_SPAWN.x,
                    pos_y      = DEFAULT_SPAWN.y,
                    pos_z      = DEFAULT_SPAWN.z,
                    pos_h      = DEFAULT_SPAWN.heading,
                }
                newlyCreated[source] = true
                TriggerClientEvent('charCreate:characterCreated', source, charData)
            else
                TriggerClientEvent('charCreate:error', source, 'Erreur lors de la sauvegarde.')
            end
        end
    )
end)

-- ─── Sauvegarder l'apparence complète ─────────────────────────────────────
RegisterNetEvent('charCreate:saveAppearance')
AddEventHandler('charCreate:saveAppearance', function(appearanceData)
    local source = source
    local identifier = getIdentifier(source)

    if type(appearanceData) ~= 'table' then return end

    exports.oxmysql:execute(
        'UPDATE `characters` SET `appearance`=? WHERE `identifier`=?',
        { json.encode(appearanceData), identifier },
        function()
            local ok, err = pcall(function()
                if newlyCreated[source] and Config and Config.GiveStarterItems and Config.StarterItems then
                    for _, entry in ipairs(Config.StarterItems) do
                        if entry.item and (entry.amount or 0) > 0 then
                            TriggerEvent('inv:giveStarterItem', source, entry.item, entry.amount)
                        end
                    end
                    newlyCreated[source] = nil
                    print('[CharCreate] Items de depart donnes au joueur ' .. source)
                end
            end)
            if not ok then
                print('[CharCreate] Erreur items de depart: ' .. tostring(err))
            end
            TriggerClientEvent('charCreate:appearanceSaved', source)
        end
    )
end)

-- ─── Sauvegarder le skin (legacy) ─────────────────────────────────────────
RegisterNetEvent('charCreate:saveSkin')
AddEventHandler('charCreate:saveSkin', function(skinData)
    local source = source
    local identifier = getIdentifier(source)
    if type(skinData) ~= 'table' then return end
    exports.oxmysql:execute(
        'UPDATE `characters` SET `skin`=? WHERE `identifier`=?',
        { json.encode(skinData), identifier },
        function() end
    )
end)

-- ─── Sauvegarder la position ──────────────────────────────────────────────
RegisterNetEvent('charCreate:savePosition')
AddEventHandler('charCreate:savePosition', function(x, y, z, h)
    local source = source
    local identifier = getIdentifier(source)
    exports.oxmysql:execute(
        'UPDATE `characters` SET `pos_x`=?, `pos_y`=?, `pos_z`=?, `pos_h`=? WHERE `identifier`=?',
        { x, y, z, h, identifier },
        function() end
    )
end)

-- ─── Sauvegarder la position à la déconnexion ─────────────────────────────
AddEventHandler('playerDropped', function(reason)
    local source = source
    newlyCreated[source] = nil
    local identifier = getIdentifier(source)
    local ped = GetPlayerPed(source)
    if DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        exports.oxmysql:execute(
            'UPDATE `characters` SET `pos_x`=?, `pos_y`=?, `pos_z`=?, `pos_h`=? WHERE `identifier`=?',
            { coords.x, coords.y, coords.z, heading, identifier },
            function() end
        )
    end
end)

-- ─── Salaire chômage toutes les X minutes ─────────────────────────────────
CreateThread(function()
    local interval = (Config.UnemploymentInterval or 30) * 60 * 1000
    while true do
        Citizen.Wait(interval)
        local pay     = Config.UnemploymentPay or 100
        local jobName = Config.UnemploymentJobName or 'Chomage'
        local msg     = Config.UnemploymentMessage or 'Gouvernement : %d$ verse pour votre chomage'

        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local identifier = getIdentifier(src)
            if identifier then
                exports.oxmysql:single(
                    'SELECT `job1`, `job2`, `bank` FROM `characters` WHERE `identifier` = ?',
                    { identifier },
                    function(row)
                        if row and (row.job1 == jobName or row.job2 == jobName) then
                            local newBank = (row.bank or 0) + pay
                            exports.oxmysql:execute(
                                'UPDATE `characters` SET `bank`=? WHERE `identifier`=?',
                                { newBank, identifier },
                                function()
                                    TriggerClientEvent('charCreate:unemploymentPay', src, pay, newBank, string.format(msg, pay))
                                end
                            )
                        end
                    end
                )
            end
        end
    end
end)

-- ─── Récupérer le solde banque ────────────────────────────────────────────
RegisterNetEvent('charCreate:getBank')
AddEventHandler('charCreate:getBank', function()
    local source = source
    local identifier = getIdentifier(source)
    exports.oxmysql:single(
        'SELECT `bank` FROM `characters` WHERE `identifier` = ?',
        { identifier },
        function(row)
            if row then
                TriggerClientEvent('charCreate:receiveBank', source, row.bank or 0)
            end
        end
    )
end)

print('[CharCreate] Server script charge.')
