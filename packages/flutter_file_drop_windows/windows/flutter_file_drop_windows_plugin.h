#ifndef FLUTTER_PLUGIN_FLUTTER_FILE_DROP_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_FILE_DROP_WINDOWS_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "include/flutter_file_drop_windows/flutter_file_drop_windows_messages_g.h"

namespace flutter_file_drop_windows {

class NativeDropTarget;
class EventStreamHandler;

class FlutterFileDropWindowsPlugin : public flutter::Plugin,
                                     public DropFileHostApi {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);
  FlutterFileDropWindowsPlugin();
  ~FlutterFileDropWindowsPlugin() override;

  FlutterFileDropWindowsPlugin(const FlutterFileDropWindowsPlugin&) = delete;
  FlutterFileDropWindowsPlugin& operator=(const FlutterFileDropWindowsPlugin&) = delete;

  void ReadFileChunk(
      const std::string& session_id,
      const std::string& handle,
      int64_t offset,
      int64_t max_bytes,
      std::function<void(ErrorOr<std::optional<std::vector<uint8_t>>>)> result) override;
  void ReleaseSession(
      const std::string& session_id,
      std::function<void(std::optional<FlutterError>)> result) override;

 private:
  friend class NativeDropTarget;
  friend class EventStreamHandler;

  bool IsListening() const;
  std::string EnsureSession();
  void Emit(const std::string& type, IDataObject* data_object,
            POINTL screen_point, bool dropped);
  void EmitLeave();
  flutter::EncodableList GetItems(IDataObject* data_object,
                                  const std::string& session_id,
                                  bool dropped);
  void RegisterNativeDropTarget(HWND window);

  flutter::BinaryMessenger* messenger_ = nullptr;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::string session_id_;
  HWND window_ = nullptr;
  NativeDropTarget* native_drop_target_ = nullptr;
  bool ole_initialized_ = false;
  std::map<std::string, std::map<std::string, std::wstring>> files_;
};

}  // namespace flutter_file_drop_windows

#endif  // FLUTTER_PLUGIN_FLUTTER_FILE_DROP_WINDOWS_PLUGIN_H_
