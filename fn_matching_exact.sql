CREATE OR ALTER FUNCTION [jadoube].[fn_matching_exact](@string1 nvarchar(max), @string2 nvarchar(max), @threshold bit = 1)
RETURNS bit
/*
[jadoube].[fn_matching_exact]

Version: 1.1
Authors: JRA
Date: 2024-10-15

Explanation:
Returns 1 if the two input strings are an exact case-sensitive match.

Parameters:
- @string1 (nvarchar(max)): One of the strings to compare.
- @string2 (nvarchar(max)): The other string to compare.
- @threshold (bit): If true, the boolean comparison of the strings is returned, otherwise false is returned. Defaults to true.

Returns:
- (bit)

Usage:
>>> [jadoube].[fn_matching_exact]('Lan Zhan', 'Lan Zhan', 1)
1
>>> [jadoube].[fn_matching_exact]('Lan Zhan', 'Lan Zhan', 0)
0
>>> [jadoube].[fn_matching_exact]('Lan Zhan', 'Lan Xichen', 1)
0
>>> [jadoube].[fn_matching_exact]('Lan Zhan', 'Lan Xichen', 0)
0

History:
- 1.1 JRA (2024-10-15): Added @threshold.
- 1.0 JRA (2024-10-14): Initial version. Runs ~30μs per execution.
*/
BEGIN
IF @threshold = 1 AND @string1 = @string2 COLLATE Latin1_General_CS_AI
    RETURN 1
RETURN 0
END