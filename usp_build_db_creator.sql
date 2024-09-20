CREATE OR ALTER PROCEDURE [jra].[usp_build_db_creator] (
-- DECLARE
	@replace bit = 0,
	@data bit = 0,
	@schemata varchar(max) = NULL,
	@tables bit = 1,
	@default_constraints bit = 1,
	@check_constraints bit = 1,
	@primary_keys bit = 1,
	@unique_constraints bit = 1,
	@foreign_keys bit = 1,
	@triggers bit = 1,
	@stored_procedures bit = 1,
	@scalar_functions bit = 1,
	@inline_table_functions bit = 1,
	@table_valued_functions bit = 1,
	@views bit = 1,
	@indexes bit = 1,
	@print bit = 1,
	@display bit = 1,
	@commit bit = 0
)
/*
Version: 1.4
Author: JRA
Date: 2024-01-15

Explanation:
Reads schemata of the current database and writes the DDL commands to recreate objects into a stored procedure.

Requirements:
- [jra].[ufn_string_split]: Splits a delimited string into an array.
- [jra].[usp_print]: Prints large strings.

Parameters:
- @replace (bit): If true, the resulting procedure will overwrite existing objects when called. Defaults to false.
- @data (bit): If true, the resulting procedure will feature data from the source (only from tables with no more than 1000 rows). Defaults to false.
- @schemata varchar(max): Comma-delimited list of schemata to read. Defaults to all schemata.
- @tables (bit): If true, the resulting procedure will feature DDL statements for tables. Defaults to true.
- @default_constraints (bit): If true, the resulting procedure will feature DDL statements for default constraints. Defaults to true.
- @check_constraints (bit): If true, the resulting procedure will feature DDL statements for check constraints. Defaults to true.
- @primary_keys (bit): If true, the resulting procedure will feature DDL statements for primary keys. Defaults to true.
- @unique_constraints (bit): If true, the resulting procedure will feature DDL statements for unique constraints. Defaults to true.
- @foreign_keys (bit): If true, the resulting procedure will feature DDL statements for foreign keys. Defaults to true.
- @triggers (bit): If true, the resulting procedure will feature DDL statements for triggers. Defaults to true.
- @stored_procedures (bit): If true, the resulting procedure will feature DDL statements for stored procedures. Defaults to true.
- @scalar_functions (bit): If true, the resulting procedure will feature DDL statements for scalar functions. Defaults to true.
- @inline_table_functions (bit): If true, the resulting procedure will feature DDL statements for inline table functions. Defaults to true.
- @table_valued_functions (bit): If true, the resulting procedure will feature DDL statements for table-valued functions. Defaults to true.
- @views (bit): If true, the resulting procedure will feature DDL statements for views. Defaults to true.
- @indexes (bit): If true, the resulting procedure will feature DDL statements for indexes. Defaults to true.
- @print (bit): If true, debug statements will be printed. Defaults to true.
- @display (bit): If true, outputs will be displayed. Defaults to true.
- @commit (bit): If true, procedure will be created.

Returns:
Writes a stored procedure with the requested DDL statements for the requested schemata.

Usage:
USE [database]
EXECUTE [jra].[usp_build_db_creator] @replace = 1, @schemata = 'jra,dbo'
>>> [jra].[usp_drop_and_create_[database]]_[dbo]]_[jra]]]

History:
- 1.4 (2024-01-15): Adjusted docstring generation. Removed @action loop.
- 1.3 (2024-01-10): Datetime columns are formatted as 'yyyy-MM-dd HH:mm:ss.fff' in data extraction. Squashed a bug where programmability objects wouldn't be dropped if schemata is unspecified. Improved grammar of comment headers. Triggers get dropped when @replace is true.
- 1.2 (2024-01-06): Added automatic documentation, @commit and loop over objects to drop. Objects in [jra] schema are not dropped if not specified in @schemata, and schema collection was improved.
- 1.1 (2024-01-06): Prioritised views during programmability creation.
*/
AS

SET NOCOUNT ON

DECLARE @cmd nvarchar(max), 
	@sql nvarchar(max), 
	@R int, 
	@O int,
	@type varchar(4),
	@description varchar(128), 
	@schema varchar(128),
	@table varchar(128),
	@name varchar(128), 
	@modified datetime2,
	@definition nvarchar(max)

DECLARE @types table (
	[type] varchar(4),
	[description] varchar(64),
	[order] tinyint,
	[include] bit
)
INSERT INTO @types
VALUES ('SC', 'Schema', 1, 1),
	('U', 'Table', 2, @tables),
	('DT', 'Data', 3, @data),
	('D', 'Default Constraint', 4, @default_constraints),
	('C', 'Check Constraint', 5, @check_constraints),
	('PK', 'Primary Key', 6, @primary_keys),
	('UQ', 'Unique Constraint', 7, @unique_constraints),
	('F', 'Foreign Key', 8, @foreign_keys),
	('TR', 'Trigger', 9, @triggers),
	('P', 'Stored Procedure', 10, @stored_procedures),
	('FN', 'Scalar Function', 11, @scalar_functions),
	('IF', 'Inline Table Function', 12, @inline_table_functions),
	('TF', 'Table-Valued Function', 13, @table_valued_functions),
	('V', 'View', 14, @views),
	('I', 'Index', 15, @indexes)

DELETE FROM @types
WHERE [include] = 0

DECLARE @definitions table (
	[type] varchar(4),
	[schema] varchar(128),
	[table] varchar(128),
	[name] varchar(128),
	[object_id] int,
	[definition] nvarchar(max)
)

--============================================================--
/* Schemata */

IF @schemata IS NULL
	SET @schemata = (
		SELECT STRING_AGG([name], ',') 
		FROM sys.schemas 
		WHERE [name] NOT IN ('public', 'guest', 'INFORMATION_SCHEMA', 'sys', 'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin', 'db_backupoperator', 'db_datareader', 'db_datawriter', 'db_denydatareader', 'db_denydatawriter')
	)

INSERT INTO @definitions
SELECT 'SC' AS [type],
	[s].[name] AS [schema],
	NULL AS [table],
	NULL AS [name],
	[s].[schema_id] AS [schema_id],
	CONCAT('IF SCHEMA_ID(''', [s].[name], ''') IS NULL', CHAR(10), CHAR(9), 'EXEC(''CREATE SCHEMA [', [s].[name], ']'')') AS [definition]
FROM sys.schemas AS [s]
WHERE [s].[name] IN (SELECT DISTINCT [value] FROM [jra].[ufn_string_split](@schemata + ',jra', ','))

--============================================================--
/* Tables */

IF @tables = 1
BEGIN
	INSERT INTO @definitions
	SELECT [t].[type], 
		SCHEMA_NAME([t].[schema_id]) AS [schema],
		[t].[name] AS [table],
		NULL AS [name],
		[t].[object_id],
		CONCAT('IF (OBJECT_ID(''[', SCHEMA_NAME([t].[schema_id]), '].[', [t].[name], ']'', ''U'') IS NULL)', 
		CHAR(10), 'BEGIN', 
		CHAR(10), 'CREATE TABLE [', SCHEMA_NAME([t].[schema_id]), '].[', [t].[name], '] (',
		STUFF((
			SELECT CONCAT(',', CHAR(10), CHAR(9), 
				'[', [c].[name] + '] ', 
				[d].[name], 
				CASE WHEN [d].[system_type_id] IN (106, 108) THEN CONCAT('(', [d].[precision], ', ', [d].[scale], ')')
					WHEN [d].[system_type_id] IN (165, 167, 173, 175) THEN CONCAT('(', IIF([c].[max_length] = -1, 'max', CONVERT(varchar, [c].[max_length])), ')') 
					WHEN [d].[system_type_id] IN (231, 239) THEN CONCAT('(', IIF([c].[max_length] = -1, 'max', CONVERT(varchar, [c].[max_length]/2)), ')') 
					ELSE '' END,
				IIF([c].[is_nullable] = 1, ' NULL', ' NOT NULL'),
				IIF([ic].[is_identity] = 1, CONCAT(' IDENTITY(', CONVERT(int, [ic].[last_value]) + 1, ', ', CONVERT(int, [ic].[increment_value]), ')'), '')
			)
			FROM sys.columns AS [c]
				INNER JOIN sys.types AS [d]
					ON [d].[system_type_id] = [c].[system_type_id]
					AND [d].[user_type_id] = [c].[user_type_id]
				LEFT JOIN sys.identity_columns AS [ic]
					ON [ic].[object_id] = [c].[object_id]
					AND [ic].[column_id] = [c].[column_id]
			WHERE [c].[object_id] = [t].[object_id]
			FOR XML PATH(''), TYPE
		).value('./text()[1]', 'nvarchar(max)'), 1, 1, ''),
		CHAR(10), ')',
		CHAR(10), 'END') AS [definition]
	FROM sys.tables AS [t]
	WHERE [t].[is_ms_shipped] = 0
		AND [t].[schema_id] IN (SELECT [object_id] FROM @definitions WHERE [type] = 'SC')
END

--============================================================--
/* Data */

IF @data = 1
BEGIN
	DECLARE data_cursor cursor FAST_FORWARD FOR
	SELECT [defs].[schema],
		[defs].[table],
		STUFF((
			SELECT CONCAT(' + '', '',', CHAR(10), 'IIF([', [c].[name], '] IS NULL, ''NULL'', CONCAT('''''''', REPLACE(', IIF([c].[system_type_id] IN (40, 42, 43, 58, 61), CONCAT('FORMAT(', QUOTENAME([c].[name], '['), ', ''yyyy-MM-dd HH:mm:ss.fff'')'), QUOTENAME([c].[name], '[')), ', '''''''', ''''''''''''), ''''''''))')
			FROM sys.columns AS [c]
			WHERE [c].[object_id] = OBJECT_ID(CONCAT('[', [defs].[schema], '].[', [defs].[table], ']'), 'U')
			FOR XML PATH('')
		), 1, 9, '') AS [definition]
	FROM @definitions AS [defs]
		
	WHERE [defs].[type] = 'U'

	OPEN data_cursor

	FETCH NEXT FROM data_cursor
	INTO @schema, @table, @definition

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @cmd = CONCAT('SELECT @R = COUNT(*) FROM [', @schema, '].[', @table, ']')
		EXECUTE sp_executesql @cmd, N'@R int OUTPUT', @R OUTPUT
		IF @R = 0
		BEGIN
			INSERT INTO @definitions
			VALUES ('DT', @schema, @table, @table + '_data', OBJECT_ID(CONCAT(QUOTENAME(@schema, '['), '.', QUOTENAME(@table, '['))), '/* Source table is empty. */')
		END
		ELSE IF @R > 1000
		BEGIN
			INSERT INTO @definitions
			VALUES ('DT', @schema, @table, @table + '_data', OBJECT_ID(CONCAT(QUOTENAME(@schema, '['), '.', QUOTENAME(@table, '['))), '/* Source table has more than 1000 rows. */')
		END
		ELSE
		BEGIN
			SET @cmd = CONCAT('
				SELECT @definition = STUFF((
					SELECT CONCAT('','', CHAR(10), CHAR(9), ''('', ', CHAR(10), @definition, ',', CHAR(10), ''')'')
					FROM [', @schema, '].[', @table, ']
					FOR XML PATH(''''), TYPE
				).value(''./text()[1]'', ''nvarchar(max)''), 1, 3, '''')
			')
			EXECUTE sp_executesql @cmd, N'@definition nvarchar(max) OUTPUT', @definition OUTPUT
			SET @definition = CONCAT('INSERT INTO [', @schema, '].[', @table, '](', STUFF((SELECT ', ' + QUOTENAME([c].[name], '[') FROM sys.columns AS [c] WHERE [c].[object_id] = OBJECT_ID(CONCAT(QUOTENAME(@schema, '['), '.', QUOTENAME(@table, '['))) FOR XML PATH('')), 1, 2, ''), ')', CHAR(10), 'VALUES ', @definition)
			IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE [object_id] = OBJECT_ID(CONCAT(QUOTENAME(@schema, '['), '.', QUOTENAME(@table, '['))))
				SET @definition = CONCAT('SET IDENTITY_INSERT ', CONCAT(QUOTENAME(@schema, '['), '.', QUOTENAME(@table, '[')), ' ON', CHAR(10), @definition, CHAR(10), 'SET IDENTITY_INSERT ', CONCAT(QUOTENAME(@schema, '['), '.', QUOTENAME(@table, '[')), ' OFF')
			INSERT INTO @definitions
			VALUES ('DT', @schema, @table, @table + '_data', OBJECT_ID(CONCAT(QUOTENAME(@schema, '['), '.', QUOTENAME(@table, '['))), @definition)
		END		

		FETCH NEXT FROM data_cursor
		INTO @schema, @table, @definition
	END

	CLOSE data_cursor
	DEALLOCATE data_cursor
END

--============================================================--
/* Default Constraints */

IF @default_constraints = 1
BEGIN
	INSERT INTO @definitions
	SELECT [dc].[type],
		SCHEMA_NAME([dc].[schema_id]) AS [schema],
		OBJECT_NAME([dc].[parent_object_id]) AS [table],
		[dc].[name],
		[dc].[object_id],
		CONCAT('IF (OBJECT_ID(''[', SCHEMA_NAME([dc].[schema_id]), '].[', [dc].[name], ']'', ''D'') IS NULL)', 
			CHAR(10), 'BEGIN', 
			CHAR(10), 'ALTER TABLE [', SCHEMA_NAME([dc].[schema_id]), '].[', OBJECT_NAME([dc].[parent_object_id]), ']', 
			CHAR(10), CHAR(9), 'ADD CONSTRAINT ', [dc].[name],
			CHAR(10), CHAR(9), 'DEFAULT ', [dc].[definition], ' FOR [', [c].[name], ']',
			CHAR(10), 'END') AS [definition]
	FROM sys.default_constraints AS [dc]
		INNER JOIN sys.columns AS [c]
			ON [c].[object_id] = [dc].[parent_object_id]
			AND [c].[column_id] = [dc].[parent_column_id]
	WHERE [dc].[is_ms_shipped] = 0
		AND [dc].[schema_id] IN (SELECT [object_id] FROM @definitions WHERE [type] = 'SC')
END

--============================================================--
/* Check Constaints */

IF @check_constraints = 1
BEGIN
	INSERT INTO @definitions
	SELECT [cc].[type],
		SCHEMA_NAME([cc].[schema_id]) AS [schema],
		OBJECT_NAME([cc].[parent_object_id]) AS [table],
		[cc].[name],
		[cc].[object_id],
		CONCAT('IF (OBJECT_ID(''[', SCHEMA_NAME([cc].[schema_id]), '].[', [cc].[name], ']'', ''C'') IS NULL)', 
			CHAR(10), 'BEGIN', 
			CHAR(10), 'ALTER TABLE [', SCHEMA_NAME([cc].[schema_id]), '].[', OBJECT_NAME([cc].[parent_object_id]), ']', 
			CHAR(10), CHAR(9), 'ADD CONSTRAINT ', [cc].[name],
			CHAR(10), CHAR(9), 'CHECK ', [cc].[definition],
			CHAR(10), 'END') AS [definition]
	FROM sys.check_constraints AS [cc]
		INNER JOIN sys.columns AS [c]
			ON [c].[object_id] = [cc].[parent_object_id]
			AND [c].[column_id] = [cc].[parent_column_id]
	WHERE [cc].[is_ms_shipped] = 0
		AND [cc].[schema_id] IN (SELECT [object_id] FROM @definitions WHERE [type] = 'SC')
END

--============================================================--
/* Primary Keys and Unique Constraints */

IF @primary_keys = 1 OR @unique_constraints = 1
BEGIN
	INSERT INTO @definitions
	SELECT IIF([i].[is_primary_key] = 1, 'PK', 'UQ') AS [type],
		SCHEMA_NAME([schema_id]) AS [schema],
		[t].[name] AS [table],
		[i].[name],
		[i].[object_id],
		CONCAT('IF (OBJECT_ID(''[', SCHEMA_NAME([t].[schema_id]), '].[', [i].[name], ']'', ''', IIF([i].[is_primary_key] = 1, 'PK', 'UQ'), ''') IS NULL)', 
			CHAR(10), 'BEGIN', 
			CHAR(10), 'ALTER TABLE [', SCHEMA_NAME([t].[schema_id]), '].[', [t].[name], ']',
			CHAR(10), CHAR(9), 'ADD CONSTRAINT ', [i].[name],
			CHAR(10), CHAR(9), IIF([i].[is_primary_key] = 1, 'PRIMARY KEY ', 'UNIQUE '), [i].[type_desc] COLLATE database_default, '(', 
			STUFF((
				SELECT CONCAT(', [', [c].[name], ']')
				FROM sys.index_columns AS [ic]
					INNER JOIN sys.columns AS [c]
						ON [c].[object_id] = [ic].[object_id]
						AND [c].[column_id] = [ic].[column_id]
				WHERE [ic].[object_id] = [i].[object_id]
					AND [ic].[index_id] = [i].[index_id]
				FOR XML PATH(''), TYPE
			).value('./text()[1]', 'nvarchar(max)'), 1, 2, ''), 
			')',
			CHAR(10), 'END') AS [definition]
	FROM sys.indexes AS [i]
		INNER JOIN sys.tables AS [t]
			ON [t].[object_id] = [i].[object_id]
	WHERE ([i].[is_primary_key] = 1
			OR [i].[is_unique_constraint] = 1)
		AND [t].[schema_id] IN (SELECT [object_id] FROM @definitions WHERE [type] = 'SC')
END

--============================================================--
/* Foreign Keys */

INSERT INTO @definitions
SELECT [fk].[type],
	SCHEMA_NAME([t].[schema_id]) AS [schema],
	[t].[name] AS [table],
	[fk].[name],
	[fk].[object_id],
	CONCAT('IF (OBJECT_ID(''[', SCHEMA_NAME([t].[schema_id]), '].[', [fk].[name], ']'', ''F'') IS NULL)', 
		CHAR(10), 'BEGIN', 
		CHAR(10), 'ALTER TABLE [', SCHEMA_NAME([t].[schema_id]), '].[', [t].[name], ']',
		CHAR(10), CHAR(9), 'ADD CONSTRAINT ', [fk].[name], ' FOREIGN KEY ([', [c].[name], '])',
		CHAR(10), CHAR(9), 'REFERENCES [', SCHEMA_NAME([s].[schema_id]), '].[', [s].[name], '] ([', [b].[name], '])',
		CHAR(10), CHAR(9), 'ON DELETE ', REPLACE([fk].[delete_referential_action_desc], '_', ' ') COLLATE database_default,
		CHAR(10), CHAR(9), 'ON UPDATE ', REPLACE([fk].[update_referential_action_desc], '_', ' ') COLLATE database_default,
		CHAR(10), 'END') AS [definition]
FROM sys.foreign_keys AS [fk]
	INNER JOIN sys.tables AS [t]
		ON [t].[object_id] = [fk].[parent_object_id]
	INNER JOIN sys.foreign_key_columns AS [fkc]
		ON [fkc].[parent_object_id] = [fk].[parent_object_id]
		AND [fkc].[constraint_object_id] = [fk].[object_id]
	INNER JOIN sys.columns AS [c]
		ON [c].[object_id] = [fkc].[parent_object_id]
		AND [c].[column_id] = [fkc].[parent_column_id]
	INNER JOIN sys.tables AS [s]
		ON [s].[object_id] = [fk].[referenced_object_id]
	INNER JOIN sys.foreign_key_columns AS [fkb]
		ON [fkb].[referenced_object_id] = [fk].[referenced_object_id]
		AND [fkb].[constraint_object_id] = [fk].[object_id]
	INNER JOIN sys.columns AS [b]
		ON [b].[object_id] = [fkb].[referenced_object_id]
		AND [b].[column_id] = [fkb].[referenced_column_id]
WHERE [fk].[is_ms_shipped] = 0
	AND ([t].[schema_id] IN (SELECT [object_id] FROM @definitions WHERE [type] = 'SC')
		OR [s].[schema_id] IN (SELECT [object_id] FROM @definitions WHERE [type] = 'SC'))

--============================================================--
/* Functions, Stored Procedures, Triggers and Views */

IF 1 IN (@scalar_functions, @table_valued_functions, @stored_procedures, @views)
BEGIN
	INSERT INTO @definitions
	SELECT [o].[type],
		SCHEMA_NAME([o].[schema_id]) AS [schema],
		IIF([o].[type] = 'TR', OBJECT_NAME([o].[parent_object_id]), NULL) AS [table],
		[o].[name],
		[o].[object_id],
		CONCAT('IF (OBJECT_ID(''[', SCHEMA_NAME([o].[schema_id]), '].[', [o].[name], ']'', ''', RTRIM([o].[type]) COLLATE database_default, ''') IS NULL)', 
		CHAR(10), 'BEGIN', 
		CHAR(10), 'EXEC(''', REPLACE([m].[definition], '''', ''''''), ''')',
		CHAR(10), 'END') AS [definition]
	FROM sys.objects AS [o]
		INNER JOIN sys.sql_modules AS [m]
			ON [m].[object_id] = [o].[object_id]
	WHERE [o].[type] IN ('FN', 'IF', 'TF', 'V', 'P', 'TR')
		AND [o].[is_ms_shipped] = 0
		AND [o].[schema_id] IN (SELECT [object_id] FROM @definitions WHERE [type] = 'SC')
		AND NOT ([o].[schema_id] = SCHEMA_ID('jra')
			AND ([o].[name] = 'usp_build_db_creator'
				OR [o].[name] LIKE 'usp_create_[[]%]'
				OR [o].[name] LIKE 'usp_drop_and_create_[[]%]'))
END

--============================================================--
/* Indexes */

IF @indexes = 1
BEGIN
	INSERT INTO @definitions
	SELECT 'I' AS [type],
		SCHEMA_NAME([o].[schema_id]) AS [schema],
		[o].[name] AS [table],
		[i].[name],
		[i].[object_id],
		CONCAT('IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = ''', [i].[name], ''' AND [object_id] = OBJECT_ID(''[', SCHEMA_NAME([o].[schema_id]), '].[', [o].[name], ']''))', 
		CHAR(10), 'BEGIN', 
		CHAR(10), 'CREATE ', IIF([i].[is_unique] = 1, 'UNIQUE ', ''), [i].[type_desc] COLLATE database_default, ' INDEX ', [i].[name], ' ON [', SCHEMA_NAME([o].[schema_id]), '].[', [o].[name], '](',
			STUFF((
				SELECT CONCAT(', [', [c].[name], ']')
				FROM sys.index_columns AS [ic]
					INNER JOIN sys.columns AS [c]
						ON [c].[object_id] = [ic].[object_id]
						AND [c].[column_id] = [ic].[column_id]
				WHERE [ic].[object_id] = [i].[object_id]
					AND [ic].[index_id] = [i].[index_id]
				FOR XML PATH(''), TYPE
			).value('./text()[1]', 'nvarchar(max)'), 1, 2, ''),
			');',
			CHAR(10), 'END') AS [definition]
	FROM sys.indexes AS [i]
		INNER JOIN sys.objects AS [o]
			ON [o].[object_id] = [i].[object_id]
	WHERE [i].[is_primary_key] = 0
		AND [i].[is_unique_constraint] = 0
		AND [i].[index_id] > 0
		AND [o].[type] IN ('U', 'V')
		AND [o].[schema_id] IN (SELECT [object_id] FROM @definitions WHERE [type] = 'SC')
END

--============================================================--
/* Definitions Cursor */

SET @sql = 'CREATE OR ALTER PROCEDURE '
SET @description = CONCAT('[jra].[usp_', IIF(@replace = 1, 'drop_and_', ''), 'create_[', DB_NAME(), ']]_[', REPLACE(REPLACE(@schemata, ',', ']]_['), ' ', ''), ']]]')
IF LEN(@description) >= 128
	SET @description = SUBSTRING(@description, 1, CHARINDEX(']]', @description)) + ']]'
SET @sql = CONCAT(@sql, @description, ' AS')

SET @sql += CONCAT(
	CHAR(10), '/*',
	CHAR(10), 'Author: [jra].[usp_build_db_creator]',
	CHAR(10), 'Date: ', FORMAT(GETUTCDATE(), 'yyyy-MM-dd HH:mm:ss'), CHAR(10),
	CHAR(10), 'Description:',
	CHAR(10), IIF(@replace = 1, 'Drops and c', 'C'), 'reates the objects from the schemata ', REPLACE(@schema, ',', ', '), ', from database ', DB_NAME(), '.',
	CHAR(10),
	CHAR(10), 'Returns: ', (SELECT CHAR(10) + '- ' + COALESCE([defs].[name], [defs].[table], [defs].[schema]) + ' (' + LOWER([types].[description]) + ')' FROM @definitions AS [defs] INNER JOIN @types AS [types] ON [types].[type] = [defs].[type] ORDER BY [types].[order] FOR XML PATH('')), 
	CHAR(10),
	CHAR(10), 'Usage:',
	CHAR(10), 'EXECUTE ', @description,
	CHAR(10), '*/',
	CHAR(10), 'BEGIN'
)

DECLARE definitions_cursor cursor STATIC SCROLL FOR
SELECT ROW_NUMBER() OVER(PARTITION BY [defs].[type] ORDER BY [schema], [table], [name]) AS [R],
	ROW_NUMBER() OVER(PARTITION BY [defs].[type], [schema], [table] ORDER BY [name]) AS [O],
	[types].[type],
	[types].[description],
	[defs].[schema],
	[defs].[table],
	[defs].[name],
	[defs].[definition]
FROM @definitions AS [defs]
	INNER JOIN @types AS [types]
		ON [types].[type] = [defs].[type]
ORDER BY [types].[order], [R], [O]

OPEN definitions_cursor

FETCH FIRST FROM definitions_cursor
INTO @R, @O, @type, @description, @schema, @table, @name, @definition

WHILE @@FETCH_STATUS = 0
BEGIN
	IF @type = 'F'
	BEGIN
		IF @R = 1
			SET @sql += CONCAT(CHAR(10), '--============================================================--', CHAR(10), '/* ', @description, ' Dropping */', CHAR(10))
		IF @O = 1 and @name IS NOT NULL AND @table IS NOT NULL
			SET @sql += CONCAT(CHAR(10), '/* [', @schema, '].[', @table, '] */')
		SET @sql += CONCAT(
			CHAR(10), '-- ', COALESCE(@name, @table, @schema), 
			CHAR(10), 'IF (OBJECT_ID(''', @name, ''', ''F'') IS NOT NULL)',
			CHAR(10), CHAR(9), 'ALTER TABLE [', @schema, '].[', @table, '] DROP CONSTRAINT ', @name, ';',
			CHAR(10)
		)
	END
	ELSE IF @type IN ('FN', 'TF', 'TR', 'V') AND @replace = 1
	BEGIN
		IF @R = 1
			SET @sql += CONCAT(CHAR(10), '--============================================================--', CHAR(10), '/* ', @description, ' Dropping */', CHAR(10))
		IF @O = 1 and @name IS NOT NULL AND @table IS NOT NULL
			SET @sql += CONCAT(CHAR(10), '/* [', @schema, '].[', @table, '] */')
		SET @sql += CONCAT(
			CHAR(10), '-- ', COALESCE(@name, @table, @schema), 
			CHAR(10), 'DROP ', CASE WHEN @type = 'V' THEN 'VIEW' WHEN @type = 'TR' THEN 'TRIGGER' ELSE 'FUNCTION' END, ' IF EXISTS [', @schema, '].[', @name, '];', 
			CHAR(10)
		)
	END

	FETCH NEXT FROM definitions_cursor
	INTO @R, @O, @type, @description, @schema, @table, @name, @definition
END

FETCH FIRST FROM definitions_cursor
INTO @R, @O, @type, @description, @schema, @table, @name, @definition

IF @replace = 1
BEGIN
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @type = 'U'
		BEGIN
			IF @R = 1
				SET @sql += CONCAT(CHAR(10), '--============================================================--', CHAR(10), '/* ', @description, ' Dropping */', CHAR(10))
			SET @sql += CONCAT('DROP TABLE IF EXISTS [', @schema, '].[', @table, '];', CHAR(10))
		END

		FETCH NEXT FROM definitions_cursor
		INTO @R, @O, @type, @description, @schema, @table, @name, @definition
	END
END

FETCH FIRST FROM definitions_cursor
INTO @R, @O, @type, @description, @schema, @table, @name, @definition

WHILE @@FETCH_STATUS = 0
BEGIN
	IF @R = 1
		SET @sql += CONCAT(CHAR(10), '--============================================================--', CHAR(10), '/* ', @description, ' Creating */', CHAR(10))
	IF @O = 1 and @name IS NOT NULL AND @table IS NOT NULL
		SET @sql += CONCAT(CHAR(10), '/* [', @schema, '].[', @table, '] */')
	SET @sql += CONCAT(CHAR(10), '-- ', COALESCE(@name, @table, @schema), CHAR(10), @definition, ';', CHAR(10))

	FETCH NEXT FROM definitions_cursor
	INTO @R, @O, @type, @description, @schema, @table, @name, @definition
END

CLOSE definitions_cursor
DEALLOCATE definitions_cursor

SET @sql += CONCAT(CHAR(10), 'END')

IF @print = 1
	EXECUTE [jra].[usp_print] @sql
IF @display = 1
BEGIN
	SELECT [types].[type],
		[types].[description],
		[defs].[schema],
		[defs].[table],
		[defs].[name],
		[defs].[definition]
	FROM @definitions AS [defs]
		INNER JOIN @types AS [types]
			ON [types].[type] = [defs].[type]
	ORDER BY [types].[order]
END
IF @commit = 1
	EXEC(@sql)