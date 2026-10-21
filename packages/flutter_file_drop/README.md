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
- Android API 24+, iOS 15+, and macOS 12+ for native builds.

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

`DropFile.openRead()` yields bounded 64 KiB chunks. `readAsBytes()` reads the full file into memory. Keep file reads inside the awaited `onDrop` callback; native file access ends when that callback completes. `DropFile.path` can be null, and applications should use `openRead()` for portable access.

`DropPreview` and `DropResult` expose global and local positions. `DropResult.items` keeps source order and includes accepted and rejected items. The `accepted` and `rejected` getters are filtered views.

## Constraint rules

- Values within one allowlist are alternatives; different constraints combine.
- MIME matching is case-insensitive and supports wildcards such as `image/*`.
- Extensions match the final filename extension, with or without a leading dot.
- Unknown metadata rejects an item when that metadata is required by a constraint.
- `maxFiles` counts files that pass other constraints. Strings do not count.
- Size checks use platform metadata; the package does not inspect file contents.
- Nested targets receive the whole batch at the deepest target accepting any item. If none accepts an item, the deepest target receives the rejected batch.

See [`example/`](example) for a runnable sample.

## Platform packages

This package endorses `flutter_file_drop_android`, `flutter_file_drop_darwin`, `flutter_file_drop_windows`, `flutter_file_drop_linux`, and `flutter_file_drop_web`. Use the façade in application code. `flutter_file_drop_platform_interface` is for implementation authors.

## License

BSD-3-Clause. See [LICENSE](LICENSE).
