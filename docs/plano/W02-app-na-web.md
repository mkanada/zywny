# W02 — zywny compilando e desenhando a partitura na Web

**Repo:** zywny (+ artefatos de W01) · **Depende de:** W01 ·
**Decisão necessária:** não

## Objetivo

`flutter run -d chrome` abre o zywny, o usuário escolhe um arquivo, o `.vsb`
é gerado pelo wasm de W01 e a partitura aparece e toca o destaque (sem som —
som é W04).

## Ler antes (só isto)

- Notas de execução de W01 (como chamar o wasm, JSON ou zip, worker).
- `lib/main.dart` L1-L24 (imports `dart:io`), L181-L296 (`_abrirPartitura`,
  `_renderAndShow` usa `Directory.systemTemp`, `File`, caminhos).
- `lib/verovio_render.dart`, `lib/verovio_resources.dart`,
  `lib/native_paths.dart`.

## Contexto que você precisa

- Pontos que não compilam/não funcionam na Web hoje: `dart:io`
  (`Directory`, `File`, `Platform`), `dart:ffi` (bindings do Verovio,
  motor de áudio), `Isolate` com FFI, `path_provider` para dados
  extraídos, `file_selector` devolvendo **caminho** (na Web só há bytes:
  `XFile.readAsBytes()`), `Platform.environment`.
- Estratégia: **uma interface de render** com duas implementações por
  import condicional:

  ```dart
  // lib/render/score_renderer.dart
  abstract class ScoreRenderer {
    Future<VsbDocument> render({required Uint8List source, required String fileName,
                                required int pageWidth, required int pageHeight,
                                required Map<String, Object> options});
  }
  // score_renderer_native.dart → o código atual (grava temp, isolate, FFI)
  // score_renderer_web.dart   → js_interop chamando o worker de W01
  ```
  `import 'score_renderer_native.dart' if (dart.library.js_interop)
  'score_renderer_web.dart';`
- O `_abrirPartitura` passa a guardar **bytes + nome** em vez de caminho
  (no nativo continua gravando em temp para o FFI).
- `score_bridge/lib` **não** importa `dart:io` (conferido em 2026-09-24), então
  deve compilar na Web sem mudança. O pacote `archive` funciona na Web.
- Arquivos do wasm (`.js`, `.wasm`, `.data`, worker) vão em `web/` do zywny
  (pasta criada por `flutter create --platforms web .` — rode isso, ele não
  toca em `lib/`). Não versione os binários grandes; um script
  `tool/build_verovio_web.sh` copia do bridge, como os outros.
- Fontes do texto comum: `loadScoreFonts()` usa assets do pacote — funciona
  na Web.
- Renderer web: o padrão do Flutter 3.47 (CanvasKit/skwasm). Compare a
  qualidade com o Linux a olho; registre.
- Tamanho do download inicial (wasm + dados + app) — registre.

## O que fazer

1. `flutter create --platforms web .`; `ScoreRenderer` com os dois lados;
   `main.dart` sem `dart:io` direto (mova para os arquivos nativos).
2. Worker + js_interop.
3. `flutter build web --release` e servir localmente.

## Fora de escopo

- Som (W04) e MIDI (W03) — os botões ficam desabilitados na Web por ora.

## Critérios de aceite

1. `flutter build web --release` sem erros; `just analyze` limpo.
2. **(manual)** No Chrome: abrir Gymnopédie e Maple Leaf Rag, ver as
   páginas, Play acende notas e vira página (inclusive página alternativa
   nas repetições do Maple Leaf Rag).
3. Linux inalterado (`just run`, `just test`).
4. Tamanho do download e tempo até a primeira página registrados.

## Notas de execução

(preencher)

### Notas de execução (2026-10-04)

**O que foi feito**
- `lib/render/score_renderer.dart`: `ScoreRenderer` (+ `ScoreRenderRequest`,
  `RenderedScore`), com import condicional (`if (dart.library.io)`):
  `score_renderer_native.dart` (grava temp, `renderScoreToVsb` por FFI, cópia
  do `.vsb` no `--debug`) e `score_renderer_web.dart` (Web Worker +
  `dart:js_interop`/`package:web`, lê o JSON único com `VsbDocument.fromJson`).
  As constantes de tamanho de página foram para `lib/render/page_size.dart`
  (`verovio_render.dart` as reexporta, então os testes não mudaram).
- A partitura circula como **bytes**: `HymnCatalog.extractScore` virou
  `loadScore` (devolve `Uint8List`; `gzip` do `archive`, não o de `dart:io`),
  `OpenedHymn.scorePath` virou `scoreXml`. Testes ajustados.
- `main.dart` sem `dart:io` (`defaultTargetPlatform` no lugar de `Platform`);
  `diag_log.dart` e `general_settings_panel.dart` com guarda `kIsWeb`;
  `SoundEngineDebugPanel` com stub na Web (usa `NativeSoundEngine`/FFI).
- `web/verovio_worker.js` (versionado) + `tool/build_verovio_web.sh` (roda o
  `build_wasm.sh` do bridge e copia para `web/verovio/`, git-ignorado).
- `pubspec.yaml`: `web: ^1.1.0`.

**Correção no bridge (C++, não commitada)**: `Toolkit::RenderToBridgeJson`
passava `""` como timemap, apesar de a spec (§2) dizer que o JSON único o
leva — sem timemap não há `ScorePlayer` (`_canPlay` exige `timemap`). Agora
pede o timemap com as mesmas opções do `.vsb` (`includeMeasures`,
`includeRests`) e a mesma regra "omite se vazio". Conferido no Gymnopédie
(189 entradas) e no Maple Leaf Rag (1013): o `timemap` do JSON é igual ao do
`timemap.json` do `.vsb`, e o JSON do wasm é igual ao do nativo (só muda a
string `generator`).

**Critérios**
1. `flutter build web --release` sem erros (59 s); `flutter analyze` limpo. ✔
2. (manual) No Chromium headless dirigido por CDP: biblioteca aparece; o
   hino 1 abre e a partitura é desenhada (5 páginas; `render` = 1,8 s, já
   contando carregar e instanciar o wasm). **Play/destaque/virada de página
   não foram conferidos**: os cliques do script não acionaram o Play (a tela
   abre em modo trilha e o som é impossível até o W04) — conferir à mão no
   Chrome, inclusive a página alternativa do Maple Leaf Rag. ✘ pendente
3. `flutter test`: 289 passam, 2 ignorados. `just run` no Linux não foi
   reaberto à mão. ✔ (testes)
4. Download (release): `main.dart.js` 3,2 MB (957 KB gzip); wasm do Verovio
   14,8 MB (4,8 MB gzip, carregado pelo worker); `canvaskit/` 37 MB (só o
   necessário é baixado); assets 17 MB (hinos 4,3 MB, soundfont 5,7 MB,
   `verovio_data.zip` 2,5 MB — este último é inútil na Web, o wasm já embute
   os recursos). Tempo até a 1ª página não medido com rede.

**Descobertas para os próximos passos**
- Na Web três exceções "Error" sem texto aparecem na inicialização (antes de
  abrir qualquer hino) — provavelmente o `flutter_midi_command` sem
  implementação Web; investigar no W03.
- O som falha com `UnsupportedError` (`createSoundEngine`), já tratado pelo
  app ("som: erro ao iniciar"); W04 troca isso.
- O parse do JSON (7 MB no Maple Leaf Rag) roda na thread principal; se
  travar, mover o `jsonDecode` para o worker.
- Tirar `verovio_data.zip` dos assets da Web e carregar o `.sf2` só quando o
  som existir diminuiria o download.
