------------------------------------------------------------------------------

-- Get Default SQL Server Backup Folder
DECLARE @path NVARCHAR(4000) 
EXEC master.dbo.xp_instance_regread 
            @rootkey = N'HKEY_LOCAL_MACHINE', 
            @key = N'Software\Microsoft\MSSQLServer\MSSQLServer',
			@value_name = N'BackupDirectory', 
            @value = @path OUTPUT
SELECT @path

------------------------------------------------------------------------------

-- Info on Dbs
EXECUTE sp_helpdb

------------------------------------------------------------------------------

-- space used
EXECUTE master.sys.sp_MSforeachdb 'USE [?]; EXEC sp_spaceused'

------------------------------------------------------------------------------

-- DB data & log files
EXECUTE master.sys.sp_MSforeachdb 'USE [?]; EXEC sp_helpfile'

------------------------------------------------------------------------------

-- sys.master_files and list all database files
SELECT
	 DB_NAME([database_id]) AS [db_name]
	,mf.[name] AS [file_name]
	,mf.[physical_name]
	,(mf.[size] * 8) /1024 AS [size_MB]
	,(mf.[size] * 8) /1024/1024 AS [size_GB]
FROM sys.master_files AS mf

------------------------------------------------------------------------------

-- Databases by Size
select db_name(database_id) as dbname,
type_desc,(size * 8) /1024 as size_MB,
(size * 8) /1024/1024 as size_GB
from sys.master_files order by size desc

------------------------------------------------------------------------------

-- Predict SQL BACKUP DATABASE finish time with sys.dm_exec_requests
SELECT session_id,percent_complete,DATEADD(MILLISECOND,estimated_completion_time,CURRENT_TIMESTAMP) Estimated_finish_time,
(total_elapsed_time/1000)/60 Total_Elapsed_Time_MINS ,
DB_NAME(Database_id) Database_Name ,command,sql_handle
FROM sys.dm_exec_requests WHERE command LIKE '%BACKUP DATABASE%'

------------------------------------------------------------------------------

-- Restore Database Estimated Finish Time
SELECT session_id,percent_complete,DATEADD(MILLISECOND,estimated_completion_time,CURRENT_TIMESTAMP) Estimated_finish_time,
(total_elapsed_time/1000)/60 Total_Elapsed_Time_MINS ,
DB_NAME(Database_id) Database_Name ,command,sql_handle
FROM sys.dm_exec_requests WHERE session_id=57

------------------------------------------------------------------------------
