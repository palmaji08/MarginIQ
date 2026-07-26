/*───────────────────────────────────────────────────────────────────────────
  Phase 3, Step 3: Business-logic VIEWS (the analytical layer).

  Design principle: keep the logic in SQL, exposed at grains that let Power BI
  slicers cross-filter cleanly.
    - vw_sales_enriched : ROW grain. Powers KPIs, trends and every breakdown.
    - vw_store_scorecard: STORE grain. Powers the scatter and top/bottom lists.
───────────────────────────────────────────────────────────────────────────*/
USE RetailTurnaround;
GO

/*══════════════════════════════════════════════════════════════════════════
  VIEW 1 — vw_sales_enriched  (row-level star join + derived business columns)

  ┌─ MEASURES built on this view in Power BI (DAX) ────────────────────────┐
  │  Total Revenue    = SUM(Revenue)                                        │
  │  Total Profit     = SUM(Profit)                                         │
  │  Total Cost       = SUM(Cost)                                           │
  │  Profit Margin %  = DIVIDE([Total Profit], [Total Revenue])            │
  │  Total Orders     = COUNTROWS(vw_sales_enriched)                        │
  │  Total Quantity   = SUM(Quantity)                                       │
  │  Avg Order Value  = DIVIDE([Total Revenue], [Total Orders])            │
  │  Avg Discount %   = AVERAGE(Discount_Percent) / 100                     │
  └────────────────────────────────────────────────────────────────────────┘
  Derived columns below (Discount_Band, Line_Margin_Pct, Is_Loss_Making,
  Sale_Year/Month) let those measures be sliced by band, time, region, etc.
══════════════════════════════════════════════════════════════════════════*/
DROP VIEW IF EXISTS vw_sales_enriched;
GO
CREATE VIEW vw_sales_enriched AS
SELECT
    f.Transaction_ID,
    f.[Date],
    YEAR(f.[Date])                                    AS Sale_Year,
    MONTH(f.[Date])                                   AS Sale_Month,
    DATEFROMPARTS(YEAR(f.[Date]), MONTH(f.[Date]), 1) AS Sale_Month_Start,   -- clean monthly axis
    DATENAME(MONTH, f.[Date])                         AS Sale_Month_Name,
    DATEPART(QUARTER, f.[Date])                       AS Sale_Quarter,

    f.Quantity,
    f.Unit_Price,
    f.Discount_Percent,
    f.Revenue,
    f.Cost,
    f.Profit,
    CAST(100.0 * f.Profit / NULLIF(f.Revenue, 0) AS DECIMAL(6,2)) AS Line_Margin_Pct,

    -- discount bucketing done in SQL so Power BI just groups by it
    CASE WHEN f.Discount_Percent = 0  THEN '0% (None)'
         WHEN f.Discount_Percent <= 10 THEN '1-10%'
         WHEN f.Discount_Percent <= 20 THEN '10-20%'
         WHEN f.Discount_Percent <= 30 THEN '20-30%'
         ELSE '30%+' END                              AS Discount_Band,
    CASE WHEN f.Discount_Percent = 0  THEN 0
         WHEN f.Discount_Percent <= 10 THEN 1
         WHEN f.Discount_Percent <= 20 THEN 2
         WHEN f.Discount_Percent <= 30 THEN 3
         ELSE 4 END                                   AS Discount_Band_Sort,   -- for correct visual ordering
    CASE WHEN f.Profit < 0 THEN 1 ELSE 0 END          AS Is_Loss_Making,
    f.Payment_Method,

    -- keys kept for relationships in Power BI
    f.Store_ID, f.Product_ID, f.Customer_ID,

    -- store attributes (store city is the analytical geography)
    s.Store_Name, s.City AS Store_City, s.Region, s.Store_Type,
    -- product attributes
    p.Category, p.Brand,
    -- customer attributes
    c.Customer_Segment, c.Age_Group, c.Gender, c.Loyalty_Member
FROM fact_transactions f
JOIN dim_stores    s ON s.Store_ID    = f.Store_ID
JOIN dim_products  p ON p.Product_ID  = f.Product_ID
JOIN dim_customers c ON c.Customer_ID = f.Customer_ID;
GO

/*══════════════════════════════════════════════════════════════════════════
  VIEW 2 — vw_store_scorecard  (store-level KPIs, ranks, 4-quadrant tag)

  ┌─ MEASURES built on this view in Power BI (DAX) ────────────────────────┐
  │  Stores to Promote      = CALCULATE(DISTINCTCOUNT(Store_ID),           │
  │                             Performance_Quadrant = "High Rev / High Profit") │
  │  Stores to Fix or Close = CALCULATE(DISTINCTCOUNT(Store_ID),           │
  │                             Is_Loss_Making_Store = 1)                   │
  └────────────────────────────────────────────────────────────────────────┘
  Columns below feed the Revenue-vs-Profit scatter (Total_Revenue,
  Total_Profit, Performance_Quadrant) and the top/bottom/loss-store lists
  (Profit_Margin_Pct, Profit_Rank, Margin_Rank).
══════════════════════════════════════════════════════════════════════════*/
DROP VIEW IF EXISTS vw_store_scorecard;
GO
CREATE VIEW vw_store_scorecard AS
WITH store_totals AS (
    SELECT
        s.Store_ID, s.Store_Name, s.City, s.Region, s.Store_Type,
        SUM(f.Revenue)                                 AS Total_Revenue,
        SUM(f.Profit)                                  AS Total_Profit,
        COUNT(*)                                       AS Total_Orders,
        SUM(f.Quantity)                                AS Total_Quantity,
        CAST(AVG(f.Discount_Percent) AS DECIMAL(6,2))  AS Avg_Discount_Pct,
        COUNT(DISTINCT f.Customer_ID)                  AS Active_Customers,
        CAST(100.0 * AVG(CASE WHEN f.Profit < 0 THEN 1.0 ELSE 0.0 END) AS DECIMAL(6,2)) AS Loss_Txn_Pct
    FROM fact_transactions f
    JOIN dim_stores s ON s.Store_ID = f.Store_ID
    GROUP BY s.Store_ID, s.Store_Name, s.City, s.Region, s.Store_Type
),
medians AS (   -- median revenue & profit define the scatter's quadrant splits
    SELECT DISTINCT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Total_Revenue) OVER () AS Med_Revenue,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Total_Profit)  OVER () AS Med_Profit
    FROM store_totals
)
SELECT
    t.Store_ID, t.Store_Name, t.City, t.Region, t.Store_Type,
    t.Total_Revenue, t.Total_Profit, t.Total_Orders, t.Total_Quantity,
    t.Avg_Discount_Pct, t.Active_Customers, t.Loss_Txn_Pct,
    CAST(100.0 * t.Total_Profit / NULLIF(t.Total_Revenue, 0) AS DECIMAL(6,2)) AS Profit_Margin_Pct,
    CASE WHEN t.Total_Profit < 0 THEN 1 ELSE 0 END                            AS Is_Loss_Making_Store,
    RANK() OVER (ORDER BY t.Total_Profit DESC)                                AS Profit_Rank,
    RANK() OVER (ORDER BY 100.0 * t.Total_Profit / NULLIF(t.Total_Revenue,0) DESC) AS Margin_Rank,
    CASE
        WHEN t.Total_Revenue >= m.Med_Revenue AND t.Total_Profit >= m.Med_Profit THEN 'High Rev / High Profit'
        WHEN t.Total_Revenue >= m.Med_Revenue AND t.Total_Profit <  m.Med_Profit THEN 'High Rev / Low Profit'
        WHEN t.Total_Revenue <  m.Med_Revenue AND t.Total_Profit >= m.Med_Profit THEN 'Low Rev / High Profit'
        ELSE 'Low Rev / Low Profit'
    END                                                                      AS Performance_Quadrant
FROM store_totals t
CROSS JOIN medians m;
GO

PRINT 'Views created: vw_sales_enriched, vw_store_scorecard.';
