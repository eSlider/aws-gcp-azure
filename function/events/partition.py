from __future__ import annotations

from datetime import datetime


def hive_key(source: str, event_id: str, ts: datetime) -> str:
    return (
        f"events/source={source}/"
        f"year={ts.year:04d}/month={ts.month:02d}/day={ts.day:02d}/"
        f"hour={ts.hour:02d}/{event_id}.json"
    )
