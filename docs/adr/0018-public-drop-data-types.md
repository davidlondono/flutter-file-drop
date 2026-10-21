# Expose package-owned file and string data types

`DropFile` will expose nullable `name`, `mimeType`, `size`, `lastModified`, and local `path` metadata. It will expose callback-scoped `openRead` and `readAsBytes` methods. Platforms may leave metadata null when the source does not provide it.

`DropString` will expose raw `value` and `mimeType`. The package will not parse HTML or URI-list values.

`DropPreview` and `DropResult` will expose both global and target-local positions as Flutter `Offset` values. Preview metadata remains best-effort.
