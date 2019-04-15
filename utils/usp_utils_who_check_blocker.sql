CREATE PROCEDURE [dbo].[usp_utils_who_check_blocker]
AS
BEGIN

	-- Drop table if existing
	DROP TABLE IF EXISTS #Who;
	DROP TABLE IF EXISTS #BlockedBlockers;
	DROP TABLE IF EXISTS #ConsolidatedBlockers;

	-- Create the 'who' tables
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
	SELECT *
	INTO #ConsolidatedBlockers
	FROM #Who
	WHERE 1 = 0;

	-- Insert the 'sp_who2' result
	INSERT INTO #Who
	EXEC sp_who2;
	
	-- Remove the background
	DELETE FROM #Who
	WHERE LTRIM(RTRIM([Login])) = 'sa';

	-- Select all those with blockers
	SELECT SPID AS BlockedSPID
		, CONVERT(INT, BlkBy) AS BlockerSPID
	INTO #BlockedBlockers
	FROM #Who
	WHERE DBName IS NOT NULL
		AND (BlkBy IS NOT NULL AND LTRIM(RTRIM(BlkBy)) <> '.')
		AND (CONVERT(NVARCHAR, SPID) <> LTRIM(RTRIM(BlkBy)));

	-- Return the result of 'who'
	SELECT *
	FROM #Who
	ORDER BY SPID;

	-- Return 'blockers' and 'blocked'
	SELECT *
	FROM #BlockedBlockers
	ORDER BY BlockedSPID;

	-- Loop until the parent is found
	DECLARE @BlockerSPID INT
		, @BlockedSPID INT
		, @AnalyzedSPID INT
		, @Skip BIT = 0;
	DECLARE BlockedSPIDCursor CURSOR
	FOR
	SELECT DISTINCT BlockedSPID
	FROM #BlockedBlockers
	ORDER BY BlockedSPID;

	-- Open the cursor
	OPEN BlockedSPIDCursor;

	-- Fetch the first result
	FETCH NEXT FROM BlockedSPIDCursor INTO @BlockedSPID;

	-- Iterate
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
	
		-- Set the current analyzed spid. Starts at the current blocker
		SET @AnalyzedSPID = @BlockedSPID;

		-- Log the current
		PRINT CONCAT('Analyzing blocked SPID: ', @AnalyzedSPID);

		-- Reset the skip flag
		SET @Skip = 0;

		-- Exit only until we found null for the 'blocker' spid
		WHILE (@Skip = 0)
		BEGIN
			
			-- Get the current blocked SPID
			SELECT @BlockerSPID = 
				(
					SELECT TOP 1 B1.BlockerSPID
					FROM #BlockedBlockers B1
					--INNER JOIN #BlockedBlockers B2 ON B2.BlockedSPID = B1.BlockerSPID
					WHERE B1.BlockedSPID = @AnalyzedSPID
				);

			-- Add the current if the 'blocker' is null
			IF (@BlockerSPID IS NOT NULL)
			BEGIN
				PRINT CONCAT('The SPID ', @AnalyzedSPID, ' is being blocked by ', @BlockerSPID, '.');
			END
			ELSE
			BEGIN
				PRINT CONCAT('There is no blocker for SPID ', @AnalyzedSPID, '.');
				
				-- Insert if not yet inserted
				IF (NOT EXISTS(SELECT TOP 1 * FROM #ConsolidatedBlockers WHERE SPID = @AnalyzedSPID))
				BEGIN
					-- Insert into blocker SPID
					INSERT INTO #ConsolidatedBlockers
					SELECT *
					FROM #Who
					WHERE SPID = @AnalyzedSPID;
					--EXEC sp_who2 @AnalyzedSPID;
				END
				
				-- Break here
				SET @Skip = 1;
			END

			-- Set the blocker SPID as the new SPID to analyze next
			SET @AnalyzedSPID = @BlockerSPID;

		END

		-- Fetch next result
		FETCH NEXT FROM BlockedSPIDCursor INTO @BlockedSPID;
	END

	-- Close the cursor
	CLOSE BlockedSPIDCursor;
	DEALLOCATE BlockedSPIDCursor;

	-- Select the blocked spids
	WITH CTE AS
	(
		SELECT ROW_NUMBER() OVER(ORDER BY SPID ASC, DiskIO DESC) AS RowNumber
			, *
		FROM #ConsolidatedBlockers
		WHERE CONVERT(NVARCHAR, SPID) <> BlkBy /* Exclude self */
	)
	SELECT CONCAT('Blocker', RowNumber) AS Who
		, [SPID]
		, [Status]
		, [Login]
		, [HostName]
		, [BlkBy]
		, [DBName]
		, [Command]
		, [CPUTime]
		, [DiskIO]
		, [LastBatch]
		, [ProgramName]
		, [SPID2]
		, [REQUESTEDID]
	FROM CTE
	ORDER BY RowNumber;

	-- Drop temporary tables
	DROP TABLE #ConsolidatedBlockers;
	DROP TABLE #BlockedBlockers;
	DROP TABLE #Who;

END
GO


