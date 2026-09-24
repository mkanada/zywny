# M03 — Tocar a partitura no teclado externo (MIDI out)

**Repo:** zywny · **Depende de:** M01, K04 · **Decisão necessária:** não

## Objetivo

Opção de saída "teclado MIDI": a partitura toca no som do próprio piano
digital do usuário, via MIDI, com o mesmo agendador de K04 e destaque
sincronizado.

## Ler antes (só isto)

- `lib/audio/sound_engine.dart` (K03), `lib/audio/score_audio_scheduler.dart`
  e `AudioPlaybackClock` (K04), `lib/midi/` (M01).

## Contexto que você precisa

- `MidiOutSoundEngine implements SoundEngine`:
  - `nowSeconds` = `Stopwatch` monotônico do app (não há relógio de
    dispositivo). `outputLatencySeconds` = 0 (ajustável pela calibração
    de T04).
  - `send` = `midi.sendData(Uint8List.fromList(bytes), deviceId: id)`.
  - `schedule`: o plugin não aceita timestamp futuro (exceto Web MIDI, que
    aceita — W03). Implemente uma fila interna ordenada e um despacho por
    `Timer` curto: o agendador de K04 já entrega com 250 ms de antecedência;
    aqui um `Timer` de ~5 ms (ou `Timer` exato até o próximo evento) envia
    cada mensagem quando `now >= at - 2 ms`. Jitter esperado: poucos ms
    (event loop). **Meça** (carimbe o envio e compare com `at`).
  - `allNotesOff`: limpa a fila e envia CC123 (all notes off) **e** CC120
    (all sound off) **e** CC64=0 nos 16 canais; alguns pianos ignoram CC123
    — como garantia, mande note-off explícito para toda tecla que o motor
    ligou e ainda não desligou (mantenha esse conjunto).
  - `loadSoundFont`: não faz nada.
- Program Change: pianos digitais mudam de timbre com PC; mande o programa
  do `NoteInfo.program` só se a opção "usar instrumentos da partitura"
  estiver ligada — padrão **desligado** (o usuário quer o som de piano dele).
- Canal: o piano digital toca em qualquer canal no modo padrão; use o canal
  da partitura, mas ofereça "forçar canal 1".
- **Local control**: se o usuário tocar junto enquanto o app toca no teclado
  dele, os dois sons se misturam no próprio piano — é o esperado. Não mexa
  em Local Control (CC122) na 1.0.
- A escolha de saída (sintetizador do app × teclado MIDI) fica na UI perto do
  Play; trocar com a música tocando: `allNotesOff` na saída antiga, nova
  âncora na nova.
- Fechar o app ou perder a conexão: `allNotesOff` no `dispose` e em
  `onConnectionStateChanged → disconnected`.

## O que fazer

1. `MidiOutSoundEngine`, seletor de saída, preferências.
2. Testes com um `FakeMidiSender`: ordem e horário das mensagens com
   relógio simulado; `allNotesOff` desliga exatamente as teclas ligadas.

## Fora de escopo

- Web MIDI (W03). BLE.

## Critérios de aceite

1. Testes verdes (ordem, `allNotesOff`, troca de saída no meio).
2. **(manual, Linux)** Com um sintetizador ALSA de teste (ex.: `fluidsynth
   -a pulseaudio -m alsa_seq <sf2>` ou `qsynth`, ou teclado real), a
   Gymnopédie toca no dispositivo externo com destaque sincronizado; pause
   deixa silêncio.
3. Jitter de envio medido (média/p95) registrado.
4. `just analyze` e `just test` limpos.

## Notas de execução

(preencher)
