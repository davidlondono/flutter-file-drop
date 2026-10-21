# flutter_file_drop_windows

Windows native implementation for [`flutter_file_drop`](https://pub.dev/packages/flutter_file_drop).

Use the façade package in applications. It registers this implementation automatically. The plugin uses Windows OLE drag-and-drop and exposes incoming files and supported text formats through the shared platform interface.

File reads use bounded chunks and session-scoped handles. Directory items are rejected. Build with the Windows Flutter toolchain.

BSD-3-Clause. See [LICENSE](LICENSE).
