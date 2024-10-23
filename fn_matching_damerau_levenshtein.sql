CREATE OR ALTER FUNCTION [jadoube].[fn_matching_damerau_levenshtein](
	@string1 nvarchar(4000),
	@string2 nvarchar(4000),
	@threshold int
)
RETURNS bit
/*
[jadoube].[fn_matching_damerau_levenshtein]

Version: 1.0
Authors: JRA
Date: 2024-10-22

Explanation:
Calculates whether two strings are within a threshold of similarity according to the unrestricted Damerau-Levenshtein distance.

Requirements:
- [jadoube].[fn_damerau_levenshtein_distance]

Parameters:
- @string1 (nvarchar(max)): One of the strings to compare.
- @string2 (nvarchar(max)): The other string to compare.
- @threshold (int): The threshold to measure against.

Returns:
- (bit)

Usage:
>>> [jadoube].[fn_matching_damerau_levenshtein]('kitty', 'litter', 2)
0
>>> [jadoube].[fn_matching_damerau_levenshtein]('kitty', 'litter', 3)
1

History:
- 1.0 JRA (2024-10-22): Initial version.
*/
BEGIN
IF [jadoube].[fn_damerau_levenshtein_distance](@string1, @string2) <= @threshold
	RETURN 1
RETURN 0
END