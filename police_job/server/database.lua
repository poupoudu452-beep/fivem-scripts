-- ============================================================
--  POLICE JOB — DATABASE TABLES
-- ============================================================

CreateThread(function()
    -- Table des grades de police
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_grades` (
            `id`       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `name`     VARCHAR(50)  NOT NULL UNIQUE,
            `level`    INT UNSIGNED NOT NULL DEFAULT 1,
            `salary`   INT UNSIGNED NOT NULL DEFAULT 200
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Table des agents de police (lie identifier au grade)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_officers` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60)  NOT NULL UNIQUE,
            `grade_id`   INT UNSIGNED NOT NULL,
            `badge`      VARCHAR(20)  DEFAULT NULL,
            `on_duty`    TINYINT(1)   NOT NULL DEFAULT 0,
            `hired_at`   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`identifier`) REFERENCES `characters`(`identifier`)
                ON DELETE CASCADE ON UPDATE CASCADE,
            FOREIGN KEY (`grade_id`) REFERENCES `police_grades`(`id`)
                ON DELETE RESTRICT ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Table des amendes / factures
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_fines` (
            `id`              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `target_id`       VARCHAR(60)   NOT NULL,
            `officer_id`      VARCHAR(60)   NOT NULL,
            `amount`          INT UNSIGNED  NOT NULL,
            `reason`          VARCHAR(255)  NOT NULL DEFAULT 'Infraction',
            `paid`            TINYINT(1)    NOT NULL DEFAULT 0,
            `created_at`      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`target_id`) REFERENCES `characters`(`identifier`)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Compte en banque de l'entreprise police
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_company_bank` (
            `id`      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `balance` BIGINT NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Historique transactions du compte entreprise
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_company_transactions` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `type`       VARCHAR(20)  NOT NULL,
            `amount`     BIGINT       NOT NULL,
            `balance`    BIGINT       NOT NULL DEFAULT 0,
            `label`      VARCHAR(255) DEFAULT NULL,
            `officer_id` VARCHAR(60)  DEFAULT NULL,
            `date`       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Table prison (joueurs emprisonnes)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_jail` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60)  NOT NULL UNIQUE,
            `minutes`    INT UNSIGNED NOT NULL DEFAULT 5,
            `jailed_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`identifier`) REFERENCES `characters`(`identifier`)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Inserer les grades par defaut si la table est vide
    MySQL.query('SELECT COUNT(*) as cnt FROM `police_grades`', {}, function(rows)
        if rows and rows[1] and rows[1].cnt == 0 then
            for _, grade in ipairs(PoliceConfig.DefaultGrades) do
                MySQL.query(
                    'INSERT INTO `police_grades` (`name`, `level`, `salary`) VALUES (?, ?, ?)',
                    { grade.name, grade.level, grade.salary }
                )
            end
            print('[PoliceJob] Grades par defaut inseres.')
        end
    end)

    -- Creer le compte entreprise s'il n'existe pas
    MySQL.query('SELECT COUNT(*) as cnt FROM `police_company_bank`', {}, function(rows)
        if rows and rows[1] and rows[1].cnt == 0 then
            MySQL.query('INSERT INTO `police_company_bank` (`balance`) VALUES (0)')
            print('[PoliceJob] Compte entreprise cree.')
        end
    end)

    print('[PoliceJob] Tables de la base de donnees pretes.')
end)
