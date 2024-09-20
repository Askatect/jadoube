CREATE OR ALTER FUNCTION [jra].[ufn_gradient_hex] (
	@target float, 
	@lower float, 
	@upper float,
	@hexmin char(7), 
	@hexmax char(7)
)
RETURNS char(7)
/*
Version: 1.0
Author: JRA
Date: 2024-01-06

Description:
Uses linear interpolation to find the hexcode of a value on the gradient between two colours.

Parameters:
- @target (float): The target value.
- @lower (float): The lower bound of the target class.
- @upper (float): The upper bound of the target class.
- @hexmin (char(7)) The hexcode of the lowest colour on the gradient.
- @hexmax (char(7)) The hexcode of the highest colour on the gradient.

Prerequisites:
- [jra].[ufn_hexcode_to_rgb]: Converts input to RGB values for calculations.

Returns:
- @hexcode (char(7)): The target colour.

Usage:
[jra].[gradient_hex](1, 0, 2, '#000000', '#FFFFFF')
>>> '#888888'
*/
AS
BEGIN
	IF @lower = @upper
		RETURN @hexmin

	DECLARE @hexcode char(7) = (
		SELECT '#' + STRING_AGG(CONVERT(char(2), CONVERT(binary(1), [result], 1), 2), '')
		FROM (
			SELECT [rgb],
				[lower],
				[upper],
				CONVERT(int, [lower] + ([upper] - [lower])*(@target - @lower)/(@upper - @lower)) AS [result]
			FROM (
				SELECT [lower].[rgb],
					[lower].[value] AS [lower],
					[upper].[value] AS [upper]
				FROM [jra].[hexcode_to_rgb](@hexmin) AS [lower]
					INNER JOIN [jra].[hexcode_to_rgb](@hexmax) AS [upper]
						ON [lower].[rgb] = [upper].[rgb]
			) AS [T]
		) AS [T]
	)
	RETURN @hexcode
END