/* =====================================================================
   02 - Stored procedures
   Run each CREATE PROCEDURE as its own batch in the Fabric SQL editor.
   ===================================================================== */

/* ---- Which stocks to fetch, and from which date (metadata-driven) ----
   start_date = watermark minus an overlap window, or a default for new stocks */
CREATE PROCEDURE etl.sp_get_symbols_to_load
    @default_start DATE = '2020-01-01',
    @overlap_days  INT  = 5
AS
BEGIN
    SELECT d.symbol,
           d.exchange,
           CONVERT(VARCHAR(10),
               COALESCE(DATEADD(DAY, -@overlap_days, w.last_loaded_date), @default_start),
               23) AS start_date
    FROM dbo.dim_symbol d
    LEFT JOIN etl.watermark w
           ON w.symbol = d.symbol AND w.exchange = d.exchange
    WHERE d.is_active = 1;
END;

/* ---- Merge staging -> fact (idempotent upsert), move watermark, log ---- */
CREATE PROCEDURE etl.sp_merge_stock_price
    @run_id VARCHAR(100)
AS
BEGIN
    SELECT symbol, exchange,
           TRY_CAST(trade_date AS DATE)            AS trade_date,
           TRY_CAST([open]  AS DECIMAL(18,4))      AS [open],
           TRY_CAST(high    AS DECIMAL(18,4))      AS high,
           TRY_CAST(low     AS DECIMAL(18,4))      AS low,
           TRY_CAST([close] AS DECIMAL(18,4))      AS [close],
           TRY_CAST(volume  AS BIGINT)             AS volume,
           run_id
    INTO #clean
    FROM (
        SELECT *, ROW_NUMBER() OVER (
                    PARTITION BY symbol, exchange, trade_date
                    ORDER BY run_id DESC) AS rn
        FROM dbo.staging_stock_price
        WHERE run_id = @run_id
    ) s
    WHERE rn = 1
      AND TRY_CAST(trade_date AS DATE) IS NOT NULL;

    -- 1) update rows that already exist (late corrections, provisional prices)
    UPDATE f
    SET f.[open] = c.[open], f.high = c.high, f.low = c.low,
        f.[close] = c.[close], f.volume = c.volume,
        f.run_id = c.run_id, f.loaded_at = SYSDATETIME()
    FROM dbo.fact_stock_price f
    JOIN #clean c
      ON f.symbol = c.symbol AND f.exchange = c.exchange AND f.trade_date = c.trade_date;

    -- 2) insert rows that do not exist yet
    INSERT INTO dbo.fact_stock_price
        (symbol, exchange, trade_date, [open], high, low, [close], volume, run_id, loaded_at)
    SELECT c.symbol, c.exchange, c.trade_date, c.[open], c.high, c.low, c.[close],
           c.volume, c.run_id, SYSDATETIME()
    FROM #clean c
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.fact_stock_price f
        WHERE f.symbol = c.symbol AND f.exchange = c.exchange AND f.trade_date = c.trade_date
    );

    DECLARE @rows INT = (SELECT COUNT(*) FROM #clean);

    -- 3) move the watermark forward
    DELETE FROM etl.watermark
    WHERE EXISTS (SELECT 1 FROM #clean c
                  WHERE c.symbol = etl.watermark.symbol AND c.exchange = etl.watermark.exchange);

    INSERT INTO etl.watermark (symbol, exchange, last_loaded_date)
    SELECT symbol, exchange, MAX(trade_date) FROM #clean GROUP BY symbol, exchange;

    INSERT INTO etl.run_log VALUES (@run_id, 'merge_fact_stock_price', 'SUCCESS', @rows, NULL, SYSDATETIME());
END;

/* ---- Data quality checks - THROW on a hard failure so the pipeline stops ---- */
CREATE PROCEDURE etl.sp_quality_checks
    @run_id VARCHAR(100)
AS
BEGIN
    DECLARE @dups INT, @bad_prices INT, @nulls INT, @stale INT;

    SELECT @dups = COUNT(*) FROM (
        SELECT symbol, exchange, trade_date
        FROM dbo.fact_stock_price
        GROUP BY symbol, exchange, trade_date
        HAVING COUNT(*) > 1) d;

    SELECT @bad_prices = COUNT(*) FROM dbo.fact_stock_price
    WHERE high < low OR [close] > high OR [close] < low OR [open] > high OR [open] < low;

    SELECT @nulls = COUNT(*) FROM dbo.fact_stock_price
    WHERE [close] IS NULL OR [close] <= 0;

    SELECT @stale = CASE WHEN MAX(trade_date) < DATEADD(DAY, -5, CAST(SYSDATETIME() AS DATE))
                         THEN 1 ELSE 0 END
    FROM dbo.fact_stock_price;

    INSERT INTO etl.run_log VALUES (@run_id, 'quality_checks',
        CASE WHEN @dups + @bad_prices + @nulls > 0 THEN 'FAILED'
             WHEN @stale = 1 THEN 'WARNING' ELSE 'SUCCESS' END,
        @dups + @bad_prices + @nulls,
        CONCAT('dups=', @dups, ', bad_prices=', @bad_prices,
               ', null_or_nonpositive_close=', @nulls, ', stale=', @stale),
        SYSDATETIME());

    IF @dups + @bad_prices + @nulls > 0
        THROW 50001, 'Data quality checks failed - see etl.run_log', 1;
END;

/* ---- Rebuild the reporting table read by Power BI ---- */
CREATE PROCEDURE etl.sp_refresh_stock_daily
AS
BEGIN
    TRUNCATE TABLE dbo.stock_daily;
    INSERT INTO dbo.stock_daily
    SELECT f.symbol, f.exchange, d.company_name, d.sector, f.trade_date,
           f.[open], f.high, f.low, f.[close], f.volume,
           (f.[close] - LAG(f.[close]) OVER (PARTITION BY f.symbol ORDER BY f.trade_date))
             / NULLIF(LAG(f.[close]) OVER (PARTITION BY f.symbol ORDER BY f.trade_date), 0) * 100,
           AVG(f.[close]) OVER (PARTITION BY f.symbol ORDER BY f.trade_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),
           AVG(f.[close]) OVER (PARTITION BY f.symbol ORDER BY f.trade_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)
    FROM dbo.fact_stock_price f
    LEFT JOIN dbo.dim_symbol d ON d.symbol = f.symbol AND d.exchange = f.exchange;
END;
