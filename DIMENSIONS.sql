-- PRODUCT_DIM Dimension
CREATE TABLE PRODUCT_DIM (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(40),
    CategoryName VARCHAR(15),
    CategoryID INT,
    FOREIGN KEY (CategoryID) REFERENCES Category(categoryId)
);

INSERT INTO PRODUCT_DIM (ProductID, ProductName, CategoryName, CategoryID)
SELECT
    p.productId,
    p.productName,
    c.categoryName,
    p.categoryId
FROM Product p
JOIN Category c ON p.categoryId = c.categoryId;

-- CATEGORY_DIM Dimension
CREATE TABLE CATEGORY_DIM (
    CategoryID INT PRIMARY KEY,
    CategoryName VARCHAR(15),
    Description TEXT
);

INSERT INTO CATEGORY_DIM (CategoryID, CategoryName, Description)
SELECT
    categoryId,
    categoryName,
    description
FROM Category;


    
-- DAY_DIM
CREATE TABLE DAY_DIM (
    Day INT PRIMARY KEY,
    Month INT,
    FOREIGN KEY (Month) REFERENCES MONTH_DIM(Month)
);

-- MONTH_DIM
CREATE TABLE MONTH_DIM (
    Month INT PRIMARY KEY,
    Year INT,
    FOREIGN KEY (Year) REFERENCES YEAR_DIM(Year)
);

-- YEAR_DIM
CREATE TABLE YEAR_DIM (
    Year INT PRIMARY KEY
);

-- DAY_DIM veri aktar
INSERT IGNORE INTO DAY_DIM (Day, Month)
SELECT DAY(orderDate), MONTH(orderDate)
FROM SalesOrder;

INSERT IGNORE INTO MONTH_DIM (Month, Year)
SELECT MONTH(orderDate), YEAR(orderDate) FROM SalesOrder;


INSERT INTO YEAR_DIM (Year)
SELECT DISTINCT YEAR(orderDate) FROM SalesOrder;



CREATE TABLE CUSTOMER_DIM (
    CustomerID INT PRIMARY KEY,
    CompanyName VARCHAR(40),
    ContactName VARCHAR(30),
    CustomerCity VARCHAR(15),
    CustomerCountry VARCHAR(15)
);
INSERT INTO CUSTOMER_DIM (CustomerID, CompanyName, ContactName, CustomerCity, CustomerCountry)
SELECT custId, companyName, contactName, city, country FROM Customer;

CREATE TABLE SUPPLIER_DIM (
    SupplierID INT PRIMARY KEY,
    CompanyName VARCHAR(40),
    ContactName VARCHAR(30),
    ContactTitle VARCHAR(30),
    SupplierCity VARCHAR(15),
    SupplierCountry VARCHAR(15)
);
INSERT INTO SUPPLIER_DIM (SupplierID, CompanyName, ContactName, ContactTitle, SupplierCity, SupplierCountry)
SELECT supplierId, companyName, contactName, contactTitle, city, country FROM Supplier;


-- EMPLOYEE_DIM tablosunu oluşturun
CREATE TABLE EMPLOYEE_DIM (
    EmployeeID INT,
    FirstName VARCHAR(10),
    LastName VARCHAR(20),
    EmployeeCity VARCHAR(15),
    EmployeeCountry VARCHAR(15),
    TerritoryID INT,
    UNIQUE KEY (EmployeeID) -- EmployeeID sütunu için benzersiz anahtar
);

-- Veri ekleyin
INSERT INTO EMPLOYEE_DIM (EmployeeID, FirstName, LastName, EmployeeCity, EmployeeCountry, TerritoryID)
SELECT e.employeeId, e.firstname, e.lastname, e.city, e.country, et.territoryId
FROM Employee e
JOIN (
    SELECT employeeId, MIN(territoryId) as territoryId
    FROM EmployeeTerritory
    GROUP BY employeeId
) et ON e.employeeId = et.employeeId;


CREATE TABLE TERRITORY_DIM (
    TerritoryID INT PRIMARY KEY
);



INSERT INTO TERRITORY_DIM (TerritoryID)
SELECT DISTINCT et.territoryId
FROM EmployeeTerritory et;


CREATE TABLE ORDER_FACT (
    CustomerID INT,
    ProductID INT,
    EmployeeID INT,
    SupplierID INT,
    Day INT,
    Month INT,
    Year INT,
    unitPrice DECIMAL(10,2),
    quantity SMALLINT,
    discount DECIMAL(10,2),
    shippedDate DATETIME,
    requiredDate DATETIME,
    PRIMARY KEY (CustomerID, ProductID, EmployeeID, SupplierID, Day, Month, Year),
    FOREIGN KEY (CustomerID) REFERENCES CUSTOMER_DIM(CustomerID),
    FOREIGN KEY (ProductID) REFERENCES PRODUCT_DIM(ProductID),
    FOREIGN KEY (EmployeeID) REFERENCES EMPLOYEE_DIM(EmployeeID),
    FOREIGN KEY (SupplierID) REFERENCES SUPPLIER_DIM(SupplierID),
    FOREIGN KEY (Day) REFERENCES DAY_DIM(Day),
	FOREIGN KEY (Month) REFERENCES MONTH_DIM(Month),
    FOREIGN KEY (Year) REFERENCES YEAR_DIM(Year)
);

INSERT INTO ORDER_FACT (
    CustomerID,
    ProductID,
    EmployeeID,
    SupplierID,
    Day,
    Month,
    Year,
    unitPrice,
    quantity,
    discount,
    shippedDate,
    requiredDate
)
SELECT
    c.CustomerID,
    p.ProductID,
    e.EmployeeID,
    so.shipperid AS SupplierID, -- Değişiklik burada
    d.Day,
    m.Month,
    y.Year,
    od.unitPrice,
    od.quantity,
    od.discount,
    so.shippedDate,
    so.requiredDate
FROM
    OrderDetail od
JOIN
    SalesOrder so ON od.orderId = so.orderId
JOIN
    Customer_DIM c ON so.custId = c.CustomerID
JOIN
    Product_DIM p ON od.productId = p.ProductID
JOIN
    Employee_DIM e ON so.employeeId = e.EmployeeID
JOIN
    Supplier_DIM s ON so.shipperid = s.SupplierID -- Değişiklik burada
JOIN
    DAY_DIM d ON DAY(so.orderDate) = d.Day AND MONTH(so.orderDate) = d.Month
JOIN
    MONTH_DIM m ON MONTH(so.orderDate) = m.Month AND YEAR(so.orderDate) = m.Year
JOIN
    YEAR_DIM y ON YEAR(so.orderDate) = y.Year;

-- What are the most ordered products?
SELECT
    ProductID,
    COUNT(*) AS OrderCount
FROM
    ORDER_FACT
GROUP BY
    ProductID
ORDER BY
    OrderCount DESC
LIMIT 10; 

-- what are the least ordered products?
SELECT
    ProductID,
    COUNT(*) AS OrderCount
FROM
    ORDER_FACT
GROUP BY
    ProductID
ORDER BY
    OrderCount ASC
LIMIT 10; 

-- What is the product category with the most orders?
SELECT
    pd.CategoryName,
    COUNT(*) AS OrderCount
FROM
    ORDER_FACT o
JOIN
    PRODUCT_DIM pd ON o.ProductID = pd.ProductID
GROUP BY
    pd.CategoryName
ORDER BY
    OrderCount DESC
LIMIT 5;

-- When is the best time for product discounts?
SELECT
    EXTRACT(MONTH FROM MAX(o.requiredDate)) AS Month,
    COUNT(*) AS OrderCount
FROM
    ORDER_FACT o
GROUP BY
    Month
ORDER BY
    OrderCount DESC;

-- What is the most ordered product quantity?
SELECT
    ProductID,
    SUM(quantity) AS TotalQuantity
FROM
    ORDER_FACT
GROUP BY
    ProductID
ORDER BY
    TotalQuantity DESC
LIMIT 5;

-- What are the cities, and countries where the customers who place the most orders live?
SELECT
    c.CustomerID,
    c.CustomerCity,
    c.CustomerCountry,
    COUNT(*) AS OrderCount
FROM
    CUSTOMER_DIM c
JOIN
    ORDER_FACT o ON c.CustomerID = o.CustomerID
GROUP BY
    c.CustomerID, c.CustomerCity, c.CustomerCountry
ORDER BY
    OrderCount DESC
LIMIT 10;

-- Who are the employees who sell the most number of orders?
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    COUNT(*) AS TotalOrdersSold
FROM
    ORDER_FACT o
JOIN
    EMPLOYEE_DIM e ON o.EmployeeID = e.EmployeeID
GROUP BY
    e.EmployeeID, e.FirstName, e.LastName
ORDER BY
    TotalOrdersSold DESC
LIMIT 10;

-- Who are the supplier of the products with the most orders?
SELECT
    s.SupplierID,
    s.CompanyName,
    COUNT(*) AS TotalOrders
FROM
    ORDER_FACT o
JOIN
    SUPPLIER_DIM s ON o.SupplierID = s.SupplierID
GROUP BY
    s.SupplierID, s.CompanyName
ORDER BY
    TotalOrders DESC
LIMIT 10;

-- Which product has the most difference between requiredDate and shippedDate?
SELECT
    p.ProductID,
    p.ProductName,
    DATEDIFF(o.shippedDate, o.requiredDate) AS DateDifference
FROM
    ORDER_FACT o
JOIN
    PRODUCT_DIM p ON o.ProductID = p.ProductID
ORDER BY
    DateDifference ASC
LIMIT 1;

-- When is the most ordered date?
SELECT
    o.Day,
    o.Month,
    o.Year,
    COUNT(*) AS OrderCount
FROM
    ORDER_FACT o
GROUP BY
    o.Day, o.Month, o.Year
ORDER BY
    OrderCount DESC
LIMIT 10;

-- What is the maximum number of units of a product a user can order?
SELECT
    ProductID,
    MAX(quantity) AS MaxOrderQuantity
FROM
    ORDER_FACT
GROUP BY
    ProductID;

    
    
-- In which territory did the employers make the most sales?
SELECT
    t.TerritoryID,
    COUNT(o.CustomerID) AS SalesCount,
    e.FirstName,
    e.LastName
FROM
    ORDER_FACT o
JOIN
    EMPLOYEE_DIM e ON o.EmployeeID = e.EmployeeID
JOIN
    TERRITORY_DIM t ON e.TerritoryID = t.TerritoryID
GROUP BY
    t.TerritoryID, e.FirstName, e.LastName
ORDER BY
    SalesCount DESC;
    
-- what is the price of the most ordered products?
SELECT
    p.ProductID,
    p.ProductName,
    MAX(o.unitPrice) AS MaxUnitPrice
FROM
    ORDER_FACT o
JOIN
    PRODUCT_DIM p ON o.ProductID = p.ProductID
GROUP BY
    p.ProductID, p.ProductName
ORDER BY
    MaxUnitPrice DESC
LIMIT 5;

-- In which city, country and territory is your employee with the fewest orders?
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    e.EmployeeCity,
    e.EmployeeCountry,
    t.TerritoryID,
    COUNT(o.EmployeeID) AS OrderCount
FROM
    ORDER_FACT o
JOIN
    EMPLOYEE_DIM e ON o.EmployeeID = e.EmployeeID
JOIN
    TERRITORY_DIM t ON e.TerritoryID = t.TerritoryID
GROUP BY
    e.EmployeeID, e.FirstName, e.LastName, e.EmployeeCity, e.EmployeeCountry, t.TerritoryID
ORDER BY
    OrderCount ASC
LIMIT 3;






