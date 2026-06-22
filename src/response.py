from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class Response:
    raw: Any
    status: int = 200
    headers: dict[str, str] = field(
        default_factory=lambda: {"content-type": "application/json"}
    )


def serialize_body(resp: Response) -> str | bytes:
    if isinstance(resp.raw, bytes):
        return resp.raw
    if isinstance(resp.raw, str):
        return resp.raw
    content_type = resp.headers.get("content-type", "application/json")
    if "json" in content_type and isinstance(resp.raw, (dict, list)):
        return json.dumps(resp.raw)
    return str(resp.raw)


def json_ok(raw: dict, status: int = 200) -> Response:
    return Response(raw=raw, status=status)


def error_response(exc: Exception, *, status: int = 500) -> Response:
    return Response(
        raw={"error": str(exc), "type": exc.__class__.__name__},
        status=status,
    )


def with_errors(handler):
    def wrapped(ctx: dict) -> Response:
        try:
            resp = handler(ctx)
            if not isinstance(resp, Response):
                raise TypeError("handler must return Response")
            return resp
        except Exception as exc:  # ponytail: boundary handler
            return error_response(exc)

    return wrapped
