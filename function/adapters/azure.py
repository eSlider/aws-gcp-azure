from __future__ import annotations

import json
from typing import Any, Callable

import azure.functions as func

from function.response import Response, serialize_body


def _mimetype(headers: dict[str, str]) -> str:
    return headers.get("content-type", "application/json")


def to_azure(resp: Response) -> func.HttpResponse:
    body = serialize_body(resp)
    if isinstance(body, bytes):
        body = body.decode("utf-8")
    return func.HttpResponse(
        body=body,
        status_code=resp.status,
        mimetype=_mimetype(resp.headers),
    )


def _ctx_from_request(req: func.HttpRequest) -> dict:
    parsed: Any = None
    try:
        parsed = req.get_json()
    except ValueError:
        raw = req.get_body()
        if raw:
            try:
                parsed = json.loads(raw.decode("utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError):
                parsed = raw.decode("utf-8", errors="replace")
    return {
        "method": req.method,
        "path": "/" + (req.route_params.get("path") or req.url.split("api", 1)[-1]),
        "query": dict(req.params),
        "body": parsed,
        "headers": dict(req.headers),
    }


def register(app: func.FunctionApp, handler: Callable[[dict], Response], route: str = "{*path}"):
    @app.route(route=route, methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
    def http_handler(req: func.HttpRequest) -> func.HttpResponse:
        path = "/"
        if "path" in req.route_params and req.route_params["path"]:
            path = "/" + req.route_params["path"].lstrip("/")
        elif req.url:
            from urllib.parse import urlparse
            path = urlparse(req.url).path or "/"
            if path.startswith("/api"):
                path = path[4:] or "/"
        ctx = {
            "method": req.method,
            "path": path,
            "query": dict(req.params),
            "body": _parse_body(req),
            "headers": dict(req.headers),
        }
        return to_azure(handler(ctx))

    return app


def _parse_body(req: func.HttpRequest):
    parsed: Any = None
    try:
        parsed = req.get_json()
    except ValueError:
        raw = req.get_body()
        if raw:
            try:
                parsed = json.loads(raw.decode("utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError):
                parsed = raw.decode("utf-8", errors="replace")
    return parsed
