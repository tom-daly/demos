"""Microsoft Graph: site/drive lookup, change notifications, delta, download, list writes.

Everything goes through the managed identity with Sites.Selected, so the identity can see the one
site it was granted and nothing else. 429 and 503 are retried after the Retry-After the service asks for.
"""
from __future__ import annotations

import logging
import time
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import urlparse

import requests

from . import state
from .config import settings
from .credential import credential

log = logging.getLogger(__name__)

GRAPH = "https://graph.microsoft.com/v1.0"
SCOPE = "https://graph.microsoft.com/.default"
# We subscribe to the library as a *list* (/sites/{id}/lists/{id}), not as a drive: list subscriptions
# live up to 30 days (drive ones under three) and are proven to work with Sites.Selected + write on
# this tenant (the survey project). The notification is only a "look again"; the delta walk below
# stays scoped to the one folder.
SUBSCRIPTION_DAYS = 28
RENEW_WHEN_LESS_THAN = timedelta(days=2)

_token: tuple[str, float] | None = None


def _bearer() -> str:
    global _token
    if _token is None or _token[1] - time.time() < 120:
        t = credential().get_token(SCOPE)
        _token = (t.token, t.expires_on)
    return _token[0]


def call(method: str, url: str, *, params: dict | None = None, json: Any = None,
         stream: bool = False, attempts: int = 5) -> requests.Response:
    if url.startswith("/"):
        url = GRAPH + url
    for attempt in range(1, attempts + 1):
        r = requests.request(method, url, params=params, json=json, stream=stream, timeout=60,
                             headers={"Authorization": f"Bearer {_bearer()}"})
        if r.status_code in (429, 503, 504) and attempt < attempts:
            wait = float(r.headers.get("Retry-After", 2 ** attempt))
            log.warning("Graph %s %s -> %s, waiting %ss", method, url, r.status_code, wait)
            time.sleep(wait)
            continue
        if r.status_code >= 400:
            raise RuntimeError(f"Graph {method} {url} -> {r.status_code}: {r.text[:500]}")
        return r
    raise RuntimeError("unreachable")


def get(url: str, **kw) -> dict:
    return call("GET", url, **kw).json()


def post(url: str, body: Any) -> dict:
    r = call("POST", url, json=body)
    return r.json() if r.content else {}


def patch(url: str, body: Any) -> dict:
    r = call("PATCH", url, json=body)
    return r.json() if r.content else {}


def delete(url: str) -> None:
    call("DELETE", url)


# --- site / drive / folder (resolved once, cached in the State table) -------

def site_id() -> str:
    cached = state.get_config("siteId")
    if cached:
        return cached
    u = urlparse(settings().sharepoint_site_url)
    site = get(f"/sites/{u.hostname}:{u.path.rstrip('/')}")
    state.set_config("siteId", site["id"])
    return site["id"]


def drive_id() -> str:
    cached = state.get_config("driveId")
    if cached:
        return cached
    drives = get(f"/sites/{site_id()}/drives", params={"$select": "id,name"})["value"]
    wanted = settings().sharepoint_library
    match = next((d for d in drives if d["name"] == wanted), None)
    if not match:
        raise RuntimeError(f"Library '{wanted}' not found; libraries: {[d['name'] for d in drives]}")
    state.set_config("driveId", match["id"])
    return match["id"]


def folder_id() -> str:
    cached = state.get_config("folderId")
    if cached:
        return cached
    item = get(f"/drives/{drive_id()}/root:/{settings().sharepoint_folder}")
    state.set_config("folderId", item["id"])
    return item["id"]


def library_list_id() -> str:
    """The document library seen as a SharePoint list; what the change subscription points at."""
    cached = state.get_config("libraryListId")
    if cached:
        return cached
    lst = get(f"/sites/{site_id()}/drives/{drive_id()}/list", params={"$select": "id"})
    state.set_config("libraryListId", lst["id"])
    return lst["id"]


# --- delta ------------------------------------------------------------------

def walk_delta() -> tuple[list[dict], str]:
    """Return (changed files, new delta link). First call walks the whole folder; later calls only changes."""
    link = state.get_delta_link(drive_id())
    url = link or f"{GRAPH}/drives/{drive_id()}/items/{folder_id()}/delta"
    files: list[dict] = []
    while True:
        page = get(url)
        for item in page.get("value", []):
            if "file" in item and "deleted" not in item:
                files.append(item)
        if "@odata.nextLink" in page:
            url = page["@odata.nextLink"]
            continue
        return files, page["@odata.deltaLink"]


def download(item_id: str) -> bytes:
    # Graph answers with a 302 to a pre-authenticated URL; requests follows it and drops the bearer header.
    return call("GET", f"/drives/{drive_id()}/items/{item_id}/content").content


# --- subscription (change notifications) --------------------------------------

def ensure_subscription() -> dict[str, Any]:
    """Exactly one live subscription for our library and our webhook: create it if missing, renew it when
    it is within two days of expiry, delete any strays (older deploys, other URLs). Returns what is on record."""
    s = settings()
    did = drive_id()
    resource = f"/sites/{site_id()}/lists/{library_list_id()}"   # the whole library; the folder filter is in delta
    notification_url = f"{s.public_base_url}/api/webhook"
    new_expiry = datetime.now(timezone.utc) + timedelta(days=SUBSCRIPTION_DAYS)

    # What Graph actually has for this identity. The table row is a cache; Graph is the truth.
    live = get("/subscriptions")["value"]
    ours = [x for x in live if x.get("resource", "").lower() == resource.lower() and x.get("notificationUrl") == notification_url]
    strays = [x for x in live if x not in ours]
    for x in strays:
        try:
            delete(f"/subscriptions/{x['id']}")
            log.info("deleted stray subscription %s (%s -> %s)", x["id"], x.get("resource"), x.get("notificationUrl"))
        except RuntimeError as e:
            log.warning("could not delete subscription %s: %s", x["id"], e)
    for x in ours[1:]:   # keep one
        try:
            delete(f"/subscriptions/{x['id']}")
            log.info("deleted duplicate subscription %s", x["id"])
        except RuntimeError as e:
            log.warning("could not delete subscription %s: %s", x["id"], e)
    if ours:
        keep = ours[0]
        expiry = datetime.fromisoformat(keep["expirationDateTime"].replace("Z", "+00:00"))
        state.set_subscription(did, keep["id"], resource, expiry)

    current = state.get_subscription(did)
    if current:
        expires_at = current["ExpiresAt"]
        if expires_at - datetime.now(timezone.utc) > RENEW_WHEN_LESS_THAN:
            return current
        try:
            patch(f"/subscriptions/{current['SubscriptionId']}", {"expirationDateTime": new_expiry.isoformat()})
            state.set_subscription(did, current["SubscriptionId"], resource, new_expiry)
            log.info("renewed subscription %s until %s", current["SubscriptionId"], new_expiry)
            return state.get_subscription(did) or current
        except RuntimeError as e:
            log.warning("renew failed (%s); creating a new subscription", e)

    created = post("/subscriptions", {
        "changeType": "updated",
        "notificationUrl": notification_url,
        "resource": resource,
        "expirationDateTime": new_expiry.isoformat(),
        "clientState": s.webhook_client_state,
    })
    expiry = datetime.fromisoformat(created["expirationDateTime"].replace("Z", "+00:00"))
    state.set_subscription(did, created["id"], resource, expiry)
    log.info("created subscription %s -> %s until %s", created["id"], notification_url, expiry)
    return state.get_subscription(did) or created


# --- results list -----------------------------------------------------------

RESULT_COLUMNS = [
    {"name": "DocType", "text": {}},
    {"name": "Lane", "text": {}},
    {"name": "Confidence", "number": {}},
    {"name": "Summary", "text": {"allowMultipleLines": True}},
    {"name": "Fields", "text": {"allowMultipleLines": True}},
    {"name": "Evidence", "text": {"allowMultipleLines": True}},
    {"name": "SourceUrl", "text": {}},
    {"name": "ItemId", "text": {}},
    {"name": "Ticket", "text": {}},
    {"name": "Model", "text": {}},
    {"name": "PromptVersion", "text": {}},
]


def results_list_id() -> str:
    cached = state.get_config("resultsListId")
    if cached:
        return cached
    sid = site_id()
    name = settings().results_list
    lists = get(f"/sites/{sid}/lists", params={"$filter": f"displayName eq '{name}'", "$select": "id,displayName"})["value"]
    if lists:
        list_id = lists[0]["id"]
    else:
        created = post(f"/sites/{sid}/lists", {"displayName": name, "columns": RESULT_COLUMNS, "list": {"template": "genericList"}})
        list_id = created["id"]
        log.info("created results list '%s' (%s)", name, list_id)
    state.set_config("resultsListId", list_id)
    return list_id


def add_result(fields: dict[str, Any]) -> dict:
    return post(f"/sites/{site_id()}/lists/{results_list_id()}/items", {"fields": fields})


# --- logging list: Title = file name, Body = the raw JSON result ----------------

def log_list_id() -> str:
    """Find the logging list by name, or create it (Title + Body). Needs the identity to have manage on the site."""
    cached = state.get_config("logListId")
    if cached:
        return cached
    sid = site_id()
    name = settings().log_list
    lists = get(f"/sites/{sid}/lists", params={"$filter": f"displayName eq '{name}'", "$select": "id,displayName"})["value"]
    if lists:
        list_id = lists[0]["id"]
    else:
        created = post(f"/sites/{sid}/lists", {
            "displayName": name,
            "description": "One row per document the pipeline read. Title is the file name, Body is the JSON answer.",
            "columns": [{"name": "Body", "text": {"allowMultipleLines": True, "textType": "plain"}}],
            "list": {"template": "genericList"},
        })
        list_id = created["id"]
        log.info("created logging list '%s' (%s)", name, list_id)
    state.set_config("logListId", list_id)
    return list_id


def add_log(title: str, body: str) -> dict:
    return post(f"/sites/{site_id()}/lists/{log_list_id()}/items", {"fields": {"Title": title[:255], "Body": body[:60000]}})
