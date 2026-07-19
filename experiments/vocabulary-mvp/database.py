from __future__ import annotations

import json
import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator
from uuid import uuid4

from pydantic import ValidationError

from models import RecordMetadata, VocabularyRecord, normalize_lookup_key


BASE_DIR = Path(__file__).resolve().parent


def _database_path() -> Path:
    configured = os.getenv("DATABASE_PATH")
    if not configured:
        return BASE_DIR / "vocabulary.db"
    path = Path(configured).expanduser()
    return path if path.is_absolute() else BASE_DIR / path


DB_PATH = _database_path()


@contextmanager
def connection() -> Iterator[sqlite3.Connection]:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(DB_PATH, timeout=10)
    db.row_factory = sqlite3.Row
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def _create_schema(db: sqlite3.Connection) -> None:
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS vocabulary (
            lookup_key TEXT PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            word TEXT NOT NULL,
            data TEXT NOT NULL,
            source TEXT NOT NULL,
            provider TEXT,
            model TEXT,
            prompt_version TEXT NOT NULL,
            source_input TEXT NOT NULL,
            validation_state TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    db.execute("CREATE INDEX IF NOT EXISTS idx_vocabulary_word ON vocabulary(word)")


def _migrate_legacy_table(db: sqlite3.Connection) -> None:
    backup = f"vocabulary_legacy_{uuid4().hex[:8]}"
    db.execute(f'ALTER TABLE vocabulary RENAME TO "{backup}"')
    _create_schema(db)
    rows = db.execute(f'SELECT * FROM "{backup}"').fetchall()
    for row in rows:
        try:
            record = VocabularyRecord.model_validate_json(row["data"])
        except (ValidationError, ValueError, KeyError):
            continue
        metadata = RecordMetadata(
            source="legacy",
            prompt_version="legacy-v0",
            source_input=row["word"],
            generated_at=row["created_at"],
        )
        _insert(db, record, metadata)


def init_db() -> None:
    with connection() as db:
        db.execute("PRAGMA journal_mode=WAL")
        existing = db.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='vocabulary'"
        ).fetchone()
        if not existing:
            _create_schema(db)
        else:
            columns = {row["name"] for row in db.execute("PRAGMA table_info(vocabulary)")}
            if "lookup_key" not in columns or "validation_state" not in columns:
                _migrate_legacy_table(db)


def get_stored_record(word: str) -> tuple[VocabularyRecord, RecordMetadata] | None:
    with connection() as db:
        row = db.execute(
            "SELECT * FROM vocabulary WHERE lookup_key = ?",
            (normalize_lookup_key(word),),
        ).fetchone()
    if row is None:
        return None
    record = VocabularyRecord.model_validate_json(row["data"])
    metadata = RecordMetadata.model_validate(
        {
            "item_id": row["id"],
            "source": row["source"],
            "provider": row["provider"],
            "model": row["model"],
            "prompt_version": row["prompt_version"],
            "source_input": row["source_input"],
            "generated_at": row["created_at"],
            "validation_state": row["validation_state"],
        }
    )
    return record, metadata


def get_record(word: str) -> VocabularyRecord | None:
    stored = get_stored_record(word)
    return stored[0] if stored else None


def _insert(db: sqlite3.Connection, record: VocabularyRecord, metadata: RecordMetadata) -> None:
    data = json.dumps(record.model_dump(), ensure_ascii=False, separators=(",", ":"))
    db.execute(
        """
        INSERT INTO vocabulary(
            lookup_key, id, word, data, source, provider, model, prompt_version,
            source_input, validation_state, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(lookup_key) DO NOTHING
        """,
        (
            normalize_lookup_key(record.word),
            str(metadata.item_id),
            record.word,
            data,
            metadata.source,
            metadata.provider,
            metadata.model,
            metadata.prompt_version,
            metadata.source_input,
            metadata.validation_state,
            metadata.generated_at.isoformat(),
        ),
    )


def save_record(record: VocabularyRecord, metadata: RecordMetadata) -> None:
    with connection() as db:
        _insert(db, record, metadata)
