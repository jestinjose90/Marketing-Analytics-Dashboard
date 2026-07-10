										
                                       -- SQL PORTFOLIO PROJECT --
                               
-- BUSINESS PROBLEM :
-- The goal of this analysis is to improve marketing campaign effectiveness and reduce customer churn by analyzing customer demographics, spending behavior,
--  and engagement patterns to identify high-value and at-risk customer segments.


use ecommerce_project;
select * from marketing;

					             --  DATA CLEANING  --
-- Check categories
SELECT DISTINCT Marital_Status FROM marketing;

-- Fix inconsistent values
UPDATE marketing
SET Marital_Status = 'Single'
WHERE Marital_Status IN ('YOLO','Alone','Divorced','Widow');

UPDATE marketing
SET Marital_Status = 'Married'
WHERE Marital_Status = 'Together';

UPDATE marketing
SET Marital_Status = 'Unknown'
WHERE Marital_Status = 'Absurd';


                           -- OVERALL CAMPAIGN PERFORMANCE -- 

SELECT 
    COUNT(*) AS total_customers,
    SUM(Response) AS total_responded,
    ROUND(SUM(Response) * 100.0 / COUNT(*), 2) AS response_rate
FROM marketing;  -- KPI FOR POWER BI -- 

select * from marketing_cleaned;


 -- CAMPAIGN PERFORMANCE ANALYSIS --

-- Response rate from each campaign --
SELECT 'Campaign 1' AS campaign, ROUND(AVG(AcceptedCmp1)*100,2) AS response_rate FROM marketing
UNION
SELECT 'Campaign 2', ROUND(AVG(AcceptedCmp2)*100,2) FROM marketing
UNION
SELECT 'Campaign 3', ROUND(AVG(AcceptedCmp3)*100,2) FROM marketing
UNION
SELECT 'Campaign 4', ROUND(AVG(AcceptedCmp4)*100,2) FROM marketing
UNION
SELECT 'Latest Campaign', ROUND(AVG(Response)*100,2) FROM marketing;

-- recent campaign doubled the response rate from previous campaign and campaign 2 had the lowest engagement --


											-- PAST BEHAVIOUR INSIGHT -- 
WITH campaign_behavior AS (
    SELECT 
        past_acceptance,
        Response
    FROM marketing_cleaned
)

SELECT 
    past_acceptance,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),2) AS pct_customers,
    ROUND(AVG(Response)*100,2) AS response_rate
FROM campaign_behavior
GROUP BY past_acceptance
ORDER BY past_acceptance DESC;


				-- Customer Segmentation by Income and Marital Status with Campaign Response and Spending Analysis

WITH segmented_data AS (
    SELECT 
        CASE 
            WHEN Income < 30000 THEN 'Low'
            WHEN Income BETWEEN 30000 AND 70000 THEN 'Medium'
            ELSE 'High'
        END AS income_group,

        CASE 
            WHEN Marital_Status IN ('Married','Together') THEN 'Married'
            WHEN Marital_Status IN ('Single','YOLO','Divorced','Widow') THEN 'Single'
            ELSE 'Unknown'
        END AS marital_group,

        Response,
        (MntWines + MntFruits + MntMeatProducts +
         MntFishProducts + MntSweetProducts + MntGoldProds) AS total_spent

    FROM marketing
)

SELECT 
    income_group,
    marital_group,
    COUNT(*) AS total_customers,
    SUM(Response) AS responded,
    ROUND(SUM(Response) * 100.0 / COUNT(*), 2) AS response_rate,
    ROUND(AVG(total_spent),2) AS avg_spending   
FROM segmented_data
GROUP BY income_group, marital_group
ORDER BY response_rate DESC;


                                   -- SPENDING BEHAVIOUR -- 
SELECT 
    Response,
    ROUND(AVG(MntWines),2) AS avg_wine,
    ROUND(AVG(MntMeatProducts),2) AS avg_meat,
    ROUND(AVG(MntFruits),2) AS avg_fruits,
    ROUND(AVG(MntFishProducts),2) AS avg_seafood,
    ROUND(AVG(MntSweetProducts),2) AS avg_paidOnSweets,
    ROUND(AVG(MntGoldProds),2) AS avg_goldpurchases
FROM marketing
GROUP BY Response;


                                               -- CHANNEL ANALYSIS --
SELECT
	Response,
    ROUND(AVG(NumWebPurchases),2) AS web,
    ROUND(AVG(NumStorePurchases),2) AS store,
    ROUND(AVG(NumCatalogPurchases),2) AS catalog,
    ROUND(AVG(NumDealsPurchases),2) As Deals
FROM marketing
GROUP BY response;


											-- CREATE ANALYTICAL VIEW --

CREATE OR REPLACE VIEW marketing_cleaned AS
SELECT 
    ID,
    Income,
    Education,
    Response,
    Recency,
    AcceptedCmp1,
    AcceptedCmp2,
    AcceptedCmp3,
    AcceptedCmp4,
    (AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4) AS past_acceptance,
    (NumWebPurchases + NumStorePurchases + NumCatalogPurchases) AS total_purchases,

    CASE 
        WHEN Marital_Status IN ('Married','Together') THEN 'Married'
        WHEN Marital_Status IN ('Single','YOLO','Divorced','Widow') THEN 'Single'
        ELSE 'Unknown'
    END AS marital_group,

    CASE 
        WHEN (YEAR(CURDATE()) - Year_Birth) BETWEEN 30 AND 45 THEN 'Mid-age'
        WHEN (YEAR(CURDATE()) - Year_Birth) BETWEEN 46 AND 60 THEN 'Older Adults'
        ELSE 'Seniors'
        END AS age_group,
        
	CASE 
        WHEN Income < 30000 THEN 'Low'
        WHEN Income BETWEEN 30000 AND 70000 THEN 'Medium'
        ELSE 'High'
        END AS income_group,
        
	CASE 
    WHEN Education IN ('Graduation', 'Master', 'PhD') 
        THEN 'Graduate'
        ELSE 'Non-Graduate'
        END AS education_group,
        
	
    (MntWines + MntFruits + MntMeatProducts + 
     MntFishProducts + MntSweetProducts + MntGoldProds) AS total_spent

FROM marketing;

                         -- AGE BASED SPENDING --
SELECT 
    age_group,
    ROUND(SUM(total_spent),2) AS total_spending,
    ROUND(AVG(total_spent),2) AS avg_spending
FROM marketing_cleaned
GROUP BY age_group
ORDER BY total_spending DESC;

-- CUSTOMER VALUE BASED ON THEIR ATTRIBUTES
SELECT 
    age_group,
    marital_group,
    income_group,
    COUNT(*) AS customers,
    ROUND(AVG(total_spent),2) AS avg_customer_value,
    ROUND(SUM(total_spent),2) AS total_revenue

FROM marketing_cleaned
GROUP BY age_group, marital_group, income_group
ORDER BY avg_customer_value DESC;


                                               -- RFM ANALYSIS --

-- Create RFM segmentation table focused on Champions and At Risk customers

DROP VIEW IF EXISTS customer_segments;

CREATE VIEW customer_segments AS

WITH rfm AS (
    SELECT 
        ID,

        NTILE(5) OVER (ORDER BY Recency DESC) AS R,

        NTILE(5) OVER (
            ORDER BY total_purchases DESC
        ) AS F,

        NTILE(5) OVER (
            ORDER BY total_spent DESC
        ) AS M

    FROM marketing_cleaned
)

SELECT 
    m.ID,
    m.age_group,
    m.marital_group,
    m.Income,
    m.total_purchases,
    m.total_spent,
    m.Recency,

    r.R,
    r.F,
    r.M,

    (r.R + r.F + r.M) AS rfm_score,

    CASE 
        WHEN (r.R + r.F + r.M) >= 13 THEN 'Champions'
        ELSE 'At Risk'
    END AS segment

FROM marketing_cleaned m
JOIN rfm r
ON m.ID = r.ID

WHERE 
    (r.R + r.F + r.M) >= 13
    OR
    (r.R + r.F + r.M) < 7;

select * from customer_segments;




											-- INSIGHTS --

-- • High-income, single, mid-age customers show the highest response rates and engagement

-- • Seniors are the highest spenders but have lower campaign response rates → retention opportunity

-- • Customers who responded to previous campaigns are significantly more likely to respond again

-- • A large portion of customers fall into the “At Risk” RFM segment, indicating churn risk

-- • Campaigns significantly increased catalog purchases and improved online engagement

-- • Wine and meat products are the most popular categories across customers

-- • High-value customers (high spenders) are also at risk of churn → critical for retention strategy










 
 








