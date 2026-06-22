from __future__ import annotations

import json
from typing import Any, Callable

import functions_framework

from function.response import Response, serialize_body


def _ctx_from_request(req) -> dict:
    body = req.get_data(as_text=True)
    parsed: Any = None
    if body:
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = body
    return {
        "method": req.method,
        "path": req.path,
        "query": req.args.to_dict(),
        "body": parsed,
        "headers": dict(req.headers),
    }


def to_gcp(resp: Response):
    body = serialize_body(resp)
    if isinstance(body, bytes):
        body = body.decode("utf-8")
    return body, resp.status, resp.headers


def entrypoint(handler: Callable[[dict], Response]):
    @functions_framework.http
    def gcp_entry(request):
        return to_gcp(handler(_ctx_from_request(request)))

    return gcp_entry
