# jadoube

| Version: 1.1
| Authors: JRA
| Date: 2024-10-17

#### Explanation:
Useful generic SQL programs.

#### Artefacts:
- fn_age: Calculates the floor of the difference in years between two dates.
- fn_damerau_levenshtein_distance: Returns the unrestricted Damerau-Levenshtein distance. Similar to the optimal string alignment (OSA) distance - where deletions, insertions, substitutions and transpositions of adjacent characters are allowed - except in Damerau-Levenshtein a substring can be edited more than once. The closer the value to zero, the more similar the strings are. The algorithm used is based on https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance#Distance_with_adjacent_transpositions.
- fn_extract_param: Extracts parameters from strings formed of key/value pairs, optionally with separators.
- fn_extract_pattern: Given a string, a pattern and its length, the function removes instances of the pattern from the string.
- fn_fingerprint: Returns a "fingerprint" of a string. The string is converted to lower case and all non-alphanumeric characters are removed.
- fn_gradient_hex: Uses linear interpolation to find the hexcode of a value on the gradient between two colours.
- fn_jaro_similarity: Computes the Jaro similarity between two strings. This is a value in the interval [0, 1], where 1 is an exact match. This algorithm is based on https://www.geeksforgeeks.org/jaro-and-jaro-winkler-similarity/.
- fn-jaro_winkler_similarity: Computes the Jaro-Winkler similarity between two strings. This is a value in the interval [0, 1], where 1 is an exact match. Note that the product of the scaling factor and the maximum matching prefix length should be no more than 1.
- fn_json_formatter: Formats an input JSON string with line breaks and indents.
- fn_levenshtein_distance: Returns the Levenshtein distance (a positive integer), calculated with the algorithm at https://www.codeproject.com/Articles/13525/Fast-memory-efficient-Levenshtein-algorithm-2. The closer the value to zero, the more similar the strings are.
- fn_matching_damerau_levenshtein_normalised: The normalised Damerau-Levenshtein distance is a real value in the interval [0, 1], where a value of 0 indicates an exact match. True is returned if the normalised unrestricted Damerau-Levenshtein distance is below the given threshold.
- fn_matching_damerau_levenshtein: Calculates whether two strings are within a threshold of similarity according to the unrestricted Damerau-Levenshtein distance.
- fn_matching_exact: Returns 1 if the two input strings are an exact case-sensitive match.
- fn_matching_jaro_winkler: Returns true if the given strings are more similar than the given threshold according to the Jaro-Winkler similarity measure.
- fn_matching_jaro: Returns true if the given strings are more similar than the given threshold according to the Jaro similarity measure.
- fn_matching_levenshtein_low_normalised: The normalised Levenshtein distance is a real value in the interval [0, 1], where a value of 0 indicates an exact match. True is returned if the normalised levenshtein distance is below the given threshold. The recursive calculation method is used, so this is optimised for lower thresholds.
- fn_matching_levenshtein_low: Calculates whether two strings are within a threshold of similarity according to the Levenshtein distance. The recursive approach is used, so this works best for lower thresholds.
- fn_matching_levenshtein_normalised: The normalised Levenshtein distance is a real value in the interval [0, 1], where a value of 0 indicates an exact match. True is returned if the normalised levenshtein distance is below the given threshold. For possible improved performance, consider using [jadoube].[fn_matching_levenshtein_low_normalised].
- fn_matching_levenshtein: Returns true if the Levenshtein distance (a positive integer), is below the given threshold (inclusive). For possible improved performance, consider using [jadoube].[fn_levenshtein_low] when using a low threshold.
- fn_matching_osa_low_normalised: The normalised optimal string alignment distance is a real value in the interval [0, 1], where a value of 0 indicates an exact match. True is returned if the normalised optimal string alignment distance is below the given threshold.
- fn_matching_osa_low: Calculates whether two strings are within a threshold of similarity according to the optimal string alignment (OSA) distance. The recursive approach is used, so this works best for lower thresholds.
- fn_matching_osa_normalised: The normalised optimal string alignment (OSA) distance is a real value in the interval [0, 1], where a value of 0 indicates an exact match. True is returned if the normalised OSA distance is below the given threshold. For possible improved performance, consider using [jadoube].[fn_matching_osa_low_normalised].
- fn_matching_osa: Calculates whether two strings are within a threshold of similarity according to the optimal string alignment distance.
- fn_osa_distance: Returns the optimal string alignment distance (also known as the restricted edit distance). Similar to the Damerau-Levenshtein distance - where deletions, insertions, substitutions and transpositions of adjacent characters are allowed - except in OSA a substring may not be edited more than once. The closer the value to zero, the more similar the strings are. The algorithm used is a variant of the Wagner-Fischer algorithm and is also memory optimised.
- fn_replace: Replaces occurrences of a substring - can be a regex set - with another substring in the input string, until no further substitutions need be made.
- fn_start_case: Converts a given string to start case.
- fn_string_split_item: Retrieves the item at the given index from a delimited string.
- fn_title_case: Converts an input string to title case.
- levenshtein.cs: Levenshtein distance function in C#, for possible compilation to a .dll file and assembly into SQL Server.
- p_build_db_creator: Reads schemata of the current database and writes the DDL commands to recreate objects into a stored procedure.
- p_mashing: Given one or two tables - with the same structure - that features a master key and duplicate keys, mashing unifies them into a single table, where no master appears as a duplicate and no duplicate appears as a master. Additional columns can be specified to be carried about with the changed. The output is stored in a table with the same schema and name as the target, with the table name suffixed with "_mashing".
- p_matching: Deduplication linkage on a given dataset according to provided blocking key and matching rules. This matching results are captured in a table of the same schema but table name suffixed by '_matching'. This table has the following structure:
    - partition (bigint): An identifier for the partition defined by the blocking rule.
    - l_pid (bigint): An identifier for the record.
    - r_pid (bigint): An identifier for the matched record.
    - l_id (any): Supplied key.
    - r_id (any): Supplied key that matched with the key in `l_id`.
- p_print: Prints large strings to console.
- p_select_to_html_colour: Takes the output table from a given DQL script and writes it to a HTML table.
- p_select_to_html: Converts a SQL table to basic html and displays the html.
- p_string_table_split: Given a string of delimited data and the delimiters, a tabulated form of the data is created.
- p_structure_compliance: Adds an [__error__] column to a specified object an populates it with cases where the object deviates from a particular structure. The structure can be chosen by pointing at an existing object. Column name and order are checked, datatypes are checked, truncation errors are optionally checked and non-nullability is also checked.
- p_timer: Measures duration of instances and batches, with the options to print the duration during execution and to display summary data (recommended at the end of a script only). The following terms are used:
    - "Instance": Instances are unique executions of some SQL, separated by calls to [jra].[timer] or start and end of a batch.
    - "Process": All instances are processes, but processes can be named by the user for reference. Particularly useful if the same instance is run multiple times and they need identifying.
    - "Task": Tasks are unique executions of batches, separated by the start or end of the script or the GO command.
    - "Batch": All tasks are batches, but batches can identify multiple tasks that are the same SQL run at different times.
    - "Plan": In SQL Server, the engine designs an execution plan for each batch, which may change over time for optimisation purposes. This is also recorded.
- p_transpose_table: Transposes a table defined by a DQR script.
- tf_hexcode_to_rgb: Converts a hexcode to RGB values.
- tf_string_split: Splits a string into a table with [ordinal] as the zero-index and [value] as the value.

#### History:
- 1.2 JRA (2024-10-23): Added several more matching functions and updates to related scripts.
- 1.1 JRA (2024-10-17): Added fn_exact_match, fn_levenshtein_distance, fn_levenshtein_low.sql, fn_levenshtein, levenshtein.cs, p_mashing and p_matching. Changed all schema references to [jadoube].
- 1.0 JRA (2024-09-24): Initial repository pulled from libjrary.