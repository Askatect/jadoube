CREATE OR ALTER FUNCTION [jadoube].[fn_string_split_item] (
    @string nvarchar(max),
    @separator char(1) = ',',
    @item int = 0
)
RETURNS nvarchar(4000)
/*
[jadoube].[fn_string_split_item]

Version: 2.0
Authors: JRA
Date: 2024-08-13

Explanation:
Retrieves the item at the given index from a delimited string.

Parameters:
- @string (nvarchar(max)): The delimited string of data to turn into an array.
- @separator (char(1)): The delimiter. Defaults to ','.
- @item (int): The position of the desired item (zero-indexed). Defaults to the first item.

Returns:
- (nvarchar(4000))

Usage:
>>> PRINT([jadoube].[fn_string_split_item]('Link,Zelda,Ganondorf', DEFAULT, 1))
'Zelda'

History:
- 2.0 JRA (2024-08-13): Rewritten to remove dependency on [jadoube].[fn_string_split]. @separator is now char(1).
- 1.0 JRA (2024-07-02): Initial version.
*/
AS
BEGIN
DECLARE @counter int = 0

IF @string IS NULL
    RETURN ''

IF LEN(@string) - LEN(REPLACE(@string, @separator, '')) < @item
    RETURN ''

WHILE @counter < @item
BEGIN
    SET @string = SUBSTRING(@string, CHARINDEX(@separator, @string) + 1, LEN(@string))
    SET @counter += 1
END

RETURN SUBSTRING(@string, 1, CHARINDEX(@separator, @string + ',') - 1)
END
