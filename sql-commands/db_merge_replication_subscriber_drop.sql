USE [$(DBName)];

IF OBJECT_ID(N'[dbo].[sysmergesubscriptions]', 'U') IS NOT NULL
BEGIN
	PRINT N'Merge subscription detected...';
	
	PRINT N'Remove all replication objects from the database';
	USE [master];
	EXEC sp_removedbreplication 
		@dbname = N'$(DBName)',
		@type = N'merge';

	PRINT N'Drop a merge pull subscription';
	USE [$(DBName)];
	EXEC sp_dropmergepullsubscription 
		@publisher = N'$(Publisher)', 
		@publisher_db = N'$(DBName)', 
		@publication = N'$(DBName)Merge';

	PRINT N'Remove metadata, such as triggers and entries...';
	USE [$(DBName)];
	EXEC sp_mergesubscription_cleanup 
		@publisher = N'$(Publisher)',
		@publisher_db = N'$(DBName)',
		@publication = N'$(DBName)Merge';
		
	IF OBJECT_ID(N'[dbo].[sysmergesubscriptions]', 'U') IS NULL
	BEGIN
		PRINT N'Merge subscription successfully removed...'
	END
END
ELSE
BEGIN
	PRINT N'No merge subscription detected...'
END
GO
