from __future__ import annotations

from typing import Any, Callable
from urllib.parse import urlparse

from src.http_util import parse_body, request_ctx, text_body
from src.response import Response


def azure(handler: Callable[[dict], Response]):
    import azure.functions as func

    app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

    def path_of(req: func.HttpRequest) -> str:
        if req.route_params.get("path"):
            return "/" + str(req.route_params["path"]).lstrip("/")
        path = urlparse(req.url or "").path or "/"
        return (path[4:] or "/") if path.startswith("/api") else path

    def body_of(req: func.HttpRequest) -> Any:
        try:
            return req.get_json()
        except ValueError:
            return parse_body(req.get_body())

    @app.route(route="{*path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
    def http_handler(req: func.HttpRequest) -> func.HttpResponse:
        resp = handler(
            request_ctx(req.method, path_of(req), dict(req.params), body_of(req), dict(req.headers))
        )
        return func.HttpResponse(
            body=text_body(resp),
            status_code=resp.status,
            mimetype=resp.headers.get("content-type", "application/json"),
        )

    return app
