USE [$(DBName)];
GO

-- Check if merge publication is configured
IF OBJECT_ID(N'[dbo].[sysmergepublications]', 'U') IS NOT NULL
BEGIN

	PRINT N'Merge publication detected...'

	-- Drops a merge publication and its associated Snapshot Agent
	PRINT N'Dropping merge publication and associated snapshot agent...'
	EXEC sp_dropmergepublication 
		@publication = N'$(DBName)Merge'

	-- Removes all replication objects on the publication database on the Publisher instance of SQL Server 
	-- or on the subscription database on the Subscriber instance of SQL Server
	PRINT N'Removing all replication objects from DB...'
	USE [master]
	EXEC sp_removedbreplication 
		@dbname = N'$(DBName)',
		@type = N'merge'

	PRINT N'Disable publication of the current database using merge replication.'
	USE [master]
	EXEC sp_replicationdboption 
	@dbname = N'$(DBName)', 
	@optname = N'merge publish', 
	@value = N'false'

END
GO

USE [$(DBName)];
GO

----- BEGIN: Remove articles from a merge publication. -----
DECLARE @tmpArticleTables TABLE([TableName] sysname, [SchemaName] sysname, [IsIdentity] bit)
INSERT INTO @tmpArticleTables([TableName], [SchemaName], [IsIdentity])
SELECT 
	 t.[name] AS [TableName]
	,s.[name] AS [SchemaName]
	,CASE 
		WHEN SUM(CAST(c.[is_identity] AS int)) > 0 THEN CAST(1 AS bit) 
		ELSE CAST(0 AS bit) 
	END AS [IsIdentity]
FROM 
	[sys].[tables] t 
	INNER JOIN [sys].[schemas] s ON t.[schema_id] = s.[schema_id] 
	INNER JOIN [sys].[columns] c ON c.[object_id] = t.[object_id]
WHERE 
	[is_ms_shipped] = 0 
	--AND NOT t.[name] IN ('__MigrationHistory') 
	AND s.[name] = 'dbo' 
GROUP BY 
	t.[name]
	,s.[name]

DECLARE @CurrTable sysname
WHILE (SELECT COUNT(*) FROM @tmpArticleTables) > 0
BEGIN
	SELECT TOP 1 @CurrTable = [TableName] FROM @tmpArticleTables

	-- Removes an article from a merge publication.
	PRINT N'Removing article for table ['+ @CurrTable +']...';
	EXEC sp_dropmergearticle 
		@publication = '$(DBName)Merge',
		@article = @CurrTable, 
		@force_invalidate_snapshot = 1,
		@force_reinit_subscription = 1;

	DELETE FROM @tmpArticleTables 
	WHERE [TableName] = @CurrTable
END
GO
----- END: Remove articles from a merge publication. -----

--Remove any leftover replication constraints
PRINT N'Removing leftover replication constraints.'
GO
DECLARE @CommandStrings TABLE (RowNum int NOT NULL IDENTITY(1,1) PRIMARY KEY, CommandString nvarchar(4000))

INSERT INTO @CommandStrings (CommandString)
SELECT
	'ALTER TABLE ' + t.name + ' DROP CONSTRAINT ' + c.name
FROM
      sysobjects c
      inner join sysobjects t on
            c.parent_obj = t.id
WHERE
      c.name LIKE 'repl_identity_range_%'
ORDER BY
      t.name

DECLARE @RowNum int, @RowCount int
DECLARE @CommandString nvarchar(4000)
SET @RowNum = 0
SELECT @RowCount = COUNT(*) FROM @CommandStrings

WHILE @RowNum < @RowCount
BEGIN
	SET @RowNum = @RowNum + 1
	SELECT @CommandString = CommandString FROM @CommandStrings WHERE RowNum = @RowNum
	PRINT @CommandString
	EXEC( @CommandString )
END
GO

--Reseed identities
PRINT N'Reseeding identity columns.'
GO
DECLARE @CommandStrings TABLE (RowNum int NOT NULL IDENTITY(1,1) PRIMARY KEY, CommandString nvarchar(4000))

INSERT INTO @CommandStrings (CommandString)
SELECT
      'DBCC CHECKIDENT (' + o.name + ', RESEED)'
FROM
	syscolumns c
	INNER JOIN sysobjects o on
		c.id = o.id
WHERE
	c.status = 0x80 and o.xtype = 'u'
ORDER BY
	o.name

DECLARE @RowNum int, @RowCount int
DECLARE @CommandString nvarchar(4000)
SET @RowNum = 0
SELECT @RowCount = COUNT(*) FROM @CommandStrings

WHILE @RowNum < @RowCount
BEGIN
	SET @RowNum = @RowNum + 1
	SELECT @CommandString = CommandString FROM @CommandStrings WHERE RowNum = @RowNum
	PRINT @CommandString
	EXEC( @CommandString )
END
GO

--Set identities to NOT FOR REPLICATION
PRINT N'Setting identities to NOT FOR REPLICATION.'
GO
DECLARE @CommandStrings TABLE (RowNum int NOT NULL IDENTITY(1,1) PRIMARY KEY, CommandString nvarchar(4000))

INSERT INTO @CommandStrings (CommandString)
select
	'EXEC sys.sp_identitycolumnforreplication ' + cast(col.id as varchar) + ', 1'
from
	syscolumns col
where
	columnproperty(col.id, col.name, 'IsIdentity') = 1
	and objectproperty(col.id, 'IsUserTable') = 1
	and columnproperty(col.id, col.name, 'IsIdNotForRepl') = 0
order by
	object_name(col.id)

DECLARE @RowNum int, @RowCount int
DECLARE @CommandString nvarchar(4000)
SET @RowNum = 0
SELECT @RowCount = COUNT(*) FROM @CommandStrings

WHILE @RowNum < @RowCount
BEGIN
	SET @RowNum = @RowNum + 1
	SELECT @CommandString = CommandString FROM @CommandStrings WHERE RowNum = @RowNum
	PRINT @CommandString
	EXEC( @CommandString )
END
GO