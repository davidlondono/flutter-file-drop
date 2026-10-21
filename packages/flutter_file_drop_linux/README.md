# flutter_file_drop_linux

Linux native implementation for [`flutter_file_drop`](https://pub.dev/packages/flutter_file_drop).

Use the façade package in applications. It registers this implementation automatically. The plugin uses GTK drag-and-drop signals and local file handles to expose incoming files and supported text formats through the shared platform interface.

File reads use bounded chunks and session-scoped handles. Directory items are rejected. Build with GTK 3 development libraries installed.

BSD-3-Clause. See [LICENSE](LICENSE).
