# W04 — Som na Web: `WebSoundEngine` (SpessaSynth)

**Repo:** zywny · **Depende de:** W02, K04 · **Decisão necessária:**
**D-WEB-SYNTH** (recomendação: SpessaSynth)

## Objetivo

`SoundEngine` na Web com o mesmo soundfont das outras plataformas: Play toca
a partitura com o relógio do `AudioContext` mandando no destaque; monitor
(M02) e treino funcionam no navegador.

## Ler antes (só isto)

- `lib/audio/sound_engine.dart` e a fábrica com import condicional (K03).
- Notas de execução de K04 (agendador, âncora) e W02 (onde ficam os JS em
  `web/`).
- Documentação do `spessasynth_lib`: "Getting started"
  (`spessasus.github.io/spessasynth_lib/getting-started/`) e a página do
  `WorkletSynthesizer` — confirme os nomes de métodos abaixo, que não foram
  verificados um a um.

## Contexto que você precisa

- `spessasynth_lib` (Apache-2.0, ≥ 4.3.0): `npm install spessasynth_core
  spessasynth_lib`; `await ctx.audioWorklet.addModule(<worklet .js do
  pacote>)`; `const synth = new WorkletSynthesizer(ctx)`; conectar ao
  `ctx.destination`; carregar o soundbank (SF2/SF3/DLS) a partir de um
  `ArrayBuffer`; `noteOn(canal, nota, velocity)`, `noteOff(canal, nota)`,
  `controllerChange`, `programChange`. Verifique na doc se há parâmetro de
  **tempo de evento** (agendar no futuro); se houver, use-o. Se não houver,
  agende do lado Dart/JS com antecedência curta como no M03, mas tomando o
  tempo de `ctx.currentTime` — ou use o `Sequencer` só para o áudio (pior:
  duplica a lógica de K04; evite).
- Empacotamento: gere um bundle JS (esbuild/vite, instalado via `npx` numa
  pasta de build fora de `lib/`, ex.: `web_src/`) que expõe um objeto global
  simples (`window.zywnyAudio = {init, loadSf2, send, schedule, clear,
  allOff, now, latency}`) e copie o resultado + o worklet para `web/`.
  O Dart fala com esse objeto por `dart:js_interop` (`@JS()` extension
  types). Não use `package:js` (legado).
- Relógio: `nowSeconds` = `ctx.getOutputTimestamp().contextTime` (o que está
  saindo agora) com `ctx.currentTime` como fallback;
  `outputLatencySeconds` = `ctx.outputLatency` (Chrome) ou `baseLatency`.
- `AudioContext` só começa com gesto do usuário: `start()` deve ser chamado
  a partir do clique no Play (ou num botão "ativar som"); trate o estado
  `suspended`.
- Soundfont: o mesmo `.sf2` de D-SF, servido como asset; se for grande,
  mostre progresso de download. SpessaSynth lê SF3 (menor) — opção só na Web
  se o tamanho doer; registre.
- Cross-origin isolation **não** é necessária (sem SharedArrayBuffer).
- Alternativas descartadas (pesquisa de 2026-09-24):
  - **WebAudioFont** (`surikov/webaudiofont`, ativo, **GPL-3.0**): catálogo
    de ~2000 instrumentos GM pré-convertidos em `.js`. Descartado porque usa
    formato próprio (não o `.sf2` de D-SF, então a Web soaria diferente das
    outras plataformas e "carregar outro `.sf2`" não funcionaria), porque a
    GPL contaminaria o bundle (cada instrumento ainda herda a licença da
    soundfont de origem) e porque toca amostras com `AudioBufferSourceNode`
    na thread principal, sem AudioWorklet nem síntese SF2 completa. Única
    vantagem, download mínimo (só o piano), já coberta pelo SF3.
  - **soundfont-player** (danigb): arquivado desde 2023. Sucessor **smplr**
    (ativo, sem licença declarada no GitHub) usa amostras pré-renderizadas,
    não SF2; mesmos problemas de consistência.

## O que fazer

1. Bundle JS + worklet em `web/`, script de build documentado.
2. `WebSoundEngine` com `js_interop`, ligado na fábrica (ramo Web).
3. Habilitar som, monitor e treino na Web.

## Fora de escopo

- Otimizações de tamanho do download além de registrar números.

## Critérios de aceite

1. **(manual, Chrome)** Play toca a Gymnopédie e o Maple Leaf Rag com
   destaque sincronizado; pause/seek sem nota presa.
2. **(manual)** Monitor com VMPK/teclado via Web MIDI (W03): latência
   percebida registrada; `ctx.baseLatency`/`outputLatency` registrados.
3. **(manual)** Modo espera (T02) completo no Chrome.
4. `flutter build web --release`, `just analyze`, `just test` limpos; Linux
   inalterado.

## Notas de execução

(preencher)
