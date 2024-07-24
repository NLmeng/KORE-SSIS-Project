USE [KoreAssignment_Lymeng_Naret]
GO

-- Select all rows from stg.Users
SELECT * 
FROM stg.Users;
GO


SELECT * 
FROM stg.Users_Errors;
GO


select *
from prod.Users;
go

-- Drop 
IF OBJECT_ID('stg.Users', 'U') IS NOT NULL
BEGIN
    DROP TABLE stg.Users;
END
GO

IF OBJECT_ID('stg.Users_Errors', 'U') IS NOT NULL
BEGIN
    DROP TABLE stg.Users_Errors;
END
GO

IF OBJECT_ID('prod.Users', 'U') IS NOT NULL
BEGIN
    DROP TABLE prod.Users;
END
GO

-- Recreate the stg.Users table
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

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'stg.Users_Errors') AND type in (N'U'))
BEGIN
CREATE TABLE stg.Users_Errors (
    StgID INT,
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
