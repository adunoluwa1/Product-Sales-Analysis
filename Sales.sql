/*          DATABASE CREATION           */
    -- IF NOT EXISTS (SELECT Name FROM sys.databases WHERE Name = 'Product_Database')
    -- CREATE DATABASE Product_Database
--
/*          DATA MANIPLULATION          */
    -- TABLE CREATION
        -- SELECT 
        -- CONVERT(INT,Order_ID) [Order_ID],
        -- Product,
        -- CONVERT(INT,Quantity_Ordered) [Quantity],
        -- CONVERT(FLOAT,Price_Each) [Unit_Price],
        -- PARSE(Order_Date AS datetime USING 'EN_US') Date,
        -- Purchase_Address
        -- INTO Sales
        -- FROM     
            --  (SELECT * 
            --  FROM Sales_April_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_August_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_December_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_February_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_January_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_July_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_June_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_March_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_May_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_November_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_October_2019
            --  UNION ALL
            --  SELECT * 
            --  FROM Sales_September_2019) Q
        -- WHERE Order_ID IS NOT NULL AND Order_ID <> 'Order_ID'
            -- AND Product IS NOT NULL AND Product <> 'Product'
            -- AND Quantity_Ordered IS NOT NULL AND Quantity_Ordered <> 'Quantity_Ordered'
            -- AND Price_Each IS NOT NULL AND Price_Each <> 'Price_Each'
            -- AND Order_Date IS NOT NULL AND Order_Date <> 'Order_Date'
            -- AND Purchase_Address IS NOT NULL
    -- 
    -- VIEW CREATION
        -- CREATE OR ALTER VIEW VW_Sales AS
        -- SELECT Order_ID, Product, Quantity, Unit_Price, 
            --  CONVERT(DEC(10,2), Quantity * Unit_Price) [Revenue],-- Date,
            --  PARSE(FORMAT([Date],'d', 'en-GB') AS DATE USING 'AR-LB') [Date],
            --  FORMAT(Date, 'T', 'en-GB') [Time],
            --  SUBSTRING(Purchase_Address,0,CHARINDEX(',',Purchase_Address)) [Street Number],
            --  SUBSTRING(Purchase_Address, CHARINDEX(',',Purchase_Address)+2, CHARINDEX(',',Purchase_Address, CHARINDEX(',',Purchase_Address)+2) - CHARINDEX(',',Purchase_Address) - 2 ) [City],
            --  SUBSTRING(Purchase_Address,CHARINDEX(',',Purchase_Address, CHARINDEX(',',Purchase_Address)+2)+2,2) [State],
            --  RIGHT(Purchase_Address, 5) [Zip Code]
        -- FROM Sales
--
/*          HIGH LEVEL ANALYSIS         */
    SELECT City, SUM(Revenue) [Revenue] 
    FROM VW_Sales
    GROUP BY City

    SELECT Product, SUM(Quantity) [Units Sold] 
    FROM VW_Sales
    GROUP BY Product
    ORDER BY [Units Sold] DESC

    SELECT CONCAT('Total Orders: ', COUNT(DISTINCT Order_ID)) [Orders] 
    FROM VW_Sales

    SELECT *--COUNT(DISTINCT Order_ID) [Orders] 
    FROM VW_Sales;

--
/*          STORED PROCEDURES           */
    -- High Level Analysis
        CREATE OR ALTER PROCEDURE sp_HighLevel_Analysis @segment NVARCHAR(50), @analysis NVARCHAR(50)
        AS
        BEGIN
            DECLARE @sql NVARCHAR(MAX)
            SET @sql = 'SELECT ' + @segment + ' [Category], 
                        SUM(' + @analysis + ') [' + @analysis +']
                        FROM vw_sales
                        GROUP BY ' + @segment +
                        ' ORDER BY SUM(' + @analysis + ') DESC'
            EXEC sp_executesql @sql
        END 
        GO;
    --
    -- Sales Analysis
        CREATE OR ALTER PROCEDURE sp_Sales_Analysis @segment NVARCHAR(50)
        AS
        BEGIN
            DECLARE @sql NVARCHAR(MAX)
            SET @sql = 'SELECT ' + @segment + ' [Category], 
                        CONCAT( ' + Quotename('$','''') + ',
                        SUM(Revenue)) [Revenue], 
                        SUM(Quantity) [Quantity],
                        COUNT(DISTINCT Order_ID) [Orders]
                        FROM vw_sales
                        GROUP BY ' + @segment +
                        ' ORDER BY SUM(Revenue) DESC'
            EXEC sp_executesql @sql
        END 
        GO;
    --
    -- Probability
        CREATE OR ALTER PROCEDURE sp_Probability @segment NVARCHAR(10)
        AS
        BEGIN 
            DECLARE @sql NVARCHAR(MAX)
            SET @sql = 'SELECT DISTINCT ' +  @segment + ' [Segment], 
                       CONVERT(DEC(10,2),
                       (SELECT COUNT(DISTINCT Order_ID) FROM VW_Sales vb WHERE vb.' + @segment + ' = va.' + @segment + ' ) * 100.0/
                       (SELECT COUNT(DISTINCT Order_ID) FROM VW_Sales)) [Probability]
                       FROM VW_Sales va
                       ORDER BY [Probability] DESC'
            EXEC sp_executesql @sql
        END
        GO
--
/*          EXECUTING QUERIES           */
    -- What was the best Year for sales? How much was earned that Year?
        EXEC sp_Sales_Analysis 'DATENAME(YYYY,date)'
    --
    -- What was the best month for sales? How much was earned that month?
        EXEC sp_Sales_Analysis 'DATENAME(MM,date)'
    --
    -- What City had the highest number of sales?
        EXEC sp_Sales_Analysis 'City'
    --
    -- What time should we display adverts to maximize likelihood of customer's buying product?
        EXEC sp_Sales_Analysis 'DATENAME(hh,time)';
    --
    -- What products are most often sold together?
        WITH CTE_Sales AS
         (SELECT Products, COUNT(Orders) Frequency
         FROM
             (SELECT Order_ID Orders, STRING_AGG([Product],', ') 
              WITHIN GROUP(ORDER BY Product) Products
              FROM VW_Sales
              GROUP BY Order_ID
              HAVING COUNT(Order_ID) > 1) Q
         GROUP BY Products)
        --
        SELECT Products, Frequency
        FROM
            (SELECT *, DENSE_RANK() OVER(ORDER BY Frequency DESC) Rank
            FROM CTE_Sales) Q
        WHERE Rank = 1
    --
    -- What product sold the most? Why do you think it sold the most? 
        EXEC sp_HighLevel_Analysis 'Product', 'Quantity'
    --
    -- Probability Questions
        -- How much probability for next people will ordered USB-C Charging Cable?
        -- How much probability for next people will ordered iPhone?
        -- How much probability for next people will ordered Google Phone?
        -- How much probability other peoples will ordered Wired Headphones?
        EXEC sp_Probability 'Product'
    --
--
SELECT * FROM VW_Sales