-- ============================================================
--  POLICE JOB — SALARY SYSTEM
-- ============================================================

local function getIdentifier(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, 8) == 'license:' then return id end
    end
    return nil
end

-- Salaire automatique toutes les X minutes
CreateThread(function()
    local interval = (PoliceConfig.SalaryInterval or 30) * 60 * 1000

    while true do
        Citizen.Wait(interval)

        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local data = GetPoliceData(src)

            if data and data.on_duty then
                local identifier = getIdentifier(src)
                if identifier then
                    -- Recuperer le salaire actuel du grade
                    MySQL.query(
                        'SELECT pg.salary FROM police_officers po JOIN police_grades pg ON po.grade_id = pg.id WHERE po.identifier = ?',
                        { identifier },
                        function(rows)
                            if rows and rows[1] then
                                local salary = rows[1].salary or 0
                                if salary > 0 then
                                    -- Ajouter en banque
                                    MySQL.query(
                                        'UPDATE characters SET bank = bank + ? WHERE identifier = ?',
                                        { salary, identifier },
                                        function()
                                            TriggerClientEvent('police:salaryReceived', src, salary)
                                            TriggerClientEvent('police:notify', src,
                                                'Salaire recu : $' .. salary .. ' (vire en banque)', 'success')
                                        end
                                    )
                                end
                            end
                        end
                    )
                end
            end
        end
    end
end)

print('[PoliceJob] Salary system charge.')
