from __future__ import annotations

from typing import Callable

from src.http_util import parse_body, request_ctx, text_body
from src.response import Response, serialize_body


def aws(handler: Callable[[dict], Response]):
    def entry(event: dict, _context) -> dict:
        http = event.get("requestContext", {}).get("http", {})
        ctx = request_ctx(
            http.get("method") or event.get("httpMethod", "GET"),
            event.get("rawPath") or event.get("path") or "/",
            event.get("queryStringParameters") or {},
            parse_body(event.get("body"), b64=event.get("isBase64Encoded", False)),
            event.get("headers") or {},
        )
        resp = handler(ctx)
        body = serialize_body(resp)
        if isinstance(body, bytes):
            import base64

            return {
                "statusCode": resp.status,
                "headers": resp.headers,
                "body": base64.b64encode(body).decode("ascii"),
                "isBase64Encoded": True,
            }
        return {"statusCode": resp.status, "headers": resp.headers, "body": body}

    return entry
