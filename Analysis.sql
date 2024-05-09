USE [Customer Segmentation]
SELECT * FROM ['Sales Orders Sheet$']
-- to get insights for rfm analysis we need last order date, how frequently customers order and what amont they roughly order.

-- How many total records are there?

SELECT COUNT(*) AS Total_records
FROM ['Sales Orders Sheet$']
--WHERE _CustomerID = 31;

-- How many distinct customers are there?

SELECT COUNT(DISTINCT _CustomerID) AS No_of_Customers
FROM ['Sales Orders Sheet$'];
  
-- Calculate recency, frequency and Monetary values to get rfm 

SELECT
    _CustomerID,
    MAX(OrderDate) AS Last_order_date,
    (SELECT MAX(OrderDate) FROM ['Sales Orders Sheet$'] ) AS  Max_Transaction_Date,
    DATEDIFF(DD,MAX(OrderDate),(SELECT MAX(OrderDate) FROM ['Sales Orders Sheet$'])) AS Recency,
    COUNT(OrderNumber) AS Frequency,
    CAST(Sum([Unit Price] - ([Unit Price]*[Discount Applied] - [Unit Cost])) AS DECIMAL(16,2)) AS  Monetary
FROM ['Sales Orders Sheet$']
GROUP BY _CustomerID
ORDER By Frequency DESC;

--Use CTE and ntile window functions to create bins (Currently trial using 5)

DROP TABLE IF EXISTS CS;--create a table to store these values 
WITH RFM AS
(SELECT
    _CustomerID,
    DATEDIFF(DD,MAX(OrderDate),(SELECT MAX(OrderDate) FROM ['Sales Orders Sheet$'])) AS Recency,
    COUNT(OrderNumber) AS Frequency,
    CAST(SUM([Unit Price] - ([Unit Price]*[Discount Applied] - [Unit Cost])) AS DECIMAL(16,2)) AS  Monetary
FROM ['Sales Orders Sheet$']
GROUP BY _CustomerID
),
rfm_results AS (
	SELECT *,
			NTILE(5) OVER (ORDER BY Recency DESC) rfm_recency,-- high value because this means customer visted recntly
			NTILE(5) OVER (ORDER BY Frequency ASC) rfm_frequency,-- less frequency score means visited less frequently
			NTILE(5) OVER (ORDER BY Monetary ASC) rfm_monetary -- less monetory less money they spent
	FROM RFM 
)

SELECT 
    *, CAST(rfm_recency AS VARCHAR)+CAST(rfm_frequency AS VARCHAR)+CAST(rfm_monetary AS VARCHAR) rfm_score,
	rfm_recency+rfm_frequency+rfm_monetary as rfm_combined
    
INTO CS
FROM rfm_results

SELECT * FROM CS;

-- We can create segments based on differetnt crierias like score or weighted score or categorising individually

DROP TABLE IF EXISTS Analysis_cs;

WITH segments as
(
SELECT _CustomerID, rfm_recency,rfm_frequency,rfm_monetary,rfm_score,
		CASE
				WHEN rfm_combined >= 13  THEN 'Champion Customers'
				WHEN (rfm_combined >= 9 AND rfm_combined < 13) THEN 'Potential Loyalists'
				WHEN (rfm_combined >= 6 AND rfm_combined < 9) THEN 'At Risk Customers'
				WHEN (rfm_combined >= 4 AND rfm_combined <6) THEN 'Declining Customer'
				WHEN rfm_recency < 4 THEN 'Lost'
				END rfm_segment
FROM CS)
SELECT * INTO Analysis_cs FROM segments;

-- Get the names of the customer by using joins so as to target them based on their segment
SELECT c.[Customer Names], cs.rfm_segment
FROM Analysis_cs cs
inner join ['Customers Sheet$'] c 
on cs._CustomerID = c._CustomerID;

-- Analysis to see what channel is the most profitable among our top customer segments
SELECT s.[Sales Channel],COUNT(s.[Sales Channel]) AS Total 
FROM ['Sales Orders Sheet$'] s
LEFT JOIN Analysis_cs cs
On s._CustomerID = cs._CustomerID
WHERE cs.rfm_segment in ('Champion Customers','Potential Loyalists')
GROUP BY s.[Sales Channel]
ORDER BY Total DESC;


-- Which cities have the maximum number of customers at risk. We can do same for all the segments
SELECT TOP 10 sl.[City Name] ,COUNT(sl.[City Name]) As 'Total Customers At Risk'
FROM ['Store Locations Sheet$'] sl
LEFT JOIN ['Sales Orders Sheet$'] so
ON sl._StoreID = so._StoreID
LEFT JOIN Analysis_cs cs
ON so._CustomerID = cs._CustomerID
WHERE cs.rfm_segment = 'At Risk Customers'
GROUP BY sl.[City Name]
ORDER BY 'Total Customers At Risk' DESC;



-- Finding our good and bad performing sales team

SELECT  TOP 10 st.[Sales Team],COUNT(st.[Sales Team]) AS 'Total Champion Customers'
FROM ['Sales Team Sheet$'] st
LEFT JOIN ['Sales Orders Sheet$'] so
ON st._SalesTeamID  = so._SalesTeamID
LEFT JOIN Analysis_cs cs
ON so._CustomerID = cs._CustomerID
WHERE cs.rfm_segment = 'Champion Customers'
GROUP BY st.[Sales Team]
ORDER BY 'Total Champion Customers' DESC;


SELECT  TOP 10 st.[Sales Team],COUNT(st.[Sales Team]) AS 'Total Declining Customers'
FROM ['Sales Team Sheet$'] st
JOIN ['Sales Orders Sheet$'] so
ON st._SalesTeamID  = so._SalesTeamID
JOIN Analysis_cs cs
ON so._CustomerID = cs._CustomerID
WHERE cs.rfm_segment = 'Declining Customer'
GROUP BY st.[Sales Team]
ORDER BY 'Total Declining Customers';

--Which productsare famous amongst champion customers
SELECT  ps.[Product Name],COUNT(ps.[Product Name]) AS 'Total purchases'
FROM ['Products Sheet$'] ps
LEFT JOIN ['Sales Orders Sheet$'] so
ON ps._ProductID = so._ProductID
LEFT JOIN Analysis_cs cs
ON so._CustomerID = cs._CustomerID
WHERE cs.rfm_segment = 'Champion Customers'
GROUP BY ps.[Product Name]
ORDER BY 'Total purchases' DESC;