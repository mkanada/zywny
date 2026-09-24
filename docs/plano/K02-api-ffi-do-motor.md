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

(preencher)
