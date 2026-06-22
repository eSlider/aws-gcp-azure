from __future__ import annotations

import base64
import json
from typing import Any, Callable

from function.response import Response, serialize_body


def _parse_body(event: dict) -> Any:
    body = event.get("body")
    if body is None:
        return None
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body)
    if isinstance(body, bytes):
        body = body.decode("utf-8")
    if isinstance(body, str) and body:
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            return body
    return body


def _ctx_from_event(event: dict) -> dict:
    path = event.get("rawPath") or event.get("path") or "/"
    return {
        "method": event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod", "GET"),
        "path": path,
        "query": event.get("queryStringParameters") or {},
        "body": _parse_body(event),
        "headers": event.get("headers") or {},
    }


def to_aws(resp: Response) -> dict:
    body = serialize_body(resp)
    if isinstance(body, bytes):
        return {
            "statusCode": resp.status,
            "headers": resp.headers,
            "body": base64.b64encode(body).decode("ascii"),
            "isBase64Encoded": True,
        }
    return {
        "statusCode": resp.status,
        "headers": resp.headers,
        "body": body,
    }


def entrypoint(handler: Callable[[dict], Response]):
    def aws_handler(event, context):
        return to_aws(handler(_ctx_from_event(event)))

    return aws_handler
