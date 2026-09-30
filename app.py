"""Job Market Dashboard: open backend, data, and AI/ML engineering roles at ~220 tech companies.

Run locally:  streamlit run app.py
"""
from pathlib import Path

import altair as alt
import duckdb
import pandas as pd
import streamlit as st

ROOT = Path(__file__).parent

st.set_page_config(page_title="Job Market Dashboard", layout="wide")

# Colors are stepped separately for light and dark backgrounds (same hues, different lightness).
DARK = st.context.theme.type == "dark"
BLUE = "#3987e5" if DARK else "#2a78d6"   # single-series bars
LABEL = "#c3c2b7" if DARK else "#52514e"  # text beside marks uses text colors, never the series color
TRACKS = {  # label -> (fct_open_roles flag column, color); a track keeps its color in every chart
    "Backend": ("is_backend", "#3987e5" if DARK else "#2a78d6"),
    "AI/ML": ("is_ai_ml", "#d95926" if DARK else "#eb6834"),
    "Data": ("is_data", "#199e70" if DARK else "#1baf7a"),
}


@st.cache_resource
def connect() -> duckdb.DuckDBPyConnection:
    """Load the tested fct_open_roles mart (built by dbt in transform/) into memory once per server."""
    con = duckdb.connect()
    marts = ROOT / "data" / "marts" / "fct_open_roles" / "*" / "*.parquet"
    con.execute(f"CREATE TABLE jobs AS SELECT * FROM read_parquet('{marts}', hive_partitioning = true)")
    return con


def query(sql: str, params=None) -> pd.DataFrame:
    # A DuckDB connection isn't safe to share between threads; Streamlit serves each viewer on its own thread,
    # so each query gets its own cursor.
    return connect().cursor().execute(sql, params or []).df()


def hbar(df: pd.DataFrame, category: str, value: str, label: str) -> alt.Chart:
    """Horizontal bars, longest first, with a hover tooltip."""
    return (
        alt.Chart(df)
        .mark_bar(color=BLUE, cornerRadiusEnd=4, height={"band": 0.7})
        .encode(
            x=alt.X(f"{value}:Q", title=label, axis=alt.Axis(tickCount=5, format=",.0f")),
            y=alt.Y(f"{category}:N", sort="-x", title=None, axis=alt.Axis(labelOverlap=False, labelLimit=160)),
            tooltip=[alt.Tooltip(f"{category}:N"), alt.Tooltip(f"{value}:Q", title=label, format=",")],
        )
        .properties(height=max(120, 30 * len(df)))
    )


# ------------------------------------------------------------------ header and filters
st.title("Job Market Dashboard")
st.caption("Open backend, data, and AI/ML engineering roles at ~220 tech companies, "
           "collected every weekday from their public job boards.")

days = query("SELECT DISTINCT snapshot_date FROM jobs ORDER BY snapshot_date DESC")["snapshot_date"].dt.date.tolist()
f1, f2, f3, f4 = st.columns([1, 2, 1, 1])
day = f1.selectbox("Snapshot", days, index=0, format_func=lambda d: d.strftime("%b %d, %Y"))
tracks = f2.multiselect("Role type", list(TRACKS), default=list(TRACKS))
remote_only = f3.toggle("Remote only")
include_non_us = f4.toggle("Include non-US", help="A few postings outside the US get past the collector's filter.")

if not tracks:
    st.info("Pick at least one role type.")
    st.stop()

# Filters other than the day, so the trend chart can reuse them across all days.
filters = ["(" + " OR ".join(TRACKS[t][0] for t in tracks) + ")"]
if remote_only:
    filters.append("is_remote")
if not include_non_us:
    filters.append("is_us")
FILTERS = " AND ".join(filters)
WHERE = "snapshot_date = ? AND " + FILTERS
params = [day]

# ------------------------------------------------------------------ headline numbers
k = query(f"""
    SELECT count(*) AS roles, count(DISTINCT company) AS companies,
           avg(is_remote::INT) AS remote_share, mode(state) AS top_state
    FROM jobs WHERE {WHERE}""", params).iloc[0]
c1, c2, c3, c4 = st.columns(4)
c1.metric("Open roles", f"{k.roles:,}")
c2.metric("Companies hiring", f"{k.companies:,}")
c3.metric("Remote", f"{k.remote_share:.0%}" if k.roles else "–")
c4.metric("Top state", k.top_state or "–")

if not k.roles:
    st.warning("No roles match these filters.")
    st.stop()

# ------------------------------------------------------------------ who and where
left, right = st.columns(2)
with left:
    st.subheader("Who is hiring")
    top = query(f"SELECT company, count(*) AS roles FROM jobs WHERE {WHERE} "
                "GROUP BY company ORDER BY roles DESC, company LIMIT 15", params)
    st.altair_chart(hbar(top, "company", "roles", "Open roles"), width="stretch")
with right:
    st.subheader("Where")
    states = query(f"SELECT state, count(*) AS roles FROM jobs WHERE {WHERE} AND state IS NOT NULL "
                   "GROUP BY state ORDER BY roles DESC, state LIMIT 15", params)
    st.altair_chart(hbar(states, "state", "roles", "Open roles"), width="stretch")
    st.caption("Top 15 states by the first place each posting names. "
               "Postings that are remote-only or don't name a state aren't shown here.")

# ------------------------------------------------------------------ role types over time
st.subheader("Role types over time")
# One count per track per day; a job with two tracks counts in both.
trend = query(" UNION ALL ".join(
    f"SELECT snapshot_date, '{name}' AS track, count(*) AS roles FROM jobs WHERE {TRACKS[name][0]} AND {FILTERS} "
    "GROUP BY snapshot_date" for name in tracks) + " ORDER BY snapshot_date")
if trend["snapshot_date"].nunique() < 2:
    today = trend.set_index("track")["roles"]
    for col, name in zip(st.columns(len(tracks)), tracks):   # fixed track order, not query order
        col.metric(name, f"{today.get(name, 0):,}")
    st.caption("A job can count toward more than one role type. "
               "The trend chart appears once there are two or more days of snapshots.")
else:
    trend["day"] = trend["snapshot_date"].dt.strftime("%Y-%m-%d")   # one point per day; read as UTC dates
    color = alt.Color("track:N", title=None, legend=alt.Legend(orient="top"),
                      scale=alt.Scale(domain=list(TRACKS), range=[c for _, c in TRACKS.values()]))
    x = alt.X("utcyearmonthdate(day):T", title=None, axis=alt.Axis(format="%b %d", tickCount="day"))
    base = alt.Chart(trend).encode(x=x, y=alt.Y("roles:Q", title="Open roles", axis=alt.Axis(format=",.0f")))
    hover = alt.selection_point(fields=["day"], nearest=True, on="pointerover", empty=False)
    lines = base.mark_line(strokeWidth=2).encode(color=color)
    points = base.mark_point(size=64, filled=True).encode(
        color=color, opacity=alt.condition(hover, alt.value(1), alt.value(0)),
        tooltip=[alt.Tooltip("utcyearmonthdate(day):T", title="Day", format="%b %d, %Y"), "track:N",
                 alt.Tooltip("roles:Q", format=",")],
    ).add_params(hover)
    rule = base.mark_rule(color="#999").encode(opacity=alt.condition(hover, alt.value(0.6), alt.value(0)))
    ends = alt.Chart(trend).transform_window(rank="rank()", sort=[alt.SortField("day", order="descending")],
                                             groupby=["track"]).transform_filter("datum.rank == 1")
    labels = ends.mark_text(align="left", dx=8, color=LABEL).encode(x=x, y="roles:Q", text="track:N")
    chart = (lines + rule + points + labels).properties(height=320, padding={"right": 64})
    st.altair_chart(chart, width="stretch")
    st.caption("A job can count toward more than one role type.")

# ------------------------------------------------------------------ the postings themselves
st.subheader("Postings")
search = st.text_input("Search company or title", placeholder="e.g. Databricks, data engineer")
table = query(f"""
    SELECT company, title, location, state, tracks AS "role type", posted_at::DATE AS posted, url
    FROM jobs WHERE {WHERE}
      AND (? = '' OR company ILIKE '%' || ? || '%' OR title ILIKE '%' || ? || '%')
    ORDER BY posted DESC NULLS LAST, company""", params + [search, search, search])
st.dataframe(table, hide_index=True, width="stretch",
             column_config={"url": st.column_config.LinkColumn("link", display_text="open"),
                            "posted": st.column_config.DateColumn("posted", format="MMM D, YYYY")})
st.caption(f"{len(table):,} postings. Source: companies' public job boards (Greenhouse, Lever, Ashby, "
           "SmartRecruiters, Workday, and others). Posting dates from Workday are approximate.")
