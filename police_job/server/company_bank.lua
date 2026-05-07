-- ============================================================
--  POLICE JOB — COMPANY BANK ACCOUNT
-- ============================================================

local function getIdentifier(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, 8) == 'license:' then return id end
    end
    return nil
end

-- ─── Ouvrir le compte entreprise ────────────────────────────
RegisterNetEvent('police:requestCompanyBank')
AddEventHandler('police:requestCompanyBank', function()
    local src = source
    if not IsCommander(src) then
        TriggerClientEvent('police:notify', src, 'Seul le Commandant peut acceder au compte.', 'error')
        return
    end

    MySQL.query('SELECT balance FROM police_company_bank WHERE id = 1', {}, function(rows)
        if not rows or not rows[1] then return end
        local balance = rows[1].balance or 0

        MySQL.query(
            'SELECT type, amount, balance, label, date FROM police_company_transactions ORDER BY date DESC LIMIT 30',
            {},
            function(txRows)
                TriggerClientEvent('police:receiveCompanyBank', src, {
                    balance      = balance,
                    transactions = txRows or {},
                })
            end
        )
    end)
end)

-- ─── Deposer de l'argent sur le compte entreprise ───────────
RegisterNetEvent('police:companyDeposit')
AddEventHandler('police:companyDeposit', function(amount)
    local src = source
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    if not IsCommander(src) then
        TriggerClientEvent('police:notify', src, 'Seul le Commandant peut effectuer cette operation.', 'error')
        return
    end

    local identifier = getIdentifier(src)
    if not identifier then return end

    -- Verifier l'argent en poche (item money)
    local totalMoney = exports['inv_system']:countItem(src, 'money')
    if totalMoney < amount then
        TriggerClientEvent('police:notify', src,
            'Pas assez d\'argent sur vous. ($' .. (totalMoney or 0) .. ' disponible)', 'error')
        return
    end

    -- Retirer du joueur
    local ok = exports['inv_system']:removeItem(src, 'money', amount)
    if not ok then
        TriggerClientEvent('police:notify', src, 'Erreur lors du retrait.', 'error')
        return
    end

    -- Crediter le compte entreprise
    MySQL.query('UPDATE police_company_bank SET balance = balance + ? WHERE id = 1', { amount }, function()
        MySQL.query('SELECT balance FROM police_company_bank WHERE id = 1', {}, function(rows)
            local newBalance = (rows and rows[1] and rows[1].balance) or 0
            MySQL.query(
                'INSERT INTO police_company_transactions (type, amount, balance, label, officer_id) VALUES (?, ?, ?, ?, ?)',
                { 'deposit', amount, newBalance, 'Depot par le Commandant', identifier }
            )
            TriggerClientEvent('police:notify', src, 'Depot de $' .. amount .. ' effectue.', 'success')
            -- Rafraichir
            TriggerServerEvent('police:requestCompanyBank')
            TriggerClientEvent('police:companyBankUpdated', src, newBalance)
        end)
    end)
end)

-- ─── Retirer de l'argent du compte entreprise ───────────────
RegisterNetEvent('police:companyWithdraw')
AddEventHandler('police:companyWithdraw', function(amount)
    local src = source
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    if not IsCommander(src) then
        TriggerClientEvent('police:notify', src, 'Seul le Commandant peut effectuer cette operation.', 'error')
        return
    end

    local identifier = getIdentifier(src)
    if not identifier then return end

    -- Retrait atomique
    MySQL.query(
        'UPDATE police_company_bank SET balance = balance - ? WHERE id = 1 AND balance >= ?',
        { amount, amount },
        function(affected)
            if not affected or affected == 0 then
                TriggerClientEvent('police:notify', src, 'Solde insuffisant sur le compte entreprise.', 'error')
                return
            end

            -- Donner l'argent au joueur
            TriggerEvent('inv:giveStarterItem', src, 'money', amount)

            MySQL.query('SELECT balance FROM police_company_bank WHERE id = 1', {}, function(rows)
                local newBalance = (rows and rows[1] and rows[1].balance) or 0
                MySQL.query(
                    'INSERT INTO police_company_transactions (type, amount, balance, label, officer_id) VALUES (?, ?, ?, ?, ?)',
                    { 'withdrawal', amount, newBalance, 'Retrait par le Commandant', identifier }
                )
                TriggerClientEvent('police:notify', src, 'Retrait de $' .. amount .. ' effectue.', 'success')
                TriggerClientEvent('police:companyBankUpdated', src, newBalance)
            end)
        end
    )
end)

print('[PoliceJob] Company bank system charge.')
