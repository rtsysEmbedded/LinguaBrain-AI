from __future__ import annotations

import unicodedata
from datetime import datetime, timezone
from typing import Literal, Optional
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


Provider = Literal["lmstudio", "ollama", "openai", "anthropic"]
PartOfSpeech = Literal["noun", "verb", "adjective", "adverb", "phrase", "other"]
CefrLevel = Literal["A1", "A2", "B1", "B2", "C1", "C2"]
ValidationState = Literal["schema_validated_unverified"]


def normalize_lookup_key(value: str) -> str:
    """Build a case-insensitive key without changing canonical German casing."""
    cleaned = " ".join(unicodedata.normalize("NFC", value).strip().split())
    return cleaned.casefold()


def _clean_required_text(value: object) -> str:
    if not isinstance(value, str):
        raise ValueError("must be text")
    cleaned = " ".join(value.strip().split())
    if not cleaned:
        raise ValueError("must not be empty")
    return cleaned


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Grammar(StrictModel):
    preterite: Optional[str]
    perfect: Optional[str]
    article: Optional[Literal["der", "die", "das"]] = None
    plural: Optional[str] = None
    comparative: Optional[str] = None
    superlative: Optional[str] = None

    @field_validator("preterite", "perfect", "plural", "comparative", "superlative", mode="before")
    @classmethod
    def clean_optional_text(cls, value: object) -> Optional[str]:
        if value is None:
            return None
        return _clean_required_text(value)


class VocabularyRecord(StrictModel):
    word: str = Field(min_length=1, max_length=120)
    lemma: str = Field(min_length=1, max_length=120)
    type: PartOfSpeech
    meaning_fa: list[str] = Field(min_length=1, max_length=8)
    meaning_en: list[str] = Field(min_length=1, max_length=8)
    example_de: str = Field(min_length=1, max_length=600)
    example_fa: str = Field(min_length=1, max_length=600)
    grammar: Grammar
    synonyms: list[str] = Field(max_length=12)
    level: CefrLevel

    @field_validator("word", "lemma", "example_de", "example_fa", mode="before")
    @classmethod
    def clean_text(cls, value: object) -> str:
        return _clean_required_text(value)

    @field_validator("meaning_fa", "meaning_en", "synonyms", mode="before")
    @classmethod
    def clean_text_list(cls, value: object) -> list[str]:
        if not isinstance(value, list):
            raise ValueError("must be an array")
        return [_clean_required_text(item) for item in value]

    @model_validator(mode="after")
    def validate_morphology(self) -> "VocabularyRecord":
        if self.type == "verb" and (not self.grammar.preterite or not self.grammar.perfect):
            raise ValueError("verbs require grammar.preterite and grammar.perfect")
        if self.type == "noun" and (not self.grammar.article or not self.grammar.plural):
            raise ValueError("nouns require grammar.article and grammar.plural")
        return self


class RecordMetadata(StrictModel):
    item_id: UUID = Field(default_factory=uuid4)
    source: Literal["ai", "legacy"] = "ai"
    provider: Optional[Provider] = None
    model: Optional[str] = None
    prompt_version: str
    source_input: str
    generated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    validation_state: ValidationState = "schema_validated_unverified"


class GeneratedVocabulary(StrictModel):
    record: VocabularyRecord
    metadata: RecordMetadata


class LookupRequest(StrictModel):
    word: str = Field(min_length=1, max_length=120)
    provider: Provider = "lmstudio"
    add_to_anki: bool = False

    @field_validator("word", mode="before")
    @classmethod
    def clean_word(cls, value: object) -> str:
        return _clean_required_text(value)


class LookupResponse(StrictModel):
    cached: bool
    anki_added: bool = False
    anki_error: Optional[str] = None
    metadata: RecordMetadata
    record: VocabularyRecord
