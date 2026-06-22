from __future__ import annotations

import json

from src.models import EventRecord
from src.peers import cloud, notify
from src.response import Response, json_ok


def ingest_webhook(ctx: dict) -> Response:
    parts = ctx["path"].strip("/").split("/")
    if len(parts) < 2:
        return Response(raw={"error": "source required"}, status=400)

    body = ctx.get("body")
    if isinstance(body, dict):
        payload = body
    elif isinstance(body, str):
        payload = json.loads(body) if body else {}
    else:
        payload = {}

    source = parts[1]
    c = cloud()
    record = EventRecord.new(source=source, cloud=c, payload=payload)
    import storage

    key = storage.write_event(record)
    notify({"id": record.id, "source": source, "cloud": c, "key": key})
    return json_ok({"stored": True, "id": record.id, "key": key}, status=201)


def receive_peer_event(ctx: dict) -> Response:
    return json_ok({"received": True, "event": ctx.get("body") or {}})
