CREATE OR ALTER FUNCTION [jadoube].[fn_matching_osa_low](
    @string1 nvarchar(4000),
    @string2 nvarchar(4000),
    @threshold int
)
RETURNS bit
/*
[jadoube].[fn_matching_osa_low]

Version: 1.0 
Authors: JRA
Date: 2024-10-22

Explanation:
Calculates whether two strings are within a threshold of similarity according to the optimal string alignment (OSA) distance. The recursive approach is used, so this works best for lower thresholds.

Parameters:
- @string1 (nvarchar(max)): One of the strings to compare.
- @string2 (nvarchar(max)): The other string to compare.
- @threshold (int): The threshold to measure against.

Returns:
- (bit): Returns true if the OSA distance of the two strings is within the given threshold (inclusive).

Usage:
>>> [jadoube].[fn_matching_levenshtein_low]('kitty', 'litter', 2)
0
>>> [jadoube].[fn_matching_levenshtein_low]('kitty', 'litter', 3)
1

History:
- 1.0 JRA (2024-10-22): Initial version.
*/
BEGIN
IF @threshold < 0
    RETURN 0

IF @string1 IS NULL AND @string2 IS NULL
    RETURN 0
ELSE IF @string1 = @string2
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

DECLARE @counter int,
	@score int

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
        @score = [score],
        @len1 = LEN([string1]),
        @len2 = LEN([string2])
    FROM @rec
    WHERE [id] = @counter

    IF @len1 = 0 AND @len2 = 0
    BEGIN
		IF @score <= @threshold
			RETURN 1

        UPDATE @rec
        SET [flag] = 1
        WHERE [id] = @counter

        SET @counter += 1
        CONTINUE
    END
    
    IF @len1 > 0
        INSERT INTO @rec([string1], [string2], [score])
        VALUES (STUFF(@string1, 1, 1, ''), @string2, @score + 1)
        
    IF @len2 > 0
        INSERT INTO @rec([string1], [string2], [score])
        VALUES (@string1, STUFF(@string2, 1, 1, ''), @score + 1)
    
    IF @len1 > 0 AND @len2 > 0
    BEGIN
        IF SUBSTRING(@string1, 1, 1) <> SUBSTRING(@string2, 1, 1) COLLATE Latin1_General_CS_AI
            SET @score += 1

        INSERT INTO @rec([string1], [string2], [score])
        VALUES (STUFF(@string1, 1, 1, ''), STUFF(@string2, 1, 1, ''), @score)
    END

	IF @len1 > 1 AND @len2 > 1
		IF SUBSTRING(@string1, 1, 2) = REVERSE(SUBSTRING(@string2, 1, 2)) COLLATE Latin1_General_CS_AI
            INSERT INTO @rec([string1], [string2], [score])
            VALUES (STUFF(@string1, 1, 2, ''), STUFF(@string2, 1, 2, ''), @score)

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