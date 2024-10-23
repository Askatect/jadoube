CREATE OR ALTER PROCEDURE [jadoube].[p_structure_compliance] (
	@job_id char(36) = '00000000-0000-0000-0000-000000000000',
	@job_name varchar(256) = 'source_999_aspect',
	@truncation_check bit = 1,
	@schema varchar(128) = NULL,
	@table varchar(128),
	@object_structure varchar(256) = NULL,
	@print bit = 0
)
/*
[jadoube].[p_structure_compliance]

Version: 1.0
Authors: JRA
Date: 2024-08-08

Explanation:
Adds an [__error__] column to a specified object an populates it with cases where the object deviates from a particular structure. The structure can be chosen by pointing at an existing object. Column name and order are checked, datatypes are checked, truncation errors are optionally checked and non-nullability is also checked.

Parameters:
- @job_id char(36): Job ID to use. Not currently required. Defaults to '00000000-0000-0000-0000-000000000000'.
- @job_name varchar(256): The name of the job. Can be used to conditionally select the structure. Defaults to 'source_999_aspect'.
- @truncation_check bit: If true, checks for truncation errors are made. Defaults to true.
- @schema varchar(128): The schema of the object to check compliance of. Defaults to default schema.
- @table varchar(128): The table of the object to check compliance of.
- @object_structure varchar(256): When provided and the object exists, the structure of that object is used. Defaults to no object.
- @print bit: If true, debug statements are printed. Defalts to false.

Usage:
>>> EXECUTE [jadoube].[p_structure_compliance] @job_name = 'FastStats_001_DataMart', @schema = NULL, @table = '##mastercontact', @print = 1

Tasklist:
- Use sys.indexes to get information about primary keys/uniqueness constraints for when @object_structure is specified.

History:
- 1.0 JRA (2024-08-08): Initial version.
*/
AS
DECLARE @source varchar(256) = CONCAT(QUOTENAME(@schema) + '.', QUOTENAME(@table)),
	@cmd nvarchar(max),
	@counter int = 1

DECLARE @structure table (
	[id] int,
	[name] varchar(128),
	[datatype] varchar(16),
	[length] int,
	[scale] int,
	[nullable] bit,
	[unique] tinyint,
	[datestyle] varchar(4),
	[datatype_string] AS CASE WHEN [datatype] IN ('decimal', 'numeric') THEN CONCAT([datatype], '(', [length], ', ', [scale], ')')
		WHEN [datatype] LIKE '%char' THEN CONCAT([datatype], '(', [length], ')')
		ELSE [datatype]
		END
)
IF OBJECT_ID(@object_structure) IS NOT NULL
BEGIN
	INSERT INTO @structure ([id], [name], [datatype], [length], [scale], [nullable])
	SELECT [c].[column_id], 
		[c].[name],
		[t].[name],
		CASE WHEN [t].[name] LIKE '%char' THEN [c].[max_length]
			WHEN [t].[name] IN ('decimal', 'numeric') THEN [c].[precision]
			END,
		CASE WHEN [t].[name] IN ('decimal', 'numeric') THEN [c].[scale] END,
		[c].[is_nullable]
	FROM sys.columns AS [c]
		INNER JOIN sys.types AS [t]
			ON [t].[system_type_id] = [c].[system_type_id]
	WHERE [object_id] = OBJECT_ID(@object_structure)
END

IF (SELECT COUNT(*) FROM @structure) = 0
	THROW 1419201803, 'No structure found to apply.', 1

SET @cmd = CONCAT('ALTER TABLE ', @source, ' ADD [__error__] nvarchar(4000) NOT NULL DEFAULT ''''', CHAR(10))
IF @print = 1 PRINT(@cmd)
EXEC(@cmd)

SET @cmd = 'Column error: ' + STUFF((
	SELECT ', ' + CASE WHEN [source].[name] IS NULL THEN CONCAT(QUOTENAME([target].[name], '['), ' is missing from position ', [target].[id])
			WHEN [target].[name] IS NULL THEN CONCAT(QUOTENAME([source].[name], '['), ' (', [source].[column_id], ') is spurious')
			WHEN [target].[id] <> [source].[column_id] THEN CONCAT(QUOTENAME([source].[name]), ' (', [source].[column_id], ') should be in position ', [target].[id])
			END
	FROM @structure AS [target]
		FULL JOIN sys.columns AS [source]
			ON [source].[name] = [target].[name]
			AND [source].[object_id] = OBJECT_ID(@source)
			AND [source].[name] NOT LIKE '[_][_]%[_][_]'
	WHERE ([target].[id] IS NOT NULL
			OR [source].[object_id] = OBJECT_ID(@source))
		AND ([target].[name] IS NULL
			OR [source].[name] IS NULL
			OR [target].[id] <> [source].[column_id])
	FOR XML PATH('')
), 1, 2, '') + '. '
IF @cmd IS NOT NULL
BEGIN
	SET @cmd = CONCAT('UPDATE ', @source, ' SET [__error__] += ', QUOTENAME(@cmd, ''''), CHAR(10))
	IF @print = 1 PRINT(@cmd)
    EXEC(@cmd)
END

SET @counter = 1
WHILE @counter <= (SELECT COUNT(*) FROM @structure)
BEGIN
	SELECT @cmd = CONCAT('UPDATE ', @source, '
SET [__error__] += CASE
		WHEN TRY_CONVERT(', [datatype_string], ', ', QUOTENAME([name], '['), ', ' + [datestyle], ') IS NULL THEN ', QUOTENAME(CONCAT('Datatype error: ', QUOTENAME([name], '['), ' could not be converted to ', [datatype_string], ' using datestyle ' + [datestyle], '. '), ''''), IIF(@truncation_check = 0, '', CONCAT('
		WHEN LEN(TRY_CONVERT(', [datatype_string], ', ', QUOTENAME([name], '['), ', ' + [datestyle], ')) < LEN(', QUOTENAME([name], '['), ') THEN ', QUOTENAME(CONCAT('Truncation error: ', QUOTENAME([name], '['), ' would be truncated when converted to ', [datatype_string], ' using datestyle ' + [datestyle], '. '), ''''))), '
		ELSE '''' END
WHERE ', QUOTENAME([name]), ' IS NOT NULL', CHAR(10))
	FROM @structure
	WHERE [id] = @counter 
		AND [name] IN (SELECT [name] FROM sys.columns WHERE [object_id] = OBJECT_ID(@source))
	IF @print = 1 PRINT(@cmd)
    EXEC(@cmd)

	SET @counter += 1
END

SET @counter = 1
WHILE @counter <= (SELECT COUNT(*) FROM @structure)
BEGIN
	SELECT @cmd = CONCAT('UPDATE ', @source, '
SET [__error__] += ', QUOTENAME(CONCAT('Nullability error: ', QUOTENAME([name], '['), ' does not contain data. '), ''''), '
WHERE ', QUOTENAME([name], '['), ' IS NULL', CHAR(10))
	FROM @structure
	WHERE [id] = @counter
		AND [nullable] = 0

	IF @@ROWCOUNT = 1
    BEGIN
		IF @print = 1 PRINT(@cmd)
        EXEC(@cmd)
    END

	SET @counter += 1
END

SET @counter = 1
WHILE @counter <= (SELECT MAX([unique]) FROM @structure)
BEGIN
	SET @cmd = STUFF((
		SELECT ', ' + QUOTENAME([name], '[')
		FROM @structure
		WHERE [unique] = @counter
		ORDER BY [id]
		FOR XML PATH('')
	), 1, 2, '')
	SELECT @cmd = CONCAT('UPDATE ', @source, '
SET [__error__] = ', QUOTENAME(CONCAT('Uniqueness error: ', QUOTENAME(@cmd, '('), ' contains duplicates. '), ''''), '
WHERE CONCAT_WS(''::'', ', @cmd, ') IN (
	SELECT CONCAT_WS(''::'', ', @cmd, ')
	FROM ', @source, '
	GROUP BY ', @cmd, '
	HAVING COUNT(*) > 1
)', CHAR(10))
	IF @print = 1 PRINT(@cmd)
    EXEC(@cmd)

	SET @counter += 1
END