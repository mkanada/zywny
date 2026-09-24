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
