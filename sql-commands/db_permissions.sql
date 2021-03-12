/*
==============================================================================
*  Creates database logins and sets permissions.
==============================================================================
*/

/*
------------------------------------------------------------------------------
  Setup variables
------------------------------------------------------------------------------
*/

--	DBName can be uncommented here to set the override value in the case that this script
--	is being run outside the SQLToolkit.
--:SETVAR DBName "DatabaseName"

-- SET NOCOUNT ON;

-- USE [master];

/*
------------------------------------------------------------------------------
  Add the server logins for admins and service accounts.
------------------------------------------------------------------------------
*/

-- Sample Active Directory Login: DOMAIN\USER
/*
IF (SUSER_ID('DOMAIN\USER') IS NULL) 
BEGIN 
	PRINT N'Adding [DOMAIN\USER] login...';
	CREATE LOGIN [DOMAIN\USER] FROM WINDOWS WITH DEFAULT_DATABASE = [master];
	
	PRINT N'Granting connect permission to [DOMAIN\USER] login...';
	GRANT CONNECT SQL TO [DOMAIN\USER]
	
	PRINT N'Adding [DOMAIN\USER] to sysadmin role...';
	EXEC sp_addsrvrolemember @loginame = N'DOMAIN\USER', @rolename = N'sysadmin'
END
*/

-- Sample SQL Server Login: SQLUser
/* 
IF (SUSER_ID('SQLUser') IS NULL) 
BEGIN 
	PRINT N'Adding [SQLUser] login...';
	CREATE LOGIN [SQLUser] WITH PASSWORD = 0x0200EB8DAA2D3F4A87AB61B0C2C9423843F061654F1503E1613371E794F7E39B39D337D539C44A0E229995FAC19D890E196BDB919B168AA6F1DBA8BC3E670E5A54F615C5C3F1 HASHED, SID = 0x0F46345A2B4383468CA52576BC9054FE, DEFAULT_DATABASE = [master], CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF; 

	PRINT N'Granting connect permission to [SQLUser] login...';
	GRANT CONNECT SQL TO [SQLUser]
END
 */

------------------------------------------------------------------------------

-- USE [$(DBName)]

/*
------------------------------------------------------------------------------
  Add logins to database.
------------------------------------------------------------------------------
*/

/* 
IF USER_ID('SQLUser') IS NULL
BEGIN 
	PRINT N'Adding [SQLUser] user...';
	CREATE USER [SQLUser] FOR LOGIN [SQLUser] WITH DEFAULT_SCHEMA=[dbo];
END	

PRINT N'Linking [SQLUser] login to database user [SQLUser]...';
EXEC dbo.sp_change_users_login 'update_one', 'SQLUser', 'SQLUser';

IF NOT EXISTS (SELECT * FROM sys.sysmembers WHERE USER_NAME([groupuid]) = N'db_datareader' AND USER_NAME(memberuid) = N'SQLUser')
BEGIN
	PRINT N'Adding [SQLUser] user to db_datareader role...';
	EXEC sp_addrolemember N'db_datareader', N'SQLUser';
END

IF NOT EXISTS (SELECT * FROM sys.sysmembers WHERE USER_NAME([groupuid]) = N'db_datawriter' AND USER_NAME(memberuid) = N'SQLUser')
BEGIN
	PRINT N'Adding [SQLUser] user to db_datawriter role...';
	EXEC sp_addrolemember N'db_datawriter', N'SQLUser';
END
*/

------------------------------------------------------------------------------


/*
------------------------------------------------------------------------------
  Grant execute permissions to user on Stored Procedures and user functions
------------------------------------------------------------------------------
*/

-- Stored Procedures
/* 
DECLARE @schemaowner AS sysname;
DECLARE @tmpArticleProcs TABLE([ProcName] sysname, [SchemaName] sysname)
INSERT INTO @tmpArticleProcs([ProcName], [SchemaName])
SELECT
	p.[name] AS [ProcName]
	,s.[name] AS [SchemaName]
FROM 
	[sys].[procedures] p
	INNER JOIN [sys].[schemas] s ON p.[schema_id] = s.[schema_id] 
WHERE 
	p.[is_ms_shipped] = 0
	AND p.[Type] = 'P'

DECLARE @CurrProc sysname
WHILE (SELECT COUNT(*) FROM @tmpArticleProcs) > 0
BEGIN
	SELECT TOP 1 
		@CurrProc = [ProcName],
        @schemaowner = [SchemaName]
	FROM @tmpArticleProcs

	IF (@ADuserFound = 1)
	BEGIN
		PRINT N'Granting execute permission to [SQLUser] on ['+ @schemaowner +'].['+ @CurrProc +']...';
		EXECUTE('GRANT EXECUTE ON OBJECT::['+ @schemaowner +'].['+ @CurrProc +'] TO [SQLUser] AS [dbo];');
	END

	DELETE FROM @tmpArticleProcs 
	WHERE [ProcName] = @CurrProc
END
 */

-- User Functions
/* 
DECLARE @tmpArticleFunc TABLE([FuncName] sysname, [SchemaName] sysname)
INSERT INTO @tmpArticleFunc([FuncName], [SchemaName])
SELECT 
	o.[name] AS [FuncName]
	,s.[name] AS [SchemaName]
FROM 
	[sys].[sql_modules] m 
	INNER JOIN [sys].[objects] o ON m.[object_id] = o.[object_id]
	INNER JOIN [sys].[schemas] s ON o.[schema_id] = s.[schema_id] 
WHERE 
	o.[type] = 'FN'
	AND o.[type_desc] LIKE '%function%'

DECLARE @CurrFunc sysname
WHILE (SELECT COUNT(*) FROM @tmpArticleFunc) > 0
BEGIN
	SELECT TOP 1 
		@CurrFunc = [FuncName],
        @schemaowner = [SchemaName]
	FROM @tmpArticleFunc

	IF (@ADuserFound = 1)
	BEGIN
		PRINT N'Granting execute permission to [SQLUser] on ['+ @schemaowner +'].['+ @CurrFunc +']...';
		EXECUTE('GRANT EXECUTE ON OBJECT::['+ @schemaowner +'].['+ @CurrFunc +'] TO [SQLUser] AS [dbo];');
	END
	

	DELETE FROM @tmpArticleFunc 
	WHERE [FuncName] = @CurrFunc
END
 */
 
------------------------------------------------------------------------------
