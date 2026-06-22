from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Any
from urllib import error, request

from function.events.partition import hive_key
from function.events.schema import EventRecord
from function.response import Response, json_ok


def _cloud() -> str:
    return os.environ.get("LAMBDA_CLOUD", "unknown")


def _peer_urls() -> list[str]:
    raw = os.environ.get("LAMBDA_PEER_URLS", "[]")
    try:
        urls = json.loads(raw)
        return [u for u in urls if isinstance(u, str) and u]
    except json.JSONDecodeError:
        return []


def list_peers() -> dict[str, Any]:
    return {"cloud": _cloud(), "peers": _peer_urls()}


def write_event(record: EventRecord) -> str:
    """Write JSON to blob storage. Returns object key."""
    blob_uri = os.environ.get("BLOB_URI", "")
    if not blob_uri:
        raise RuntimeError("BLOB_URI not configured")

    ts = datetime.fromisoformat(record.received_at)
    key = hive_key(record.source, record.id, ts)
    body = json.dumps(record.to_dict()).encode("utf-8")

    if blob_uri.startswith("s3://"):
        import boto3

        _, _, rest = blob_uri.partition("s3://")
        bucket, _, prefix = rest.partition("/")
        obj_key = f"{prefix.rstrip('/')}/{key}" if prefix else key
        boto3.client("s3").put_object(Bucket=bucket, Key=obj_key, Body=body, ContentType="application/json")
        return obj_key

    if blob_uri.startswith("gs://"):
        from google.cloud import storage

        _, _, rest = blob_uri.partition("gs://")
        bucket_name, _, prefix = rest.partition("/")
        blob_name = f"{prefix.rstrip('/')}/{key}" if prefix else key
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        bucket.blob(blob_name).upload_from_string(body, content_type="application/json")
        return blob_name

    if ".blob.core.windows.net" in blob_uri:
        from azure.storage.blob import BlobServiceClient

        # https://account.blob.core.windows.net/container
        parts = blob_uri.replace("https://", "").split("/")
        account_host = parts[0]
        container = parts[1] if len(parts) > 1 else "events"
        conn = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
        if not conn:
            raise RuntimeError("AZURE_STORAGE_CONNECTION_STRING required for Azure blob writes")
        client = BlobServiceClient.from_connection_string(conn)
        blob_name = f"{key}"
        client.get_blob_client(container=container, blob=blob_name).upload_blob(body, overwrite=True)
        return blob_name

    raise RuntimeError(f"unsupported BLOB_URI scheme: {blob_uri}")


def notify_peers(summary: dict[str, Any]) -> None:
    payload = json.dumps(summary).encode("utf-8")
    for base in _peer_urls():
        url = f"{base.rstrip('/')}/internal/event"
        req = request.Request(
            url,
            data=payload,
            headers={"content-type": "application/json"},
            method="POST",
        )
        try:
            request.urlopen(req, timeout=3)
        except error.URLError:
            pass  # ponytail: fire-and-forget


def ingest_webhook(ctx: dict) -> Response:
    parts = ctx["path"].strip("/").split("/")
    if len(parts) < 2:
        return Response(raw={"error": "source required"}, status=400)
    source = parts[1]
    body = ctx.get("body")
    if body is None:
        payload: dict[str, Any] = {}
    elif isinstance(body, dict):
        payload = body
    elif isinstance(body, str):
        payload = json.loads(body) if body else {}
    else:
        payload = {}

    record = EventRecord.new(source=source, cloud=_cloud(), payload=payload)
    key = write_event(record)
    summary = {"id": record.id, "source": source, "cloud": _cloud(), "key": key}
    notify_peers(summary)
    return json_ok({"stored": True, "id": record.id, "key": key}, status=201)


def receive_peer_event(ctx: dict) -> Response:
    return json_ok({"received": True, "event": ctx.get("body") or {}})


def query_events(query: dict) -> dict[str, Any]:
    source = query.get("source")
    date = query.get("date")
    if not source or not date:
        raise ValueError("source and date query params required")

    blob_uri = os.environ.get("BLOB_URI", "")
    if not blob_uri:
        raise RuntimeError("BLOB_URI not configured")

    year, month, day = date.split("-")
    glob = (
        f"events/source={source}/year={year}/month={month}/day={day}/**/*.json"
    )

    try:
        import duckdb
    except ImportError:
        return {"error": "duckdb not available", "glob": glob}

    con = duckdb.connect()
    try:
        if blob_uri.startswith("s3://"):
            con.execute("INSTALL httpfs; LOAD httpfs;")
            path = f"{blob_uri.rstrip('/')}/{glob}"
            rows = con.execute(
                "SELECT * FROM read_json_auto(?)", [path]
            ).fetchall()
            cols = [d[0] for d in con.description]
            return {"rows": [dict(zip(cols, row)) for row in rows]}
        return {"error": "query supported on s3:// BLOB_URI only for now", "glob": glob}
    finally:
        con.close()
