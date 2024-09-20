CREATE OR ALTER FUNCTION [jra].[ufn_extract_param] (
    @string varchar(max),
    @separator varchar(1) = ';',
    @key varchar(max),
    @include_key bit = 0
)
RETURNS varchar(max)
/*
[jra].[ufn_extract_param]

Version: 1.0
Authors: JRA
Date: 2024-02-08

Explanation:
Extracts parameters from strings formed of key/value pairs, optionally with separators.

Parameters:
- @string (varchar(max)): The string of key/value pairs.
- @separator (varchar(1)): The separator of key/value pairs. Defaults to ';'.
- @key (varchar(max)): The key to find the value of - can be a SQL regular expression.
- @include_key (bit): If true, the key and value are returned. If false, only the value is returned. Defaults to false.

Returns:
- (varchar(max))

Usage:
>>> [jra].[ufn_extract_param]('server=<server>;database=<database>', DEFAULT, @key = 'database_', DEFAULT)
'<database>'

History:
- 1.0 JRA (2024-02-08): Initial version.
*/
BEGIN
DECLARE @c int = 1,
    @key_length int = 0,
    @regex_set bit = 0,
    @char char(1),
    @key_pos int,
    @val_pos int

WHILE @c <= LEN(@key)
BEGIN
    SET @char = SUBSTRING(@key, @c, 1)
    IF @char = '['
    BEGIN
        SET @key_length += 1
        SET @regex_set = 1
    END
    ELSE IF @char = ']'
        SET @regex_set = 0
    ELSE IF @regex_set = 0
        SET @key_length += 1
    SET @c += 1
END

SET @key_pos = PATINDEX('%' + @key + '%', @string COLLATE Latin1_General_CS_AI)
IF @key_pos = 0
    RETURN NULL
SET @val_pos = CHARINDEX(@separator, @string, @key_pos + @key_length)
SET @c = IIF(@include_key = 1, 0, @key_length) + @key_pos

RETURN SUBSTRING(@string, @c, IIF(@val_pos = 0, LEN(@string), @val_pos - @c))
END
GO
