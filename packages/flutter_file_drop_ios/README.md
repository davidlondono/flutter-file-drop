# flutter_file_drop_ios

iOS native implementation for [`flutter_file_drop`](https://pub.dev/packages/flutter_file_drop).

Use the façade package in applications. It registers this implementation automatically. iOS 15 or later is required. The plugin uses UIKit drop interactions and copies provider files into a temporary session directory. Temporary files are deleted after the awaited drop callback completes.

Incoming files and supported text representations preserve source order. Directories are rejected. A local file path is not exposed; use the file's chunk stream.

BSD-3-Clause. See [LICENSE](LICENSE).
