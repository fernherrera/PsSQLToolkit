----- BEGIN: Script to be run at Publisher -----
USE [master];

-- Enable transactional or snapshot replication on the publication database.
PRINT N'Enabling snapshot replication...';
EXEC sp_replicationdboption 
	@dbname = N'$(DBName)',
    @optname = N'merge publish', 
	@value = N'true';
GO


USE [$(DBName)];

-- Creates a new merge publication. 
PRINT N'Creating merge publication...';
EXEC sp_addmergepublication 
	@publication = N'$(DBName)Merge',
    @description = N'Merge publication of database ''$(DBName)'' from Publisher ''$(Publisher)''.',
    @sync_mode = N'native', 
	@retention = 14, 
	@allow_push = N'true',
    @allow_pull = N'true', 
	@allow_anonymous = N'true',
    @enabled_for_internet = N'false', 
	@snapshot_in_defaultfolder = N'true',
    @compress_snapshot = N'false', 
	@ftp_port = 21,
    @allow_subscription_copy = N'false', 
	@add_to_active_directory = N'false',
    @dynamic_filters = N'false', 
	@conflict_retention = 14,
    @keep_partition_changes = N'false', 
	@allow_synctoalternate = N'false',
    @max_concurrent_merge = 0, 
	@max_concurrent_dynamic_snapshots = 0,
    @use_partition_groups = NULL, 
	@publication_compatibility_level = N'100RTM',
    @replicate_ddl = 1, 
	@allow_subscriber_initiated_snapshot = N'false',
    @allow_web_synchronization = N'false',
    @allow_partition_realignment = N'true', 
	@retention_period_unit = N'days',
    @conflict_logging = N'both', 
	@automatic_reinitialization_policy = 0,
	@generation_leveling_threshold = '0';
GO


-- Creates the Snapshot Agent for the specified publication.
PRINT N'Creating snapshot agent...';
EXEC sp_addpublication_snapshot 
	@publication = N'$(DBName)Merge',
    @frequency_type = 8, 
	@frequency_interval = 9,
    @frequency_relative_interval = 1, 
	@frequency_recurrence_factor = 1,
    @frequency_subday = 1, 
	@frequency_subday_interval = 5,
    @active_start_time_of_day = N'$(Minutes)', 
	@active_end_time_of_day = 235959,
    @active_start_date = 0, 
	@active_end_date = 0,
    @job_login = N'hca\aastsvcsqlfs', 
	@job_password = N'59nC638G!',
    @publisher_security_mode = 1;
GO


----- BEGIN: Add articles to the publication -----
PRINT N'Adding articles...';
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
GROUP BY 
	t.[name]
	,s.[name]

DECLARE @CurrSchema sysname
DECLARE @CurrTable sysname
DECLARE @isIdentity bit
WHILE (SELECT COUNT(*) FROM @tmpArticleTables) > 0
BEGIN
	SELECT TOP 1 
		@CurrSchema = [SchemaName],
		@CurrTable = [TableName],
		@isIdentity = [IsIdentity]
	FROM @tmpArticleTables

	PRINT N'Adding article for table ['+ @CurrTable +']...';
	
	IF @isIdentity = 1
	BEGIN
		EXEC sp_addmergearticle 
		@publication = N'$(DBName)Merge',
		@article = @CurrTable, 
		@source_owner = @CurrSchema,
		@source_object = @CurrTable, 
		@type = N'table', 
		@description = NULL,
		@creation_script = NULL, 
		@pre_creation_cmd = N'none',
		@schema_option = 0x000000010C034FD1,
		@identityrangemanagementoption = N'auto', 
		@pub_identity_range = 10000,
		@identity_range = 1000, 
		@threshold = 80, 
		@destination_owner = @CurrSchema,
		@force_reinit_subscription = 1, 
		@column_tracking = N'false',
		@subset_filterclause = NULL, 
		@vertical_partition = N'false',
		@verify_resolver_signature = 1, 
		@allow_interactive_resolver = N'false',
		@fast_multicol_updateproc = N'true', 
		@check_permissions = 0,
		@subscriber_upload_options = 0, -- 0 = No restrictions, 1 = Changes are allowed at the Subscriber, but they are not uploaded to the Publisher, 2 = Changes are not allowed at the Subscriber.
		@delete_tracking = N'true',
		@compensate_for_errors = N'false', 
		@stream_blob_columns = N'false',
		@partition_options = 0;
	END
	ELSE
	BEGIN
		EXEC sp_addmergearticle 
			@publication = N'$(DBName)Merge',
			@article = @CurrTable, 
			@source_owner = @CurrSchema,
			@source_object = @CurrTable, 
			@type = N'table', 
			@description = NULL,
			@creation_script = NULL, 
			@pre_creation_cmd = N'none',
			@schema_option = 0x000000010C034FD1,
			@force_reinit_subscription = 1, 
			@column_tracking = N'false',
			@subset_filterclause = NULL, 
			@vertical_partition = N'false',
			@verify_resolver_signature = 1, 
			@allow_interactive_resolver = N'false',
			@fast_multicol_updateproc = N'true', 
			@check_permissions = 0,
			@subscriber_upload_options = 0, -- 0 = No restrictions, 1 = Changes are allowed at the Subscriber, but they are not uploaded to the Publisher, 2 = Changes are not allowed at the Subscriber.
			@delete_tracking = N'true',
			@compensate_for_errors = N'false', 
			@stream_blob_columns = N'false',
			@partition_options = 0;
	END

	DELETE FROM @tmpArticleTables 
	WHERE [TableName] = @CurrTable
END
----- END: Add articles to the publication -----

----- END: Script to be run at Publisher -----