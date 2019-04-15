CREATE PROCEDURE [dbo].[usp_utils_who_check_logical]
AS
BEGIN
	SELECT TOP 20 QS.total_logical_reads AS TotalLogicalReads
		, QS.total_logical_writes AS TotalLogicalWrites
		, QS.total_logical_reads + QS.total_logical_writes AS TotalDiskIO
		, QS.execution_count AS ExecuteCount
		, QT.text AS QueryText
		, DB_NAME(QT.dbid) AS DatabaseName
		, QT.objectid AS ObjectId
		, OBJECT_NAME(QT.objectid) AS ObjectName
	FROM sys.dm_exec_query_stats QS
	CROSS APPLY sys.dm_exec_sql_text(SQL_HANDLE) QT
	WHERE (QS.total_logical_reads + QS.total_logical_writes) > 0
	ORDER BY TotalDiskIO DESC;
END
GO


