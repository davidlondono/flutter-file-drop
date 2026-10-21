# Define allowlist matching and file-count semantics

Values in one allowlist use OR matching. Different configured constraint categories use AND matching. MIME types and filename extensions match case-insensitively. MIME wildcards such as `image/*` are supported. A missing allowlist adds no restriction; an empty allowlist rejects every applicable item.

MIME screening uses MIME metadata supplied by the drag source. Extension screening uses the source filename. The package will not inspect bytes to infer either value. If metadata required by an active filter remains unavailable after drop, reject the item with a typed metadata-unavailable reason. MIME and item-kind constraints apply to files and strings; extensions and size limits apply only to files.

`maxFiles` counts files that pass the other configured constraints, in source order. A file rejected by another constraint does not consume the file-count limit. Strings do not count. When `maxFileSizeBytes` is active and final size remains unavailable, reject the file with a typed reason.
