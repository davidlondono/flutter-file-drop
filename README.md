# flutter_file_drop

Federated Flutter plugin for headless file and text drag-and-drop. `DropTarget` wraps an app-owned widget and reports drag lifecycle, metadata, payloads, positions, and per-item validation results.

## Packages

| Package | Purpose |
| --- | --- |
| [`flutter_file_drop`](packages/flutter_file_drop/README.md) | Public API and endorsed platform registrations |
| [`flutter_file_drop_platform_interface`](packages/flutter_file_drop_platform_interface/README.md) | Shared event and file-access contract |
| [`flutter_file_drop_android`](packages/flutter_file_drop_android/README.md) | Android native plugin |
| [`flutter_file_drop_darwin`](packages/flutter_file_drop_darwin/README.md) | iOS and macOS native plugins |
| [`flutter_file_drop_windows`](packages/flutter_file_drop_windows/README.md) | Windows native plugin |
| [`flutter_file_drop_linux`](packages/flutter_file_drop_linux/README.md) | Linux native plugin |
| [`flutter_file_drop_web`](packages/flutter_file_drop_web/README.md) | Browser plugin |

The façade owns the app API and routes whole batches to nested targets. Native implementations own operating-system drag sessions and temporary file access. No package renders a drop UI or delegates native work to another drag-and-drop package.

## Scope

Incoming drops only. Supported payloads are files and raw `text/plain`, `text/html`, and `text/uri-list` values. The package does not fetch URI values, traverse directories, sniff file contents, or promise local file paths. File reads stream in bounded chunks and remain valid until the awaited `onDrop` callback completes.

Requirements: Flutter 3.44+, Dart 3.12+, Android API 24+, iOS 13+, macOS 12+.

## Development

Use Flutter 3.44.2 or later. From the repository root:

```sh
flutter pub get
tool/verify_workspace.sh
```

Run native sample builds with the appropriate platform SDK. Track device and desktop validation using [`docs/validation.md`](docs/validation.md). Architecture choices are in [`docs/adr/`](docs/adr/).

## Release

Keep all seven package versions aligned. Publish the platform interface first, then the five implementation packages, then the façade. Run `dart pub publish --dry-run` in each package before publishing. Release order and compatibility policy are recorded in [ADR 0019](docs/adr/0019-release-policy.md).

BSD-3-Clause. See [LICENSE](LICENSE).
