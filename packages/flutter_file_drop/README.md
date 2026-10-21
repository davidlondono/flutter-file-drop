# flutter_file_drop

Headless drag-and-drop for files and text in Flutter. It provides a `DropTarget` wrapper; your app owns all visuals and layout.

## Features

- Native incoming drops on Android, iOS, macOS, Windows, Linux, and web.
- File metadata previews while dragging, plus ordered per-item results after drop.
- Streaming file reads and raw `text/plain`, `text/html`, and `text/uri-list` values.
- Declarative kind, MIME type, extension, file count, and file size constraints.
- Nested targets, global and target-local pointer positions, and rejection reasons.

The package does not start outgoing drags, fetch URI values, traverse directories, or render a drop UI. Directories are reported as rejected items. File paths are optional and may be absent.

## Requirements

- Flutter 3.44 or later; Dart 3.12 or later.
- Android API 24+, iOS 13+, and macOS 12+ for native builds.

Add the dependency:

```yaml
dependencies:
  flutter_file_drop: ^0.1.0
```

The façade selects the platform implementation through Flutter plugin registration.

## Usage

Wrap any app-owned widget. The package adds no visual decoration.

```dart
DropTarget(
  constraints: DropConstraints(
    allowedMimeTypes: {'image/*'},
    maxFiles: 3,
    maxFileSizeBytes: 10 * 1024 * 1024,
  ),
  onEnter: (preview) => setState(() => hovering = true),
  onLeave: () => setState(() => hovering = false),
  onDrop: (result) async {
    for (final entry in result.items) {
      if (!entry.accepted) {
        debugPrint('Rejected: ${entry.reasons}');
        continue;
      }

      final item = entry.item;
      if (item is DropFile) {
        debugPrint('${item.name}: ${item.size} bytes');
        await for (final chunk in item.openRead()) {
          processChunk(chunk);
        }
      } else if (item is DropString) {
        debugPrint('${item.mimeType}: ${item.value}');
      }
    }
  },
  child: const MyDropSurface(),
)
```

`DropFile.openRead()` yields bounded 64 KiB chunks. Pass `maxBytes` to enforce a limit against bytes actually read; the reader may inspect one additional byte to detect overflow. `DropConstraints.maxFileSizeBytes` screens reported metadata only. `readAsBytes()` reads the full file into memory unless `maxBytes` is set. Keep file reads inside the awaited `onDrop` callback; native file access ends when that callback completes. `DropFile.path` can be null, and applications should use `openRead()` for portable access.

`DropPreview` and `DropResult` expose global and local positions. `DropResult.items` keeps source order and includes accepted and rejected items. The `accepted` and `rejected` getters are filtered views.

## Constraint rules

- Values within one allowlist are alternatives; different constraints combine.
- MIME matching is case-insensitive and supports wildcards such as `image/*`.
- Extensions match the final filename extension, with or without a leading dot.
- Unknown metadata rejects an item when that metadata is required by a constraint.
- `maxFiles` counts files that pass other constraints. Strings do not count.
- `maxFileSizeBytes` uses reported size metadata; unknown size is rejected when set. It does not cap bytes read.
- For a hard content limit, use `openRead(maxBytes: ...)` or `readAsBytes(maxBytes: ...)` and handle `DropFileReadFailure.maxBytesExceeded`.
- Nested targets receive the whole batch at the deepest target accepting any item. If none accepts an item, the deepest target receives the rejected batch.

See [`example/`](example) for a runnable sample.

## Platform packages

This package endorses `flutter_file_drop_android`, `flutter_file_drop_darwin`, `flutter_file_drop_windows`, `flutter_file_drop_linux`, and `flutter_file_drop_web`. Use the façade in application code. `flutter_file_drop_platform_interface` is for implementation authors.

## Development before publication

Until all seven packages are published, an app can use path overrides from a checkout:

```yaml
dependency_overrides:
  flutter_file_drop:
    path: ../flutter-file-drop/packages/flutter_file_drop
  flutter_file_drop_platform_interface:
    path: ../flutter-file-drop/packages/flutter_file_drop_platform_interface
  flutter_file_drop_android:
    path: ../flutter-file-drop/packages/flutter_file_drop_android
  flutter_file_drop_darwin:
    path: ../flutter-file-drop/packages/flutter_file_drop_darwin
  flutter_file_drop_windows:
    path: ../flutter-file-drop/packages/flutter_file_drop_windows
  flutter_file_drop_linux:
    path: ../flutter-file-drop/packages/flutter_file_drop_linux
  flutter_file_drop_web:
    path: ../flutter-file-drop/packages/flutter_file_drop_web
```

For Git development, point each override to this repository, the matching `packages/<package>` path, and the same commit or tag. Keep the interface and implementation packages on one revision. Remove the overrides and depend on the façade after publication.

## License

BSD-3-Clause. See [LICENSE](LICENSE).
