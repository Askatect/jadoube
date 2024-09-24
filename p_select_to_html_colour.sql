CREATE OR ALTER PROCEDURE [jra].[p_select_to_html_colour] (
    @query varchar(max),
    @order_by varchar(max) = NULL,
	@out varchar(max) = '' OUTPUT,
	@sum bit = 0,
    @print bit = 0,
    @display bit = 0
)
/*
Version: 1.0
Author: JRA
Date: 2024-01-06

Description:
Takes the output table from a given DQL script and writes it to a HTML table.

Parameters:
- @query (nvarchar(max)): DQL script to get data.
- @order_by (varchar(max)): ORDER BY clause. Defaults to no ordering.
- @out (varchar(max) OUTPUT): Output HTML.
- @sum (bit): If true, aggregates numerical data by summation. Defaults to false.
- @print (bit): If true, prints debug statements. Defaults to false.
- @display (bit): If true, displays outputs. Defaults to false.

Prerequisites:
- [jra].[fn_gradient_hex]: Calculates gradients for numerical columns.

Returns:
- @out (nvarchar(max) OUTPUT): Output HTML.

Usage:
DECLARE @output nvarchar(max) = ''
EXECUTE [jra].[p_select_to_html] @query = 'SELECT * FROM [table]', @order_by = '[column1] ASC, [column2] DESC', @out = @output OUTPUT
*/
AS
IF @print = 0
    SET NOCOUNT ON

BEGIN
    DECLARE @main char(7) = '#181848',
        @black char(7) = '#000000',
        @white char(7) = '#ffffff',
        @dark_accent char(7) = '#541b8c',
        @light_accent char(7) = '#72abe3',
        @grey char(7) = '#cfcfcf',
        @negative char(7) = '#8c1b1b',
        @null char(7) = '#8c8c1b',
        @positive char(7) = '#1b8c1b'

    DROP TABLE IF EXISTS [jra].[temp];
    CREATE TABLE [jra].[temp]([R] int) -- Beat the intellisense.

    DECLARE @cmd nvarchar(max) = CONCAT('
        DROP TABLE IF EXISTS [jra].[temp];
        
        SELECT * 
        INTO [jra].[temp] 
        FROM (', @query, ') AS [T]
    ')
    IF @print = 1
	    PRINT(@cmd)
    EXEC(@cmd)

    DROP TABLE IF EXISTS #columns;

    SELECT [c].[column_id] AS [c],
        [c].[name] AS [col],
        CASE WHEN [c].[system_type_id] IN (48, 52, 56, 59, 60, 62, 106, 108, 122, 127/*, 40, 41, 42, 43, 61, 189*/) THEN [c].[system_type_id]
            ELSE 0
            END AS [numeric],
        CONVERT(float, 0.0) AS [min],
        CONVERT(float, 0.0) AS [max],
		CONVERT(float, 0.0) AS [sum]
    INTO #columns
    FROM [sys].[columns] AS [c]
    WHERE [c].[object_id] = OBJECT_ID('[jra].[temp]')
    ORDER BY [c].[column_id]

    ALTER TABLE [jra].[temp]
    ADD [ID] int IDENTITY(0, 1) NOT NULL, [R] int;

    SET @cmd = CONCAT('
        UPDATE [jra].[temp]
        SET [R] = [T].[R]
        FROM (SELECT (ROW_NUMBER() OVER(ORDER BY ', ISNULL(@order_by, (SELECT TOP(1) '[' + [col] + ']' FROM #columns)), ') - 1) AS [R], [ID] FROM [jra].[temp]) AS [T]
        WHERE [jra].[temp].[ID] = [T].[ID]
    ')
    IF @print = 1
	    PRINT(@cmd)
    EXEC(@cmd)

    ALTER TABLE [jra].[temp]
    DROP COLUMN [ID];

    DECLARE @c int,
        @col nvarchar(max),
        @numeric tinyint,
        @min float,
        @max float,
        @R int = 0,
        @value_float float,
        @value_char varchar(max),
        @background char(7),
        @fontcolour char(7),
		@text_align varchar(6)
    DECLARE row_cursor cursor DYNAMIC SCROLL FOR
        SELECT [c], [col], [numeric], [min], [max]
        FROM #columns WITH (NOLOCK)

    OPEN row_cursor

    FETCH FIRST FROM row_cursor
    INTO @c, @col, @numeric, @min, @max

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @numeric <> 0
        BEGIN
            SET @cmd = CONCAT('
                UPDATE #columns
                SET [min] = CONVERT(float, (SELECT MIN([', @col, ']) FROM [jra].[temp])),
                    [max] = CONVERT(float, (SELECT MAX([', @col, ']) FROM [jra].[temp]))
                WHERE [col] = ''', @col, '''
            ')
            IF @print = 1
			    PRINT(@cmd)
            EXEC(@cmd)
			IF @sum = 1
			BEGIN
				SET @cmd = CONCAT('
					UPDATE #columns
					SET [sum] = CONVERT(float, (SELECT SUM([', @col, ']) FROM [jra].[temp]))
					WHERE [col] = ''', @col, '''
				')
                IF @print = 1
				    PRINT(@cmd)
				EXEC(@cmd)
			END
        END

        FETCH NEXT FROM row_cursor
        INTO @c, @col, @numeric, @min, @max
    END

    DECLARE @separator varchar(100) = CONCAT('</th>', CHAR(10), CHAR(9), CHAR(9), '<th style="background-color:', @main, ';border:2px solid ', @black, ';text-align:center">')
	DECLARE @html varchar(max) = ''
    SET @html += '<table style="font-size:.9em;font-family:Verdana,Sans-Serif;border:3px solid' + @black + ';border-collapse:collapse">' + CHAR(10)
    SET @html += (SELECT 
        CONCAT(
            CHAR(9), '<tr style="color:' + @white + '">', CHAR(10), 
            CHAR(9), CHAR(9), '<th style="background-color:' + @main + ';border:2px solid ' + @black + ';text-align:center">', STRING_AGG([col], @separator), '</th>', CHAR(10), 
            CHAR(9), '</tr>', CHAR(10)
        ) 
        FROM #columns
    )

	WHILE @R <= (SELECT MAX([R]) FROM [jra].[temp])
    BEGIN
	    FETCH FIRST FROM row_cursor
        INTO @c, @col, @numeric, @min, @max

        SET @html += CONCAT(CHAR(9), '<tr>', CHAR(10))

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @cmd = CONCAT('
                SELECT @value_char = REPLACE(CONVERT(varchar(max), [', @col, '], 21), CHAR(10), ''''),
                    @value_float = ', IIF(@numeric <> 0, CONCAT('CONVERT(float, [', @col, '])'), 'NULL'), '
                FROM [jra].[temp]
                WHERE [R] = ', @R, '
            ')
            IF @print = 1
			    PRINT(@cmd)
            EXEC sp_executesql @cmd, N'@value_char varchar(max) OUTPUT, @value_float float OUTPUT', @value_char OUTPUT, @value_float OUTPUT

            IF @c = 1
                SET @html += CONCAT(CHAR(9), CHAR(9), '<td style="border:2px solid ', @black,';background-color:', @dark_accent, ';color:', @white, ';text-align:center">', @value_char, '</td>', CHAR(10))
            ELSE
            BEGIN
				IF @numeric <> 0
					SET @text_align = 'right'
				ELSE
					SET @text_align = 'center'
				
                IF @numeric <> 0 AND @min < 0
                BEGIN
                    IF @value_float < 0
                        SET @background = [jra].[fn_gradient_hex](@value_float, @min, 0, @negative, @null)
                    ELSE
                        SET @background = [jra].[fn_gradient_hex](@value_float, @max, 0, @positive, @null)
                    SET @fontcolour = @white
                END
                ELSE
                BEGIN
                    IF @numeric <> 0
                        SET @background = [jra].[fn_gradient_hex](@value_float, @min, @max, @white, @light_accent)
                    ELSE IF @R % 2 = 0
                        SET @background = @white
                    ELSE
                        SET @background = @grey
                    SET @fontcolour = @black
                END
                SET @html += CONCAT(CHAR(9), CHAR(9), '<td style="border:2px solid ', @black,';background-color:', @background, ';color:', @fontcolour, ';text-align:', @text_align, '">', @value_char, '</td>', CHAR(10))
            END

            FETCH NEXT FROM row_cursor
            INTO @c, @col, @numeric, @min, @max
        END

        SET @html += CONCAT(CHAR(9), '</tr>', CHAR(10))
        SET @R += 1
    END

	IF @sum = 1
	BEGIN
		FETCH FIRST FROM row_cursor
		INTO @c, @col, @numeric, @min, @max

		SET @html += CONCAT(CHAR(9), '<tr>', CHAR(10))

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @c = 1
				SET @html += CONCAT(CHAR(9), CHAR(9), '<td style="border:2px solid ', @black,';background-color:', @dark_accent, ';color:', @white, ';text-align:center;font-style:italic">Total</td>', CHAR(10))
			ELSE IF @numeric <> 0
			BEGIN
				SET @cmd = CONCAT('
					SELECT @value_char = CONVERT(varchar(max), CONVERT(', (SELECT [name] FROM [sys].[types] WHERE [system_type_id] = @numeric), ', [sum]), 21),
						@value_float = [sum]
					FROM #columns
					WHERE [col] = ''', @col, '''
				')
                IF @print = 1
				    PRINT(@cmd)
				EXEC sp_executesql @cmd, N'@value_char varchar(max) OUTPUT, @value_float float OUTPUT', @value_char OUTPUT, @value_float OUTPUT

				IF @min < 0
                BEGIN
                    IF @value_float < 0
                        SET @background = @negative
                    ELSE
                        SET @background = @positive
                    SET @fontcolour = @white
                END
                ELSE
                BEGIN
                    SET @background = @light_accent
                    SET @fontcolour = @black
                END
				SET @html += CONCAT(CHAR(9), CHAR(9), '<td style="border:2px solid ', @black,';background-color:', @background, ';color:', @fontcolour, ';text-align:right;font-style:italic">', @value_char, '</td>', CHAR(10))
			END
			ELSE
				SET @html += CONCAT(CHAR(9), CHAR(9), '<td style="border:2px solid ', @black,';background-color:', @black, ';color:', @black, ';text-align:center"></td>', CHAR(10))

			FETCH NEXT FROM row_cursor
			INTO @c, @col, @numeric, @min, @max
		END
		SET @html += CONCAT(CHAR(9), '</tr>', CHAR(10))
	END

    SET @html += '</table>'

    CLOSE row_cursor
    DEALLOCATE row_cursor

    DROP TABLE IF EXISTS [jra].[temp]
    DROP TABLE IF EXISTS #columns

	SET @out = @html

    IF @print = 1
        PRINT(@out)
    IF @display = 1
        SELECT @out AS [html]

	RETURN;
END