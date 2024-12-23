CREATE OR ALTER PROCEDURE [jadoube].[p_mashing](
	@target_schema varchar(128) = NULL,
	@target_table varchar(128),
	@source_schema varchar(128) = NULL,
	@source_table varchar(128) = NULL,
	@master_key varchar(128),
	@duplicate_key varchar(128),
	@update_columns varchar(4000) = NULL,
	@priority nvarchar(4000) = NULL,
	@print bit = 0,
	@execute bit = 1
)
AS
/*
[jadoube].[p_mashing]

Version: 1.2
Authors: JRA
Date: 2024-11-06

Explanation:
Given a table that features a master key and duplicate keys, mashing modifies the table such that no master appears as a duplicate and no duplicate appears as a master. Additional columns can be specified to be carried about with the changed. The output is stored in a table with the same schema and name as the target, with the table name suffixed with "_mashing". Furthermore, if a source table is provided, then the source is mashed into the target and (for performance), the target is not itself mashed. Note that the source must have the same structure as the target.

Requirements:
- [jadoube].[fn_string_split_item]

Parameters:
- @target_schema (varchar(128)): The schema of the table to use as a target. Defaults to no schema.
- @target_table (varchar(128)): The table to use as a target.
- @source_schema (varchar(128)): The schema of the table to use as a source. Defaults to no schema.
- @source_table (varchar(128)): The table to use as a source. Defaults to no source.
- @master_key (varchar(128)): The name of the column containing the master keys.
- @duplicate_key (varchar(128)): The name of the columns containing the duplicate keys.
- @update_columns (varchar(4000)): A comma-separated list of columns associated with the duplicate that should stay with their own duplicate key. Defaults to no additional columns.
- @priority (nvarchar(4000)): A SQL ordering expression to prioritise records. Higher priority records remain as left keys and lower priority records become right keys. Defaults to no prioritisation.
- @print (bit): If true, debug statements and tables are displayed. Defaults to false.
- @execute (bit): If true, dynamic SQL statements are executed. Defaults to true.

Usage:
>>> EXECUTE [jadoube].[p_mashing]
		@target_schema = 'misc',
		@target_table = 'goodreads_matching',
		@source_schema = NULL,
		@source_table = NULL,
		@master_key = 'l_pid',
		@duplicate_key = 'r_pid',
		@update_columns = 'l_id',
		@priority = '[__order] ASC, [loaddate] ASC',
		@print = 1,
		@execute = 1
>>> SELECT * FROM [misc].[goodreads_matching_mashing]

History:
- 1.2 JRA (2024-11-06): Added an index on the table to be mashed in an attempt to improve performance. The target will be mashed only if the source not provided.
- 1.1 JRA (2024-10-24): Removed [__source]. Changed the behaviour if `@source` is provided. Fixed an issue if no update columns are provided.
- 1.0 JRA (2024-10-16): Initial version.
*/
DECLARE @target varchar(261),
	@source varchar(261),
	@cmd nvarchar(max);
SET @target = CONCAT_WS('.', QUOTENAME(@target_schema, '['), QUOTENAME(@target_table, '['));
SET @source = CONCAT_WS('.', QUOTENAME(@source_schema, '['), QUOTENAME(@source_table, '['));

IF @source = ''
	SET @source = NULL;

IF @priority IS NULL
	SET @priority = '(SELECT 1)';

IF @update_columns IS NOT NULL
BEGIN
	DECLARE @columns table ([index] int, [column] varchar(128));
	WITH [T] AS (
		SELECT 0 AS [index], [jadoube].[fn_string_split_item](@update_columns, ',', 0) AS [column]
		UNION ALL
		SELECT [index] + 1, [jadoube].[fn_string_split_item](@update_columns, ',', [index] + 1)
		FROM [T]
		WHERE [jadoube].[fn_string_split_item](@update_columns, ',', [index] + 1) <> ''
	)
	INSERT INTO @columns
	SELECT [index], [column]
	FROM [T]
END

SET @cmd = CONCAT('
DROP TABLE IF EXISTS [##mashing];
WITH [T] AS (
	SELECT 0 AS [__source], * FROM ', @target, '
	UNION ALL
	SELECT 1 AS [__source], * FROM ' + @source, '
)
SELECT ROW_NUMBER() OVER(ORDER BY ', @priority, ') AS [__priority], *
INTO [##mashing]
FROM [T]
')
IF @print = 1 PRINT(@cmd)
IF @execute = 1 EXEC(@cmd);

SET @cmd = CONCAT('CREATE CLUSTERED INDEX I_##_mashing ON [##mashing]([__source], [__priority], ', QUOTENAME(@master_key, '['), ')')
IF @print = 1 PRINT(@cmd);
IF @execute = 1 EXEC(@cmd);

IF @update_columns IS NOT NULL
BEGIN
	SET @cmd = (
		SELECT CONCAT(',', CHAR(10), CHAR(9), CHAR(9), '[right].', QUOTENAME([column], '['), ' = [left].', QUOTENAME([column], '['))
		FROM @columns
		FOR XML PATH(''), TYPE
	).value('./text()[1]', 'nvarchar(max)')
END
ELSE
	SET @cmd = NULL
SET @cmd = CONCAT('
DECLARE @row_count int = 1
WHILE @row_count > 0
BEGIN
	UPDATE [right]
	SET [right].', QUOTENAME(@master_key, '['), ' = [left].', QUOTENAME(@master_key, '['), @cmd, '
	FROM [##mashing] AS [left]
		INNER JOIN [##mashing] AS [right]
			ON ', IIF(@source IS NULL, '', '[left].[__source] = 1
			AND '), '[left].[__priority] < [right].[__priority]
			AND [left].', QUOTENAME(@master_key, '['), ' <> [right].', QUOTENAME(@master_key, '['), '
			AND [left].', QUOTENAME(@duplicate_key, '['), ' IN ([right].', QUOTENAME(@master_key, '['), ', [right].', QUOTENAME(@duplicate_key, '['), ')
	
	SET @row_count = @@ROWCOUNT
END
')
IF @print = 1 PRINT(@cmd);
IF @execute = 1 EXEC(@cmd);

SET @target = CONCAT_WS('.', QUOTENAME(@target_schema, '['), QUOTENAME(@target_table + '_mashing', '['));
SET @cmd = CONCAT('
DROP TABLE IF EXISTS ', @target, ';
WITH [T] AS (
	SELECT ROW_NUMBER() OVER(PARTITION BY ', QUOTENAME(@master_key, '['), ', ', QUOTENAME(@duplicate_key, '['), ' ORDER BY [__priority] ASC) AS [R], *
	FROM [##mashing]
)
SELECT *
INTO ',  @target, '
FROM [T]
WHERE [R] = 1

ALTER TABLE ', @target, '
DROP COLUMN [__source], [__priority], [R]

DROP TABLE IF EXISTS [##mashing];
')
IF @print = 1 PRINT(@cmd);
IF @execute = 1 EXEC(@cmd);