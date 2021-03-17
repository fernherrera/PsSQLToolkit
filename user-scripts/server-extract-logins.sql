-- Scripting Out the Logins, Server Role Assignments, and Server Permissions
-- ************************************************************************************************************************
-- Copyright © 2015 by JP Chen of DatAvail Corporation
-- This script is free for non-commercial purposes with no warranties. 

-- CRITICAL NOTE: You’ll need to change your results to display more characters in the query result.
-- Under Tools –> Options –> Query Results –> SQL Server –> Results to Text to increase the maximum number of characters 
-- returned to 8192 the maximum or to a number high enough to prevent the results being truncated.
-- ************************************************************************************************************************

USE [master]
GO

---[ Create Temp Stored Proc ]------------------------------------------------
/****** Object:  StoredProcedure [dbo].[sp_hexadecimal]    Script Date: 9/30/2013 6:25:17 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE #sp_hexadecimal
(
    @binvalue varbinary(256),
    @hexvalue varchar (514) OUTPUT
)
AS
BEGIN
	DECLARE @charvalue varchar (514)
	DECLARE @i int
	DECLARE @length int
	DECLARE @hexstring char(16)
	SELECT @charvalue = '0x'
	SELECT @i = 1
	SELECT @length = DATALENGTH (@binvalue)
	SELECT @hexstring = '0123456789ABCDEF'
	
	WHILE (@i <= @length)
	BEGIN
	  DECLARE @tempint int
	  DECLARE @firstint int
	  DECLARE @secondint int
	  SELECT @tempint = CONVERT(int, SUBSTRING(@binvalue,@i,1))
	  SELECT @firstint = FLOOR(@tempint/16)
	  SELECT @secondint = @tempint - (@firstint*16)
	  SELECT @charvalue = @charvalue +
		SUBSTRING(@hexstring, @firstint+1, 1) +
		SUBSTRING(@hexstring, @secondint+1, 1)
	  SELECT @i = @i + 1
	END

	SELECT @hexvalue = @charvalue;
END;
GO
------------------------------------------------------------------------------

---[ Create Temp Stored Proc ]------------------------------------------------
CREATE PROCEDURE #sp_help_revlogin
	@login_name sysname = NULL AS
DECLARE @name sysname
DECLARE @type varchar (1)
DECLARE @hasaccess int
DECLARE @denylogin int
DECLARE @is_disabled int
DECLARE @PWD_varbinary  varbinary (256)
DECLARE @PWD_string  varchar (514)
DECLARE @SID_varbinary varbinary (85)
DECLARE @SID_string varchar (514)
DECLARE @tmpstr  varchar (1024)
DECLARE @is_policy_checked varchar (3)
DECLARE @is_expiration_checked varchar (3)

DECLARE @defaultdb sysname
 
IF (@login_name IS NULL)
	DECLARE login_curs CURSOR FOR
	SELECT p.sid, p.name, p.type, p.is_disabled, p.default_database_name, l.hasaccess, l.denylogin 
	FROM sys.server_principals p 
	LEFT JOIN sys.syslogins l ON ( l.name = p.name ) WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name <> 'sa'

ELSE
	DECLARE login_curs CURSOR FOR
	SELECT p.sid, p.name, p.type, p.is_disabled, p.default_database_name, l.hasaccess, l.denylogin 
	FROM sys.server_principals p LEFT JOIN sys.syslogins l ON ( l.name = p.name ) WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name = @login_name

OPEN login_curs

FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
IF (@@fetch_status = -1)
BEGIN
  PRINT 'No login(s) found.'
  CLOSE login_curs
  DEALLOCATE login_curs
  RETURN -1
END

SET @tmpstr = '/* sp_help_revlogin script '
PRINT @tmpstr
SET @tmpstr = '** Generated ' + CONVERT (varchar, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
PRINT @tmpstr
PRINT ''
WHILE (@@fetch_status <> -1)
BEGIN
  IF (@@fetch_status <> -2)
  BEGIN
    PRINT ''
    SET @tmpstr = '-- Login: ' + @name
    PRINT @tmpstr
    
	IF (@type IN ( 'G', 'U'))
    BEGIN -- NT authenticated account/group
      SET @tmpstr = 'IF (SUSER_ID('+QUOTENAME(@name,'''')+') IS NULL) BEGIN CREATE LOGIN ' + QUOTENAME( @name ) + ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + ']'
    END
    ELSE BEGIN -- SQL Server authentication
        -- obtain password and sid
        SET @PWD_varbinary = CAST( LOGINPROPERTY( @name, 'PasswordHash' ) AS varbinary (256) )
        EXEC #sp_hexadecimal @PWD_varbinary, @PWD_string OUT
        EXEC #sp_hexadecimal @SID_varbinary,@SID_string OUT
 
        -- obtain password policy state
        SELECT @is_policy_checked = CASE is_policy_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name
        SELECT @is_expiration_checked = CASE is_expiration_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name
 
        SET @tmpstr = 'IF (SUSER_ID('+QUOTENAME(@name,'''')+') IS NULL) BEGIN CREATE LOGIN ' + QUOTENAME( @name ) + ' WITH PASSWORD = ' + @PWD_string + ' HASHED, SID = ' + @SID_string + ', DEFAULT_DATABASE = [' + @defaultdb + ']'

        IF ( @is_policy_checked IS NOT NULL )
        BEGIN
          SET @tmpstr = @tmpstr + ', CHECK_POLICY = ' + @is_policy_checked
        END

        IF ( @is_expiration_checked IS NOT NULL )
        BEGIN
          SET @tmpstr = @tmpstr + ', CHECK_EXPIRATION = ' + @is_expiration_checked
        END
    END
    
	IF (@denylogin = 1)
    BEGIN -- login is denied access
      SET @tmpstr = @tmpstr + '; DENY CONNECT SQL TO ' + QUOTENAME( @name )
    END

    ELSE IF (@hasaccess = 0)
    BEGIN -- login exists but does not have access
      SET @tmpstr = @tmpstr + '; REVOKE CONNECT SQL TO ' + QUOTENAME( @name )
    END
    
	IF (@is_disabled = 1)
    BEGIN -- login is disabled
      SET @tmpstr = @tmpstr + '; ALTER LOGIN ' + QUOTENAME( @name ) + ' DISABLE'
    END

	SET @tmpstr = @tmpstr + ' END;'

    PRINT @tmpstr
  END

  FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
   END
CLOSE login_curs
DEALLOCATE login_curs
RETURN 0;
GO
------------------------------------------------------------------------------

--EXEC #sp_help_revlogin

SET NOCOUNT ON
------------------------------------------------------------------------------

EXEC #sp_help_revlogin

------------------------------------------------------------------------------
/*
-- Scripting Out the Logins To Be Created
SELECT 'IF (SUSER_ID('+QUOTENAME(SP.name,'''')+') IS NULL) BEGIN CREATE LOGIN ' +QUOTENAME(SP.name)+
			   CASE 
					WHEN SP.type_desc = 'SQL_LOGIN' 
						THEN ' WITH PASSWORD = ' + CONVERT(NVARCHAR(MAX),SL.password_hash,1) 
							+ ' HASHED, CHECK_EXPIRATION = ' + CASE WHEN SL.is_expiration_checked = 1 THEN 'ON' ELSE 'OFF' END 
							+ ', CHECK_POLICY = ' + CASE WHEN SL.is_policy_checked = 1 THEN 'ON,' ELSE 'OFF,' END
						ELSE ' FROM WINDOWS WITH'
				END 
	   +' DEFAULT_DATABASE=[' +SP.default_database_name+ '], DEFAULT_LANGUAGE=[' +SP.default_language_name+ '] END;' COLLATE SQL_Latin1_General_CP1_CI_AS AS [-- Logins To Be Created --]
FROM sys.server_principals AS SP 
LEFT JOIN sys.sql_logins AS SL ON SP.principal_id = SL.principal_id
WHERE 
	SP.type IN ('S','G','U')
	AND SP.name NOT LIKE '##%##'
	AND SP.name NOT LIKE 'NT AUTHORITY%'
	AND SP.name NOT LIKE 'NT SERVICE%'
	AND SP.name <> ('sa');
*/
------------------------------------------------------------------------------

-- Scripting Out the Role Membership to Be Added
SELECT 
'EXEC master..sp_addsrvrolemember @loginame = N''' + SL.name + ''', @rolename = N''' + SR.name + '''' AS [-- Server Roles the Logins Need to be Added --]
FROM master.sys.server_role_members SRM
	JOIN master.sys.server_principals SR ON SR.principal_id = SRM.role_principal_id
	JOIN master.sys.server_principals SL ON SL.principal_id = SRM.member_principal_id
WHERE 
	SL.type IN ('S','G','U')
	AND SL.name NOT LIKE '##%##'
	AND SL.name NOT LIKE 'NT AUTHORITY%'
	AND SL.name NOT LIKE 'NT SERVICE%'
	AND SL.name <> ('sa');

------------------------------------------------------------------------------

-- Scripting out the Permissions to Be Granted
SELECT 
	CASE WHEN SrvPerm.state_desc <> 'GRANT_WITH_GRANT_OPTION' 
		THEN SrvPerm.state_desc 
		ELSE 'GRANT' 
	END
    + ' ' + SrvPerm.permission_name + ' TO [' + SP.name + ']' + 
	CASE WHEN SrvPerm.state_desc <> 'GRANT_WITH_GRANT_OPTION' 
		THEN '' 
		ELSE ' WITH GRANT OPTION' 
	END collate database_default AS [-- Server Level Permissions to Be Granted --] 
FROM sys.server_permissions AS SrvPerm 
	JOIN sys.server_principals AS SP ON SrvPerm.grantee_principal_id = SP.principal_id 
WHERE
	SP.type IN ( 'S', 'U', 'G' ) 
	AND SP.name NOT LIKE '##%##'
	AND SP.name NOT LIKE 'NT AUTHORITY%'
	AND SP.name NOT LIKE 'NT SERVICE%'
	AND SP.name <> ('sa');

------------------------------------------------------------------------------
SET NOCOUNT OFF

DROP PROCEDURE #sp_hexadecimal;
DROP PROCEDURE #sp_help_revlogin;