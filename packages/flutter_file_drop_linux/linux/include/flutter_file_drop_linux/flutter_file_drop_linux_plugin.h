#ifndef FLUTTER_PLUGIN_FLUTTER_FILE_DROP_LINUX_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_FILE_DROP_LINUX_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

G_DECLARE_FINAL_TYPE(FlutterFileDropLinuxPlugin, flutter_file_drop_linux_plugin,
                     FLUTTER_FILE_DROP, LINUX_PLUGIN, GObject)

FLUTTER_PLUGIN_EXPORT GType flutter_file_drop_linux_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void flutter_file_drop_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_FLUTTER_FILE_DROP_LINUX_PLUGIN_H_
