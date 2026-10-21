import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_file_drop/flutter_file_drop.dart';
import 'package:flutter_file_drop_platform_interface/flutter_file_drop_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  late _FakeDropPlatform platform;

  setUp(() {
    platform = _FakeDropPlatform();
    FlutterFileDropPlatform.instance = platform;
  });

  tearDown(() async {
    await platform.controller.close();
    FlutterFileDropPlatform.instance = MethodChannelFlutterFileDropPlatform();
  });

  testWidgets('routes whole batch to deepest target accepting an item', (
    tester,
  ) async {
    DropResult? innerResult;
    var outerCalls = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          constraints: DropConstraints(
            allowedKinds: const <DropItemKind>{DropItemKind.file},
          ),
          onDrop: (result) async {
            outerCalls++;
          },
          child: SizedBox(
            width: 200,
            height: 200,
            child: DropTarget(
              constraints: DropConstraints(
                allowedMimeTypes: const <String>{'image/*'},
              ),
              onDrop: (result) async {
                innerResult = result;
              },
              child: const SizedBox.expand(key: ValueKey<String>('inner')),
            ),
          ),
        ),
      ),
    );

    final position = tester.getCenter(
      find.byKey(const ValueKey<String>('inner')),
    );
    platform.emit(
      _dropEvent(position, <PlatformDropItem>[
        const PlatformDropItem(
          type: PlatformDropItemType.file,
          handle: 'image',
          name: 'photo.png',
          mimeType: 'image/png',
          size: 4,
        ),
        const PlatformDropItem(
          type: PlatformDropItemType.string,
          value: 'hello',
          mimeType: 'text/plain',
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(innerResult, isNotNull);
    expect(innerResult!.items, hasLength(2));
    expect(innerResult!.accepted, hasLength(1));
    expect(
      innerResult!.rejected.single.reasons,
      contains(DropRejectionReason.mimeTypeNotAllowed),
    );
    expect(outerCalls, 0);
    expect(platform.releasedSessions, <String>['session-1']);
  });

  testWidgets('fires enter once when platform repeats enter events', (
    tester,
  ) async {
    var enterCalls = 0;
    var moveCalls = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          onEnter: (_) => enterCalls++,
          onMove: (_) => moveCalls++,
          child: const SizedBox(
            width: 100,
            height: 100,
            key: ValueKey('target'),
          ),
        ),
      ),
    );
    final position = tester.getCenter(find.byKey(const ValueKey('target')));
    final event = PlatformDropEvent(
      sessionId: 'session-1',
      type: PlatformDropEventType.enter,
      globalPositionX: position.dx,
      globalPositionY: position.dy,
    );
    platform.emit(event);
    platform.emit(event);
    await tester.pump();

    expect(enterCalls, 1);
    expect(moveCalls, 1);
  });

  testWidgets('maxFiles counts only eligible files in source order', (
    tester,
  ) async {
    DropResult? result;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          constraints: DropConstraints(
            allowedExtensions: const <String>{'.pdf'},
            maxFiles: 1,
          ),
          onDrop: (value) async {
            result = value;
          },
          child: const SizedBox(
            width: 100,
            height: 100,
            key: ValueKey('target'),
          ),
        ),
      ),
    );

    final position = tester.getCenter(
      find.byKey(const ValueKey<String>('target')),
    );
    platform.emit(
      _dropEvent(position, <PlatformDropItem>[
        const PlatformDropItem(
          type: PlatformDropItemType.file,
          handle: 'one',
          name: 'one.pdf',
          size: 1,
        ),
        const PlatformDropItem(
          type: PlatformDropItemType.string,
          value: 'text',
          mimeType: 'text/plain',
        ),
        const PlatformDropItem(
          type: PlatformDropItemType.file,
          handle: 'two',
          name: 'two.txt',
          size: 1,
        ),
        const PlatformDropItem(
          type: PlatformDropItemType.file,
          handle: 'three',
          name: 'three.pdf',
          size: 1,
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.items.map((item) => item.accepted), <bool>[
      true,
      true,
      false,
      false,
    ]);
    expect(
      result!.items[2].reasons,
      contains(DropRejectionReason.extensionNotAllowed),
    );
    expect(
      result!.items[3].reasons,
      contains(DropRejectionReason.maxFilesExceeded),
    );
  });

  testWidgets('reports missing metadata once and rejects directories safely', (
    tester,
  ) async {
    DropResult? result;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          constraints: DropConstraints(
            allowedMimeTypes: const <String>{'image/*'},
            allowedExtensions: const <String>{'.png'},
          ),
          onDrop: (value) async {
            result = value;
          },
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    final position = tester.getCenter(find.byType(DropTarget));
    platform.emit(
      _dropEvent(position, const <PlatformDropItem>[
        PlatformDropItem(type: PlatformDropItemType.file, isDirectory: true),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.items.single.reasons, <DropRejectionReason>[
      DropRejectionReason.unsupportedKind,
      DropRejectionReason.metadataUnavailable,
      DropRejectionReason.mimeTypeNotAllowed,
      DropRejectionReason.extensionNotAllowed,
    ]);
  });

  testWidgets('size constraints screen reported size and reject unknown size', (
    tester,
  ) async {
    DropResult? result;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          constraints: DropConstraints(maxFileSizeBytes: 2),
          onDrop: (value) async => result = value,
          child: const SizedBox(
            width: 100,
            height: 100,
            key: ValueKey('target'),
          ),
        ),
      ),
    );
    final position = tester.getCenter(find.byKey(const ValueKey('target')));
    platform.emit(
      _dropEvent(position, const <PlatformDropItem>[
        PlatformDropItem(
          type: PlatformDropItemType.file,
          handle: 'large',
          size: 3,
        ),
        PlatformDropItem(type: PlatformDropItemType.file, handle: 'unknown'),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(
      result!.items.map((item) => item.reasons.single),
      <DropRejectionReason>[
        DropRejectionReason.fileTooLarge,
        DropRejectionReason.fileSizeUnknown,
      ],
    );
  });

  testWidgets('streams bytes during callback and expires file after callback', (
    tester,
  ) async {
    DropFile? file;
    Uint8List? bytes;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          onDrop: (result) async {
            file = result.accepted.single.item as DropFile;
            bytes = await file!.readAsBytes(maxBytes: 3);
          },
          child: const SizedBox(
            width: 100,
            height: 100,
            key: ValueKey('target'),
          ),
        ),
      ),
    );

    final position = tester.getCenter(
      find.byKey(const ValueKey<String>('target')),
    );
    platform.emit(
      _dropEvent(position, const <PlatformDropItem>[
        PlatformDropItem(
          type: PlatformDropItemType.file,
          handle: 'file',
          name: 'data.bin',
          size: 3,
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(bytes, <int>[1, 2, 3]);
    expect(platform.releasedReads, hasLength(1));
    await expectLater(
      file!.readAsBytes(),
      throwsA(
        isA<DropFileReadException>().having(
          (error) => error.reason,
          'reason',
          DropFileReadFailure.callbackComplete,
        ),
      ),
    );
  });

  testWidgets('bounded reads reject bytes beyond the actual byte limit', (
    tester,
  ) async {
    DropFileReadException? failure;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          onDrop: (result) async {
            final file = result.accepted.single.item as DropFile;
            try {
              await file.readAsBytes(maxBytes: 2);
            } on DropFileReadException catch (error) {
              failure = error;
            }
          },
          child: const SizedBox(
            width: 100,
            height: 100,
            key: ValueKey('target'),
          ),
        ),
      ),
    );
    final position = tester.getCenter(find.byKey(const ValueKey('target')));
    platform.emit(
      _dropEvent(position, const <PlatformDropItem>[
        PlatformDropItem(type: PlatformDropItemType.file, handle: 'file'),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(failure?.reason, DropFileReadFailure.maxBytesExceeded);
    expect(platform.requestedByteCounts, <int>[3]);
    expect(platform.releasedReads, hasLength(1));
  });

  testWidgets('bounded reads catch a source that underreports its size', (
    tester,
  ) async {
    platform.fileBytes = Uint8List(64 * 1024 + 17);
    DropFileReadException? failure;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          onDrop: (result) async {
            final file = result.accepted.single.item as DropFile;
            try {
              await file.readAsBytes(maxBytes: 100);
            } on DropFileReadException catch (error) {
              failure = error;
            }
          },
          child: const SizedBox(
            width: 100,
            height: 100,
            key: ValueKey('target'),
          ),
        ),
      ),
    );
    final position = tester.getCenter(find.byKey(const ValueKey('target')));
    platform.emit(
      _dropEvent(position, const <PlatformDropItem>[
        PlatformDropItem(
          type: PlatformDropItemType.file,
          handle: 'file',
          size: 1,
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(failure?.reason, DropFileReadFailure.maxBytesExceeded);
    expect(platform.requestedByteCounts.first, 101);
    expect(platform.releasedReads, hasLength(1));
  });

  testWidgets('reads large files in ordered chunks no larger than 64 KiB', (
    tester,
  ) async {
    final expected = Uint8List.fromList(
      List<int>.generate(64 * 1024 + 17, (index) => index % 256),
    );
    platform.fileBytes = expected;
    final chunks = <Uint8List>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          onDrop: (result) async {
            await for (final chunk
                in (result.accepted.single.item as DropFile).openRead()) {
              chunks.add(chunk);
            }
          },
          child: const SizedBox(
            width: 100,
            height: 100,
            key: ValueKey('target'),
          ),
        ),
      ),
    );
    final position = tester.getCenter(find.byKey(const ValueKey('target')));
    platform.emit(
      _dropEvent(position, const <PlatformDropItem>[
        PlatformDropItem(type: PlatformDropItemType.file, handle: 'file'),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(chunks.map((chunk) => chunk.length), <int>[64 * 1024, 17]);
    expect(chunks.expand((chunk) => chunk), expected);
    expect(platform.releasedReads, hasLength(1));
  });

  testWidgets('cancelling a reader closes its platform stream', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropTarget(
          onDrop: (result) async {
            final file = result.accepted.single.item as DropFile;
            final iterator = StreamIterator<Uint8List>(file.openRead());
            expect(await iterator.moveNext(), isTrue);
            await iterator.cancel();
          },
          child: const SizedBox(
            width: 100,
            height: 100,
            key: ValueKey('target'),
          ),
        ),
      ),
    );
    final position = tester.getCenter(find.byKey(const ValueKey('target')));
    platform.emit(
      _dropEvent(position, const <PlatformDropItem>[
        PlatformDropItem(type: PlatformDropItemType.file, handle: 'file'),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(platform.releasedReads, hasLength(1));
    expect(platform.releasedSessions, <String>['session-1']);
  });
}

PlatformDropEvent _dropEvent(Offset position, List<PlatformDropItem> items) =>
    PlatformDropEvent(
      sessionId: 'session-1',
      type: PlatformDropEventType.drop,
      globalPositionX: position.dx,
      globalPositionY: position.dy,
      items: items,
    );

class _FakeDropPlatform extends FlutterFileDropPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<PlatformDropEvent> controller =
      StreamController<PlatformDropEvent>.broadcast(sync: true);
  final List<String> releasedSessions = <String>[];
  final List<String> releasedReads = <String>[];
  final List<int> requestedByteCounts = <int>[];
  Uint8List fileBytes = Uint8List.fromList(<int>[1, 2, 3]);

  void emit(PlatformDropEvent event) => controller.add(event);

  @override
  Stream<PlatformDropEvent> get events => controller.stream;

  @override
  Future<Uint8List?> readFileChunk(
    String sessionId,
    String handle,
    String readId,
    int offset,
    int maxBytes,
  ) async {
    requestedByteCounts.add(maxBytes);
    if (offset >= fileBytes.length) return null;
    final end = (offset + maxBytes).clamp(0, fileBytes.length);
    return Uint8List.sublistView(fileBytes, offset, end);
  }

  @override
  Future<void> releaseFileReadStream(
    String sessionId,
    String handle,
    String readId,
  ) async {
    releasedReads.add(readId);
  }

  @override
  Future<void> releaseSession(String sessionId) async {
    releasedSessions.add(sessionId);
  }
}
