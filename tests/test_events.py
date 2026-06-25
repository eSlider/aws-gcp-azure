import json
import sys
import types
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from src.events import ingest_webhook, receive_peer_event
from src.models import EventRecord
from src.response import serialize_body


@pytest.fixture
def storage_stub(monkeypatch):
    calls: list[EventRecord] = []

    def write_event(record: EventRecord) -> str:
        calls.append(record)
        return f"events/source={record.source}/{record.id}.json"

    monkeypatch.setitem(
        sys.modules,
        "storage",
        types.SimpleNamespace(write_event=write_event),
    )
    return calls


@pytest.fixture
def notify_stub(monkeypatch):
    calls: list[dict] = []
    monkeypatch.setattr("src.events.notify", lambda summary: calls.append(summary))
    return calls


def test_ingest_webhook_missing_source():
    r = ingest_webhook({"path": "/webhook"})
    assert r.status == 400
    assert r.raw == {"error": "source required"}


def test_ingest_webhook_stores_event_dict_body(storage_stub, notify_stub, monkeypatch):
    monkeypatch.setenv("LAMBDA_CLOUD", "aws")

    r = ingest_webhook({
        "path": "/webhook/stripe",
        "body": {"type": "charge.succeeded", "amount": 100},
    })

    assert r.status == 201
    body = json.loads(serialize_body(r))
    assert body["stored"] is True
    assert body["key"] == f"events/source=stripe/{body['id']}.json"

    assert len(storage_stub) == 1
    record = storage_stub[0]
    assert record.source == "stripe"
    assert record.cloud == "aws"
    assert record.payload == {"type": "charge.succeeded", "amount": 100}

    assert notify_stub == [{
        "id": record.id,
        "source": "stripe",
        "cloud": "aws",
        "key": body["key"],
    }]


def test_ingest_webhook_parses_json_string_body(storage_stub, notify_stub, monkeypatch):
    monkeypatch.setenv("LAMBDA_CLOUD", "gcp")

    r = ingest_webhook({
        "path": "/webhook/github",
        "body": '{"action": "opened"}',
    })

    assert r.status == 201
    assert storage_stub[0].source == "github"
    assert storage_stub[0].cloud == "gcp"
    assert storage_stub[0].payload == {"action": "opened"}
    assert notify_stub[0]["source"] == "github"


def test_ingest_webhook_empty_body(storage_stub, notify_stub):
    r = ingest_webhook({"path": "/webhook/ping", "body": ""})

    assert r.status == 201
    assert storage_stub[0].payload == {}
    assert notify_stub[0]["source"] == "ping"


def test_ingest_webhook_none_body(storage_stub):
    r = ingest_webhook({"path": "/webhook/ping", "body": None})

    assert r.status == 201
    assert storage_stub[0].payload == {}


def test_receive_peer_event_defaults_empty_body():
    r = receive_peer_event({"body": None})

    assert r.status == 200
    assert json.loads(serialize_body(r)) == {"received": True, "event": {}}


def test_receive_peer_event_passes_body_through():
    event = {"id": "evt-1", "source": "stripe", "cloud": "aws"}

    r = receive_peer_event({"body": event})

    assert r.status == 200
    assert json.loads(serialize_body(r)) == {"received": True, "event": event}
