CREATE PROCEDURE [dbo].[usp_utils_who_check_resource_usage_percentage_per_database_by_disk_io]
AS
BEGIN

	-- Variables
	DECLARE @Sum DECIMAL(18, 2);

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

	-- Get the sum
	SELECT @Sum = CONVERT(DECIMAL(18, 2), SUM([DiskIO])) FROM #Who; /* total resource of SQL Server instead */

	-- Return the result ordered by CPUTime and DiskIO
	WITH CTE AS
	(
		SELECT DBName
			, CONVERT(DECIMAL(18, 2), SUM([DiskIO])) AS SumDiskIO
		FROM #Who
		WHERE DBName IS NOT NULL
		GROUP BY DBName
	),
	Percentage_CTE AS
	(
		SELECT DBName
			, SumDiskIO
			, CONVERT(DECIMAL(18, 2), ((SumDiskIO / @Sum) * 100)) AS [Percentage]
		FROM CTE
	)
	SELECT *
	FROM Percentage_CTE
	ORDER BY [Percentage] DESC, [DBName] ASC;

	/* Add the FreeResource by deducting the TotalResource - SUM(DiskIO) */

	-- Drop the temp tables
	DROP TABLE #Who;

END
GO


