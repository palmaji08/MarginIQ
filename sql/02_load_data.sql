/*───────────────────────────────────────────────────────────────────────────
  Phase 2, Step 2: Load the cleaned CSVs into the star schema.
  FORMAT='CSV' handles the CRLF line endings; FIRSTROW=2 skips the header.
  Dimensions load first so the fact table's foreign keys are satisfied.
───────────────────────────────────────────────────────────────────────────*/
USE RetailTurnaround;
GO

-- Empty tables first (FK-safe order) so the load is re-runnable
DELETE FROM fact_transactions;
DELETE FROM dim_stores;
DELETE FROM dim_products;
DELETE FROM dim_customers;
GO

BULK INSERT dim_stores
FROM 'd:\project ass\RetailTurnaround\data\clean\stores_clean.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', TABLOCK);

BULK INSERT dim_products
FROM 'd:\project ass\RetailTurnaround\data\clean\products_clean.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', TABLOCK);

BULK INSERT dim_customers
FROM 'd:\project ass\RetailTurnaround\data\clean\customers_clean.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', TABLOCK);

BULK INSERT fact_transactions
FROM 'd:\project ass\RetailTurnaround\data\clean\transactions_clean.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', TABLOCK);
GO

PRINT 'Load complete. Row counts:';
SELECT 'dim_stores' AS tbl, COUNT(*) AS rows FROM dim_stores
UNION ALL SELECT 'dim_products',      COUNT(*) FROM dim_products
UNION ALL SELECT 'dim_customers',     COUNT(*) FROM dim_customers
UNION ALL SELECT 'fact_transactions', COUNT(*) FROM fact_transactions;
