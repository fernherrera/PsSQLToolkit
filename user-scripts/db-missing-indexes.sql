------------------------------------------------------------------------------

-- Missing Index Script
-- Original Author: Pinal Dave 
-- (Selected database only)
SELECT TOP 25
dm_mid.database_id AS DatabaseID,
dm_migs.avg_user_impact*(dm_migs.user_seeks+dm_migs.user_scans) Avg_Estimated_Impact,
dm_migs.last_user_seek AS Last_User_Seek,
OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) AS [TableName],
'CREATE INDEX [IX_' + OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) + '_'
+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.equality_columns,''),', ','_'),'[',''),']','') 
+ CASE
WHEN dm_mid.equality_columns IS NOT NULL
AND dm_mid.inequality_columns IS NOT NULL THEN '_'
ELSE ''
END
+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.inequality_columns,''),', ','_'),'[',''),']','')
+ ']'
+ ' ON ' + dm_mid.statement
+ ' (' + ISNULL (dm_mid.equality_columns,'')
+ CASE WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns 
IS NOT NULL THEN ',' ELSE
'' END
+ ISNULL (dm_mid.inequality_columns, '')
+ ')'
+ ISNULL (' INCLUDE (' + dm_mid.included_columns + ')', '') AS Create_Statement
FROM sys.dm_db_missing_index_groups dm_mig
INNER JOIN sys.dm_db_missing_index_group_stats dm_migs
ON dm_migs.group_handle = dm_mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details dm_mid
ON dm_mig.index_handle = dm_mid.index_handle
WHERE dm_mid.database_ID = DB_ID()
ORDER BY Avg_Estimated_Impact DESC
GO

------------------------------------------------------------------------------

-- Alternate version (All databases)
SELECT CAST(SERVERPROPERTY('ServerName') AS [nvarchar](256)) AS [SQLServer]
    ,db.[database_id] AS [DatabaseID]
    ,db.[name] AS [DatabaseName]
    ,id.[object_id] AS [ObjectID]
    ,id.[statement] AS [FullyQualifiedObjectName]
    ,id.[equality_columns] AS [EqualityColumns]
    ,id.[inequality_columns] AS [InEqualityColumns]
    ,id.[included_columns] AS [IncludedColumns]
    ,gs.[unique_compiles] AS [UniqueCompiles]
    ,gs.[user_seeks] AS [UserSeeks]
    ,gs.[user_scans] AS [UserScans]
    ,gs.[last_user_seek] AS [LastUserSeekTime]
    ,gs.[last_user_scan] AS [LastUserScanTime]
    ,gs.[avg_total_user_cost] AS [AvgTotalUserCost]
    ,gs.[avg_user_impact] AS [AvgUserImpact]
    ,gs.[system_seeks] AS [SystemSeeks]
    ,gs.[system_scans] AS [SystemScans]
    ,gs.[last_system_seek] AS [LastSystemSeekTime]
    ,gs.[last_system_scan] AS [LastSystemScanTime]
    ,gs.[avg_total_system_cost] AS [AvgTotalSystemCost]
    ,gs.[avg_system_impact] AS [AvgSystemImpact]
    ,gs.[user_seeks] * gs.[avg_total_user_cost] * (gs.[avg_user_impact] * 0.01) AS [IndexAdvantage]
    ,'CREATE INDEX IX_' + OBJECT_NAME(id.[object_id], db.[database_id]) + '_' + REPLACE(REPLACE(REPLACE(ISNULL(id.[equality_columns], ''), ', ', '_'), '[', ''), ']', '') + CASE
        WHEN id.[equality_columns] IS NOT NULL
            AND id.[inequality_columns] IS NOT NULL
            THEN '_'
        ELSE ''
        END + REPLACE(REPLACE(REPLACE(ISNULL(id.[inequality_columns], ''), ', ', '_'), '[', ''), ']', '') + '_' + LEFT(CAST(NEWID() AS [nvarchar](64)), 5) + ']' + ' ON ' + id.[statement] + ' (' + ISNULL(id.[equality_columns], '') + CASE
        WHEN id.[equality_columns] IS NOT NULL
            AND id.[inequality_columns] IS NOT NULL
            THEN ','
        ELSE ''
        END + ISNULL(id.[inequality_columns], '') + ')' + ISNULL(' INCLUDE (' + id.[included_columns] + ')', '') AS [ProposedIndex]
    ,CAST(CURRENT_TIMESTAMP AS [smalldatetime]) AS [CollectionDate]
FROM [sys].[dm_db_missing_index_group_stats] gs WITH (NOLOCK)
INNER JOIN [sys].[dm_db_missing_index_groups] ig WITH (NOLOCK)
    ON gs.[group_handle] = ig.[index_group_handle]
INNER JOIN [sys].[dm_db_missing_index_details] id WITH (NOLOCK)
    ON ig.[index_handle] = id.[index_handle]
INNER JOIN [sys].[databases] db WITH (NOLOCK)
    ON db.[database_id] = id.[database_id]
WHERE id.[database_id] > 4 -- Remove this to see for entire instance
ORDER BY [IndexAdvantage] DESC
OPTION (RECOMPILE);

------------------------------------------------------------------------------
