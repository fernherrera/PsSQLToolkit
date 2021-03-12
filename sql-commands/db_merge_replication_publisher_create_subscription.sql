USE [$(DBName)];

-- Adding the merge subscriptions
PRINT N'Adding the merge subscription for $(Subscriber)...';
EXEC sp_addmergesubscription 
	@publication = N'$(DBName)Merge', 
	@subscriber = N'$(Subscriber)', 
	@subscriber_db = N'$(DBName)', 
	@subscription_type = N'Pull', 
	@sync_type = N'Automatic', 
	@subscriber_type = N'Local', 
	@subscription_priority = 0, 
	@description = N'', 
	@use_interactive_resolver = N'False'
GO