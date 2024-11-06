SELECT TOP(100) 
	[Book Id], 
	[Author],
	[Author l-f],
	[Title], 
	[Original Publication Year]
FROM [misc].[goodreads]

DECLARE @match_rules varchar(max)
SET @match_rules = CONCAT_WS(';',
	'Author,exact,1',
	'Title,levenshtein_low,5',
	'Author l-f,exact,1,a',
	'Original Publication Year,exact,1,a'
)
PRINT('@match_rules: ' + @match_rules)

EXECUTE [jadoube].[p_matching]
	@schema = 'misc',
	@table = 'goodreads',
	@id_column = 'Book Id',
	@blocking_key = 'LEFT([Author], 1)',
	@priority = 'ISNULL([Original Publication Year], 9999) ASC',
	@match_rules = @match_rules,
	@mash = 0,
	@print = 1,
	@execute = 1

SELECT [a].*,
	[b].[Author],
	[c].[Author],
	[b].[Title],
	[c].[Title],
	[b].[Author l-f],
	[c].[Author l-f],
	[b].[Original Publication Year],
	[c].[Original Publication Year]
FROM [misc].[goodreads_matching] AS [a]
	INNER JOIN [misc].[goodreads] AS [b]
		ON [b].[Book Id] = [a].[l_id]
	INNER JOIN [misc].[goodreads] AS [c]
		ON [c].[Book Id] = [a].[r_id]
ORDER BY [b].[Author], 
	[c].[Author]

EXECUTE [jadoube].[p_mashing]
	@target_schema = 'misc',
	@target_table = 'goodreads_matching',
	@source_schema = NULL,
	@source_table = NULL,
	@master_key = 'l_id',
	@duplicate_key = 'r_id',
	@update_columns = 'l_pid',
	@priority = '[l_pid] ASC',
	@print = 1,
	@execute = 1

SELECT *
FROM [misc].[goodreads_matching_mashing]
ORDER BY [l_id], [r_id]