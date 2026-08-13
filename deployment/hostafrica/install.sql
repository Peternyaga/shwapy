-- Shwapy initial MySQL/MariaDB schema for installations without CLI access.
-- Import this file into the database configured by DB_DATABASE.
-- It does not drop tables or insert application users or secrets.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS `migrations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) NOT NULL,
  `batch` int NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `users` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `phone_number` varchar(12) NOT NULL,
  `google_id` varchar(255) DEFAULT NULL,
  `avatar_url` varchar(255) DEFAULT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `remember_token` varchar(100) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_email_unique` (`email`),
  UNIQUE KEY `users_phone_number_unique` (`phone_number`),
  UNIQUE KEY `users_google_id_unique` (`google_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `password_reset_tokens` (
  `email` varchar(255) NOT NULL,
  `token` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sessions` (
  `id` varchar(255) NOT NULL,
  `user_id` bigint unsigned DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text,
  `payload` longtext NOT NULL,
  `last_activity` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `sessions_user_id_index` (`user_id`),
  KEY `sessions_last_activity_index` (`last_activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cache` (
  `key` varchar(255) NOT NULL,
  `value` mediumtext NOT NULL,
  `expiration` int NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cache_locks` (
  `key` varchar(255) NOT NULL,
  `owner` varchar(255) NOT NULL,
  `expiration` int NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_locks_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `queue` varchar(255) NOT NULL,
  `payload` longtext NOT NULL,
  `attempts` tinyint unsigned NOT NULL,
  `reserved_at` int unsigned DEFAULT NULL,
  `available_at` int unsigned NOT NULL,
  `created_at` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `jobs_queue_index` (`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `job_batches` (
  `id` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `total_jobs` int NOT NULL,
  `pending_jobs` int NOT NULL,
  `failed_jobs` int NOT NULL,
  `failed_job_ids` longtext NOT NULL,
  `options` mediumtext,
  `cancelled_at` int DEFAULT NULL,
  `created_at` int NOT NULL,
  `finished_at` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `failed_jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) NOT NULL,
  `connection` text NOT NULL,
  `queue` text NOT NULL,
  `payload` longtext NOT NULL,
  `exception` longtext NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `personal_access_tokens` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) NOT NULL,
  `tokenable_id` bigint unsigned NOT NULL,
  `name` text NOT NULL,
  `token` varchar(64) NOT NULL,
  `abilities` text,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`),
  KEY `personal_access_tokens_expires_at_index` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `payment_accounts` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('paybill','till') NOT NULL,
  `paybill_no` varchar(255) DEFAULT NULL,
  `account_no` varchar(255) DEFAULT NULL,
  `till_no` varchar(255) DEFAULT NULL,
  `merchant_name` varchar(255) DEFAULT NULL,
  `created_by_user_id` bigint unsigned NOT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `payment_accounts_till_no_unique` (`till_no`),
  UNIQUE KEY `payment_accounts_paybill_no_account_no_unique` (`paybill_no`,`account_no`),
  KEY `payment_accounts_type_index` (`type`),
  KEY `payment_accounts_created_by_user_id_foreign` (`created_by_user_id`),
  CONSTRAINT `payment_accounts_created_by_user_id_foreign` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `transactions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `payment_account_id` bigint unsigned NOT NULL,
  `merchant_request_id` varchar(255) DEFAULT NULL,
  `checkout_request_id` varchar(255) DEFAULT NULL,
  `transaction_type` varchar(255) NOT NULL,
  `phone_number` varchar(12) NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `status` enum('pending','processing','success','failed','cancelled','timeout') NOT NULL DEFAULT 'pending',
  `extraction_confidence` decimal(5,4) DEFAULT NULL,
  `raw_extraction` json DEFAULT NULL,
  `raw_callback` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `transactions_checkout_request_id_unique` (`checkout_request_id`),
  KEY `transactions_user_id_foreign` (`user_id`),
  KEY `transactions_payment_account_id_foreign` (`payment_account_id`),
  KEY `transactions_merchant_request_id_index` (`merchant_request_id`),
  KEY `transactions_status_index` (`status`),
  CONSTRAINT `transactions_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `transactions_payment_account_id_foreign` FOREIGN KEY (`payment_account_id`) REFERENCES `payment_accounts` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `migrations` (`migration`, `batch`)
SELECT '0001_01_01_000000_create_users_table', 1
WHERE NOT EXISTS (SELECT 1 FROM `migrations` WHERE `migration` = '0001_01_01_000000_create_users_table');
INSERT INTO `migrations` (`migration`, `batch`)
SELECT '0001_01_01_000001_create_cache_table', 1
WHERE NOT EXISTS (SELECT 1 FROM `migrations` WHERE `migration` = '0001_01_01_000001_create_cache_table');
INSERT INTO `migrations` (`migration`, `batch`)
SELECT '0001_01_01_000002_create_jobs_table', 1
WHERE NOT EXISTS (SELECT 1 FROM `migrations` WHERE `migration` = '0001_01_01_000002_create_jobs_table');
INSERT INTO `migrations` (`migration`, `batch`)
SELECT '2026_05_10_112657_add_phone_number_to_users_table', 1
WHERE NOT EXISTS (SELECT 1 FROM `migrations` WHERE `migration` = '2026_05_10_112657_add_phone_number_to_users_table');
INSERT INTO `migrations` (`migration`, `batch`)
SELECT '2026_05_10_112657_create_personal_access_tokens_table', 1
WHERE NOT EXISTS (SELECT 1 FROM `migrations` WHERE `migration` = '2026_05_10_112657_create_personal_access_tokens_table');
INSERT INTO `migrations` (`migration`, `batch`)
SELECT '2026_05_10_112658_create_payment_accounts_table', 1
WHERE NOT EXISTS (SELECT 1 FROM `migrations` WHERE `migration` = '2026_05_10_112658_create_payment_accounts_table');
INSERT INTO `migrations` (`migration`, `batch`)
SELECT '2026_05_10_112658_create_transactions_table', 1
WHERE NOT EXISTS (SELECT 1 FROM `migrations` WHERE `migration` = '2026_05_10_112658_create_transactions_table');
INSERT INTO `migrations` (`migration`, `batch`)
SELECT '2026_05_22_000000_add_google_auth_fields_to_users_table', 1
WHERE NOT EXISTS (SELECT 1 FROM `migrations` WHERE `migration` = '2026_05_22_000000_add_google_auth_fields_to_users_table');

SET FOREIGN_KEY_CHECKS = 1;
