# Export Manifest Contract v1

The manifest is an internal validation/audit record and is not required to be a trusted Anki card field.

Required fields:

```json
{
  "export_id": "uuid",
  "schema_version": "apkg-export-v1",
  "source_groups": ["hermes_generated"],
  "card_identities": [],
  "collection_entry": "collection.anki21",
  "media": [{
    "source_asset_id": "uuid",
    "anki_index": 0,
    "sha256": "hex",
    "byte_size": 0,
    "availability": "available"
  }],
  "scheduling_policy": "preserved|fresh_anki_with_warning",
  "validation": {"integrity": "passed"}
}
```

