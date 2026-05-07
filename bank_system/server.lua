-- ============================================================
--  BANK SYSTEM — SERVER
-- ============================================================

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

-- ─── Création tables ─────────────────────────────────────────────────────────
CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `bank_transactions` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60)  NOT NULL,
            `type`       VARCHAR(20)  NOT NULL,
            `amount`     BIGINT       NOT NULL,
            `balance`    BIGINT       NOT NULL DEFAULT 0,
            `date`       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        print('[BankSystem] Table `bank_transactions` prete.')
    end)
end)

-- ─── Ouvrir la banque : récupérer les données du compte ──────────────────
RegisterNetEvent('bank:requestData')
AddEventHandler('bank:requestData', function()
    local source = source
    local identifier = getIdentifier(source)

    exports.oxmysql:single(
        'SELECT `firstname`, `lastname`, `bank`, `created_at` FROM `characters` WHERE `identifier` = ?',
        { identifier },
        function(row)
            if not row then
                TriggerClientEvent('bank:notify', source, 'Aucun personnage trouve.', 'error')
                return
            end

            exports.oxmysql:fetch(
                'SELECT `type`, `amount`, `balance`, `date` FROM `bank_transactions` WHERE `identifier` = ? ORDER BY `date` DESC LIMIT 50',
                { identifier },
                function(transactions)
                    local totalDeposits    = 0
                    local totalWithdrawals = 0
                    for _, tx in ipairs(transactions or {}) do
                        if tx.type == 'deposit' then
                            totalDeposits = totalDeposits + tx.amount
                        elseif tx.type == 'withdrawal' then
                            totalWithdrawals = totalWithdrawals + tx.amount
                        end
                    end

                    local accountNum = string.upper(string.sub(identifier, 1, 12))

                    TriggerClientEvent('bank:receiveData', source, {
                        firstname        = row.firstname,
                        lastname         = row.lastname,
                        balance          = row.bank or 0,
                        totalDeposits    = totalDeposits,
                        totalWithdrawals = totalWithdrawals,
                        accountNumber    = accountNum,
                        createdAt        = row.created_at or 'Inconnu',
                        transactions     = transactions or {},
                    })
                end
            )
        end
    )
end)

-- ─── Dépôt : item money → banque ─────────────────────────────────────────
RegisterNetEvent('bank:deposit')
AddEventHandler('bank:deposit', function(amount)
    local source = source
    local identifier = getIdentifier(source)
    amount = tonumber(amount) or 0

    if amount <= 0 then
        TriggerClientEvent('bank:notify', source, 'Montant invalide.', 'error')
        return
    end

    -- Compter l'argent sur le joueur via export
    local ok, totalMoney = pcall(function()
        return exports['inv_system']:countItem(source, 'money')
    end)

    if not ok then
        TriggerClientEvent('bank:notify', source, 'Impossible de deposer : inventaire non disponible.', 'error')
        return
    end

    totalMoney = totalMoney or 0

    if totalMoney < amount then
        TriggerClientEvent('bank:notify', source, 'Impossible de deposer : pas assez d\'argent sur vous. ($' .. totalMoney .. ' disponible)', 'error')
        return
    end

    -- Retirer l'item money de l'inventaire via export (modifie directement PlayerInventories)
    local okRemove, removed = pcall(function()
        return exports['inv_system']:removeItem(source, 'money', amount)
    end)

    if not okRemove or not removed then
        TriggerClientEvent('bank:notify', source, 'Impossible de deposer : erreur lors du retrait.', 'error')
        return
    end

    -- Ajouter en banque (depot atomique)
    exports.oxmysql:execute(
        'UPDATE `characters` SET `bank` = `bank` + ? WHERE `identifier` = ?',
        { amount, identifier },
        function(affectedRows)
            if not affectedRows or affectedRows == 0 then return end

            exports.oxmysql:single(
                'SELECT `bank` FROM `characters` WHERE `identifier` = ?',
                { identifier },
                function(row)
                    if not row then return end
                    local newBank = row.bank or 0
                    exports.oxmysql:insert(
                        'INSERT INTO `bank_transactions` (`identifier`, `type`, `amount`, `balance`) VALUES (?, ?, ?, ?)',
                        { identifier, 'deposit', amount, newBank },
                        function()
                            refreshBankData(source, identifier)
                            TriggerClientEvent('bank:notify', source, 'Depot de $' .. amount .. ' effectue.', 'success')
                        end
                    )
                end
            )
        end
    )
end)

-- ─── Retrait : banque → item money ────────────────────────────────────────
RegisterNetEvent('bank:withdraw')
AddEventHandler('bank:withdraw', function(amount)
    local source = source
    local identifier = getIdentifier(source)
    amount = tonumber(amount) or 0

    if amount <= 0 then
        TriggerClientEvent('bank:notify', source, 'Montant invalide.', 'error')
        return
    end

    -- Retrait atomique : UPDATE uniquement si le solde est suffisant (empeche le negatif)
    exports.oxmysql:execute(
        'UPDATE `characters` SET `bank` = `bank` - ? WHERE `identifier` = ? AND `bank` >= ?',
        { amount, identifier, amount },
        function(affectedRows)
            if not affectedRows or affectedRows == 0 then
                -- Le solde etait insuffisant, on recupere le solde actuel pour le message
                exports.oxmysql:single(
                    'SELECT `bank` FROM `characters` WHERE `identifier` = ?',
                    { identifier },
                    function(row)
                        local currentBank = (row and row.bank) or 0
                        TriggerClientEvent('bank:notify', source, 'Impossible de retirer : solde insuffisant. ($' .. currentBank .. ' disponible)', 'error')
                    end
                )
                return
            end

            -- Recuperer le nouveau solde pour l'historique
            exports.oxmysql:single(
                'SELECT `bank` FROM `characters` WHERE `identifier` = ?',
                { identifier },
                function(row)
                    local newBank = (row and row.bank) or 0

                    -- Donner l'item money via l'event existant
                    TriggerEvent('inv:giveStarterItem', source, 'money', amount)

                    exports.oxmysql:insert(
                        'INSERT INTO `bank_transactions` (`identifier`, `type`, `amount`, `balance`) VALUES (?, ?, ?, ?)',
                        { identifier, 'withdrawal', amount, newBank },
                        function()
                            refreshBankData(source, identifier)
                            TriggerClientEvent('bank:notify', source, 'Retrait de $' .. amount .. ' effectue.', 'success')
                        end
                    )
                end
            )
        end
    )
end)

-- ─── Rafraîchir les données bancaires ─────────────────────────────────────
function refreshBankData(targetSource, identifier)
    exports.oxmysql:single(
        'SELECT `firstname`, `lastname`, `bank`, `created_at` FROM `characters` WHERE `identifier` = ?',
        { identifier },
        function(row)
            if not row then return end

            exports.oxmysql:fetch(
                'SELECT `type`, `amount`, `balance`, `date` FROM `bank_transactions` WHERE `identifier` = ? ORDER BY `date` DESC LIMIT 50',
                { identifier },
                function(transactions)
                    local totalDeposits    = 0
                    local totalWithdrawals = 0
                    for _, tx in ipairs(transactions or {}) do
                        if tx.type == 'deposit' then
                            totalDeposits = totalDeposits + tx.amount
                        elseif tx.type == 'withdrawal' then
                            totalWithdrawals = totalWithdrawals + tx.amount
                        end
                    end

                    local accountNum = string.upper(string.sub(identifier, 1, 12))

                    TriggerClientEvent('bank:receiveData', targetSource, {
                        firstname        = row.firstname,
                        lastname         = row.lastname,
                        balance          = row.bank or 0,
                        totalDeposits    = totalDeposits,
                        totalWithdrawals = totalWithdrawals,
                        accountNumber    = accountNum,
                        createdAt        = row.created_at or 'Inconnu',
                        transactions     = transactions or {},
                    })
                end
            )
        end
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
--  ENTREPRISE : compte bancaire d'entreprise (intégré dans bank_system)
-- ═══════════════════════════════════════════════════════════════════════════

-- Helper : vérifier si le joueur est commandant/gérant d'une entreprise
local function getCompanyInfo(source)
    local identifier = getIdentifier(source)
    -- Vérifier si le joueur a un job1 qui correspond à une entreprise avec compte
    local row = exports.oxmysql:single_async(
        'SELECT `job1` FROM `characters` WHERE `identifier` = ?',
        { identifier }
    )
    if not row or not row.job1 or row.job1 == '' or row.job1 == 'Chomage' then
        return nil
    end

    local jobName = row.job1

    -- Vérifier si le joueur est commandant/gérant via police_job ou autre système
    local isCommander = false
    local ok, val = pcall(function()
        return exports['police_job']:IsCommanderServer(source)
    end)
    if ok and val then
        isCommander = true
    end

    if not isCommander then return nil end

    return { jobName = jobName, identifier = identifier }
end

-- Récupérer les données du compte entreprise
RegisterNetEvent('bank:requestCompanyData')
AddEventHandler('bank:requestCompanyData', function()
    local source = source
    local company = getCompanyInfo(source)

    if not company then
        TriggerClientEvent('bank:receiveCompanyData', source, nil)
        return
    end

    local jobName = company.jobName

    -- Chercher le compte entreprise dans police_company_bank
    exports.oxmysql:single(
        'SELECT `balance` FROM `police_company_bank` WHERE `id` = 1',
        {},
        function(bankRow)
            local balance = (bankRow and bankRow.balance) or 0

            -- Récupérer les transactions entreprise
            exports.oxmysql:fetch(
                'SELECT `type`, `amount`, `description`, `date` FROM `police_company_transactions` ORDER BY `date` DESC LIMIT 50',
                {},
                function(transactions)
                    TriggerClientEvent('bank:receiveCompanyData', source, {
                        jobName      = jobName,
                        balance      = balance,
                        transactions = transactions or {},
                    })
                end
            )
        end
    )
end)

-- Dépôt sur le compte entreprise
RegisterNetEvent('bank:companyDeposit')
AddEventHandler('bank:companyDeposit', function(amount)
    local source = source
    local company = getCompanyInfo(source)
    if not company then
        TriggerClientEvent('bank:notify', source, 'Acces refuse.', 'error')
        return
    end

    amount = tonumber(amount) or 0
    if amount <= 0 then
        TriggerClientEvent('bank:notify', source, 'Montant invalide.', 'error')
        return
    end

    -- Vérifier l'argent sur le joueur
    local ok, totalMoney = pcall(function()
        return exports['inv_system']:countItem(source, 'money')
    end)
    if not ok then totalMoney = 0 end
    totalMoney = totalMoney or 0

    if totalMoney < amount then
        TriggerClientEvent('bank:notify', source, 'Pas assez d\'argent sur vous. ($' .. totalMoney .. ' disponible)', 'error')
        return
    end

    -- Retirer l'argent du joueur
    local okRemove, removed = pcall(function()
        return exports['inv_system']:removeItem(source, 'money', amount)
    end)
    if not okRemove or not removed then
        TriggerClientEvent('bank:notify', source, 'Erreur lors du retrait.', 'error')
        return
    end

    -- Ajouter au compte entreprise
    exports.oxmysql:execute(
        'UPDATE `police_company_bank` SET `balance` = `balance` + ? WHERE `id` = 1',
        { amount },
        function()
            -- Logger la transaction
            local playerName = GetPlayerName(source) or 'Inconnu'
            exports.oxmysql:insert(
                'INSERT INTO `police_company_transactions` (`type`, `amount`, `author`, `description`) VALUES (?, ?, ?, ?)',
                { 'deposit', amount, playerName, 'Depot par ' .. playerName }
            )
            TriggerClientEvent('bank:notify', source, 'Depot de $' .. amount .. ' sur le compte entreprise.', 'success')
            -- Rafraîchir les données
            TriggerEvent('bank:requestCompanyData_internal', source)
        end
    )
end)

-- Retrait du compte entreprise
RegisterNetEvent('bank:companyWithdraw')
AddEventHandler('bank:companyWithdraw', function(amount)
    local source = source
    local company = getCompanyInfo(source)
    if not company then
        TriggerClientEvent('bank:notify', source, 'Acces refuse.', 'error')
        return
    end

    amount = tonumber(amount) or 0
    if amount <= 0 then
        TriggerClientEvent('bank:notify', source, 'Montant invalide.', 'error')
        return
    end

    -- Retrait atomique
    exports.oxmysql:execute(
        'UPDATE `police_company_bank` SET `balance` = `balance` - ? WHERE `id` = 1 AND `balance` >= ?',
        { amount, amount },
        function(affectedRows)
            if not affectedRows or affectedRows == 0 then
                TriggerClientEvent('bank:notify', source, 'Solde entreprise insuffisant.', 'error')
                return
            end

            -- Donner l'argent au joueur
            TriggerEvent('inv:giveStarterItem', source, 'money', amount)

            local playerName = GetPlayerName(source) or 'Inconnu'
            exports.oxmysql:insert(
                'INSERT INTO `police_company_transactions` (`type`, `amount`, `author`, `description`) VALUES (?, ?, ?, ?)',
                { 'withdrawal', amount, playerName, 'Retrait par ' .. playerName }
            )
            TriggerClientEvent('bank:notify', source, 'Retrait de $' .. amount .. ' du compte entreprise.', 'success')
            TriggerEvent('bank:requestCompanyData_internal', source)
        end
    )
end)

-- Event interne pour rafraîchir les données entreprise
AddEventHandler('bank:requestCompanyData_internal', function(targetSource)
    exports.oxmysql:single(
        'SELECT `balance` FROM `police_company_bank` WHERE `id` = 1',
        {},
        function(bankRow)
            local balance = (bankRow and bankRow.balance) or 0
            exports.oxmysql:fetch(
                'SELECT `type`, `amount`, `description`, `date` FROM `police_company_transactions` ORDER BY `date` DESC LIMIT 50',
                {},
                function(transactions)
                    -- Récupérer le nom du job
                    local identifier = getIdentifier(targetSource)
                    local charRow = exports.oxmysql:single_async(
                        'SELECT `job1` FROM `characters` WHERE `identifier` = ?',
                        { identifier }
                    )
                    TriggerClientEvent('bank:receiveCompanyData', targetSource, {
                        jobName      = (charRow and charRow.job1) or 'Entreprise',
                        balance      = balance,
                        transactions = transactions or {},
                    })
                end
            )
        end
    )
end)

print('[BankSystem] Server script charge.')
