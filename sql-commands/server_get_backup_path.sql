
-- Get Default SQL Server Backup Folder
DECLARE @path NVARCHAR(4000) 
EXEC master.dbo.xp_instance_regread 
            @rootkey = N'HKEY_LOCAL_MACHINE', 
            @key = N'Software\Microsoft\MSSQLServer\MSSQLServer',
			@value_name = N'BackupDirectory', 
            @value = @path OUTPUT
SELECT @path AS [Path]