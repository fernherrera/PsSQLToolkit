/*
==============================================================================
  Restores a database from a full backup and removes replication settings.
  
  Usage: SLQCMD mode
  Expects variables:
    DBName         - Database name to restore as.
    backupPath     - File path to backup directory.
    backupFilename - Filename of backup to restore.
    MdfPath        - SQL Server path for data files.
    LdfPath        - SQL Server path for transaction log files.
==============================================================================
*/

------------------------------------------------------------------------------
-- Restore DB
------------------------------------------------------------------------------
USE [master];
GO

PRINT N'Getting FILELIST from backup file...';
GO
DECLARE @FileList TABLE
(
       [LogicalName] nvarchar(128) NOT NULL
      ,[PhysicalName] nvarchar(260) NOT NULL
      ,[Type] char(1) NOT NULL
      ,[FileGroupName] nvarchar(120) NULL
      ,[Size] numeric(20, 0) NOT NULL
      ,[MaxSize] numeric(20, 0) NOT NULL
      ,[FileID] bigint NULL
      ,[CreateLSN] numeric(25,0) NULL
      ,[DropLSN] numeric(25,0) NULL
      ,[UniqueID] uniqueidentifier NULL
      ,[ReadOnlyLSN] numeric(25,0) NULL
      ,[ReadWriteLSN] numeric(25,0) NULL
      ,[BackupSizeInBytes] bigint NULL
      ,[SourceBlockSize] int NULL
      ,[FileGroupID] int NULL
      ,[LogGroupGUID] uniqueidentifier NULL
      ,[DifferentialBaseLSN] numeric(25,0)NULL
      ,[DifferentialBaseGUID] uniqueidentifier NULL
      ,[IsReadOnly] bit NULL
      ,[IsPresent] bit NULL
      ,[TDEThumbprint] varbinary(32) NULL
	  ,[SnapshotUrl] nvarchar(360) NULL
);

DECLARE 
	 @RestoreStatement nvarchar(max)
	,@MoveStatements nvarchar(max) = ''
	,@BackupFile nvarchar(max);
 
SET @BackupFile = N'$(backupPath)\$(backupFilename)';
SET @RestoreStatement =  N'RESTORE FILELISTONLY FROM DISK=N''' + @BackupFile + '''';

INSERT INTO @FileList EXEC(@RestoreStatement);

DECLARE 
	 @logical_name nvarchar(128)
	,@tmp_logical_name nvarchar(max)
	,@tmp_string nvarchar(max)
	,@file_id int;;

-- Loop through all the data files
WHILE (SELECT COUNT(*) FROM @FileList WHERE [Type] = 'D') > 0
BEGIN
	SELECT TOP(1) 
		@logical_name = [LogicalName]
		,@file_id = [FileID]
		,@tmp_logical_name = CASE WHEN [FileID] = 1 THEN '$(DBName)_Data' ELSE '$(DBName)_Data_' + CAST([FileID] AS varchar) END
		,@tmp_string = CONCAT('MOVE N''', [LogicalName], N''' TO N''$(MdfPath)\', @tmp_logical_name, SUBSTRING([PhysicalName], LEN([PhysicalName])-3, 4), ''',', CHAR(13))
	FROM @FileList WHERE [Type] = 'D'
	ORDER BY [FileID];

	SET @MoveStatements = @MoveStatements + @tmp_string;

	DELETE FROM @FileList WHERE [LogicalName] = @logical_name;
END;

-- Loop through all the transaction log files
WHILE (SELECT COUNT(*) FROM @FileList WHERE [Type] = 'L') > 0
BEGIN
	SELECT TOP(1) 
		@logical_name = [LogicalName]
		,@file_id = [FileID]
		,@tmp_logical_name = CASE WHEN [FileID] = 2 THEN '$(DBName)_Log' ELSE '$(DBName)_Log_' + CAST([FileID] AS varchar) END
		,@tmp_string = CONCAT('MOVE N''', [LogicalName], N''' TO N''$(LdfPath)\', @tmp_logical_name, SUBSTRING([PhysicalName], LEN([PhysicalName])-3, 4), ''',', CHAR(13))
	FROM @FileList WHERE [Type] = 'L'
	ORDER BY [FileID];

	SET @MoveStatements = @MoveStatements + @tmp_string;

	DELETE FROM @FileList WHERE [LogicalName] = @logical_name;
END;


IF db_id('$(DBName)') IS NOT NULL
BEGIN
	PRINT N'Dropping existing replication...';
	EXEC sp_removedbreplication @dbname=[$(DBName)];

	PRINT N'Going into single user mode...';
	ALTER DATABASE [$(DBName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

	PRINT N'Dropping existing database...';
	DROP DATABASE [$(DBName)];
END

PRINT N'Restoring database...';
SET @RestoreStatement = N'RESTORE DATABASE [$(DBName)]
FROM DISK = N''' + @BackupFile + '''
WITH
	' + @MoveStatements + '
	REPLACE,
	STATS = 5';

EXEC(@RestoreStatement);

IF (SELECT user_access_desc FROM sys.databases WHERE name = '$(DBName)') = 'SINGLE_USER'
BEGIN
	PRINT 'Turning off single user mode...';
	ALTER DATABASE [$(DBName)] SET MULTI_USER;
END
GO

------------------------------------------------------------------------------

USE [$(DBName)];
GO

PRINT 'Removing replication that came with backup file...'
SET NUMERIC_ROUNDABORT OFF
GO
SET XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT ON
GO

-----------------------------------------
-- Change compatibility level to SQL Server 2016
-----------------------------------------
PRINT N'Setting compatibility level to SQL Server 2016...'
ALTER DATABASE [$(DBName)] SET COMPATIBILITY_LEVEL = 130
GO

------------------------------
-- Remove publication
------------------------------
PRINT N'Removing publication...';
EXEC sp_removedbreplication N'$(DBName)'
GO

---------------------------------------------
-- Remove any leftover replication constraints
---------------------------------------------
PRINT N'Removing leftover replication constraints...'
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

--------------------
-- Reseed identities
--------------------
/*
PRINT N'Reseeding identity columns...'
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
*/

----------------------------------------
-- Set identities to NOT FOR REPLICATION
----------------------------------------
PRINT N'Setting identities to NOT FOR REPLICATION...'
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

------------------------------------------------------------------------------
