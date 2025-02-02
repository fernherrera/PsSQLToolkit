USE [master]
EXEC sp_configure 'show advanced options', 1
exec sp_configure 'access check cache bucket count', '0'; Reconfigure with Override;
exec sp_configure 'access check cache quota', '0'; Reconfigure with Override;
exec sp_configure 'Ad Hoc Distributed Queries', '0'; Reconfigure with Override;
exec sp_configure 'affinity I/O mask', '0'; Reconfigure with Override;
exec sp_configure 'affinity mask', '0'; Reconfigure with Override;
exec sp_configure 'affinity64 I/O mask', '0'; Reconfigure with Override;
exec sp_configure 'affinity64 mask', '0'; Reconfigure with Override;
exec sp_configure 'Agent XPs', '1'; Reconfigure with Override;
exec sp_configure 'allow polybase export', '0'; Reconfigure with Override;
exec sp_configure 'allow updates', '0'; Reconfigure with Override;
exec sp_configure 'automatic soft-NUMA disabled', '0'; Reconfigure with Override;
exec sp_configure 'backup checksum default', '0'; Reconfigure with Override;
exec sp_configure 'backup compression default', '1'; Reconfigure with Override;
exec sp_configure 'blocked process threshold (s)', '0'; Reconfigure with Override;
exec sp_configure 'c2 audit mode', '0'; Reconfigure with Override;
exec sp_configure 'clr enabled', '0'; Reconfigure with Override;
exec sp_configure 'contained database authentication', '0'; Reconfigure with Override;
exec sp_configure 'cost threshold for parallelism', '50'; Reconfigure with Override;
exec sp_configure 'cross db ownership chaining', '0'; Reconfigure with Override;
exec sp_configure 'cursor threshold', '-1'; Reconfigure with Override;
exec sp_configure 'Database Mail XPs', '1'; Reconfigure with Override;
exec sp_configure 'default full-text language', '1033'; Reconfigure with Override;
exec sp_configure 'default language', '0'; Reconfigure with Override;
exec sp_configure 'default trace enabled', '1'; Reconfigure with Override;
exec sp_configure 'disallow results from triggers', '0'; Reconfigure with Override;
exec sp_configure 'external scripts enabled', '0'; Reconfigure with Override;
exec sp_configure 'filestream access level', '0'; Reconfigure with Override;
exec sp_configure 'fill factor (%)', '0'; Reconfigure with Override;
exec sp_configure 'ft crawl bandwidth (max)', '100'; Reconfigure with Override;
exec sp_configure 'ft crawl bandwidth (min)', '0'; Reconfigure with Override;
exec sp_configure 'ft notify bandwidth (max)', '100'; Reconfigure with Override;
exec sp_configure 'ft notify bandwidth (min)', '0'; Reconfigure with Override;
exec sp_configure 'hadoop connectivity', '0'; Reconfigure with Override;
exec sp_configure 'index create memory (KB)', '0'; Reconfigure with Override;
exec sp_configure 'in-doubt xact resolution', '0'; Reconfigure with Override;
exec sp_configure 'lightweight pooling', '0'; Reconfigure with Override;
exec sp_configure 'locks', '0'; Reconfigure with Override;
exec sp_configure 'max degree of parallelism', '8'; Reconfigure with Override;
exec sp_configure 'max full-text crawl range', '4'; Reconfigure with Override;
exec sp_configure 'max server memory (MB)', '40960'; Reconfigure with Override;
exec sp_configure 'max text repl size (B)', '65536'; Reconfigure with Override;
exec sp_configure 'max worker threads', '0'; Reconfigure with Override;
exec sp_configure 'media retention', '0'; Reconfigure with Override;
exec sp_configure 'min memory per query (KB)', '1024'; Reconfigure with Override;
exec sp_configure 'min server memory (MB)', '0'; Reconfigure with Override;
exec sp_configure 'nested triggers', '1'; Reconfigure with Override;
exec sp_configure 'network packet size (B)', '4096'; Reconfigure with Override;
exec sp_configure 'Ole Automation Procedures', '0'; Reconfigure with Override;
exec sp_configure 'open objects', '0'; Reconfigure with Override;
exec sp_configure 'optimize for ad hoc workloads', '0'; Reconfigure with Override;
exec sp_configure 'PH timeout (s)', '60'; Reconfigure with Override;
exec sp_configure 'polybase network encryption', '1'; Reconfigure with Override;
exec sp_configure 'precompute rank', '0'; Reconfigure with Override;
exec sp_configure 'priority boost', '0'; Reconfigure with Override;
exec sp_configure 'query governor cost limit', '0'; Reconfigure with Override;
exec sp_configure 'query wait (s)', '-1'; Reconfigure with Override;
exec sp_configure 'recovery interval (min)', '0'; Reconfigure with Override;
exec sp_configure 'remote access', '1'; Reconfigure with Override;
exec sp_configure 'remote admin connections', '0'; Reconfigure with Override;
exec sp_configure 'remote data archive', '0'; Reconfigure with Override;
exec sp_configure 'remote login timeout (s)', '10'; Reconfigure with Override;
exec sp_configure 'remote proc trans', '0'; Reconfigure with Override;
exec sp_configure 'remote query timeout (s)', '600'; Reconfigure with Override;
exec sp_configure 'Replication XPs', '0'; Reconfigure with Override;
exec sp_configure 'scan for startup procs', '1'; Reconfigure with Override;
exec sp_configure 'server trigger recursion', '1'; Reconfigure with Override;
exec sp_configure 'set working set size', '0'; Reconfigure with Override;
exec sp_configure 'show advanced options', '1'; Reconfigure with Override;
exec sp_configure 'SMO and DMO XPs', '1'; Reconfigure with Override;
exec sp_configure 'transform noise words', '0'; Reconfigure with Override;
exec sp_configure 'two digit year cutoff', '2049'; Reconfigure with Override;
exec sp_configure 'user connections', '0'; Reconfigure with Override;
exec sp_configure 'user options', '0'; Reconfigure with Override;
exec sp_configure 'xp_cmdshell', '0'; Reconfigure with Override;