"""Table storage: the delta link, the subscription, "already seen" rows, and a few cached ids.

Azure Table Storage has no row expiry, so every row that should not live forever carries an
ExpiresAt column and sweep() deletes the ones past it. The housekeeping timer calls it.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from typing import Any, Iterable

from azure.core.exceptions import ResourceExistsError, ResourceNotFoundError
from azure.data.tables import TableClient, TableServiceClient, UpdateMode

from .config import settings
from .credential import credential

log = logging.getLogger(__name__)

# Partition keys in the State table
PK_DELTA = "delta"
PK_SUBSCRIPTION = "subscription"
PK_SEEN = "seen"
PK_CONFIG = "config"


def now() -> datetime:
    return datetime.now(timezone.utc)


def expires_in(**delta: float) -> datetime:
    return now() + timedelta(**delta)


@lru_cache(maxsize=1)
def _service() -> TableServiceClient:
    return TableServiceClient(endpoint=settings().table_url, credential=credential())


def state() -> TableClient:
    return _service().get_table_client(settings().state_table)


def _safe_key(value: str) -> str:
    # Table keys may not contain / \ # ? or control characters.
    return "".join("_" if c in '/\\#?' or ord(c) < 32 else c for c in value)[:255]


def get(table: TableClient, pk: str, rk: str) -> dict[str, Any] | None:
    try:
        return dict(table.get_entity(pk, _safe_key(rk)))
    except ResourceNotFoundError:
        return None


def upsert(table: TableClient, pk: str, rk: str, **fields: Any) -> None:
    entity = {"PartitionKey": pk, "RowKey": _safe_key(rk), **fields}
    table.upsert_entity(entity, mode=UpdateMode.MERGE)


# --- delta ------------------------------------------------------------------

def get_delta_link(drive_id: str) -> str | None:
    row = get(state(), PK_DELTA, drive_id)
    return row.get("DeltaLink") if row else None


def set_delta_link(drive_id: str, link: str) -> None:
    upsert(state(), PK_DELTA, drive_id, DeltaLink=link, UpdatedAt=now())


# --- seen (idempotency) -----------------------------------------------------
# One row per (file, version). It is *claimed* at scan time with an insert, which fails if the row
# already exists: two scans racing (a notification and the timer at the same moment) then cannot
# both queue the same file. It is marked done when processing finishes.

def claim(item_id: str, etag: str, *, days: int = 7) -> bool:
    """True if this file version was not on record and is now claimed for processing."""
    try:
        state().create_entity({"PartitionKey": PK_SEEN, "RowKey": _safe_key(f"{item_id}:{etag}"),
                               "Status": "queued", "QueuedAt": now(), "ExpiresAt": expires_in(days=days)})
        return True
    except ResourceExistsError:
        return False


def is_done(item_id: str, etag: str) -> bool:
    row = get(state(), PK_SEEN, f"{item_id}:{etag}")
    return bool(row) and row.get("Status") == "done"


def mark_seen(item_id: str, etag: str, *, days: int = 7) -> None:
    upsert(state(), PK_SEEN, f"{item_id}:{etag}", Status="done", ProcessedAt=now(), ExpiresAt=expires_in(days=days))


# --- subscription -----------------------------------------------------------

def get_subscription(drive_id: str) -> dict[str, Any] | None:
    return get(state(), PK_SUBSCRIPTION, drive_id)


def set_subscription(drive_id: str, subscription_id: str, resource: str, expires_at: datetime) -> None:
    upsert(state(), PK_SUBSCRIPTION, drive_id,
           SubscriptionId=subscription_id, Resource=resource, ExpiresAt=expires_at, UpdatedAt=now())


# --- config cache (site id, drive id, list ids) -----------------------------

def get_config(key: str) -> str | None:
    row = get(state(), PK_CONFIG, key)
    return row.get("Value") if row else None


def set_config(key: str, value: str) -> None:
    upsert(state(), PK_CONFIG, key, Value=value, UpdatedAt=now())


# --- sweep --------------------------------------------------------------------

def sweep() -> int:
    """Delete every row whose ExpiresAt is in the past. Returns how many."""
    cutoff = now().strftime("%Y-%m-%dT%H:%M:%SZ")
    expired: Iterable = state().query_entities(f"ExpiresAt lt datetime'{cutoff}'", select=["PartitionKey", "RowKey"])
    n = 0
    for row in expired:
        state().delete_entity(row["PartitionKey"], row["RowKey"])
        n += 1
    log.info("sweep: %s expired rows removed", n)
    return n
