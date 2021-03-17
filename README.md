# PowerShell SQL Toolkit
PowerShell scripts for working with SQL Server databases.

## Toolkit Capabilities
* Backup & Restore
* Copy database to another server.
* Setup & tear down replication (Transactional & Merge)
* Run ad-hoc scripts
* Logs all script operations.

## Contents
| File/Folder        | Description|
|--------------------|------------|
| \logs              |Log files of all operations by date.|
| \modules           | PowerShell functions imported into main control script.
| \sql-commands      | SQLCMD compatible SQL scripts that make heavy use of variable parameters. |
| sql-operations.bat | Batch file to invoke sql-operations.ps1 (Ensures it is run with Admin privileges).|
| sql-operations.ps1 | Main executable, orchestrates all operations.|

## Syntax
`.\sql-operations.ps1 -Server [value] -Database [value]...`

## Parameters
| Option | Description |
|--------|-------------|
| `-Server` *server_instance* | The SQL Server to connect to. In the case of the **CopyDB** operation this is used as the destination server. |
| `-Database` *database_name* | The database to use. In the case of the **CopyDB** operation this is used as the destination database name. |
| `-QueryTimeout` timeout_value | Query execution timeout in seconds (default: 30 seconds) |
| **Execute Ad-Hoc script** |
| `-Exec` | This switch is used run an ad-hoc script. |
| `-ScriptFile` *filename* | The filename if the ad-hoc script to run. File must be placed in the `\user-scripts` folder. |
| **Create a Database Backup** |
| `-BackupDB` | This switch is used to execute a database backup. |
| `-backupFilename` *filename* | The filename of the backup to create. **The backups are created in the server's default backup location.** |
| **Copy a Database** |
| `-CopyDB` | This switch is used to copy a database to another server or to create a copy with a different name. |
| `-SourceServer` *server_instance* | The source server instance to copy the database from. |
| `-SourceDatabase` *database_name* | The source database to be copied. |
| `-UseLastBackup` | Uses the last available full backup of the database to be copied. If this switch is not used then a new full backup is created and copied to the destination. |
| `-RecoveryModelSimple` | This switch sets the copied database to simple recovery mode. |
| **Merge Replication Parameters** |
| `-CreateMergeReplicationPublisher` | This switch is used to create a Merge Replication publisher. |
| `-DropMergeReplicationPublisher` | This switch is used to drop a Merge Replication publisher. |
| `-CreateMergeReplicationSubscriber` | This switch is used to create Merge Replication subscribers. |
| `-DropMergeReplicationSubscriber` | This switch is used to drop a Merge Replication subscribers. |
| **Transactional Replication Parameters** |
| `-CreateTransReplicationPublisher` | This switch is used to create a Transactional Replication publisher. |
| `-DropTransReplicationPublisher` | This switch is used to drop a Transactional Replication publisher. |
| `-CreateTransReplicationSubscriber` | This switch is used to create Transactional Replication subscribers. |
| `-DropTransReplicationSubscriber` | This switch is used to drop Transactional Replication subscribers. |
| **Additional Replication Parameters** |
| `-Publisher` *server_instance* | The server instance name for the publisher SQL Server. |
| `-Subscribers` *server_instance, server_inst...* | A comma separated list of instance names or IP addresses of the replication subscribers. |
| `-StartTime` *700* | Is the time of day when the distribution task is first scheduled. **StartTime** is int, with a default of 0. |

## Examples
The following examples detail typical command line usage scenarios.

### Backup Examples
To backup a database before a migration use the following:

`sql-operations.bat -Server localhost -Database MyDB -BackupDB -backupFilename MyDB-preMigration.bak`

### Copy Database Examples
To copy a database to a different server with the same name use the following:
Copy *MyDB* database from *ServerA* to *ServerB*

`sql-operations.bat -CopyDB -Server ServerB -Database MyDB -SourceServer ServerA -SourceDatabase MyDB`

To copy a database on the same server with a different name use the following:
Copy *MyDB* database to new database called *MyNewDB* on *ServerA*

`sql-operations.bat -CopyDB -Server ServerA -Database MyNewDB -SourceServer ServerA -SourceDatabase MyDB`

To copy a database from it's last full backup use the following:

`sql-operations.bat -CopyDB -Server ServerA -Database MyDB -SourceServer ServerB -SourceDatabase MyDB -UseLastBackup`

### Ad-Hoc Script Example
To run an ad-hoc SQL script file on a database use the following:

`sql-operations.bat -Server ServerA -Database MyDB -Exec -ScriptFile MyCustomScript.sql`

