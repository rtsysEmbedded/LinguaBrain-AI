from __future__ import annotations

import argparse
import asyncio
import csv
import io
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from pydantic import ValidationError

load_dotenv()

from ai_client import AIClientError, generate_record
from database import get_record, init_db, save_record
from models import LookupRequest, Provider


CSV_FIELDS = ["word", "status", "error"]


def _csv_safe(value: str) -> str:
    return f"'{value}" if value.startswith(("=", "+", "-", "@")) else value


def _write_results(output: Path, rows: list[dict[str, str]]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_results_csv(rows), encoding="utf-8-sig")


def render_results_csv(rows: list[dict[str, str]]) -> str:
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=CSV_FIELDS)
    writer.writeheader()
    writer.writerows(
        {key: _csv_safe(row[key]) for key in CSV_FIELDS}
        for row in rows
    )
    return stream.getvalue()


async def import_workbook(path: Path, output: Path, provider: Provider) -> list[dict[str, str]]:
    frame = pd.read_excel(path)
    if "word" not in frame.columns:
        raise ValueError("Excel file must contain a column named 'word'")

    results: list[dict[str, str]] = []
    _write_results(output, results)
    for raw in frame["word"]:
        if pd.isna(raw) or (isinstance(raw, str) and not raw.strip()):
            continue

        display_word = raw if isinstance(raw, str) else str(raw)
        row = {"word": display_word, "status": "", "error": ""}
        try:
            request = LookupRequest(word=raw, provider=provider)
            row["word"] = request.word
            if get_record(request.word):
                row["status"] = "skipped_existing"
            else:
                generated = await generate_record(request.word, provider)
                save_record(generated.record, generated.metadata)
                row["status"] = "saved"
        except ValidationError:
            row.update(status="failed", error="word must be non-empty text (maximum 120 characters)")
        except AIClientError as exc:
            row.update(status="failed", error=str(exc))
        except Exception:
            row.update(status="failed", error="local database or file write failed")
        results.append(row)
        _write_results(output, results)
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("excel", type=Path)
    parser.add_argument("--output", type=Path, default=Path("import_results.csv"))
    parser.add_argument(
        "--provider",
        choices=["lmstudio", "ollama", "openai", "anthropic"],
        default="lmstudio",
    )
    args = parser.parse_args()
    init_db()
    asyncio.run(import_workbook(args.excel, args.output, args.provider))
