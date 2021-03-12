
DECLARE @publicationDB AS sysname;
DECLARE @publication AS sysname;
DECLARE @subscriber AS sysname;
DECLARE @schemaowner AS sysname;

SET @publicationDB = N'$(DBName)'; 
SET @publication = N'$(DBName)_Transactional';
SET @subscriber = N'$(SubServer)';

USE [$(DBName)]
PRINT N'Removing subscription [] form [$(SubServer)].'
EXEC sp_dropsubscription 
  @publication = @publication, 
  @subscriber = @subscriber,
  @destination_db = @publicationDB,
  @article = N'all';


----- BEGIN: Add articles to the publication -----
PRINT N'Dropping table articles...';
DECLARE @tmpArticleTables TABLE([TableName] sysname, [SchemaName] sysname, [IsIdentity] bit, [HasPrimaryKey] bit)
INSERT INTO @tmpArticleTables([TableName], [SchemaName], [IsIdentity], [HasPrimaryKey])
SELECT 
	 t.[name] AS [TableName]
	,s.[name] AS [SchemaName]
	,CASE 
		WHEN SUM(CAST(c.[is_identity] AS int)) > 0 THEN CAST(1 AS bit) 
		ELSE CAST(0 AS bit) 
	END AS [IsIdentity]
	,CASE
		WHEN SUM(OBJECTPROPERTY(t.[object_id],'TableHasPrimaryKey')) > 0 THEN CAST(1 AS bit)
		ELSE CAST(0 AS BIT)
	END AS [HasPrimaryKey]
FROM 
	[sys].[tables] t 
	INNER JOIN [sys].[schemas] s ON t.[schema_id] = s.[schema_id] 
	INNER JOIN [sys].[columns] c ON c.[object_id] = t.[object_id]
WHERE 
	[is_ms_shipped] = 0 
	AND NOT t.[name] IN ('NeedsAggregationMetrics','fsOpenNeedsData','__MigrationHistory','TablesAndSchemas','DatabaseSettings') 
	AND s.[name] IN ('dbo','Dashboards')
GROUP BY 
	 s.[name]
	,t.[name]

DECLARE @CurrTable sysname

DECLARE @isIdentity bit
WHILE (SELECT COUNT(*) FROM @tmpArticleTables) > 0
BEGIN
	SELECT TOP 1 
		@CurrTable = [TableName],
        @schemaowner = [SchemaName],
		@isIdentity = [IsIdentity]
	FROM @tmpArticleTables

	PRINT N'Dropping article for table [' + @schemaowner + '].['+ @CurrTable +'].';
	
	IF @isIdentity = 1
	BEGIN
    EXEC sp_dropsubscription 
      @publication = @publication, 
      @article = @CurrTable, 
      @subscriber = N'all',
      @destination_db = N'all';

    EXEC sp_droparticle 
      @publication = @publication, 
      @article = @CurrTable, 
      @force_invalidate_snapshot = 1;
	END
	
	DELETE FROM @tmpArticleTables 
	WHERE [TableName] = @CurrTable
END


PRINT N'Dropping stored procedure articles...';
DECLARE @tmpArticleProcs TABLE([ProcName] sysname, [SchemaName] sysname)
INSERT INTO @tmpArticleProcs([ProcName], [SchemaName])
SELECT
	p.[name] AS [ProcName]
	,s.[name] AS [SchemaName]
FROM 
	[sys].[procedures] p
	INNER JOIN [sys].[schemas] s ON p.[schema_id] = s.[schema_id] 
WHERE 
	p.[is_ms_shipped] = 0
	AND p.[Type] = 'P'
	AND s.[name] IN ('dbo','Dashboards')
GROUP BY 
	p.[name]
	,s.[name]

DECLARE @CurrProc sysname
WHILE (SELECT COUNT(*) FROM @tmpArticleProcs) > 0
BEGIN
	SELECT TOP 1 
		@CurrProc = [ProcName],
        @schemaowner = [SchemaName]
	FROM @tmpArticleProcs

	PRINT N'Dropping article for proc [' + @schemaowner + '].['+ @CurrProc +'].';

  EXEC sp_dropsubscription 
    @publication = @publication, 
    @article = @CurrProc, 
    @subscriber = N'all',
    @destination_db = N'all';

  EXEC sp_droparticle 
      @publication = @publication, 
      @article = @CurrProc, 
      @force_invalidate_snapshot = 1;

	DELETE FROM @tmpArticleProcs 
	WHERE [ProcName] = @CurrProc
END


PRINT N'Dropping function articles...';
DECLARE @tmpArticleFunc TABLE([FuncName] sysname, [SchemaName] sysname)
INSERT INTO @tmpArticleFunc([FuncName], [SchemaName])
SELECT 
	o.[name] AS [FuncName]
	,s.[name] AS [SchemaName]
FROM 
	[sys].[sql_modules] m 
	INNER JOIN [sys].[objects] o ON m.[object_id] = o.[object_id]
	INNER JOIN [sys].[schemas] s ON o.[schema_id] = s.[schema_id] 
WHERE 
	o.[type_desc] LIKE '%function%'
	AND s.[name] IN ('dbo','Dashboards')

DECLARE @CurrFunc sysname
WHILE (SELECT COUNT(*) FROM @tmpArticleFunc) > 0
BEGIN
	SELECT TOP 1 
		@CurrFunc = [FuncName],
        @schemaowner = [SchemaName]
	FROM @tmpArticleFunc

	PRINT N'Dropping article for function [' + @schemaowner + '].['+ @CurrFunc +'].';

  EXEC sp_dropsubscription 
    @publication = @publication, 
    @article = @CurrFunc, 
    @subscriber = N'all',
    @destination_db = N'all';

  EXEC sp_droparticle 
      @publication = @publication, 
      @article = @CurrFunc, 
      @force_invalidate_snapshot = 1;

	DELETE FROM @tmpArticleFunc 
	WHERE [FuncName] = @CurrFunc
END


PRINT N'Dropping view articles...';
DECLARE @tmpArticleViews TABLE([ViewName] sysname, [SchemaName] sysname)
SELECT
	v.[name] AS [ViewName]
	,s.[name] AS [SchemaName]
FROM 
	[sys].[views] v
	INNER JOIN [sys].[schemas] s ON v.[schema_id] = s.[schema_id] 
WHERE 
	v.[is_ms_shipped] = 0
	AND v.[Type] = 'V'
	AND NOT v.[name] IN ('fsOpenNeedsData')
	AND s.[name] IN ('dbo','Dashboards')
GROUP BY 
	v.[name]
	,s.[name]

DECLARE @CurrView sysname
WHILE (SELECT COUNT(*) FROM @tmpArticleViews) > 0
BEGIN
	SELECT TOP 1 
		@CurrView = [ViewName],
        @schemaowner = [SchemaName]
	FROM @tmpArticleViews

	PRINT N'Dropping article for view [' + @schemaowner + '].['+ @CurrView +'].';
	
  EXEC sp_dropsubscription 
    @publication = @publication, 
    @article = @CurrView, 
    @subscriber = N'all',
    @destination_db = N'all';

  EXEC sp_droparticle 
      @publication = @publication, 
      @article = @CurrView, 
      @force_invalidate_snapshot = 1;

	DELETE FROM @tmpArticleViews 
	WHERE [ViewName] = @CurrView
END
----- END: Add articles to the publication -----

GO