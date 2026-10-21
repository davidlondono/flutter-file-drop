import 'dart:async';
import 'dart:typed_data';

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_drop_platform_interface/flutter_file_drop_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  late _FakeDropPlatform platform;

  setUp(() {
    platform = _FakeDropPlatform();
    FlutterFileDropPlatform.instance = platform;
  });

  tearDown(() {
    FlutterFileDropPlatform.instance = MethodChannelFlutterFileDropPlatform();
  });

  testWidgets('shows app-owned drop surface', (tester) async {
    await tester.pumpWidget(const DropExampleApp());

    expect(find.text('Drop target'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('drop-surface')), findsOneWidget);
  });
}

class _FakeDropPlatform extends FlutterFileDropPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<PlatformDropEvent> _events =
      StreamController<PlatformDropEvent>.broadcast();

  @override
  Stream<PlatformDropEvent> get events => _events.stream;

  @override
  Future<Uint8List?> readFileChunk(
    String sessionId,
    String handle,
    String readId,
    int offset,
    int maxBytes,
  ) async => null;

  @override
  Future<void> releaseFileReadStream(
    String sessionId,
    String handle,
    String readId,
  ) async {}

  @override
  Future<void> releaseSession(String sessionId) async {}
}
