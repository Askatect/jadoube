CREATE OR ALTER PROCEDURE [jadoube].[p_matching](
	@schema varchar(128) = NULL, 
	@table varchar(128), 
	@id_column varchar(128), 
	@blocking_key nvarchar(4000) = NULL,
	@priority nvarchar(4000) = NULL,
	@match_rules varchar(4000),
	@mash bit = 1,
	@function_schema varchar(128) = 'jadoube',
	@print bit = 0,
	@execute bit = 1
)
AS
/*
[jadoube].[p_matching]

Version: 1.3
Authors: JRA
Date: 2024-10-23

Explanation:
Deduplication linkage on a given dataset according to provided blocking key and matching rules. This matching results are captured in a table of the same schema but table name suffixed by '_matching'. This table has the following structure:
- partition (bigint): An identifier for the partition defined by the blocking rule.
- l_pid (bigint): An identifier for the record.
- r_pid (bigint): An identifier for the matched record.
- l_id (any): Supplied key.
- r_id (any): Supplied key that matched with the key in `l_id`.

Requirements:
- [jadoube].[fn_string_split_item]
- [jadoube].[fn_string_split]
- Functions for matching rules must already exist in the database with the appropriate name.
	- Given matching logic based on 'jaro_winkler', the function `[jadoube].[fn_matching_jaro_winkler](@string1, @string2, @threshold)` must exist.
	- To see a list of available functions, run something like the following:
"""
SET NOCOUNT ON

DECLARE @loop int = 1, @docstring varchar(max)
DECLARE @functions table ([id] int NOT NULL IDENTITY(1, 1), [docstring] nvarchar(max))

INSERT INTO @functions([docstring])
SELECT SUBSTRING([m].[definition], CHARINDEX('/*', [m].[definition]), 2 + CHARINDEX('*/', [m].[definition]) - CHARINDEX('/*', [m].[definition])) AS [docstring]
FROM sys.objects AS [o]
	INNER JOIN sys.sql_modules AS [m]
		ON [m].[object_id] = [o].[object_id]
WHERE [o].[type] = 'FN'
	AND [o].[name] LIKE 'fn[_]matching[_]%'

WHILE @loop <= (SELECT MAX([id]) FROM @functions)
BEGIN
	SET @docstring = (SELECT [docstring] FROM @functions WHERE [id] = @loop)
	PRINT('--============================================================--')
	PRINT(@docstring)
	SET @loop += 1
END
--*/
"""

Parameters:
- @schema (varchar(128)): The schema in which to find the data to deduplicate. Defaults to no schema.
- @table (varchar(128)): The table in which to find the data to deduplicate.
- @id_column (varchar(128)): The key for rows in the data to deduplicate.
- @blocking_key (nvarchar(4000)): A SQL expression for which the results of will define blocking keys and partition the data. Defaults to no blocking.
- @priority (nvarchar(4000)): A SQL ordering expression to prioritise records. Higher priority records become left keys and lower priority records become right keys. Defaults to no prioritisation.
- @match_rules (nvarchar(4000)): This is how the matching logic is specified. Separate rules with a semi-colon and provide comma-separated rules as follows.
	- The column to match on.
	- The matching function use.
	- The threshold the match must meet to be a confirmed match.
	- A ruleset identifier. A true match only needs to meet the requirements of a single ruleset. The rulesets are ordered ascending by this identifier, so computationally expensive rulesets should be place last. Defaults to the empty string.
- @mash (bit): If true, the matches are mashed before being returned. This means that there should will be no loops in the output - each set of matched records has the same left key. Defaults to true.
- @function_schema (varchar(128)): The schema housing matching functions.
- @print (bit): If true, debug statements and tables are displayed. Defaults to false.
- @execute (bit): If true, dynamic SQL statements are executed. Defaults to true.

Usage:
>>> EXECUTE [jadoube].[p_matching]
		@schema = NULL,
		@table = '##goodreads',
		@id_column = 'Book Id',
		@blocking_key = 'LEFT([Author], 1)',
		@priority = 'ISNULL([Original Publication Year], 9999) ASC',
		@match_rules = 'Author,exact,1;Title,levenshtein_low,5;Author l-f,exact,1,a;Year Published,exact,1,a',
		@mash = 1,
		@print = 0,
		@execute = 1
>>> SELECT * FROM [##goodreads_matching]

Tasklist:
- Maybe make prefix columns of `[##matching]` with "__" to avoid clashes with existing columns?

History:
- 1.3 JRA (2024-10-23): Moved mashing to the end!
- 1.2 JRA (2024-10-22): Added @function_schema as an input parameter.
- 1.1 JRA (2024-10-16): Added ruleset logic. Added @mash.
- 1.0 JRA (2024-10-15): Initial version.
*/
IF @print = 0
	SET NOCOUNT ON
ELSE
	SET NOCOUNT OFF

DECLARE @object varchar(261),
	@cmd nvarchar(max);

SET @object = CONCAT_WS('.', QUOTENAME(@schema, '['), QUOTENAME(@table, '['));
IF @print = 1 PRINT('Running matching on ' + @object + '.')

IF @blocking_key IS NULL
	SET @blocking_key = '(SELECT 1)'
IF @priority IS NULL
	SET @priority = '(SELECT 1)'

DECLARE @metadata table (
	[ordinal] tinyint,
	[column] varchar(128),
	[function] varchar(125),
	[threshold] varchar(16),
	[ruleset] tinyint
);
WITH [T] AS (
	SELECT [a].[ordinal],
		[jadoube].[fn_string_split_item]([a].[value], ',', 0) AS [column],
		[jadoube].[fn_string_split_item]([a].[value], ',', 1) AS [function],
		[jadoube].[fn_string_split_item]([a].[value], ',', 2) AS [threshold],
		DENSE_RANK() OVER(ORDER BY [jadoube].[fn_string_split_item]([a].[value], ',', 3) ASC) - 1 AS [ruleset]
	FROM [jadoube].[tf_string_split](@match_rules, ';') AS [a]
)
INSERT INTO @metadata
SELECT * FROM [T]

IF @print = 1
	SELECT * FROM @metadata

SET @cmd = (SELECT STRING_AGG(QUOTENAME([column], '['), ',' + CHAR(10) + CHAR(9)) FROM (SELECT DISTINCT [column] FROM @metadata) AS [T])
SET @cmd = CONCAT('
DROP TABLE IF EXISTS [##matching];
WITH [T] AS (
SELECT ', @blocking_key,' AS [blocking_key],
	', QUOTENAME(@id_column, '['), ' AS [id],
	ROW_NUMBER() OVER(ORDER BY ', @priority, ') AS [pid],
	', @cmd, '
FROM ', @object, '
)
SELECT DENSE_RANK() OVER(ORDER BY [blocking_key]) AS [partition],
	ROW_NUMBER() OVER(PARTITION BY [blocking_key] ORDER BY [pid]) AS [pid],
	[id],
	', @cmd, '
INTO [##matching]
FROM [T]
')
IF @print = 1 PRINT(@cmd);
IF @execute = 1 EXEC(@cmd);

SET @object = CONCAT_WS('.', QUOTENAME(@schema, '['), QUOTENAME(@table + '_matching', '['));
SET @cmd = STUFF((
	SELECT CONCAT(IIF([m].[ruleset] <> ISNULL([prev].[ruleset], 255), ')' + CHAR(10) + CHAR(9) + 'OR (', CHAR(10) + CHAR(9) + CHAR(9) + 'AND '), QUOTENAME(@function_schema, '[') + '.', QUOTENAME(CONCAT('fn_matching_', [m].[function]), '['), '([l].', QUOTENAME([m].[column], '['), ', [r].', QUOTENAME([m].[column], '['), ', ', [m].[threshold], ') = 1')
	FROM @metadata AS [m]
		LEFT JOIN @metadata AS [next]
			ON [next].[ordinal] = [m].[ordinal] + 1
		LEFT JOIN @metadata AS [prev]
			ON [prev].[ordinal] = [m].[ordinal] - 1
	FOR XML PATH(''), TYPE
).value('./text()[1]', 'nvarchar(max)'), 1, 7, '(') + ')'
SET @cmd = CONCAT('
DROP TABLE IF EXISTS ', @object, ';
SELECT
	[l].[partition] AS [partition],
	[l].[pid] AS [l_pid],
	[r].[pid] AS [r_pid],
	[l].[id] AS [l_id],
	[r].[id] AS [r_id]
INTO ', IIF(@mash = 1, '[##matching_to_mash]', @object), '
FROM [##matching] AS [l]
	INNER JOIN [##matching] AS [r]
		ON [l].[partition] = [r].[partition]
		AND [l].[pid] < [r].[pid]
', 'WHERE ' + @cmd)
IF @print = 1 PRINT(@cmd)
IF @execute = 1 EXEC(@cmd)

DROP TABLE IF EXISTS [##matching];

IF @mash = 1
BEGIN
	SET @cmd = '
DECLARE @row_count int = 1
WHILE @row_count > 0
BEGIN
	UPDATE [right]
	SET [right].[l_pid] = [left].[l_pid],
		[right].[l_id] = [left].[l_id]
	FROM [##matching_to_mash] AS [left]
		INNER JOIN [##matching_to_mash] AS [right]
			ON [left].[partition] = [right].[partition]
			AND [left].[l_pid] < [right].[l_pid]
			AND [left].[r_pid] IN ([right].[l_pid], [right].[r_pid])

	SET @row_count = @@ROWCOUNT
END
'
	IF @print = 1 PRINT(@cmd);
	IF @execute = 1 EXEC(@cmd);

	SET @cmd = CONCAT('SELECT DISTINCT * INTO ', @object, ' FROM [##matching_to_mash]')
	IF @print = 1 PRINT(@cmd);
	IF @execute = 1 EXEC(@cmd);

	DROP TABLE IF EXISTS [##matching_to_mash];
END