import azure.functions as func

from function.adapters.azure import register
from function.app import handle

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)
register(app, handle)
