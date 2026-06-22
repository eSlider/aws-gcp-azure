from adapter import gcp
from src.app import handle

health = gcp(handle)
