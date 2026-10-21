# Use Pigeon commands and EventChannel streams

Native implementations will use Pigeon-generated typed APIs for file-handle operations and other request/response calls. An `EventChannel` will deliver ongoing drag lifecycle events. The Web implementation will use Dart JavaScript interop.

`DropFile.openRead` will request bounded byte chunks from the platform. `DropFile.readAsBytes` will collect those chunks into one byte buffer. This keeps streaming reads bounded in memory; the caller remains responsible for the memory used by `readAsBytes`.
