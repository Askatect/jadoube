CREATE OR ALTER FUNCTION [jadoube].[fn_jaro_similarity](@string1 nvarchar(4000), @string2 nvarchar(4000))
RETURNS numeric(9, 8)
/*
[jadoube].[fn_jaro_similarity]

Version: 1.0
Authors: JRA
Date: 2024-10-21

Explanation:
Computes the Jaro similarity between two strings. This is a value in the interval [0, 1], where 1 is an exact match. This algorithm is based on https://www.geeksforgeeks.org/jaro-and-jaro-winkler-similarity/.

Parameters:
- @string1 (nvarchar(4000)): One of the strings to compare.
- @string2 (nvarchar(4000)): The other string to compare to.

Returns:
- (numeric(9, 8))

Usage:
>>> [jadoube].[fn_jaro_similarity]('virtuoso', 'viscous')
0.71309524

History:
- 1.0 JRA (2024-10-21): Initial version. Runs at ~2ms.
*/
BEGIN
IF @string1 = @string2 COLLATE Latin1_General_CS_AI
    RETURN 1

DECLARE @max_dist int,
	@max_length int,
    @length1 int = LEN(@string1),
    @length2 int = LEN(@string2),
	@matches int = 0,
	@i int,
	@j int
SET @max_length = (@length1 + @length2 + ABS(@length1 - @length2)) / 2
SET @max_dist = @max_length / 2 - 1
IF @max_dist < 0
	SET @max_dist = 0

DECLARE @array table ([index] int, [string1] char(1), [s1] bit, [string2] char(1), [s2] bit);
WITH [cte] AS (
	SELECT 0 AS [index], 
		SUBSTRING(@string1, 1, 1) AS [string1],
		0 AS [s1], 
		SUBSTRING(@string2, 1, 1) As [string2],
		0 AS [s2]
	UNION ALL
	SELECT [index] + 1, SUBSTRING(@string1, [index] + 2, 1), 0, SUBSTRING(@string2, [index] + 2, 1), 0
	FROM [cte]
	WHERE [index] < @max_length - 1
)
INSERT INTO @array
SELECT * FROM [cte]

SET @i = 0
WHILE @i < @length1
BEGIN
	SET @j = @i - @max_dist
	IF @j < 0
		SET @j = 0
	WHILE @j < @length2 AND @j < @i + @max_dist + 1
	BEGIN
		IF SUBSTRING(@string1, @i + 1, 1) = SUBSTRING(@string2, @j + 1, 1) COLLATE Latin1_General_CS_AI
			AND (SELECT [s2] FROM @array WHERE [index] = @j) = 0
		BEGIN
			UPDATE @array
			SET [s1] = 1
			WHERE [index] = @i

			UPDATE @array
			SET [s2] = 1
			WHERE [index] = @j

			SET @matches += 1

			BREAK;
		END
		SET @j += 1
	END
	SET @i += 1
END

IF @matches = 0
	RETURN 0

DECLARE @transpositions AS int = 0
SET @j = 0
SET @i = 0
WHILE @i < @length1
BEGIN
	IF (SELECT [s1] FROM @array WHERE [index] = @i) = 1
	BEGIN
		WHILE (SELECT [s2] FROM @array WHERE [index] = @j) = 0
			SET @j += 1
		
		IF SUBSTRING(@string1, @i + 1, 1) <> SUBSTRING(@string2, @j + 1, 1) COLLATE Latin1_General_CS_AI
			SET @transpositions += 1
		
		SET @j += 1
	END
	SET @i += 1
END

RETURN (CONVERT(numeric, @matches)/@length1
	+ CONVERT(numeric, @matches)/@length2
	+ 1 - CONVERT(numeric, @transpositions/2)/(@matches)) / 3
END