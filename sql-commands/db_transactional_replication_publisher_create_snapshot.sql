USE [$(DBName)];

DECLARE @publication AS sysname;

SET @publication = N'$(DBName)_Transactional'; 

-- Start the Snapshot Agent job.
PRINT N'Starting snapshot agent job.';
EXEC sp_startpublication_snapshot 
	@publication = @publication;
GO