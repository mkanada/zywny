#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <locale.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // B11: canal `zywny/incoming`, por onde um `.zywny` aberto com o app já
  // rodando chega ao Dart. Os caminhos esperam em `incoming_waiting` até o Dart
  // perguntar o que já havia (`initial`); depois vão direto.
  FlMethodChannel* incoming_channel;
  GPtrArray* incoming_waiting;
  gboolean dart_listening;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// O mapa `{name, path}` que o Dart entende (lib/incoming/incoming_packages.dart).
static FlValue* incoming_payload(const gchar* path) {
  g_autofree gchar* name = g_path_get_basename(path);
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "name", fl_value_new_string(name));
  fl_value_set_string_take(map, "path", fl_value_new_string(path));
  return map;
}

// Entrega ao Dart o que estiver esperando, se ele já pediu `initial`.
static void incoming_flush(MyApplication* self) {
  if (!self->dart_listening || self->incoming_channel == nullptr) return;
  for (guint i = 0; i < self->incoming_waiting->len; i++) {
    const gchar* path =
        static_cast<const gchar*>(g_ptr_array_index(self->incoming_waiting, i));
    g_autoptr(FlValue) payload = incoming_payload(path);
    fl_method_channel_invoke_method(self->incoming_channel, "file", payload,
                                    nullptr, nullptr, nullptr);
  }
  g_ptr_array_set_size(self->incoming_waiting, 0);
}

static void incoming_method_call_cb(FlMethodChannel* channel,
                                    FlMethodCall* method_call,
                                    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(method_call), "initial") == 0) {
    // O Dart se pôs à escuta: devolve o que chegou antes e, daí em diante,
    // empurra cada arquivo novo.
    self->dart_listening = TRUE;
    g_autoptr(FlValue) list = fl_value_new_list();
    for (guint i = 0; i < self->incoming_waiting->len; i++) {
      const gchar* path = static_cast<const gchar*>(
          g_ptr_array_index(self->incoming_waiting, i));
      fl_value_append_take(list, incoming_payload(path));
    }
    g_ptr_array_set_size(self->incoming_waiting, 0);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send incoming response: %s", error->message);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  // Segunda abertura do app (por exemplo, o clique duplo num `.zywny`): em vez
  // de uma janela nova, traz a que já existe.
  GtkWindow* existing =
      gtk_application_get_active_window(GTK_APPLICATION(application));
  if (existing != nullptr) {
    gtk_window_present(existing);
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "zywny");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "zywny");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  // O canal precisa existir antes de o Dart subir (o `realize` abaixo): é
  // a primeira coisa que o `main` pergunta.
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->incoming_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "zywny/incoming", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->incoming_channel, incoming_method_call_cb, self, nullptr);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  if (g_application_get_is_remote(application)) {
    // B11: já há um app aberto (só nas versões de release; ver
    // `my_application_new`). Os `.zywny` da linha de comando vão para ele
    // e este processo sai.
    g_autoptr(GPtrArray) files =
        g_ptr_array_new_with_free_func(g_object_unref);
    for (gchar** arg = self->dart_entrypoint_arguments;
         arg != nullptr && *arg != nullptr; arg++) {
      if (g_str_has_prefix(*arg, "--")) continue;
      g_autofree gchar* lower = g_ascii_strdown(*arg, -1);
      if (g_str_has_suffix(lower, ".zywny")) {
        g_ptr_array_add(files, g_file_new_for_commandline_arg(*arg));
      }
    }
    if (files->len > 0) {
      g_application_open(application,
                         reinterpret_cast<GFile**>(files->pdata), files->len,
                         "");
    } else {
      g_application_activate(application);
    }
    *exit_status = 0;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::open: o `.zywny` que outro processo mandou para
// este (o app já estava aberto). Vai ao Dart pelo canal e a janela sobe.
static void my_application_open(GApplication* application, GFile** files,
                                gint n_files, const gchar* hint) {
  MyApplication* self = MY_APPLICATION(application);
  for (gint i = 0; i < n_files; i++) {
    gchar* path = g_file_get_path(files[i]);
    if (path != nullptr) g_ptr_array_add(self->incoming_waiting, path);
  }
  incoming_flush(self);
  g_application_activate(application);
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);

  // O startup do GtkApplication (gtk_init) aplica o locale do sistema, e com
  // LANG=pt_BR o LC_NUMERIC passa a usar vírgula decimal. O Verovio lê as
  // âncoras SMuFL das fontes (Leipzig.xml etc.) com strtod, que depende
  // desse locale: "1.26" vira 1 e "0.16" vira 0, e as hastes das notas saem
  // na posição errada. Fixar LC_NUMERIC em "C" aqui, na thread principal e
  // antes de o Dart subir, vale para o processo todo sem mexer em mais nada
  // (texto, mensagens e entrada continuam no locale do usuário).
  setlocale(LC_NUMERIC, "C");
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->incoming_channel);
  g_clear_pointer(&self->incoming_waiting, g_ptr_array_unref);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->open = my_application_open;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->incoming_waiting = g_ptr_array_new_with_free_func(g_free);
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  // B11: com o app aberto, abrir um `.zywny` (clique duplo no gerenciador de
  // arquivos) leva o arquivo para a janela que já existe em vez de abrir outro
  // app. Só nas versões de release: no `flutter run` (debug) o app é sempre um
  // processo novo, senão ele sairia na hora, passando o arquivo a um release
  // que estivesse aberto, e o `flutter run` perderia o processo.
#ifdef NDEBUG
  const GApplicationFlags flags = G_APPLICATION_HANDLES_OPEN;
#else
  const GApplicationFlags flags = static_cast<GApplicationFlags>(
      G_APPLICATION_HANDLES_OPEN | G_APPLICATION_NON_UNIQUE);
#endif
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     flags, nullptr));
}
