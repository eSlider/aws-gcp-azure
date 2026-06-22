import functions_framework


@functions_framework.http
def health(request):
    return {"status": "ok"}, 200, {"Content-Type": "application/json"}
