-- One row per open job per snapshot day, with tidied text. No business logic here, only cleanup.
select
    snapshot_date,
    job_key,
    snapshot_date::varchar || '|' || job_key as snapshot_job_id,   -- the grain, as one testable column
    company,
    ats,
    title,
    tracks,
    location,
    -- collapse whitespace, and spell out Washington DC so it isn't read as the state of Washington
    regexp_replace(regexp_replace(coalesce(location, ''), '\s+', ' ', 'g'),
                   '(?i)washington,? ?d\.?c\.?', 'District of Columbia', 'g') as location_clean,
    nullif(country, '') as country,
    posted_at,
    url
from {{ source('raw', 'snapshots') }}
