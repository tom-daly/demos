"""Blob and queue access with the managed identity. No connection strings."""
from __future__ import annotations

import json
from functools import lru_cache
from typing import Any

from azure.storage.blob import BlobServiceClient, ContentSettings
from azure.storage.queue import BinaryBase64EncodePolicy, QueueClient

from .config import settings
from .credential import credential


@lru_cache(maxsize=1)
def _blobs() -> BlobServiceClient:
    return BlobServiceClient(settings().blob_url, credential=credential())


def put_blob(container: str, name: str, data: bytes, content_type: str = "application/octet-stream") -> str:
    client = _blobs().get_blob_client(container, name)
    client.upload_blob(data, overwrite=True, content_settings=ContentSettings(content_type=content_type))
    return client.url


def get_blob(container: str, name: str) -> bytes:
    return _blobs().get_blob_client(container, name).download_blob().readall()


def put_json(container: str, name: str, payload: dict[str, Any]) -> str:
    return put_blob(container, name, json.dumps(payload, indent=2, default=str).encode("utf-8"), "application/json")


@lru_cache(maxsize=1)
def _queue() -> QueueClient:
    # The Functions host decodes base64 by default, so encode the same way when we enqueue ourselves.
    return QueueClient(settings().queue_url, settings().queue_name, credential=credential(),
                       message_encode_policy=BinaryBase64EncodePolicy())


def enqueue(message: dict[str, Any]) -> None:
    _queue().send_message(json.dumps(message).encode("utf-8"))
