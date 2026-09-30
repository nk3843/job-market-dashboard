"""Run each statement in a .sql file with DuckDB and print the results.  Usage: python run_sql.py sql/01_explore.sql"""
import sys

import duckdb

con = duckdb.connect()
for statement in con.extract_statements(open(sys.argv[1], encoding="utf-8").read()):
    result = con.sql(statement.query)
    if result is not None:
        result.show(max_width=140)
