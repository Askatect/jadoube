CREATE OR ALTER FUNCTION [jra].[ufn_start_case](@string nvarchar(max))
RETURNS nvarchar(max)
AS
/*
[jra].[ufn_start_case]

Version: 2.1
Author: JRA
Date: 2024-08-22

Explanation:
Converts a given string to start case.

Parameters:
- @string (nvarchar(max)): The string to convert.

Returns:
- (nvarchar(max)): The given string in start case.

Usage:
[jra].[ufn_start_case]('semi-EULERIAN gRaPh')
>>> 'Semi-Eulerian Graph'

History:
- 2.1 JRA (2024-08-22): Added '\', '&', CHAR(9), CHAR(10) and CHAR(13) as characters to precede a capital.
- 2.0 JRA (2024-01-17): Complete rewrite - no fancy tricks, just a loop over the word.
- 1.0 JRA (2024-01-15): Initial version.
*/
BEGIN
SET @string = LOWER(@string)
DECLARE @c int = 1,
    @char nvarchar(2) = LEFT(@string, 1)
WHILE @c <= LEN(@string)
BEGIN
    IF @c = 1 OR @char IN (' ', '-', '\', '&', CHAR(9), CHAR(10), CHAR(13))
    BEGIN
        SET @char = SUBSTRING(@string, @c, 1)
        SET @string = STUFF(@string, @c, 1, UPPER(@char))
    END
    ELSE
        SET @char = SUBSTRING(@string, @c, 1)
    SET @c += 1
END
RETURN @string
END
GO