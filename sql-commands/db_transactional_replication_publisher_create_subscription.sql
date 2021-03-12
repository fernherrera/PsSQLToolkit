-- This script uses sqlcmd scripting variables. They are in the form
-- $(MyVariable). For information about how to use scripting variables  
-- on the command line and in SQL Server Management Studio, see the 
-- "Executing Replication Scripts" section in the topic
-- "Programming Replication Using System Stored Procedures".

DECLARE @publication AS sysname;
DECLARE @subscriber AS sysname;
DECLARE @subscriptionDB AS sysname;
DECLARE @login AS sysname;
DECLARE @password AS sysname;

SET @publication = N'$(DBName)_Transactional';
SET @subscriber = N'$(SubServer)';
SET @subscriptionDB = N'$(DBName)';

-- Windows account used to run the Log Reader and Snapshot Agents.
--SET @login = $(Login); 
SET @login = N'hca\aastsvcsqlfs';
-- This should be passed at runtime.
--SET @password = $(Password); 
SET @password = N'59nC638G!'; 

USE [$(DBName)];

--Add a push subscription to a transactional publication.
PRINT N'Adding a push subscription to [$(SubServer)].';
EXEC sp_addsubscription 
    @publication = @publication, 
    @subscriber = @subscriber, 
    @destination_db = @subscriptionDB, 
    @subscription_type = N'push',
    @sync_type = N'automatic', 
	@article = N'all', 
	@update_mode = N'read only', 
	@subscriber_type = 0;

--Add an agent job to synchronize the push subscription.
PRINT N'Adding push subscription agent.';
EXEC sp_addpushsubscription_agent 
    @publication = @publication, 
    @subscriber = @subscriber, 
    @subscriber_db = @subscriptionDB, 
    @job_login = @login, 
    @job_password = @password;
GO