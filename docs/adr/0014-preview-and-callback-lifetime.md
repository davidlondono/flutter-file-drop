# Keep previews metadata-only and scope reads to the awaited drop callback

`onEnter` and `onMove` will receive a best-effort preview with pointer position and available item metadata. Fields remain nullable when a platform cannot provide them before drop. Previews will not expose file bytes or string payload contents. `onLeave` takes no arguments; applications can retain the last preview if needed.

Enter, move, and leave callbacks will be synchronous. `onDrop` will return `Future<void>`; file reads remain available until that future completes. A file read failure during the callback throws a typed error to the caller. An access failure found before delivery becomes a rejected item. Callback errors reach Flutter's error zone, and native access is released when the callback finishes, including when it throws.
