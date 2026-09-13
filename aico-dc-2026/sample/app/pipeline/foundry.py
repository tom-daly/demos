"""One call to the model deployed in Microsoft Foundry, through the Azure OpenAI v1 endpoint with the
managed identity. The answer is pinned to a strict JSON schema, so it always parses."""
from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Any

from azure.identity import get_bearer_token_provider
from openai import OpenAI

from . import prompts
from .config import settings
from .credential import credential
from .documents import Document

log = logging.getLogger(__name__)
COGNITIVE_SCOPE = "https://cognitiveservices.azure.com/.default"


@lru_cache(maxsize=1)
def client() -> OpenAI:
    s = settings()
    token_provider = get_bearer_token_provider(credential(), COGNITIVE_SCOPE)
    return OpenAI(base_url=f"{s.foundry_openai_endpoint}openai/v1/", api_key=token_provider)


def _user_content(doc: Document) -> list[dict[str, Any]]:
    """The document as the user turn: a one-line header, then its text, or its page images if scanned."""
    header = f"Document: {doc.name} ({doc.pages} page(s){', scanned' if doc.scanned else ''})\n\n"
    parts: list[dict[str, Any]] = [{"type": "text", "text": header + (doc.text or "(the pages follow as images)")}]
    for url in doc.images:
        parts.append({"type": "image_url", "image_url": {"url": url, "detail": "high"}})
    return parts


@dataclass
class ModelResult:
    answer: dict[str, Any]                       # the parsed JSON the pipeline routes on
    request: dict[str, Any]                      # exactly what was sent (images replaced by their size)
    raw: dict[str, Any]                          # the whole response object, as the API returned it
    model: str = ""
    prompt_version: str = ""
    finish_reason: str = ""
    ms: int = 0
    usage: dict[str, Any] = field(default_factory=dict)


def _request_snapshot(messages: list[dict[str, Any]], **kw: Any) -> dict[str, Any]:
    """The request as sent, with image data URLs replaced by their length so the snapshot stays small."""
    snap = []
    for m in messages:
        c = m["content"]
        if isinstance(c, list):
            c = [{"type": "image", "bytes": len(p["image_url"]["url"])} if p.get("type") == "image_url" else p for p in c]
        snap.append({"role": m["role"], "content": c})
    return {"messages": snap, **kw}


def read_resume(doc: Document) -> ModelResult:
    """System prompt + résumé prompt, the whole document, one call. Returns the answer plus everything
    needed to audit the call later: the request, the raw response, tokens, timing."""
    s = settings()
    messages = [
        {"role": "system", "content": prompts.system_prompt()},
        {"role": "user", "content": _user_content(doc)},
    ]
    params: dict[str, Any] = dict(model=s.model_deployment, response_format={"type": "json_schema", "json_schema": prompts.RESUME_SCHEMA},
                                  max_completion_tokens=4000, reasoning_effort=s.reasoning_effort)
    t0 = time.perf_counter()
    response = client().chat.completions.create(messages=messages, **params)
    ms = round((time.perf_counter() - t0) * 1000)
    choice = response.choices[0]
    usage = response.usage
    usage_d = {"prompt_tokens": usage.prompt_tokens, "completion_tokens": usage.completion_tokens, "total_tokens": usage.total_tokens} if usage else {}
    log.info("model %s · in=%s out=%s · %s ms · finish=%s", s.model_deployment, usage_d.get("prompt_tokens", "?"), usage_d.get("completion_tokens", "?"), ms, choice.finish_reason)
    result = ModelResult(answer={}, request=_request_snapshot(messages, **{k: v for k, v in params.items() if k != "response_format"}, schema=prompts.RESUME_SCHEMA["name"]),
                         raw=response.model_dump(), model=s.model_deployment, prompt_version=prompts.version(), finish_reason=choice.finish_reason or "", ms=ms, usage=usage_d)
    if choice.finish_reason == "length":
        raise ModelError("model ran out of tokens before finishing the JSON", result)
    result.answer = json.loads(choice.message.content or "{}")
    return result


class ModelError(RuntimeError):
    """The call completed but the answer is unusable; carries the ModelResult so the trace can keep it."""
    def __init__(self, message: str, result: ModelResult) -> None:
        super().__init__(message)
        self.result = result
