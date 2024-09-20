CREATE OR ALTER PROCEDURE [jra].[usp_string_table_split] (
    @string nvarchar(max),
    @separator nvarchar(max) = ',',
    @row_separator nvarchar(max) = ';',
    @header bit = 1,
    @print bit = 1,
    @display bit = 1
)
/* 
Version: 1.0
Author: JRA
Date: 2024-01-06

Description:
Given a string of delimited data and the delimiters, a tabulated form of the data is created.

Parameters:
- @string (nvarchar(max)): The string of delimited data.
- @separator (nvarchar(max)): The column separator.
- @row_separator (nvarchar(max)): The row separator.
- @header (bit): If true, the first row of the data is used as a header.
- @print (bit): If true, debug prints will be displayed.
- @display (bit): If true, tabular output will be displayed.

Returns:
- ##output (table): Tabulated data from given string.

Usage:
EXECUTE [jra].[usp_string_table_split]('Boss,Location;Massive Moss Charger,Greenpath', DEFAULT, DEFAULT, DEFAULT, 0, 1)
>>> #======================#===========#
    | Boss                 | Location  |
    #======================#===========#
    | Massive Moss Charger | Greenpath |
    +----------------------+-----------+
*/
AS
IF @print = 0
    SET NOCOUNT ON

DECLARE @cmd nvarchar(max),
    @row nvarchar(max),
    @col_count int,
    @row_count int,
    @c int = 1

SET @row_count = LEN(@string) - LEN(REPLACE(@string, @row_separator, ''))

IF @row_count = 0
    SET @row = @string
ELSE
    SET @row = SUBSTRING(@string, 1, CHARINDEX(@row_separator, @string, 1) - 1)

SET @col_count = 1 + LEN(@row) - LEN(REPLACE(@row, @separator, ''))

IF @header = 0
BEGIN
    SET @row = ''
    WHILE @c <= @col_count
    BEGIN
        SET @row += CONCAT('Column', @c, @separator)
        SET @c += 1
    END
END
ELSE
    SET @row += @separator

SET @row = REPLACE(@row, @separator, ' nvarchar(max), ')
SET @row = LEFT(@row, LEN(@row) - 1)

IF 1 = 0
    DROP TABLE IF EXISTS ##output; SELECT '' AS [ ] INTO ##output -- Beat the intellisense.

SET @cmd = CONCAT('DROP TABLE IF EXISTS ##output; 
CREATE TABLE ##output (', @row, ')')
IF @print = 1
    PRINT(@cmd)
EXEC(@cmd)

SET @cmd = CONCAT('INSERT INTO ##output
VALUES ', IIF(@header = 1, '--', ''), '(''', REPLACE(REPLACE(@string, @separator, ''', '''), @row_separator, CONCAT('''), ', CHAR(10), CHAR(9), '(''')), ''')'
)
IF @print = 1
    PRINT(@cmd)
EXEC(@cmd)

IF @display = 1
    SELECT * FROM ##output