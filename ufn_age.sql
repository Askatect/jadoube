CREATE OR ALTER FUNCTION [jra].[ufn_age](
	@Start date, 
	@End date = NULL
)
RETURNS int
/*
Version: 1.0
Author: JRA
Date: 2024-01-06

Description:
Calculates the floor of the difference in years between two dates.

Parameters:
- @Start (date): Start date.
- @End (date): End date. Defaults to current date.

Returns:
- (int)

Usage:
[jra].[ufn_age]('1999-10-03 05:45', '2024-01-06')
>>> 24
*/
BEGIN
	RETURN (CAST(FORMAT(ISNULL(@End, GETDATE()), 'yyyyMMdd') AS int) - CAST(FORMAT(@Start, 'yyyyMMdd') AS int))/10000
END