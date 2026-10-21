import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Kind of payload represented by a [DropItem].
enum DropItemKind { file, string }

/// Reason the drop target rejected one item.
enum DropRejectionReason {
  unsupportedKind,
  metadataUnavailable,
  mimeTypeNotAllowed,
  extensionNotAllowed,
  maxFilesExceeded,
  fileTooLarge,
  fileSizeUnknown,
  accessFailed,
}

/// Failure category raised while reading a [DropFile].
enum DropFileReadFailure {
  callbackComplete,
  unavailable,
  platform,
  maxBytesExceeded,
}

/// Error raised when a dropped file cannot be read.
class DropFileReadException implements Exception {
  /// Creates an error with a typed [reason] and optional platform [cause].
  const DropFileReadException(this.reason, [this.cause]);

  /// Failure category.
  final DropFileReadFailure reason;

  /// Underlying platform or stream error, when available.
  final Object? cause;

  @override
  String toString() => 'DropFileReadException($reason)';
}

/// A file or string received from an external drag source.
sealed class DropItem {
  const DropItem();

  /// Payload kind.
  DropItemKind get kind;
}

/// File metadata and session-scoped access to a dropped file's bytes.
class DropFile extends DropItem {
  @internal
  factory DropFile.fromPlatform({
    required String? name,
    required String? mimeType,
    required int? size,
    required DateTime? lastModified,
    required String? path,
    required String sessionId,
    required String handle,
    required Future<Uint8List?> Function(
      String sessionId,
      String handle,
      String readId,
      int offset,
      int maxBytes,
    )
    readChunk,
    required Future<void> Function(
      String sessionId,
      String handle,
      String readId,
    )
    releaseRead,
  }) => DropFile._(
    name: name,
    mimeType: mimeType,
    size: size,
    lastModified: lastModified,
    path: path,
    sessionId: sessionId,
    handle: handle,
    readChunk: readChunk,
    releaseRead: releaseRead,
  );

  DropFile._({
    required this.name,
    required this.mimeType,
    required this.size,
    required this.lastModified,
    required this.path,
    required this._sessionId,
    required this._handle,
    required this._readChunk,
    required this._releaseRead,
  });

  /// Display name supplied by the source, when available.
  final String? name;

  /// MIME type supplied by the source, when available.
  final String? mimeType;

  /// File size supplied by the source, when available.
  final int? size;

  /// Last modified time supplied by the source, when available.
  final DateTime? lastModified;

  /// Local path when the platform can safely provide one.
  final String? path;
  final String _sessionId;
  final String _handle;
  final Future<Uint8List?> Function(
    String sessionId,
    String handle,
    String readId,
    int offset,
    int maxBytes,
  )
  _readChunk;
  final Future<void> Function(String sessionId, String handle, String readId)
  _releaseRead;
  static int _nextReadId = 0;
  bool _isValid = true;

  @override
  DropItemKind get kind => DropItemKind.file;

  /// Reads file data in bounded 64 KiB chunks, optionally limiting total bytes.
  ///
  /// When [maxBytes] is set, throws [DropFileReadException] with
  /// [DropFileReadFailure.maxBytesExceeded] if the source contains more bytes.
  /// At most one byte beyond the limit is read to detect overflow. This checks
  /// bytes actually delivered by the platform, unlike [size] metadata.
  /// Consume this stream before the awaited `onDrop` callback completes.
  Stream<Uint8List> openRead({int? maxBytes}) async* {
    if (maxBytes != null && maxBytes < 0) {
      throw ArgumentError.value(
        maxBytes,
        'maxBytes',
        'Must be zero or greater.',
      );
    }
    if (!_isValid) {
      throw const DropFileReadException(DropFileReadFailure.callbackComplete);
    }
    final readId = 'read-${_nextReadId++}';
    var offset = 0;
    try {
      while (true) {
        if (!_isValid) {
          throw const DropFileReadException(
            DropFileReadFailure.callbackComplete,
          );
        }
        final remaining = maxBytes == null ? null : maxBytes - offset;
        final requestBytes = remaining == null || remaining >= 64 * 1024
            ? 64 * 1024
            : remaining + 1;
        late final Uint8List? bytes;
        try {
          bytes = await _readChunk(
            _sessionId,
            _handle,
            readId,
            offset,
            requestBytes,
          );
        } on PlatformException catch (error) {
          throw DropFileReadException(DropFileReadFailure.platform, error);
        } catch (error) {
          throw DropFileReadException(DropFileReadFailure.unavailable, error);
        }
        if (!_isValid) {
          throw const DropFileReadException(
            DropFileReadFailure.callbackComplete,
          );
        }
        if (bytes == null || bytes.isEmpty) return;
        if (bytes.length > requestBytes || bytes.length > 64 * 1024) {
          throw const DropFileReadException(DropFileReadFailure.unavailable);
        }
        if (remaining != null && bytes.length > remaining) {
          throw const DropFileReadException(
            DropFileReadFailure.maxBytesExceeded,
          );
        }
        offset += bytes.length;
        yield bytes;
      }
    } finally {
      try {
        await _releaseRead(_sessionId, _handle, readId);
      } catch (_) {
        // Session release still runs when the onDrop callback completes.
      }
    }
  }

  /// Reads the complete file into memory, subject to optional [maxBytes].
  ///
  /// Use [openRead] when files may be large.
  Future<Uint8List> readAsBytes({int? maxBytes}) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in openRead(maxBytes: maxBytes)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @internal
  void invalidate() => _isValid = false;
}

/// Raw text payload and its source MIME type.
class DropString extends DropItem {
  /// Creates a text payload with its original [value] and [mimeType].
  const DropString({required this.value, required this.mimeType});

  /// Original text. URI-list values are not fetched or resolved.
  final String value;

  /// Source MIME type, when available.
  final String? mimeType;

  @override
  DropItemKind get kind => DropItemKind.string;
}

/// Metadata available while the pointer is over a drop target.
@immutable
class DropItemPreview {
  /// Creates a metadata preview for one source item.
  const DropItemPreview({
    required this.kind,
    this.name,
    this.mimeType,
    this.size,
    this.lastModified,
  });

  /// Payload kind.
  final DropItemKind kind;

  /// Source name, when available.
  final String? name;

  /// Source MIME type, when available.
  final String? mimeType;

  /// Source size, when available.
  final int? size;

  /// Source modification time, when available.
  final DateTime? lastModified;
}

/// Drag position and source-ordered item metadata.
@immutable
class DropPreview {
  /// Creates a preview at the given global and target-local positions.
  DropPreview({
    required this.globalPosition,
    required this.localPosition,
    required List<DropItemPreview> items,
  }) : items = List.unmodifiable(items);

  /// Pointer position in Flutter's global logical pixels.
  final Offset globalPosition;

  /// Pointer position in the target's local coordinates.
  final Offset localPosition;

  /// Source-ordered metadata for items in the current drag.
  final List<DropItemPreview> items;
}

/// Metadata rules applied to each item before it is accepted.
@immutable
class DropConstraints {
  /// Creates constraints; different constraint types combine.
  ///
  /// Values within each allowlist are alternatives. Null disables that rule;
  /// an empty allowlist rejects every item to which it applies.
  DropConstraints({
    Set<DropItemKind>? allowedKinds,
    Set<String>? allowedMimeTypes,
    Set<String>? allowedExtensions,
    int? maxFiles,
    int? maxFileSizeBytes,
  }) : allowedKinds = allowedKinds == null
           ? null
           : Set.unmodifiable(allowedKinds),
       allowedMimeTypes = allowedMimeTypes == null
           ? null
           : Set.unmodifiable(allowedMimeTypes),
       allowedExtensions = allowedExtensions == null
           ? null
           : Set.unmodifiable(allowedExtensions),
       maxFiles = _validateLimit('maxFiles', maxFiles),
       maxFileSizeBytes = _validateLimit('maxFileSizeBytes', maxFileSizeBytes);

  /// Creates constraints that accept all supported items.
  const DropConstraints.unrestricted()
    : allowedKinds = null,
      allowedMimeTypes = null,
      allowedExtensions = null,
      maxFiles = null,
      maxFileSizeBytes = null;

  /// Allowed payload kinds, or null to allow both kinds.
  final Set<DropItemKind>? allowedKinds;

  /// MIME types or wildcard patterns, such as `image/*`.
  final Set<String>? allowedMimeTypes;

  /// Final filename extensions, with or without a leading dot.
  final Set<String>? allowedExtensions;

  /// Maximum number of otherwise eligible files. Strings do not count.
  final int? maxFiles;

  /// Maximum reported file size in bytes. Unknown sizes are rejected when set.
  /// This metadata check does not limit bytes read from the file.
  final int? maxFileSizeBytes;

  static int? _validateLimit(String name, int? value) {
    if (value != null && value < 0) {
      throw ArgumentError.value(value, name, 'Must be zero or greater.');
    }
    return value;
  }
}

/// One item and its validation result.
@immutable
class DropResultItem {
  /// Creates a result; an empty [reasons] list means accepted.
  DropResultItem({
    required this.item,
    required List<DropRejectionReason> reasons,
  }) : reasons = List.unmodifiable(reasons);

  /// File or string received from the source.
  final DropItem item;

  /// Rejection reasons. Empty means the item was accepted.
  final List<DropRejectionReason> reasons;

  /// Whether this item passed every configured rule.
  bool get accepted => reasons.isEmpty;
}

/// Source-ordered validation results for one completed drop.
@immutable
class DropResult {
  /// Creates a result at the global and target-local drop positions.
  DropResult({
    required this.globalPosition,
    required this.localPosition,
    required List<DropResultItem> items,
  }) : items = List.unmodifiable(items);

  /// Pointer position in Flutter's global logical pixels.
  final Offset globalPosition;

  /// Pointer position in the target's local coordinates.
  final Offset localPosition;

  /// All source items in their original order.
  final List<DropResultItem> items;

  /// Accepted items in source order.
  List<DropResultItem> get accepted =>
      List.unmodifiable(items.where((item) => item.accepted));

  /// Rejected items in source order.
  List<DropResultItem> get rejected =>
      List.unmodifiable(items.where((item) => !item.accepted));

  /// Whether at least one item passed validation.
  bool get hasAcceptedItems => items.any((item) => item.accepted);
}
