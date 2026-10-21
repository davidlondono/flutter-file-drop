#include "include/flutter_file_drop_windows/flutter_file_drop_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_file_drop_windows_plugin.h"

void FlutterFileDropWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_file_drop_windows::FlutterFileDropWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
