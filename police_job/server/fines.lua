-- ============================================================
--  POLICE JOB — FINES / TICKETS SYSTEM
-- ============================================================

local function getIdentifier(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, 8) == 'license:' then return id end
    end
    return nil
end

-- ─── Creer une amende ───────────────────────────────────────
RegisterNetEvent('police:createFine')
AddEventHandler('police:createFine', function(targetId, amount, reason)
    local src = source
    targetId = tonumber(targetId)
    amount   = tonumber(amount) or 0
    reason   = tostring(reason or 'Infraction')
    if not targetId or amount <= 0 then return end
    if not IsPoliceOfficer(src) then return end

    local data = GetPoliceData(src)
    if not data or not data.on_duty then
        TriggerClientEvent('police:notify', src, 'Vous devez etre en service.', 'error')
        return
    end

    if amount > PoliceConfig.MaxFineAmount then
        TriggerClientEvent('police:notify', src, 'Montant maximum : $' .. PoliceConfig.MaxFineAmount, 'error')
        return
    end

    local officerIdentifier = getIdentifier(src)
    local targetIdentifier  = getIdentifier(targetId)
    if not officerIdentifier or not targetIdentifier then return end

    MySQL.query(
        'INSERT INTO police_fines (target_id, officer_id, amount, reason) VALUES (?, ?, ?, ?)',
        { targetIdentifier, officerIdentifier, amount, reason },
        function(insertId)
            if insertId then
                local targetName  = GetPlayerName(targetId) or 'Inconnu'
                local officerName = GetPlayerName(src) or 'Inconnu'

                TriggerClientEvent('police:notify', src,
                    'Amende de $' .. amount .. ' envoyee a ' .. targetName .. '.', 'success')
                TriggerClientEvent('police:receiveFine', targetId, {
                    id     = insertId,
                    amount = amount,
                    reason = reason,
                    officer = officerName,
                })
                TriggerClientEvent('police:notify', targetId,
                    'Vous avez recu une amende de $' .. amount .. ' — Motif : ' .. reason, 'warning')
            end
        end
    )
end)

-- ─── Payer une amende ───────────────────────────────────────
RegisterNetEvent('police:payFine')
AddEventHandler('police:payFine', function(fineId)
    local src = source
    fineId = tonumber(fineId)
    if not fineId then return end

    local identifier = getIdentifier(src)
    if not identifier then return end

    MySQL.query(
        'SELECT id, amount, paid FROM police_fines WHERE id = ? AND target_id = ?',
        { fineId, identifier },
        function(rows)
            if not rows or not rows[1] then
                TriggerClientEvent('police:notify', src, 'Amende introuvable.', 'error')
                return
            end

            local fine = rows[1]
            if fine.paid == 1 then
                TriggerClientEvent('police:notify', src, 'Cette amende est deja payee.', 'error')
                return
            end

            local amount = fine.amount

            -- Verifier le solde en banque
            MySQL.query(
                'SELECT bank FROM characters WHERE identifier = ?',
                { identifier },
                function(charRows)
                    if not charRows or not charRows[1] then return end
                    local bank = charRows[1].bank or 0

                    if bank < amount then
                        TriggerClientEvent('police:notify', src,
                            'Solde insuffisant. Vous avez $' .. bank .. ', il faut $' .. amount .. '.', 'error')
                        return
                    end

                    -- Debiter le joueur
                    MySQL.query(
                        'UPDATE characters SET bank = bank - ? WHERE identifier = ? AND bank >= ?',
                        { amount, identifier, amount },
                        function(affected)
                            if not affected or affected == 0 then
                                TriggerClientEvent('police:notify', src, 'Erreur lors du paiement.', 'error')
                                return
                            end

                            -- Marquer l'amende comme payee
                            MySQL.query(
                                'UPDATE police_fines SET paid = 1 WHERE id = ?',
                                { fineId }
                            )

                            -- Crediter le compte entreprise police
                            MySQL.query(
                                'UPDATE police_company_bank SET balance = balance + ? WHERE id = 1',
                                { amount }
                            )

                            -- Enregistrer la transaction
                            MySQL.query(
                                'SELECT balance FROM police_company_bank WHERE id = 1',
                                {},
                                function(bankRows)
                                    local newBalance = (bankRows and bankRows[1] and bankRows[1].balance) or 0
                                    MySQL.query(
                                        'INSERT INTO police_company_transactions (type, amount, balance, label) VALUES (?, ?, ?, ?)',
                                        { 'fine', amount, newBalance, 'Amende #' .. fineId .. ' payee' }
                                    )
                                end
                            )

                            TriggerClientEvent('police:notify', src,
                                'Amende de $' .. amount .. ' payee avec succes.', 'success')
                            TriggerClientEvent('police:finePaid', src, fineId)
                        end
                    )
                end
            )
        end
    )
end)

-- ─── Recuperer les amendes non payees d'un joueur ───────────
RegisterNetEvent('police:getMyFines')
AddEventHandler('police:getMyFines', function()
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return end

    MySQL.query(
        'SELECT id, amount, reason, paid, created_at FROM police_fines WHERE target_id = ? ORDER BY created_at DESC LIMIT 20',
        { identifier },
        function(rows)
            TriggerClientEvent('police:receiveMyFines', src, rows or {})
        end
    )
end)

print('[PoliceJob] Fines system charge.')
