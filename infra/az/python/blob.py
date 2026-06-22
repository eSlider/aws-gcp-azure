from __future__ import annotations

import os
from typing import Protocol


class BlobStore(Protocol):
    def put(self, key: str, body: bytes, *, content_type: str = "application/json") -> str: ...
    def duckdb_glob(self, glob: str) -> str | None: ...


class AzureBlobStore:
    def __init__(self, container: str, connection_string: str) -> None:
        self._container = container
        self._connection_string = connection_string

    @classmethod
    def from_uri(cls, uri: str) -> AzureBlobStore:
        parts = uri.replace("https://", "").split("/")
        container = parts[1] if len(parts) > 1 else "events"
        conn = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
        if not conn:
            raise RuntimeError("AZURE_STORAGE_CONNECTION_STRING required for Azure blob writes")
        return cls(container, conn)

    def put(self, key: str, body: bytes, *, content_type: str = "application/json") -> str:
        from azure.storage.blob import BlobServiceClient

        BlobServiceClient.from_connection_string(self._connection_string).get_blob_client(
            container=self._container, blob=key
        ).upload_blob(body, overwrite=True)
        return key

    def duckdb_glob(self, glob: str) -> str | None:
        return None


def from_env() -> BlobStore:
    uri = os.environ.get("BLOB_URI", "")
    if not uri:
        raise RuntimeError("BLOB_URI not configured")
    if ".blob.core.windows.net" not in uri:
        raise RuntimeError(f"expected Azure blob BLOB_URI, got: {uri}")
    return AzureBlobStore.from_uri(uri)
