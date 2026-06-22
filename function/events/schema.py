from __future__ import annotations

from dataclasses import dataclass, field
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
