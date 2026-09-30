-- One row per open job per snapshot day: the table the dashboard reads.
select
    j.snapshot_date,
    j.snapshot_job_id,
    j.job_key,
    j.company,
    j.ats,
    j.title,
    j.tracks,
    j.location,
    l.is_us,
    l.state,
    regexp_matches(j.location_clean, '(?i)remote|virtual|anywhere|work from home') as is_remote,
    regexp_matches(j.location_clean, '(?i)^\d+ locations|;')                      as is_multi,
    j.tracks like '%Backend%' as is_backend,
    j.tracks like '%Data%'    as is_data,
    j.tracks like '%AI/ML%'   as is_ai_ml,
    j.posted_at,
    j.url
from {{ ref('stg_snapshots') }} j
left join {{ ref('int_location_states') }} l using (location_clean)
