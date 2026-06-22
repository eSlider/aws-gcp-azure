from function.adapters.gcp import entrypoint
from function.app import handle

health = entrypoint(handle)
