CREATE OR ALTER FUNCTION [jadoube].[fn_fingerprint](@string nvarchar(4000))
RETURNS nvarchar(4000)
/*
[jadoube].[fn_fingerprint]

Version: 1.0
Authors: JRA
Date: 2024-10-22

Explanation:
Returns a "fingerprint" of a string. The string is converted to lower case and all non-alphanumeric characters are removed.

Requirements:
- [jadoube].[fn_replace]

Parameters:
- @string (nvarchar(4000)): The string to calculate the fingerprint of.

Returns:
- (nvarchar(4000)): The fingerprint.

Usage:
>>> [jadoube].[fn_fingerprint]('F1inger-PR!INT')
'fingerprint'

History:
- 1.0 JRA (2024-10-22): Intial version.
*/
BEGIN
RETURN [jadoube].[fn_replace]('[^a-z0-9]', '', 0, LOWER(@string))
END