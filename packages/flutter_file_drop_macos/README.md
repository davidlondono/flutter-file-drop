# flutter_file_drop_macos

macOS native implementation for [`flutter_file_drop`](https://pub.dev/packages/flutter_file_drop).

Use the façade package in applications. It registers this implementation automatically. macOS 12 or later is required. The plugin registers a native file and text drop target over the Flutter view and reads files in bounded chunks while the drop session remains active.

Incoming files and supported text formats preserve source order. Directory items are rejected. File paths are optional; use the chunk stream for portable access.

BSD-3-Clause. See [LICENSE](LICENSE).
