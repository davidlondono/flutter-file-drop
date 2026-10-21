/// Internal transport contract for `flutter_file_drop` platform packages.
library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/messages.g.dart';

/// Lifecycle event emitted while an external item moves over a drop target.
enum PlatformDropEventType { enter, move, leave, drop }

/// Kind of item in a native drop batch.
enum PlatformDropItemType { file, string }

/// Platform-neutral metadata or payload for one dropped item.
class PlatformDropItem {
  const PlatformDropItem({
    required this.type,
    this.handle,
    this.name,
    this.mimeType,
    this.size,
    this.lastModifiedMilliseconds,
    this.path,
    this.value,
    this.accessDenied = false,
    this.isDirectory = false,
  });

  final PlatformDropItemType type;
  final String? handle;
  final String? name;
  final String? mimeType;
  final int? size;
  final int? lastModifiedMilliseconds;
  final String? path;
  final String? value;
  final bool accessDenied;
  final bool isDirectory;

  /// Creates an item from the event channel's map representation.
  factory PlatformDropItem.fromMap(Map<Object?, Object?> map) {
    final type = map['type'];
    if (type != 'file' && type != 'string') {
      throw FormatException('Unknown dropped item type: $type');
    }
    return PlatformDropItem(
      type: type == 'file'
          ? PlatformDropItemType.file
          : PlatformDropItemType.string,
      handle: map['handle'] as String?,
      name: map['name'] as String?,
      mimeType: map['mimeType'] as String?,
      size: map['size'] as int?,
      lastModifiedMilliseconds: map['lastModifiedMilliseconds'] as int?,
      path: map['path'] as String?,
      value: map['value'] as String?,
      accessDenied: map['accessDenied'] == true,
      isDirectory: map['isDirectory'] == true,
    );
  }
}

/// One platform drop lifecycle event in source order.
class PlatformDropEvent {
  const PlatformDropEvent({
    required this.sessionId,
    required this.type,
    required this.globalPositionX,
    required this.globalPositionY,
    this.items = const <PlatformDropItem>[],
  });

  final String sessionId;
  final PlatformDropEventType type;
  final double globalPositionX;
  final double globalPositionY;
  final List<PlatformDropItem> items;

  /// Creates an event from the event channel's map representation.
  factory PlatformDropEvent.fromMap(Map<Object?, Object?> map) {
    final type = switch (map['type']) {
      'enter' => PlatformDropEventType.enter,
      'move' => PlatformDropEventType.move,
      'leave' => PlatformDropEventType.leave,
      'drop' => PlatformDropEventType.drop,
      final value => throw FormatException('Unknown drop event type: $value'),
    };
    final rawItems = map['items'];
    return PlatformDropEvent(
      sessionId: map['sessionId'] as String? ?? '',
      type: type,
      globalPositionX: (map['globalX'] as num?)?.toDouble() ?? 0,
      globalPositionY: (map['globalY'] as num?)?.toDouble() ?? 0,
      items: rawItems is List<Object?>
          ? rawItems
                .map(
                  (item) => PlatformDropItem.fromMap(
                    Map<Object?, Object?>.from(item! as Map),
                  ),
                )
                .toList(growable: false)
          : const <PlatformDropItem>[],
    );
  }
}

/// Contract implemented by each platform-specific plugin package.
abstract class FlutterFileDropPlatform extends PlatformInterface {
  FlutterFileDropPlatform() : super(token: _token);

  static final Object _token = Object();
  static FlutterFileDropPlatform _instance =
      MethodChannelFlutterFileDropPlatform();

  static FlutterFileDropPlatform get instance => _instance;

  static set instance(FlutterFileDropPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Events from the native drag-and-drop API.
  Stream<PlatformDropEvent> get events;

  /// Reads at most [maxBytes] from [offset] in a session-scoped file handle.
  Future<Uint8List?> readFileChunk(
    String sessionId,
    String handle,
    String readId,
    int offset,
    int maxBytes,
  );

  /// Closes a reader opened by [readFileChunk].
  Future<void> releaseFileReadStream(
    String sessionId,
    String handle,
    String readId,
  );

  /// Releases all temporary resources associated with [sessionId].
  Future<void> releaseSession(String sessionId);
}

class MethodChannelFlutterFileDropPlatform extends FlutterFileDropPlatform {
  MethodChannelFlutterFileDropPlatform({
    this.eventChannel = const EventChannel('flutter_file_drop/events'),
    DropFileHostApi? hostApi,
  }) : _hostApi = hostApi ?? DropFileHostApi();

  final EventChannel eventChannel;
  final DropFileHostApi _hostApi;
  late final Stream<PlatformDropEvent> _events = eventChannel
      .receiveBroadcastStream()
      .map(
        (event) =>
            PlatformDropEvent.fromMap(Map<Object?, Object?>.from(event as Map)),
      );

  @override
  Stream<PlatformDropEvent> get events => _events;

  @override
  Future<Uint8List?> readFileChunk(
    String sessionId,
    String handle,
    String readId,
    int offset,
    int maxBytes,
  ) => _hostApi.readFileChunk(sessionId, handle, readId, offset, maxBytes);

  @override
  Future<void> releaseFileReadStream(
    String sessionId,
    String handle,
    String readId,
  ) => _hostApi.releaseFileReadStream(sessionId, handle, readId);

  @override
  Future<void> releaseSession(String sessionId) =>
      _hostApi.releaseSession(sessionId);
}
