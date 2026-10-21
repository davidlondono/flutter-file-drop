# Limit file count and per-file size

Version 1 exposes `maxFiles` and `maxFileSizeBytes`. `maxFiles` counts files that pass the other configured constraints, in source order; strings do not count. `maxFileSizeBytes` screens each file using reported metadata. If size is unavailable while this constraint is active, reject that file. It does not cap actual bytes read; use `DropFile.openRead(maxBytes:)` or `readAsBytes(maxBytes:)` for an actual-byte limit. Version 1 will not impose an aggregate batch-size limit. MIME and item-type filters also apply to string payloads.
