USE [$(DBName)];

----- BEGIN: Script to be run at Subscriber -----

-- Adds a pull subscription to a merge publication.
EXEC sp_addmergepullsubscription 
	@publisher = N'$(Publisher)',
    @publication = N'$(DBName)Merge', 
	@publisher_db = N'$(DBName)',
    @subscriber_type = N'Local', 
	@subscription_priority = 0,
    @description = N'', 
	@sync_type = N'Automatic';


-- Adds a new agent job used to schedule synchronization of a pull subscription to a merge publication. 
EXEC sp_addmergepullsubscription_agent 
	@publisher = N'$(Publisher)',
    @publisher_db = N'$(DBName)', 
	@publication = N'$(DBName)Merge',
    @distributor = N'$(Publisher)', 
	@distributor_security_mode = 1,
    @distributor_login = N'', 
	@distributor_password = NULL,
    @enabled_for_syncmgr = N'False', 
	@frequency_type = 4,
    @frequency_interval = 1, 
	@frequency_relative_interval = 1,
    @frequency_recurrence_factor = 1, 
	@frequency_subday = 4,
    @frequency_subday_interval = 10, 
	@active_start_time_of_day = N'$(Minutes)',
    @active_end_time_of_day = 235959, 
	@active_start_date = 20160720,
    @active_end_date = 99991231, 
	@alt_snapshot_folder = N'',
    @working_directory = N'', 
	@use_ftp = N'False',
    @job_login = N'HCA\aastsvcsqlfs', 
	@job_password = N'59nC638G!',
    @publisher_security_mode = 1, 
	@publisher_login = N'HCA\aastsvcsqlfs',
    @publisher_password = N'59nC638G!', 
	@use_interactive_resolver = N'False',
    @dynamic_snapshot_location = NULL, 
	@use_web_sync = 0;
GO

----- END: Script to be run at Subscriber -----