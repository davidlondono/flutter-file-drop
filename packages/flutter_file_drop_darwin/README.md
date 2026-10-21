# flutter_file_drop_darwin

iOS and macOS native implementation for [`flutter_file_drop`](https://pub.dev/packages/flutter_file_drop).

Use the façade package in applications. It registers this implementation automatically. iOS 13 or later and macOS 12 or later are required.

The iOS adapter prefers in-place provider access, coordinates the source file, and stages it in a temporary session directory for reads during the awaited drop callback. Providers that cannot supply an in-place URL may create a full temporary source copy before the plugin can inspect it. Dart constraints and bounded reads cannot limit that provider-owned copy; the package does not impose a fixed staging cap. A consumer-specific cap on the package's own staging would require a two-phase native protocol that selects a target and its limits before file loading. The package-owned session directory is deleted after the callback completes. The macOS adapter reads file URLs from the pasteboard and manages security-scoped access for each drop session.

Both platforms preserve item order, reject directories, and stream file contents in bounded chunks. iOS does not expose a local file path; macOS paths are optional.

BSD-3-Clause. See [LICENSE](LICENSE).
