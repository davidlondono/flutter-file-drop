# Use Pub workspaces and validate every package

Use a Dart Pub workspace for the package monorepo, with a `packages/*` workspace glob. Do not add Melos initially. Dart 3.12 supports Pub workspace globs.

Keep one example Flutter app under `flutter_file_drop/example`. Use app-owned visuals and demonstrate hover previews, constraints, file streams and bytes, strings, and partial results across supported platforms.

Add tests for screening and widget routing with a fake platform backend. CI will format, analyze, test, run publish dry-runs for each publishable package, and build supported platform implementations. Keep real operating-system drag checks in a manual validation checklist for each platform.
