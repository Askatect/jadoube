DECLARE @test table (
	[partition] int NOT NULL DEFAULT 1,
	[l_pid] int,
	[r_pid] int,
	[l_id] char(1),
	[r_id] char(1)
)
INSERT INTO @test([l_pid], [r_pid], [l_id], [r_id])
VALUES (1, 2, 'a', 'b'),
	(2, 3, 'b', 'c'),
	(2, 4, 'b', 'd'),
	(3, 4, 'c', 'd')

SELECT * FROM @test

DECLARE @row_count int = 1
WHILE @row_count > 0
BEGIN
UPDATE [beta]
SET [beta].[l_pid] = [alpha].[l_pid],
	[beta].[l_id] = [alpha].[l_id]
OUTPUT [alpha].*, deleted.*
FROM @test AS [alpha]
	INNER JOIN @test AS [beta]
		ON [alpha].[partition] = [beta].[partition]
		AND [alpha].[l_pid] < [beta].[l_pid]
		AND [alpha].[r_pid] IN ([beta].[l_pid], [beta].[r_pid])

SET @row_count = @@ROWCOUNT
END

SELECT * FROM @test
SELECT DISTINCT * FROM @test