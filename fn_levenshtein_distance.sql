CREATE OR ALTER FUNCTION [jadoube].[fn_levenshtein_distance](@string1 nvarchar(max), @string2 nvarchar(max))
RETURNS int
/*
[jadoube].[fn_levenshtein_distance]

Version: 1.2
Authors: JRA
Date: 2024-10-22

Explanation:
Returns the Levenshtein distance (a positive integer), calculated with the algorithm at https://www.codeproject.com/Articles/13525/Fast-memory-efficient-Levenshtein-algorithm-2. The closer the value to zero, the more similar the strings are.

Parameters:
- @string1 (nvarchar(max)): One of the strings to compare.
- @string2 (nvarchar(max)): The other string to compare.

Returns:
- (int)

Usage:
>>> [jadoube].[fn_levenshtein_distance]('Athena', 'Athena')
0
>>> [jadoube].[fn_levenshtein_distance]('Heracles', 'Hercules')
2
>>> [jadoube].[fn_levenshtein_distance]('Prometheus', 'Hephaestus')
8

Tasklist:
- Currently runs at roughly 13.6ms per execution for short strings. Possibly could be more optimised for the SQL engine?

History:
- 1.2 JRA (2024-10-22): Added case handling for NULL strings.
- 1.1 JRA (2024-10-18): Fixed a bug arising from `@array` being zero-indexed and T-SQL functions being one-indexed.
- 1.0 JRA (2024-10-14): Initial version. Runs on the order of 10ms per execution.
*/
BEGIN
IF @string1 = @string2 COLLATE Latin1_General_CS_AI
	RETURN 0

DECLARE @m int = LEN(@string1),
	@n int = LEN(@string2),
	@i int,
	@j int

IF @string1 IS NULL AND @string2 IS NULL
	RETURN 2147483647
ELSE IF @string1 IS NULL OR @m = 0
	RETURN @n
ELSE IF @string2 IS NULL OR @n = 0
	RETURN @m

DECLARE @array table ([id] int, [v0] int, [v1] int)

SET @i = 0
WHILE @i <= @n
BEGIN
	INSERT INTO @array([id], [v0])
	VALUES (@i, @i)

	SET @i += 1
END

SET @i = 0
WHILE @i < @m
BEGIN
	UPDATE @array
	SET [v1] = @i + 1
	WHERE [id] = 0

	SET @j = 0
	WHILE @j < @n
	BEGIN
		WITH [T]([cost]) AS (
			SELECT [v0] + 1 FROM @array WHERE [id] = @j + 1
			UNION ALL
			SELECT [v1] + 1 FROM @array WHERE [id] = @j
			UNION ALL
			SELECT [v0] + IIF(SUBSTRING(@string1, @i + 1, 1) = SUBSTRING(@string2, @j + 1, 1) COLLATE Latin1_General_CS_AI, 0, 1) FROM @array WHERE [id] = @j
		)
		UPDATE @array
		SET [v1] = [T].[cost]
		FROM (SELECT MIN([cost]) FROM [T]) AS [T]([cost])
		WHERE [id] = @j + 1

		SET @j += 1
	END
	
	UPDATE @array
	SET [v0] = [v1]

	SET @i += 1
END

RETURN (SELECT [v0] FROM @array WHERE [id] = @n)	
END