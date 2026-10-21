import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'flutter_file_drop_platform_interface',
    kotlinOut:
        '../flutter_file_drop_android/android/src/main/kotlin/dev/flutterfiledrop/flutter_file_drop_android/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.flutterfiledrop.flutter_file_drop_android',
    ),
    swiftOut: <String>[
      '../flutter_file_drop_darwin/ios/Classes/Messages.g.swift',
      '../flutter_file_drop_darwin/ios/flutter_file_drop_darwin/Sources/flutter_file_drop_darwin/Messages.g.swift',
      '../flutter_file_drop_darwin/macos/flutter_file_drop_darwin/Sources/flutter_file_drop_darwin/Messages.g.swift',
    ],
    cppHeaderOut:
        '../flutter_file_drop_windows/windows/include/flutter_file_drop_windows/flutter_file_drop_windows_messages_g.h',
    cppSourceOut: '../flutter_file_drop_windows/windows/messages.g.cpp',
    cppOptions: CppOptions(
      namespace: 'flutter_file_drop_windows',
      headerIncludePath: 'flutter_file_drop_windows_messages_g.h',
    ),
    gobjectHeaderOut:
        '../flutter_file_drop_linux/linux/include/flutter_file_drop_linux/messages.g.h',
    gobjectSourceOut: '../flutter_file_drop_linux/linux/messages.g.cc',
    gobjectOptions: GObjectOptions(
      headerIncludePath: 'include/flutter_file_drop_linux/messages.g.h',
      module: 'FlutterFileDropLinux',
    ),
  ),
)
@HostApi()
abstract class DropFileHostApi {
  @async
  Uint8List? readFileChunk(
    String sessionId,
    String fileHandle,
    int offset,
    int maxBytes,
  );

  @async
  void releaseSession(String sessionId);
}
