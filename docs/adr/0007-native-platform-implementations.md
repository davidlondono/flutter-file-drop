# Implement native platform backends

Each federated implementation will connect directly to its platform's drag-and-drop APIs. The repository will implement Web, Android, iOS, macOS, Windows, and Linux support; it will not delegate drag-and-drop behavior to `desktop_drop`, `flutter_dropzone`, `super_drag_and_drop`, or similar packages. Keep platform types behind the package-owned platform interface.

The three packages informed the contract, but they will not be runtime dependencies: [`desktop_drop`](https://pub.dev/packages/desktop_drop), [`flutter_dropzone`](https://pub.dev/packages/flutter_dropzone), and [`super_drag_and_drop`](https://pub.dev/packages/super_drag_and_drop).

This choice requires native implementation and maintenance for each supported platform. Set Flutter, Dart, and operating-system minimum versions before coding.
