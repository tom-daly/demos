"""One credential for everything. In Azure it is the user-assigned managed identity (AZURE_CLIENT_ID
makes DefaultAzureCredential pick it). On your machine it is whoever ran `az login`."""
from __future__ import annotations

from functools import lru_cache

from azure.identity import DefaultAzureCredential


@lru_cache(maxsize=1)
def credential() -> DefaultAzureCredential:
    return DefaultAzureCredential(exclude_interactive_browser_credential=True)
