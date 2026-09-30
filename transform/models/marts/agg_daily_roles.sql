-- Open US roles per day and role type (a job with two role types counts in both).
select snapshot_date, 'Backend' as track, count(*) as roles from {{ ref('fct_open_roles') }} where is_us and is_backend group by 1
union all
select snapshot_date, 'AI/ML', count(*) from {{ ref('fct_open_roles') }} where is_us and is_ai_ml group by 1
union all
select snapshot_date, 'Data', count(*) from {{ ref('fct_open_roles') }} where is_us and is_data group by 1
