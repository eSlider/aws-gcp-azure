from __future__ import annotations

import os
from typing import Protocol


class BlobStore(Protocol):
    def put(self, key: str, body: bytes, *, content_type: str = "application/json") -> str: ...
    def duckdb_glob(self, glob: str) -> str | None: ...


def _object_key(prefix: str, key: str) -> str:
    return f"{prefix.rstrip('/')}/{key}" if prefix else key


class GCSBlobStore:
    def __init__(self, bucket: str, prefix: str = "") -> None:
        self._bucket = bucket
        self._prefix = prefix

    @classmethod
    def from_uri(cls, uri: str) -> GCSBlobStore:
        _, _, rest = uri.partition("gs://")
        bucket, _, prefix = rest.partition("/")
        return cls(bucket, prefix)

    def put(self, key: str, body: bytes, *, content_type: str = "application/json") -> str:
        from google.cloud import storage

        blob_name = _object_key(self._prefix, key)
        storage.Client().bucket(self._bucket).blob(blob_name).upload_from_string(
            body, content_type=content_type
        )
        return blob_name

    def duckdb_glob(self, glob: str) -> str | None:
        return None


def from_env() -> BlobStore:
    uri = os.environ.get("BLOB_URI", "")
    if not uri:
        raise RuntimeError("BLOB_URI not configured")
    if not uri.startswith("gs://"):
        raise RuntimeError(f"expected gs:// BLOB_URI, got: {uri}")
    return GCSBlobStore.from_uri(uri)
