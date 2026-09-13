"""App settings, read once. Names match the Bicep app settings and env/<name>.json appSettings."""
from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache


def _req(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing app setting {name}")
    return value


@dataclass(frozen=True)
class Settings:
    storage_account: str
    incoming_container: str
    results_container: str
    queue_name: str
    state_table: str

    foundry_openai_endpoint: str
    model_deployment: str
    reasoning_effort: str

    sharepoint_site_url: str
    sharepoint_library: str
    sharepoint_folder: str
    results_list: str
    log_list: str
    write_results_list: bool
    webhook_client_state: str

    # Routing thresholds. Start here, look at a week of review-queue decisions, then move them.
    auto_threshold: float
    review_threshold: float

    # Scanned documents are sent as page images, up to this many pages. Text documents go in whole.
    max_image_pages: int

    # Optional: a role or job description to judge résumés against. Empty = judge the résumé on its own terms.
    resume_target_role: str

    @property
    def blob_url(self) -> str:
        return f"https://{self.storage_account}.blob.core.windows.net"

    @property
    def queue_url(self) -> str:
        return f"https://{self.storage_account}.queue.core.windows.net"

    @property
    def table_url(self) -> str:
        return f"https://{self.storage_account}.table.core.windows.net"

    @property
    def public_base_url(self) -> str:
        """Where Graph reaches the webhook. In Azure the host sets WEBSITE_HOSTNAME; locally use a tunnel."""
        explicit = os.environ.get("PUBLIC_BASE_URL")
        if explicit:
            return explicit.rstrip("/")
        host = os.environ.get("WEBSITE_HOSTNAME", "localhost:7071")
        scheme = "http" if host.startswith("localhost") else "https"
        return f"{scheme}://{host}"


@lru_cache(maxsize=1)
def settings() -> Settings:
    return Settings(
        storage_account=_req("STORAGE_ACCOUNT_NAME"),
        incoming_container=os.environ.get("STORAGE_INCOMING_CONTAINER", "incoming"),
        results_container=os.environ.get("STORAGE_RESULTS_CONTAINER", "results"),
        queue_name=os.environ.get("STORAGE_QUEUE_NAME", "documents"),
        state_table=os.environ.get("STORAGE_STATE_TABLE", "State"),
        foundry_openai_endpoint=_req("FOUNDRY_OPENAI_ENDPOINT").rstrip("/") + "/",
        model_deployment=_req("FOUNDRY_MODEL_DEPLOYMENT"),
        reasoning_effort=os.environ.get("FOUNDRY_REASONING_EFFORT", "low"),
        sharepoint_site_url=_req("SHAREPOINT_SITE_URL").rstrip("/"),
        sharepoint_library=os.environ.get("SHAREPOINT_LIBRARY", "Documents"),
        sharepoint_folder=os.environ.get("SHAREPOINT_FOLDER", "Incoming").strip("/"),
        results_list=os.environ.get("SHAREPOINT_RESULTS_LIST", "Document Results"),
        log_list=os.environ.get("SHAREPOINT_LOG_LIST", "Pipeline Log"),
        write_results_list=os.environ.get("WRITE_RESULTS_LIST", "false").lower() in ("1", "true", "yes"),
        webhook_client_state=_req("GRAPH_WEBHOOK_CLIENT_STATE"),
        auto_threshold=float(os.environ.get("ROUTER_AUTO_THRESHOLD", "0.85")),
        review_threshold=float(os.environ.get("ROUTER_REVIEW_THRESHOLD", "0.5")),
        max_image_pages=int(os.environ.get("DOC_MAX_IMAGE_PAGES", "20")),
        resume_target_role=os.environ.get("RESUME_TARGET_ROLE", "").strip(),
    )
