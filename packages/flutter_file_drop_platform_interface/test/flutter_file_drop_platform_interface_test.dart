import 'package:flutter_file_drop_platform_interface/flutter_file_drop_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses ordered file and string items from an event map', () {
    final event = PlatformDropEvent.fromMap(<Object?, Object?>{
      'sessionId': 'session-1',
      'type': 'drop',
      'globalX': 12,
      'globalY': 24.5,
      'items': <Object?>[
        <Object?, Object?>{
          'type': 'file',
          'handle': 'file-1',
          'name': 'photo.png',
          'mimeType': 'image/png',
          'size': 42,
        },
        <Object?, Object?>{
          'type': 'string',
          'mimeType': 'text/plain',
          'value': 'hello',
        },
      ],
    });

    expect(event.sessionId, 'session-1');
    expect(event.type, PlatformDropEventType.drop);
    expect(event.globalPositionX, 12);
    expect(event.globalPositionY, 24.5);
    expect(event.items.map((item) => item.type), <PlatformDropItemType>[
      PlatformDropItemType.file,
      PlatformDropItemType.string,
    ]);
    expect(event.items.first.name, 'photo.png');
    expect(event.items.last.value, 'hello');
  });

  test('rejects unknown event and item types', () {
    expect(
      () => PlatformDropEvent.fromMap(<Object?, Object?>{'type': 'unknown'}),
      throwsFormatException,
    );
    expect(
      () => PlatformDropItem.fromMap(<Object?, Object?>{'type': 'unknown'}),
      throwsFormatException,
    );
  });
}
