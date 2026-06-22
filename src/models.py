from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4


@dataclass
class EventRecord:
    id: str
    source: str
    cloud: str
    received_at: str
    payload: dict[str, Any]

    @classmethod
    def new(cls, source: str, cloud: str, payload: dict[str, Any]) -> EventRecord:
        return cls(
            id=str(uuid4()),
            source=source,
            cloud=cloud,
            received_at=datetime.now(timezone.utc).isoformat(),
            payload=payload,
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "source": self.source,
            "cloud": self.cloud,
            "received_at": self.received_at,
            "payload": self.payload,
        }


def hive_key(source: str, event_id: str, ts: datetime) -> str:
    return (
        f"events/source={source}/"
        f"year={ts.year:04d}/month={ts.month:02d}/day={ts.day:02d}/"
        f"hour={ts.hour:02d}/{event_id}.json"
    )
