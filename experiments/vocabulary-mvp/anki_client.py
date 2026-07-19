from __future__ import annotations

import html
import os
from typing import Any

import httpx

from models import VocabularyRecord


def _escaped(value: str) -> str:
    return html.escape(value, quote=True)


def _fields(record: VocabularyRecord) -> dict[str, str]:
    grammar_parts = [
        f"Präteritum: {_escaped(record.grammar.preterite)}" if record.grammar.preterite else "",
        f"Perfekt: {_escaped(record.grammar.perfect)}" if record.grammar.perfect else "",
        f"Artikel: {_escaped(record.grammar.article)}" if record.grammar.article else "",
        f"Plural: {_escaped(record.grammar.plural)}" if record.grammar.plural else "",
        f"Komparativ: {_escaped(record.grammar.comparative)}" if record.grammar.comparative else "",
        f"Superlativ: {_escaped(record.grammar.superlative)}" if record.grammar.superlative else "",
    ]
    back_parts = [
        f'<div dir="ltr"><b>{_escaped(record.lemma)}</b> · {_escaped(record.type)} · {_escaped(record.level)}</div>',
        f'<div dir="rtl">{_escaped("، ".join(record.meaning_fa))}</div>',
        f'<div dir="ltr">{_escaped(", ".join(record.meaning_en))}</div>',
        f'<div dir="ltr">{_escaped(record.example_de)}</div>',
        f'<div dir="rtl">{_escaped(record.example_fa)}</div>',
        "<br>".join(part for part in grammar_parts if part),
    ]
    return {
        os.getenv("ANKI_FRONT_FIELD", "Front"): _escaped(record.word),
        os.getenv("ANKI_BACK_FIELD", "Back"): "<br>".join(part for part in back_parts if part),
    }


async def add_to_anki(record: VocabularyRecord) -> int:
    request: dict[str, Any] = {
        "action": "addNote",
        "version": 6,
        "params": {
            "note": {
                "deckName": os.getenv("ANKI_DECK", "German Vocabulary"),
                "modelName": os.getenv("ANKI_MODEL", "Basic"),
                "fields": _fields(record),
                "options": {"allowDuplicate": False},
                "tags": ["vocabulary-mvp", "ai-unverified", record.level],
            }
        },
    }
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.post(
            os.getenv("ANKI_CONNECT_URL", "http://localhost:8765"),
            json=request,
        )
        response.raise_for_status()
    try:
        payload = response.json()
    except ValueError as exc:
        raise RuntimeError("AnkiConnect returned invalid JSON") from exc
    if not isinstance(payload, dict):
        raise RuntimeError("AnkiConnect returned an invalid response")
    if payload.get("error"):
        raise RuntimeError(str(payload["error"]))
    note_id = payload.get("result")
    if not isinstance(note_id, int) or isinstance(note_id, bool):
        raise RuntimeError("AnkiConnect did not return a note id")
    return note_id
