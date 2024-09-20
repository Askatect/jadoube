CREATE OR ALTER FUNCTION [jra].[ufn_string_split] (
    @string nvarchar(max),
    @separator nvarchar(max) = ','
)
RETURNS @array table ([value] nvarchar(max), [ordinal] int)
/*
[jra].[ufn_string_split]

Version: 2.1
Authors: JRA
Date: 2024-08-13

Explanation:
Splits a string into a table with [ordinal] as the zero-index and [value] as the value.

Parameters:
- @string (nvarchar(max)): The delimited string of data to turn into an array.
- @separator (nvarchar(max)): The delimiter. Defaults to ','.

Returns:
- @array (table): Tabulated data from input string.

Usage:
>>> SELECT * FROM [jra].[ufn_string_split]('Link,Zelda,Ganondorf', DEFAULT)
#===========#=========#
| value     | ordinal |
#===========#=========#
| Link      | 0       |
+-----------+---------+
| Zelda     | 1       |
+-----------+---------+
| Ganondorf | 2       |
+-----------+---------+

History:
- 2.1 JRA (2024-08-13): Now checking for compatibility level 160; only SQL Server 2022 16.x and later has the ordinal argument of STRING_SPLIT.
- 2.0 JRA (2024-07-02): Added [ordinal] to output.
- 1.1 JRA (2024-01-08): Whitespace of values is trimmed.
- 1.0 JRA: Initial version.
*/
AS
BEGIN
    IF (SELECT [compatibility_level] FROM sys.databases WHERE [name] = DB_NAME()) >= 160
        INSERT INTO @array SELECT RTRIM(LTRIM([value])), [ordinal] - 1 FROM STRING_SPLIT(@string, @separator, 1)
    ELSE
    BEGIN
        DECLARE @c int = 1,
            @loc int
        SET @string += @separator
        SET @loc = CHARINDEX(@separator, @string, @c)
        WHILE @loc > 0
        BEGIN
            INSERT INTO @array ([value], [ordinal])
            VALUES (RTRIM(LTRIM(SUBSTRING(@string, @c, @loc - @c))), (SELECT COUNT(*) FROM @array));
            SET @c = @loc + LEN(@separator)
            SET @loc = CHARINDEX(@separator, @string, @c)
        END
    END
    RETURN;
END