-- One row per distinct location text, with its US state and whether it is outside the US.
-- Matching runs once per distinct location, not once per job per day: locations repeat heavily
-- ("San Francisco, CA" appears hundreds of times a day), so this stays fast as snapshots pile up.
with locations as (
    select distinct location_clean as loc from {{ ref('stg_snapshots') }}
),

-- every state name, state code, or known city found in the text, with where it starts
matches as (
    select l.loc, s.code as state, strpos(lower(l.loc), lower(s.name)) as pos
    from locations l
    join {{ ref('us_states') }} s on regexp_matches(l.loc, '(?i)\b' || s.name || '\b')

    union all

    select l.loc, s.code,
           strpos(l.loc, regexp_extract(l.loc, '(^|[^A-Za-z])' || s.code || '($|[^A-Za-z])', 0))
    from locations l
    join {{ ref('us_states') }} s on regexp_matches(l.loc, '(^|[^A-Za-z])' || s.code || '($|[^A-Za-z])')

    union all

    select l.loc, c.state, strpos(lower(l.loc), lower(c.city))
    from locations l
    join {{ ref('us_cities') }} c on regexp_matches(l.loc, '(?i)\b' || c.city || '\b')
),

first_match as (   -- the earliest match wins
    select loc, arg_min(state, pos) as state from matches group by loc
),

non_us as (        -- a single place (no ';') that is on the non-US list
    select distinct l.loc
    from locations l
    join {{ ref('non_us_places') }} n
      on regexp_matches(l.loc, '(?i)(^|\PL)' || n.place || '($|\PL)')   -- \PL = not a letter; \b misses "ö"
    where l.loc not like '%;%'
)

select
    l.loc as location_clean,
    n.loc is null as is_us,
    case when n.loc is null then f.state end as state
from locations l
left join first_match f using (loc)
left join non_us n using (loc)
