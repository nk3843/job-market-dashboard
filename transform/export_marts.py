"""Export the dbt marts as Parquet files for the dashboard. Run from transform/ after `dbt build`.

  data/marts/fct_open_roles/snapshot_date=YYYY-MM-DD/data.parquet   one file per snapshot day
  data/marts/agg_daily_roles.parquet

A file is only rewritten when its contents change (output is byte-identical for identical data), so a new day
adds one small file to git instead of rewriting everything.
"""
import os
import shutil
import tempfile

import duckdb

DB = "../build/jobs.duckdb"
OUT = "../data/marts"


def write_if_changed(con, query: str, target: str) -> bool:
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        staged = os.path.join(tmp, "data.parquet")
        con.execute(f"COPY ({query}) TO '{staged}' (FORMAT parquet, COMPRESSION zstd)")
        if os.path.exists(target):
            with open(staged, "rb") as new, open(target, "rb") as old:
                if new.read() == old.read():
                    return False
        shutil.move(staged, target)
    return True


def main() -> None:
    con = duckdb.connect(DB, read_only=True)
    facts = os.path.join(OUT, "fct_open_roles")
    days = [d.isoformat() for (d,) in con.execute(
        "SELECT DISTINCT snapshot_date FROM fct_open_roles ORDER BY 1").fetchall()]
    changed = 0
    for day in days:
        # snapshot_date lives in the folder name (hive partitioning), so it is left out of the file itself
        query = (f"SELECT * EXCLUDE (snapshot_date) FROM fct_open_roles "
                 f"WHERE snapshot_date = DATE '{day}' ORDER BY snapshot_job_id")
        changed += write_if_changed(con, query, os.path.join(facts, f"snapshot_date={day}", "data.parquet"))
    for folder in os.listdir(facts):   # drop days that are no longer in the source
        if folder.startswith("snapshot_date=") and folder.split("=", 1)[1] not in days:
            shutil.rmtree(os.path.join(facts, folder))
            changed += 1
    changed += write_if_changed(con, "SELECT * FROM agg_daily_roles ORDER BY snapshot_date, track",
                                os.path.join(OUT, "agg_daily_roles.parquet"))
    print(f"{len(days)} day(s) exported, {changed} file(s) changed")


if __name__ == "__main__":
    main()
