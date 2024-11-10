SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GenerateOtherTypes]
    @DataType NVARCHAR(50),             -- Data type to handle ('binary', 'char', 'money', 'geography', 'time', 'nvarchar', etc.)
    @BinaryLength INT = NULL,           -- Length for binary/varbinary data
    @CharLength INT = NULL,             -- Length for char or nchar data
    @MoneyValue MONEY OUTPUT,           -- Random money value
    @BinaryValue VARBINARY(MAX) OUTPUT, -- Random binary or varbinary value
    @CharValue NVARCHAR(MAX) OUTPUT,    -- Random char or nchar value
    @GeographyValue GEOGRAPHY OUTPUT,   -- Random geography value (latitude, longitude)
    @TimeValue TIME OUTPUT,             -- Random time value
    @RealValue REAL OUTPUT,             -- Random real value
    @SmallDateTimeValue SMALLDATETIME OUTPUT, -- Random smalldatetime value
    @SmallMoneyValue SMALLMONEY OUTPUT, -- Random smallmoney value
    @NCharValue NCHAR(100) OUTPUT       -- Random nchar value, default size 100
AS
BEGIN
    DECLARE @RandomString NVARCHAR(MAX); -- To store generated random text

    -- Generate data based on @DataType
    IF @DataType = 'binary' OR @DataType = 'varbinary'
    BEGIN
        -- Generate a random binary or varbinary value
        IF @BinaryLength IS NOT NULL
        BEGIN
            DECLARE @BinaryString NVARCHAR(MAX) = '';
            WHILE LEN(@BinaryString) < @BinaryLength * 2
            BEGIN
                SET @BinaryString += RIGHT(CONVERT(NVARCHAR(2), CHECKSUM(NEWID())), 2);
            END
            SET @BinaryValue = CONVERT(VARBINARY(MAX), '0x' + LEFT(@BinaryString, @BinaryLength * 2), 1);
        END
    END
    ELSE IF @DataType = 'char'
    BEGIN
        -- Generate a random char value of specified length
        IF @CharLength IS NOT NULL
        BEGIN
            SET @CharValue = LEFT(REPLICATE('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', @CharLength / 2), @CharLength);
        END
    END
    ELSE IF @DataType = 'nchar'
    BEGIN
        -- Generate a random nchar value of specified length
        IF @CharLength IS NOT NULL
        BEGIN
            SET @NCharValue = LEFT(REPLICATE(N'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', @CharLength / 2), @CharLength);
        END
    END
    ELSE IF @DataType = 'money'
    BEGIN
        -- Generate a random money value
        SET @MoneyValue = ROUND(CAST(ABS(CHECKSUM(NEWID())) % 1000000 AS MONEY) / 100, 2); -- Range up to 10,000.00
    END
    ELSE IF @DataType = 'smallmoney'
    BEGIN
        -- Generate a random smallmoney value
        SET @SmallMoneyValue = ROUND(CAST(ABS(CHECKSUM(NEWID())) % 200000 AS SMALLMONEY) / 100, 2); -- Range up to 2,000.00
    END
    ELSE IF @DataType = 'real'
    BEGIN
        -- Generate a random real value
        SET @RealValue = CAST(RAND() * 10000 AS REAL); -- Range up to 10,000.0
    END
    ELSE IF @DataType = 'geography'
    BEGIN
        -- Generate a random geography point (latitude and longitude)
        DECLARE @Latitude FLOAT = (RAND() * 180.0) - 90.0;
        DECLARE @Longitude FLOAT = (RAND() * 360.0) - 180.0;
        SET @GeographyValue = GEOGRAPHY::Point(@Latitude, @Longitude, 4326);
    END
    ELSE IF @DataType = 'time'
    BEGIN
        -- Generate a random time value
        DECLARE @RandomSeconds INT = ABS(CHECKSUM(NEWID())) % 86400; -- Number of seconds in a day
        SET @TimeValue = DATEADD(SECOND, @RandomSeconds, CAST('00:00:00' AS TIME));
    END
    ELSE IF @DataType = 'smalldatetime'
    BEGIN
        -- Generate a random smalldatetime value within the range of smalldatetime
        DECLARE @DaysRange INT = DATEDIFF(DAY, '1900-01-01', '2079-06-06'); -- Range of smalldatetime
        DECLARE @RandomDays INT = ABS(CHECKSUM(NEWID())) % @DaysRange;
        SET @SmallDateTimeValue = DATEADD(DAY, @RandomDays, '1900-01-01');
    END
END;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GenerateRandomDateTime]
    @DataType NVARCHAR(50) = 'datetime',  -- Data type to handle ('datetime', 'datetime2', or 'date')
    @MinDate DATETIME2 = NULL,            -- Minimum date (NULL defaults based on @DataType)
    @MaxDate DATETIME2 = NULL,            -- Maximum date (NULL defaults based on @DataType)
    @RandomDateTime DATETIME2 OUTPUT      -- Output random datetime value
AS
BEGIN
    DECLARE @DaysRange BIGINT;
    DECLARE @RandomDays BIGINT;
    DECLARE @RandomHours INT;

    -- Set default values for @MinDate and @MaxDate based on @DataType
    IF @DataType = 'datetime'
    BEGIN
        SET @MinDate = ISNULL(@MinDate, '1753-01-01');
        SET @MaxDate = ISNULL(@MaxDate, '9999-12-31');
    END
    ELSE IF @DataType = 'datetime2'
    BEGIN
        SET @MinDate = ISNULL(@MinDate, '0001-01-01');
        SET @MaxDate = ISNULL(@MaxDate, '9999-12-31');
    END
    ELSE IF @DataType = 'date'
    BEGIN
        SET @MinDate = ISNULL(CAST(@MinDate AS DATE), '0001-01-01');
        SET @MaxDate = ISNULL(CAST(@MaxDate AS DATE), '9999-12-31');
    END

    -- Calculate the range in days between the min and max dates
    SET @DaysRange = DATEDIFF(DAY, @MinDate, @MaxDate);

    -- Generate a random number of days within the range
    SET @RandomDays = ABS(CHECKSUM(NEWID())) % @DaysRange;

    -- Generate a random number of hours (0 to 23) if the type is not 'date'
    IF @DataType IN ('datetime', 'datetime2')
    BEGIN
        SET @RandomHours = ABS(CHECKSUM(NEWID())) % 24;
        SET @RandomDateTime = DATEADD(HOUR, @RandomHours, DATEADD(DAY, @RandomDays, @MinDate));

        -- Truncate @RandomDateTime if @DataType is 'datetime' to match 'datetime' precision
        IF @DataType = 'datetime'
            SET @RandomDateTime = CONVERT(DATETIME, @RandomDateTime);
    END
    ELSE IF @DataType = 'date'
    BEGIN
        -- If the type is 'date', only add days
        SET @RandomDateTime = DATEADD(DAY, @RandomDays, @MinDate);
    END
END;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GenerateRandomDecimal]
    @Precision INT,       -- Total number of digits
    @Scale INT,           -- Number of digits after the decimal point
    @RandomDecimal DECIMAL(38, 18) OUTPUT -- Output random decimal value (supports high precision)
AS
BEGIN
    DECLARE @MaxValue DECIMAL(38, 18);

    -- Calculate the maximum value based on precision
    -- e.g., Precision 5 would give a max of 99999 (for 5 digits)
    SET @MaxValue = CAST(REPLICATE('9', @Precision - @Scale) + '.' + REPLICATE('9', @Scale) AS DECIMAL(38, 18));

    -- Generate a random decimal within the range [0, @MaxValue]
    SET @RandomDecimal = (ABS(CHECKSUM(NEWID())) % (@MaxValue + 1)) * POWER(CAST(0.1 AS DECIMAL(38, 18)), @Scale);
END;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GenerateRandomInt]
    @DataType NVARCHAR(50),  -- Accepts the data type (e.g., 'tinyint', 'smallint', 'int', 'bigint')
    @RandomInt BIGINT OUTPUT
AS
BEGIN
    DECLARE @MaxValue BIGINT;

    -- Set the maximum value based on the data type
    SET @MaxValue = CASE 
        WHEN @DataType = 'tinyint' THEN 255         -- Range for tinyint: 0 to 255
        WHEN @DataType = 'smallint' THEN 32767      -- Range for smallint: -32768 to 32767
        WHEN @DataType = 'int' THEN 2147483647      -- Range for int: -2147483648 to 2147483647
        WHEN @DataType = 'bigint' THEN 9223372036854775807 -- Range for bigint: -9223372036854775808 to 9223372036854775807
        ELSE 2147483647  -- Default to the int range if the type is unknown
    END;

    -- Generate a random integer within the range [0, @MaxValue] 
    -- Use @MaxValue directly for bigint to prevent overflow
    SET @RandomInt = ABS(CHECKSUM(NEWID())) % (CASE WHEN @DataType = 'bigint' THEN @MaxValue ELSE @MaxValue + 1 END);
END;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GenerateRandomString]
    @MinLength INT,
    @MaxLength INT,
    @RandomnessFactor INT,
    @RandomString NVARCHAR(MAX) OUTPUT
AS
BEGIN
    DECLARE @CharPool NVARCHAR(100);
    DECLARE @PoolLength INT;

    -- Set character pool based on randomness factor, including spaces as default
    SET @CharPool = CASE 
        WHEN @RandomnessFactor = 1 THEN 'abcdefghijkmnopqrstuvwxyz '
        WHEN @RandomnessFactor = 2 THEN 'abcdefghijkmnopqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ '
        WHEN @RandomnessFactor = 3 THEN 'abcdefghijkmnopqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ23456789 '
        WHEN @RandomnessFactor = 4 THEN 'abcdefghijkmnopqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ23456789.,-_!$@#%^&* '
        ELSE 'abcdefghijkmnopqrstuvwxyz '  -- Default to level 1 if out of range
    END;

    SET @PoolLength = LEN(@CharPool);
    DECLARE @Length INT = FLOOR(RAND(CHECKSUM(NEWID())) * (@MaxLength - @MinLength + 1)) + @MinLength;
    DECLARE @Counter INT = 0;
    SET @RandomString = '';

    WHILE @Counter < @Length
    BEGIN
        SET @RandomString = @RandomString + SUBSTRING(@CharPool, ABS(CHECKSUM(NEWID())) % @PoolLength + 1, 1);
        SET @Counter = @Counter + 1;
    END
END;
