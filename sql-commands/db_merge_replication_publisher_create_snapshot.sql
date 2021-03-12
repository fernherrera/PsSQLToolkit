USE [$(DBName)];

-- Start the Snapshot Agent job.
PRINT N'Starting snapshot agent job...';
EXEC sp_startpublication_snapshot 
	@publication = N'$(DBName)Merge';
GO