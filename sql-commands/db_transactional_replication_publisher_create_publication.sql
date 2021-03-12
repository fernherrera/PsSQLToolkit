----- BEGIN: Script to be run at Publisher -----
USE [$(DBName)];

DECLARE @publicationDB AS sysname;
DECLARE @publication AS sysname;
DECLARE @login AS sysname;
DECLARE @password AS sysname;
DECLARE @schemaowner AS sysname;

SET @publicationDB = N'$(DBName)'; 
SET @publication = N'$(DBName)_Transactional'; 

-- Windows account used to run the Log Reader and Snapshot Agents.
--SET @login = $(Login); 
SET @login = N'hca\aastsvcsqlfs';
-- This should be passed at runtime.
--SET @password = $(Password); 
SET @password = N'59nC638G!'; 

-- Enable transactional or snapshot replication on the publication database.
PRINT N'Enabling transactional replication.';
EXEC sp_replicationdboption 
	@dbname = N'$(DBName)',
    @optname = N'publish', 
	@value = N'true';

-- Execute sp_addlogreader_agent to create the agent job.
PRINT N'Adding Log Reader Agent.';
EXEC sp_addlogreader_agent 
	@job_login = @login, 
	@job_password = @password,
	-- Explicitly specify the use of Windows Integrated Authentication (default) 
	-- when connecting to the Publisher.
	@publisher_security_mode = 1;

-- Create a new transactional publication with the required properties. 
PRINT N'Creating publication [' + @publication + '].';
EXEC sp_addpublication 
	@publication = @publication, 
    @description = N'Transactional publication of database ''$(DBName)''.', 
    @sync_method = N'concurrent', 
    @retention = 0, 
    @allow_push = N'true', 
    @allow_pull = N'true', 
    @allow_anonymous = N'true', 
    @enabled_for_internet = N'false', 
    @snapshot_in_defaultfolder = N'true', 
    @compress_snapshot = N'false', 
    @ftp_port = 21, 
    @ftp_login = N'anonymous', 
    @allow_subscription_copy = N'false', 
    @add_to_active_directory = N'false', 
    @repl_freq = N'continuous', 
    @status = N'active', 
    @independent_agent = N'true', 
    @immediate_sync = N'true', 
    @allow_sync_tran = N'false', 
    @autogen_sync_procs = N'false', 
    @allow_queued_tran = N'false', 
    @allow_dts = N'false', 
    @replicate_ddl = 1, 
    @allow_initialize_from_backup = N'true', 
    @enabled_for_p2p = N'false', 
    @enabled_for_het_sub = N'false';

-- Create a new snapshot job for the publication, using a default schedule.
PRINT N'Creating snapshot job.';
EXEC sp_addpublication_snapshot 
	@publication = @publication, 
    @frequency_type = 1, 
    @frequency_interval = 0, 
    @frequency_relative_interval = 0, 
    @frequency_recurrence_factor = 0, 
    @frequency_subday = 0, 
    @frequency_subday_interval = 0, 
    @active_start_time_of_day = 0, 
    @active_end_time_of_day = 235959, 
    @active_start_date = 0, 
    @active_end_date = 0, 
	@job_login = @login, 
	@job_password = @password,
	-- Explicitly specify the use of Windows Integrated Authentication (default) 
	-- when connecting to the Publisher.
	@publisher_security_mode = 1;


----- BEGIN: Add articles to the publication -----
PRINT N'Adding table articles...';
DECLARE @tmpArticleTables TABLE([TableName] sysname, [SchemaName] sysname, [IsIdentity] bit, [HasPrimaryKey] bit)
INSERT INTO @tmpArticleTables([TableName], [SchemaName], [IsIdentity], [HasPrimaryKey])
SELECT 
	 t.[name] AS [TableName]
	,s.[name] AS [SchemaName]
	,CASE 
		WHEN SUM(CAST(c.[is_identity] AS int)) > 0 THEN CAST(1 AS bit) 
		ELSE CAST(0 AS bit) 
	END AS [IsIdentity]
	,CASE
		WHEN SUM(OBJECTPROPERTY(t.[object_id],'TableHasPrimaryKey')) > 0 THEN CAST(1 AS bit)
		ELSE CAST(0 AS BIT)
	END AS [HasPrimaryKey]
FROM 
	[sys].[tables] t 
	INNER JOIN [sys].[schemas] s ON t.[schema_id] = s.[schema_id] 
	INNER JOIN [sys].[columns] c ON c.[object_id] = t.[object_id]
WHERE 
	[is_ms_shipped] = 0 
	-- AND NOT t.[name] IN ('__MigrationHistory') 
GROUP BY 
	 s.[name]
	,t.[name]

DECLARE @CurrTable sysname

DECLARE @isIdentity bit
DECLARE @hasPrimaryKey bit
WHILE (SELECT COUNT(*) FROM @tmpArticleTables) > 0
BEGIN
	SELECT TOP 1 
		@CurrTable = [TableName],
        @schemaowner = [SchemaName],
		@isIdentity = [IsIdentity],
		@hasPrimaryKey = [HasPrimaryKey]
	FROM @tmpArticleTables

	PRINT N'Adding article for table [' + @schemaowner + '].['+ @CurrTable +'].';
	
	IF @hasPrimaryKey = 1
	BEGIN
        EXEC sp_addarticle 
            @publication = @publication, 
            @article = @CurrTable, 
            @source_object = @CurrTable,
            @source_owner = @schemaowner, 
            @type = N'logbased',
			@description = N'', 
			@creation_script = N'', 
			@pre_creation_cmd = N'drop', 
            @schema_option = 0x0000000048035FDF,
		    @identityrangemanagementoption = N'manual', 
            @vertical_partition = N'false', 
			@ins_cmd = N'SQL', 
    		@del_cmd = N'SQL', 
    		@upd_cmd = N'SQL';

        -- Add all columns to the article.
        EXEC sp_articlecolumn 
            @publication = @publication, 
            @article = @CurrTable,
			@force_invalidate_snapshot = 0, 
			@force_reinit_subscription = 0;
	END
	
	DELETE FROM @tmpArticleTables 
	WHERE [TableName] = @CurrTable
END


PRINT N'Adding stored procedure articles...';
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
GROUP BY 
	p.[name]
	,s.[name]

DECLARE @CurrProc sysname
WHILE (SELECT COUNT(*) FROM @tmpArticleProcs) > 0
BEGIN
	SELECT TOP 1 
		@CurrProc = [ProcName],
        @schemaowner = [SchemaName]
	FROM @tmpArticleProcs

	PRINT N'Adding article for proc [' + @schemaowner + '].['+ @CurrProc +'].';
    EXEC sp_addarticle 
        @publication = @publication, 
        @article = @CurrProc, 
        @source_object = @CurrProc,
        @source_owner = @schemaowner, 
        @type = N'proc schema only',
		@description = N'', 
		@creation_script = N'', 
	    @pre_creation_cmd = N'drop', 
        @schema_option = 0x0000000048000001, 
		@status = 16;

	DELETE FROM @tmpArticleProcs 
	WHERE [ProcName] = @CurrProc
END


PRINT N'Adding function articles...';
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
	o.[type_desc] LIKE '%function%'
	AND s.[name] IN ('dbo','Dashboards')

DECLARE @CurrFunc sysname
WHILE (SELECT COUNT(*) FROM @tmpArticleFunc) > 0
BEGIN
	SELECT TOP 1 
		@CurrFunc = [FuncName],
        @schemaowner = [SchemaName]
	FROM @tmpArticleFunc

	PRINT N'Adding article for function [' + @schemaowner + '].['+ @CurrFunc +'].';
    EXEC sp_addarticle 
        @publication = @publication, 
        @article = @CurrFunc, 
        @source_object = @CurrFunc,
        @source_owner = @schemaowner, 
        @type = N'func schema only',
		@description = N'', 
		@creation_script = N'', 
		@pre_creation_cmd = N'drop', 
		@schema_option = 0x0000000048000001, 
		@status = 16;

	DELETE FROM @tmpArticleFunc 
	WHERE [FuncName] = @CurrFunc
END


PRINT N'Adding view articles...';
DECLARE @tmpArticleViews TABLE([ViewName] sysname, [SchemaName] sysname)
INSERT INTO @tmpArticleViews([ViewName], [SchemaName])
SELECT
	v.[name] AS [ViewName]
	,s.[name] AS [SchemaName]
FROM 
	[sys].[views] v
	INNER JOIN [sys].[schemas] s ON v.[schema_id] = s.[schema_id] 
WHERE 
	v.[is_ms_shipped] = 0
	AND v.[Type] = 'V'
GROUP BY 
	v.[name]
	,s.[name]

DECLARE @CurrView sysname
WHILE (SELECT COUNT(*) FROM @tmpArticleViews) > 0
BEGIN
	SELECT TOP 1 
		@CurrView = [ViewName],
        @schemaowner = [SchemaName]
	FROM @tmpArticleViews

	PRINT N'Adding article for view [' + @schemaowner + '].['+ @CurrView +'].';
    EXEC sp_addarticle 
        @publication = @publication, 
        @article = @CurrView, 
        @source_object = @CurrView,
        @source_owner = @schemaowner, 
		@type = N'view schema only',
		@description = N'',
		@creation_script = N'',
		@pre_creation_cmd = N'drop',
        @schema_option = NULL,
		@destination_table = @CurrView, 
		@destination_owner = @schemaowner;


	DELETE FROM @tmpArticleViews 
	WHERE [ViewName] = @CurrView
END
----- END: Add articles to the publication -----

GO
----- END: Script to be run at Publisher -----