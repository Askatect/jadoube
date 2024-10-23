CREATE OR ALTER FUNCTION [jadoube].[fn_matching_jaro_winkler](
	@string1 nvarchar(4000),
	@string2 nvarchar(4000),
	@threshold numeric(9, 8)
)
RETURNS bit
/*
[jadoube].[fn_matching_jaro_winkler]

Version: 1.0 
Authors: JRA
Date: 2024-10-21

Explanation:
Returns true if the given strings are more similar than the given threshold according to the Jaro-Winkler similarity measure.

Requirements:
- [jadoube].[fn_jaro_winkler_similarity]

Parameters:
- @string1 (nvarchar(4000)): One of the strings to compare.
- @string2 (nvarchar(4000)): The other string to compare to.
- @threshold (numeric(9, 8)): The threshold to compare to, should be in the range [0, 1].

Returns:
- (bit)

Usage:
>>> [jadoube].[fn_matching_jaro_winkler]('virtuoso', 'viscous', 0.9)
0
>>> [jadoube].[fn_matching_jaro_winkler]('virtuoso', 'virtuous', 0.9)
1

History:
- 1.0 JRA (2024-10-21): Initial version.
*/
BEGIN
IF [jadoube].[fn_jaro_winkler_similarity](@string1, @string2, DEFAULT, DEFAULT) >= @threshold
	RETURN 1
RETURN 0
END