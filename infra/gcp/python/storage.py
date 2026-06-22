from __future__ import annotations

import json
from datetime import datetime

from blob import from_env
from src.models import EventRecord, hive_key


def write_event(record: EventRecord) -> str:
    store = from_env()
    key = hive_key(record.source, record.id, datetime.fromisoformat(record.received_at))
    body = json.dumps(record.to_dict()).encode("utf-8")
    return store.put(key, body)
