# Report every rejection reason per item

Each rejected item will include all applicable typed reasons, such as unsupported kind, unavailable metadata required by an active filter, disallowed MIME type, disallowed extension, file-count overflow, file-size overflow, unknown file size under an active size limit, or an item-access failure detected before delivery. A later file read failure throws a typed error to the caller and does not change the delivered result. Results preserve source order, including files rejected after `maxFiles` is reached; see [ADR 0015](0015-source-ordered-results.md).
