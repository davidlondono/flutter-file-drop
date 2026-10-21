#include "include/flutter_file_drop_linux/flutter_file_drop_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstring>
#include <string>

#include "include/flutter_file_drop_linux/messages.g.h"

struct _FlutterFileDropLinuxPlugin {
  GObject parent_instance;
  FlView* view;
  FlBinaryMessenger* messenger;
  FlEventChannel* event_channel;
  gboolean listening;
  gchar* session_id;
  guint next_session;
  gint drop_x;
  gint drop_y;
  GHashTable* files;
};

G_DEFINE_TYPE(FlutterFileDropLinuxPlugin, flutter_file_drop_linux_plugin, g_object_get_type())

static gboolean drag_motion_cb(GtkWidget* widget, GdkDragContext* context,
                               gint x, gint y, guint time, gpointer user_data);
static void drag_leave_cb(GtkWidget* widget, GdkDragContext* context,
                          guint time, gpointer user_data);
static gboolean drag_drop_cb(GtkWidget* widget, GdkDragContext* context,
                             gint x, gint y, guint time, gpointer user_data);
static void drag_data_received_cb(GtkWidget* widget, GdkDragContext* context,
                                 gint x, gint y, GtkSelectionData* selection_data,
                                 guint info, guint time, gpointer user_data);

static void map_set_string(FlValue* map, const gchar* key, const gchar* value) {
  if (value != nullptr) fl_value_set_string_take(map, key, fl_value_new_string(value));
}

static void map_set_int(FlValue* map, const gchar* key, gint64 value) {
  fl_value_set_string_take(map, key, fl_value_new_int(value));
}

static gchar* make_session_id(FlutterFileDropLinuxPlugin* self) {
  return g_strdup_printf("linux-%u", ++self->next_session);
}

static FlValue* file_item(FlutterFileDropLinuxPlugin* self, const gchar* uri,
                          guint index, gboolean dropped) {
  g_autoptr(GFile) file = g_file_new_for_uri(uri);
  g_autofree gchar* path = g_file_get_path(file);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GFileInfo) info = g_file_query_info(
      file,
      "standard::display-name,standard::content-type,standard::size,standard::type,time::modified,time::modified-usec",
      G_FILE_QUERY_INFO_NONE, nullptr, &error);
  const gboolean is_directory =
      info != nullptr && g_file_info_get_file_type(info) == G_FILE_TYPE_DIRECTORY;
  FlValue* item = fl_value_new_map();
  map_set_string(item, "type", "file");
  if (info != nullptr) {
    map_set_string(item, "name", g_file_info_get_display_name(info));
    if (g_file_info_has_attribute(info, G_FILE_ATTRIBUTE_STANDARD_SIZE) && !is_directory) {
      map_set_int(item, "size", g_file_info_get_size(info));
    }
    if (g_file_info_has_attribute(info, G_FILE_ATTRIBUTE_TIME_MODIFIED)) {
      map_set_int(item, "lastModifiedMilliseconds",
                  static_cast<gint64>(g_file_info_get_attribute_uint64(info, G_FILE_ATTRIBUTE_TIME_MODIFIED)) * 1000 +
                      g_file_info_get_attribute_uint32(info, G_FILE_ATTRIBUTE_TIME_MODIFIED_USEC) / 1000);
    }
    if (const gchar* content_type = g_file_info_get_content_type(info)) {
      g_autofree gchar* mime_type = g_content_type_get_mime_type(content_type);
      map_set_string(item, "mimeType", mime_type);
    }
    if (is_directory) {
      fl_value_set_string_take(item, "isDirectory", fl_value_new_bool(TRUE));
    }
  }
  map_set_string(item, "path", path);
  if (dropped && path != nullptr && !is_directory) {
    g_autofree gchar* handle = g_strdup_printf("%u", index);
    if (access(path, R_OK) == 0) {
      GHashTable* session_files = static_cast<GHashTable*>(g_hash_table_lookup(self->files, self->session_id));
      if (session_files == nullptr) {
        session_files = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
        g_hash_table_insert(self->files, g_strdup(self->session_id), session_files);
      }
      g_hash_table_insert(session_files, g_strdup(handle), g_strdup(path));
      map_set_string(item, "handle", handle);
    } else {
      fl_value_set_string_take(item, "accessDenied", fl_value_new_bool(TRUE));
    }
  } else if (dropped && !is_directory) {
    fl_value_set_string_take(item, "accessDenied", fl_value_new_bool(TRUE));
  }
  return item;
}

static FlValue* string_item(const gchar* mime_type, const gchar* value,
                            gboolean include_value) {
  FlValue* item = fl_value_new_map();
  map_set_string(item, "type", "string");
  map_set_string(item, "mimeType", mime_type);
  if (include_value && value != nullptr) map_set_string(item, "value", value);
  if (include_value && value == nullptr) {
    fl_value_set_string_take(item, "accessDenied", fl_value_new_bool(TRUE));
  }
  return item;
}

static FlValue* preview_items(GdkDragContext* context) {
  FlValue* items = fl_value_new_list();
  GList* targets = gdk_drag_context_list_targets(context);
  const gchar* preferred[] = {"text/uri-list", "text/html", "text/plain"};
  for (const gchar* name : preferred) {
    GdkAtom candidate = gdk_atom_intern_static_string(name);
    if (g_list_find(targets, candidate) == nullptr) continue;
    if (g_strcmp0(name, "text/uri-list") == 0) {
      FlValue* item = fl_value_new_map();
      map_set_string(item, "type", "file");
      fl_value_append_take(items, item);
    } else {
      fl_value_append_take(items, string_item(name, nullptr, FALSE));
    }
    break;
  }
  g_list_free(targets);
  return items;
}

static void send_event(FlutterFileDropLinuxPlugin* self, const gchar* type,
                       gint x, gint y, FlValue* items) {
  if (!self->listening || self->event_channel == nullptr || self->session_id == nullptr) return;
  g_autoptr(FlValue) event = fl_value_new_map();
  map_set_string(event, "sessionId", self->session_id);
  map_set_string(event, "type", type);
  fl_value_set_string_take(event, "globalX", fl_value_new_float(x));
  fl_value_set_string_take(event, "globalY", fl_value_new_float(y));
  fl_value_set_string_take(event, "items", items);
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(self->event_channel, event, nullptr, &error)) {
    g_warning("Could not send file drop event: %s", error->message);
  }
}

static FlMethodErrorResponse* stream_listen_cb(FlEventChannel* channel,
                                               FlValue* args,
                                               gpointer user_data) {
  (void)channel;
  (void)args;
  FlutterFileDropLinuxPlugin* self = FLUTTER_FILE_DROP_LINUX_PLUGIN(user_data);
  self->listening = TRUE;
  return nullptr;
}

static FlMethodErrorResponse* stream_cancel_cb(FlEventChannel* channel,
                                               FlValue* args,
                                               gpointer user_data) {
  (void)channel;
  (void)args;
  FlutterFileDropLinuxPlugin* self = FLUTTER_FILE_DROP_LINUX_PLUGIN(user_data);
  self->listening = FALSE;
  return nullptr;
}

static void read_file_chunk(const gchar* session_id, const gchar* file_handle,
                            int64_t offset, int64_t max_bytes,
                            FlutterFileDropLinuxDropFileHostApiResponseHandle* response,
                            gpointer user_data) {
  FlutterFileDropLinuxPlugin* self = FLUTTER_FILE_DROP_LINUX_PLUGIN(user_data);
  if (offset < 0 || max_bytes <= 0 || max_bytes > 64 * 1024) {
    flutter_file_drop_linux_drop_file_host_api_respond_read_file_chunk(response, nullptr, 0);
    return;
  }
  GHashTable* session_files = static_cast<GHashTable*>(g_hash_table_lookup(self->files, session_id));
  const gchar* path = session_files == nullptr ? nullptr : static_cast<const gchar*>(g_hash_table_lookup(session_files, file_handle));
  if (path == nullptr) {
    flutter_file_drop_linux_drop_file_host_api_respond_read_file_chunk(response, nullptr, 0);
    return;
  }
  int descriptor = open(path, O_RDONLY);
  if (descriptor < 0) {
    flutter_file_drop_linux_drop_file_host_api_respond_error_read_file_chunk(response, "read-failed", "Could not open dropped file.", nullptr);
    return;
  }
  g_autofree guint8* bytes = static_cast<guint8*>(g_malloc(static_cast<gsize>(max_bytes)));
  ssize_t count = pread(descriptor, bytes, static_cast<size_t>(max_bytes), static_cast<off_t>(offset));
  close(descriptor);
  if (count < 0) {
    flutter_file_drop_linux_drop_file_host_api_respond_error_read_file_chunk(response, "read-failed", "Could not read dropped file.", nullptr);
    return;
  }
  if (count == 0) {
    flutter_file_drop_linux_drop_file_host_api_respond_read_file_chunk(response, nullptr, 0);
    return;
  }
  flutter_file_drop_linux_drop_file_host_api_respond_read_file_chunk(response, bytes, static_cast<size_t>(count));
}

static void release_session(const gchar* session_id,
                            FlutterFileDropLinuxDropFileHostApiResponseHandle* response,
                            gpointer user_data) {
  FlutterFileDropLinuxPlugin* self = FLUTTER_FILE_DROP_LINUX_PLUGIN(user_data);
  g_hash_table_remove(self->files, session_id);
  flutter_file_drop_linux_drop_file_host_api_respond_release_session(response);
}

static const FlutterFileDropLinuxDropFileHostApiVTable host_api_vtable = {
    read_file_chunk,
    release_session,
};

static gboolean drag_motion_cb(GtkWidget* widget, GdkDragContext* context,
                               gint x, gint y, guint time, gpointer user_data) {
  (void)widget;
  FlutterFileDropLinuxPlugin* self = FLUTTER_FILE_DROP_LINUX_PLUGIN(user_data);
  if (!self->listening) return FALSE;
  gboolean entering = self->session_id == nullptr;
  if (entering) self->session_id = make_session_id(self);
  send_event(self, entering ? "enter" : "move", x, y, preview_items(context));
  gdk_drag_status(context, GDK_ACTION_COPY, time);
  return TRUE;
}

static void drag_leave_cb(GtkWidget* widget, GdkDragContext* context,
                          guint time, gpointer user_data) {
  (void)widget;
  (void)context;
  (void)time;
  FlutterFileDropLinuxPlugin* self = FLUTTER_FILE_DROP_LINUX_PLUGIN(user_data);
  if (self->session_id == nullptr) return;
  send_event(self, "leave", 0, 0, fl_value_new_list());
  g_clear_pointer(&self->session_id, g_free);
}

static gboolean drag_drop_cb(GtkWidget* widget, GdkDragContext* context,
                             gint x, gint y, guint time, gpointer user_data) {
  FlutterFileDropLinuxPlugin* self = FLUTTER_FILE_DROP_LINUX_PLUGIN(user_data);
  if (!self->listening) {
    gtk_drag_finish(context, FALSE, FALSE, time);
    g_clear_pointer(&self->session_id, g_free);
    return TRUE;
  }
  if (self->session_id == nullptr) self->session_id = make_session_id(self);
  self->drop_x = x;
  self->drop_y = y;
  GdkAtom selected = GDK_NONE;
  GList* targets = gdk_drag_context_list_targets(context);
  const gchar* preferred[] = {"text/uri-list", "text/html", "text/plain"};
  for (const gchar* name : preferred) {
    GdkAtom candidate = gdk_atom_intern_static_string(name);
    if (g_list_find(targets, candidate) != nullptr) {
      selected = candidate;
      break;
    }
  }
  g_list_free(targets);
  if (selected == GDK_NONE) {
    gtk_drag_finish(context, FALSE, FALSE, time);
    g_clear_pointer(&self->session_id, g_free);
    return TRUE;
  }
  gtk_drag_get_data(widget, context, selected, time);
  return TRUE;
}

static void drag_data_received_cb(GtkWidget* widget, GdkDragContext* context,
                                 gint x, gint y, GtkSelectionData* selection_data,
                                 guint info, guint time, gpointer user_data) {
  (void)x;
  (void)y;
  (void)info;
  FlutterFileDropLinuxPlugin* self = FLUTTER_FILE_DROP_LINUX_PLUGIN(user_data);
  if (!self->listening) {
    gtk_drag_finish(context, FALSE, FALSE, time);
    g_clear_pointer(&self->session_id, g_free);
    return;
  }
  g_autoptr(FlValue) items = fl_value_new_list();
  GdkAtom target = gtk_selection_data_get_target(selection_data);
  g_autofree gchar* target_name = gdk_atom_name(target);
  if (g_strcmp0(target_name, "text/uri-list") == 0) {
    gchar** uris = gtk_selection_data_get_uris(selection_data);
    guint index = 0;
    for (gchar** uri = uris; uri != nullptr && *uri != nullptr; ++uri, ++index) {
      g_autofree gchar* scheme = g_uri_parse_scheme(*uri);
      if (g_strcmp0(scheme, "file") == 0) {
        fl_value_append_take(items, file_item(self, *uri, index, TRUE));
      } else {
        fl_value_append_take(items, string_item("text/uri-list", *uri, TRUE));
      }
    }
    g_strfreev(uris);
  } else {
    g_autofree gchar* text = reinterpret_cast<gchar*>(gtk_selection_data_get_text(selection_data));
    const gchar* mime = g_strcmp0(target_name, "text/html") == 0 ? "text/html" : "text/plain";
    fl_value_append_take(items, string_item(mime, text, TRUE));
  }
  send_event(self, "drop", self->drop_x, self->drop_y, items);
  gtk_drag_finish(context, TRUE, FALSE, time);
  g_clear_pointer(&self->session_id, g_free);
}

static void flutter_file_drop_linux_plugin_dispose(GObject* object) {
  FlutterFileDropLinuxPlugin* self = FLUTTER_FILE_DROP_LINUX_PLUGIN(object);
  if (self->view != nullptr) {
    g_signal_handlers_disconnect_by_data(self->view, self);
    g_object_unref(self->view);
    self->view = nullptr;
  }
  g_clear_object(&self->event_channel);
  g_clear_object(&self->messenger);
  g_clear_pointer(&self->session_id, g_free);
  g_clear_pointer(&self->files, g_hash_table_unref);
  G_OBJECT_CLASS(flutter_file_drop_linux_plugin_parent_class)->dispose(object);
}

static void flutter_file_drop_linux_plugin_class_init(FlutterFileDropLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_file_drop_linux_plugin_dispose;
}

static void flutter_file_drop_linux_plugin_init(FlutterFileDropLinuxPlugin* self) {
  self->files = g_hash_table_new_full(g_str_hash, g_str_equal, g_free,
                                     reinterpret_cast<GDestroyNotify>(g_hash_table_unref));
}

void flutter_file_drop_linux_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterFileDropLinuxPlugin* plugin = FLUTTER_FILE_DROP_LINUX_PLUGIN(
      g_object_new(flutter_file_drop_linux_plugin_get_type(), nullptr));
  plugin->messenger = FL_BINARY_MESSENGER(g_object_ref(fl_plugin_registrar_get_messenger(registrar)));
  plugin->event_channel = fl_event_channel_new(
      plugin->messenger, "flutter_file_drop/events",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_event_channel_set_stream_handlers(plugin->event_channel, stream_listen_cb,
                                       stream_cancel_cb, g_object_ref(plugin),
                                       g_object_unref);
  flutter_file_drop_linux_drop_file_host_api_set_method_handlers(
      plugin->messenger, nullptr, &host_api_vtable, g_object_ref(plugin),
      g_object_unref);

  plugin->view = fl_plugin_registrar_get_view(registrar);
  if (plugin->view != nullptr) {
    g_object_ref(plugin->view);
    GtkTargetEntry targets[] = {
        {const_cast<gchar*>("text/uri-list"), 0, 0},
        {const_cast<gchar*>("text/html"), 0, 1},
        {const_cast<gchar*>("text/plain"), 0, 2},
    };
    gtk_drag_dest_set(GTK_WIDGET(plugin->view), GTK_DEST_DEFAULT_MOTION,
                      targets, G_N_ELEMENTS(targets), GDK_ACTION_COPY);
    g_signal_connect_object(plugin->view, "drag-motion", G_CALLBACK(drag_motion_cb),
                            G_OBJECT(plugin), G_CONNECT_DEFAULT);
    g_signal_connect_object(plugin->view, "drag-leave", G_CALLBACK(drag_leave_cb),
                            G_OBJECT(plugin), G_CONNECT_DEFAULT);
    g_signal_connect_object(plugin->view, "drag-drop", G_CALLBACK(drag_drop_cb),
                            G_OBJECT(plugin), G_CONNECT_DEFAULT);
    g_signal_connect_object(plugin->view, "drag-data-received", G_CALLBACK(drag_data_received_cb),
                            G_OBJECT(plugin), G_CONNECT_DEFAULT);
  }
  g_object_unref(plugin);
}
