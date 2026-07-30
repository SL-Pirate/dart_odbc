-- Test fixtures for the MariaDB integration suite.
--
-- Run automatically by the mariadb image via /docker-entrypoint-initdb.d/ on
-- first boot, inside the database named by MARIADB_DATABASE. That is why there
-- is no CREATE DATABASE and no USE statement here.
--
-- Identifiers are backtick-quoted and upper case to match PostgreSQL, so the
-- same test assertions ('UID', 'NAME', 'DATA') work against both engines. On
-- Linux, MariaDB defaults to lower_case_table_names=0, so table name case is
-- preserved and significant.

CREATE TABLE `USERS` (
    `UID`         INT          NOT NULL PRIMARY KEY,
    `NAME`        VARCHAR(150) NOT NULL,
    `DESCRIPTION` VARCHAR(500) NULL,
    `BIRTHDAY`    DATE         NULL
);

INSERT INTO `USERS` (`UID`, `NAME`, `DESCRIPTION`, `BIRTHDAY`)
VALUES
    (1, 'Alice', NULL, '1999-05-12'),
    (2, 'Bob',   NULL, '2000-12-05');

CREATE TABLE `BINARY_TABLE` (
    `ID`   INT            NOT NULL PRIMARY KEY,
    `DATA` VARBINARY(100) NOT NULL
);

INSERT INTO `BINARY_TABLE` (`ID`, `DATA`)
VALUES
    (1, 0x010203040506),
    (2, 0xDEADBEEF);
