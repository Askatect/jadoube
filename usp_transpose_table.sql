CREATE OR ALTER PROCEDURE [jra].[usp_transpose_table] (@query varchar(max),
	@output varchar(max) = '[jra].[output]'
)
/*
Version: 1.0
Author: JRA
Date: 2024-01-06

Description:
Transposes a table defined by a DQR script.

Parameters:
- @query (varchar(max)): DQR script with table to transpose.
- @output (varchar(max)): Name of output table.

Usage:
EXECUTE [jra].[usp_transpose_table] @query = 'SELECT * FROM (VALUES (''Sapphira'', ''Blue''), (''Thorn'', ''Red''), (''Glaedr'', ''Gold''), (''Firnen'', ''Green''), (''Shruikan'', ''Black'')) AS [T]([Dragon] nvarchar(max), [Colour] nvarchar(max))', @output = '##Transposed'
SELECT * FROM ##Transposed
>>> #========#==========#=======#========#========#==========#
	| Dragon | Sapphira | Thorn | Glaedr | Firnen | Shruikan |
	#========#==========#=======#========#========#==========#
	| Colour | Blue     | Red   | Gold   | Green  | Black    |
	+--------+----------+-------+--------+--------+----------+
*/
AS
BEGIN
	SET NOCOUNT ON

	DROP TABLE IF EXISTS [jra].[temp]
	DROP TABLE IF EXISTS #columns
	DROP TABLE IF EXISTS ##insert

	DECLARE @cmd varchar(max)
	SET @cmd = CONCAT('
		SELECT *
		INTO [jra].[temp]
		FROM (', @query, ') AS [T]
	')
	--PRINT(@cmd)
	EXEC(@cmd)

	DECLARE @c int, @col varchar(max)
	DECLARE cols_cursor SCROLL cursor FOR
	SELECT [column_id] AS [c],
		[name] AS [col]
	FROM sys.columns
	WHERE [object_id] = OBJECT_ID('[jra].[temp]')
	ORDER BY [column_id]

	OPEN cols_cursor

	FETCH FIRST FROM cols_cursor
	INTO @c, @col

	SET @cmd = CONCAT('
		SELECT ', @c, ' AS [c], CONCAT(''(['', STRING_AGG(ISNULL(CONVERT(varchar, [', @col, '], 21), ''NULL''), ''] varchar(max), [''), ''] varchar(max))'') AS [values]
		INTO ##insert
		FROM [jra].[temp]
	')

	WHILE @@FETCH_STATUS = 0
	BEGIN
		FETCH NEXT FROM cols_cursor
		INTO @c, @col

		SET @cmd += CONCAT('
			UNION
			SELECT ', @c, ', CONCAT(''('''''', STRING_AGG(ISNULL(CONVERT(varchar, [', @col, '], 21), ''NULL''), '''''', ''''''), '''''')'')
			FROM [jra].[temp]
		')
	END
	--PRINT(@cmd)
	EXEC(@cmd)

	SET @cmd = CONCAT('
		CREATE TABLE ', @output, '
		', (SELECT [values] FROM ##insert WHERE [c] = 1)
	)
	--PRINT(@cmd)
	EXEC(@cmd)

	SET @cmd = CONCAT('
		INSERT INTO ', @output, '
		--OUTPUT inserted.*
		VALUES ', (SELECT STRING_AGG([values], ', ' + CHAR(10)) FROM ##insert WHERE [c] > 1)
	)
	--PRINT(@cmd)
	EXEC(@cmd)

	CLOSE cols_cursor
	DEALLOCATE cols_cursor

	DROP TABLE IF EXISTS [jra].[temp]
	DROP TABLE IF EXISTS #columns
	DROP TABLE IF EXISTS ##insert
END