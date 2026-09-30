"""Run the statements in one or more .sql files, in order, on one DuckDB connection, printing any results.

Usage: python run_sql.py sql/models/stg_jobs.sql sql/03_locations.sql
"""
import sys

import duckdb

con = duckdb.connect()
for path in sys.argv[1:]:
    for statement in con.extract_statements(open(path, encoding="utf-8").read()):
        result = con.sql(statement.query)
        if result is not None:
            result.show(max_width=140)
