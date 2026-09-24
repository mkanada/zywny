# Plano de implementação — som, MIDI e treino (zywny 1.0)

Meta da 1.0: o usuário **treina qualquer música no teclado MIDI**. A
apresentação da partitura está pronta (no Linux). Falta a parte sonora e
MIDI: tocar a música por soundfont, tocar por MIDI no teclado plugado,
receber e avaliar o que o usuário toca — em **Android, Linux, Windows e Web**.

Este diretório divide o trabalho em passos pequenos, cada um executável por um
modelo com contexto limitado (~250k tokens). Leia **só** este README e o
arquivo do passo que for executar. Cada passo traz, em **"Contexto que você
precisa"**, os fatos já medidos/pesquisados — não refaça a pesquisa; se um
fato estiver errado, corrija o documento (passo 6 abaixo).

## Como executar um passo

1. Leia este README (seções **Convenções**, **Mapa do código** e **Fatos**) e
   o arquivo do passo.
2. Confira na tabela de passos se as dependências estão `concluído`.
3. Se o passo tiver **Decisão necessária** ainda não resolvida na tabela de
   decisões, **pare e pergunte ao usuário** antes de escrever código. Não
   decida sozinho.
4. Implemente só o escopo do passo ("Fora de escopo" existe para isso).
5. Rode **todos** os critérios de aceite e registre o resultado.
6. Marque o passo `concluído` na tabela e escreva "Notas de execução" no fim
   do arquivo do passo: desvios, números medidos, descobertas que afetam os
   passos seguintes. Se algo medido contradisser este README ou um passo
   futuro, **corrija o documento** — um número errado custa mais que nenhum.
7. Não faça commit nem push sem o usuário pedir.

## Dois repositórios

| Repo | Caminho | Papel |
| --- | --- | --- |
| zywny (este) | `/home/mauricio/IdeaProjects/zywny` | App Flutter. Aqui moram o motor de áudio (`native/zywny_audio`, Rust), a camada MIDI e o treino |
| verovio_flutter_bridge | `/home/mauricio/rust_projects/verovio_flutter_bridge` | Fork do Verovio (C++) que exporta `.vsb` + pacote Dart `score_bridge` (parser, `ScoreView`, `ScoreController`, `ScorePlayer`). Dependência por `path:` no `pubspec.yaml` do zywny |

Ao editar o **bridge**, siga também o `CLAUDE.md` e as convenções de
`docs/plano/README.md` **de lá** (estilo C++ do Verovio, `.clang-format`,
saídas temporárias em `compare/out/`, não alterar `View`/`SvgDeviceContext`,
a spec `docs/formato/especificacao-v1.md` é atualizada junto com o formato).
O plano **daquele** repo usa os prefixos F/S/R/A/E/P; os passos deste plano
usam prefixos próprios (X, N, C, K, M, T, W, V) para não colidir.

## Convenções

- **Rodar o app (Linux)**: `just run` (= `flutter run -d linux
  --no-enable-impeller`; sem Impeller por causa de flutter#191171).
  `just test`, `just analyze`. Headless: `xvfb-run -a` quando `DISPLAY` vazio.
- **Refazer a libverovio.so** depois de mexer no fork: `just native` (chama
  `verovio/bindings/dart/build_linux_so.sh` do bridge e faz `strip`).
  CLI do fork: `cd verovio/tools && cmake ../cmake && make -j4` →
  `verovio/tools/verovio --resource-path verovio/data`. Rode `cmake ../cmake`
  de novo ao criar `.cpp` (glob).
- **score_bridge**: `cd score_bridge && flutter test` (fixtures `.vsb` em
  `score_bridge/test/fixtures/`).
- **Estilo Dart**: `dart format` + `flutter analyze` sem avisos. Comentários
  em português no bridge; no zywny o código existente comenta em inglês —
  imite o arquivo que estiver editando.
- **Estilo Rust** (`native/zywny_audio`): `cargo fmt`, `cargo clippy -- -D
  warnings`, nada de `unsafe` fora da fronteira FFI, **nada que aloque ou
  trave (mutex, println, Vec::push sem capacidade) dentro do callback de
  áudio**.
- **Tempo**: tudo em **milissegundos musicais** da partitura (o `tstamp` do
  timemap, andamento original). Tempo de parede = musical / `speed`.
- **Testes de lógica sem hardware**: toda lógica (agendador, casamento de
  notas, avaliação) é Dart puro, testável com relógio simulado. Hardware só
  nos critérios marcados **(manual)** — descreva o que foi feito e o
  resultado nas notas.
- Saídas temporárias: diretório de scratch do sistema, nunca no repo.

## Arquitetura alvo

```
.vsb (gerado no app pelo fork do Verovio)
  ├─ scene.json / glyphs.json  → ScoreView (pronto)
  ├─ timemap.json              → ScoreTimeline / ScorePlayer (pronto)
  └─ notes.json  (N01, novo)   → NoteTable (N02): pitch, pauta, canal, ligadura por id

zywny
  PerformanceTrack (N03)  = NoteTable × timemap → eventos {id, pitch, onMs, offMs, staff, ch, vel}
      │
      ├─ ScoreAudioScheduler (K04) ── janela à frente ──► SoundEngine (interface Dart)
      │                                                    ├─ NativeSoundEngine (K02/K03: Rust rustysynth+cpal, FFI)
      │                                                    ├─ MidiOutSoundEngine (M03: teclado externo)
      │                                                    └─ WebSoundEngine (W03: SpessaSynth, js_interop)
      │
      ├─ PlaybackClock (C01) ◄── posição do áudio (quem manda é o áudio)
      │        └─ ScorePlayer (bridge) lê o relógio → destaque / virada
      │
      └─ MidiInputService (M01/M02: flutter_midi_command) ──► PracticeSession (T01..T04)
                                                              └─ cores no ScoreController
```

## Mapa do código (estado em 2026-09-24)

### zywny

| Conceito | Onde |
| --- | --- |
| Entrada, estado da tela, play/stop | `lib/main.dart`: `main` L17 (`--debug`), `_ScoreHomePageState` L59, `_renderAndShow` L212 (cria `ScorePlayer` ~L262), `_togglePlay` L298, `_stop` L312, `_onEntry` L322, `build` L550 |
| Render do `.vsb` num isolate (FFI) | `lib/verovio_render.dart`: `VsbRenderRequest` L34, `renderScoreToVsb` L75, `_renderInIsolate` L82 |
| Localizar `libverovio.so` | `lib/native_paths.dart` `findVerovioLibrary` — **só Linux** hoje |
| Dados do Verovio (zip → diretório) | `lib/verovio_resources.dart` (`archive` + `path_provider`) |
| Painel de opções | `lib/layout_panel.dart`, `lib/layout_options.dart` |
| Build | `justfile`, `tool/build_verovio_linux.sh`, `tool/build_verovio_assets.sh`, `linux/CMakeLists.txt` L109+ (instala `libverovio.so` em `lib/` do bundle) |
| Testes | `test/widget_test.dart`, `test/vsb_render_test.dart`, `test/layout_options_test.dart` |

### score_bridge (no bridge)

| Conceito | Onde |
| --- | --- |
| Modelo | `score_bridge/lib/src/model.dart`: `VsbDocument` L167 (`manifest`, `glyphs`, `pages`, `timemap`, `meta`, `alternates` preguiçoso), `TimemapEntry` L633 (`tstamp` ms, `on`, `off`, `restsOn`, `restsOff`, `tempo`, `measureOn`, `qstamp`, `qfrac`) |
| Parser | `score_bridge/lib/src/parser.dart`: lê `manifest.files.timemap`/`.meta`/`.alternates` do zip (L57-L121) |
| Player | `score_bridge/lib/src/score_player.dart`: `Ticker` próprio, `_positionMs`, `speed`, `play` ~L150, `pause`, `_onTick` (soma `delta*speed`), `advance(Duration)`, `_advanceToMs`, `_apply` (on → `highlightAll`, off → `release`), `seek`, `seekToElement` L269, `onEntry`, `dispose` L346 |
| Linha do tempo | `score_bridge/lib/src/score_timeline.dart`: `ScoreTimeline(document)`, `entries`, `durationMs`, `measures` (`MeasureInfo`: id, page, noteIds, startMs, endMs, pass, view), `measureIndexAt` |
| Ids expandidos | `score_bridge/lib/src/expansion.dart`: `VsbDocument.sceneIdOf(id)` tira o `-rend<N>`; `passOf` |
| Destaque | `score_bridge/lib/src/score_controller.dart`: `highlightAll`, `release`, `releaseAll`, `clearHighlights`, `clearAll`, cores por id |
| API pública | `score_bridge/lib/score_bridge.dart` (exporte daqui tudo que o app usar) |

### Fork do Verovio (no bridge, `verovio/`)

| Conceito | Onde |
| --- | --- |
| Empacotar `.vsb` | `src/toolkit.cpp` `Toolkit::RenderToBridgeFile` (~L2364): timemap via `RenderToTimemap("{\"includeMeasures\": true}")`, `ZipFileWriter`, `BridgeWriter::WriteManifest(generator, pages, hasTimemap, hasMeta, hasAlternates, hasDebug)`; também `RenderToBridgeJson` (JSON único) |
| Doc expandido (repetições) | `Toolkit::SetMidiDoc()` L287 → `m_midiDoc` (ids `-rend<N>`) |
| Geração de MIDI | `src/doc.cpp` `Doc::ExportMIDI` (~L450-L620): laço por pauta (`staffDef->GetN()` = track), canal de `instrDef->GetMidiChannel()`, `transSemi`, patch |
| Nota → MIDI | `src/midifunctor.cpp` `GenerateMIDIFunctor::VisitNote` L807: pula `HasSameasLink`, cue (se `m_noCue`), **ligadura secundária** (`GetScoreTimeTiedDuration() < 0`); `velocity = HasVel ? GetVel : MIDI_VELOCITY`; trinados/tremolos expandidos em `m_expandedNotes`; pitch via `GenerateMIDIFunctor::GetMIDIPitch` L1149 = `note->GetMIDIPitch(m_transSemi, m_octaveShift)` (**inclui 8va** via `HandleOctave`) |
| Timemap | `GenerateTimemapFunctor::AddTimemapEntry` L1237: **toda** nota (inclusive ligada secundária) entra em `on`/`off` com seu próprio tempo |
| Ligaduras | `InitTimemapTiesFunctor::VisitTie` L313: nota 1 recebe a duração somada; nota 2 fica com `-1` |
| Bindings Dart | `verovio/bindings/dart/lib/src/verovio_toolkit.dart` (`renderToMIDI` L252, `getMIDIValuesForElement` L173 — **este ignora 8va/transposição**, não use para pitch) |

## Fatos (pesquisados em 2026-09-24)

- **Estado das plataformas hoje**: só Linux roda. Android: existe
  `verovio/bindings/dart/android-libs/arm64-v8a/libverovio.so` no bridge e um
  `build_android_so.sh`, mas o zywny não empacota a lib nem sabe achá-la.
  Windows: **não existe build** da `verovio.dll`. Web: nada roda (FFI,
  isolates, `dart:io`).
- **Máquina de dev**: Pop!_OS 24.04, Flutter 3.47.4 stable, NDKs em
  `~/Android/Sdk/ndk/` (23…29), `cargo`/`rustup` com só
  `x86_64-unknown-linux-gnu`/`musl` instalados, Chrome disponível
  (`flutter devices`). **Sem `emcc`**, sem máquina Windows local.
- **MIDI I/O**: `flutter_midi_command` 1.3.0 (set/2026) cobre Android
  (`android.media.midi`, USB e BLE), Linux (ALSA), Windows (WinMM) e Web (Web
  MIDI). API: `MidiCommand().devices`, `connectToDevice(d)`,
  `onMidiDataReceived` (`MidiDataReceivedEvent{device, transport, timestamp,
  message}` com mensagens tipadas `NoteOnMessage`, `CCMessage`…),
  `sendData(bytes, deviceId:)`, `onMidiSetupChanged`. BLE é pacote à parte
  (`flutter_midi_command_ble`). Alternativa: crate Rust `midir` (ALSA,
  WinMM/WinRT, Web MIDI, Android API 29+ via AMidi).
- **Síntese**: nenhum pacote Flutter faz SF2 nas 4 plataformas
  (`flutter_midi_pro` 4.0.4: só Android/iOS/macOS; `dart_melty_soundfont`:
  só PCM e sem saída de áudio multiplataforma; `flutter_pcm_sound`: sem
  Linux/Windows/Web). Escolha: crate próprio com **`rustysynth` 1.3.6** (MIT,
  SF2; **SF3 não documentado — assuma sem SF3**) + **`cpal`** (AAudio no
  Android, ALSA no Linux — PipeWire atende via pipewire-alsa —, WASAPI no
  Windows, WebAudio/AudioWorklet em wasm).
- **Web**: Web MIDI em Chrome/Edge/Opera/Samsung Internet; Firefox 108+ só
  com site-permission add-on; **Safari/iOS não têm**. Exige HTTPS (ou
  `localhost`). `AudioContext` só abre com gesto do usuário. Sintetizador web
  recomendado: **`spessasynth_lib`** (Apache-2.0, AudioWorklet, SF2/SF3/DLS;
  `npm i spessasynth_core spessasynth_lib`,
  `ctx.audioWorklet.addModule(...)`, `new WorkletSynthesizer(ctx)`; versões
  < 4.3.0 sem suporte).
- **Windows**: WinMM era de cliente único (porta ocupada por outro app =
  falha). O Windows MIDI Services (Win11 24H2/25H2, a partir de fev/2026)
  torna tudo multi-cliente, inclusive para WinMM. **Win10 continua
  exclusivo** → tratar "porta ocupada" com mensagem clara.
- **Latência**: alvo tecla→som ≤ 20 ms (bom ≤ 10 ms). Fone Bluetooth soma
  150-250 ms — avise o usuário. Android varia muito por aparelho → calibração
  (T04).
- **Piano digital tem som próprio**: se o app também sintetizar a entrada,
  sai som em dobro. O monitor da entrada pelo sintetizador do app vem
  **desligado** por padrão quando a saída é o próprio teclado.

## Decisões

| Id | Pergunta | Bloqueia | Recomendação | Status |
| --- | --- | --- | --- | --- |
| D-SF | Qual soundfont empacotar (tamanho × licença × qualidade)? | K01 | GeneralUser GS (~30 MB, licença permissiva, GM completo) como padrão; permitir o usuário carregar outro `.sf2` | **aberta** |
| D-MIDI | Pilha MIDI: `flutter_midi_command` ou `midir` (Rust)? | M01 | `flutter_midi_command` (pronto nas 4 plataformas); `midir` só se M01 medir problema | **aberta** (recomendação pronta) |
| D-WIN | Como compilar e testar no Windows (máquina própria, VM, CI)? | X02, K06 | Uma máquina/VM Windows 11 com VS Build Tools + Flutter; cross-compile só se não houver | **aberta** |
| D-WEB | A Web entra na 1.0 com o mesmo peso? | ordem da fase W | Sim, mas por último: o custo é portar o render (Verovio→wasm), não o som | **aberta** |
| D-WEB-SYNTH | Síntese na Web: SpessaSynth (JS) ou o crate Rust em wasm? | W04 | SpessaSynth (maduro, AudioWorklet pronto); mesmo `.sf2` nos dois lados | **aberta** |
| D-TREINO | Tolerâncias e UX do treino (janela de acerto, o que conta como erro) | T03 | ±75 ms "certo", ±150 ms "quase", fora disso "errado/perdido"; ornamentos e apojaturas não cobrados na 1.0 | **aberta** |

## Riscos conhecidos

1. **Web é o item mais caro** e não é por causa do som: o pipeline do `.vsb`
   é todo FFI. Mitigação: protótipo W01 cedo (pode rodar em paralelo à fase K).
2. **Latência no Android**. Mitigação: K05 mede de ponta a ponta antes de
   construir o treino em cima.
3. **Drift áudio × vídeo** se o `Ticker` continuar mandando. Mitigação: C01
   (relógio plugável) antes de ligar o som.
4. **Notas presas** (note on sem note off) em pause/seek/erro. Mitigação: toda
   implementação de `SoundEngine` tem `allNotesOff()` e ela é chamada em
   pause, stop, seek, troca de dispositivo e `dispose`.
5. **Pitch errado com 8va/transposição**: não use `getMIDIValuesForElement`.
   Mitigação: N01 grava o pitch que o `GenerateMIDIFunctor` calcula.

## Passos

| Passo | Título | Depende de | Decisão | Status |
| --- | --- | --- | --- | --- |
| [X01](X01-android-render.md) | Android: `.vsb` e partitura rodando (sem som) | — | — | pendente |
| [X02](X02-windows-render.md) | Windows: `verovio.dll` e partitura rodando (sem som) | — | D-WIN | pendente |
| [N01](N01-notes-json-no-fork.md) | Fork: `notes.json` no `.vsb` (pitch, pauta, canal, ligadura) | — | — | pendente |
| [N02](N02-notes-no-score-bridge.md) | `score_bridge`: modelo e parser de `notes.json` | N01 | — | pendente |
| [N03](N03-performance-track.md) | `PerformanceTrack`: eventos tocáveis por id, com ligaduras e mãos | N02 | — | pendente |
| [C01](C01-relogio-plugavel.md) | `ScorePlayer` com relógio plugável | — | — | pendente |
| [K01](K01-crate-de-audio-prototipo.md) | Crate `zywny_audio`: rustysynth + cpal tocando no Linux (CLI) | — | D-SF | pendente |
| [K02](K02-api-ffi-do-motor.md) | API C do motor: comandos, agenda por amostra, relógio | K01 | — | pendente |
| [K03](K03-sound-engine-dart.md) | `SoundEngine` (Dart) + `NativeSoundEngine` via FFI no Linux | K02 | — | pendente |
| [K04](K04-agendador-e-play-com-som.md) | Agendador da partitura + botão Play com som, relógio do áudio | K03, N03, C01 | — | pendente |
| [K05](K05-motor-no-android.md) | Motor de áudio no Android (cargo-ndk, AAudio) e latência | K04, X01 | — | pendente |
| [K06](K06-motor-no-windows.md) | Motor de áudio no Windows (WASAPI) | K04, X02 | D-WIN | pendente |
| [M01](M01-entrada-midi.md) | Dispositivos MIDI e entrada (monitor de notas) | — | D-MIDI | pendente |
| [M02](M02-monitor-pelo-sintetizador.md) | Tocar a entrada pelo sintetizador do app (monitor) | M01, K03 | — | pendente |
| [M03](M03-saida-midi.md) | Tocar a partitura no teclado externo (MIDI out) | M01, K04 | — | pendente |
| [T01](T01-casador-de-notas.md) | `PracticeSession`: acordes esperados e casador (Dart puro) | N03 | — | pendente |
| [T02](T02-modo-espera.md) | Modo espera + escolha de mão + app toca a outra | T01, K04, M01 | — | pendente |
| [T03](T03-modo-tempo-real-e-nota.md) | Modo tempo real com avaliação e resumo | T02 | D-TREINO | pendente |
| [T04](T04-calibracao-loop-metronomo.md) | Calibração de latência, loop A-B, metrônomo | T03 | — | pendente |
| [W01](W01-verovio-wasm.md) | Protótipo: fork do Verovio em wasm gerando `.vsb` no navegador | — | D-WEB | pendente |
| [W02](W02-app-na-web.md) | zywny compilando e desenhando a partitura na Web | W01 | — | pendente |
| [W03](W03-web-midi.md) | Web MIDI (entrada e saída) | W02, M03 | — | pendente |
| [W04](W04-som-na-web.md) | Som na Web: `WebSoundEngine` (SpessaSynth) | W02, K04 | D-WEB-SYNTH | pendente |
| [V01](V01-portao-da-1-0.md) | Portão da 1.0: matriz de plataformas | todos | — | pendente |

Ordem sugerida: N01→N02→N03 e C01 (dá para fazer em paralelo) → K01…K04
(som no Linux) → M01…M03 → T01…T04 → X01/K05, X02/K06 → W01…W04 → V01.
X01, X02 e W01 não dependem de nada e podem ser adiantados.
