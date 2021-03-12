USE [$(DBName)];
GO

DECLARE @publicationDB AS sysname;
DECLARE @publication AS sysname;

SET @publicationDB = N'$(DBName)'; 
SET @publication = N'$(DBName)_Transactional'; 

-- Remove a transactional publication.
PRINT N'Dropping publication.';
EXEC sp_droppublication 
	@publication = @publication;

-- Removes all replication objects on the publication database on the Publisher instance of SQL Server 
-- or on the subscription database on the Subscriber instance of SQL Server
PRINT N'Removing all replication objects from database.'
EXEC sp_removedbreplication 
    @dbname = @publicationDB,
    @type = N'tran'

-- Remove replication objects from the database.
PRINT N'Removing replication objects from the database.';
EXEC sp_replicationdboption 
    @dbname = @publicationDB, 
    @optname = N'publish', 
    @value = N'false';

GO