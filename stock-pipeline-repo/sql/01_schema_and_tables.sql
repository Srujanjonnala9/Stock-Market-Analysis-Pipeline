/* =====================================================================
   01 - Schema and tables (Microsoft Fabric Warehouse, T-SQL)
   Notes:
   - Fabric Warehouse does not enforce primary keys (NOT ENFORCED), so
     duplicates are prevented by the merge procedure and detected by the
     quality checks.
   - Use varchar, not nvarchar. datetime2 supports precision up to 6.
   - Run each statement separately in the Fabric SQL editor (no GO).
   ===================================================================== */

CREATE SCHEMA etl;

/* Stocks to load - the pipeline reads its work list from this table */
CREATE TABLE dbo.dim_symbol (
    symbol        VARCHAR(30)  NOT NULL,
    exchange      VARCHAR(10)  NOT NULL,
    company_name  VARCHAR(200) NULL,
    sector        VARCHAR(100) NULL,
    is_active     BIT          NOT NULL
);
ALTER TABLE dbo.dim_symbol
    ADD CONSTRAINT pk_dim_symbol PRIMARY KEY NONCLUSTERED (symbol, exchange) NOT ENFORCED;

/* Staging: raw API rows as text, emptied at the start of every run */
CREATE TABLE dbo.staging_stock_price (
    symbol      VARCHAR(30)  NULL,
    exchange    VARCHAR(10)  NULL,
    trade_date  VARCHAR(30)  NULL,
    [open]      VARCHAR(50)  NULL,
    high        VARCHAR(50)  NULL,
    low         VARCHAR(50)  NULL,
    [close]     VARCHAR(50)  NULL,
    volume      VARCHAR(50)  NULL,
    run_id      VARCHAR(100) NULL
);

/* Fact: clean, typed, permanent history */
CREATE TABLE dbo.fact_stock_price (
    symbol      VARCHAR(30)    NOT NULL,
    exchange    VARCHAR(10)    NOT NULL,
    trade_date  DATE           NOT NULL,
    [open]      DECIMAL(18,4)  NULL,
    high        DECIMAL(18,4)  NULL,
    low         DECIMAL(18,4)  NULL,
    [close]     DECIMAL(18,4)  NULL,
    volume      BIGINT         NULL,
    run_id      VARCHAR(100)   NULL,
    loaded_at   DATETIME2(6)   NOT NULL
);
ALTER TABLE dbo.fact_stock_price
    ADD CONSTRAINT pk_fact_stock_price PRIMARY KEY NONCLUSTERED (symbol, exchange, trade_date) NOT ENFORCED;

/* Incremental-load bookkeeping */
CREATE TABLE etl.watermark (
    symbol             VARCHAR(30) NOT NULL,
    exchange           VARCHAR(10) NOT NULL,
    last_loaded_date   DATE        NOT NULL
);

CREATE TABLE etl.run_log (
    run_id         VARCHAR(100)  NOT NULL,
    step_name      VARCHAR(100)  NOT NULL,
    status         VARCHAR(20)   NOT NULL,   -- SUCCESS / WARNING / FAILED
    rows_affected  INT           NULL,
    message        VARCHAR(1000) NULL,
    logged_at      DATETIME2(6)  NOT NULL
);

/* Reporting table read by the Power BI semantic model (Direct Lake).
   A real table is used instead of a view because views force a
   DirectQuery fallback in Direct Lake models. */
CREATE TABLE dbo.stock_daily (
    symbol            VARCHAR(30),
    exchange          VARCHAR(10),
    company_name      VARCHAR(200),
    sector            VARCHAR(100),
    trade_date        DATE,
    [open]            DECIMAL(18,4),
    high              DECIMAL(18,4),
    low               DECIMAL(18,4),
    [close]           DECIMAL(18,4),
    volume            BIGINT,
    daily_change_pct  DECIMAL(18,6),
    ma_7              DECIMAL(18,4),
    ma_30             DECIMAL(18,4)
);
