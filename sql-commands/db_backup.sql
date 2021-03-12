USE [$(DBName)]
GO

DECLARE @backupPath NVARCHAR(4000); 
--SET @backupPath = '$(BackupPath)\$(DBName)\$(BackupFilename).bak';

EXEC master.dbo.xp_instance_regread 
            @rootkey = N'HKEY_LOCAL_MACHINE', 
            @key = N'Software\Microsoft\MSSQLServer\MSSQLServer',
			@value_name = N'BackupDirectory', 
            @value = @backupPath OUTPUT;

SET @backupPath = @backupPath + N'\$(DBName)\$(BackupFilename)';

PRINT N'Backing up database [$(DBName)] to ' + @backupPath

DECLARE @sql NVARCHAR(MAX);
SET @sql = N' BACKUP DATABASE [$(DBName)] TO DISK = N''' + @backupPath + N''' WITH COMPRESSION, STATS = 5, FORMAT;';

EXEC sp_executesql @sql;
GO
