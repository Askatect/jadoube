CREATE OR ALTER PROCEDURE [jra].[usp_timer](
	@process varchar(512) = NULL,
	@start datetime = NULL,
	@record bit = 1,
	@print bit = 1,
	@display bit = 0
)
AS
/*
Version: 2.1
Author: JRA
Date: 2024-01-25

Explanation:
Measures duration of instances and batches, with the options to print the duration during execution and to display summary data (recommended at the end of a script only). The following terms are used:
- "Instance": Instances are unique executions of some SQL, separated by calls to [jra].[timer] or start and end of a batch.
- "Process": All instances are processes, but processes can be named by the user for reference. Particularly useful if the same instance is run multiple times and they need identifying.
- "Task": Tasks are unique executions of batches, separated by the start or end of the script or the GO command.
- "Batch": All tasks are batches, but batches can identify multiple tasks that are the same SQL run at different times.
- "Plan": In SQL Server, the engine designs an execution plan for each batch, which may change over time for optimisation purposes. This is also recorded.

Parameters:
- @process varchar(512): The user can provide a process name for the instance just passed. Defaults to NULL.
- @start datetime: The user can overwrite the start time for the instance just passed. Defaults to the end of the previous instance or the start of the batch (whichever is later).
- @record bit: If true, the timer data is stored in ##timer. Note that this means there will be nothing to display. Defaults to true.
- @print bit: If true, the procedure will print the process name (if applicable), the instance number and the duration of the instance. Defaults to true.
- @display bit: If true, the timer data with aggregation will be displayed. Defaults to false.

Returns:
Prints time elapsed during processes.

Usage:
DECLARE @start datetime
SET @start = GETDATE()
<script>
EXECUTE [jra].[usp_timer] @process = 'Original', @start = @start, @record = 0, @print = 1
---
<script>
EXECUTE [jra].[usp_timer]
<further script>
EXECUTE [jra].[usp_timer]
GO
<additional further script>
EXECUTE [jra].[usp_timer] @diplay = 1
---
DECLARE @counter AS int = 0
WHILE @counter < <iterations>
BEGIN
	<script>
	EXECUTE [jra].[usp_timer] @process = 'TimeIt', @print = 0
	SET @counter += 1
END
EXECUTE [jra].[usp_timer] @record = 0, @print = 0, @display = 1

History:
- 2.1 JRA (2024-01-25): Removed the batch text facility. Can't seem to get it working when called as a procedure.
- 2.0 JRA (2024-01-25): Complete rewrite for easier use. Original functionality still preserved.
- 1.0 JRA (2023): Initial version (required handling variables in main scope).
*/
DECLARE @instance int

IF (@record = 1 AND (OBJECT_ID('tempdb..##timer', 'U') IS NULL))
BEGIN
	SELECT [session_id],
		@process AS [process],
		1 AS [instance_id], 
		[start_time] AS [task_start],
		[start_time] AS [instance_start],
		GETDATE() AS [instance_end],
		[sql_handle] AS [batch_id], 
		[plan_handle] AS [plan_id]
	INTO ##timer
	FROM sys.dm_exec_requests
	WHERE [session_id] = @@SPID
	SET @instance = 1
END
ELSE IF (@record = 1)
BEGIN
	SET @instance = (SELECT COUNT([instance_id]) + 1 FROM ##timer)
	INSERT INTO ##timer([session_id], [process], [instance_id], [task_start], [instance_start], [instance_end], [batch_id], [plan_id])
	SELECT [session_id], 
		@process,
		@instance,		
		[start_time],
		COALESCE(@start, (SELECT [instance_end] FROM ##timer WHERE [task_start] = [start_time] AND [instance_id] = @instance - 1), [start_time]),
		GETDATE(),
		[sql_handle], 
		[plan_handle]
	FROM sys.dm_exec_requests
	WHERE [session_id] = @@SPID
END

IF @print = 1
BEGIN
	DECLARE @statement nvarchar(max),
		@duration bigint = IIF(@record = 0, 
			DATEDIFF(millisecond, ISNULL(@start, (SELECT [start_time] FROM sys.dm_exec_requests)), GETDATE()), 
			(SELECT DATEDIFF(millisecond, [instance_start], [instance_end]) FROM ##timer WHERE [instance_id] = @instance)
		)
	SET @statement = CONCAT(@process, ' (Instance ', @instance, ') - ', FORMAT((@duration/360000), '###00'), ':', FORMAT((@duration/60000 % 60), 'D2'), ':', FORMAT((@duration/1000 % 60), 'D2'), '.', FORMAT((@duration % 1000), 'D3'))
	PRINT(LTRIM(@statement))
END

IF @display = 1 AND (OBJECT_ID('tempdb..##timer') IS NOT NULL)
BEGIN
	;WITH [timer] AS (
		SELECT [session_id] AS [Session ID],
			[plan_id] AS [Plan ID],
			[batch_id] AS [Batch ID],
			ISNULL([process], '') AS [Process],
			ROW_NUMBER() OVER(PARTITION BY [task_start] ORDER BY [instance_start] ASC) AS [Process Instance],
			[instance_id] AS [Instance ID],
			[task_start] AS [Task Start],
			MAX([instance_end]) OVER(PARTITION BY [task_start]) AS [Task End],
			DATEDIFF(millisecond, [task_start], MAX([instance_end]) OVER(PARTITION BY [task_start])) AS [Task Duration],
			[instance_start] AS [Instance Start],
			[instance_end] AS [Instance End],
			DATEDIFF(millisecond, [instance_start], [instance_end]) AS [Instance Duration]
		FROM ##timer
		WHERE [session_id] = @@SPID
	)
	SELECT *,
		MIN([Task Duration]) OVER(PARTITION BY [Plan ID]) AS [Plan MIN],
		AVG([Task Duration]) OVER(PARTITION BY [Plan ID]) AS [Plan AVG],
		MAX([Task Duration]) OVER(PARTITION BY [Plan ID]) AS [Plan MAX],
		MIN([Task Duration]) OVER(PARTITION BY [Batch ID]) AS [Batch MIN],
		AVG([Task Duration]) OVER(PARTITION BY [Batch ID]) AS [Batch AVG],
		MAX([Task Duration]) OVER(PARTITION BY [Batch ID]) AS [Batch MAX],
		MIN([Instance Duration]) OVER(PARTITION BY [Process]) AS [Process MIN],
		AVG([Instance Duration]) OVER(PARTITION BY [Process]) AS [Process AVG],
		MAX([Instance Duration]) OVER(PARTITION BY [Process]) AS [Process MAX]
	FROM [timer]
	ORDER BY [Instance ID] ASC
END
ELSE IF @display = 1
	SELECT 'No timer data has been recorded.' AS [Error]