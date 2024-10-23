CREATE OR ALTER FUNCTION [jadoube].[fn_matching_levenshtein](
	@string1 nvarchar(max), 
	@string2 nvarchar(max),
	@threshold int
)
RETURNS bit
/*
[jadoube].[fn_matching_levenshtein]

Version: 1.1
Authors: JRA
Date: 2024-10-18

Explanation:
Returns true if the Levenshtein distance (a non-negative integer), is below the given threshold (inclusive). For possible improved performance, consider using [jadoube].[fn_matching_levenshtein_low] when using a low threshold.

Requirements:
- [jadoube].[fn_levenshtein_distance]

Parameters:
- @string1 (nvarchar(max)): One of the strings to compare.
- @string2 (nvarchar(max)): The other string to compare.
- @threshold (int): The threshold.

Returns:
- (bit)

Usage:
>>> [jadoube].[fn_matching_levenshtein]('Athena', 'Athena', 0)
1
>>> [jadoube].[fn_matching_levenshtein]('Heracles', 'Hercules', 1)
0
>>> [jadoube].[fn_matching_levenshtein]('Heracles', 'Hercules', 2)
1

History:
- 1.1 JRA (2024-10-18): Added case handling for non-positive thresholds.
- 1.0 JRA (2024-10-15): Initial version.
*/
BEGIN
IF @threshold = 0
	RETURN IIF(@string1 = @string2 COLLATE Latin1_General_CS_AI, 1, 0)
ELSE IF @threshold < 0
	RETURN 0
ELSE IF [jadoube].[fn_levenshtein_distance](@string1, @string2) <= @threshold
	RETURN 1
RETURN 0
END