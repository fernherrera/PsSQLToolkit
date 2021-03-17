/* PROVIDES THE REPLICATION OPTIONS VALUE FOR @SCHEMA_OPTION */

select cast(

  cast(0x01 AS BIGINT) --DEFAULT Generates object creation script
| cast(0x02 AS BIGINT) --DEFAULT Generates procs that propogate changes for the article
| cast(0x04 AS BIGINT) --Identity columns are scripted using the IDENTITY property
| cast(0x08 AS BIGINT) --DEFAULT Replicate timestamp columns (if not set timestamps are replicated as binary)
| cast(0x10 AS BIGINT) --DEFAULT Generates corresponding clustered index
--| cast(0x20 AS BIGINT) --Converts UDT to base data types
--| cast(0x40 AS BIGINT) --Create corresponding nonclustered indexes
| cast(0x80 AS BIGINT) --DEFAULT Replicate pk constraints
--| cast(0x100 AS BIGINT) --Replicates user triggers
--| cast(0x200 AS BIGINT) --Replicates foreign key constraints
--| cast(0x400 AS BIGINT) --Replicates check constraints
--| cast(0x800 AS BIGINT)  --Replicates defaults
| cast(0x1000 AS BIGINT) --DEFAULT Replicates column-level collation
--| cast(0x2000 AS BIGINT) --Replicates extended properties
| cast(0x4000 AS BIGINT) --DEFAULT Replicates UNIQUE constraints
--| cast(0x8000 AS BIGINT) --Not valid
| cast(0x10000 AS BIGINT) --DEFAULT Replicates CHECK constraints as NOT FOR REPLICATION so are not enforced during sync
| cast(0x20000 AS BIGINT) --DEFAULT Replicates FOREIGN KEY constraints as NOT FOR REPLICATION so are not enforced during sync
--| cast(0x40000 AS BIGINT) --Replicates filegroups (filegroups must already exist on subscriber)
--| cast(0x80000 AS BIGINT) --Replicates partition scheme for partitioned table
--| cast(0x100000 AS BIGINT) --Replicates partition scheme for partitioned index
--| cast(0x200000 AS BIGINT) --Replicates table statistics
--| cast(0x400000 AS BIGINT) --Default bindings
--| cast(0x800000 AS BIGINT) --Rule bindings
--| cast(0x1000000 AS BIGINT) --Full text index
--| cast(0x2000000 AS BIGINT) --XML schema collections bound to xml columns not replicated
--| cast(0x4000000 AS BIGINT) --Replicates indexes on xml columns
| cast(0x8000000 AS BIGINT) --DEFAULT Creates schemas not present on subscriber
--| cast(0x10000000 AS BIGINT) --Converts xml columns to ntext
--| cast(0x20000000 AS BIGINT) --Converts (max) data types to text/image
--| cast(0x40000000 AS BIGINT) --Replicates permissions
--| cast(0x80000000 AS BIGINT) --Drop dependencies to objects not part of publication
--| cast(0x100000000 AS BIGINT) --Replicate FILESTREAM attribute (2008 only)
--| cast(0x200000000 AS BIGINT) --Converts date & time data types to earlier versions
| cast(0x400000000 AS BIGINT) --Replicates compression option for data & indexes
--| cast(0x800000000 AS BIGINT)  --Store FILESTREAM data on its own filegroup at subscriber
--| cast(0x1000000000 AS BIGINT) --Converts CLR UDTs larger than 8000 bytes to varbinary(max)
--| cast(0x2000000000 AS BIGINT) --Converts hierarchyid to varbinary(max)
--| cast(0x4000000000 AS BIGINT) --Replicates filtered indexes
--| cast(0x8000000000 AS BIGINT) --Converts geography, geometry to varbinary(max)
--| cast(0x10000000000 AS BIGINT) --Replicates geography, geometry indexes
--| cast(0x20000000000 AS BIGINT) --Replicates SPARSE attribute 
AS BINARY(8)) as Schema_Option 