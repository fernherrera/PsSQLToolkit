
<###[Parameters]################################>
param(
	[parameter(Mandatory=$true, HelpMessage="-Server parameter is required")]
	[string]$Server,

	[parameter(Mandatory=$true, HelpMessage="-Database parameter is required")]
	[string]$Database,

	[int]$QueryTimeout = 30,

	<# RunScript #>
	[switch]$Exec,
	<#[ValidateScript({Test-Path $_})]#>
	[string]$ScriptFile,

	<# Apply Permissions #>
	[switch]$ApplyPermissions,

	<# Backup #>
	[switch]$BackupDB,
	[string]$backupFilename,
	
	<# CopyDB #>
	[switch]$CopyDB,
	[switch]$UseLastBackup,
	[switch]$RecoveryModelSimple,
	[string]$SourceServer,
	[string]$SourceDatabase,

	<# Replication #>
	[switch]$CreateMergeReplicationPublisher,
	[switch]$DropMergeReplicationPublisher,
	[switch]$CreateMergeReplicationSubscriber,
	[switch]$DropMergeReplicationSubscriber,

	[switch]$CreateTransReplicationPublisher,
	[switch]$DropTransReplicationPublisher,
	[switch]$CreateTransReplicationSubscriber,
	[switch]$DropTransReplicationSubscriber,

	[string]$Publisher,
	[string[]]$Subscribers,
	[int]$StartTime
)
	
<###[Variables]#################################>
$Localhost = $env:computername
$LogFile = "$PSScriptRoot\logs\$(Get-Date -format "yyyy-MM-dd").log"
$script:ModulePath = "$PSScriptRoot\modules"
$script:SqlOpsPath = "$PSScriptRoot\sql-commands"
$script:UserScriptPath = "$PSScriptRoot\user-scripts"

<###[Load Modules]##############################>
Import-Module sqlps
Import-Module $script:ModulePath\utilities.ps1
Import-Module $script:ModulePath\sql.ps1

<###[Set Paths]#################################>
$script:SQLBackupPath = Get-BackupPath -Server $Server
$script:SQLDataPath = Get-DataPath -Server $Server
$script:SQLLogPath = Get-LogPath -Server $Server
$script:RemoteBackupPath = $null

<###[Functions]#################################>
Function Test-Parameters
{
	if (($script:Exec) -and !($script:ScriptFile))
	{
		Write-Error -Message "-ScriptFile parameter not set."
		exit
	}

	if (($script:BackupDB) -and !($script:backupFilename))
	{
		Write-Error -Message "-backupFilename parameter not set."
		exit
	}

	if (($script:CopyDB))
	{
		if (!$script:SourceServer)
		{
			Write-Error -Message "-SourceServer parameter is required."
			exit
		}

		if (!$script:SourceDatabase)
		{
			Write-Error -Message "-SourceDatabase parameter is required."
			exit
		}

		if ($script:Localhost -eq $script:SourceServer)
		{
			Write-Error -Message "-SourceServer must be a remote server to copy from."
			exit
		}

		if (!$script:SQLBackupPath)
		{
			Write-Error -Message "Unable to get local backup path."
			exit
		}
		
		if (!$script:SQLDataPath)
		{
			Write-Error -Message "Unable to get local data(MDF) file path."
			exit
		}

		if (!$script:SQLLogPath)
		{
			Write-Error -Message "Unable to get local log(LDF) file path."
			exit
		}			

		$script:RemoteBackupPath = Get-RemoteBackupPath -Server $script:SourceServer -Database "master" -InputFilePath $script:SqlOpsPath
		if (!$script:RemoteBackupPath)
		{
			Write-Error "Unable to get remote backup path."
			exit
		}
	}

	if (($script:CreateMergeReplicationPublisher))
	{
		if (!($script:StartTime))
		{
			Write-Error -Message "-StartTime parameter is required."
			exit
		}

		if (!($script:Subscribers))
		{
			Write-Error -Message "-Subscribers parameter is required."
			exit
		}
	}

	if (($script:DropMergeReplicationPublisher) -and !($script:Publisher))
	{
		Write-Error -Message "-Publisher parameter is required."
		exit
	}

	if (($script:DropTransReplicationPublisher) -and !($script:Publisher))
	{
		Write-Error -Message "-Publisher parameter is required."
		exit
	}

	if (($script:CreateMergeReplicationSubscriber))
	{
		if (!($script:Publisher))
		{
			Write-Error -Message "-Publisher parameter is required."
			exit
		}

		if (!($script:StartTime))
		{
			Write-Error -Message "-StartTime parameter is required."
			exit
		}
	}

	if (($script:DropMergeReplicationSubscriber) -and !($script:Publisher))
	{
		Write-Error -Message "-Publisher parameter is required."
		exit
	}

	if (($script:DropTransReplicationSubscriber) -and !($script:Publisher))
	{
		Write-Error -Message "-Publisher parameter is required."
		exit
	}
}

Function Show-Script-Header 
{
	Write-Verbose "=============================================================================="
	Write-Verbose "  Powershell SQL Automation"
	Write-Verbose "=============================================================================="
	Write-Verbose "SQL Server              : $($script:Server)"
	Write-Verbose "Database                : $($script:Database)"
	Write-Verbose "Query Timeout           : $($script:QueryTimeout)"
	Write-Verbose "Data file location      : $($script:SQLDataPath)"
	Write-Verbose "Log file location       : $($script:SQLLogPath)"
	Write-Verbose "Backup file location    : $($script:SQLBackupPath)"

	if ($script:ApplyPermissions)
	{
		Write-Verbose "Apply Permissions       : $($script:ApplyPermissions)"
	}

	if ($script:BackupDB)
	{
		Write-Verbose "Backup DB               : $($script:BackupDB)"
		Write-Verbose "Backup Filename         : $($script:backupFilename)"
	}

	if ($script:CopyDB)
	{
		Write-Verbose "Copy DB                 : $($script:CopyDB)"
		Write-Verbose "Use last backup         : $($script:UseLastBackup)"
		Write-Verbose "Source Server           : $($script:SourceServer)"
		Write-Verbose "Source Database         : $($script:SourceDatabase)"
	}

	if ($script:Exec)
	{
		Write-Verbose "Action                  : Exec"
		Write-Verbose "Script File             : $($script:ScriptFile)"
	}

	if ($script:DropMergeReplicationPublisher) 
	{
		Write-Verbose "Drop merge replication (Publisher)    : $($script:DropMergeReplicationPublisher)"
		Write-Verbose "Publisher               : $($script:Publisher)"
		Write-Verbose "Subscribers             : $($script:Subscribers)"
	}

	if ($script:DropMergeReplicationSubscriber) 
	{
		Write-Verbose "Drop merge replication (Subscriber)    : $($script:DropMergeReplicationSubscriber)"
		Write-Verbose "Publisher               : $($script:Publisher)"
	}

	if ($script:CreateMergeReplicationPublisher) 
	{
		Write-Verbose "Create merge replication (Publisher)  : $($script:CreateMergeReplicationPublisher)"
		Write-Verbose "Publisher               : $($script:Publisher)"
	}

	if ($script:CreateMergeReplicationSubscriber) 
	{
		Write-Verbose "Create merge replication (Subscriber)  : $($script:CreateMergeReplicationSubscriber)"
		Write-Verbose "Publisher               : $($script:Publisher)"
		Write-Verbose "Start Time              : $($script:StartTime)"
	}

	if ($script:DropTransReplicationPublisher) 
	{
		Write-Verbose "Drop trans replication (Publisher)    : $($script:DropTransReplicationPublisher)"
		Write-Verbose "Publisher               : $($script:Publisher)"
		Write-Verbose "Subscribers             : $($script:Subscribers)"
	}

	if ($script:DropTransReplicationSubscriber) 
	{
		Write-Verbose "Drop trans replication (Subscriber)    : $($script:DropTransReplicationSubscriber)"
		Write-Verbose "Publisher               : $($script:Publisher)"
	}

	if ($script:CreateTransReplicationPublisher) 
	{
		Write-Verbose "Create trans replication (Publisher)  : $($script:CreateTransReplicationPublisher)"
		Write-Verbose "Publisher               : $($script:Publisher)"
	}	
	
	Write-Verbose "---------------------------------------------------`n"
}

Function Start-Main
{
	Show-Script-Header

	if ($script:BackupDB)
	{
		TimedCommandBlock "Backup database ($($Database))..." { Start-Backup -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath -BackupPath $script:SQLBackupPath -BackupFilename $backupFilename }
	}

	if ($script:CopyDB)
	{
		$BackupLocationUNCPath = "\\$($script:SourceServer)\$($script:RemoteBackupPath.Path.Replace(':', '$'))\$SourceDatabase"

		if ($UseLastBackup)
		{
			$LastFullBackup = Get-NewestFile -Path $BackupLocationUNCPath -Filter "*.bak"
			$BackupFilename = $LastFullBackup.Name
		}
		else 
		{
			$BackupFilename = "$($script:SourceDatabase).bak"

			TimedCommandBlock "Backup database ($($SourceDatabase))..." { Start-Backup -Server $script:SourceServer -Database $script:SourceDatabase -InputFilePath $script:SqlOpsPath -BackupPath $script:SQLBackupPath -BackupFilename $BackupFilename }
			TimedCommandBlock "Wait for backup to finish writing to disk..." { timeout 30 /nobreak }
		}

		if (!$BackupFilename)
		{
			Write-Error "Unable to get last backup file."
			exit
		}

		TimedCommandBlock "Copying database backup ($($BackupFilename))..." { robocopy "$BackupLocationUNCPath" "$SQLBackupPath\$Database" "$BackupFilename" /z /np | Out-Default }
		TimedCommandBlock "Restore DB backup..." { Start-Restore -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath -DataPath $script:SQLDataPath -LogPath $script:SQLLogPath -BackupPath "$script:SQLBackupPath\$Database" -BackupFileName "$BackupFilename" }
		TimedCommandBlock "Set Permissions on $($Database)..." { Set-Permissions -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath }
		TimedCommandBlock "Removing file ($($BackupFilename))..." { Remove-Item "$SQLBackupPath\$Database\$BackupFilename" }

		if ($RecoveryModelSimple)
		{
			TimedCommandBlock "Setting Recovery model to Simple ($($Database))..." { Set-RecoveryModel -Server $script:Server -Database $script:Database }
		}
	}

	if ($script:DropMergeReplicationSubscriber)
	{
		TimedCommandBlock "Drop subscription for [$($script:Database)] from [$($script:Server)] to [$($script:Publisher)]..." { Start-DropMergeReplicationSubscriber -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath -Publisher $script:Publisher }
	}

	if ($script:DropMergeReplicationPublisher)
	{
		$subs = Get-MergeReplicationSubscribers -Server $script:Server -Database $script:Database
		foreach($sub in $subs)
		{
			TimedCommandBlock "Drop subscriber replication from [$($sub.subscriber_server)]..." { Start-DropMergeReplicationSubscriber -Server $sub.subscriber_server -Database $script:Database -InputFilePath $script:SqlOpsPath -Publisher $script:Server }
		}
		
		TimedCommandBlock "Drop publisher replication..." { Start-DropMergeReplicationPublisher -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath }
	}

	if ($script:DropTransReplicationSubscriber)
	{
		TimedCommandBlock "Drop subscription for [$($script:Database)] from [$($script:Server)] to [$($script:Publisher)]..." { Start-DropTransReplicationSubscriber -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath -Publisher $script:Publisher }
	}

	if ($script:DropTransReplicationPublisher)
	{
		$subs = Get-TransReplicationSubscribers -Server $script:Server -Database $script:Database
		foreach($sub in $subs)
		{
			TimedCommandBlock "Drop subscription from publisher..." { Start-DropTransReplicationPublisherSubscription -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath -Subscriber $sub.subscriber_server }
		}
		
		TimedCommandBlock "Drop publication..." { Start-DropTransReplicationPublisher -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath }

		foreach($sub in $subs)
		{
			TimedCommandBlock "Drop subscription from [$($sub.subscriber_server)]..." { Start-DropTransReplicationSubscriber -Server $sub.subscriber_server -Database $script:Database -InputFilePath $script:SqlOpsPath -Publisher $script:Server }
		}
	}

	if ($script:Exec)
	{
		$ScriptFilePath = "$($script:UserScriptPath)\$($script:ScriptFile)"
		TimedCommandBlock "Executing script $($ScriptFilePath)..." { Invoke-SqlcmdFile -Server $script:Server -Database $script:Database -InputFilePath $ScriptFilePath -Timeout $script:QueryTimeout }
	}

	if ($script:CreateMergeReplicationPublisher)
	{
		$SQLReplDataPath = Get-DefaultReplicationPath -Server $script:Server -Database master

		TimedCommandBlock "Deleting previous snapshots..." { Remove-Item "$SQLReplDataPath\unc\$($script:Server)_$($script:Database)_$($script:Database)MERGE\*" -recurse }
		TimedCommandBlock "Create replication publication..." { Start-CreateMergeReplicationPublisher -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath -Subscribers $script:Subscribers -Minutes $script:StartTime }
		Write-Warning "[!] Please check that the snapshot agent job has finished before setting up the subscribers."
	}

	if ($script:CreateMergeReplicationSubscriber)
	{
		$defaultReplPath = Get-DefaultReplicationPath -Server $script:Publisher -Database master
		$SQLReplDataPath = "$($defaultReplPath)\unc\$($Publisher)_$($Database)_$($Database)MERGE"
		$SnapshotLocationPath = "\\$($script:Publisher)\$($SQLReplDataPath.Replace(':', '$'))"

		TimedCommandBlock "Copy Snapshot from ($($Publisher))..." { robocopy "$SnapshotLocationPath" "$SQLReplDataPath" /mir /NP | Out-Default }
		TimedCommandBlock "Create subscription on subscriber for ($($script:Database))..." { Start-CreateMergeReplicationSubscriber -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath -Publisher $script:Publisher -Minutes $script:StartTime }
		TimedCommandBlock "Set Permissions on ($($script:Database))..." { Set-Permissions -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath }
	}

	if ($script:CreateTransReplicationPublisher)
	{
		$defaultReplPath = Get-DefaultReplicationPath -Server $script:Server -Database master
		$SQLReplDataPath = "$($defaultReplPath)";

		TimedCommandBlock "Deleting previous snapshots..." { Remove-Item "$SQLReplDataPath\unc\$($script:Server)_$($script:Database)_$($script:Database)_Transactional\*" -recurse }
		TimedCommandBlock "Create transactional replication publication for [$($script:Database)]..." { Start-CreateTransReplicationPublisher -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath -Subscribers $script:Subscribers }
		Write-Warning "[!] Please check that the snapshot agent job has finished before setting up the subscribers."
	}

	if ($script:CreateTransReplicationSubscriber)
	{

	}

	if ($script:ApplyPermissions)
	{
		TimedCommandBlock "Set Permissions on DB..." { Set-Permissions -Server $script:Server -Database $script:Database -InputFilePath $script:SqlOpsPath }
	}
}

<###[Main Script]###############################>
Test-Parameters
Start-Log $LogFile
Start-Main
Stop-Log