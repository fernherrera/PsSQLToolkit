DECLARE @profilename AS sysname;
DECLARE @profileid AS int;
SET @profilename = N'FS_custom_agent_profile';

-- Create a temporary table to hold the returned 
-- Merge Agent profiles.
CREATE TABLE #profiles (
	profile_id int, 
	profile_name sysname,
	agent_type int,
	[type] int,
	description varchar(3000),
	def_profile bit)

INSERT INTO #profiles (profile_id, profile_name, 
	agent_type, [type],description, def_profile)
	EXEC sp_help_agent_profile @agent_type = 4;

SET @profileid = (SELECT profile_id FROM #profiles 
    WHERE profile_name = @profilename);

IF (@profileid IS NOT NULL)
BEGIN
    EXEC sp_drop_agent_profile @profileid;
END

DROP TABLE #profiles

-- Add a new merge agent profile. 
EXEC sp_add_agent_profile 
    @profile_id = @profileid OUTPUT, 
    @profile_name = @profilename, 
    @agent_type = 4, -- Merge Agent
    @description = N'FS custom merge profile',
    @default = 1; --Make it the new default profile.

-- Change the value of ChangesPerHistory in the profile.
EXEC sp_change_agent_parameter 
    @profile_id = @profileid, 
    @parameter_name = N'-ChangesPerHistory', @parameter_value = 1000;

-- Add a new parameter DestThreads the profile. 
EXEC sp_change_agent_parameter 
    @profile_id = @profileid, 
    @parameter_name = N'-DestThreads', @parameter_value = 4;

-- Add a new parameter DownloadGenerationsPerBatch the profile. 
EXEC sp_change_agent_parameter 
    @profile_id = @profileid, 
    @parameter_name = N'-DownloadGenerationsPerBatch', @parameter_value = 1000;

-- Add a new parameter DownloadWriteChangesPerBatch the profile. 
EXEC sp_change_agent_parameter 
    @profile_id = @profileid, 
    @parameter_name = N'-DownloadWriteChangesPerBatch', @parameter_value = 1000;

-- Add a new parameter GenerationChangeThreshold the profile. 
EXEC sp_add_agent_parameter 
    @profile_id = @profileid, 
    @parameter_name = N'-GenerationChangeThreshold', @parameter_value = 10000;

-- Add a new parameter MaxBcpThreads the profile. 
EXEC sp_change_agent_parameter 
    @profile_id = @profileid, 
    @parameter_name = N'-MaxBcpThreads', @parameter_value = 4;

-- Add a new parameter QueryTimeout the profile. 
EXEC sp_change_agent_parameter 
    @profile_id = @profileid, 
    @parameter_name = N'-QueryTimeout', @parameter_value = 600;

-- Add a new parameter SrcThreads the profile. 
EXEC sp_change_agent_parameter 
    @profile_id = @profileid, 
    @parameter_name = N'-SrcThreads', @parameter_value = 3;

-- Add a new parameter UploadGenerationsPerBatch the profile. 
EXEC sp_change_agent_parameter 
    @profile_id = @profileid, 
    @parameter_name = N'-UploadGenerationsPerBatch', @parameter_value = 500;

-- Verify the new profile. 
EXEC sp_help_agent_parameter 
    @profileid;
GO