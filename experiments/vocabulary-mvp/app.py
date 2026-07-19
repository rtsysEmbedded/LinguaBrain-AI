from __future__ import annotations

import os
import tempfile
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Union

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse

load_dotenv()

from ai_client import AIClientError, generate_record
from anki_client import add_to_anki
from database import get_stored_record, init_db, save_record
from import_excel import import_workbook, render_results_csv
from models import LookupRequest, LookupResponse, Provider


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(title="German Vocabulary MVP", lifespan=lifespan)


async def lookup(payload: LookupRequest) -> LookupResponse:
    stored = get_stored_record(payload.word)
    cached = stored is not None
    if stored is None:
        try:
            generated = await generate_record(payload.word, payload.provider)
        except AIClientError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
        save_record(generated.record, generated.metadata)
        persisted = get_stored_record(payload.word)
        record, metadata = persisted or (generated.record, generated.metadata)
    else:
        record, metadata = stored

    anki_added = False
    anki_error = None
    if payload.add_to_anki:
        try:
            await add_to_anki(record)
            anki_added = True
        except (httpx.HTTPError, RuntimeError):
            anki_error = "AnkiConnect is unavailable or rejected the note"

    return LookupResponse(
        cached=cached,
        anki_added=anki_added,
        anki_error=anki_error,
        metadata=metadata,
        record=record,
    )


@app.post("/lookup", response_model=LookupResponse, response_model_exclude_none=True)
async def lookup_endpoint(payload: LookupRequest) -> LookupResponse:
    return await lookup(payload)


@app.post("/anki/{word}")
async def anki_endpoint(word: str) -> dict[str, Union[int, str]]:
    stored = get_stored_record(word)
    if stored is None:
        raise HTTPException(status_code=404, detail="Word not found")
    record, _ = stored
    try:
        note_id = await add_to_anki(record)
    except (httpx.HTTPError, RuntimeError) as exc:
        raise HTTPException(status_code=502, detail="AnkiConnect export failed") from exc
    return {"word": record.word, "note_id": note_id}


@app.post("/import")
async def import_endpoint(
    file: UploadFile = File(...),
    provider: Provider = Form("lmstudio"),
) -> StreamingResponse:
    suffix = Path(file.filename or "input.xlsx").suffix.lower()
    if suffix not in {".xlsx", ".xlsm"}:
        raise HTTPException(status_code=400, detail="Upload an .xlsx or .xlsm workbook")

    try:
        max_bytes = int(os.getenv("MAX_IMPORT_BYTES", str(10 * 1024 * 1024)))
        if max_bytes <= 0:
            raise ValueError
    except ValueError as exc:
        raise HTTPException(status_code=500, detail="MAX_IMPORT_BYTES must be a positive integer") from exc
    contents = await file.read(max_bytes + 1)
    if len(contents) > max_bytes:
        raise HTTPException(status_code=413, detail="Excel file is too large")

    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / f"input{suffix}"
        output = Path(directory) / "results.csv"
        source.write_bytes(contents)
        try:
            rows = await import_workbook(source, output, provider)
        except Exception as exc:
            raise HTTPException(status_code=400, detail="Could not read the Excel workbook") from exc

    csv_text = render_results_csv(rows)
    return StreamingResponse(
        iter([csv_text]),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": "attachment; filename=import_results.csv"},
    )


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
