-- ============================================================
--  PERMIS DE CONDUIRE — SERVER
--  Attribution du permis via inv_system
-- ============================================================

-- ─── Vérifier si le joueur a déjà le permis ─────────────────────────────────
RegisterNetEvent('driving:checkLicense')
AddEventHandler('driving:checkLicense', function()
    local src = source
    local has = false
    pcall(function()
        has = exports['inv_system']:HasItem(src, 'permis_conduire', 1)
    end)
    TriggerClientEvent('driving:licenseStatus', src, has == true)
end)

-- ─── Donner le permis ────────────────────────────────────────────────────────
RegisterNetEvent('driving:giveLicense')
AddEventHandler('driving:giveLicense', function()
    local src = source
    local playerName = GetPlayerName(src) or 'Inconnu'

    local hasLicense = false
    pcall(function()
        hasLicense = exports['inv_system']:HasItem(src, 'permis_conduire', 1)
    end)

    if hasLicense then
        return
    end

    local ok2, err2 = pcall(function()
        exports['inv_system']:addItemWithMetadata(src, 'permis_conduire', 1, {
            holder = playerName,
            date   = os.date('%d/%m/%Y'),
        })
    end)

    if not ok2 then
        print('[DrivingLicense] addItemWithMetadata failed : ' .. tostring(err2))
        pcall(function()
            TriggerEvent('inv:giveStarterItem', src, 'permis_conduire', 1)
        end)
    end

    TriggerClientEvent('driving:licenseStatus', src, true)
    print('[DrivingLicense] ' .. playerName .. ' (ID:' .. src .. ') PERMIS OBTENU')
end)

print('[DrivingLicense] Server chargé')
