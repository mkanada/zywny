// Service worker do zywny (PWA): guarda o app inteiro para ele abrir sem
// internet depois de instalado.
//
// tool/publish_web.sh troca VERSION (hash do conteúdo) e PRECACHE (a lista
// de arquivos do build) na cópia publicada. Fora dele — `flutter run -d
// chrome`, `just build-web` — VERSION fica 'dev': o worker só apaga caches
// de versões anteriores e não intercepta nada.
//
// Modelo "app shell" versionado: cada build publicado é um cache próprio
// (`zywny-<VERSION>`) servido cache-first; o navegador baixa o sw.js de novo
// a cada abertura e, se mudou, o worker novo baixa a versão nova inteira em
// segundo plano e assume quando todas as abas/janelas do app fecharem (sem
// skipWaiting: uma aba aberta nunca mistura main.dart.js velho com wasm
// novo). As bibliotecas ficam no IndexedDB e não passam por aqui.
const VERSION = '2ca5c150c0f6fb97';
const PRECACHE = ["assets/AssetManifest.bin", "assets/AssetManifest.bin.json", "assets/FontManifest.json", "assets/assets/cursos/iniciacao/course.md", "assets/assets/cursos/iniciacao/lessons/01-o-teclado.md", "assets/assets/cursos/iniciacao/lessons/02-pauta-e-clave-de-sol.md", "assets/assets/cursos/iniciacao/lessons/03-clave-de-sol.md", "assets/assets/cursos/iniciacao/lessons/04-clave-de-fa.md", "assets/assets/cursos/iniciacao/lessons/05-pauta-dupla.md", "assets/assets/cursos/iniciacao/lessons/06-figuras-e-pausas.md", "assets/assets/cursos/iniciacao/lessons/07-mais-tempos.md", "assets/assets/cursos/iniciacao/lessons/08-acidentes.md", "assets/assets/cursos/iniciacao/lessons/09-armadura.md", "assets/assets/cursos/iniciacao/lessons/10-juntando-tudo.md", "assets/assets/cursos/iniciacao/media/armadura-fa.png", "assets/assets/cursos/iniciacao/media/compasso.ogg", "assets/assets/cursos/iniciacao/media/dos.ogg", "assets/assets/cursos/iniciacao/media/ode-a-alegria.musicxml", "assets/assets/cursos/iniciacao/media/pauta-dupla.png", "assets/assets/cursos/iniciacao/media/vale-ate-a-barra.musicxml", "assets/assets/fonts/CormorantGaramond-MediumItalic.ttf", "assets/assets/fonts/CormorantGaramond-SemiBold.ttf", "assets/assets/fonts/CormorantGaramond-SemiBoldItalic.ttf", "assets/assets/fonts/InstrumentSans-Medium.ttf", "assets/assets/soundfonts/TimGM6mb.sf2", "assets/fonts/MaterialIcons-Regular.otf", "assets/fonts/fallback/Roboto-Regular.ttf", "assets/packages/cupertino_icons/assets/CupertinoIcons.ttf", "assets/packages/score_bridge/fonts/LiberationSerif-Bold.ttf", "assets/packages/score_bridge/fonts/LiberationSerif-BoldItalic.ttf", "assets/packages/score_bridge/fonts/LiberationSerif-Italic.ttf", "assets/packages/score_bridge/fonts/LiberationSerif-Regular.ttf", "assets/packages/wakelock_plus/assets/no_sleep.js", "assets/shaders/ink_sparkle.frag", "assets/shaders/stretch_effect.frag", "audio/spessasynth_processor.min.js", "audio/zywny_audio.js", "canvaskit/canvaskit.js", "canvaskit/canvaskit.wasm", "canvaskit/chromium/canvaskit.js", "canvaskit/chromium/canvaskit.wasm", "favicon.png", "flutter_bootstrap.js", "icons/Icon-192.png", "icons/Icon-512.png", "icons/Icon-maskable-192.png", "icons/Icon-maskable-512.png", "index.html", "main.dart.js", "manifest.json", "verovio/verovio-toolkit-hum.js", "verovio_worker.js"];

const CACHE = `zywny-${VERSION}`;
const scope = self.registration.scope;

self.addEventListener('install', (event) => {
  if (VERSION === 'dev') {
    self.skipWaiting();
    return;
  }
  // `cache: 'reload'` passa por cima do cache HTTP (o Pages manda
  // max-age=600): sem isso a versão nova podia guardar arquivo velho.
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      cache.addAll(PRECACHE.map((p) => new Request(new URL(p, scope), { cache: 'reload' }))),
    ),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key.startsWith('zywny-') && key !== CACHE) await caches.delete(key);
      }
      if (VERSION !== 'dev') await self.clients.claim();
    })(),
  );
});

if (VERSION !== 'dev') {
  self.addEventListener('fetch', (event) => {
    const request = event.request;
    if (request.method !== 'GET' || request.headers.has('range')) return;
    const url = new URL(request.url);
    const sameOrigin = url.origin === self.location.origin;
    // De fora, só as fontes que o Flutter busca no Google (Roboto e as de
    // fallback): guardadas quando passam, para valerem offline também.
    if (!sameOrigin && url.hostname !== 'fonts.gstatic.com') return;
    if (sameOrigin && !url.href.startsWith(scope)) return;
    event.respondWith(respond(request, sameOrigin));
  });
}

async function respond(request, sameOrigin) {
  const cache = await caches.open(CACHE);
  // Qualquer navegação dentro do app é o index.html (o Flutter roteia).
  const key = request.mode === 'navigate' ? new URL('index.html', scope).href : request;
  const hit = await cache.match(key, { ignoreSearch: sameOrigin });
  if (hit) return hit;
  const response = await fetch(request);
  // O que não estava na lista (NOTICES, uma variante do CanvasKit, fonte do
  // Google) entra no cache desta versão na primeira vez que passa.
  if (response.ok && (response.type === 'basic' || response.type === 'cors')) {
    cache.put(key, response.clone());
  }
  return response;
}
