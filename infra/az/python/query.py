from __future__ import annotations

from typing import Any


def run(query: dict) -> dict[str, Any]:
    return {"error": "query not supported on Azure yet", "query": query}
