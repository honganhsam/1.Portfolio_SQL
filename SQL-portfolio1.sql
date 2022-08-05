/* Database AdventureWorkDW2019 - Microsoft
https://docs.microsoft.com/en-us/sql/samples/adventureworks-install-configure?view=sql-server-ver16&tabs=ssms
*/

/*Task 1: From database, display ProductKey, EnglishProductName, Total OrderQuantity (caculate from OrderQuantity in Quarter 3 of 2013) of product sold Customers/Resellers live in London for each Sales type ('Resell' and 'Internet') */

-- Tạo CTE với cả thông tin của InternetSales và ResellerSales
WITH FactSales as
    (
    SELECT ProductKey
           , OrderQuantity
           , OrderDate
           , 'Internet'  Order_type
           , GeographyKey
    FROM FactInternetsales as Internet_Sales
             LEFT JOIN DimCustomer as Dcus
                       ON Internet_Sales.CustomerKey = Dcus.CustomerKey
    UNION
    SELECT ProductKey
           , OrderQuantity
           , OrderDate
           , 'Resell'  Order_type
           , GeographyKey
    FROM FactResellerSales AS Reseller_Sales
             LEFT JOIN DimReseller as Drsl
                       On Reseller_Sales.ResellerKey = Drsl.ResellerKey
    )
-- Dùng CTE kết hợp các tables khác và conditions
SELECT FactSales.ProductKey
       , EnglishProductName
       , Sum(OrderQuantity) as Total_Orderquantity
       , Order_type
FROM FactSales
         LEFT JOIN DimProduct as Dp
                   ON FactSales.ProductKey = Dp.ProductKey
         LEFT JOIN DimGeography as Dgeo
                   On FactSales.GeographyKey = Dgeo.GeographyKey
WHERE Datepart(Quarter, OrderDate) = 3
  and Year(OrderDate) = 2013
  and City = 'London'
GROUP BY EnglishProductName
        , Order_type
        , FactSales.ProductKey;

  
/*Task 2: From database, retrieve total SalesAmount monthly of internet_sales and reseller_sales */

-- Tạo 2 CTE lấy thông tin từ InternetSales và ResellerSales theo month, year
WITH 
InternetSales As 
    (
    SELECT MONTH(OrderDate) thang
            , YEAR(OrderDate) nam
            , Sum(SalesAmount) as Internet_sale
    FROM FactInternetSales
    GROUP BY MONTH(OrderDate)
            ,YEAR(OrderDate)
    ),

ResellerSales As
    (
    SELECT MONTH(OrderDate) thang
            , YEAR(OrderDate) nam
            , Sum(SalesAmount) as Reseller_sale
    FROM FactResellerSales
    GROUP BY MONTH(OrderDate)
            ,YEAR(OrderDate)
    )
-- FULL JOIN 2 CTE theo month, year
SELECT ISNULL(Rsl.thang, Isl.thang) thang
        , ISNULL(Rsl.nam, Isl.nam) nam
        , Sum(Internet_sale) doanh_thu_internet
        , Sum(Reseller_sale) doanh_thu_reseller
FROM InternetSales Isl 
    FULL OUTER JOIN ResellerSales Rsl
            ON Isl.thang = Rsl.thang 
            and Isl.nam = Rsl.nam
GROUP BY ISNULL(Rsl.thang, Isl.thang)
        , ISNULL(Rsl.nam, Isl.nam);

/* Task 3: From FactInternetSales table, write a query that retrieves the following data:  
 Total orders each month of the year (using OrderDate) 
 Total orders each month of the year (using ShipDate) 
 Total orders orders each month of the year (using DueDate) */

--Tạo 3 CTE tính number of order theo từng yêu cầu
WITH 
Ordertable AS
    (
    SELECT Month(OrderDate) thang
            , Year(OrderDate) nam
            , COUNT(distinct SalesOrderNumber) as No_of_orders
    FROM FactInternetSales
    GROUP BY Month(OrderDate)
            , Year(OrderDate)
    ),

Shiptable AS
    (
    SELECT Month(ShipDate) thang
            , Year(ShipDate) nam
            , COUNT(distinct SalesOrderNumber) as No_of_invoices
    FROM FactInternetSales
    GROUP BY Month(ShipDate)
            , Year(ShipDate)
    ),

Duetable AS
    (
    SELECT Month(DueDate) thang
            , Year(DueDate) nam
            , COUNT(distinct SalesOrderNumber) as No_of_expired
    FROM FactInternetSales
    GROUP BY Month(DueDate)
            , Year(DueDate)
    )

-- FULL JOIN 3 CTE
SELECT COALESCE(O.thang, S.thang, D.thang) thang
        , COALESCE(O.nam, S.nam, D.nam) nam
        , No_of_orders as 'Number of orders'
        , No_of_invoices as 'Number of shipped invoices'
        , No_of_expired as 'Number of expired orders'
FROM Ordertable O
    FULL OUTER JOIN Shiptable S
            ON O.thang = S.thang 
            and O.nam = S.nam 
    FULL OUTER JOIN Duetable D
            ON O.thang = D.thang 
            and O.nam = D.nam
ORDER BY thang, nam;

/* Task 4
Từ bảng DimProduct, DimSalesTerritory và FactInternetSales,
hãy tính toán % tỷ trọng doanh thu của từng sản phẩm (đặt tên là PercentofTotaInCountry)
trong Tổng doanh thu của mỗi quốc gia. Kết quả trả về gồm có các thông tin sau:
SalesTerritoryCountry
ProductKey
EnglishProductName
InternetTotalSales
PercentofTotaInCountry (định dạng %)
*/
-- create CTE lấy thông tin cần thiết từ 3 tables
WITH tonghop AS
    (
    SELECT SalesTerritoryCountry
            , F.ProductKey
            , EnglishProductName
            , SUM(SalesAmount) InternetTotalSales
    FROM FactInternetSales F
        LEFT JOIN DimProduct Dp 
                ON F.ProductKey = Dp.ProductKey
        LEFT JOIN DimSalesTerritory Dst 
                ON F.SalesTerritoryKey = Dst.SalesTerritoryKey
    GROUP BY SalesTerritoryCountry
            , F.ProductKey
            , EnglishProductName
    )

-- tính phần trăm dựa theo total tính từ subquery
SELECT SalesTerritoryCountry
        , ProductKey
        , EnglishProductName
        , InternetTotalSales
        , InternetTotalSales*100/ 
        (
        SELECT SUM(InternetTotalSales)
        FROM tonghop A
        WHERE A.SalesTerritoryCountry =B.SalesTerritoryCountry
        ) as PercentofTotaInCountry
FROM tonghop B
ORDER BY SalesTerritoryCountry, ProductKey;

/* Task 5
Từ bảng FactInternetSales, và DimCustomer,
hãy truy vấn ra danh sách top 3 khách hàng có tổng doanh thu tháng (đặt tên là CustomerMonthAmount) cao nhất trong hệ thống theo mỗi tháng.
Kết quả trả về gồm có các thông tin sau:
OrderYear
OrderMonth
CustomerKey
CustomerFullName (kết hợp từ FirstName, MiddleName, LastName)
CustomerMonthAmount
*/

-- Create CTE including các thông tin cần thiết từ 2 bảng, đánh ranking
WITH CustomerbyMonth as 
    (
    SELECT YEAR(OrderDate) as OrderYear
            , MONTH(OrderDate) as OrderMonth
            , DC.CustomerKey
            , CONCAT_WS(' ', FirstName, MiddleName, LastName) as CustomerFullname
            , SUM(SalesAmount) as  CustomerMonthAmount
            , RANK() OVER (PARTITION BY YEAR(OrderDate), MONTH(OrderDate) ORDER BY SUM(SalesAmount) DESC) AS CustomerRank
    FROM FactInternetSales AS Fis
             LEFT JOIN DimCustomer DC
                       ON Fis.CustomerKey = DC.CustomerKey
    GROUP BY DC.CustomerKey
           , CONCAT_WS(' ', FirstName, MiddleName, LastName)
           , YEAR(OrderDate)
           , MONTH(OrderDate)
    )

-- lấy ra data theo condition
SELECT OrderYear
     , OrderMonth
     , CustomerKey
     , CustomerFullname
     , CustomerMonthAmount
FROM CustomerbyMonth
WHERE CustomerRank <= 3
ORDER BY OrderYear, OrderMonth, CustomerKey;

/* Task 6
Từ bảng FactInternetSales hãy tính toán % tăng trưởng doanh thu (đặt tên là PercentSalesGrowth)
so với cùng kỳ năm trước (ví dụ: Tháng 11 năm 2012 thì so sánh với tháng 11 năm 2011). Kết quả trả về gồm có các thông tin sau:
OrderYear
OrderMonth
InternetMonthAmount
InternetMonthAmount_LastYear
PercentSalesGrowth
*/

WITH
-- Create CTE based on data forom from FactInternetSales
InternetSales AS
    (
    SELECT Year(OrderDate) OrderYear
            , Month(OrderDate) OrderMonth
            , SUM(SalesAmount) InternetMonthAmount
    FROM FactInternetSales
    GROUP BY Year(OrderDate)
            , Month(OrderDate)
    ),
-- tạo CTE từ subquery để so sánh 
InternetSales_ss as
    (
    SELECT OrderYear
            , OrderMonth
            , InternetMonthAmount
            ,(
            SELECT InternetMonthAmount
            FROM InternetSales A 
            WHERE A.OrderMonth = B.OrderMonth 
                and A.OrderYear = B.OrderYear - 1
            ) as InternetSalesAmount_LastYear
    FROM InternetSales B
    )
-- Tính toán và lấy ra thông tin
SELECT OrderYear
        , OrderMonth
        , InternetMonthAmount
        , InternetSalesAmount_LastYear
        , (InternetMonthAmount-InternetSalesAmount_LastYear)*100/ InternetMonthAmount as PercentSalesGrowth
FROM subtable2
ORDER BY OrderYear, OrderMonth;
