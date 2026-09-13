"""The prompt and the JSON schema the model must answer in.

Two text files in ../prompts, editable without touching code:
  system.txt          who the model is and the house rules; goes first
  extract_resume.txt  the task: facts off the page, then an assessment

One system message = system.txt + blank line + extract_resume.txt (+ the target role, if one is set).
The schema below is enforced in strict mode, so the answer always has exactly these fields.

The task prompt starts with "PROMPT_VERSION: <value>". That value is the prompt's version: bump it when the
wording changes, and the model echoes it back in the answer's prompt_version field, so every stored result
says which prompt produced it and process.py can check the model actually read the prompt it was sent.
"""
from __future__ import annotations

import pathlib
import re
from functools import lru_cache

from .config import settings

PROMPT_DIR = pathlib.Path(__file__).resolve().parent.parent / "prompts"


@lru_cache(maxsize=None)
def load(name: str) -> str:
    return (PROMPT_DIR / f"{name}.txt").read_text(encoding="utf-8").strip()


def version() -> str:
    """The PROMPT_VERSION value on the first line of extract_resume.txt."""
    m = re.match(r"PROMPT_VERSION:\s*(\S+)", load("extract_resume"))
    if not m:
        raise RuntimeError("prompts/extract_resume.txt must start with a PROMPT_VERSION: line")
    return m.group(1)


def system_prompt() -> str:
    task = load("extract_resume")
    role = settings().resume_target_role
    if role:
        task += f"\n\nTARGET ROLE. Judge the assessment against this role:\n{role}"
    return f"{load('system')}\n\n{task}"


FACTS = ["name", "email", "phone", "location", "current_title", "most_recent_employer", "years_experience", "education"]
AREAS = ["experience", "skills", "education", "career_progression", "presentation"]


def _string_list() -> dict:
    return {"type": "array", "items": {"type": "string"}}


def _scored_area() -> dict:
    return {
        "type": "object",
        "properties": {"score": {"type": "integer"}, "reason": {"type": "string"}},
        "required": ["score", "reason"],
        "additionalProperties": False,
    }


RESUME_SCHEMA = {
    "name": "resume",
    "strict": True,
    "schema": {
        "type": "object",
        "properties": {
            **{f: {"type": ["string", "null"]} for f in FACTS},
            "top_skills": _string_list(),
            "assessment": {
                "type": "object",
                "properties": {
                    "overall_score": {"type": "integer"},
                    "scores": {
                        "type": "object",
                        "properties": {a: _scored_area() for a in AREAS},
                        "required": AREAS,
                        "additionalProperties": False,
                    },
                    "strengths": _string_list(),
                    "gaps": _string_list(),
                    "weaknesses": _string_list(),
                    "summary": {"type": "string"},
                },
                "required": ["overall_score", "scores", "strengths", "gaps", "weaknesses", "summary"],
                "additionalProperties": False,
            },
            "confidence": {"type": "number"},
            "notes": {"type": "string"},
            "prompt_version": {"type": "string"},
        },
        "required": FACTS + ["top_skills", "assessment", "confidence", "notes", "prompt_version"],
        "additionalProperties": False,
    },
}
