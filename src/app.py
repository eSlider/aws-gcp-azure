from src.events import ingest_webhook, receive_peer_event
from src.peers import list_peers
from src.response import Response, json_ok, with_errors


@with_errors
def handle(ctx: dict) -> Response:
    path = ctx.get("path", "/")
    method = ctx.get("method", "GET")

    if path == "/health" and method == "GET":
        return json_ok({"status": "ok"})
    if path == "/peers" and method == "GET":
        return json_ok(list_peers())
    if path.startswith("/webhook/"):
        if method != "POST":
            return Response(raw={"error": "method not allowed"}, status=405)
        return ingest_webhook(ctx)
    if path == "/internal/event" and method == "POST":
        return receive_peer_event(ctx)
    if path == "/query" and method == "GET":
        import query

        return json_ok(query.run(ctx.get("query") or {}))

    return Response(raw={"error": "not found"}, status=404)
