/*
    Stored Procedure: InsertDummyData
    
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

    Parameters:
    - `@SchemaName NVARCHAR(128)`: The schema name of the target table.
    - `@TableName NVARCHAR(128)`: The name of the target table to fill with dummy data.
    - `@RowCount INT`: The number of rows to insert.
    - `@RandomnessFactor INT`: Controls the randomness level for text-based columns.
    - `@VarcharMinLength INT`: Minimum length of strings generated for `varchar` and `nvarchar` columns.

    Usage:
    - The procedure is used to quickly populate tables with sample data, useful for testing and development.
    
    Example Execution:
    ```
    DECLARE @SchemaName NVARCHAR(128) = 'dbo';
    DECLARE @TableName NVARCHAR(128) = 'TestData';
    DECLARE @RowCount INT = 30;
    EXEC InsertDummyData @SchemaName, @TableName, @RowCount;
    ```
*/

DECLARE @SchemaName NVARCHAR(128) = ''; -- Schema Name
DECLARE @TableName NVARCHAR(128) = ''; -- Table Name
DECLARE @RowCount INT = 30; -- Number of rows to insert
DECLARE @CurrentRow INT = 1;
DECLARE @SQL NVARCHAR(MAX);
DECLARE @Columns NVARCHAR(MAX) = '';
DECLARE @Values NVARCHAR(MAX);
DECLARE @RandomnessFactor INT = 1; -- Randomness factor
DECLARE @VarcharMinLength INT = 1;

-- Utility variables for storing generated random values
DECLARE @RandomString NVARCHAR(MAX);
DECLARE @RandomInt BIGINT;
DECLARE @RandomDecimal DECIMAL(38,18);
DECLARE @RandomDateTime DATETIME2;
DECLARE @BinaryValue VARBINARY(MAX);
DECLARE @CharValue NVARCHAR(MAX);
DECLARE @MoneyValue MONEY;
DECLARE @GeographyValue GEOGRAPHY;
DECLARE @TimeValue TIME;
DECLARE @RealValue REAL;
DECLARE @SmallDateTimeValue SMALLDATETIME;
DECLARE @SmallMoneyValue SMALLMONEY;
DECLARE @NCharValue NCHAR(100);

-- Cursor variables for column metadata
DECLARE @ColumnName NVARCHAR(128);
DECLARE @ColumnDataType NVARCHAR(50);
DECLARE @ColumnLength INT;
DECLARE @IsNullable BIT;
DECLARE @IsIndex BIT;
DECLARE @IsIndexUnique BIT;
DECLARE @IsPrimaryKey BIT;
DECLARE @IsIdentityAutoIncrement BIT;
DECLARE @IsFK BIT;
DECLARE @FKReferenceTable NVARCHAR(128);

-- Construct the fully qualified table name
DECLARE @FullTableName NVARCHAR(256) = QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName);

-- Define a cursor to fetch column metadata
DECLARE column_cursor CURSOR FOR
SELECT 
    c.name AS ColumnName,
    t.name AS ColumnDataType,
    CASE 
        WHEN c.max_length = -1 THEN 4000    -- Handling for `MAX` types (e.g., nvarchar(max))
        WHEN t.name = 'nvarchar' THEN c.max_length / 2 -- Adjust for nvarchar byte size
        ELSE c.max_length 
    END AS ColumnLength,
    c.is_nullable AS IsNullable,
    CASE WHEN i.index_id IS NOT NULL THEN 1 ELSE 0 END AS IsIndex,
    CASE WHEN i.is_unique = 1 THEN 1 ELSE 0 END AS IsIndexUnique,
    CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS IsPrimaryKey,
    ISNULL(ic.is_identity, 0) AS IsIdentityAutoIncrement,
    CASE WHEN fk.constraint_column_id IS NOT NULL THEN 1 ELSE 0 END AS IsFK,
    OBJECT_NAME(fk.referenced_object_id) AS FKReferenceTable
FROM 
    sys.columns c
JOIN 
    sys.types t ON c.user_type_id = t.user_type_id
LEFT JOIN 
    sys.identity_columns ic ON c.object_id = ic.object_id AND c.column_id = ic.column_id
LEFT JOIN 
    sys.index_columns idxcol ON c.object_id = idxcol.object_id AND c.column_id = idxcol.column_id
LEFT JOIN 
    sys.indexes i ON idxcol.object_id = i.object_id AND idxcol.index_id = i.index_id
LEFT JOIN 
    (SELECT ic.column_id
     FROM sys.index_columns ic
     JOIN sys.indexes ix ON ic.object_id = ix.object_id AND ix.is_primary_key = 1
    ) pk ON c.column_id = pk.column_id
LEFT JOIN 
    sys.foreign_key_columns fk ON fk.parent_object_id = c.object_id AND fk.parent_column_id = c.column_id
WHERE 
    c.object_id = OBJECT_ID(@FullTableName);

-- Open the cursor to get column names
OPEN column_cursor;

-- Build the column names string for the INSERT statement
FETCH NEXT FROM column_cursor INTO @ColumnName, @ColumnDataType, @ColumnLength, @IsNullable, @IsIndex, @IsIndexUnique, @IsPrimaryKey, @IsIdentityAutoIncrement, @IsFK, @FKReferenceTable;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Skip identity/autoincrement columns
    IF @IsIdentityAutoIncrement = 0
    BEGIN
        SET @Columns += QUOTENAME(@ColumnName) + ',';
    END
    FETCH NEXT FROM column_cursor INTO @ColumnName, @ColumnDataType, @ColumnLength, @IsNullable, @IsIndex, @IsIndexUnique, @IsPrimaryKey, @IsIdentityAutoIncrement, @IsFK, @FKReferenceTable;
END
-- Remove the trailing comma from @Columns
SET @Columns = LEFT(@Columns, LEN(@Columns) - 1);

-- Loop through each row for insertion
WHILE @CurrentRow <= @RowCount
BEGIN
    SET @Values = ''; -- Reset @Values for each row

    -- Reset the cursor to the first record
    CLOSE column_cursor;
    OPEN column_cursor;

    FETCH NEXT FROM column_cursor INTO @ColumnName, @ColumnDataType, @ColumnLength, @IsNullable, @IsIndex, @IsIndexUnique, @IsPrimaryKey, @IsIdentityAutoIncrement, @IsFK, @FKReferenceTable;

    WHILE @@FETCH_STATUS = 0
    BEGIN

		-- Check if column is a PK --
		IF @IsPrimaryKey = 1 AND @ColumnDataType IN ('tinyint', 'smallint', 'int', 'bigint')
		BEGIN
			-- Check if it's an auto incremented PK seed
			IF @IsIdentityAutoIncrement = 1
			BEGIN
				SET @Values = '';
			END
		END

		-- Handling varchar columns --
		ELSE IF @ColumnDataType IN ('nvarchar', 'varchar')
        BEGIN
            -- Reset the variable before each call to ensure it's empty
            SET @RandomString = '';

			-- Check if VarcharMinLength > @ColumnLength
			IF @ColumnLength < @VarcharMinLength
			BEGIN
				SET @VarcharMinLength = @ColumnLength
			END

            -- Generate a unique random string for each row
            EXEC dbo.GenerateRandomString 
                @MinLength = @VarcharMinLength, 
                @MaxLength = @ColumnLength, 
                @RandomnessFactor = @RandomnessFactor, 
                @RandomString = @RandomString OUTPUT;

            -- Append the generated random string to the values for the INSERT statement
            SET @Values += '''' + @RandomString + ''',';
        END

		-- Handling integer columns including foreign key checks --
		ELSE IF @ColumnDataType IN ('int', 'bigint', 'smallint', 'tinyint') AND @IsPrimaryKey = 0
		BEGIN
			-- Check if the column is a foreign key
			IF @IsFK = 1
			BEGIN
				DECLARE @ReferencedTableRowCount INT;
        
				-- Query to count rows in the referenced table
				DECLARE @ReferencedTableCountQuery NVARCHAR(MAX) = 
					'SELECT @RowCount = COUNT(*) FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@FKReferenceTable);
        
				EXEC sp_executesql @ReferencedTableCountQuery, N'@RowCount INT OUTPUT', @RowCount = @ReferencedTableRowCount OUTPUT;

				-- Check if referenced table has rows
				IF @ReferencedTableRowCount > 0
				BEGIN
					-- Fetch a random value from the referenced table
					DECLARE @ReferencedValue INT;
					DECLARE @RandomValueQuery NVARCHAR(MAX) = 
						'SELECT TOP 1 @ReferencedValue = ' + QUOTENAME(@ColumnName) + ' FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@FKReferenceTable) + ' ORDER BY NEWID()';
            
					EXEC sp_executesql @RandomValueQuery, N'@ReferencedValue INT OUTPUT', @ReferencedValue = @ReferencedValue OUTPUT;
            
					SET @Values += CAST(@ReferencedValue AS NVARCHAR) + ',';
				END
				ELSE
				BEGIN
					IF @IsNullable = 1
					BEGIN
						PRINT 'Warning: ' + @FKReferenceTable + ' has no rows; inserting NULL for nullable foreign key column ' + @ColumnName;
						SET @Values += 'NULL,';
					END
					ELSE
					BEGIN
						PRINT 'Error: ' + @FKReferenceTable + ' has no rows; cannot insert into non-nullable foreign key column ' + @ColumnName;
						-- Close and deallocate the cursor
						CLOSE column_cursor;
						DEALLOCATE column_cursor;
						RETURN;
					END
				END
			END
			ELSE
			BEGIN
				-- If not a foreign key, generate a random integer value
				EXEC dbo.GenerateRandomInt @DataType = @ColumnDataType, @RandomInt = @RandomInt OUTPUT;
				SET @Values += CAST(@RandomInt AS NVARCHAR) + ',';
			END
		END

		-- Handling numeric columns --
		ELSE IF @ColumnDataType IN ('decimal', 'numeric', 'float')
        BEGIN
            EXEC dbo.GenerateRandomDecimal @Precision = 18, @Scale = 4, @RandomDecimal = @RandomDecimal OUTPUT;
            SET @Values += CAST(@RandomDecimal AS NVARCHAR(38)) + ',';
        END

		-- Handling date columns
		ELSE IF @ColumnDataType IN ('datetime', 'datetime2', 'date')
		BEGIN
			EXEC dbo.GenerateRandomDateTime @DataType = @ColumnDataType, @RandomDateTime = @RandomDateTime OUTPUT;
			PRINT @RandomDateTime;

			-- Added: Format the datetime based on the specific data type
			IF @ColumnDataType = 'datetime'
				SET @Values += '''' + CONVERT(NVARCHAR, @RandomDateTime, 120) + ''','; -- Format as yyyy-MM-dd HH:mm:ss for datetime
			ELSE IF @ColumnDataType = 'datetime2'
				SET @Values += '''' + CONVERT(NVARCHAR, @RandomDateTime, 126) + ''','; -- Format as yyyy-MM-ddTHH:mm:ss.fffffff for datetime2
			ELSE
				SET @Values += '''' + CONVERT(NVARCHAR, @RandomDateTime, 120) + ''','; -- Format as yyyy-MM-dd for date
		END

		-------------------------------------------------------------------------------------------------
		-- TO DO: Handle other data types from [dbo].[GenerateOtherTypes] stored procedure if you want --
		-------------------------------------------------------------------------------------------------

		-- Fetch next column
        FETCH NEXT FROM column_cursor INTO @ColumnName, @ColumnDataType, @ColumnLength, @IsNullable, @IsIndex, @IsIndexUnique, @IsPrimaryKey, @IsIdentityAutoIncrement, @IsFK, @FKReferenceTable;
    END

    -- Remove the trailing comma from @Values
    SET @Values = LEFT(@Values, LEN(@Values) - 1);

    -- Construct the final INSERT statement for the current row
    SET @SQL = 'INSERT INTO ' + @FullTableName + ' (' + @Columns + ') VALUES (' + @Values + ');';
	PRINT @SQL
    -- Execute the generated SQL for the current row
    EXEC sp_executesql @SQL;

    -- Move to the next row
    SET @CurrentRow += 1;
END

-- Clean up
CLOSE column_cursor;
DEALLOCATE column_cursor;
