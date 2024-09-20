CREATE OR ALTER FUNCTION [jra].[ufn_hexcode_to_rgb] (@hexcode char(7))
RETURNS @Output TABLE ([rgb] char(1), [value] int)
/*
Version: 1.0
Author: JRA
Date: 2024-01-06

Description:
Converts a hexcode to RGB values.

Parameters:
- @hexcode (char(7)): Input hexcode to convert.

Returns:
- @Output (table([rgb] char(1), [value] int)): RGB values in tabulated format.

Usage:
[jra].[hexcode_to_rgb]('#181848')
>>> #=====#=======#
	| rgb | value |
	#=====#=======#
	| r   |    24 |
	+-----+-------+
	| g   |    24 |
	+-----+-------+
	| b   |    72 |
	+-----+-------+
*/
AS
BEGIN
	IF LEN(@hexcode) = 4
		SET @hexcode = '#' + SUBSTRING(@hexcode, 2, 1) + SUBSTRING(@hexcode, 2, 1) + SUBSTRING(@hexcode, 3, 1) + SUBSTRING(@hexcode, 3, 1) + SUBSTRING(@hexcode, 4, 1) + SUBSTRING(@hexcode, 4, 1)
	ELSE IF LEN(@hexcode) <> 7
		RETURN

	INSERT INTO @Output
	SELECT *
	FROM (
		VALUES ('r', CONVERT(int, CONVERT(binary(1), '0x' + SUBSTRING(@hexcode, 2, 2), 1))),
			('g', CONVERT(int, CONVERT(binary(1), '0x' + SUBSTRING(@hexcode, 4, 2), 1))),
			('b', CONVERT(int, CONVERT(binary(1), '0x' + SUBSTRING(@hexcode, 6, 2), 1)))
	) AS [Output]([rgb], [value])
	RETURN
END