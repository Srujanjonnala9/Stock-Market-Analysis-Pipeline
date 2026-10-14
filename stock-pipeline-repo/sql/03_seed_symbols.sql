/* =====================================================================
   03 - Seed the stock list (25 US stocks, 5 per sector)
   Test each symbol against the Twelve Data free plan before adding it.
   ===================================================================== */
INSERT INTO dbo.dim_symbol (symbol, exchange, company_name, sector, is_active) VALUES
('AAPL','NASDAQ','Apple','Technology',1),
('MSFT','NASDAQ','Microsoft','Technology',1),
('NVDA','NASDAQ','NVIDIA','Technology',1),
('GOOGL','NASDAQ','Alphabet','Technology',1),
('META','NASDAQ','Meta Platforms','Technology',1),
('JPM','NYSE','JPMorgan Chase','Financials',1),
('BAC','NYSE','Bank of America','Financials',1),
('WFC','NYSE','Wells Fargo','Financials',1),
('GS','NYSE','Goldman Sachs','Financials',1),
('MS','NYSE','Morgan Stanley','Financials',1),
('XOM','NYSE','Exxon Mobil','Energy',1),
('CVX','NYSE','Chevron','Energy',1),
('COP','NYSE','ConocoPhillips','Energy',1),
('SLB','NYSE','Schlumberger','Energy',1),
('EOG','NYSE','EOG Resources','Energy',1),
('JNJ','NYSE','Johnson & Johnson','Healthcare',1),
('PFE','NYSE','Pfizer','Healthcare',1),
('UNH','NYSE','UnitedHealth Group','Healthcare',1),
('MRK','NYSE','Merck','Healthcare',1),
('ABBV','NYSE','AbbVie','Healthcare',1),
('AMZN','NASDAQ','Amazon','Consumer',1),
('TSLA','NASDAQ','Tesla','Consumer',1),
('KO','NYSE','Coca-Cola','Consumer',1),
('PEP','NASDAQ','PepsiCo','Consumer',1),
('MCD','NYSE','McDonalds','Consumer',1);
