from __future__ import annotations

import base64
import json
from typing import Any

from src.response import Response, serialize_body


def parse_body(raw: Any, *, b64: bool = False) -> Any:
    if raw is None:
        return None
    if b64:
        raw = base64.b64decode(raw)
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8")
    if isinstance(raw, str) and raw:
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw
    return raw


def request_ctx(
    method: str,
    path: str,
    query: dict | None,
    body: Any,
    headers: dict | None,
) -> dict:
    return {
        "method": method,
        "path": path,
        "query": query or {},
        "body": body,
        "headers": headers or {},
    }


def text_body(resp: Response) -> str:
    body = serialize_body(resp)
    return body.decode("utf-8") if isinstance(body, bytes) else body
