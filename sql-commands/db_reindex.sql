--:setvar DBName "DatabaseName"

IF OBJECT_ID('tempdb..#DatabaseName') IS NOT NULL DROP TABLE #DatabaseName
CREATE TABLE #DatabaseName-- Temp table to store Database names on which index operation needs to be performed on the server
(
id INT IDENTITY (1,1),
Databasename SYSNAME,
Database_id SMALLINT
)

INSERT INTO #DatabaseName
SELECT name,database_id FROM SYS.DATABASES WHERE name NOT IN ('master','model','msdb','tempdb')--Select databases you would like rebuild/reorganize to be performed
 --and name in ('logicalread')
AND state_desc='online' and is_read_only=0 and compatibility_level <> 80 AND [databases].[name]='$[DBName]'--the script would not work for database with compatibility level 80

Select 'List of Databases On which Maintenance Activity will be performed'
SELECT * FROM #DatabaseName

DECLARE 
@id int,
@dbname SYSNAME,
@db_id smallint,
@cmd1 nvarchar(max),
@cmd2 nvarchar(max)
--@DBID smallint
SET @ID=1
WHILE(1=1)
BEGIN
SELECT @ID=ID,
@Dbname=Databasename,
@db_id=Database_id
FROM #DatabaseName
WHERE ID=@ID
--set @dbid=DB_ID(@dbname)
IF @@ROWCOUNT=0
BREAK


IF OBJECT_ID('tempdb..#work_table') IS NOT NULL DROP TABLE #work_table
create table #work_table
(
IDD int IDENTITY (1,1) NOT NULL,
objectname sysname,
indexname sysname,
Schemaname sysname,
AFIP float
 
)


SET @Cmd1= N'USE ['+ @dbname + N'] ; 
Insert into #work_table
select
                    o.name AS objectName                

                ,        i.name AS indexName 
				,s.name as Schemaname
                ,p.avg_fragmentation_in_percent


FROM sys.dm_db_index_physical_stats (DB_ID (), NULL, NULL , NULL, null) AS p
 
                    INNER JOIN sys.objects as o 

                        ON p.object_id = o.object_id 

                    INNER JOIN sys.schemas as s 

                        ON s.schema_id = o.schema_id 

                    INNER JOIN sys.indexes i 

                        ON p.object_id = i.object_id 

                        AND i.index_id = p.index_id 

                WHERE p.page_count > 1000 and p.avg_fragmentation_in_percent >5
                AND p.index_id > 0 and s.name <> ''sys''
				;'
                
--print (@cmd1)                
exec sp_executesql @CMD1

select * from #work_table



Declare
@Object_name sysname,
@index_name sysname,
@SchemaName sysname,
@Fragmentation float,
@command1 nvarchar (max),
@command2 nvarchar (max),
@IDD Int
Set @IDD=1
while (1=1)
BEGIN
Select 
@Object_name =ObjectName,
@index_name= Indexname,
@SchemaName=Schemaname,
@Fragmentation=AFIP
from #work_table
where IDD=@IDD
IF @@ROWCOUNT=0
BREAK


If (@Fragmentation > 30)

BEGIN
SET @Command1 = N'USE ' + '['+@Dbname+']' + ' ; ALTER INDEX ' + '[' +@index_name +']' + N' ON '  + @SchemaName + '.' + '['+ @Object_name +']' 
+ N' REBUILD  WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)'
print (@Command1)
exec sp_executesql @command1
END

ELSE
BEGIN

SET @Command2 = N'USE ' + '['+@Dbname+']' + '; ALTER INDEX ' + '[' +@index_name +']'+  N' ON ' + @SchemaName + '.' +'['+ @Object_name+']'
+ N' REORGANIZE WITH ( LOB_COMPACTION = ON ) '
Print @command2
exec sp_executesql @command2
END
SET @IDD=@IDD+1

END
set @id=@id+1
END