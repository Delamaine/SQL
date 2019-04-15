CREATE PROCEDURE [dbo].[usp_utils_who_check_resource_usage]
AS
BEGIN

	-- Drop if exists
	DROP TABLE IF EXISTS #Who;

	-- Create temp tables
	CREATE TABLE #Who
	(
		[SPID] INT
		, [Status] NVARCHAR(64)
		, [Login] NVARCHAR(64)
		, [HostName] NVARCHAR(64)
		, [BlkBy] NVARCHAR(64)
		, [DBName] NVARCHAR(128)
		, [Command] NVARCHAR(128)
		, [CPUTime] BIGINT
		, [DiskIO] BIGINT
		, [LastBatch] NVARCHAR(128)
		, [ProgramName] NVARCHAR(128)
		, [SPID2] INT
		, [REQUESTEDID] INT
	);

	-- Insert the result of 'sp_who'
	INSERT INTO #Who
	EXEC sp_who2;

	-- Remove the background
	DELETE FROM #Who
	WHERE LTRIM(RTRIM([Login])) = 'sa';

	-- Return the result ordered by CPUTime and DiskIO
	SELECT *
	FROM #Who
	WHERE DBName IS NOT NULL
	ORDER BY CPUTime DESC, DiskIO DESC;

	-- Drop the temp tables
	DROP TABLE #Who;

END
GO


