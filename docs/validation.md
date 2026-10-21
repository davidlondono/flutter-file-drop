# Native validation checklist

Automated tests cover Dart routing, constraints, event parsing, file streaming, and the sample widget. Run `tool/verify_workspace.sh` before platform validation.

Native drag-and-drop needs platform hardware or a desktop session with an external drag source. Record device, OS version, Flutter version, result, and date for each run. Do not mark a platform validated from a successful compile alone.

## Shared checks

- [ ] Drag one file and several files. Confirm source order and nullable metadata handling.
- [ ] Drag plain text, HTML, and a URI list. Confirm values remain raw and URI values are not fetched.
- [ ] Drag a directory. Confirm it appears as rejected and no contents are traversed.
- [ ] Enter, move across, leave, and drop. Confirm callbacks and global/local positions.
- [ ] Drag over nested targets. Confirm one whole batch reaches the deepest target that accepts an item.
- [ ] Check MIME, extension, file count, and size constraints, including missing metadata.
- [ ] Stream a file larger than 64 KiB. Confirm chunks stay bounded and bytes match.
- [ ] Retain a `DropFile` after `onDrop` resolves. Confirm later reads fail with `callbackComplete`.
- [ ] Cancel or leave a drag before dropping. Confirm no file session remains open.

## Platform runs

| Platform | Manual setup | Result |
| --- | --- | --- |
| Android | API 24+ device; drag from an app that exposes draggable content | Not run |
| iOS | iOS 15+ iPad with Files and a second app visible for drag and drop | Simulator build checked locally; hardware run pending |
| macOS | macOS 12+; drag from Finder and a text source | Build checked locally; hardware run pending |
| Windows | Supported Windows desktop; drag from Explorer and a text source | Not run |
| Linux | GTK 3 desktop under X11 and Wayland where available | Not run |
| Web | Desktop browser; drag from file manager and browser text/link sources | Not run |

## Environment record

| Field | Value |
| --- | --- |
| Flutter / Dart | |
| Device or desktop | |
| OS version | |
| Date | |
| Result and notes | |
