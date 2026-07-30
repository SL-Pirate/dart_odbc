-- Test fixtures for the PostgreSQL integration suite.
--
-- Run automatically by postgres:16-alpine via /docker-entrypoint-initdb.d/ on
-- first boot, inside the database named by POSTGRES_DB. That is why there is no
-- CREATE DATABASE and no database-switch statement here: the entrypoint creates
-- the database and connects to it before running this file.
--
-- Identifiers are QUOTED so PostgreSQL preserves their upper case. Unquoted
-- identifiers get folded to lower case, which would silently change every
-- returned column key from 'UID' to 'uid' and break the test assertions.
-- Consequence: queries must quote them too -- SELECT * FROM "USERS".

CREATE TABLE "USERS" (
    "UID"         INTEGER      NOT NULL PRIMARY KEY,
    "NAME"        VARCHAR(150) NOT NULL,
    "DESCRIPTION" VARCHAR(500),
    "BIRTHDAY"    DATE
);

INSERT INTO "USERS" ("UID", "NAME", "DESCRIPTION", "BIRTHDAY")
VALUES
    (1, 'Alice', NULL, DATE '1999-05-12'),
    (2, 'Bob',   NULL, DATE '2000-12-05');

CREATE TABLE "BINARY_TABLE" (
    "ID"   INTEGER NOT NULL PRIMARY KEY,
    "DATA" BYTEA   NOT NULL
);

INSERT INTO "BINARY_TABLE" ("ID", "DATA")
VALUES
    (1, '\x010203040506'::bytea),
    (2, '\xDEADBEEF'::bytea);
