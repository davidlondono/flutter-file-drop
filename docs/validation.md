# Native validation checklist

Automated tests cover Dart routing, constraints, event parsing, file streaming, and the sample widget. Run `tool/verify_workspace.sh` before platform validation.

Native drag-and-drop needs platform hardware or a desktop session with an external drag source. Record device, OS version, Flutter version, result, and date for each run. Do not mark a platform validated from a successful compile alone. The simulator CI build targets iOS 15 because the current Xcode simulator SDK rejects deployment targets below 15; that build does not validate the iOS 13 minimum.

## Shared checks

- [ ] Drag one file and several files. Confirm source order, including mixed files and strings.
- [ ] Drag plain text, HTML, and a URI list. Confirm values remain raw and URI values are not fetched.
- [ ] Drag a directory. Confirm it appears as rejected and no contents are traversed.
- [ ] Enter, move across, leave, and drop. Confirm callbacks and global/local positions.
- [ ] Drag over nested targets. Confirm one whole batch reaches the deepest target that accepts an item.
- [ ] Mix accepted and rejected items. Confirm rejected items remain in source order with reasons.
- [ ] Check MIME, extension, file count, and reported-size constraints with missing metadata.
- [ ] Test a known oversized file and a source whose reported size is missing or inaccurate. Use a bounded reader to enforce the actual byte limit.
- [ ] Stream a file larger than 64 KiB. Confirm chunks stay bounded, bytes match, and Android does not reopen and rescan the URI for each chunk.
- [ ] Retain a `DropFile` after `onDrop` resolves. Confirm later reads fail with `callbackComplete`.
- [ ] Cancel a file stream after one chunk. Confirm the reader closes and the drop session releases after the callback.
- [ ] Leave or cancel a drag before dropping. Confirm no native file session or Android drag permission remains.
- [ ] Verify temporary files are removed after callback completion, including when reads fail or are cancelled.

Automated tests cover the Dart bounded-reader overflow and cancellation behavior, Android sequential-reader offsets and cleanup, metadata screening, and source ordering. Fake-platform tests do not prove native drag behavior.

## Platform runs

| Platform | Manual setup | Result |
| --- | --- | --- |
| Android | API 24+ physical device and a current Android device; drag files from Files and another app/provider | Not run |
| iOS | iPad on iOS 13 if available and a current iPad; use Files and another app as sources | Simulator build checked at iOS 15; iOS 13 hardware behavior pending |
| macOS | macOS 12 and current macOS; drag from Finder and a text source | Build checked locally; hardware behavior pending |
| Windows | Current supported Windows desktop; drag from Explorer and a text source | Not run |
| Linux | GTK 3 desktop under X11 and Wayland where available; drag from a file manager and text source | Not run |
| Web | Current desktop Chromium and Safari; drag from file manager and browser text/link sources | Not run |

Run the shared checks on each platform. On Android also repeat a multi-file drop from a cloud-backed provider and keep the callback open while reading to verify URI permission lifetime. On iOS include a provider that supports in-place access and one that uses provider staging when available; record that provider staging may copy the complete source before Dart can screen or bound reads. On Web confirm browser cancellation and directory items. Record unsupported source/OS combinations instead of marking them passed.

## Environment record

| Field | Value |
| --- | --- |
| Flutter / Dart | |
| Device or desktop | |
| OS version | |
| Date | |
| Result and notes | |
