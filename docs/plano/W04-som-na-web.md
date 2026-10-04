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

### Notas de execução (2026-10-04)

**D-WEB-SYNTH decidida**: SpessaSynth (`spessasynth_lib` 4.3.14 +
`spessasynth_core` 4.3.22, Apache-2.0), seguindo a recomendação.

**O que foi feito**
- `web_src/` (fonte do bundle; `package.json` + lock versionados,
  `node_modules` não): `src/zywny_audio.js` é um módulo ES com `init`,
  `loadSoundFont`, `send`, `schedule`, `clear`, `allOff`, `now`, `earliest`,
  `latency`, `baseLatency`, `outputLatency`, `peak`, `state`, `dispose`.
  `tool/build_audio_web.sh` (esbuild) gera `web/audio/zywny_audio.js` (210 KB,
  86 KB gzip) e copia o worklet `spessasynth_processor.min.js` (394 KB, 136 KB
  gzip) — pasta git-ignorada, como `web/verovio/`. `just web-audio`.
- `lib/audio/web_sound_engine.dart` (`WebSoundEngine`): extension type sobre o
  módulo, carregado **sob demanda** por `importModule('./audio/zywny_audio.js')`
  na primeira abertura do som (nada de som no download inicial). A fábrica
  (`sound_engine_factory.dart`) agora é `_native.dart if (dart.library.js_interop)
  _web.dart`; o stub que lançava `UnsupportedError` saiu. `schedule` manda um
  lote em dois typed arrays (tempos `Float64Array`, bytes 3 por evento).
- `settings`: "Timbre do piano → Trocar" escondido na Web (não há onde guardar
  o `.sf2` escolhido); só o TimGM6mb embutido.

**Relógio** (confirmado no código do SpessaSynth): `synth.sendMessage(bytes, 0,
{time})` com `time` em segundos do `AudioContext`; o worklet enfileira se
`time > currentTime` e processa na hora senão (resolução de um quantum, 128
amostras = 2,7 ms). `nowSeconds` = `getOutputTimestamp().contextTime`
extrapolado com `performance.now()` (só com o contexto `running`; senão
`currentTime - latência`), `earliestScheduleSeconds` = `currentTime`,
`outputLatencySeconds` = `outputLatency || baseLatency`. A diferença entre os
dois relógios foi 38,5 ms com `outputLatency` de 40 ms.

**A agenda mora no JS, não no worklet**: o worklet **não tem como cancelar**
eventos agendados (`stopAll` só para vozes, `eventQueue` não é limpa). Então
`schedule` guarda a fila no JS e um `setInterval` de 25 ms só manda ao worklet
o que está a menos de 100 ms (`LEAD`); `clear` descarta a fila e, para cada
nota-on que já estava a caminho, manda um nota-off logo depois (senão ficaria
presa); `allOff` faz isso, `stopAll(true)` e CC64=0 nos 16 canais. Custo: o
disparo depende do timer da página (uma aba em segundo plano e silenciosa é
limitada a 1 s pelo Chrome — com áudio saindo não é).

**`AudioContext`**: criado em `start()`; `resume()` é chamado a cada
`send`/`schedule` (um evento MIDI não conta como gesto — o contexto tem de
ter sido liberado antes por um clique, o que o fluxo normal garante). O
Chromium do teste usa `--autoplay-policy=no-user-gesture-required`.

**Medido** (Chromium headless, Linux, `latencyHint: 'interactive'`)
- `sampleRate` 48000; `baseLatency` 10,7 ms; `outputLatency` 40 ms.
- Início do contexto + worklet: 292 ms. Carregar o TimGM6mb (5,97 MB) no
  worklet: 52 ms.
- Monitor (tecla → amostra gerada no grafo, pelo `AnalyserNode`): 4–13 ms,
  uma vez 26 ms (primeira nota); some a isso `outputLatency`. A latência
  percebida num Chrome de verdade, com um teclado, ainda não foi medida.
- Nota imediata, nota agendada (silêncio antes, som no horário, silêncio
  depois) e cancelamento (com e sem `allOff`) sem nota presa: conferidos pelo
  pico do analisador.

**Critérios**
1. (manual) No Chromium headless dirigido por CDP (o hino 1; a Gymnopédie e o
   Maple Leaf Rag **não** foram abertos — são `.vsb` de teste, não estão na
   biblioteca): Play toca (pico 0,05–0,15), destaque em verde e virada de
   página acompanham; Parar, Pausar e Reiniciar silenciam em < 0,3 s e,
   depois de Parar, 1,6 s depois o pico é 0 (também após Próxima página e
   Reiniciar com o Play ligado). ✔ (falta ouvir e conferir a repetição do
   Maple Leaf Rag)
2. (manual) Monitor com o Web MIDI falso: nota injetada soa (pico 0,07) e
   para ao soltar; latências registradas acima. ✔ (falta teclado real)
3. (manual) Modo espera (T02): ver W03, critério 1. ✔
4. `flutter build web --release`, `flutter analyze` e `flutter test` (294,
   2 ignorados) limpos. O Linux não foi reaberto à mão (`just run`); a
   única mudança no caminho nativo é a fábrica condicional. ✔

**Teste de fumaça**: `tool/web_smoke/` (`just web-smoke`): Chromium
headless + Web MIDI falso, 7 verificações (sem pergunta na abertura, sysex
falso, conexão, Play soa, Parar silencia, monitor soa, saída MIDI recebe).

**Para depois**
- Volume: o pico do piano é baixo (≈ 0,15 no Play, 0,07 no monitor); o
  motor nativo tem `setGain` — conferir a diferença de volume de ouvido e, se
  preciso, `synth.setMasterParameter('masterGain', …)`.
- O download da Web ainda leva `assets/verovio_data.zip` (2,5 MB, inútil
  aqui) e o `.sf2` (5,7 MB) mesmo sem som — ver W02.
- SF3 (menor): não foi preciso; 5,7 MB já é pouco.
