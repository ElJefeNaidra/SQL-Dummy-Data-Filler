DELIMITER //

CREATE PROCEDURE GenerateOtherTypes(
    IN DataType VARCHAR(50),             -- Data type to handle ('binary', 'char', 'decimal', 'time', etc.)
    IN BinaryLength INT,                 -- Length for binary/varbinary data
    IN CharLength INT,                   -- Length for char or varchar data
    OUT DecimalValue DECIMAL(19,4),      -- Random decimal value
    OUT BinaryValue VARBINARY(255),      -- Random binary value
    OUT CharValue VARCHAR(255),          -- Random char or varchar value
    OUT GeometryValue GEOMETRY,          -- Random geometry value (latitude, longitude)
    OUT TimeValue TIME,                  -- Random time value
    OUT FloatValue FLOAT,                -- Random float value
    OUT DateTimeValue DATETIME,          -- Random datetime value
    OUT DecimalSmallValue DECIMAL(10,4), -- Smaller random decimal value
    OUT NCharValue CHAR(100)             -- Random char value, default size 100
)
BEGIN
    DECLARE RandomString VARCHAR(255); -- To store generated random text

    -- Generate data based on DataType
    IF DataType = 'binary' OR DataType = 'varbinary' THEN
        IF BinaryLength IS NOT NULL THEN
            SET BinaryValue = RANDOM_BYTES(BinaryLength);
        END IF;
    ELSEIF DataType = 'char' THEN
        IF CharLength IS NOT NULL THEN
            SET CharValue = LEFT(REPEAT('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', CharLength DIV 2), CharLength);
        END IF;
    ELSEIF DataType = 'nchar' THEN
        IF CharLength IS NOT NULL THEN
            SET NCharValue = LEFT(REPEAT('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', CharLength DIV 2), CharLength);
        END IF;
    ELSEIF DataType = 'decimal' THEN
        SET DecimalValue = ROUND(RAND() * 10000, 2);
    ELSEIF DataType = 'decimal_small' THEN
        SET DecimalSmallValue = ROUND(RAND() * 2000, 2);
    ELSEIF DataType = 'float' THEN
        SET FloatValue = RAND() * 10000;
    ELSEIF DataType = 'geometry' THEN
        SET @Latitude = (RAND() * 180.0) - 90.0;
        SET @Longitude = (RAND() * 360.0) - 180.0;
        SET GeometryValue = ST_GeomFromText(CONCAT('POINT(', @Latitude, ' ', @Longitude, ')'));
    ELSEIF DataType = 'time' THEN
        SET TimeValue = SEC_TO_TIME(FLOOR(RAND() * 86400));
    ELSEIF DataType = 'datetime' THEN
        -- Generate a random datetime within a reasonable range
        SET DateTimeValue = DATE_ADD('2000-01-01', INTERVAL FLOOR(RAND() * 7300) DAY); -- 20-year range
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE GenerateRandomDateTime(
    IN DataType VARCHAR(50),             -- Data type to handle ('datetime' or 'date')
    IN MinDate DATETIME DEFAULT NULL,    -- Minimum date (NULL defaults based on DataType)
    IN MaxDate DATETIME DEFAULT NULL,    -- Maximum date (NULL defaults based on DataType)
    OUT RandomDateTime DATETIME          -- Output random datetime value
)
BEGIN
    DECLARE DaysRange INT;
    DECLARE RandomDays INT;
    DECLARE RandomHours INT;

    -- Set default values for MinDate and MaxDate based on DataType
    IF DataType = 'datetime' THEN
        SET MinDate = COALESCE(MinDate, '1753-01-01');
        SET MaxDate = COALESCE(MaxDate, '9999-12-31');
    ELSEIF DataType = 'date' THEN
        SET MinDate = COALESCE(CAST(MinDate AS DATE), '0001-01-01');
        SET MaxDate = COALESCE(CAST(MaxDate AS DATE), '9999-12-31');
    END IF;

    -- Calculate the range in days between MinDate and MaxDate
    SET DaysRange = DATEDIFF(MaxDate, MinDate);

    -- Generate a random number of days within the range
    SET RandomDays = FLOOR(RAND() * DaysRange);

    -- Generate a random number of hours (0 to 23) if the type is 'datetime'
    IF DataType = 'datetime' THEN
        SET RandomHours = FLOOR(RAND() * 24);
        SET RandomDateTime = DATE_ADD(DATE_ADD(MinDate, INTERVAL RandomDays DAY), INTERVAL RandomHours HOUR);
    ELSEIF DataType = 'date' THEN
        -- If the type is 'date', only add days
        SET RandomDateTime = DATE_ADD(MinDate, INTERVAL RandomDays DAY);
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE GenerateRandomDecimal(
    IN Precision INT,                   -- Total number of digits
    IN Scale INT,                       -- Number of digits after the decimal point
    OUT RandomDecimal DECIMAL(38, 18)    -- Output random decimal value (supports high precision)
)
BEGIN
    DECLARE MaxValue DECIMAL(38,18);

    -- Calculate the maximum value based on precision
    -- e.g., Precision 5 with Scale 2 would give a max of 999.99
    SET MaxValue = CAST(CONCAT(REPEAT('9', Precision - Scale), '.', REPEAT('9', Scale)) AS DECIMAL(38, 18));

    -- Generate a random decimal within the range [0, MaxValue]
    SET RandomDecimal = ROUND(RAND() * MaxValue, Scale);
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE GenerateRandomInt(
    IN DataType VARCHAR(50),   -- Accepts the data type (e.g., 'tinyint', 'smallint', 'int', 'bigint')
    OUT RandomInt BIGINT       -- Output random integer
)
BEGIN
    DECLARE MaxValue BIGINT;

    -- Set the maximum value based on the data type
    SET MaxValue = CASE 
        WHEN DataType = 'tinyint' THEN 255           -- Range for tinyint: 0 to 255
        WHEN DataType = 'smallint' THEN 32767        -- Range for smallint: -32768 to 32767
        WHEN DataType = 'mediumint' THEN 8388607     -- Range for mediumint: -8388608 to 8388607
        WHEN DataType = 'int' THEN 2147483647        -- Range for int: -2147483648 to 2147483647
        WHEN DataType = 'bigint' THEN 9223372036854775807 -- Range for bigint: -9223372036854775808 to 9223372036854775807
        ELSE 2147483647  -- Default to the int range if the type is unknown
    END;

    -- Generate a random integer within the range [0, MaxValue]
    SET RandomInt = FLOOR(RAND() * (MaxValue + 1));
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE GenerateRandomString(
    IN MinLength INT,
    IN MaxLength INT,
    IN RandomnessFactor INT,
    OUT RandomString VARCHAR(255)  -- Adjusted to VARCHAR(255) for MySQL
)
BEGIN
    DECLARE CharPool VARCHAR(100);
    DECLARE PoolLength INT;
    DECLARE Length INT DEFAULT FLOOR(RAND() * (MaxLength - MinLength + 1)) + MinLength;
    DECLARE Counter INT DEFAULT 0;

    -- Set character pool based on randomness factor, including spaces as default
    SET CharPool = CASE 
        WHEN RandomnessFactor = 1 THEN 'abcdefghijkmnopqrstuvwxyz '
        WHEN RandomnessFactor = 2 THEN 'abcdefghijkmnopqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ '
        WHEN RandomnessFactor = 3 THEN 'abcdefghijkmnopqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ23456789 '
        WHEN RandomnessFactor = 4 THEN 'abcdefghijkmnopqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ23456789.,-_!$@#%^&* '
        ELSE 'abcdefghijkmnopqrstuvwxyz '  -- Default to level 1 if out of range
    END;

    SET PoolLength = CHAR_LENGTH(CharPool);
    SET RandomString = '';

    -- Generate a random string of the specified length
    WHILE Counter < Length DO
        SET RandomString = CONCAT(RandomString, SUBSTRING(CharPool, FLOOR(RAND() * PoolLength) + 1, 1));
        SET Counter = Counter + 1;
    END WHILE;
END //

DELIMITER ;
