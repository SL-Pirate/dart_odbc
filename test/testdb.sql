CREATE DATABASE odbc_test;

------------------ Run the following commands seperately from the initial command

USE odbc_test;

CREATE TABLE USERS (
    UID INT NOT NULL PRIMARY KEY,
    NAME NVARCHAR(150) NOT NULL,
    DESCRIPTION NVARCHAR(500) NULL
);

INSERT INTO USERS (UID, NAME, DESCRIPTION)
VALUES
    (1, 'Alice', NULL),
    (2, 'Bob', NULL);

CREATE TABLE BINARY_TABLE (
    id INT NOT NULL PRIMARY KEY,
    data VARBINARY(100) NOT NULL
);

INSERT INTO BINARY_TABLE (id, data)
VALUES
    (1, 0x010203040506),
    (2, 0xDEADBEEF);
