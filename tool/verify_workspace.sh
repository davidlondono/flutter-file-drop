#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

flutter pub get

find packages \
  -type d \( -name build -o -name .dart_tool \) -prune -o \
  -type f -name '*.dart' -print0 |
  xargs -0 dart format --output=none --set-exit-if-changed

for package in packages/*; do
  [[ -f "$package/pubspec.yaml" ]] || continue
  (
    cd "$package"
    flutter analyze --no-pub
    if [[ -n "$(find test -type f -name '*_test.dart' -print -quit 2>/dev/null)" ]]; then
      flutter test --no-pub
    fi
  )
done

(
  cd packages/flutter_file_drop/example
  flutter analyze --no-pub
  flutter test --no-pub
)
