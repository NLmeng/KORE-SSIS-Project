IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'KoreAssignment_{Lymeng_Naret}')
BEGIN
	CREATE DATABASE [KoreAssignment_{Lymeng_Naret}];
END
GO

USE [KoreAssignment_{Lymeng_Naret}]
GO

-- Check and create stg schema if it does not exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'stg')
BEGIN
	EXEC('CREATE SCHEMA stg');
END
GO

-- Check and create prod schema if it does not exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'prod')
BEGIN
	EXEC('CREATE SCHEMA prod');
END
GO

-- Check and create stg.Users table if it does not exist
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'stg.Users') AND type in (N'U'))
BEGIN
CREATE TABLE stg.Users (
	StgID INT IDENTITY(1,1) PRIMARY KEY,
	UserID INT,
	FullName NVARCHAR(255),
	Age INT,
	Email NVARCHAR(255),
	RegistrationDate DATE,
	LastLoginDate DATE,
	PurchaseTotal FLOAT
	);
END
GO

-- Check and create prod.Users table if it does not exist
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'prod.Users') AND type in (N'U'))
BEGIN
CREATE TABLE prod.Users (
	ID INT IDENTITY(1,1) PRIMARY KEY,
	UserID INT,
	FullName NVARCHAR(255),
	Age INT,
	Email NVARCHAR(255),
	RegistrationDate DATE,
	LastLoginDate DATE,
	PurchaseTotal FLOAT,
	RecordLastUpdated DATETIME DEFAULT GETDATE()
	);
END
GO