# jadoube

| Version: 1.0
| Authors: JRA
| Date: 2024-09-24

#### Explanation:
Useful generic SQL programs.

#### Artefacts:
- fn_age: Calculates the floor of the difference in years between two dates.
- fn_extract_param: Extracts parameters from strings formed of key/value pairs, optionally with separators.
- fn_extract_pattern: Given a string, a pattern and its length, the function removes instances of the pattern from the string.
- fn_gradient_hex: Uses linear interpolation to find the hexcode of a value on the gradient between two colours.
- fn_json_formatter: Formats an input JSON string with line breaks and indents.
- fn_replace: Replaces occurrences of a substring - can be a regex set - with another substring in the input string, until no further substitutions need be made.
- fn_start_case: Converts a given string to start case.
- fn_string_split_item: Retrieves the item at the given index from a delimited string.
- fn_title_case: Converts an input string to title case.
- p_build_db_creator: Reads schemata of the current database and writes the DDL commands to recreate objects into a stored procedure.
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
- 1.0 JRA (2024-09-24): Initial repository pulled from libjrary.