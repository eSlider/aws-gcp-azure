from __future__ import annotations

import os
from typing import Protocol


class BlobStore(Protocol):
    def put(self, key: str, body: bytes, *, content_type: str = "application/json") -> str: ...
    def duckdb_glob(self, glob: str) -> str | None: ...


def _object_key(prefix: str, key: str) -> str:
    return f"{prefix.rstrip('/')}/{key}" if prefix else key


class S3BlobStore:
    def __init__(self, bucket: str, prefix: str = "") -> None:
        self._bucket = bucket
        self._prefix = prefix

    @classmethod
    def from_uri(cls, uri: str) -> S3BlobStore:
        _, _, rest = uri.partition("s3://")
        bucket, _, prefix = rest.partition("/")
        return cls(bucket, prefix)

    def put(self, key: str, body: bytes, *, content_type: str = "application/json") -> str:
        import boto3

        obj_key = _object_key(self._prefix, key)
        boto3.client("s3").put_object(
            Bucket=self._bucket, Key=obj_key, Body=body, ContentType=content_type
        )
        return obj_key

    def duckdb_glob(self, glob: str) -> str | None:
        base = f"s3://{self._bucket}"
        if self._prefix:
            base = f"{base}/{self._prefix.rstrip('/')}"
        return f"{base}/{glob}"


def from_env() -> BlobStore:
    uri = os.environ.get("BLOB_URI", "")
    if not uri:
        raise RuntimeError("BLOB_URI not configured")
    if not uri.startswith("s3://"):
        raise RuntimeError(f"expected s3:// BLOB_URI, got: {uri}")
    return S3BlobStore.from_uri(uri)
