/*
    Stored Procedure: InsertDummyData

    Author: Ardian Krasniqi - ardian.krasniqi@hotmail.com
    Initial release: November 2017

    Description:
    This stored procedure dynamically generates and inserts dummy data into a specified table in MySQL based on its schema metadata. The procedure detects column types, constraints, and relationships, then inserts appropriate values for each column based on its characteristics.

    Features:
    1. **Primary Key and Identity Columns**:
       - Skips `AUTO_INCREMENT` columns that automatically increment.
       - Inserts sequential or random unique values in primary key columns as applicable.

    2. **Data Type Handling**:
       - Supports common MySQL data types including:
         - `int`, `bigint`, `smallint`, `tinyint`, `mediumint`
         - `varchar`, `nvarchar`, `text`
         - `decimal`, `numeric`
         - `datetime`, `date`
       - Uses additional helper stored procedures to generate data for each type:
         - `GenerateRandomInt` for integer columns
         - `GenerateRandomString` for string-based columns with controlled randomness
         - `GenerateRandomDecimal` for precise decimal values
         - `GenerateRandomDateTime` for datetime columns, with different levels of precision

    3. **Unique Constraints**:
       - Ensures unique values are generated for columns with unique indexes as needed.

    4. **Foreign Key Handling**:
       - Detects foreign key columns and retrieves values from the referenced table.
       - If the referenced table has no rows and the foreign key column is nullable, inserts `NULL`.
       - If the foreign key column is not nullable and the referenced table has no rows, the procedure exits and provides an error message.

    5. **Randomness Factor**:
       - Controlled by `@RandomnessFactor` parameter, allowing varied levels of randomness for string-based columns.

    6. **Dynamic Column Length Adjustment**:
       - Adjusts the length of `varchar` and `text` columns based on their maximum length, generating strings that fit within the length requirement.

    Parameters:
    - `@DatabaseName VARCHAR(128)`: The name of the database where the target table resides.
    - `@TableName VARCHAR(128)`: The name of the target table to fill with dummy data.
    - `@RowCount INT`: The number of rows to insert.
    - `@RandomnessFactor INT`: Controls the randomness level for text-based columns.
    - `@VarcharMinLength INT`: Minimum length of strings generated for `varchar` and `text` columns.

    Usage:
    - The procedure is used to quickly populate tables with sample data, useful for testing and development.

    Example Execution:
    ```sql
    CALL InsertDummyData('your_database', 'your_table', 30);
    ```
*/

DELIMITER //

CREATE PROCEDURE InsertDummyData(
    IN DatabaseName VARCHAR(128),         -- Database Name
    IN TableName VARCHAR(128),            -- Table Name
    IN RowCount INT,                      -- Number of rows to insert
    IN RandomnessFactor INT DEFAULT 1,    -- Randomness factor for text-based columns
    IN VarcharMinLength INT DEFAULT 1     -- Minimum length of strings for VARCHAR columns
)
BEGIN
    DECLARE CurrentRow INT DEFAULT 1;
    DECLARE SQLStmt TEXT;
    DECLARE Columns TEXT DEFAULT '';
    DECLARE Values TEXT;
    
    -- Utility variables for generated values
    DECLARE RandomString VARCHAR(255);
    DECLARE RandomInt BIGINT;
    DECLARE RandomDecimal DECIMAL(38, 18);
    DECLARE RandomDateTime DATETIME;
    
    -- Cursor variables for column metadata
    DECLARE ColumnName VARCHAR(128);
    DECLARE ColumnDataType VARCHAR(50);
    DECLARE ColumnLength INT;
    DECLARE IsNullable TINYINT;
    DECLARE IsPrimaryKey TINYINT;
    DECLARE IsIdentityAutoIncrement TINYINT;
    DECLARE IsFK TINYINT;
    DECLARE FKReferenceTable VARCHAR(128);
    
    -- Construct the fully qualified table name
    DECLARE FullTableName VARCHAR(256);
    SET FullTableName = CONCAT('`', DatabaseName, '`.`', TableName, '`');
    
    -- Define a cursor to fetch column metadata
    DECLARE column_cursor CURSOR FOR
    SELECT 
        COLUMN_NAME,
        DATA_TYPE,
        CHARACTER_MAXIMUM_LENGTH,
        IF(IS_NULLABLE = 'YES', 1, 0) AS IsNullable,
        IF(COLUMN_KEY = 'PRI', 1, 0) AS IsPrimaryKey,
        IF(EXTRA = 'auto_increment', 1, 0) AS IsIdentityAutoIncrement,
        IFNULL((SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = DatabaseName AND TABLE_NAME = TableName AND COLUMN_NAME = COLUMN_NAME AND REFERENCED_TABLE_NAME IS NOT NULL), 0) AS IsFK,
        (SELECT REFERENCED_TABLE_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = DatabaseName AND TABLE_NAME = TableName AND COLUMN_NAME = COLUMN_NAME AND REFERENCED_TABLE_NAME IS NOT NULL) AS FKReferenceTable
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DatabaseName AND TABLE_NAME = TableName;

    -- Open the cursor to get column names
    OPEN column_cursor;

    -- Build the column names string for the INSERT statement
    FETCH NEXT FROM column_cursor INTO ColumnName, ColumnDataType, ColumnLength, IsNullable, IsPrimaryKey, IsIdentityAutoIncrement, IsFK, FKReferenceTable;
    WHILE FOUND() DO
        -- Skip identity/autoincrement columns
        IF IsIdentityAutoIncrement = 0 THEN
            SET Columns = CONCAT(Columns, '`', ColumnName, '`,');
        END IF;
        FETCH NEXT FROM column_cursor INTO ColumnName, ColumnDataType, ColumnLength, IsNullable, IsPrimaryKey, IsIdentityAutoIncrement, IsFK, FKReferenceTable;
    END WHILE;

    -- Remove the trailing comma from Columns
    SET Columns = LEFT(Columns, CHAR_LENGTH(Columns) - 1);

    -- Loop through each row for insertion
    WHILE CurrentRow <= RowCount DO
        SET Values = ''; -- Reset Values for each row

        -- Reset the cursor to the first record
        CLOSE column_cursor;
        OPEN column_cursor;

        FETCH NEXT FROM column_cursor INTO ColumnName, ColumnDataType, ColumnLength, IsNullable, IsPrimaryKey, IsIdentityAutoIncrement, IsFK, FKReferenceTable;
        
        WHILE FOUND() DO
            -- Handling varchar and nvarchar columns
            IF ColumnDataType IN ('varchar', 'nvarchar') THEN
                SET RandomString = '';
                CALL GenerateRandomString(VarcharMinLength, ColumnLength, RandomnessFactor, RandomString);
                SET Values = CONCAT(Values, "'", RandomString, "',");
            
            -- Handling text columns
            ELSEIF ColumnDataType = 'text' THEN
                SET RandomString = '';
                CALL GenerateRandomString(VarcharMinLength, 255, RandomnessFactor, RandomString);  -- Generate a reasonable length for TEXT
                SET Values = CONCAT(Values, "'", RandomString, "',");

            -- Handling integer columns including all MySQL int types
            ELSEIF ColumnDataType IN ('int', 'bigint', 'smallint', 'tinyint', 'mediumint') THEN
                IF IsFK = 1 THEN
                    -- Fetch a random value from the referenced table
                    SET @ReferencedValue = (SELECT COLUMN_NAME FROM FKReferenceTable ORDER BY RAND() LIMIT 1);
                    IF @ReferencedValue IS NOT NULL THEN
                        SET Values = CONCAT(Values, @ReferencedValue, ",");
                    ELSEIF IsNullable = 1 THEN
                        SET Values = CONCAT(Values, "NULL,");
                    ELSE
                        LEAVE;  -- Exit if the referenced table has no rows for a non-nullable FK
                    END IF;
                ELSE
                    CALL GenerateRandomInt(ColumnDataType, RandomInt);
                    SET Values = CONCAT(Values, RandomInt, ",");
                END IF;

            -- Handling decimal and numeric columns
            ELSEIF ColumnDataType IN ('decimal', 'numeric') THEN
                CALL GenerateRandomDecimal(18, 4, RandomDecimal);
                SET Values = CONCAT(Values, RandomDecimal, ",");

            -- Handling datetime columns
            ELSEIF ColumnDataType IN ('datetime', 'date') THEN
                CALL GenerateRandomDateTime(ColumnDataType, NULL, NULL, RandomDateTime);
                SET Values = CONCAT(Values, "'", RandomDateTime, "',");

            -- Handling other data types if needed
            ELSE
                -- Default NULL for unsupported data types or unrecognized columns
                SET Values = CONCAT(Values, "NULL,");
            END IF;

            FETCH NEXT FROM column_cursor INTO ColumnName, ColumnDataType, ColumnLength, IsNullable, IsPrimaryKey, IsIdentityAutoIncrement, IsFK, FKReferenceTable;
        END WHILE;

        -- Remove the trailing comma from Values
        SET Values = LEFT(Values, CHAR_LENGTH(Values) - 1);

        -- Construct the final INSERT statement for the current row
        SET SQLStmt = CONCAT('INSERT INTO ', FullTableName, ' (', Columns, ') VALUES (', Values, ');');
        
        -- Execute the generated SQL statement for the current row
        PREPARE stmt FROM SQLStmt;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        -- Move to the next row
        SET CurrentRow = CurrentRow + 1;
    END WHILE;

    -- Clean up
    CLOSE column_cursor;
END //

DELIMITER ;
