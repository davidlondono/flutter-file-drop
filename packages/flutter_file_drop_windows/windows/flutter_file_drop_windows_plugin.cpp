#include "flutter_file_drop_windows_plugin.h"

#include <windows.h>
#include <ole2.h>
#include <shellapi.h>
#include <shlobj.h>

#include <atomic>
#include <algorithm>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <string>
#include <utility>

#include <flutter/standard_method_codec.h>

namespace flutter_file_drop_windows {
namespace {

std::string ToUtf8(const std::wstring& value) {
  if (value.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string result(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      result.data(), size, nullptr, nullptr);
  return result;
}

UINT WindowDpi(HWND window) {
  using GetDpiForWindowFunction = UINT(WINAPI*)(HWND);
  const HMODULE user32 = GetModuleHandleW(L"user32.dll");
  const auto get_dpi = reinterpret_cast<GetDpiForWindowFunction>(
      GetProcAddress(user32, "GetDpiForWindow"));
  return get_dpi == nullptr ? 96 : get_dpi(window);
}

void SetString(flutter::EncodableMap* map, const char* key,
               const std::string& value) {
  (*map)[flutter::EncodableValue(key)] = flutter::EncodableValue(value);
}

void SetInt(flutter::EncodableMap* map, const char* key, int64_t value) {
  (*map)[flutter::EncodableValue(key)] = flutter::EncodableValue(value);
}

void SetBool(flutter::EncodableMap* map, const char* key, bool value) {
  (*map)[flutter::EncodableValue(key)] = flutter::EncodableValue(value);
}

bool ReadClipboardData(IDataObject* data_object, CLIPFORMAT clipboard_format,
                       std::vector<uint8_t>* bytes) {
  FORMATETC format = {clipboard_format, nullptr, DVASPECT_CONTENT, -1,
                      TYMED_HGLOBAL};
  STGMEDIUM medium = {};
  if (FAILED(data_object->GetData(&format, &medium))) return false;
  const SIZE_T size = GlobalSize(medium.hGlobal);
  const auto* source = static_cast<const uint8_t*>(GlobalLock(medium.hGlobal));
  if (source != nullptr && size > 0) bytes->assign(source, source + size);
  if (source != nullptr) GlobalUnlock(medium.hGlobal);
  ReleaseStgMedium(&medium);
  return source != nullptr && size > 0;
}

std::wstring ReadUnicodeText(IDataObject* data_object,
                             CLIPFORMAT clipboard_format) {
  std::vector<uint8_t> bytes;
  if (!ReadClipboardData(data_object, clipboard_format, &bytes)) return {};
  const auto* text = reinterpret_cast<const wchar_t*>(bytes.data());
  const size_t length = wcsnlen_s(text, bytes.size() / sizeof(wchar_t));
  return std::wstring(text, length);
}

std::string ReadRawText(IDataObject* data_object,
                        CLIPFORMAT clipboard_format) {
  std::vector<uint8_t> bytes;
  if (!ReadClipboardData(data_object, clipboard_format, &bytes)) return {};
  while (!bytes.empty() && bytes.back() == 0) bytes.pop_back();
  return std::string(bytes.begin(), bytes.end());
}

std::vector<CLIPFORMAT> AvailableFormats(IDataObject* data_object) {
  std::vector<CLIPFORMAT> formats;
  IEnumFORMATETC* enumerator = nullptr;
  if (FAILED(data_object->EnumFormatEtc(DATADIR_GET, &enumerator)) ||
      enumerator == nullptr) {
    return formats;
  }
  FORMATETC format = {};
  ULONG fetched = 0;
  while (enumerator->Next(1, &format, &fetched) == S_OK && fetched == 1) {
    formats.push_back(format.cfFormat);
    if (format.ptd != nullptr) CoTaskMemFree(format.ptd);
    format = {};
  }
  enumerator->Release();
  return formats;
}

flutter::EncodableMap MakeFileItem(
    const std::wstring& path,
    const std::string& session_id,
    const std::string& handle,
    bool dropped,
    std::map<std::string, std::map<std::string, std::wstring>>* files) {
  flutter::EncodableMap item;
  SetString(&item, "type", "file");
  SetString(&item, "path", ToUtf8(path));
  const size_t separator = path.find_last_of(L"\\/");
  SetString(&item, "name", ToUtf8(path.substr(separator == std::wstring::npos ? 0 : separator + 1)));

  WIN32_FILE_ATTRIBUTE_DATA attributes = {};
  bool is_directory = false;
  if (GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &attributes)) {
    const uint64_t size = (static_cast<uint64_t>(attributes.nFileSizeHigh) << 32) |
                          attributes.nFileSizeLow;
    if ((attributes.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
      SetInt(&item, "size", static_cast<int64_t>(size));
    } else {
      is_directory = true;
      SetBool(&item, "isDirectory", true);
    }
    ULARGE_INTEGER file_time;
    file_time.LowPart = attributes.ftLastWriteTime.dwLowDateTime;
    file_time.HighPart = attributes.ftLastWriteTime.dwHighDateTime;
    const int64_t milliseconds = static_cast<int64_t>(file_time.QuadPart / 10000) - 11644473600000LL;
    SetInt(&item, "lastModifiedMilliseconds", milliseconds);
  }

  if (dropped && !is_directory) {
    HANDLE file = CreateFileW(path.c_str(), GENERIC_READ,
                              FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                              nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file != INVALID_HANDLE_VALUE) {
      CloseHandle(file);
      SetString(&item, "handle", handle);
      (*files)[session_id][handle] = path;
    } else {
      SetBool(&item, "accessDenied", true);
    }
  }
  return item;
}

flutter::EncodableMap MakeStringItem(const std::string& mime_type,
                                     const std::string& value,
                                     bool include_value) {
  flutter::EncodableMap item;
  SetString(&item, "type", "string");
  SetString(&item, "mimeType", mime_type);
  if (include_value) SetString(&item, "value", value);
  return item;
}

}  // namespace

class EventStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  explicit EventStreamHandler(FlutterFileDropWindowsPlugin* plugin)
      : plugin_(plugin) {}

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
  OnListenInternal(const flutter::EncodableValue*,
                  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
    plugin_->event_sink_ = std::move(events);
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
  OnCancelInternal(const flutter::EncodableValue*) override {
    plugin_->event_sink_.reset();
    return nullptr;
  }

 private:
  FlutterFileDropWindowsPlugin* plugin_;
};

class NativeDropTarget : public IDropTarget {
 public:
  explicit NativeDropTarget(FlutterFileDropWindowsPlugin* plugin)
      : plugin_(plugin) {}

  ~NativeDropTarget() {
    if (data_object_ != nullptr) data_object_->Release();
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** object) override {
    if (object == nullptr) return E_POINTER;
    if (iid == IID_IUnknown || iid == IID_IDropTarget) {
      *object = static_cast<IDropTarget*>(this);
      AddRef();
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }

  ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }

  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG count = --references_;
    if (count == 0) delete this;
    return count;
  }

  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* data_object, DWORD,
                                       POINTL point, DWORD* effect) override {
    if (!plugin_->IsListening()) {
      *effect = DROPEFFECT_NONE;
      return S_OK;
    }
    SetDataObject(data_object);
    *effect = DROPEFFECT_COPY;
    plugin_->Emit("enter", data_object, point, false);
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE DragOver(DWORD, POINTL point,
                                       DWORD* effect) override {
    if (!plugin_->IsListening()) {
      *effect = DROPEFFECT_NONE;
      return S_OK;
    }
    *effect = DROPEFFECT_COPY;
    plugin_->Emit("move", data_object_, point, false);
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE DragLeave() override {
    plugin_->EmitLeave();
    SetDataObject(nullptr);
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE Drop(IDataObject* data_object, DWORD,
                                   POINTL point, DWORD* effect) override {
    if (!plugin_->IsListening()) {
      *effect = DROPEFFECT_NONE;
      return S_OK;
    }
    *effect = DROPEFFECT_COPY;
    plugin_->Emit("drop", data_object, point, true);
    SetDataObject(nullptr);
    return S_OK;
  }

 private:
  void SetDataObject(IDataObject* data_object) {
    if (data_object == data_object_) return;
    if (data_object_ != nullptr) data_object_->Release();
    data_object_ = data_object;
    if (data_object_ != nullptr) data_object_->AddRef();
  }

  std::atomic<ULONG> references_{1};
  FlutterFileDropWindowsPlugin* plugin_;
  IDataObject* data_object_ = nullptr;
};

FlutterFileDropWindowsPlugin::FlutterFileDropWindowsPlugin() = default;

FlutterFileDropWindowsPlugin::~FlutterFileDropWindowsPlugin() {
  if (event_channel_) event_channel_->SetStreamHandler(nullptr);
  if (messenger_ != nullptr) DropFileHostApi::SetUp(messenger_, nullptr);
  if (window_ != nullptr) RevokeDragDrop(window_);
  if (native_drop_target_ != nullptr) native_drop_target_->Release();
  if (ole_initialized_) OleUninitialize();
}

void FlutterFileDropWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<FlutterFileDropWindowsPlugin>();
  plugin->messenger_ = registrar->messenger();
  plugin->event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "flutter_file_drop/events",
      &flutter::StandardMethodCodec::GetInstance());
  plugin->event_channel_->SetStreamHandler(std::make_unique<EventStreamHandler>(plugin.get()));
  DropFileHostApi::SetUp(registrar->messenger(), plugin.get());
  auto* view = registrar->GetView();
  plugin->RegisterNativeDropTarget(view == nullptr ? nullptr : view->GetNativeWindow());
  registrar->AddPlugin(std::move(plugin));
}

bool FlutterFileDropWindowsPlugin::IsListening() const {
  return event_sink_ != nullptr;
}

std::string FlutterFileDropWindowsPlugin::EnsureSession() {
  if (!session_id_.empty()) return session_id_;
  GUID id;
  CoCreateGuid(&id);
  wchar_t wide[40] = {};
  StringFromGUID2(id, wide, ARRAYSIZE(wide));
  session_id_ = "windows-" + ToUtf8(wide);
  return session_id_;
}

void FlutterFileDropWindowsPlugin::Emit(const std::string& type,
                                        IDataObject* data_object,
                                        POINTL screen_point,
                                        bool dropped) {
  if (!IsListening()) return;
  const std::string session_id = EnsureSession();
  POINT point = {screen_point.x, screen_point.y};
  ScreenToClient(window_, &point);
  const UINT dpi = WindowDpi(window_);
  const double scale = dpi == 0 ? 1.0 : static_cast<double>(dpi) / 96.0;
  flutter::EncodableMap event;
  SetString(&event, "sessionId", session_id);
  SetString(&event, "type", type);
  event[flutter::EncodableValue("globalX")] = flutter::EncodableValue(point.x / scale);
  event[flutter::EncodableValue("globalY")] = flutter::EncodableValue(point.y / scale);
  event[flutter::EncodableValue("items")] = flutter::EncodableValue(
      data_object == nullptr ? flutter::EncodableList{}
                             : GetItems(data_object, session_id, dropped));
  event_sink_->Success(flutter::EncodableValue(event));
  if (dropped) session_id_.clear();
}

void FlutterFileDropWindowsPlugin::EmitLeave() {
  if (!IsListening() || session_id_.empty()) return;
  flutter::EncodableMap event;
  SetString(&event, "sessionId", session_id_);
  SetString(&event, "type", "leave");
  event[flutter::EncodableValue("globalX")] = flutter::EncodableValue(0.0);
  event[flutter::EncodableValue("globalY")] = flutter::EncodableValue(0.0);
  event[flutter::EncodableValue("items")] = flutter::EncodableValue(flutter::EncodableList{});
  event_sink_->Success(flutter::EncodableValue(event));
  session_id_.clear();
}

flutter::EncodableList FlutterFileDropWindowsPlugin::GetItems(
    IDataObject* data_object, const std::string& session_id, bool dropped) {
  const CLIPFORMAT html_format =
      static_cast<CLIPFORMAT>(RegisterClipboardFormatW(L"HTML Format"));
  const CLIPFORMAT uri_format =
      static_cast<CLIPFORMAT>(RegisterClipboardFormatW(L"text/uri-list"));
  const std::vector<CLIPFORMAT> formats = AvailableFormats(data_object);
  const bool has_file_drop = std::find(formats.begin(), formats.end(), CF_HDROP) != formats.end();
  flutter::EncodableList items;
  for (const CLIPFORMAT format : formats) {
    if (format == CF_HDROP) {
      FORMATETC request = {format, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
      STGMEDIUM medium = {};
      if (FAILED(data_object->GetData(&request, &medium))) {
        flutter::EncodableMap rejected;
        SetString(&rejected, "type", "file");
        SetBool(&rejected, "accessDenied", true);
        items.emplace_back(std::move(rejected));
        continue;
      }
      HDROP drop = static_cast<HDROP>(medium.hGlobal);
      const UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
      for (UINT index = 0; index < count; ++index) {
        const UINT length = DragQueryFileW(drop, index, nullptr, 0);
        std::wstring path(length + 1, L'\0');
        DragQueryFileW(drop, index, path.data(), length + 1);
        path.resize(length);
        items.emplace_back(MakeFileItem(path, session_id, std::to_string(index), dropped, &files_));
      }
      ReleaseStgMedium(&medium);
      continue;
    }
    if (format == CF_UNICODETEXT) {
      const std::wstring value = ReadUnicodeText(data_object, format);
      if (!value.empty()) items.emplace_back(MakeStringItem("text/plain", ToUtf8(value), dropped));
      continue;
    }
    if (format == html_format) {
      const std::string value = ReadRawText(data_object, format);
      if (!value.empty()) items.emplace_back(MakeStringItem("text/html", value, dropped));
      continue;
    }
    if (format == uri_format && !has_file_drop) {
      const std::string value = ReadRawText(data_object, format);
      if (!value.empty()) items.emplace_back(MakeStringItem("text/uri-list", value, dropped));
    }
  }
  return items;
}

void FlutterFileDropWindowsPlugin::RegisterNativeDropTarget(HWND window) {
  const HRESULT ole_result = OleInitialize(nullptr);
  ole_initialized_ = SUCCEEDED(ole_result);
  if (!ole_initialized_ || window == nullptr) return;
  window_ = window;
  native_drop_target_ = new NativeDropTarget(this);
  const HRESULT result = RegisterDragDrop(window_, native_drop_target_);
  if (FAILED(result)) {
    native_drop_target_->Release();
    native_drop_target_ = nullptr;
    window_ = nullptr;
  }
}

void FlutterFileDropWindowsPlugin::ReadFileChunk(
    const std::string& session_id, const std::string& file_handle,
    const std::string& read_id, int64_t offset,
    int64_t max_bytes,
    std::function<void(ErrorOr<std::optional<std::vector<uint8_t>>>)> result) {
  (void)read_id;
  const auto session = files_.find(session_id);
  if (offset < 0 || max_bytes <= 0 || max_bytes > 64 * 1024 || session == files_.end()) {
    result(std::optional<std::vector<uint8_t>>{});
    return;
  }
  const auto file = session->second.find(file_handle);
  if (file == session->second.end()) {
    result(std::optional<std::vector<uint8_t>>{});
    return;
  }
  std::ifstream stream(file->second, std::ios::binary);
  if (!stream) {
    result(FlutterError("read-failed", "Could not open dropped file."));
    return;
  }
  stream.seekg(offset, std::ios::beg);
  std::vector<uint8_t> bytes(static_cast<size_t>(max_bytes));
  stream.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
  bytes.resize(static_cast<size_t>(stream.gcount()));
  if (bytes.empty()) {
    result(std::optional<std::vector<uint8_t>>{});
    return;
  }
  result(std::optional<std::vector<uint8_t>>(std::move(bytes)));
}

void FlutterFileDropWindowsPlugin::ReleaseFileReadStream(
    const std::string& session_id, const std::string& handle,
    const std::string& read_id,
    std::function<void(std::optional<FlutterError>)> result) {
  (void)session_id;
  (void)handle;
  (void)read_id;
  result(std::optional<FlutterError>{});
}

void FlutterFileDropWindowsPlugin::ReleaseSession(
    const std::string& session_id,
    std::function<void(std::optional<FlutterError>)> result) {
  files_.erase(session_id);
  result(std::optional<FlutterError>{});
}

}  // namespace flutter_file_drop_windows
