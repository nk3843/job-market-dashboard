-- First look at the job snapshots. Run with:  python run_sql.py sql/01_explore.sql

-- DuckDB reads every day's gzipped CSV as one table and infers the column types.
CREATE OR REPLACE VIEW jobs AS
SELECT * FROM read_csv('data/snapshots/*.csv.gz', header = true);

-- How many open roles, at how many companies?
SELECT count(*) AS roles, count(DISTINCT company) AS companies FROM jobs;

-- Who is hiring the most?
SELECT company, count(*) AS roles FROM jobs GROUP BY company ORDER BY roles DESC LIMIT 10;

-- Roles per track. `tracks` holds a list like "Backend, AI/ML", so split it into one row per track
-- first; grouping on the raw column would undercount (an AI/ML role tagged "Backend, AI/ML" is missed).
SELECT trim(t) AS track, count(*) AS roles
FROM jobs, unnest(string_split(tracks, ',')) AS u(t)
GROUP BY track ORDER BY roles DESC;

-- How usable is the location text? (Cleaning it up is the next step.)
SELECT CASE WHEN location ILIKE '%location%' THEN 'N Locations (vague)'
            WHEN location ILIKE '%remote%' THEN 'mentions remote'
            WHEN location IS NULL OR location = '' THEN 'blank'
            ELSE 'specific place' END AS kind,
       count(*) AS roles,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM jobs GROUP BY kind ORDER BY roles DESC;
