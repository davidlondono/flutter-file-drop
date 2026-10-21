# Use federated platform packages

We will keep one app-facing package, a shared platform interface, and separate implementation packages for Web, Android, iOS, macOS, Windows, and Linux in this repository. The app-facing package will be `flutter_file_drop`; companion packages will use the `flutter_file_drop_<platform>` prefix and `flutter_file_drop_platform_interface` for the interface.

The app-facing package will endorse all six implementations through dependencies and `default_package` entries, so app developers need only add `flutter_file_drop`. This follows [Flutter's federated plugin guidance](https://docs.flutter.dev/packages-and-plugins/developing-packages).

At 2026-10-21T02:41:04Z, Pub.dev returned 404 for the proposed package slugs. This does not reserve them; check again before publishing.
