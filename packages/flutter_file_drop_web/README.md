# flutter_file_drop_web

Browser implementation for [`flutter_file_drop`](https://pub.dev/packages/flutter_file_drop).

Use the façade package in applications. Flutter registers this implementation automatically. It listens to browser drag events while a `DropTarget` is mounted and reads dropped files in bounded slices.

The browser exposes raw `text/plain`, `text/html`, and `text/uri-list` values when supplied. URI values are not fetched. Browser security rules may omit file paths or metadata. Directories are rejected.

While a `DropTarget` is mounted, the plugin prevents the browser's default drag-over behavior so a later `drop` event can reach Flutter. The browser may show a copy cursor anywhere in the page; Dart hit testing still routes the batch only to a target under the pointer.

BSD-3-Clause. See [LICENSE](LICENSE).
