CREATE OR ALTER FUNCTION [jadoube].[fn_matching_levenshtein_low](
	@string1 nvarchar(max), 
	@string2 nvarchar(max), 
	@threshold int
)
RETURNS bit
/*
[jadoube].[fn_matching_levenstein_low]

Version: 2.0
Authors: JRA
Date: 2024-10-23

Explanation:
Calculates whether two strings are within a threshold of similarity according to the Levenshtein distance. The recursive approach is used, so this works best for lower thresholds.

Parameters:
- @string1 (nvarchar(max)): One of the strings to compare.
- @string2 (nvarchar(max)): The other string to compare.
- @threshold (int): The threshold to measure against.

Returns:
- (bit): Returns true if the Levenshtein distance of the two strings is within the given threshold (inclusive).

Usage:
>>> [jadoube].[fn_matching_levenshtein_low]('kitty', 'litter', 2)
0
>>> [jadoube].[fn_matching_levenshtein_low]('kitty', 'litter', 3)
1

History:
- 2.0 JRA (2024-10-23): Rewrite based on knowledge gained from implementing OSA low.
- 1.1 JRA (2024-10-22): Changed case handling for NULL strings. Amended the breakout logic.
- 1.0 JRA (2024-10-15): Initial version. ~5ms per execution (with threshold 2).
*/
BEGIN
IF @threshold < 0
	RETURN 0

IF @string1 IS NULL AND @string2 IS NULL
	RETURN 0
ELSE IF @string1 = @string2 COLLATE Latin1_General_CS_AI
	RETURN 1
ELSE IF @threshold = 0
	RETURN 0

DECLARE @len1 int = LEN(@string1),
	@len2 int = LEN(@string2)

IF @string1 IS NULL OR @len1 = 0
	RETURN IIF(@len2 > @threshold, 0, 1)
ELSE IF @string2 IS NULL OR @len2 = 0
	RETURN IIF(@len1 > @threshold, 0, 1)
ELSE IF ABS(@len1 - @len2) > @threshold
	RETURN 0

DECLARE @counter int, @score int
DECLARE @rec table (
	[id] int NOT NULL IDENTITY(0, 1),
	[string1] nvarchar(4000),
	[string2] nvarchar(4000),
	[score] int,
	[flag] bit NOT NULL DEFAULT 0
)
INSERT INTO @rec([string1], [string2], [score])
VALUES (@string1, @string2, 0)

SET @counter = 0
WHILE @counter <= (SELECT MAX([id]) FROM @rec)
BEGIN
	SELECT @string1 = [string1],
		@string2 = [string2],
		@score = [score]
	FROM @rec
	WHERE [id] = @counter

	WHILE SUBSTRING(@string1, 1, 1) = SUBSTRING(@string2, 1, 1) COLLATE Latin1_General_CS_AI AND '' NOT IN (@string1, @string2)
	BEGIN
		SET @string1 = STUFF(@string1, 1, 1, '')
		SET @string2 = STUFF(@string2, 1, 1, '')
	END

	SET @len1 = LEN(@string1)
	SET @len2 = LEN(@string2)

	IF @len1 = 0 OR @len2 = 0
	BEGIN
		SET @score += IIF(@len1 = 0, @len2, @len1)

		IF @score <= @threshold
			RETURN 1

		UPDATE @rec
		SET [flag] = 1,
			[score] = @score
		WHERE [id] = @counter

		SET @counter += 1
		CONTINUE
	END

	SET @score += 1

	INSERT INTO @rec([string1], [string2], [score])
	VALUES (STUFF(@string1, 1, 1, ''), @string2, @score),
		(@string1, STUFF(@string2, 1, 1, ''), @score),
		(STUFF(@string1, 1, 1, ''), STUFF(@string2, 1, 1, ''), @score)

	DELETE FROM @rec
	WHERE [id] = @counter

	IF (SELECT MIN([score]) FROM @rec) > @threshold
		RETURN 0
	ELSE IF NOT EXISTS (SELECT 1 FROM @rec WHERE [flag] = 0)
		BREAK

	SET @counter += 1
END
IF (SELECT MIN([score]) FROM @rec) <= @threshold
	RETURN 1
RETURN 0
END