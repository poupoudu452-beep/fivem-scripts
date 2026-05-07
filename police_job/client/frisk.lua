-- ============================================================
--  POLICE JOB — CLIENT FRISK (fouille)
-- ============================================================

-- ─── Geler / degeler un joueur ──────────────────────────────
RegisterNetEvent('police:freezePlayer')
AddEventHandler('police:freezePlayer', function(frozen)
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, frozen)
    if frozen then
        -- Animation mains en l'air
        RequestAnimDict('missminuteman_1ig_2')
        while not HasAnimDictLoaded('missminuteman_1ig_2') do
            Citizen.Wait(10)
        end
        TaskPlayAnim(playerPed, 'missminuteman_1ig_2', 'handsup_enter', 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        ClearPedTasks(playerPed)
    end
end)

print('[PoliceJob] Client frisk charge.')
