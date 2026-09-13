"""What happens to one file: fetch, read, one model call, route, record. Called by the queue worker.
Every step is traced (pipeline/trace.py): what went in, what came out, how long, and where the big
inputs and outputs were saved. The trace ends up in the log, in a blob next to the result, and in the
SharePoint logging list."""
from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Any

from . import documents, foundry, graph, prompts, router, state, storage
from .config import settings
from .trace import Trace

log = logging.getLogger(__name__)


def scan(reason: str = "") -> int:
    """Walk the delta for the watched folder and queue every new or changed file. Returns how many."""
    tr = Trace("scan", settings().sharepoint_folder, reason=reason)
    with tr.step("walk_delta") as out:
        files, new_link = graph.walk_delta()
        out["changed_files"] = len(files)
        out["names"] = [f["name"] for f in files]
    queued = 0
    with tr.step("queue_new_files", changed=len(files)) as out:
        skipped = []
        for item in files:
            item_id, etag = item["id"], item.get("eTag", "")
            if not state.claim(item_id, etag):   # already queued or done: the insert fails, so skip it
                skipped.append(item["name"])
                continue
            storage.enqueue({
                "kind": "file", "item_id": item_id, "etag": etag, "name": item["name"],
                "content_type": item.get("file", {}).get("mimeType"), "web_url": item.get("webUrl", ""),
                "trace_parent": tr.id,
            })
            queued += 1
        out["queued"] = queued
        out["already_seen"] = skipped
    with tr.step("save_delta_link") as out:
        state.set_delta_link(graph.drive_id(), new_link)
        out["delta_link"] = new_link
    tr.finish()
    log.info("scan: %s changed, %s queued", len(files), queued)
    return queued


def process_file(msg: dict[str, Any], delivery: int = 0) -> dict[str, Any]:
    s = settings()
    name = msg["name"]
    item_id, etag = msg["item_id"], msg["etag"]
    tr = Trace("file", name, item_id=item_id, etag=etag, delivery=delivery, source_url=msg.get("web_url", ""), trace_parent=msg.get("trace_parent"))
    if state.is_done(item_id, etag):
        log.info("skip %s: already processed", name)
        tr.finish("skipped", "already processed")
        return {"skipped": True, "trace_id": tr.id}

    try:
        # 1. Get the bytes. A copy goes to the incoming container so a retry never re-downloads.
        with tr.step("download", item_id=item_id, content_type=msg.get("content_type")) as out:
            data = graph.download(item_id)
            url = storage.put_blob(s.incoming_container, f"{item_id}/{name}", data, msg.get("content_type") or "application/octet-stream")
            out["bytes"] = len(data); out["copy"] = url
            tr.artifact("original", url)

        # 2. Read it: text if it has any, page images if it is a scan.
        with tr.step("read", name=name, bytes=len(data), declared_type=msg.get("content_type")) as out:
            doc = documents.read(name, data, msg.get("content_type"))
            out.update(content_type=doc.content_type, pages=doc.pages, scanned=doc.scanned, text_chars=len(doc.text), images=len(doc.images))
            if doc.text:
                tr.artifact("document_text", storage.put_blob(s.results_container, f"{item_id}/document.txt", doc.text.encode("utf-8"), "text/plain; charset=utf-8"))

        # 3. One call: system prompt + résumé prompt, the whole document. The exact request and the raw
        #    response are kept as blobs so any answer can be explained later.
        with tr.step("model", model=s.model_deployment, prompt_version=prompts.version(), reasoning_effort=s.reasoning_effort, text_chars=len(doc.text), images=len(doc.images)) as out:
            try:
                mr = foundry.read_resume(doc)
            except foundry.ModelError as e:
                tr.artifact("model_request", storage.put_json(s.results_container, f"{item_id}/model-request.json", e.result.request))
                tr.artifact("model_response", storage.put_json(s.results_container, f"{item_id}/model-response.json", e.result.raw))
                out.update(finish_reason=e.result.finish_reason, usage=e.result.usage, model_ms=e.result.ms)
                raise
            tr.artifact("model_request", storage.put_json(s.results_container, f"{item_id}/model-request.json", mr.request))
            tr.artifact("model_response", storage.put_json(s.results_container, f"{item_id}/model-response.json", mr.raw))
            out.update(finish_reason=mr.finish_reason, usage=mr.usage, model_ms=mr.ms, confidence=mr.answer.get("confidence"),
                       overall_score=mr.answer.get("assessment", {}).get("overall_score"), prompt_version_echoed=mr.answer.get("prompt_version"),
                       facts={k: mr.answer.get(k) for k in prompts.FACTS})
        answer = mr.answer

        # 4. The answer must carry the version of the prompt it was given. A mismatch means the model
        #    ignored the prompt or a stale one is deployed; treat the answer as unsure so a person looks.
        with tr.step("check_prompt_version", expected=mr.prompt_version, echoed=answer.get("prompt_version")) as out:
            expected = mr.prompt_version
            echoed = answer.get("prompt_version")
            version_ok = echoed == expected
            out["ok"] = version_ok
            if not version_ok:
                log.warning("%s: prompt version mismatch: sent %s, model returned %s", name, expected, echoed)

        # 5. Decide where it goes: plain code on the confidence number.
        with tr.step("route", confidence=answer.get("confidence"), version_ok=version_ok, auto_threshold=s.auto_threshold, review_threshold=s.review_threshold) as out:
            lane = router.lane(answer.get("confidence", 0.0) if version_ok else 0.0)
            out["lane"] = lane

        # 6. Record everything: a JSON blob, the trace beside it, one row in the logging list, and a "seen" mark.
        result = {
            "name": name, "item_id": item_id, "etag": etag, "source_url": msg.get("web_url", ""),
            "lane": lane, "answer": answer,
            "pages": doc.pages, "scanned": doc.scanned,
            "model": s.model_deployment, "prompt_version": expected, "prompt_version_echoed": echoed, "prompt_version_ok": version_ok,
            "usage": mr.usage, "model_ms": mr.ms,
            "processed_at": datetime.now(timezone.utc).isoformat(), "trace_id": tr.id,
        }
        with tr.step("record", lane=lane) as out:
            out["result"] = storage.put_json(s.results_container, f"{item_id}.json", result)
            tr.artifact("result", out["result"])
            row = graph.add_log(name, json.dumps({**result, "trace": tr.to_dict()}, indent=1, default=str))
            out["log_row"] = row.get("id")
            state.mark_seen(item_id, etag)
        trace = tr.finish()
        result["trace"] = trace
        storage.put_json(s.results_container, f"{item_id}/trace.json", trace)
        log.info("done %s · score %s · %s · trace %s", name, answer.get("assessment", {}).get("overall_score"), lane, tr.id)
        return result

    except documents.Unsupported as e:
        # Not a retry case. Log it as a row too, then let the message complete.
        log.warning("unsupported %s: %s", name, e)
        trace = tr.finish("unsupported", str(e))
        graph.add_log(name, json.dumps({"name": name, "item_id": item_id, "error": str(e), "lane": router.MANUAL, "trace": trace}, indent=1, default=str))
        storage.put_json(s.results_container, f"{item_id}/trace.json", trace)
        state.mark_seen(item_id, etag)
        return {"unsupported": str(e), "trace_id": tr.id}
    except Exception as e:  # noqa: BLE001
        # Everything else propagates: the queue retries five times, then parks the message in documents-poison.
        # The trace of the failed attempt is still written, one per delivery, so the retries can be compared.
        trace = tr.finish("error", f"{type(e).__name__}: {e}")
        try:
            storage.put_json(s.results_container, f"{item_id}/trace-attempt-{delivery}.json", trace)
        except Exception:  # noqa: BLE001
            log.exception("could not write the failure trace for %s", name)
        raise
