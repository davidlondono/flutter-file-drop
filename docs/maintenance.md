# Repository maintenance

## Dependency updates

- Dependabot updates GitHub Actions once a week. It does not update Dart packages.
- Renovate updates Pub dependencies across workspace `pubspec.yaml` files once a week. Minor and patch updates are grouped; major updates stay separate. Updates do not merge automatically.
- Install the [Mend Renovate GitHub App](https://github.com/apps/renovate) for `davidlondono/flutter-file-drop` to activate `renovate.json`.

Each dependency pull request runs the existing CI checks. Keep the `pub` and `github-actions` scopes separate to avoid duplicate pull requests.

## CI cadence

- `.github/workflows/ci.yml` checks Flutter 3.44.2 and builds the native example targets on pull requests and pushes.
- `.github/workflows/weekly-stable.yml` runs workspace analysis and tests against the latest Flutter stable channel every Monday at 04:00 in Colombia. It can also run from GitHub Actions with `workflow_dispatch`.
- CI builds do not replace the manual drag behavior checks in [`validation.md`](validation.md).

## GitHub security settings

In repository Settings, enable Dependabot alerts, Dependabot security updates, and private vulnerability reporting. These are repository settings; the update configuration files do not enable them.

## Package releases

Keep all seven package versions aligned. Publish in this order: platform interface, five platform implementations, then the public façade. Run `dart pub publish --dry-run` in every package before release. See [ADR 0019](adr/0019-release-policy.md).

For future release automation, configure pub.dev trusted publishing for each package and use version-matched Git tags. Pub.dev requires tag-triggered GitHub Actions and a separate tag pattern per package; see the [Dart automated publishing guide](https://dart.dev/tools/pub/automated-publishing).
