-- client/weapons.lua
--
-- Gestion côté client des armes :
--   • Réception des armes depuis le serveur
--   • Raccourcis clavier 1-8 pour équiper/déséquiper
--   • Affichage de l'arme lourde dans le dos
--   • Synchronisation NUI
--
-- STANDALONE : ne dépend ni d'ESX ni de QBCore.
--

playerWeapons    = {}       -- { [category] = { weapon = 'WEAPON_...', ammo = n } }  (global : utilisé par main.lua et nui.lua)
equippedCategory = nil      -- catégorie actuellement équipée                      (global : utilisé par main.lua)
equippedWeaponName = nil    -- nom de l'arme actuellement en main                  (global : utilisé par nui.lua et main.lua)
equippedRealAmmo = 0        -- munitions réelles de l'arme en main                 (global : utilisé par main.lua)
local backPropHandle   = nil    -- handle du prop attaché dans le dos
local backWeaponName   = nil    -- nom de l'arme actuellement dans le dos
local backModelHash    = nil    -- hash du modèle du prop dans le dos
local weaponsLoaded    = false  -- true quand les armes ont été chargées depuis le serveur

-- Catégories qui affichent l'arme dans le dos quand non équipée
-- Tout sauf armes blanches (melee) et armes de poing (handgun)
local BACK_CATEGORIES = { smg = true, rifle = true, shotgun = true, sniper = true, heavy = true, thrown = true }

-- ─── Fonction helper ──────────────────────────────────────────────────────────
local function GetCategoryByIndex(index)
    if index >= 1 and index <= #WeaponCategories then
        return WeaponCategories[index]
    end
    return nil
end

-- ─── Enregistrer les touches 1-8 via RegisterKeyMapping ──────────────────────
-- Touches 1-5 : vérifient le hotbar NUI d'abord, puis fallback arme
-- Touches 6-8 : directement le système d'armes
for i = 1, #WeaponCategories do
    local cat = WeaponCategories[i]
    local cmdName = 'weapon_slot_' .. i

    RegisterCommand(cmdName, function()
        if i <= 5 then
            SendNUIMessage({ action = 'hotbarUse', slot = i })
        else
            ToggleWeaponSlot(i)
        end
    end, false)

    RegisterKeyMapping(
        cmdName,
        'Arme: ' .. cat.label .. ' [' .. i .. ']',
        'keyboard', tostring(i)
    )
end

-- ─── Animation d'équipement ───────────────────────────────────────────────────
local EQUIP_ANIMS = {
    melee   = { dict = 'melee@unarmed@streamed_core',       anim = 'heavy_finishing_punch', duration = 1200 },
    handgun = { dict = 'reaction@intimidation@1h',           anim = 'intro',                 duration = 1800 },
    smg     = { dict = 'reaction@intimidation@1h',           anim = 'intro',                 duration = 1800 },
    rifle   = { dict = 'reaction@intimidation@cop@unarmed',  anim = 'intro',                 duration = 2200 },
    shotgun = { dict = 'reaction@intimidation@cop@unarmed',  anim = 'intro',                 duration = 2200 },
    sniper  = { dict = 'reaction@intimidation@cop@unarmed',  anim = 'intro',                 duration = 2200 },
    heavy   = { dict = 'reaction@intimidation@cop@unarmed',  anim = 'intro',                 duration = 2500 },
    thrown  = { dict = 'reaction@intimidation@1h',           anim = 'intro',                 duration = 1400 },
}

local function PlayEquipAnimation(ped, category)
    local animData = EQUIP_ANIMS[category]
    if not animData then return end

    RequestAnimDict(animData.dict)
    local timeout = 2000
    while not HasAnimDictLoaded(animData.dict) and timeout > 0 do
        Wait(10)
        timeout = timeout - 10
    end
    if not HasAnimDictLoaded(animData.dict) then return end

    -- Animation upper body (flag 49 = upper body + contrôle joueur)
    TaskPlayAnim(ped, animData.dict, animData.anim, 6.0, -3.0, animData.duration, 49, 0, false, false, false)

    RemoveAnimDict(animData.dict)
end

-- ─── Nettoyage au démarrage et à l'arrêt de la ressource ─────────────────────
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupAllBackProps()
        RemoveAllPedWeapons(PlayerPedId(), true)
    end
end)

-- ─── Chargement initial des armes ─────────────────────────────────────────────
-- On attend que le joueur soit bien spawné (ped valide) puis on demande les armes.
-- Pas de dépendance à playerSpawned/spawnmanager.
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end
    Wait(2000)

    -- Nettoyer les props résiduels d'une session précédente
    CleanupAllBackProps()

    TriggerServerEvent('weapons:request')
    weaponsLoaded = true
end)

-- ─── Thread : empêcher le jeu de ranger l'arme quand ammo = 0 ────────────────
-- GTA5 switch automatiquement à WEAPON_UNARMED quand les munitions tombent à 0.
-- Ce thread re-force l'arme équipée pour que le joueur la garde en main.
-- On poll chaque frame (Wait(0)) pour réagir instantanément.
CreateThread(function()
    while true do
        Wait(0)
        if equippedCategory and equippedWeaponName then
            local ped = PlayerPedId()
            local weaponDef = Weapons[equippedWeaponName]
            if weaponDef then
                -- Sync ammo : lire les munitions réelles du ped
                local pedAmmo = GetAmmoInPedWeapon(ped, weaponDef.hash)

                -- Détecter quand le joueur tire et les ammo changent
                if equippedRealAmmo > 0 and pedAmmo <= 0 then
                    equippedRealAmmo = 0
                    local weaponData = playerWeapons[equippedCategory]
                    if weaponData and weaponData.weapon == equippedWeaponName then
                        weaponData.ammo = 0
                    end
                    TriggerServerEvent('weapons:updateAmmo', equippedCategory, 0)
                    SendWeaponsToNUI()
                    SendNUIMessage({ action = 'updateAmmoDisplay', weaponName = equippedWeaponName, ammo = 0 })
                elseif equippedRealAmmo > 0 and pedAmmo > 0 and pedAmmo ~= equippedRealAmmo then
                    equippedRealAmmo = pedAmmo
                    local weaponData = playerWeapons[equippedCategory]
                    if weaponData and weaponData.weapon == equippedWeaponName then
                        weaponData.ammo = pedAmmo
                    end
                    TriggerServerEvent('weapons:updateAmmo', equippedCategory, pedAmmo)
                    SendWeaponsToNUI()
                    SendNUIMessage({ action = 'updateAmmoDisplay', weaponName = equippedWeaponName, ammo = pedAmmo })
                end

                local currentHash = GetSelectedPedWeapon(ped)
                if currentHash ~= weaponDef.hash then
                    -- Le jeu a changé d'arme (ammo = 0), on re-force
                    GiveWeaponToPed(ped, weaponDef.hash, 0, false, true)
                    if equippedRealAmmo > 0 then
                        SetPedAmmo(ped, weaponDef.hash, equippedRealAmmo)
                    else
                        -- 1 munition fantôme dans le chargeur pour que GTA garde l'arme en main
                        SetPedAmmo(ped, weaponDef.hash, 1)
                        SetAmmoInClip(ped, weaponDef.hash, 1)
                    end
                    SetCurrentPedWeapon(ped, weaponDef.hash, true)
                end

                -- Bloquer le tir + rechargement si les vraies munitions sont à 0
                if equippedRealAmmo <= 0 then
                    DisableControlAction(0, 24, true)   -- INPUT_ATTACK
                    DisableControlAction(0, 45, true)   -- INPUT_RELOAD
                    DisableControlAction(0, 142, true)  -- INPUT_MELEE_ATTACK_ALTERNATE
                    DisablePlayerFiring(ped, true)
                    -- Forcer le chargeur plein pour empêcher l'auto-reload de GTA
                    SetAmmoInClip(ped, weaponDef.hash, 1)
                end
            end

            -- Sécurité : si un prop de dos existe alors qu'on a une arme en main, le supprimer
            if backPropHandle then
                CleanupAllBackProps()
            end
        end
    end
end)

-- ─── Équiper / Déséquiper une arme ────────────────────────────────────────────
function ToggleWeaponSlot(slotIndex)
    -- Ne pas gérer les raccourcis quand l'inventaire NUI est ouvert
    if isOpen then return end

    local cat = GetCategoryByIndex(slotIndex)
    if not cat then return end

    local weaponData = playerWeapons[cat.id]
    if not weaponData then return end

    local weaponDef = Weapons[weaponData.weapon]
    if not weaponDef then return end

    local ped = PlayerPedId()

    if equippedCategory == cat.id then
        -- Synchroniser les munitions réelles avant de déséquiper
        weaponData.ammo = equippedRealAmmo

        -- Déséquiper l'arme
        UnequipCurrentWeapon()
        ShowNotification('~o~' .. weaponDef.label .. ' ~w~rangée')
    else
        -- Déséquiper l'arme actuelle d'abord
        UnequipCurrentWeapon()

        -- Toujours retirer le prop du dos AVANT d'équiper
        CleanupAllBackProps()

        -- Équiper la nouvelle arme
        GiveWeaponToPed(ped, weaponDef.hash, 0, false, true)
        if weaponData.ammo > 0 then
            SetPedAmmo(ped, weaponDef.hash, weaponData.ammo)
        else
            SetPedAmmo(ped, weaponDef.hash, 1) -- fantôme, le thread bloquera le tir
            SetAmmoInClip(ped, weaponDef.hash, 1) -- dans le chargeur pour éviter l'auto-reload
        end
        SetCurrentPedWeapon(ped, weaponDef.hash, true)
        equippedCategory = cat.id
        equippedWeaponName = weaponData.weapon
        equippedRealAmmo = weaponData.ammo

        -- Animation stylée
        PlayEquipAnimation(ped, cat.id)

        ShowNotification('~g~' .. weaponDef.label .. ' ~w~équipée [' .. slotIndex .. '] (' .. weaponData.ammo .. ' mun.)')
    end

    -- Mettre à jour le NUI
    SendWeaponsToNUI()
end

function UnequipCurrentWeapon()
    if not equippedCategory then return end

    local ped = PlayerPedId()
    local prevCategory = equippedCategory
    local weaponData = playerWeapons[prevCategory]

    -- Marquer comme déséquipé AVANT d'attacher au dos
    -- (sinon AttachWeaponToBack voit l'arme encore équipée et refuse de créer le prop)
    equippedCategory = nil
    equippedWeaponName = nil
    local savedRealAmmo = equippedRealAmmo
    equippedRealAmmo = 0
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    if weaponData then
        local weaponDef = Weapons[weaponData.weapon]
        if weaponDef then
            -- Sauvegarder les munitions réelles (pas la fantôme)
            weaponData.ammo = savedRealAmmo
            TriggerServerEvent('weapons:updateAmmo', prevCategory, savedRealAmmo)

            -- Retirer l'arme du ped
            RemoveWeaponFromPed(ped, weaponDef.hash)
        end

        -- Remettre l'arme dans le dos si c'est une catégorie de dos
        if BACK_CATEGORIES[prevCategory] then
            AttachWeaponToBack(weaponData.weapon)
        end
    end
end

-- ─── Arme dans le dos ─────────────────────────────────────────────────────────
function AttachWeaponToBack(weaponName)
    RemoveBackProp()

    local modelName = WeaponBackModels[weaponName]
    if not modelName then return end

    -- Vérifier que l'arme n'est pas déjà équipée en main
    local weaponDef = Weapons[weaponName]
    if weaponDef and equippedCategory == weaponDef.category then return end

    local modelHash = GetHashKey(modelName)
    RequestModel(modelHash)

    local timeout = 5000
    while not HasModelLoaded(modelHash) and timeout > 0 do
        Wait(10)
        timeout = timeout - 10
    end

    if not HasModelLoaded(modelHash) then return end

    -- Re-vérifier après le chargement async du modèle
    if weaponDef and equippedCategory == weaponDef.category then
        SetModelAsNoLongerNeeded(modelHash)
        return
    end

    local ped = PlayerPedId()
    local boneIndex = GetPedBoneIndex(ped, 24818)  -- SKEL_Spine3

    -- Créer un prop LOCAL (non-networked) pour éviter les props fantômes
    local prop = CreateObject(modelHash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityCollision(prop, false, false)
    AttachEntityToEntity(
        prop, ped, boneIndex,
        -0.10, -0.22, 0.0,    -- offset X, Y, Z
        0.0, 180.0, -5.0,     -- rotation X, Y, Z
        false, true, false, false, 2, true
    )

    SetModelAsNoLongerNeeded(modelHash)
    backPropHandle = prop
    backWeaponName = weaponName
    backModelHash  = modelHash
end

function RemoveBackProp()
    -- Supprimer le prop connu
    if backPropHandle then
        if DoesEntityExist(backPropHandle) then
            SetEntityAsMissionEntity(backPropHandle, true, true)
            DetachEntity(backPropHandle, true, true)
            DeleteObject(backPropHandle)
        end
        if DoesEntityExist(backPropHandle) then
            DeleteEntity(backPropHandle)
        end
    end
    backPropHandle = nil
    backWeaponName = nil
    backModelHash  = nil
end

-- Nettoyage agressif : supprimer TOUS les objets armes attachés au joueur
function CleanupAllBackProps()
    RemoveBackProp()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for weaponName, modelName in pairs(WeaponBackModels) do
        local hash = GetHashKey(modelName)
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, hash, false, false, false)
        if obj and obj ~= 0 and IsEntityAttachedToEntity(obj, ped) then
            SetEntityAsMissionEntity(obj, true, true)
            DetachEntity(obj, true, true)
            DeleteObject(obj)
            if DoesEntityExist(obj) then
                DeleteEntity(obj)
            end
        end
    end
end

-- ─── Réception des armes depuis le serveur ────────────────────────────────────
RegisterNetEvent('weapons:receive', function(weapons)
    playerWeapons = weapons or {}

    -- Réappliquer l'arme dans le dos si on a des armes lourdes/fusils non équipées
    RemoveBackProp()
    for cat, data in pairs(playerWeapons) do
        if BACK_CATEGORIES[cat] and cat ~= equippedCategory then
            AttachWeaponToBack(data.weapon)
            break
        end
    end

    SendWeaponsToNUI()
end)

-- Quand une arme est donnée via /giveweapon
RegisterNetEvent('weapons:weaponGiven', function(weaponName, ammo)
    local weaponDef = Weapons[weaponName]
    if not weaponDef then return end

    local ped = PlayerPedId()

    -- Si l'arme est déjà équipée en main (même catégorie), forcer les munitions exactes
    if equippedCategory == weaponDef.category then
        SetPedAmmo(ped, weaponDef.hash, ammo)
    end

    -- Si le ped a l'arme (GTA peut la donner automatiquement), forcer les munitions
    if HasPedGotWeapon(ped, weaponDef.hash, false) and equippedCategory ~= weaponDef.category then
        SetPedAmmo(ped, weaponDef.hash, ammo)
    end

    -- Si c'est une arme lourde et qu'on ne l'a pas équipée, afficher dans le dos
    if BACK_CATEGORIES[weaponDef.category] and equippedCategory ~= weaponDef.category then
        RemoveBackProp()
        AttachWeaponToBack(weaponName)
    end
end)

-- ─── Envoyer au NUI pour affichage dans l'inventaire ──────────────────────────
function SendWeaponsToNUI()
    local weaponSlots = {}
    for i, cat in ipairs(WeaponCategories) do
        local data = playerWeapons[cat.id]
        local slot = {
            index    = i,
            category = cat.id,
            label    = cat.label,
            key      = tostring(i),
            icon     = cat.icon,
            equipped = (equippedCategory == cat.id),
        }
        if data then
            local weaponDef = Weapons[data.weapon]
            slot.weapon      = data.weapon
            slot.weaponLabel = weaponDef and weaponDef.label or data.weapon
            slot.ammo        = data.ammo
            slot.hasWeapon   = true
        else
            slot.hasWeapon = false
        end
        weaponSlots[i] = slot
    end

    SendNUIMessage({
        action      = 'updateWeapons',
        weaponSlots = weaponSlots,
    })
end

-- ─── NUI callback : équiper depuis l'UI (clic) ───────────────────────────────
RegisterNUICallback('equipWeapon', function(data, cb)
    local slotIndex = tonumber(data.slotIndex)
    if slotIndex then
        ToggleWeaponSlot(slotIndex)
    end
    cb('ok')
end)

-- ─── NUI callback : équiper depuis l'inventaire (drag & drop inv → slot arme)
RegisterNUICallback('equipWeaponFromInv', function(data, cb)
    local invSlot = tonumber(data.invSlot)
    if invSlot then
        TriggerServerEvent('weapons:equipFromInv', invSlot)
    end
    cb('ok')
end)

-- ─── NUI callback : équiper depuis le hotbar (touche 1-5 ou clic hotbar) ─────
-- Équipe/déséquipe l'arme directement sur le ped sans passer par le système de slots
local hotbarEquippedWeapon = nil

RegisterNUICallback('hotbarEquipWeapon', function(data, cb)
    local weaponName = data.weaponName
    local category = data.category
    local ammo = tonumber(data.ammo) or 1

    if not weaponName then cb('ok') return end

    local weaponDef = Weapons[weaponName]
    if not weaponDef then cb('ok') return end

    local ped = PlayerPedId()

    if hotbarEquippedWeapon == weaponName then
        -- Déséquiper l'arme
        RemoveWeaponFromPed(ped, weaponDef.hash)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        hotbarEquippedWeapon = nil
        equippedCategory = nil
        equippedWeaponName = nil
        equippedRealAmmo = 0
        CleanupAllBackProps()
        ShowNotification('~o~' .. weaponDef.label .. ' ~w~rangée')
    else
        -- Déséquiper l'arme actuelle d'abord
        if hotbarEquippedWeapon then
            local oldDef = Weapons[hotbarEquippedWeapon]
            if oldDef then
                RemoveWeaponFromPed(ped, oldDef.hash)
            end
        end
        if equippedCategory then
            UnequipCurrentWeapon()
        end
        CleanupAllBackProps()

        -- Équiper la nouvelle arme
        GiveWeaponToPed(ped, weaponDef.hash, 0, false, true)
        SetPedAmmo(ped, weaponDef.hash, ammo)
        SetCurrentPedWeapon(ped, weaponDef.hash, true)
        hotbarEquippedWeapon = weaponName
        equippedCategory = category

        equippedWeaponName = weaponName
        equippedRealAmmo = ammo

        -- Si ammo = 0, donner 1 munition fantôme pour garder l'arme en main
        if ammo <= 0 then
            SetPedAmmo(ped, weaponDef.hash, 1)
            SetAmmoInClip(ped, weaponDef.hash, 1) -- dans le chargeur pour éviter l'auto-reload
        end

        PlayEquipAnimation(ped, category)
        ShowNotification('~g~' .. weaponDef.label .. ' ~w~équipée (' .. ammo .. ' mun.)')
    end

    SendWeaponsToNUI()
    cb('ok')
end)

-- ─── NUI callback : ranger l'arme dans l'inventaire (drag & drop slot arme → inv)
RegisterNUICallback('unequipWeaponToInv', function(data, cb)
    local category = data.category
    if category and playerWeapons[category] then
        -- Déséquiper si c'est l'arme en main
        if equippedCategory == category then
            UnequipCurrentWeapon()
        end
        -- Toujours retirer du dos quand on range l'arme dans l'inventaire
        CleanupAllBackProps()
        -- Retirer l'arme du ped
        local weaponDef = Weapons[playerWeapons[category].weapon]
        if weaponDef then
            RemoveWeaponFromPed(PlayerPedId(), weaponDef.hash)
        end
        TriggerServerEvent('weapons:unequipToInv', category)
    end
    cb('ok')
end)

-- ─── NUI callback : fallback vers le système d'armes si hotbar vide ─────────
RegisterNUICallback('fallbackWeaponSlot', function(data, cb)
    local slotIndex = tonumber(data.slotIndex)
    if slotIndex then
        ToggleWeaponSlot(slotIndex)
    end
    cb('ok')
end)

RegisterNUICallback('dropWeapon', function(data, cb)
    local category = data.category
    if not category or not playerWeapons[category] then
        cb('ok')
        return
    end

    local weaponData = playerWeapons[category]
    local weaponDef = Weapons[weaponData.weapon]

    -- Déséquiper si équipée
    if equippedCategory == category then
        UnequipCurrentWeapon()
    end

    -- Retirer du dos
    CleanupAllBackProps()

    -- Retirer l'arme du ped
    if weaponDef then
        RemoveWeaponFromPed(PlayerPedId(), weaponDef.hash)
    end

    -- Informer le serveur
    playerWeapons[category] = nil
    TriggerServerEvent('weapons:removeWeapon', category)

    ShowNotification('~r~' .. (weaponDef and weaponDef.label or 'Arme') .. ' jetée')
    SendWeaponsToNUI()
    cb('ok')
end)

-- ─── Quand le serveur retire une arme du slot (unequipToInv) ──────────────────
RegisterNetEvent('weapons:weaponRemoved', function(category)
    if equippedCategory == category then
        local ped = PlayerPedId()
        local weaponData = playerWeapons[category]
        if weaponData then
            local weaponDef = Weapons[weaponData.weapon]
            if weaponDef then
                RemoveWeaponFromPed(ped, weaponDef.hash)
            end
        end
        equippedCategory = nil
        equippedWeaponName = nil
        equippedRealAmmo = 0
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    end
    CleanupAllBackProps()
end)
