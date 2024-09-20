CREATE OR ALTER PROCEDURE [jra].[ufn_select_to_html] (
    @schema varchar(128) = NULL,
    @table varchar(128),
    @print bit = 1
)
/*
[jra].[ufn_select_to_html]

Version: 1.0
Authors: JRA
Date: 2024-06-04

Explanation:
Converts a SQL table to basic html and displays the html

Parameters:
- @schema (varchar(128)): The schema of the table to convert. Defaults to the default schema (usually [dbo]).
- @table (varchar(128)): The name of the table to convert.
- @print (bit): If true, debug statements are printed. Defaults to true.

Returns: 
- [html] nvarchar(max): The html conversion of the table as a single cell.

Usage:
>>> SELECT 'value' AS [column] INTO #table
>>> EXECUTE [jra].[ufn_select_to_html] @table = '#table', @print = 0
"""
+=========================================================================================================+
|                                                 html                                                    |
+=========================================================================================================+
| <table style="font-size:.9em;font-family:Verdana,Sans-Serif;border:3px solid;border-collapse:collapse"> |
|     <tr>                                                                                                |
|         <th style="border:2px solid;text-align:center">column</th>                                      |
|     </tr>                                                                                               |
|     <tr>                                                                                                |
|         <td style="border:2px solid;text-align:left">value</td>                                         |
|     </tr>                                                                                               |
| </table>                                                                                                |
+---------------------------------------------------------------------------------------------------------+
"""

History:
- 1.0 JRA (2024-06-04): Initial version.
*/
AS
DECLARE @html nvarchar(max) = '',
    @cmd nvarchar(max),
    @temp bit = IIF(@table LIKE '#%', 1, 0)
DECLARE @object varchar(256) = CONCAT(IIF(@temp = 1, '[tempdb].', QUOTENAME(@schema, '[')) + '.', QUOTENAME(@table, '['))

PRINT(@object)

-- Get source metadata.
DECLARE @columns table (
    [c] int,
    [column] varchar(128),
    [numeric] bit
)
IF @temp = 1
BEGIN
    INSERT INTO @columns ([c], [column], [numeric])
    SELECT [column_id],
        [name],
        IIF([system_type_id] IN (48, 52, 56, 59, 60, 62, 106, 108, 122, 127/*, 40, 41, 42, 43, 61, 189*/), 1, 0)
    FROM tempdb.sys.columns
    WHERE [object_id] = OBJECT_ID(@object)
END
ELSE
BEGIN
    INSERT INTO @columns ([c], [column], [numeric])
    SELECT [column_id],
        [name],
        IIF([system_type_id] IN (48, 52, 56, 59, 60, 62, 106, 108, 122, 127/*, 40, 41, 42, 43, 61, 189*/), 1, 0)
    FROM sys.columns
    WHERE [object_id] = OBJECT_ID(@object)
END

-- Begin table.
SET @html += '<table style="font-size:.9em;font-family:Verdana,Sans-Serif;border:3px solid;border-collapse:collapse">' + CHAR(10)

-- Get columns.
SET @cmd = (
    SELECT REPLICATE(CHAR(9), 2) + '<th style="border:2px solid;text-align:center">' + [column] + '</th>' + CHAR(10)
    FROM @columns
    ORDER BY [c]
    FOR XML PATH (''), TYPE
).value('.', 'nvarchar(max)')

-- Header row.
SET @html += '<tr>' + CHAR(10) + @cmd + CHAR(9) + '</tr>' + CHAR(10)

-- Dynamic select clause for fields with html.
SET @cmd = STUFF((
    SELECT CONCAT(',', CHAR(10), CHAR(9), IIF([c] = 1, 'CHAR(9) + ''<tr>'' + CHAR(10) + ', ''), 'REPLICATE(CHAR(9), 2) + ''<td style="border:2px solid;text-align:', IIF([numeric] = 1, 'right', 'left'),'">'' + CONVERT(nvarchar(4000), ISNULL(', QUOTENAME([column], '['), ', '''')) + ''</td>'' + CHAR(10)', IIF([c] = (SELECT MAX([c]) FROM @columns), '+ CHAR(9) + ''</tr>'' + CHAR(10)', ''), ' AS ', QUOTENAME([column]))
    FROM @columns
    ORDER BY [c]
    FOR XML PATH(''), TYPE
).value('.', 'nvarchar(max)'), 1, 3, '')

-- Dynamic DQL to get fields with html.
SET @cmd = CONCAT('SET @cmd = (
    SELECT ', @cmd, '
    FROM ', IIF(@temp = 1, QUOTENAME(@table, '['), @object), '
    FOR XML PATH(''''), TYPE
).value(''.'', ''nvarchar(max)'')'
)
PRINT(@cmd)

-- Add fields with html.
EXEC sp_executesql @cmd, N'@cmd nvarchar(max) OUTPUT', @cmd OUTPUT
SET @html += @cmd

-- Close table.
SET @html += '</table>'

PRINT(@html)

SELECT @html AS [html]

GO

DROP TABLE IF EXISTS [#table]
SELECT 'value' AS [column] INTO [#table]
EXECUTE [utl].[ufn_select_to_html] @table = '#table'