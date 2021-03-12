Function Get-BackupPath
{
	param( [string]$Server )
	
	$isNotDefaultInstance = $Server -Match "\\"

	if ($isNotDefaultInstance) {
		$data = Get-Item SQLSERVER:\SQL\$Server
	}
	else {
		$data = Get-Item SQLSERVER:\SQL\$Server\DEFAULT
	}

	return $data.BackupDirectory
}

Function Get-DataPath
{
	param( [string]$Server )
	
	$isNotDefaultInstance = $Server -Match "\\"

	if ($isNotDefaultInstance) {
		$data = Get-Item SQLSERVER:\SQL\$Server
	}
	else {
		$data = Get-Item SQLSERVER:\SQL\$Server\DEFAULT
	}

	return $data.DefaultFile
}

Function Get-LogPath
{
	param( [string]$Server )
	
	$isNotDefaultInstance = $Server -Match "\\"
	
	if ($isNotDefaultInstance) {
		$data = Get-Item SQLSERVER:\SQL\$Server
	}
	else {
		$data = Get-Item SQLSERVER:\SQL\$Server\DEFAULT
	}

	return $data.DefaultLog
}

Function Get-DefaultReplicationPath
{
	param( [string]$Server, [string]$Database )
	$distributor = Invoke-Sqlcmd -ServerInstance $Server -Database $Database -Query "EXEC sp_helpdistributor" -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
	return $distributor.directory
}

Function Get-RemoteBackupPath
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath )
	$SQLCmdParams = @("DBName=$Database")
	Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\server_get_backup_path.sql" -Variable $SQLCmdParams -OutputSqlErrors $FALSE -Verbose
}

Function Get-Connections
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath )
	$SQLCmdParams = @("DBName=$Database")
	Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\server_check_connections.sql" -Variable $SQLCmdParams -OutputSqlErrors $TRUE | Format-Table 
}

Function Set-RecoveryModel
{
	param( [string]$Server, [string]$Database )
	$SQLCmdParams = @("DBName=$Database")
	Invoke-Sqlcmd -ServerInstance $Server -Database $Database -Query "ALTER DATABASE [$($Database)] SET RECOVERY SIMPLE" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Continue
}

Function Start-Backup
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [string]$BackupPath, [string]$BackupFilename )
    $SQLCmdParams = @("DBName=$Database","BackupPath=$BackupPath","BackupFilename=$BackupFilename")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_backup.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
}

Function Start-Restore
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [string]$DataPath, [string]$LogPath, [string]$BackupPath, [string]$BackupFileName )
	$SQLCmdParams = @("DBName=$Database","MdfPath=$DataPath","LdfPath=$LogPath", "backupPath=$BackupPath", "backupFilename=$BackupFileName")
	Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_restore.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
}

Function Set-Permissions
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath )
	$SQLCmdParams = @("DBName=$Database")
	Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_permissions.sql" -Variable $SQLCmdParams -OutputSqlErrors $TRUE -Verbose
}

Function Invoke-SqlcmdFile
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [int]$Timeout = 30 )
	Write-Verbose "QueryTimeout: $($Timeout)"
	$SQLCmdParams = @("DBName=$Database")
	Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath" -Variable $SQLCmdParams -QueryTimeout $Timeout -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
}


<# Merge Replication #>
Function Get-MergeReplicationSubscribers
{
	param( [string]$Server, [string]$Database )
	$subscribers = Invoke-Sqlcmd -ServerInstance $Server -Database $Database -Query "SELECT [subscriber_server] FROM [dbo].[sysmergesubscriptions] WHERE [subscription_type] = 1 AND [db_name] = N'$($Database)'" -OutputSqlErrors $TRUE -Verbose -ErrorAction Continue
	return $subscribers
}

Function Start-CreateMergeReplicationPublisher
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [string[]]$Subscribers, [int]$Minutes )
    $SQLCmdParams = @("DBName=$Database","Publisher=$Server","Minutes=$Minutes")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_merge_replication_publisher_create.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop

	foreach($sub in $script:Subscribers.split(","))
	{
		$SQLCmdParams2 = @("DBName=$Database","Subscriber=$sub")
		Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_merge_replication_publisher_create_subscription.sql" -Variable $SQLCmdParams2 -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
	}

	Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_merge_replication_publisher_create_snapshot.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
}

Function Start-CreateMergeReplicationSubscriber
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [string]$Publisher, [int]$Minutes )
    $SQLCmdParams = @("DBName=$Database","Publisher=$Publisher", "Minutes=$Minutes")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_merge_replication_subscriber_create.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
}

Function Start-DropMergeReplicationPublisher
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath )
    $SQLCmdParams = @("DBName=$Database")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_merge_replication_publisher_drop.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Continue
}

Function Start-DropMergeReplicationSubscriber
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [string]$Publisher )
    $SQLCmdParams = @("DBName=$Database","Publisher=$Publisher")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_merge_replication_subscriber_drop.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Continue
}



<# Transactional Replication #>
Function Get-TransReplicationSubscribers
{
	param( [string]$Server, [string]$Database )
	$subscribers = Invoke-Sqlcmd -ServerInstance $Server -Database $Database -Query "SELECT DISTINCT [srvname] AS [subscriber_server] FROM [dbo].[syssubscriptions] WHERE [srvname] IS NOT NULL AND [dest_db] = N'$($Database)'" -OutputSqlErrors $TRUE -Verbose -ErrorAction Continue
	return $subscribers
}

Function Start-CreateTransReplicationPublisher
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [string[]]$Subscribers )
    $SQLCmdParams = @("DBName=$Database","Publisher=$Server")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_transactional_replication_publisher_create_publication.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop

	foreach($sub in $script:Subscribers.split(","))
	{
		$SQLCmdParams2 = @("DBName=$Database","SubServer=$sub")
		Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_transactional_replication_publisher_create_subscription.sql" -Variable $SQLCmdParams2 -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
	}

	Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_transactional_replication_publisher_create_snapshot.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
}

Function Start-CreateTransReplicationSubscriber
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [string]$Publisher )
    $SQLCmdParams = @("DBName=$Database","Publisher=$Publisher")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_transactional_replication_subscriber_create.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Stop
}

Function Start-DropTransReplicationPublisher
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath )
    $SQLCmdParams = @("DBName=$Database")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_transactional_replication_publisher_drop_publication.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Continue
}

Function Start-DropTransReplicationPublisherSubscription
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [string]$Subscriber )
    $SQLCmdParams = @("DBName=$Database", "SubServer=$Subscriber")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_transactional_replication_publisher_drop_subscription.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Continue
}

Function Start-DropTransReplicationSubscriber
{
	param( [string]$Server, [string]$Database, [string]$InputFilePath, [string]$Publisher )
    $SQLCmdParams = @("DBName=$Database","PubServer=$Publisher", "SubServer=$Server")
    Invoke-Sqlcmd -ServerInstance $Server -InputFile "$InputFilePath\db_transactional_replication_subscriber_drop_subscription.sql" -Variable $SQLCmdParams -QueryTimeout 0 -OutputSqlErrors $TRUE -Verbose -ErrorAction Continue
}
