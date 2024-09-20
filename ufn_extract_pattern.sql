CREATE OR ALTER FUNCTION [jra].[ufn_extract_pattern] (
    @string nvarchar(max),
    @pattern nvarchar(max) = '[ABCDEFGHIJKLMNOPQRSTUVWXYZ,0-9]',
    @pattern_length int = 1
)
RETURNS nvarchar(max)
/* 
Version: 1.1
Author: JRA
Date: 2024-01-06

Description:
Given a string, a pattern and its length, the function removes instances of the pattern from the string.

Parameters:
- @string (nvarchar(max)): The string to extract from.
- @pattern (nvarchar(max)): The pattern to extract. Defaults to uppercase alphanumeric characters.
- @pattern_length (int): The length of the pattern to extract, defaults to single characters.

Returns:
- (nvarchar(max)): The reduced string.

Usage:
[jra].[ufn_extract_pattern]('Execute Order 66', DEFAULT, DEFAULT)
>>> 'EO66'

History:
- 1.1 JRA (2024-01-06): Added @pattern_length.
*/
AS
BEGIN
    DECLARE @c int = 1
    WHILE @c <= LEN(@string)
    BEGIN  
        IF PATINDEX(@pattern, SUBSTRING(@string, @c, @pattern_length) COLLATE Latin1_General_CS_AI) = 0
        BEGIN
            SET @string = STUFF(@string, @c, @pattern_length, '')
            CONTINUE
        END
        SET @c += 1
    END
RETURN @string
END