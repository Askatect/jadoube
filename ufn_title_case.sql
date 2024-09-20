CREATE OR ALTER FUNCTION [utl].[ufn_title_case] (
    @string nvarchar(4000)
)
RETURNS nvarchar(4000)
/*
[utl].[ufn_title_case]

Version: 1.0
Authors: JRA
Date: 2024-06-20

Explanation:
Converts an input string to title case.

Parameters:
- @string (nvarchar(max)): The input string to convert.

Returns:
- @string (nvarchar(max)): The input string in title case.

Usage:
>>> PRINT('the life-changing MAGIC of tidying up: the japanese sEnSAtiOn - over 3 million copies sold')
'The Life-Changing Magic of Tidying Up: The Japanese Sensation - Over 3 Million Copies Sold'

Tasklist:
- Different rules exist for title case, so there's more that could be done. See https://en.wikipedia.org/wiki/Title_case.

History:
- 1.0 JRA (2024-06-20): Initial version.
*/
BEGIN
DECLARE @word nvarchar(4000),
    @separators varchar(32),
    @terminals varchar(8) = '!?.;:' + CHAR(10),
    @internals varchar(8) = ' ,',
    @enclosers varchar(8) = '([{',
    @divisives varchar(8) = '/\-',
    @type varchar(16),
    @c int,
    @capitalise bit = 1

DECLARE @output nvarchar(max) = ''

DECLARE @next_punctuations table (
    [type] varchar(16),
    [word_length] int NOT NULL DEFAULT 0
)
INSERT INTO @next_punctuations ([type])
VALUES (@terminals), (@internals), (@enclosers), (@divisives)

SET @string = LOWER(@string)
SET @c = 1

WHILE @c IS NOT NULL
BEGIN
    UPDATE @next_punctuations
    SET [word_length] = PATINDEX('%' + QUOTENAME([type], '[') + '%', SUBSTRING(@string, @c, LEN(@string)))

    SET @type = (SELECT TOP(1) [type] FROM @next_punctuations WHERE [word_length] > 0 ORDER BY [word_length] ASC)
    SET @word = SUBSTRING(@string, @c, ISNULL((SELECT MIN([word_length]) FROM @next_punctuations WHERE [word_length] > 0), LEN(@string)))

    IF @capitalise = 1 OR @word NOT IN ('a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'in', 'nor', 'of', 'on', 'or', 'so', 'the', 'to', 'up', 'yet', 'is')
    BEGIN
        SET @string = STUFF(@string, @c, 1, UPPER(LEFT(@word, 1)))
        IF @type = @divisives
            SET @capitalise = 1
        ELSE
            SET @capitalise = 0
    END

    IF @type IN (@terminals, @enclosers)
        SET @capitalise = 1

    SET @c += (SELECT MIN([word_length]) FROM @next_punctuations WHERE [word_length] > 0)

    IF @c > LEN(@string)
        SET @c = NULL
END

RETURN @string
END