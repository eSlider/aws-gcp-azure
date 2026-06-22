from __future__ import annotations

from typing import Callable

from src.http_util import parse_body, request_ctx, text_body
from src.response import Response


def gcp(handler: Callable[[dict], Response]):
    import functions_framework

    @functions_framework.http
    def health(request):
        ctx = request_ctx(
            request.method,
            request.path,
            request.args.to_dict(),
            parse_body(request.get_data(as_text=True) or None),
            dict(request.headers),
        )
        resp = handler(ctx)
        return text_body(resp), resp.status, resp.headers

    return health
