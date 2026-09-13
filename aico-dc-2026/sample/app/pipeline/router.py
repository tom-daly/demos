"""Sure? Save it. Not sure? Ask a person. Plain code on the confidence number, not another prompt."""
from __future__ import annotations

from .config import settings

AUTO = "auto"        # confident: taken as is
REVIEW = "review"    # a person confirms it, ~30 seconds
MANUAL = "manual"    # a person handles it from scratch; nothing is trusted


def lane(confidence: float) -> str:
    s = settings()
    if confidence < s.review_threshold:
        return MANUAL
    if confidence >= s.auto_threshold:
        return AUTO
    return REVIEW
