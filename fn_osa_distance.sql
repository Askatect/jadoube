CREATE OR ALTER FUNCTION [jadoube].[fn_osa_distance](@string1 nvarchar(4000), @string2 nvarchar(4000))
RETURNS int
/*
[jadoube].[fn_osa_distance]

Version: 1.0
Authors: JRA
Date: 2024-10-22

Explanation:
Returns the optimal string alignment distance (also known as the restricted edit distance). Similar to the Damerau-Levenshtein distance - where deletions, insertions, substitutions and transpositions of adjacent characters are allowed - except in OSA a substring may not be edited more than once. The closer the value to zero, the more similar the strings are. The algorithm used is a variant of the Wagner-Fischer algorithm and is also memory optimised.

Parameters:
- @string1 (nvarchar(max)): One of the strings to compare.
- @string2 (nvarchar(max)): The other string to compare.

Returns:
- (int)

Usage:
>>> [jadoube].[fn_osa_distance]('Athena', 'Athena')
0
>>> [jadoube].[fn_osa_distance]('Herucles', 'Hercules')
1
>>> [jadoube].[fn_osa_distance]('Heracles', 'Hercules')
2
>>> [jadoube].[fn_osa_distance]('Prometheus', 'Hephaestus')
8
>>> [jadoube].[fn_osa_distance]('ca', 'abc')
3

Tasklist:
- Write [jadoube].[fn_matching_osa_low] from the recursive definition.

History:
- 1.0 JRA (2024-10-22): Initial version. Runs at ~5ms.
*/
BEGIN
IF @string1 = @string2 COLLATE Latin1_General_CS_AI
	RETURN 0

DECLARE @len1 int = LEN(@string1),
	@len2 int = LEN(@string2)

IF @string1 IS NULL AND @string2 IS NULL
	RETURN 2147483647
ELSE IF @string1 IS NULL OR @len1 = 0
	RETURN @len2
ELSE IF @string2 IS NULL OR @len2 = 0
	RETURN @len1

DECLARE @i int,
	@j int,
	@min int

DECLARE @array table ([index] int, [r-1] int, [r0] int, [r1] int)

SET @i = 0
WHILE @i <= @len2
BEGIN
	INSERT INTO @array([index], [r0])
	VALUES (@i, @i)

	SET @i += 1
END

SET @i = 0
WHILE @i < @len1
BEGIN
	UPDATE @array
	SET [r1] = @i + 1
	WHERE [index] = 0

	SET @j = 0
	WHILE @j < @len2
	BEGIN
		WITH [T]([cost]) AS (
			SELECT [r0] + 1 FROM @array WHERE [index] = @j + 1
			UNION ALL
			SELECT [r1] + 1 FROM @array WHERE [index] = @j
			UNION ALL
			SELECT [r0] + IIF(SUBSTRING(@string1, @i + 1, 1) = SUBSTRING(@string2, @j + 1, 1) COLLATE Latin1_General_CS_AI, 0, 1) FROM @array WHERE [index] = @j
		)
		SELECT @min = MIN([cost]) FROM [T]

		IF @i > 0 
			AND @j > 0 
			AND SUBSTRING(@string1, @i, 1) = SUBSTRING(@string2, @j + 1, 1) COLLATE Latin1_General_CS_AI
			AND SUBSTRING(@string1, @i + 1, 1) = SUBSTRING(@string2, @j, 1) COLLATE Latin1_General_CS_AI
		BEGIN
			WITH [T]([cost]) AS (
				SELECT @min
				UNION ALL
				SELECT [r-1] + 1 FROM @array WHERE [index] = @j - 1
			)
			SELECT @min = MIN([cost]) FROM [T]
		END

		UPDATE @array
		SET [r1] = @min
		WHERE [index] = @j + 1

		SET @j += 1
	END

	UPDATE @array
	SET [r-1] = [r0],
		[r0] = [r1]

	SET @i += 1
END

RETURN (SELECT [r1] FROM @array WHERE [index] = @len2)

END