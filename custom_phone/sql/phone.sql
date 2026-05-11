-- custom_phone : tables pour les contacts et messages

CREATE TABLE IF NOT EXISTS `phone_numbers` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(64) NOT NULL UNIQUE,
    `phone_number` VARCHAR(15) NOT NULL UNIQUE,
    `display_name` VARCHAR(64) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `phone_contacts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `owner_identifier` VARCHAR(64) NOT NULL,
    `contact_name` VARCHAR(64) NOT NULL,
    `contact_number` VARCHAR(15) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_owner` (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `phone_messages` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `sender_number` VARCHAR(15) NOT NULL,
    `receiver_number` VARCHAR(15) NOT NULL,
    `message` TEXT NOT NULL,
    `is_read` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_sender` (`sender_number`),
    INDEX `idx_receiver` (`receiver_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `service_messages` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `job` VARCHAR(50) NOT NULL,
    `sender_identifier` VARCHAR(60) NOT NULL,
    `sender_name` VARCHAR(100) NOT NULL,
    `message` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_job` (`job`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
