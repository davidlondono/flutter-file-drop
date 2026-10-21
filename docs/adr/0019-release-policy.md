# Align package licensing and releases

License all eight packages under BSD-3-Clause. Use `flutter_file_drop contributors` as the copyright holder in each package license file.

Keep all eight package versions aligned. Start at `0.1.0`; release `1.0.0` after the six platform implementations pass the manual drag-and-drop checklist. Publish the platform interface first, platform implementations next, and the app-facing package last.

Omit repository and issue-tracker URLs from package metadata until the repository has a Git remote. Do not publish placeholder URLs.
