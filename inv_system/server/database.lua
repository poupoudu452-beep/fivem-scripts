-- server/database.lua

-- Création de la table inventaire liée aux personnages
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `character_inventory` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60)   NOT NULL,
            `slot`       TINYINT UNSIGNED NOT NULL,
            `item`       VARCHAR(60)   NOT NULL,
            `amount`     INT UNSIGNED NOT NULL DEFAULT 1,
            `metadata`   TEXT          DEFAULT NULL,
            UNIQUE KEY `uq_slot` (`identifier`, `slot`),
            FOREIGN KEY (`identifier`) REFERENCES `characters`(`identifier`)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    -- Mise à jour pour les tables existantes (SMALLINT → INT)
    MySQL.query([[
        ALTER TABLE `character_inventory` MODIFY COLUMN `amount` INT UNSIGNED NOT NULL DEFAULT 1;
    ]])
    -- Migration : ajouter la colonne metadata si elle n'existe pas
    MySQL.query([[
        ALTER TABLE `character_inventory` ADD COLUMN IF NOT EXISTS `metadata` TEXT DEFAULT NULL;
    ]])
end)

-- Charge l'inventaire d'un joueur depuis la BDD
-- @return table { [slot] = {item, amount, metadata} }
function DB_LoadInventory(identifier, cb)
    MySQL.query(
        'SELECT slot, item, amount, metadata FROM character_inventory WHERE identifier = ?',
        { identifier },
        function(rows)
            local inv = {}
            if rows then
                for _, row in ipairs(rows) do
                    local meta = nil
                    if row.metadata and row.metadata ~= '' then
                        local ok, decoded = pcall(json.decode, row.metadata)
                        if ok then meta = decoded end
                    end
                    inv[row.slot] = { item = row.item, amount = row.amount, metadata = meta }
                end
            end
            cb(inv)
        end
    )
end

-- Sauvegarde un slot unique (upsert)
function DB_SaveSlot(identifier, slot, item, amount, metadata)
    if amount <= 0 then
        MySQL.query(
            'DELETE FROM character_inventory WHERE identifier = ? AND slot = ?',
            { identifier, slot }
        )
    else
        local metaStr = nil
        if metadata then
            local ok, encoded = pcall(json.encode, metadata)
            if ok then metaStr = encoded end
        end
        MySQL.query(
            [[INSERT INTO character_inventory (identifier, slot, item, amount, metadata)
              VALUES (?, ?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE item = VALUES(item), amount = VALUES(amount), metadata = VALUES(metadata)]],
            { identifier, slot, item, amount, metaStr }
        )
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE INVENTAIRE VÉHICULE (coffre + boîte à gants)
-- ═══════════════════════════════════════════════════════════════════════════════
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `vehicle_inventory` (
            `id`           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `plate`        VARCHAR(12)   NOT NULL,
            `storage_type` VARCHAR(10)   NOT NULL DEFAULT 'trunk',
            `slot`         TINYINT UNSIGNED NOT NULL,
            `item`         VARCHAR(60)   NOT NULL,
            `amount`       INT UNSIGNED NOT NULL DEFAULT 1,
            `metadata`     TEXT          DEFAULT NULL,
            UNIQUE KEY `uq_veh_slot` (`plate`, `storage_type`, `slot`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

function DB_LoadVehicleInventory(plate, storageType, cb)
    MySQL.query(
        'SELECT slot, item, amount, metadata FROM vehicle_inventory WHERE plate = ? AND storage_type = ?',
        { plate, storageType },
        function(rows)
            local inv = {}
            if rows then
                for _, row in ipairs(rows) do
                    local meta = nil
                    if row.metadata and row.metadata ~= '' then
                        local ok, decoded = pcall(json.decode, row.metadata)
                        if ok then meta = decoded end
                    end
                    inv[row.slot] = { item = row.item, amount = row.amount, metadata = meta }
                end
            end
            cb(inv)
        end
    )
end

function DB_SaveVehicleInventory(plate, storageType, inventory)
    MySQL.query('DELETE FROM vehicle_inventory WHERE plate = ? AND storage_type = ?', { plate, storageType }, function()
        for slot, data in pairs(inventory) do
            if data and data.item and data.amount then
                local itemDef = Items and Items[data.item]
                local isWeapon = itemDef and itemDef.isWeapon
                if data.amount > 0 or isWeapon then
                    local metaStr = nil
                    if data.metadata then
                        local ok, encoded = pcall(json.encode, data.metadata)
                        if ok then metaStr = encoded end
                    end
                    MySQL.query(
                        [[INSERT INTO vehicle_inventory (plate, storage_type, slot, item, amount, metadata)
                          VALUES (?, ?, ?, ?, ?, ?)
                          ON DUPLICATE KEY UPDATE item = VALUES(item), amount = VALUES(amount), metadata = VALUES(metadata)]],
                        { plate, storageType, slot, data.item, data.amount, metaStr }
                    )
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE ARMES
-- ═══════════════════════════════════════════════════════════════════════════════
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `character_weapons` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60)   NOT NULL,
            `category`   VARCHAR(20)   NOT NULL,
            `weapon`     VARCHAR(60)   NOT NULL,
            `ammo`       INT UNSIGNED NOT NULL DEFAULT 0,
            UNIQUE KEY `uq_weapon_cat` (`identifier`, `category`),
            FOREIGN KEY (`identifier`) REFERENCES `characters`(`identifier`)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

function DB_LoadWeapons(identifier, cb)
    MySQL.query(
        'SELECT category, weapon, ammo FROM character_weapons WHERE identifier = ?',
        { identifier },
        function(rows)
            local weapons = {}
            if rows then
                for _, row in ipairs(rows) do
                    weapons[row.category] = { weapon = row.weapon, ammo = row.ammo }
                end
            end
            cb(weapons)
        end
    )
end

function DB_SaveWeapons(identifier, weapons)
    MySQL.query('DELETE FROM character_weapons WHERE identifier = ?', { identifier }, function()
        for category, data in pairs(weapons) do
            if data and data.weapon then
                MySQL.query(
                    [[INSERT INTO character_weapons (identifier, category, weapon, ammo)
                      VALUES (?, ?, ?, ?)
                      ON DUPLICATE KEY UPDATE weapon = VALUES(weapon), ammo = VALUES(ammo)]],
                    { identifier, category, data.weapon, data.ammo or 0 }
                )
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INVENTAIRE — Sauvegarde complète
-- ═══════════════════════════════════════════════════════════════════════════════

-- Sauvegarde tout l'inventaire d'un coup (ex: à la déconnexion)
function DB_SaveInventory(identifier, inventory)
    MySQL.query('DELETE FROM character_inventory WHERE identifier = ?', { identifier }, function()
        for slot, data in pairs(inventory) do
            if data and data.item and data.amount then
                -- Les armes utilisent amount pour les munitions (peut être 0).
                -- On les garde même avec 0 munitions pour ne pas perdre l'arme.
                local itemDef = Items and Items[data.item]
                local isWeapon = itemDef and itemDef.isWeapon
                if data.amount > 0 or isWeapon then
                    local metaStr = nil
                    if data.metadata then
                        local ok, encoded = pcall(json.encode, data.metadata)
                        if ok then metaStr = encoded end
                    end
                    MySQL.query(
                        [[INSERT INTO character_inventory (identifier, slot, item, amount, metadata)
                          VALUES (?, ?, ?, ?, ?)
                          ON DUPLICATE KEY UPDATE item = VALUES(item), amount = VALUES(amount), metadata = VALUES(metadata)]],
                        { identifier, slot, data.item, data.amount, metaStr }
                    )
                end
            end
        end
    end)
end
