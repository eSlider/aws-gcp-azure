from __future__ import annotations

import json
import os
from typing import Any
from urllib import error, request


def cloud() -> str:
    return os.environ.get("LAMBDA_CLOUD", "unknown")


def peer_urls() -> list[str]:
    try:
        urls = json.loads(os.environ.get("LAMBDA_PEER_URLS", "[]"))
        return [u for u in urls if isinstance(u, str) and u]
    except json.JSONDecodeError:
        return []


def list_peers() -> dict[str, Any]:
    return {"cloud": cloud(), "peers": peer_urls()}


def notify(summary: dict[str, Any]) -> None:
    payload = json.dumps(summary).encode("utf-8")
    for base in peer_urls():
        req = request.Request(
            f"{base.rstrip('/')}/internal/event",
            data=payload,
            headers={"content-type": "application/json"},
            method="POST",
        )
        try:
            request.urlopen(req, timeout=3)
        except error.URLError:
            pass
