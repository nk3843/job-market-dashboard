-- Check the location cleaning in the fct_open_roles mart (built by dbt in transform/). Run:
--   python run_sql.py sql/03_locations.sql

CREATE OR REPLACE VIEW fct_open_roles AS
SELECT * FROM read_parquet('data/marts/fct_open_roles/*/*.parquet', hive_partitioning = true);

-- How much got a state?
SELECT CASE WHEN NOT is_us THEN 'not US'
            WHEN state IS NOT NULL THEN 'state found'
            WHEN is_remote THEN 'remote, no state'
            WHEN is_multi THEN 'multiple, no state'
            ELSE 'no state' END AS result,
       count(*) AS roles, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM fct_open_roles GROUP BY result ORDER BY roles DESC;

-- Top states
SELECT state, count(*) AS roles FROM fct_open_roles WHERE state IS NOT NULL
GROUP BY state ORDER BY roles DESC LIMIT 12;

-- Spot-check: what is still unmatched?
SELECT location, count(*) AS n FROM fct_open_roles
WHERE state IS NULL AND is_us AND NOT is_remote AND NOT is_multi
GROUP BY location ORDER BY n DESC LIMIT 15;
