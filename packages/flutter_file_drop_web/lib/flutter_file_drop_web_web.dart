import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_file_drop_platform_interface/flutter_file_drop_platform_interface.dart';
import 'package:web/web.dart' as web;

class FlutterFileDropWebPlugin {
  static void registerWith(Registrar registrar) {
    FlutterFileDropPlatform.instance = _WebDropPlatform();
  }
}

class _WebDropPlatform extends FlutterFileDropPlatform {
  final StreamController<PlatformDropEvent> _controller =
      StreamController<PlatformDropEvent>.broadcast();
  final Map<String, web.File> _files = <String, web.File>{};
  final Map<String, Set<String>> _sessionHandles = <String, Set<String>>{};
  int _nextSession = 0;
  String? _sessionId;
  bool _listening = false;

  late final web.EventListener _dragEnter = ((web.Event event) {
    _begin(event as web.DragEvent);
  }).toJS;
  late final web.EventListener _dragOver = ((web.Event event) {
    _move(event as web.DragEvent);
  }).toJS;
  late final web.EventListener _dragLeave = ((web.Event event) {
    _leave(event as web.DragEvent);
  }).toJS;
  late final web.EventListener _drop = ((web.Event event) {
    _dropFiles(event as web.DragEvent);
  }).toJS;

  _WebDropPlatform() {
    _controller
      ..onListen = _startListening
      ..onCancel = _stopListening;
  }

  @override
  Stream<PlatformDropEvent> get events => _controller.stream;

  void _startListening() {
    if (_listening) return;
    _listening = true;
    web.window
      ..addEventListener('dragenter', _dragEnter)
      ..addEventListener('dragover', _dragOver)
      ..addEventListener('dragleave', _dragLeave)
      ..addEventListener('drop', _drop);
  }

  void _stopListening() {
    if (!_listening) return;
    _listening = false;
    web.window
      ..removeEventListener('dragenter', _dragEnter)
      ..removeEventListener('dragover', _dragOver)
      ..removeEventListener('dragleave', _dragLeave)
      ..removeEventListener('drop', _drop);
    _sessionId = null;
  }

  void _begin(web.DragEvent event) {
    final transfer = event.dataTransfer;
    if (transfer == null || _sessionId != null) return;
    _sessionId = 'web-${++_nextSession}';
    _emit(PlatformDropEventType.enter, event, transfer, includeValues: false);
  }

  void _move(web.DragEvent event) {
    final transfer = event.dataTransfer;
    if (transfer == null) return;
    _sessionId ??= 'web-${++_nextSession}';
    event.preventDefault();
    _emit(PlatformDropEventType.move, event, transfer, includeValues: false);
  }

  void _leave(web.DragEvent event) {
    final transfer = event.dataTransfer;
    if (transfer == null || event.relatedTarget != null) return;
    final sessionId = _sessionId;
    if (sessionId == null) return;
    _controller.add(
      PlatformDropEvent(
        sessionId: sessionId,
        type: PlatformDropEventType.leave,
        globalPositionX: event.clientX.toDouble(),
        globalPositionY: event.clientY.toDouble(),
      ),
    );
    _sessionId = null;
  }

  void _dropFiles(web.DragEvent event) {
    final transfer = event.dataTransfer;
    if (transfer == null) return;
    event.preventDefault();
    final sessionId = _sessionId ?? 'web-${++_nextSession}';
    _emit(
      PlatformDropEventType.drop,
      event,
      transfer,
      sessionId: sessionId,
      includeValues: true,
    );
    _sessionId = null;
  }

  void _emit(
    PlatformDropEventType type,
    web.DragEvent event,
    web.DataTransfer transfer, {
    String? sessionId,
    required bool includeValues,
  }) {
    final currentSession = sessionId ?? _sessionId!;
    final items = <PlatformDropItem>[];
    for (var index = 0; index < transfer.items.length; index++) {
      final item = transfer.items[index];
      if (item.kind == 'file') {
        final file = item.getAsFile();
        final isDirectory = item.webkitGetAsEntry()?.isDirectory ?? false;
        String? handle;
        if (file != null && includeValues) {
          handle = '$currentSession:$index';
          _files[handle] = file;
          _sessionHandles
              .putIfAbsent(currentSession, () => <String>{})
              .add(handle);
        }
        items.add(
          PlatformDropItem(
            type: PlatformDropItemType.file,
            handle: handle,
            name: file?.name,
            mimeType: file == null || file.type.isEmpty ? null : file.type,
            size: file?.size,
            lastModifiedMilliseconds: file?.lastModified,
            accessDenied: includeValues && file == null && !isDirectory,
            isDirectory: isDirectory,
          ),
        );
      } else {
        final mimeType = item.type.toLowerCase();
        if (!_supportedStringType(mimeType)) continue;
        items.add(
          PlatformDropItem(
            type: PlatformDropItemType.string,
            mimeType: mimeType,
            value: includeValues ? transfer.getData(item.type) : null,
          ),
        );
      }
    }
    _controller.add(
      PlatformDropEvent(
        sessionId: currentSession,
        type: type,
        globalPositionX: event.clientX.toDouble(),
        globalPositionY: event.clientY.toDouble(),
        items: items,
      ),
    );
  }

  bool _supportedStringType(String type) =>
      type == 'text/plain' || type == 'text/html' || type == 'text/uri-list';

  @override
  Future<Uint8List?> readFileChunk(
    String sessionId,
    String handle,
    String readId,
    int offset,
    int maxBytes,
  ) async {
    if (offset < 0 || maxBytes <= 0 || maxBytes > 64 * 1024) return null;
    final file = _files[handle];
    if (file == null || !_sessionHandles.containsKey(sessionId)) return null;
    final buffer =
        (await file.slice(offset, offset + maxBytes).arrayBuffer().toDart)
            .toDart;
    return Uint8List.view(buffer);
  }

  @override
  Future<void> releaseFileReadStream(
    String sessionId,
    String handle,
    String readId,
  ) async {}

  @override
  Future<void> releaseSession(String sessionId) async {
    for (final handle
        in _sessionHandles.remove(sessionId) ?? const <String>{}) {
      _files.remove(handle);
    }
  }
}
