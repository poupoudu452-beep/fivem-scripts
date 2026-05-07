-- ============================================================
--  POLICE JOB — CLIENT HUD
-- ============================================================

-- Mini HUD en haut a droite quand en service
CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsPolice and IsOnDuty and PlayerPoliceData then
            local baseX = 0.985
            local baseY = 0.15
            local boxW  = 0.14
            local boxH  = 0.065

            -- Fond
            DrawRect(baseX - boxW / 2, baseY + boxH / 2, boxW, boxH, 10, 15, 35, 210)

            -- Barre bleue en haut
            DrawRect(baseX - boxW / 2, baseY + 0.002, boxW, 0.004, 37, 99, 235, 255)

            -- Grade
            SetTextFont(4)
            SetTextScale(0.0, 0.28)
            SetTextColour(37, 99, 235, 255)
            SetTextDropshadow(1, 0, 0, 0, 200)
            SetTextEntry('STRING')
            SetTextJustification(2)
            SetTextWrap(0.0, baseX - 0.008)
            AddTextComponentString(PlayerPoliceData.grade_name or 'Police')
            DrawText(baseX - 0.008, baseY + 0.008)

            -- Statut
            SetTextFont(4)
            SetTextScale(0.0, 0.24)
            SetTextColour(34, 197, 94, 255)
            SetTextDropshadow(1, 0, 0, 0, 200)
            SetTextEntry('STRING')
            SetTextJustification(2)
            SetTextWrap(0.0, baseX - 0.008)
            AddTextComponentString('EN SERVICE')
            DrawText(baseX - 0.008, baseY + 0.035)
        else
            Citizen.Wait(1000)
        end
    end
end)

print('[PoliceJob] Client HUD charge.')
