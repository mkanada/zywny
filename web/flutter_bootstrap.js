{{flutter_js}}
{{flutter_build_config}}

// Sem `serviceWorkerSettings`: o service worker do Flutter (descontinuado)
// hoje só se desinstala e recarrega a página — registrado no mesmo escopo,
// derrubaria o sw.js do zywny (PWA), que o index.html registra.
_flutter.loader.load();
