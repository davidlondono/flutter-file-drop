# Flutter file drop

This context defines how Flutter apps receive files through drag and drop, without imposing visual presentation.

## Language

**Incoming drop**:
A gesture that transfers one or more files into a Flutter app. Starting a drag from the app is outside this context.
_Avoid_: outbound drag

**Headless drop handling**:
Drop detection and file access without package-owned visual presentation. The host app owns what users see.

**Drop lifecycle**:
The events reported through enter, move, leave, and drop callbacks.

**Drop preview**:
Best-effort item metadata and pointer position reported while a drag is over a target. Fields may be unavailable until drop.

**Drop position**:
The drag location in global and target-local Flutter coordinates.

**Drop target**:
A headless target that receives incoming drops and reports lifecycle events. The host app supplies its visual child.

**String payload**:
Plain text, HTML, or URI-list content supplied by a drag source with a content type. URI values remain data; the package does not fetch them.

**Drop item**:
A typed entry in a drop batch. It represents a file or a MIME-tagged string payload, and preserves each representation supplied by the source.

**Drop result**:
The ordered outcome of a completed drop. Each item is accepted or rejected; rejected items include reasons. Accepted and rejected views are available.

**File context**:
The metadata and content access provided for a dropped file. It includes byte and stream reads; a filesystem path is available only on platforms that provide one.

**Drop file**:
The package-owned file item type. It exposes nullable name, MIME type, size, modification time, and path metadata, plus callback-scoped byte and stream reads without exposing platform backend types.

**Drop string**:
The package-owned string item type. It exposes the raw string value and MIME type without parsing HTML or URI lists.

**Drop read error**:
A typed failure raised when reading an accepted file fails during the awaited drop callback.

**Drop screening**:
Checks against available item metadata, such as type, MIME, extension, count, or size. Screening can run during preview or after drop when preview metadata is missing. It does not verify file contents.

**Drop constraints**:
Declarative rules for item types, MIME types, extensions, maximum file count, and per-file size.

**Rejection reason**:
A typed explanation for a failed drop constraint or item-access failure. An item may have multiple reasons.

**Nested drop targets**:
Drop targets arranged inside other drop targets. The innermost target accepting any item receives the whole batch; if no target accepts an item, the deepest target receives an all-rejected result.

**Drop routing**:
Selection of the `DropTarget` under the native drag position. The Flutter layer routes host-view events through registered target bounds and hit testing.

**Partial acceptance**:
A batch outcome where accepted items are delivered and each rejected item has a reason.

**Content validation**:
Application-defined checks performed on file data after it is read.
