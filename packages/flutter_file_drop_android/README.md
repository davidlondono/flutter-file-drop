# flutter_file_drop_android

Android native implementation for [`flutter_file_drop`](https://pub.dev/packages/flutter_file_drop).

Use the façade package in applications. It registers this implementation automatically. Android API 24 or later is required. The plugin reads dropped content through Android content URIs and keeps temporary drag permissions until the awaited drop callback completes.

Incoming files, supported text formats, metadata, and session-scoped chunk reads are exposed through the shared platform interface. Directories are rejected. This package does not request persistent storage access or fetch URI text.

BSD-3-Clause. See [LICENSE](LICENSE).
