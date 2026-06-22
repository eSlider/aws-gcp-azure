import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "infra/aws/python"))

from blob import S3BlobStore


def test_s3_from_uri_and_duckdb_glob():
    store = S3BlobStore.from_uri("s3://my-bucket/events/prefix")
    assert store.duckdb_glob("**/*.json") == "s3://my-bucket/events/prefix/**/*.json"
