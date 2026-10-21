# flutter_file_drop_darwin

iOS and macOS native implementation for [`flutter_file_drop`](https://pub.dev/packages/flutter_file_drop).

Use the façade package in applications. It registers this implementation automatically. iOS 15 or later and macOS 12 or later are required.

The iOS adapter uses UIKit drop interactions and copies provider files into a temporary session directory. Those files are deleted after the awaited drop callback completes. The macOS adapter reads file URLs from the pasteboard and manages security-scoped access for each drop session.

Both platforms preserve item order, reject directories, and stream file contents in bounded chunks. iOS does not expose a local file path; macOS paths are optional.

BSD-3-Clause. See [LICENSE](LICENSE).
