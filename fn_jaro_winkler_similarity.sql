CREATE OR ALTER FUNCTION [jadoube].[fn_jaro_winkler_similarity](
	@string1 nvarchar(4000), 
	@string2 nvarchar(4000), 
	@scaling_factor numeric(5, 5) = 0.1,
	@max_matching_prefix int = 4
)
RETURNS numeric(9, 8)
/*
[jadoube].[fn_jaro_winkler_similarity]

Version: 1.0
Authors: JRA
Date: 2024-10-21

Explanation:
Computes the Jaro-Winkler similarity between two strings. This is a value in the interval [0, 1], where 1 is an exact match. Note that the product of the scaling factor and the maximum matching prefix length should be no more than 1.

Requirements:
- [jadoube].[fn_jaro_similarity]

Parameters:
- @string1 (nvarchar(4000)): One of the strings to compare.
- @string2 (nvarchar(4000)): The other string to compare to.
- @scaling_factor (numeric(5, 5)): The scaling factor informs the extra weight to assign to the length of characters that match at the start of each string. Defaults to 0.1.
- @max_matching_prefix (int): The highest number of matching characters at the start of each string. Defaults to 4.

Returns:
- (numeric(9, 8))

Usage:
>>> [jadoube].[fn_jaro_winkler_similarity]('virtuoso', 'viscous')
0.77047619
>>> [jadoube].[fn_jaro_winkler_similarity]('virtuoso', 'virtuous')
0.95000000

History:
- 1.0 JRA (2024-10-21): Initial version.
*/
BEGIN
DECLARE @matching_prefix int = 0,
	@jaro numeric(9, 8)

WHILE SUBSTRING(@string1, @matching_prefix + 1, 1) = SUBSTRING(@string2, @matching_prefix + 1, 1) COLLATE Latin1_General_CS_AI AND @matching_prefix < @max_matching_prefix
	SET @matching_prefix += 1

SET @jaro = [jadoube].[fn_jaro_similarity](@string1, @string2)

RETURN @jaro + @scaling_factor*@matching_prefix*(1 - @jaro)
END