# W01 — Protótipo: fork do Verovio em wasm gerando `.vsb` no navegador

**Repo:** verovio_flutter_bridge (build) + protótipo HTML descartável ·
**Depende de:** — · **Decisão necessária:** **D-WEB** (prioridade da Web)

## Objetivo

Provar (ou derrubar) o caminho da Web antes de investir nele: o **fork** do
Verovio compilado com Emscripten, rodando numa página HTML simples, carrega
uma MusicXML e produz os bytes de um `.vsb` idêntico ao do CLI nativo.

## Ler antes (só isto)

- No bridge: `CLAUDE.md` e `verovio/bindings/dart/lib/src/verovio_toolkit.dart`
  (quais funções do toolkit o app usa: `setResourcePath`, `setOptions`,
  `loadData`/`loadFile`, `renderToBridgeFile`, …) e `lib/verovio_render.dart`
  do zywny L82-L124 (a sequência exata de chamadas).
- `verovio/emscripten/` do fork (preservado do upstream: `buildToolkit`,
  `buildNpmPackage`, `exports.txt` — a lista de funções exportadas, onde
  entram as do bridge, — e `npm/`) e
  `verovio/tools/c_wrapper.cpp` (`vrvToolkit_renderToBridgeFile` L296).

## Contexto que você precisa

- **`emcc` não está instalado.** Instale o emsdk em `~/emsdk`
  (`git clone https://github.com/emscripten-core/emsdk && ./emsdk install
  latest && ./emsdk activate latest && source ./emsdk_env.sh`). Não coloque
  nada disso nos repos.
- O Verovio upstream publica o toolkit JS/wasm (`npm verovio`) a partir de
  `emscripten/buildToolkit` (script Python/CMake). Siga-o, mas **precisa
  incluir os `.cpp` do bridge** (`bridgedevicecontext`, `bridgewriter`,
  `bridgealternates`, `svgpathparser`, `filereader` com miniz, …) e exportar
  `vrvToolkit_renderToBridgeFile` (e `vrvToolkit_renderToBridgeJson`) em
  `EXPORTED_FUNCTIONS`. O CMake do bridge coleta `src/*.cpp` por glob — se o
  build Emscripten usar o mesmo CMake, eles já entram.
- `RenderToBridgeFile(filename)` escreve num arquivo: no Emscripten, grave no
  **MEMFS** (`/tmp/score.vsb`) e leia com `FS.readFile`. Alternativa:
  `renderToBridgeJson` devolve string (JSON único, §2.2) — o `score_bridge`
  já sabe ler JSON único (`VsbDocument.fromJson`). Prefira o que for mais
  simples; registre tamanho e tempo dos dois.
- **Dados** (`verovio/data`, fontes SMuFL): o build upstream embute via
  `--preload-file` ou `--embed-file`. Meça o tamanho do `.wasm` + `.data`
  final; o upstream fica em ~6-10 MB com as fontes.
- Threads: não use pthreads (exigiria COOP/COEP). Rode num Web Worker para
  não travar a UI (o app já roda o Verovio num isolate).
- Página de teste: `compare/out/w01/index.html` (git-ignorado) servida com
  `python3 -m http.server`; um `<input type=file>`, gera o `.vsb` e oferece
  download.

## O que fazer

1. Build wasm do fork com as funções do bridge exportadas.
2. Página de teste + Web Worker.
3. Comparar bytes com o nativo.
4. Registrar: comandos exatos de build (num script
   `verovio/bindings/js/build_wasm.sh` ou similar, no bridge), tamanhos,
   tempos.

## Fora de escopo

- Integração com o Flutter (W02).

## Critérios de aceite

1. Gymnopédie e Maple Leaf Rag: `scene.json`, `glyphs.json`,
   `timemap.json`, `notes.json` (se N01 já feito) **byte-idênticos** aos do
   CLI nativo com as mesmas opções (ou diferença explicada — ex.: string de
   `generator`).
2. Tamanho `.wasm` + dados e tempo de geração no Chrome registrados.
3. Script de build reproduzível no bridge.
4. Parecer nas notas: o caminho é viável para a 1.0? (sim/não/com o quê).

## Notas de execução

(preencher)
