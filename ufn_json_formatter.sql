CREATE OR ALTER FUNCTION [jra].[ufn_json_formatter](@json nvarchar(max))
RETURNS nvarchar(max)
/*
Version: 1.0
Author: JRA
Date: 2024-01-06

Description:
Formats an input JSON string with line breaks and indents.

Parameters:
- @json (nvarchar(max)): Input JSON to format.

Returns:
 - @json (nvarchar(max)): Formatted JSON.

Usage:
[jra].[ufn_json_formatter]('{"game": ["Super", "Mario", "Odyssey"], "moons": 880, "bosses": {"Cascade": "Madame Broode", "Metro": "Mechawiggler", "Ruined": "Lord of Lightning"}}')
>>> {
		"game": [
			"Super",
			"Mario",
			"Odyssey"
		],
		"moons": 880,
		"bosses": {
			"Cascade": "Madame Broode",
			"Metro": "Mechawiggler",
			"Ruined": "Lord of Lightning"
		}
	}
*/
AS
BEGIN
SET @json = REPLACE(REPLACE(@json, CHAR(10), ''), CHAR(9), '')

DECLARE @word nvarchar(256) = '',
	@string bit = 0,
	@c int = 0,
	@char nvarchar(4) = ''

DECLARE @jsonwords table (id int, word nvarchar(256))

WHILE @c <= len(@json)
BEGIN
	SET @char = SUBSTRING(@json, @c, 1)
	IF @char = '"' AND @string = 0
	BEGIN
		SET @string = 1
		SET @word += @char
	END
	ELSE IF @string = 1
	BEGIN
		SET @word += @char
		IF @char = '"'
		BEGIN
			SET @string = 0
			INSERT INTO @jsonwords VALUES ((SELECT COUNT(*) FROM @jsonwords) + 1, @word)
			SET @word = ''
		END
	END
	ELSE IF @char IN ('{', '}', '[', ']', ':', ',')
	BEGIN
		INSERT INTO @jsonwords VALUES ((SELECT COUNT(*) FROM @jsonwords) + 1, @word), ((SELECT COUNT(*) FROM @jsonwords) + 2, @char)
		SET @word = ''
	END
	ELSE IF @char = ' '
	BEGIN
		SET @c += 1
		CONTINUE
	END
	ELSE
		SET @word += @char

	SET @c += 1
END

DECLARE @value bit = 0
DECLARE @levels table (id int, level varchar(16))
SET @json = ''
SET @c = 1

WHILE @c <= (SELECT COUNT(*) FROM @jsonwords)
BEGIN
	SET @word = (SELECT word FROM @jsonwords WHERE id = @c)

	IF LEN(@word) = 0
	BEGIN
		SET @c += 1
		CONTINUE
	END
	ELSE IF @word IN ('{', '[')
	BEGIN
		IF @value = 1
		BEGIN
			SET @value = 0
			SET @json += @word
		END
		ELSE
			SET @json += CHAR(10) + REPLICATE(CHAR(9), (SELECT COUNT(*) FROM @levels)) + @word
		IF @word = '{'
			INSERT INTO @levels VALUES ((SELECT COUNT(*) FROM @levels) + 1, 'object')
		ELSE
			INSERT INTO @levels VALUES ((SELECT COUNT(*) FROM @levels) + 1, 'array')
	END
	ELSE IF @word IN ('}', ']')
	BEGIN
		SET @value = 0
		DELETE FROM @levels WHERE id = (SELECT COUNT(*) FROM @levels)
		SET @json += CHAR(10) + REPLICATE(CHAR(9), (SELECT COUNT(*) FROM @levels)) + @word
	END
	ELSE IF @word = ':'
	BEGIN
		SET @value = 1
		SET @json += ': '
	END
	ELSE IF @value = 1 OR @word = ','
	BEGIN
		SET @value = 0
		SET @json += @word
	END
	ELSE
		SET @json += CHAR(10) + REPLICATE(CHAR(9), (SELECT COUNT(*) FROM @levels)) + @word

	SET @c += 1
END

RETURN LTRIM(@json)
END