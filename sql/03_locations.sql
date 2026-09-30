-- Check the location cleaning in stg_jobs. Run after the model:
--   python run_sql.py sql/models/stg_jobs.sql sql/03_locations.sql

-- Still one row per job? (should print the same two numbers)
SELECT (SELECT count(*) FROM raw_jobs) AS raw_rows, (SELECT count(*) FROM stg_jobs) AS stg_rows;

-- How much got a state?
SELECT CASE WHEN NOT is_us THEN 'not US'
            WHEN state IS NOT NULL THEN 'state found'
            WHEN is_remote THEN 'remote, no state'
            WHEN is_multi THEN 'multiple, no state'
            ELSE 'no state' END AS result,
       count(*) AS roles, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM stg_jobs GROUP BY result ORDER BY roles DESC;

-- Top states
SELECT state, count(*) AS roles FROM stg_jobs WHERE state IS NOT NULL
GROUP BY state ORDER BY roles DESC LIMIT 12;

-- Spot-check: what is still unmatched?
SELECT location, count(*) AS n FROM stg_jobs
WHERE state IS NULL AND is_us AND NOT is_remote AND NOT is_multi
GROUP BY location ORDER BY n DESC LIMIT 15;
