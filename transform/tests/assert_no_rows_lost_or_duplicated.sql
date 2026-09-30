-- The joins in fct_open_roles must keep exactly one row per job per day (no fan-out, nothing dropped).
-- A test fails when its query returns rows.
select s.n as staging_rows, f.n as fact_rows
from (select count(*) as n from {{ ref('stg_snapshots') }}) s,
     (select count(*) as n from {{ ref('fct_open_roles') }}) f
where s.n <> f.n
