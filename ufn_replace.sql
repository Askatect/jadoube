CREATE OR ALTER FUNCTION [jra].[ufn_replace](
    @old_substring nvarchar(max), 
    @new_substring nvarchar(max), 
    @strict bit = 1,
    @string nvarchar(max)
)
RETURNS nvarchar(max)
/*
Version: 2.0
Author: JRA
Date: 2024-02-09

Explanation:
Replaces occurrences of a substring - can be a regex set - with another substring in the input string, until no further substitutions need be made.

Parameters:
- @old_substring (nvarchar(max)): The substring or regex set to be replaced.
- @new_substring (nvarchar(max)): The replacement substring.
- @strict (bit): If true, replacement only occurs if the replacement substring is not already present.
- @string (nvarchar(max)): The input string.

Returns:
- (nvarchar(max)): The input with string with all appropriate replacements.

Usage:
>>> [jra].[ufn_replace]('Old', 'New', 0, 'Replace Old Text')
'Replace New Text'
>>> [jra].[ufn_replace]('New', 'Newer', 1, 'Replace New Text')
'Replace New Text'
>>> [jra].[ufn_replace]('  ', ' ', 0, 'Three   spaces.')
'Three spaces.'
>>> [jra].[ufn_replace]('[^0-9]', '', 0, 'Source_20240101.csv')
'20240101'

History:
- 2.0 (2024-02-09): The @old_substring can now be a regex set.
- 1.3 (2024-01-19): Fixed another infinite loop bug.
- 1.2 (2024-01-17): Fixed an infinite loop bug.
- 1.1 (2024-01-15): Recursive replacement implemented.
- 1.0 (2023-12-05): Initial version.
*/
BEGIN
DECLARE @recursion bit = 0,
	@c int = 1,
	@string_prev varchar(max) = @string,
	@regex_set bit = 0

IF @strict = 1 AND @string LIKE '%' + @new_substring + '%'
	RETURN @string

IF @new_substring LIKE '%' + @old_substring + '%'
	SET @recursion = 1

IF @old_substring LIKE '%]%'
BEGIN
	DECLARE @char varchar(1),
		@old_substring_length int = 0
	WHILE @c <= LEN(@old_substring)
	BEGIN
		SET @char = SUBSTRING(@old_substring, @c, 1)
		IF @char = '['
		BEGIN
			SET @old_substring_length += 1
			SET @regex_set = 1
		END
		ELSE IF @char = ']'
			SET @regex_set = 0
		ELSE IF @regex_set = 0
			SET @old_substring_length += 1
		SET @c += 1
	END
	SET @regex_set = 1
END

SET @c = PATINDEX('%' + @old_substring + '%' COLLATE Latin1_General_CS_AI, @string)
WHILE @c > 0
BEGIN
	IF @regex_set = 1
	BEGIN
		WHILE @c > 0
		BEGIN
			SET @string = STUFF(@string, @c, @old_substring_length, @new_substring)
			SET @c += ISNULL(NULLIF(PATINDEX('%' + @old_substring + '%' COLLATE Latin1_General_CS_AI, SUBSTRING(@string, 1 + @c + DATALENGTH(@new_substring) - @old_substring_length, LEN(@string))), 0), -(@c + DATALENGTH(@new_substring) - @old_substring_length)) + DATALENGTH(@new_substring) - @old_substring_length
		END
	END
	ELSE
		SET @string = REPLACE(@string, @old_substring, @new_substring)

	IF @recursion = 1
		RETURN @string

	IF @string_prev = @string
		RETURN @string
	ELSE
		SET @string_prev = @string

	SET @c = PATINDEX('%' + @old_substring + '%' COLLATE Latin1_General_CS_AI, @string)
END

RETURN @string

END
GO