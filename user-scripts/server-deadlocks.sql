------------------------------------------------------------------------------

-- Blocked processes
SELECT * from sys.sysprocesses where blocked > 0

------------------------------------------------------------------------------

-- Blocked processes with connection info
SELECT Blocker.*, *
FROM sys.dm_exec_connections AS Conns
INNER JOIN sys.dm_exec_requests AS BlockedReqs
    ON Conns.session_id = BlockedReqs.blocking_session_id
INNER JOIN sys.dm_os_waiting_tasks AS w
    ON BlockedReqs.session_id = w.session_id
CROSS APPLY sys.dm_exec_sql_text(Conns.most_recent_sql_handle) AS Blocker

------------------------------------------------------------------------------

-- List of Wait Types by wait times
WITH Waits AS 
( 
SELECT 
wait_type, 
wait_time_ms / 1000. AS wait_time_s, 
100. * wait_time_ms / SUM(wait_time_ms) OVER() AS pct, 
ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn 
FROM sys.dm_os_wait_stats 
WHERE wait_type 
NOT IN 
('CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 
'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 
'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT') 
) -- filter out additional irrelevant waits 
SELECT W1.wait_type, 
CAST(W1.wait_time_s AS DECIMAL(12, 2)) AS wait_time_s, 
CAST(W1.pct AS DECIMAL(12, 2)) AS pct, 
CAST(SUM(W2.pct) AS DECIMAL(12, 2)) AS running_pct 
FROM Waits AS W1 
INNER JOIN Waits AS W2 ON W2.rn <= W1.rn 
GROUP BY W1.rn, 
W1.wait_type, 
W1.wait_time_s, 
W1.pct 
HAVING SUM(W2.pct) - W1.pct < 95; -- percentage threshold;

------------------------------------------------------------------------------

-- Average Current tasks and Average Wait tasks counts
SELECT AVG(current_tasks_count) AS [Avg Current Task], 
AVG(runnable_tasks_count) AS [Avg Wait Task]
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255
AND status = 'VISIBLE ONLINE'

------------------------------------------------------------------------------

-- List schedulers with current running tasks
SELECT 
a.scheduler_id ,
b.session_id,
 (SELECT TOP 1 SUBSTRING(s2.text,statement_start_offset / 2+1 , 
      ( (CASE WHEN statement_end_offset = -1 
         THEN (LEN(CONVERT(nvarchar(max),s2.text)) * 2) 
         ELSE statement_end_offset END)  - statement_start_offset) / 2+1))  AS sql_statement
FROM sys.dm_os_schedulers a 
INNER JOIN sys.dm_os_tasks b on a.active_worker_address = b.worker_address
INNER JOIN sys.dm_exec_requests c on b.task_address = c.task_address
CROSS APPLY sys.dm_exec_sql_text(c.sql_handle) AS s2 

------------------------------------------------------------------------------

-- Total number of logical processors
SELECT COUNT(*) AS proc# 
FROM sys.dm_os_schedulers 
WHERE status = 'VISIBLE ONLINE' 
AND is_online = 1

------------------------------------------------------------------------------

-- SQL statements currently running 
SELECT s2.text, 
session_id,
start_time,
status, 
cpu_time, 
blocking_session_id, 
wait_type,
wait_time, 
wait_resource, 
open_transaction_count
FROM sys.dm_exec_requests a
CROSS APPLY sys.dm_exec_sql_text(a.sql_handle) AS s2  
WHERE status <> 'background'

------------------------------------------------------------------------------

-- Identifying Blocking Chain
SET NOCOUNT ON
GO

SELECT SPID, BLOCKED, REPLACE (REPLACE (T.TEXT, CHAR(10), ' '), CHAR (13), ' ' ) AS BATCH
INTO #T
FROM sys.sysprocesses R CROSS APPLY sys.dm_exec_sql_text(R.SQL_HANDLE) T
GO

WITH BLOCKERS (SPID, BLOCKED, LEVEL, BATCH)
AS
(
	SELECT 
		SPID,
		BLOCKED,
		CAST (REPLICATE ('0', 4-LEN (CAST (SPID AS VARCHAR))) + CAST (SPID AS VARCHAR) AS VARCHAR (1000)) AS LEVEL,
		BATCH 
	FROM #T R
	WHERE 
		(BLOCKED = 0 OR BLOCKED = SPID)
		AND EXISTS (SELECT * FROM #T R2 WHERE R2.BLOCKED = R.SPID AND R2.BLOCKED <> R2.SPID)
	UNION ALL
	SELECT 
		R.SPID,
		R.BLOCKED,
		CAST (BLOCKERS.LEVEL + RIGHT (CAST ((1000 + R.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL,
		R.BATCH 
	FROM #T AS R
		INNER JOIN BLOCKERS ON R.BLOCKED = BLOCKERS.SPID WHERE R.BLOCKED > 0 AND R.BLOCKED <> R.SPID
)
SELECT 
	N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) +
	CASE WHEN (LEN(LEVEL)/4 - 1) = 0
	THEN 'HEAD -  '
	ELSE '|------  ' END
	+ CAST (SPID AS NVARCHAR (10)) + N' ' + BATCH AS BLOCKING_TREE
FROM BLOCKERS 
ORDER BY 
	LEVEL ASC
GO

DROP TABLE #T
GO

------------------------------------------------------------------------------
