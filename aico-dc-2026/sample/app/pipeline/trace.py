"""A step-by-step record of what the pipeline did to one file: every step, what went in, what came out,
how long it took, and what failed. Three places see it:

  1. the function log, one JSON line per step ("step {...}"), so App Insights can search and chart it:
         traces | where message startswith "step " | extend s = parse_json(substring(message, 5))
  2. a trace.json blob next to the result, with the full list of steps;
  3. the row in the SharePoint logging list, which carries the same steps.

Large inputs and outputs are not copied into the trace; they are written as their own blobs and the trace
points at them (the document text that was sent, the exact request, the raw model response).
"""
from __future__ import annotations

import json
import logging
import time
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Any, Iterator

log = logging.getLogger("pipeline.trace")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def summarize(value: Any, limit: int = 300) -> Any:
    """Keep the trace readable: bytes become a length, long strings are cut, everything else passes through."""
    if isinstance(value, (bytes, bytearray)):
        return {"bytes": len(value)}
    if isinstance(value, str) and len(value) > limit:
        return value[:limit] + f"… ({len(value)} chars)"
    if isinstance(value, dict):
        return {k: summarize(v, limit) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [summarize(v, limit) for v in value[:20]] + ([f"… {len(value) - 20} more"] if len(value) > 20 else [])
    return value


class Trace:
    def __init__(self, kind: str, subject: str, **context: Any) -> None:
        self.id = uuid.uuid4().hex[:12]
        self.kind = kind                       # "file" or "scan"
        self.subject = subject                 # the file name, or the folder for a scan
        self.context = context                 # item id, etag, delivery count, ...
        self.started = _now()
        self._t0 = time.perf_counter()
        self.steps: list[dict[str, Any]] = []
        self.artifacts: dict[str, str] = {}    # name -> blob url, for the big inputs and outputs
        self.status = "running"
        self.error: str | None = None
        log.info("trace %s start %s %s %s", self.id, kind, subject, json.dumps(context, default=str))

    @contextmanager
    def step(self, step_name: str, **inputs: Any) -> Iterator[dict[str, Any]]:
        """with trace.step("read", content_type=ct) as out: ... ; out["pages"] = 3
        The step's own parameter is deliberately not called "name", so an input called name= is allowed."""
        rec: dict[str, Any] = {"n": len(self.steps) + 1, "step": step_name, "started": _now(), "inputs": summarize(inputs)}
        out: dict[str, Any] = {}
        t0 = time.perf_counter()
        try:
            yield out
            rec["status"] = "ok"
        except Exception as e:  # noqa: BLE001 - recorded, then re-raised
            rec["status"] = "error"
            rec["error"] = f"{type(e).__name__}: {e}"[:1000]
            raise
        finally:
            rec["ms"] = round((time.perf_counter() - t0) * 1000)
            rec["outputs"] = summarize(out)
            self.steps.append(rec)
            log.info("step %s", json.dumps({"trace": self.id, "subject": self.subject, **rec}, default=str))

    def artifact(self, name: str, url: str) -> None:
        self.artifacts[name] = url

    def finish(self, status: str = "ok", error: str | None = None) -> dict[str, Any]:
        self.status, self.error = status, error
        d = self.to_dict()
        log.info("trace %s end %s %s in %s ms · %s steps", self.id, status, self.subject, d["ms"], len(self.steps))
        return d

    def to_dict(self) -> dict[str, Any]:
        return {
            "trace_id": self.id, "kind": self.kind, "subject": self.subject, "context": self.context,
            "started": self.started, "ms": round((time.perf_counter() - self._t0) * 1000),
            "status": self.status, "error": self.error, "steps": self.steps, "artifacts": self.artifacts,
        }
