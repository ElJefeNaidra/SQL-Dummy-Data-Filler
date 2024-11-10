# SQL-Dummy-Data-Filler

SQL Scripst for both MSSQL and MySQL used to automate dummy data filling of databases for testing of index sizes, joins etc

    Description:
    This stored procedure generates and inserts dummy data into a specified table in SQL Server based on its schema metadata. The procedure dynamically detects the column types, constraints, and relationships, inserting values according to each column's characteristics.

    Features:
    1. **Primary Key and Identity Columns**:
       - Skips `Identity` columns that automatically increment.
       - Inserts sequential values or random unique values in primary key columns as applicable.

    2. **Data Type Handling**:
       - Supports common SQL Server data types including:
         - `int`, `bigint`, `smallint`, `tinyint`
         - `nvarchar`, `varchar`
         - `decimal`, `numeric`, `float`
         - `datetime`, `datetime2`, `date`
       - Uses additional helper stored procedures to generate appropriate data for each type:
         - `GenerateRandomInt` for integer columns
         - `GenerateRandomString` for string-based columns with controlled randomness
         - `GenerateRandomDecimal` for precise decimal values
         - `GenerateRandomDateTime` for datetime columns, with different levels of precision

    3. **Unique Constraints**:
       - If a column has a unique index, the procedure ensures unique values are generated accordingly.

    4. **Foreign Key Handling**:
       - Detects foreign key columns and retrieves values from the referenced table.
       - If the referenced table has no rows and the foreign key column is nullable, inserts `NULL`.
       - If the foreign key column is not nullable and the referenced table has no rows, the procedure exits and provides an error message.

    5. **Randomness Factor**:
       - Controlled by `@RandomnessFactor` parameter, allowing varied levels of randomness for string-based columns.

    6. **Dynamic Column Length Adjustment**:
       - Adjusts the length of `nvarchar` and `varchar` columns based on their maximum length and ensures strings are generated to fit the length requirement.

