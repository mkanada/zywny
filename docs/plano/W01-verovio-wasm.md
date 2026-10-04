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

**Ambiente**: `emsdk` instalado em `~/emsdk` (Emscripten 6.0.10), ativado via
`~/.bashrc` (fora dos repos). Não havia `bindings/js/` no bridge; criado.

**O que foi feito**:
- `verovio/emscripten/exports.txt`: adicionados `_vrvToolkit_renderToBridgeFile`
  e `_vrvToolkit_renderToBridgeJson` (não precisam de `EMSCRIPTEN_KEEPALIVE`
  em `c_wrapper.cpp` — exportar pelo `exports.txt` basta, como todo o resto
  do arquivo).
- `verovio/bindings/js/build_wasm.sh`: roda `emscripten/buildToolkit -w -c`
  (flags padrão do upstream — humdrum embutido, sem modularize). CMake usa o
  mesmo `../cmake` do build nativo (`file(GLOB verovio_SRC "../src/*.cpp")`),
  então os `.cpp` do bridge (`bridgewriter`, `bridgedevicecontext`,
  `filereader`/miniz, `svgpathparser`, …) entram automaticamente — nenhuma
  mudança de CMake foi necessária. Build completo: **9m51s** nesta máquina
  (compila o Verovio inteiro + Humdrum do zero).
- Saída: `verovio/emscripten/build/verovio-toolkit-hum.js` — **14.710.672
  bytes** (~14 MB) com o `.wasm` embutido em base64 (`SINGLE_FILE=1`, flag
  padrão do upstream); gzip (`build/verovio-toolkit-hum.js.gz`) =
  **4.784.370 bytes** (~4,7 MB), estimativa mais realista de transferência.
- `compare/out/w01/`: `index.html` + `worker.js` (Web Worker, evita travar a
  UI). Usa `Module.cwrap` diretamente (não o `VerovioToolkit`/proxy do npm,
  que não expõe `renderToBridgeJson`) — ok para protótipo descartável, W02
  decide a integração de verdade. Usei `renderToBridgeJson` (JSON único, não
  `renderToBridgeFile` + MEMFS): `Module.FS` **não fica exposto** com
  `-s STRICT=1` (só `cwrap`/`HEAPU8` estão em `EXPORTED_RUNTIME_METHODS`), e
  `renderToBridgeJson` é a alternativa mais simples que o passo já previa.
  Entrada: `--xml-id-seed 42` via `setOptions({outputTo:'vsb-json',
  xmlIdSeed:42})` **antes** de carregar os dados — sem isso
  `ApplyBridgeDefaults()` não roda (ela checa `GetOutputTo()==VSB_JSON`) e o
  render sai com cabeçalho/rodapé/labels que o nativo não tem.
- Referências nativas: `compare/out/w01/native/*.vsb.json`, geradas com
  `verovio -t vsb-json --xml-id-seed 42 --resource-path verovio/data`
  (mesmas opções que o worker usa).

**Critério 1 (byte-idêntico) — NÃO bate, achado real**: `midi.notes` e
`glyphs` batem exatamente (455/2568 notas, 16 glifos, mesmo `meta.title`) —
o parsing do MusicXML é idêntico. Mas a **paginação difere**: Gymnopédie
sai em 1 página no nativo e **2** no wasm; Maple Leaf Rag em 1 no nativo e
**3** no wasm. Tamanho da página é idêntico nos dois (2100×2970, mesma
`fit.scale`) — é o algoritmo de quebra de sistema/página decidindo
diferente para a mesma entrada+opções, não um erro de carregamento de
recursos (`emscripten/data/` tem os mesmos arquivos que `verovio/data/`,
mesmo tamanho; sem FreeType/HarfBuzz no CMake — as métricas de texto já são
só JSON embutido, iguais nos dois builds). Os `xml:id` de elementos gerados
por contagem (ex.: `alternates.sequences[0].pages[0].root.children[0].id`)
também divergem — consequência em cascata da paginação diferente (mais
sistemas/páginas = contador de id chega em valores diferentes), não um bug
de RNG à parte. **Não root-causei** (teria que instrumentar o cálculo de
largura/quebra de sistema no `view`/layout do Verovio upstream — escopo
maior que este protótipo). Mesmo padrão nas duas peças (não é 1 caso
isolado de arredondamento).

**Critério 2 (tamanho/tempo no Chrome) — medido no Chrome de verdade** (não
Node): Gymnopédie 467.265 bytes / **382,0 ms**; Maple Leaf Rag 7.325.037
bytes / **2653,6 ms** (só a chamada `renderToBridgeJson`, sem contar
carregar/instanciar o módulo wasm).

**Critério 3 (script reproduzível)** — `verovio/bindings/js/build_wasm.sh`,
rodou do zero com sucesso.

**Parecer (critério 4): não, ainda não** — tecnicamente o caminho funciona
(carrega, interpreta a partitura corretamente, roda em tempo aceitável num
Chrome real), mas o `.vsb` gerado no navegador **não bate** com o nativo por
um motivo ainda não identificado no próprio layout do Verovio (não é bug do
bridge nem de carregamento de recursos). Como a paridade >99,99% de pixels
é requisito inegociável do projeto (`CLAUDE.md` do bridge), esse é um
bloqueador real antes de investir em W02+: precisa isolar a causa da
paginação diferente (ex.: instrumentar `System::GetHeight`/cálculo de
largura de sistema com logs nos dois builds e comparar nó a nó) antes de
confiar no caminho Web.

### Correção (2026-10-04): o achado bloqueador era falso

A "paginação diferente" vinha da **referência nativa**, não do wasm: o CLI
`verovio -t vsb-json` sem `-a` (`--all-pages`) emite só a página 1
(`main.cpp`: `to = allPages ? GetPageCount() : from`). O wasm sempre emite o
documento inteiro. Com `-a` o nativo dá 2 páginas (Gymnopédie) e 3 (Maple
Leaf Rag), igual ao wasm. **Receita da referência nativa:**
`verovio -a -t vsb-json --xml-id-seed 42 --resource-path verovio/data -o X.json peça.mxl`.

O wasm de 2026-09-28 também estava velho (anterior ao `pitchpos` e ao G01),
então foi recompilado de 2026-10-04 (`build_wasm.sh`, 15 MB; 4,8 MB em gzip).
Comparado ao nativo (-a, mesma semente), nas duas peças: `alternates`,
`glyphs`, `meta`, `midi`, `pitchpos` e `scene` **idênticos**; só
`manifest.generator` difere (hash do commit do binário nativo, mais antigo que
o wasm) — diferença explicada, critério 1 atendido. Tempo no Node 26
(processo inteiro, incluindo carregar o wasm): Gymnopédie 0,96 s, Maple Leaf
Rag 3,14 s.

**Parecer revisado (critério 4): sim, o caminho é viável para a 1.0.**
Lição para os próximos passos: qualquer referência nativa para comparar com o
wasm precisa de `-a`, e o wasm precisa ser recompilado quando o C++ do bridge
muda. Harness de comparação sem navegador: carregar
`verovio-toolkit-hum.js` no Node e chamar `Module.cwrap` como o `worker.js`.
