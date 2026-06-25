from typing import List

from infra.aws.python.blob import S3BlobStore

class Solution:
    def twoSum(self, nums: List[int], target: int) -> list[int] | None:
        seen = {}
        for i, n in enumerate(nums):
            if (c := target - n) in seen: return [seen[c], i]
            seen[n] = i



def test_s3_from_uri_and_duckdb_glob():
    store = S3BlobStore.from_uri("s3://my-bucket/events/prefix")
    json_dd = store.duckdb_glob("**/*.json") == "s3://my-bucket/events/prefix/**/*.json"
    assert json_dd
