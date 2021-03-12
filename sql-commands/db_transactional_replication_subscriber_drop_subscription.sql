USE [$(DBName)];
GO

DECLARE @publicationDB AS sysname;
DECLARE @publication AS sysname;
DECLARE @publisher AS sysname;
DECLARE @subscriber AS sysname;

SET @publicationDB = N'$(DBName)'; 
SET @publication = N'$(DBName)_Transactional';
SET @publisher = N'$(PubServer)';
SET @subscriber = N'$(SubServer)';

PRINT N'Remove metadata, such as triggers and entries.';
EXEC sp_subscription_cleanup 
    @publisher = @publisher,
    @publisher_db = @publicationDB,
    @publication = @publication;

GO