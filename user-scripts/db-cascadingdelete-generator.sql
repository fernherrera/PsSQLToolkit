/*----------------------------------------------------------------------------
Script for executing or generating cascading delete scripts.
http://connectsql.blogspot.co.il/2011/03/sql-server-cascade-delete.html

Usage example 1

Note the use of the fully qualified column name in the example. It's subtle but you must specify the table name for the generated SQL to execute properly.

EXEC uspCascadeDelete
@ParentTableId = 'Production.Location',
@WhereClause = 'Location.LocationID = 2'

Usage example 2
EXEC uspCascadeDelete
@ParentTableId = 'dbo.brand',
@WhereClause = 'brand.brand_name <> ''Apple'''

Usage example 3
exec uspCascadeDelete
@ParentTableId = 'dbo.product_type',
@WhereClause = 'product_type.product_type_id NOT IN 
(SELECT bpt.product_type_id FROM dbo.brand_product_type bpt)'

----------------------------------------------------------------------------*/

PRINT N'---------------------------------------------------------'
PRINT N'Creating supporting functions and sprocs...'
PRINT N'---------------------------------------------------------'

PRINT N'Dropping dbo.udfGetFullQualName'
GO
IF OBJECT_ID('dbo.udfGetFullQualName') IS NOT NULL
    DROP FUNCTION dbo.udfGetFullQualName;
GO

PRINT N'Creating dbo.udfGetFullQualName'
GO
CREATE FUNCTION dbo.udfGetFullQualName
(@ObjectId INT)
RETURNS VARCHAR (300)
AS
BEGIN
    DECLARE @schema_id AS BIGINT;
    SELECT @schema_id = schema_id
    FROM   sys.tables
    WHERE  object_id = @ObjectId;
    RETURN '[' + SCHEMA_NAME(@schema_id) + '].[' + OBJECT_NAME(@ObjectId) + ']';
END
GO

--============ Supporting Function dbo.udfGetOnJoinClause
PRINT N'Dropping dbo.udfGetOnJoinClause'
GO
IF OBJECT_ID('dbo.udfGetOnJoinClause') IS NOT NULL
    DROP FUNCTION dbo.udfGetOnJoinClause;
GO

PRINT N'Creating dbo.udfGetOnJoinClause'
GO
CREATE FUNCTION dbo.udfGetOnJoinClause
(@fkNameId INT)
RETURNS VARCHAR (1000)
AS
BEGIN
    DECLARE @OnClauseTemplate AS VARCHAR (1000);
    SET @OnClauseTemplate = '[<@pTable>].[<@pCol>] = [<@cTable>].[<@cCol>] AND ';
    DECLARE @str AS VARCHAR (1000);
    SET @str = '';
    SELECT @str = @str + REPLACE(REPLACE(REPLACE(REPLACE(@OnClauseTemplate, '<@pTable>', OBJECT_NAME(rkeyid)), '<@pCol>', COL_NAME(rkeyid, rkey)), '<@cTable>', OBJECT_NAME(fkeyid)), '<@cCol>', COL_NAME(fkeyid, fkey))
    FROM   dbo.sysforeignkeys AS fk
    WHERE  fk.constid = @fkNameId; --OBJECT_ID('FK_ProductArrearsMe_ProductArrears')
    RETURN LEFT(@str, LEN(@str) - LEN(' AND '));
END

GO
--=========== CASECADE DELETE STORED PROCEDURE dbo.uspCascadeDelete
PRINT N'Dropping dbo.uspCascadeDelete'
GO
IF OBJECT_ID('dbo.uspCascadeDelete') IS NOT NULL
    DROP PROCEDURE dbo.uspCascadeDelete;
GO

PRINT N'Creating dbo.uspCascadeDelete'
GO
CREATE PROCEDURE dbo.uspCascadeDelete
@ParentTableId VARCHAR (300), 
@WhereClause VARCHAR (2000), 
@ExecuteDelete CHAR (1)='N', --'N' IF YOU NEED DELETE SCRIPT
@FromClause VARCHAR (8000)='', 
@Level INT=0 -- TABLE NAME OR OBJECT (TABLE) ID (Production.Location) WHERE CLAUSE (Location.LocationID = 7) 'Y' IF WANT TO DELETE DIRECTLY FROM SP,  IF LEVEL 0, THEN KEEP DEFAULT
AS -- writen by Daniel Crowther 16 Dec 2004 - handles composite primary keys
SET NOCOUNT ON;
/* Set up debug */
DECLARE @DebugMsg AS VARCHAR (4000), 
@DebugIndent AS VARCHAR (50);
SET @DebugIndent = REPLICATE('---', @@NESTLEVEL) + '> ';
IF ISNUMERIC(@ParentTableId) = 0
    BEGIN -- assume owner is dbo and calculate id
        IF CHARINDEX('.', @ParentTableId) = 0
            SET @ParentTableId = OBJECT_ID('[dbo].[' + @ParentTableId + ']');
        ELSE
            SET @ParentTableId = OBJECT_ID(@ParentTableId);
    END
IF @Level = 0
    BEGIN
        PRINT @DebugIndent + ' **************************************************************************';
        PRINT @DebugIndent + ' *** Cascade delete ALL data from ' + dbo.udfGetFullQualName(@ParentTableId);
        IF @ExecuteDelete = 'Y'
            PRINT @DebugIndent + ' *** @ExecuteDelete = Y *** deleting data...';
        ELSE
            PRINT @DebugIndent + ' *** Cut and paste output into another window and execute ***';
    END
DECLARE @CRLF AS CHAR (2);
SET @CRLF = CHAR(13) + CHAR(10);
DECLARE @strSQL AS VARCHAR (4000);
IF @Level = 0
    SET @strSQL = 'SET NOCOUNT ON' + @CRLF;
ELSE
    SET @strSQL = '';
SET @strSQL = @strSQL + 'PRINT ''' + @DebugIndent + dbo.udfGetFullQualName(@ParentTableId) + ' Level=' + CAST (@@NESTLEVEL AS VARCHAR) + '''';
IF @ExecuteDelete = 'Y'
    EXECUTE (@strSQL);
ELSE
    PRINT @strSQL;
DECLARE curs_children CURSOR LOCAL FORWARD_ONLY
    FOR SELECT DISTINCT constid AS fkNameId, -- constraint name
                        fkeyid AS cTableId
        FROM   dbo.sysforeignkeys AS fk
        WHERE  fk.rkeyid <> fk.fkeyid -- WE DO NOT HANDLE self referencing tables!!!
               AND fk.rkeyid = @ParentTableId;
OPEN curs_children;
DECLARE @fkNameId AS INT, 
@cTableId AS INT, 
@cColId AS INT, 
@pTableId AS INT, 
@pColId AS INT;
FETCH NEXT FROM curs_children INTO @fkNameId, @cTableId; --, @cColId, @pTableId, @pColId
DECLARE @strFromClause AS VARCHAR (1000);
DECLARE @nLevel AS INT;
IF @Level = 0
    BEGIN
        SET @FromClause = 'FROM ' + dbo.udfGetFullQualName(@ParentTableId);
    END
WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @strFromClause = @FromClause + @CRLF + '      INNER JOIN ' + dbo.udfGetFullQualName(@cTableId) + @CRLF + '       ON ' + dbo.udfGetOnJoinClause(@fkNameId);
        SET @nLevel = @Level + 1;
        EXECUTE dbo.uspCascadeDelete @ParentTableId = @cTableId, @WhereClause = @WhereClause, @ExecuteDelete = @ExecuteDelete, @FromClause = @strFromClause, @Level = @nLevel;
        SET @strSQL = 'DELETE FROM ' + dbo.udfGetFullQualName(@cTableId) + @CRLF + @strFromClause + @CRLF + 'WHERE   ' + @WhereClause + @CRLF;
        SET @strSQL = @strSQL + 'PRINT ''---' + @DebugIndent + 'DELETE FROM ' + dbo.udfGetFullQualName(@cTableId) + '     Rows Deleted: '' + CAST(@@ROWCOUNT AS VARCHAR)' + @CRLF + @CRLF;
        IF @ExecuteDelete = 'Y'
            EXECUTE (@strSQL);
        ELSE
            PRINT @strSQL;
        FETCH NEXT FROM curs_children INTO @fkNameId, @cTableId;
    --, @cColId, @pTableId, @pColId
    END
IF @Level = 0
    BEGIN
        SET @strSQL = @CRLF + 'PRINT ''' + @DebugIndent + dbo.udfGetFullQualName(@ParentTableId) + ' Level=' + CAST (@@NESTLEVEL AS VARCHAR) + ' TOP LEVEL PARENT TABLE''' + @CRLF;
        SET @strSQL = @strSQL + 'DELETE FROM ' + dbo.udfGetFullQualName(@ParentTableId) + ' WHERE ' + @WhereClause + @CRLF;
        SET @strSQL = @strSQL + 'PRINT ''' + @DebugIndent + 'DELETE FROM ' + dbo.udfGetFullQualName(@ParentTableId) + ' Rows Deleted: '' + CAST(@@ROWCOUNT AS VARCHAR)' + @CRLF;
        IF @ExecuteDelete = 'Y'
            EXECUTE (@strSQL);
        ELSE
            PRINT @strSQL;
    END
CLOSE curs_children;
DEALLOCATE curs_children;



/*----------------------------------------------------------------------------

To remove the functions and sprocs run the code below.

PRINT N'Dropping dbo.udfGetFullQualName'
GO
IF OBJECT_ID('dbo.udfGetFullQualName') IS NOT NULL
    DROP FUNCTION dbo.udfGetFullQualName;
GO

PRINT N'Dropping dbo.udfGetOnJoinClause'
GO
IF OBJECT_ID('dbo.udfGetOnJoinClause') IS NOT NULL
    DROP FUNCTION dbo.udfGetOnJoinClause;
GO

PRINT N'Dropping dbo.uspCascadeDelete'
GO
IF OBJECT_ID('dbo.uspCascadeDelete') IS NOT NULL
    DROP PROCEDURE dbo.uspCascadeDelete;
GO

----------------------------------------------------------------------------*/