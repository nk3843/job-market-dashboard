# Job Market Dashboard

Tracks open backend, data, and AI/ML engineering roles at ~220 tech companies, one snapshot per weekday,
and turns them into hiring trends: who is hiring, for what, and where.

*Work in progress.*

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
