-- Warn when location cleaning gets worse: of US postings that name a specific place (not remote-only,
-- not "N Locations"), at least 90% should resolve to a state on every day. Falls below -> add cities
-- or places to data/reference/.
{{ config(severity = 'warn') }}

select snapshot_date, round(100.0 * avg((state is not null)::int), 1) as pct_with_state
from {{ ref('fct_open_roles') }}
where is_us and not is_remote and not is_multi
group by snapshot_date
having avg((state is not null)::int) < 0.90
