# flutter_file_drop_android

Android native implementation for [`flutter_file_drop`](https://pub.dev/packages/flutter_file_drop).

Use the façade package in applications. It registers this implementation automatically. Android API 24 or later is required. The plugin reads dropped content through Android content URIs and keeps temporary drag permissions until the awaited drop callback completes.

Incoming files, supported text formats, metadata, and session-scoped chunk reads are exposed through the shared platform interface. Each reader keeps one sequential `ContentResolver` stream open until EOF, cancellation, or drop-session release. Drag permissions remain active through the awaited `onDrop` callback. Directories are rejected. This package does not request persistent storage access or fetch URI text.

The Android build uses the consuming app's Android Gradle Plugin and Kotlin Gradle Plugin versions. Keep those plugins configured in the host app's Gradle settings; the package does not add its own version pins. CI validates Gradle 9.1, AGP 9.0.1, and KGP 2.3.20 with Flutter 3.44.2 in legacy KGP mode; other combinations are not yet verified. Flutter's built-in Kotlin mode requires Flutter 3.47 or later and a migrated host app and plugins.

BSD-3-Clause. See [LICENSE](LICENSE).
