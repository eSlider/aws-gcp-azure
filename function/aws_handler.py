from function.adapters.aws import entrypoint
from function.app import handle

handler = entrypoint(handle)
