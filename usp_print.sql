CREATE OR ALTER PROCEDURE [jra].[usp_print] (@string nvarchar(max))
/*
Version: 1.0
Author: JRA
Date: 2024-01-06

Description:
Prints large strings to console.

Parameters:
- @string (nvarchar(max)): String to print.

Returns:
Prints the given string.

Usage:
EXECUTE [jra].[usp_print](<long string>)
>>> <long string>
*/
AS

SET @string = REPLACE(@string, CHAR(13), CHAR(10))

DECLARE @working_string nvarchar(max),
	@position int, 
	@newline tinyint

WHILE LEN(@string) > 0
BEGIN
	SET @working_string = SUBSTRING(@string, 1, 4000)
	SET @position = CHARINDEX(CHAR(10), REVERSE(@working_string))
	IF @position = 0
	BEGIN
		SET @position = LEN(@working_string)
		SET @newline = 1
	END
	ELSE
	BEGIN
		SET @position = LEN(@working_string) - @position
		SET @newline = 2
	END
	PRINT(SUBSTRING(@string, 1, @position))
	SET @string = SUBSTRING(@string, @newline + @position, LEN(@string))
END
GO