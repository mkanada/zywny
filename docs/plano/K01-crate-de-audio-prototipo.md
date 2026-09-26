# K01 — Crate `zywny_audio`: rustysynth + cpal tocando no Linux (CLI)

**Repo:** zywny (`native/zywny_audio/`, novo) · **Depende de:** — ·
**Decisão necessária:** **D-SF** (qual soundfont)

## Objetivo

Provar a pilha de som nativa antes de qualquer FFI: um crate Rust que abre a
saída de áudio padrão com `cpal`, carrega um `.sf2` com `rustysynth` e toca
(1) uma escala e (2) um arquivo `.mid`, pelo terminal. Medir o tamanho de
buffer e a latência de saída reportada.

## Ler antes (só isto)

- Este README (Fatos, Convenções/Estilo Rust).
- Docs do `rustysynth` (docs.rs/rustysynth) e do `cpal` (docs.rs/cpal) —
  só as páginas das APIs citadas abaixo.

## Contexto que você precisa

- Máquina: `cargo`/`rustup` prontos (alvo `x86_64-unknown-linux-gnu`);
  `libasound2-dev` 1.2.11 e `pipewire-alsa` instalados (o backend ALSA do
  cpal sai pelo PipeWire). `flutter_rust_bridge_codegen` também está
  instalado, mas **não** é usado aqui (ver K02).
- `rustysynth` 1.3.6 (MIT). Uso:
  ```rust
  let sf = Arc::new(SoundFont::new(&mut File::open(path)?)?);
  let settings = SynthesizerSettings::new(sample_rate as i32);
  let mut synth = Synthesizer::new(&sf, &settings)?;
  synth.note_on(channel, key, velocity);   // i32
  synth.note_off(channel, key);
  synth.process_midi_message(channel, command, data1, data2); // CC, program…
  synth.render(&mut left[..], &mut right[..]);  // f32, mesmo tamanho
  ```
  Também há `MidiFile::new(&mut file)` e `MidiFileSequencer::new(synth)` +
  `sequencer.play(&midi, loop)` + `sequencer.render(..)` — use para o teste
  (2). SF3 **não** é suportado (assuma); só `.sf2`.
- `cpal`: `cpal::default_host().default_output_device()`,
  `device.default_output_config()` (normalmente f32, 48 kHz, 2 canais no
  PipeWire), `device.build_output_stream(&config, callback, err_cb, None)`,
  `stream.play()`. O callback recebe `&mut [f32]` intercalado
  (L R L R…) e um `OutputCallbackInfo` com `timestamp().callback` e
  `.playback` (`StreamInstant`) — a diferença é a latência de saída
  estimada. Peça buffer pequeno com `BufferSize::Fixed(256)` se
  `SupportedBufferSize::Range` permitir; senão `Default`.
- No callback: **zero alocação e zero lock**. Pré-aloque `left`/`right` com
  folga (ex.: 8192 quadros) antes de criar o stream e renderize em pedaços.
- Soundfont (D-SF): até a decisão, use qualquer SF2 GM livre para teste
  (ex.: `FluidR3_GM.sf2`, MIT, pacote `fluid-soundfont-gm` do Ubuntu em
  `/usr/share/sounds/sf2/` se instalado). **Não versionar `.sf2` no git**
  sem a decisão — registrar onde ficou.
- Arquivo `.mid` de teste: gere com o CLI do fork
  (`verovio -t midi corpus/musicxml/Erik_Satie_-_Gymnopedie_No.1.mxl`), em
  diretório temporário.

## O que fazer

1. `native/zywny_audio/` com `Cargo.toml` (`rustysynth`, `cpal`, `anyhow` só
   no binário de exemplo), `src/lib.rs` mínimo e
   `examples/play.rs`: `cargo run --release --example play -- <sf2>
   [scale|<arquivo.mid>]`.
2. Imprimir: host, device, sample rate, formato, tamanho de buffer pedido e
   obtido, latência estimada (`playback - callback`) média/máxima dos
   primeiros 200 callbacks, e contagem de underruns (`err_cb`).
3. `.gitignore` para `native/zywny_audio/target/`.

## Fora de escopo

- FFI, agenda por amostra, Dart (K02/K03). Outras plataformas.

## Critérios de aceite

1. **(manual)** `play -- <sf2> scale` toca dó maior audível e limpa; `play --
   <sf2> gymnopedie.mid` toca a peça inteira sem estalos.
2. Números impressos registrados nas notas (sample rate, buffer, latência,
   underruns = 0).
3. `cargo clippy -- -D warnings` e `cargo fmt --check` limpos.
4. D-SF registrada no README (ou, se o usuário não decidiu, o SF usado no
   teste e o motivo).

## Notas de execução

**Implementado em 2026-09-25.** `native/zywny_audio/` (crate `lib`, sem
`crate-type` especial ainda — isso é K02): `Cargo.toml` (`rustysynth
1.3.6`, `cpal 0.18`, `anyhow` só em `[dev-dependencies]`, usado apenas pelo
exemplo), `src/lib.rs` mínimo (só doc-comment, a lógica mora no exemplo, como
sugerido) e `examples/play.rs`:
`cargo run --release --example play -- <sf2> scale|<arquivo.mid>`.

**cpal 0.18 divergiu um pouco do que o "Ler antes" descrevia** (a doc do
crate mudou desde então): `Device` não tem mais `.name()`, é `.id() ->
Result<DeviceId, Error>`; `err_cb` recebe `cpal::Error` (com `.kind()`,
`ErrorKind::Xrun` existe e é o que conto como underrun) em vez de um
`StreamError` à parte; `build_output_stream` toma `StreamConfig` por valor,
não por referência. Escala de teste: dó maior (C4-C5), notas de 450 ms + 50
ms de silêncio, agendada manualmente (`note_on`/`note_off`) com granularidade
de bloco do callback (~5 ms a 256 quadros/48 kHz) — suficiente aqui; a
agenda por amostra exata é K02. Peça de teste: `.mid` gerado do fork
(`verovio -r <verovio/data> -t midi
corpus/musicxml/Erik_Satie_-_Gymnopedie_No.1.mxl`), tocado via
`MidiFileSequencer` do próprio rustysynth (não precisei agendar nada à mão
para esse caminho).

**D-SF continua aberta** (README). Testei com
`/usr/share/sounds/sf2/TimGM6mb.sf2` (pacote Debian/Ubuntu
`timgm6mb-soundfont`, ~6 MB, já instalado no sistema, domínio público
declarado pelo autor — Tim Brechbill) por já estar disponível na máquina;
não é o `GeneralUser GS` proposto como padrão na tabela de decisões, só o SF
GM livre mais à mão para o protótipo. Não versionado (nem esse nem nenhum
outro `.sf2`), como pedido.

**Números medidos** (`aplay`/PipeWire, saída ALSA padrão): host `Alsa`,
device `alsa:default`, 48000 Hz, 2 canais, `F32`. Buffer pedido 256 quadros,
obtido `Fixed(256)` (o range do dispositivo permitia). Latência estimada
(`playback - callback`, 200 primeiros callbacks): média 15,84 ms / máxima
16,00 ms tocando a escala; 15,85 ms / 16,00 ms tocando a Gymnopédie —
consistente entre os dois modos, e compatível com um buffer de 256 quadros
(5,3 ms) mais duas ou três voltas de latência da pilha PipeWire/ALSA.
**Underruns: 0** nos dois testes.

**Critério 1 (manual, "toca... audível e limpa")**: rodei os dois comandos
de ponta a ponta (escala completa, Gymnopédie inteira) sem erros, sem
underruns e sem que o processo travasse — não tenho como confirmar a
qualidade do áudio *ouvindo*, isso fica para uma checagem manual do usuário.

**`cargo clippy --all-targets -- -D warnings`** e **`cargo fmt --check`**:
limpos.
