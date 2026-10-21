# Expose a headless drop target widget

The app-facing package will expose a headless `DropTarget` widget that wraps an app-owned child and reports `onEnter`, `onMove`, `onLeave`, and `onDrop` callbacks. `onEnter` and `onMove` receive best-effort metadata previews and pointer position. `onDrop` receives a source-ordered `DropResult` with accepted and rejected views. The widget will not impose visual presentation; the host app owns the target's appearance. See [ADR 0014](0014-preview-and-callback-lifetime.md) and [ADR 0015](0015-source-ordered-results.md).

When targets are nested, the innermost target that accepts at least one item receives the full batch, including rejected items. If no target accepts any item, the deepest target under the pointer receives an all-rejected result. Never split one batch across targets; see [ADR 0010](0010-nested-drop-targets.md).

Platform implementations capture drops at the Flutter host view or window and send positions and item handles to Dart. Dart routes events to registered `DropTarget` widgets; platform packages do not add an overlay view for each target. See [ADR 0013](0013-route-drops-in-dart.md).

The package will expose its own `DropFile` and `DropString` types. `DropFile` provides nullable name, MIME type, size, last-modified time, and optional filesystem path, plus byte and stream reads without exposing backend types. `DropString` preserves the raw value and MIME type. File reads remain scoped to the awaited `onDrop` callback, as recorded in [ADR 0003](0003-callback-scoped-file-access.md). `DropPreview` and `DropResult` include global and target-local positions; see [ADR 0018](0018-public-drop-data-types.md).
