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
const VERSION = 'dev';
const PRECACHE = [];

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
