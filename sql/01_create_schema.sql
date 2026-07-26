/*───────────────────────────────────────────────────────────────────────────
  Retail Store Turnaround Analysis — Phase 2, Step 1: Schema
  Creates the RetailTurnaround database and a clean STAR SCHEMA:
      fact_transactions  ->  dim_stores / dim_products / dim_customers
  Data types are chosen to match the cleaned CSVs (money as DECIMAL, not FLOAT,
  so currency math is exact). Re-runnable: drops existing tables first.
───────────────────────────────────────────────────────────────────────────*/

IF DB_ID('RetailTurnaround') IS NULL
    CREATE DATABASE RetailTurnaround;
GO

USE RetailTurnaround;
GO

-- Drop in FK-safe order (fact first, then dimensions) so the script can re-run
DROP TABLE IF EXISTS fact_transactions;
DROP TABLE IF EXISTS dim_stores;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_customers;
GO

/*── Dimension: Stores ──────────────────────────────────────────────────────*/
CREATE TABLE dim_stores (
    Store_ID        INT           NOT NULL PRIMARY KEY,
    Store_Name      VARCHAR(50)   NOT NULL,
    City            VARCHAR(50)   NOT NULL,
    Region          VARCHAR(20)   NOT NULL,
    Store_Type      VARCHAR(30)   NOT NULL,
    Opening_Date    DATE          NULL,
    Manager_Name    VARCHAR(50)   NULL,
    Monthly_Rent    INT           NULL,
    Employees       INT           NULL,
    Floor_Area_sqft INT           NULL
);

/*── Dimension: Products ────────────────────────────────────────────────────*/
CREATE TABLE dim_products (
    Product_ID      INT           NOT NULL PRIMARY KEY,
    Product_Name    VARCHAR(100)  NOT NULL,
    Category        VARCHAR(30)   NOT NULL,
    Brand           VARCHAR(50)   NULL,
    Cost_Price      DECIMAL(10,2) NULL,
    Selling_Price   DECIMAL(10,2) NULL
);

/*── Dimension: Customers ───────────────────────────────────────────────────
  Note: this City is the CUSTOMER's home city (distinct from a store's city).
  We keep the store city as the analytical geography for the turnaround. */
CREATE TABLE dim_customers (
    Customer_ID      INT          NOT NULL PRIMARY KEY,
    Gender           VARCHAR(10)  NULL,
    Age_Group        VARCHAR(10)  NULL,
    Customer_Segment VARCHAR(20)  NULL,
    Loyalty_Member   VARCHAR(3)   NULL,   -- 'Yes' / 'No'
    City             VARCHAR(50)  NULL
);

/*── Fact: Transactions ─────────────────────────────────────────────────────*/
CREATE TABLE fact_transactions (
    Transaction_ID   INT           NOT NULL PRIMARY KEY,
    [Date]           DATE          NOT NULL,
    Store_ID         INT           NOT NULL,
    Product_ID       INT           NOT NULL,
    Customer_ID      INT           NOT NULL,
    Quantity         INT           NOT NULL,
    Unit_Price       DECIMAL(12,2) NOT NULL,
    Discount_Percent DECIMAL(5,2)  NOT NULL,
    Revenue          DECIMAL(14,2) NOT NULL,
    Cost             DECIMAL(14,2) NOT NULL,
    Profit           DECIMAL(14,2) NOT NULL,
    Payment_Method   VARCHAR(20)   NOT NULL,
    CONSTRAINT FK_fact_store    FOREIGN KEY (Store_ID)    REFERENCES dim_stores(Store_ID),
    CONSTRAINT FK_fact_product  FOREIGN KEY (Product_ID)  REFERENCES dim_products(Product_ID),
    CONSTRAINT FK_fact_customer FOREIGN KEY (Customer_ID) REFERENCES dim_customers(Customer_ID)
);
GO

/*── Indexes on the join / filter columns (fast star-schema joins) ──────────*/
CREATE INDEX IX_fact_store    ON fact_transactions(Store_ID);
CREATE INDEX IX_fact_product  ON fact_transactions(Product_ID);
CREATE INDEX IX_fact_customer ON fact_transactions(Customer_ID);
CREATE INDEX IX_fact_date     ON fact_transactions([Date]);
GO

PRINT 'Schema created: RetailTurnaround (3 dims + 1 fact, FKs + indexes).';
