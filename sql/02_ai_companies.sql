-- make the snapshot files available as a table called "jobs"
CREATE OR REPLACE VIEW jobs AS
SELECT * FROM read_csv('data/snapshots/*.csv.gz', header = true);

SELECT company, count(*) AS ai_roles                    -- 4. show company + how many rows it has
FROM jobs, unnest(string_split(tracks, ',')) AS u(t)    -- 1. split each job into one row per track, called t
WHERE trim(t) = 'AI/ML'                                  -- 2. keep only the AI/ML rows
GROUP BY company                                         -- 3. put rows of the same company together
ORDER BY ai_roles DESC                                   -- 5. biggest first
LIMIT 10;                                                -- 6. only the top 10
