CREATE OR ALTER FUNCTION [jadoube].[fn_matching_levenshtein_low_normalised](
    @string1 nvarchar(max),
    @string2 nvarchar(max),
    @threshold numeric(6, 5)
)
RETURNS bit
/*
[jadoube].[fn_matching_levenshtein_low_normalised]

Version: 1.0
Authors: JRA
Date: 2024-10-18

Explanation:
The normalised Levenshtein distance is a real value in the interval [0, 1], where a value of 0 indicates an exact match. True is returned if the normalised levenshtein distance is below the given threshold. The recursive calculation method is used, so this is optimised for lower thresholds.

Requirements:
- [jadoube].[fn_matching_levenshtein_low]

Parameters:
- @string1 (nvarchar(max)): One of the strings to compare.
- @string2 (nvarchar(max)): The other string to compare.
- @threshold (numeric(6, 5)): The threshold.

Returns:
- (bit)

Usage:
>>> [jadoube].[fn_matching_levenshtein_low_normalised]('sat', 'sun', 0.9)
0
>>> [jadoube].[fn_matching_levenshtein_low_normalised]('sat', 'sun', 1.0)
1
>>> [jadoube].[fn_matching_levenshtein_low_normalised]('saturday', 'sunday', 0.3)
0
>>> [jadoube].[fn_matching_levenshtein_low_normalised]('saturday', 'sunday', 0.4)
1

History:
- 1.0 JRA (2024-10-18): Initial version.
*/
BEGIN
RETURN [jadoube].[fn_matching_levenshtein_low](@string1, @string2, @threshold*IIF(LEN(@string1) < LEN(@string2), LEN(@string2), LEN(@string1)))
END