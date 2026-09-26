# K02 — API C do motor: comandos, agenda por amostra, relógio

**Repo:** zywny (`native/zywny_audio/`) · **Depende de:** K01 ·
**Decisão necessária:** não

## Objetivo

Transformar o protótipo de K01 numa biblioteca (`cdylib`) com uma API C
pequena, segura para chamar do Dart por `dart:ffi`: tocar agora, **agendar
eventos num instante exato (quadro de áudio)**, limpar a agenda, silenciar
tudo e informar o relógio do áudio.

## Ler antes (só isto)

- `native/zywny_audio/` (o que K01 deixou) e as notas de execução de K01.
- `lib/verovio_render.dart` e o binding do Verovio
  (`/home/mauricio/rust_projects/verovio_flutter_bridge/verovio/bindings/dart/lib/src/verovio_bindings.dart`
  L80-L140) — só para ver o estilo de binding manual que o projeto já usa.

## Contexto que você precisa

- **Por que C ABI manual e não flutter_rust_bridge**: a API é ~12 funções
  de tipos simples; o projeto já tem o padrão de binding manual (Verovio); e
  a Web não usará este crate por FFI (W04). FRB fica como alternativa se a
  API crescer.
- **Threads**: as chamadas FFI vêm do isolate principal do Dart (um thread
  por vez, mas não necessariamente sempre o mesmo thread do SO). O callback
  de áudio roda no thread do cpal. Comunicação: fila **SPSC sem lock**
  (crate `rtrb`) do lado de controle → áudio, com o produtor protegido por um
  `Mutex` **no lado de controle** (nunca no callback).
- **Agenda**: comando `Scheduled { frame: u64, msg: [u8; 3] }`. No callback,
  drene a fila para um heap pré-alocado (capacidade fixa, ex.: 16 384; se
  encher, descarte e conte em `dropped_events`). Renderize o buffer em
  sub-blocos cortados nos `frame` dos eventos: renderiza até o evento, aplica,
  continua. Eventos com `frame` no passado aplicam no início do bloco.
- **Relógio**: `frames_rendered: AtomicU64` (quadros entregues ao dispositivo
  até o início do callback atual) e, no mesmo callback, o instante
  monotônico (nanos, de `std::time::Instant` fixado na criação) guardado num
  `AtomicU64`. `zy_now_frame()` = quadro que **está saindo no alto-falante
  agora** ≈ `frames_rendered_at_cb + (agora - instante_cb) * sr -
  latência_saída_em_quadros`. Exponha também `zy_render_frame()` (sem
  subtrair latência) — o agendador usa este para saber o mínimo agendável.
- **Latência**: média de `playback - callback` dos `OutputCallbackInfo`
  (K01 mediu); exponha em quadros.
- **Carregar SF2**: por bytes (`*const u8, len`) — o Dart lê do asset. Pare o
  stream, recrie o `Synthesizer`, recomece; o `frames_rendered` continua
  monotônico (não zere). Documente que agendamentos pendentes são perdidos.
- **Silenciar**: `zy_all_notes_off()` = limpa a agenda + CC123 (all notes
  off) e CC64=0 (sustain) em todos os 16 canais, aplicado no próximo
  callback.
- API sugerida (`src/ffi.rs`, `#[no_mangle] pub extern "C"`, sem panics
  atravessando a fronteira — `catch_unwind` e código de erro):

  ```c
  ZyEngine* zy_engine_new(int32_t preferred_buffer_frames);  // NULL = erro; zy_last_error()
  int32_t   zy_engine_load_sf2(ZyEngine*, const uint8_t* bytes, size_t len);
  void      zy_engine_free(ZyEngine*);
  int32_t   zy_sample_rate(ZyEngine*);
  int32_t   zy_output_latency_frames(ZyEngine*);
  uint64_t  zy_now_frame(ZyEngine*);          // o que se ouve agora
  uint64_t  zy_render_frame(ZyEngine*);       // o que está sendo calculado
  void      zy_send(ZyEngine*, uint8_t status, uint8_t d1, uint8_t d2);          // já
  void      zy_schedule(ZyEngine*, const ZyEvent* events, size_t n);            // em lote
  void      zy_clear_scheduled(ZyEngine*);
  void      zy_all_notes_off(ZyEngine*);
  void      zy_set_gain(ZyEngine*, float gain);
  uint64_t  zy_stat(ZyEngine*, int32_t which); // underruns, dropped_events, …
  const char* zy_last_error(void);             // thread-local, válido até a próxima chamada
  typedef struct { uint64_t frame; uint8_t status, d1, d2, _pad; } ZyEvent;
  ```
- Build: `crate-type = ["cdylib"]`, `tool/build_audio_linux.sh` (cargo build
  --release + strip), instalação no bundle igual à `libverovio.so`
  (`linux/CMakeLists.txt` L109+), receita `just native-audio`.

## O que fazer

1. `src/engine.rs` (estado, fila, heap, callback), `src/ffi.rs`, header
   `include/zywny_audio.h` escrito à mão (ou `cbindgen`, se preferir —
   registre).
2. Testes Rust **sem dispositivo**: extraia a função "renderizar N quadros
   aplicando a agenda" para ser testada com um `Synthesizer` real e um buffer
   em memória (sem cpal).
3. Exemplo `examples/schedule.rs` que agenda uma escala a 120 bpm usando
   `zy_render_frame() + margem` e toca.

## Fora de escopo

- Dart (K03). Android/Windows (K05/K06).

## Critérios de aceite

1. Teste Rust: note-on agendado no quadro F produz a primeira amostra não
   nula em F (± 1 bloco interno do rustysynth, que é 64 quadros — registre o
   número exato; se for 64, é aceitável e documentado).
2. Teste Rust: `all_notes_off` leva a saída a silêncio (RMS < 1e-4) em até
   o tempo de release do preset (registre).
3. Teste Rust: heap cheio incrementa `dropped_events` sem pânico.
4. **(manual)** `examples/schedule.rs` toca a escala com andamento regular
   (sem "galope"); underruns = 0.
5. `cargo clippy -- -D warnings`, `cargo fmt --check`, `cargo test` limpos.

## Notas de execução

**Implementado em 2026-09-25.** `native/zywny_audio/` virou biblioteca de
verdade: `Cargo.toml` com `crate-type = ["cdylib", "lib"]` (o `"lib"` é o
que deixa `examples/`/`cargo test` linkarem normalmente — só `"cdylib"`
não geraria rlib) e `rtrb` adicionado; `anyhow` saiu de
`[dev-dependencies]` para `[dependencies]` (a camada segura `ZyEngine`/
`EngineCore` também usa, não só o exemplo de K01).

- **`src/engine.rs`**: `EngineCore` (a metade "áudio": `Synthesizer` +
  heap de eventos de capacidade fixa 16 384, `BinaryHeap<HeapEvent>`
  invertido para virar min-heap) e `render_block` (corta o bloco exatamente
  nos `frame` vencidos, aplica, continua — testável sem `cpal` nenhum).
  `ZyEngine` (a metade "controle"): abre o dispositivo em `new`; `load_sf2`
  é quem de fato cria o `Synthesizer` e sobe o `cpal::Stream` — chamável de
  novo depois (pausa o stream anterior, troca a fila SPSC — `rtrb` — e o
  heap, mantém os `Arc<AtomicU64>` do relógio). Todo comando (`send`,
  `schedule`, `clear_scheduled`, `all_notes_off`, `set_gain`) vira um
  `Command` empurrado na fila (produtor atrás de um `Mutex`, só no lado de
  controle); o callback de áudio drena a fila inteira no início de cada
  bloco — zero alocação, zero lock no caminho quente (o `Mutex` só existe
  do lado do produtor).
- **Relógio**: `frames_rendered`/`cb_instant_nanos` (um par consistente,
  atualizado no FIM do callback, depois de renderizar) mais
  `extrapolate_frame` (aritmética pura sobre `Instant` monotônico) dão
  `render_frame()`/`now_frame()` (este último subtrai a latência de saída
  estimada, recalculada a cada callback a partir de
  `OutputCallbackInfo.timestamp()`, igual a K01). Ressalva: entre
  `ZyEngine::new` e o primeiro callback de verdade rodar, `render_frame()`
  extrapola a partir do par inicial (0 quadros, no instante da criação do
  engine) — superestima levemente o quanto já tocou (nunca subestima:
  sempre do lado seguro, nunca agenda "no passado"). Só importa no
  arranque; o exemplo `schedule.rs` não teve problema com isso.
- **`src/ffi.rs`**: as 13 funções da API sugerida, escritas à mão (não
  `cbindgen`) — `include/zywny_audio.h` também à mão, mantido em sincronia
  manualmente. `catch_unwind` só em `zy_engine_new`/`zy_engine_load_sf2`
  (as únicas que fazem trabalho de verdade — abrir dispositivo, parsear
  bytes de SF2); as demais só leem atômicos ou empurram um `Command` na
  fila, e `ZyEngine::push_command` já recupera de um `Mutex` envenenado em
  vez de depender de `catch_unwind` para isso. `zy_last_error`:
  `thread_local!` de `CString`, como pedido.
- **Testes Rust sem dispositivo** (critérios 1-3, `src/engine.rs`, módulo
  `tests`): abrem um `Synthesizer` real (sem `cpal`) com um `.sf2` de teste
  — `ZYWNY_TEST_SF2` ou, senão, `/usr/share/sounds/sf2/TimGM6mb.sf2`
  (mesmo SF de teste do K01; ausência de qualquer um dos dois faz o teste
  pular com uma mensagem, mesmo padrão do `score_bridge` para corpus
  ausente). `note_on_agendado_soa_no_quadro_certo`: agenda em F, primeira
  amostra não-nula aparece em **exatamente F** (atraso 0, dentro da
  tolerância de 64 quadros do critério). `all_notes_off_silencia_ate_o_release`:
  confirma a nota soando (RMS > 1e-4) antes do corte, silencia (RMS < 1e-4)
  bem dentro da folga de 3 s dada. `heap_cheio_descarta_sem_panico`: empurra
  `SCHEDULE_CAPACITY + 10` eventos, heap para em `SCHEDULE_CAPACITY`,
  `dropped_events` bate exatamente 10, sem pânico.
- **`examples/schedule.rs` (critério 4, manual)**: agenda a escala de dó
  maior a 120 bpm com `engine.render_frame() + 200 ms` de margem, toca via
  `ZyEngine` direto (API segura do Rust, não a FFI crua — mais simples
  dentro do próprio crate) com o mesmo SF de teste do K01. Rodou sem
  underruns nem `dropped_events`; não tenho como confirmar "sem galope"
  *ouvindo* — fica para checagem manual do usuário, como em K01.
- **Build/bundle**: `tool/build_audio_linux.sh` (`cargo build --release` +
  `strip`, mesmo tratamento do `.so` do Verovio), receita `just
  native-audio`, e `linux/CMakeLists.txt` instala
  `native/zywny_audio/target/release/libzywny_audio.so` em `lib/` do bundle
  (mesmo RPATH `$ORIGIN/lib`, `WARNING` em vez de erro se a lib não existir
  — igual ao padrão do Verovio). Validado de ponta a ponta: `flutter build
  linux --release` roda limpo e `libzywny_audio.so` (612 KB, stripped)
  aparece em `build/linux/x64/release/bundle/lib/` ao lado de
  `libverovio.so` — a Dart/K03 ainda não referencia a lib nenhuma, só a
  bundling em si foi exercitada.
- **`cargo clippy --all-targets -- -D warnings`**, **`cargo fmt --check`**
  e **`cargo test`**: limpos (crate inteiro, incluindo os dois exemplos).
