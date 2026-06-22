import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from src.app import handle
from src.models import EventRecord, hive_key
from src.response import error_response, json_ok, serialize_body


def test_json_ok_defaults():
    r = json_ok({"status": "ok"})
    assert r.status == 200
    assert r.headers["content-type"] == "application/json"
    assert serialize_body(r) == '{"status": "ok"}'


def test_error_response():
    r = error_response(ValueError("boom"))
    assert r.status == 500
    body = json.loads(serialize_body(r))
    assert body["error"] == "boom"
    assert body["type"] == "ValueError"


def test_hive_key_format():
    ts = datetime(2026, 6, 22, 10, 30, tzinfo=timezone.utc)
    key = hive_key("stripe", "evt-1", ts)
    assert key == "events/source=stripe/year=2026/month=06/day=22/hour=10/evt-1.json"


def test_event_record_roundtrip():
    rec = EventRecord.new("github", "gcp", {"action": "opened"})
    data = rec.to_dict()
    assert data["source"] == "github"
    assert data["cloud"] == "gcp"
    assert data["payload"]["action"] == "opened"


def test_health_route():
    r = handle({"method": "GET", "path": "/health", "query": {}, "body": None, "headers": {}})
    assert r.status == 200
    assert json.loads(serialize_body(r)) == {"status": "ok"}


def test_not_found():
    r = handle({"method": "GET", "path": "/nope", "query": {}, "body": None, "headers": {}})
    assert r.status == 404


def test_webhook_requires_post():
    r = handle({
        "method": "GET",
        "path": "/webhook/stripe",
        "query": {},
        "body": None,
        "headers": {},
    })
    assert r.status == 405
