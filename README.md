# Job Market Dashboard

Tracks open backend, data, and AI/ML engineering roles at ~220 tech companies, one snapshot per weekday,
and turns them into hiring trends: who is hiring, for what, and where.

**Live demo: [nk-job-market.streamlit.app](https://nk-job-market.streamlit.app/)** (it may take ~30 seconds to wake up)

![Dashboard screenshot](docs/screenshot.png)

## Run it

```bash
python -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/streamlit run app.py
```

## How it works

```
job boards ─► collector (scheduled, weekdays) ─► data/snapshots/*.csv.gz
                                                        │  push triggers GitHub Actions
                                                        ▼
                         dbt build: models + 30 tests (transform/)
                            │ tests fail → stop; the dashboard keeps the last good data
                            ▼ tests pass
                         data/marts/*.parquet ─► app.py (Streamlit + DuckDB + Altair)
```

- **Collection:** a scheduled job checks each company's public job board and saves every open matching role.
- **Transformation ([dbt](https://www.getdbt.com/), `transform/`):**

  ```
  source: raw.snapshots ─► stg_snapshots ─► int_location_states ─┐
  seeds: us_states, us_cities, non_us_places ────────────────────┴► fct_open_roles ─► agg_daily_roles
  ```

  Messy location text ("US, CA, Santa Clara", "San Diego, CALIFORNIA", "3 Locations (primary: …)") becomes a
  US state via lookup tables in `data/reference/` (84.6% of postings), with remote and non-US flags. Matching runs
  once per distinct location (905), not once per job per day, so builds stay fast as snapshots accumulate.
- **Data tests (30):** one row per job per day, no rows lost or duplicated by joins, every state is a real state
  code, lookup tables have no duplicates, and a warning if fewer than 90% of placed US postings get a state.
  They run on every new snapshot in [`.github/workflows/build.yml`](.github/workflows/build.yml); only data that
  passes is published to `data/marts/` (one Parquet file per day).
- **Dashboard:** DuckDB reads the Parquet marts in-process; there is no database server.

Build locally:

```bash
.venv/bin/pip install -r requirements-dbt.txt
cd transform && ../.venv/bin/dbt build --profiles-dir . && ../.venv/bin/python export_marts.py
```

To explore with SQL: `.venv/bin/python run_sql.py sql/03_locations.sql`

## Data

`data/snapshots/YYYY-MM-DD.csv.gz` — every open matching role on that day, one row per posting:

| column | meaning |
|---|---|
| snapshot_date | day the snapshot was taken (UTC) |
| company | employer |
| ats | hiring system the posting came from (greenhouse, lever, ashby, workday, …) |
| job_key | stable id for the posting (`ats:company:job_id`) |
| title | job title as posted |
| tracks | role type: Backend, Data, AI/ML (a title can have several) |
| location | location text as posted |
| country | country when the hiring system provides one |
| posted_at | posting date as reported by the hiring system (Workday gives day precision at best) |
| url | link to the posting |

All of it comes from the companies' public job boards.
