/* Useful checks after a pipeline run */

-- what happened in each run
SELECT * FROM etl.run_log ORDER BY logged_at DESC;

-- any failures
SELECT * FROM etl.run_log WHERE status = 'FAILED' ORDER BY logged_at DESC;

-- rows per stock and date coverage
SELECT symbol, COUNT(*) AS rows_in_fact, MIN(trade_date) AS first_date, MAX(trade_date) AS last_date
FROM dbo.fact_stock_price GROUP BY symbol ORDER BY symbol;

-- watermark per stock
SELECT * FROM etl.watermark ORDER BY symbol;

-- stocks per sector in the reporting table
SELECT sector, COUNT(DISTINCT symbol) AS stocks FROM dbo.stock_daily GROUP BY sector ORDER BY sector;
