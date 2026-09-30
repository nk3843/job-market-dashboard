-- stg_jobs: one row per job per snapshot day, with cleaned columns every chart can rely on.
--   is_us        FALSE when the only place named is outside the US (the collector's US filter misses a few)
--   state        two-letter US state of the first place named in `location` (NULL when none is named or not US)
--   is_remote    location says remote / virtual / anywhere
--   is_multi     location is only "N Locations" (Workday) or lists several places
--   is_backend, is_data, is_ai_ml   one flag per track (a job can have several)
-- Known limits: only the first place counts; unlisted cities stay NULL. Add places to data/reference/ as they show up.

CREATE OR REPLACE TABLE ref_states AS SELECT * FROM read_csv('data/reference/us_states.csv');
CREATE OR REPLACE TABLE ref_cities AS SELECT * FROM read_csv('data/reference/us_cities.csv');
CREATE OR REPLACE TABLE ref_non_us AS SELECT * FROM read_csv('data/reference/non_us_places.csv');

CREATE OR REPLACE VIEW raw_jobs AS
SELECT * FROM read_csv('data/snapshots/*.csv.gz', header = true);

CREATE OR REPLACE VIEW stg_jobs AS
WITH base AS (
    SELECT *,
           -- tidy the text once: collapse whitespace, and spell out Washington DC so it isn't read as WA
           regexp_replace(regexp_replace(coalesce(location, ''), '\s+', ' ', 'g'),
                          '(?i)washington,? ?d\.?c\.?', 'District of Columbia', 'g') AS loc
    FROM raw_jobs
),
-- every state name, state code, or known city found in the text, with where it starts
matches AS (
    SELECT b.snapshot_date, b.job_key, s.code AS state, strpos(lower(b.loc), lower(s.name)) AS pos
    FROM base b JOIN ref_states s ON regexp_matches(b.loc, '(?i)\b' || s.name || '\b')
    UNION ALL
    SELECT b.snapshot_date, b.job_key, s.code,
           strpos(b.loc, regexp_extract(b.loc, '(^|[^A-Za-z])' || s.code || '($|[^A-Za-z])', 0))
    FROM base b JOIN ref_states s ON regexp_matches(b.loc, '(^|[^A-Za-z])' || s.code || '($|[^A-Za-z])')
    UNION ALL
    SELECT b.snapshot_date, b.job_key, c.state, strpos(lower(b.loc), lower(c.city))
    FROM base b JOIN ref_cities c ON regexp_matches(b.loc, '(?i)\b' || c.city || '\b')
),
first_match AS (   -- the earliest match wins
    SELECT snapshot_date, job_key, arg_min(state, pos) AS state
    FROM matches GROUP BY snapshot_date, job_key
),
flagged AS (       -- a single place (no ';') that is on the non-US list
    SELECT b.*, NOT EXISTS (SELECT 1 FROM ref_non_us n WHERE regexp_matches(b.loc, '(?i)(^|\PL)' || n.place || '($|\PL)'))  -- \PL = not a letter; \b ignores "ö"
                OR b.loc LIKE '%;%' AS is_us
    FROM base b
)
SELECT b.snapshot_date, b.company, b.ats, b.job_key, b.title, b.tracks, b.location,
       b.is_us,
       CASE WHEN b.is_us THEN f.state END AS state,
       regexp_matches(b.loc, '(?i)remote|virtual|anywhere|work from home') AS is_remote,
       regexp_matches(b.loc, '(?i)^\d+ locations|;') AS is_multi,
       b.tracks LIKE '%Backend%' AS is_backend,
       b.tracks LIKE '%Data%'    AS is_data,
       b.tracks LIKE '%AI/ML%'   AS is_ai_ml,
       b.posted_at, b.url
FROM flagged b
LEFT JOIN first_match f USING (snapshot_date, job_key);
