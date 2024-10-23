CREATE OR ALTER FUNCTION [jadoube].[fn_damerau_levenshtein_distance](@string1 nvarchar(4000), @string2 nvarchar(4000))
RETURNS int
/*
[jadoube].[fn_damerau_levenshtein_distance]

Version: 1.0
Authors: JRA
Date: 2024-10-22

Explanation:
Returns the unrestricted Damerau-Levenshtein distance. Similar to the optimal string alignment (OSA) distance - where deletions, insertions, substitutions and transpositions of adjacent characters are allowed - except in Damerau-Levenshtein a substring can be edited more than once. The closer the value to zero, the more similar the strings are. The algorithm used is based on https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance#Distance_with_adjacent_transpositions.

Parameters:
- @string1 (nvarchar(max)): One of the strings to compare.
- @string2 (nvarchar(max)): The other string to compare.

Returns:
- (int)

Usage:
>>> [jadoube].[fn_damerau_levenshtein_distance]('kitty', 'litter')
3
>>> [jadoube].[fn_damerau_levenshtein_distance]('damerau', 'demarera')
4
>>> [jadoube].[fn_damerau_levenshtein_distance]('Damerau', 'demarera')
5
>>> [jadoube].[fn_damerau_levenshtein_distance]('ca', 'abc')
2

History:
- 1.0 JRA (2024-10-22): Initial version. Runs at ~5-10ms.
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

DECLARE @alphabet table ([letter] nvarchar(2), [da] int);
WITH [cte] AS (
	SELECT 1 AS [index],
		SUBSTRING(@string1 + @string2, 1, 1) AS [letter]
	UNION ALL
	SELECT [index] + 1,
		SUBSTRING(@string1 + @string2, [index] + 1, 1)
	FROM [cte] 
	WHERE SUBSTRING(@string1 + @string2, [index] + 1, 1) <> ''
)
INSERT INTO @alphabet
SELECT DISTINCT [letter], 0 
FROM [cte]

DECLARE @i int,
	@j int,
	@k int,
	@l int,
	@width int = @len2 + 2,
	@total_len int = @len1 + @len2,
	@db int,
	@cost tinyint

DECLARE @array table ([index] int, [d] int);
SET @i = -1 - @width
WHILE @i < (@len1 + 1)*(@len2 + 1) + @len1
BEGIN
	INSERT INTO @array([index], [d])
	VALUES (
		@i, 
		CASE WHEN @i < -1 OR @i % @width IN (-1, @width - 1) THEN @total_len
			WHEN @i <= @len2 THEN @i
			WHEN @i % @width = 0 THEN @i / @width
			ELSE 0 END
	)
	SET @i += 1
END

SET @i = 1
WHILE @i <= @len1
BEGIN
	SET @db = 0

	SET @j = 1
	WHILE @j <= @len2
	BEGIN
		SET @k = (SELECT [da] FROM @alphabet WHERE [letter] = SUBSTRING(@string2, @j, 1) COLLATE Latin1_General_CS_AI)
		SET @l = @db
		
		IF SUBSTRING(@string1, @i, 1) = SUBSTRING(@string2, @j, 1) COLLATE Latin1_General_CS_AI
		BEGIN
			SET @cost = 0;
			SET @db = @j;
		END
		ELSE
			SET @cost = 1;

		WITH [T]([cost]) AS (
			SELECT [d] + @cost FROM @array WHERE [index] = @width*(@i-1) + (@j-1)
			UNION ALL
			SELECT [d] + 1 FROM @array WHERE [index] = @width*@i + (@j-1)
			UNION ALL
			SELECT [d] + 1 FROM @array WHERE [index] = @width*(@i-1) + @j
			UNION ALL
			SELECT [d] + @i + @j - @l - @k - 1 FROM @array WHERE [index] = @width*(@k-1) + (@l-1)
		)
		UPDATE @array
		SET [d] = (SELECT MIN([cost]) FROM [T])
		WHERE [index] = @width*@i + @j

	   SET @j += 1
	END
	
	UPDATE @alphabet
	SET [da] = @i
	WHERE [letter] = SUBSTRING(@string1, @i, 1) COLLATE Latin1_General_CS_AI

	SET @i += 1
END

RETURN (SELECT [d] FROM @array WHERE [index] = @width*@len1 + @len2)
END