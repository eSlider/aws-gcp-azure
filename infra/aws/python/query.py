from __future__ import annotations

from typing import Any

from blob import from_env


def run(query: dict) -> dict[str, Any]:
    source, date = query.get("source"), query.get("date")
    if not source or not date:
        raise ValueError("source and date query params required")

    year, month, day = date.split("-")
    glob = f"events/source={source}/year={year}/month={month}/day={day}/**/*.json"

    store = from_env()
    path = store.duckdb_glob(glob)
    if not path:
        return {"error": "query not supported for this BLOB_URI", "glob": glob}

    try:
        import duckdb
    except ImportError:
        return {"error": "duckdb not available", "glob": glob}

    con = duckdb.connect()
    try:
        con.execute("INSTALL httpfs; LOAD httpfs;")
        rows = con.execute("SELECT * FROM read_json_auto(?)", [path]).fetchall()
        cols = [d[0] for d in con.description]
        return {"rows": [dict(zip(cols, row)) for row in rows]}
    finally:
        con.close()
