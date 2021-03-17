------------------------------------------------------------------------------
-- List DB Connections
------------------------------------------------------------------------------
DECLARE @sp_who2 TABLE
(
	 [SPID] int
	,[Status] varchar(255)
    ,[Login] varchar(255)
	,[HostName] varchar(255)
    ,[BlkBy] varchar(255)
	,[DBName] varchar(255)
    ,[Command] varchar(255)
	,[CPUTime] int
    ,[DiskIO] int
	,[LastBatch] varchar(255)
    ,[ProgramName] varchar(255)
	,[SPID2] int
    ,[REQUESTID] int
);

INSERT INTO @sp_who2 EXEC sp_who2;

SELECT
	[SPID],[Login],[Hostname],[DBName],[ProgramName],[Command]
FROM @sp_who2
--WHERE [DBName] = ''
	--AND [ProgramName] LIKE '%UI.Web'
ORDER BY [HostName];

GO
------------------------------------------------------------------------------
