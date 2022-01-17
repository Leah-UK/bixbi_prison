USE `es_extended`;

ALTER TABLE `users` ADD COLUMN `bixbi_prison` longtext COLLATE utf8mb4_bin DEFAULT '{"time":0,"reason":"","officer":""}';