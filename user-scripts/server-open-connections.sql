SELECT 
	 DB_NAME([sysprocesses].[dbid]) AS [Database]
	,COUNT([sysprocesses].[dbid]) AS [Number Of Open Connections]
	,loginame AS [LoginName]
FROM sys.sysprocesses
WHERE [dbid] > 0
GROUP BY [dbid], [loginame]