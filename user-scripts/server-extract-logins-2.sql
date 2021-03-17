DECLARE @cmd nvarchar(max);
DECLARE cur CURSOR LOCAL FORWARD_ONLY STATIC
FOR
SELECT N'CREATE LOGIN ' + QUOTENAME(sp.name) + N'
WITH PASSWORD = ' + COALESCE(sys.fn_varbintohexstr(
    CONVERT(VARBINARY(MAX), LOGINPROPERTY(sp.name, 'PasswordHash')
    )), '') + N' HASHED
    , SID = ' + CONVERT(VARCHAR(40), sys.fn_varbintohexstr(sp.sid), 0) + N'
    ' + CASE WHEN sp.default_database_name IS NOT NULL THEN N', DEFAULT_DATABASE = ' + QUOTENAME(sp.default_database_name) ELSE N'' END + N'
    ' + CASE WHEN sp.default_language_name IS NOT NULL THEN N', DEFAULT_LANGUAGE = ' + sp.default_language_name ELSE N'' END + N'
    ' + CASE WHEN LOGINPROPERTY('SomeLogin', 'DaysUntilExpiration') IS NULL THEN N', CHECK_POLICY = OFF
    , CHECK_EXPIRATION = OFF' ELSE N'' END + N'
' + CASE WHEN sp.is_disabled = 1 THEN N'ALTER LOGIN ' + sp.name + N' DISABLE;
' ELSE N'' END + N'
'
FROM sys.server_principals sp
WHERE sp.type_desc = N'SQL_LOGIN'
    AND NOT (sp.name LIKE N'##%')
    AND NOT (sp.name = N'sa')
ORDER BY sp.name;
OPEN cur;
FETCH NEXT FROM cur INTO @cmd;
WHILE @@FETCH_STATUS = 0
BEGIN
    RAISERROR (@cmd, 0, 1) WITH NOWAIT;
    FETCH NEXT FROM cur INTO @cmd;
END
CLOSE cur;
DEALLOCATE cur;