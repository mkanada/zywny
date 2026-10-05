# Q05 — As alturas no app: o que se lê, o que se ouve, o que chega

**Repo:** zywny · **Depende de:** Q02, Q03 · **Decisão necessária:** não
(D-TRP-SOM decidida: o app soa no tom original)

## Objetivo

Com a música transposta, o casador compara alturas **escritas**, e todo som
que o app produz sai na altura **soada** (tom original). Quem converte é o
`PitchFrame` do Q02, montado num lugar só.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "As três alturas", "O problema do
  MIDI do teclado", "Quando o som é do app…".
- `lib/practice/practice_controller.dart` `_onNote` L473–L497 (todas as
  chamadas com `note.pitch`: `noteOn`, `noteOff`, `_releaseDone`,
  `ghosts?.release`, `_wrongPitches`).
- `lib/audio/score_audio_scheduler.dart` `_emit` L494 (L513–L514 mandam
  `e.pitch`).
- `lib/midi/midi_monitor.dart` `_onNote` L30; `lib/midi/midi_out_sound_engine.dart`
  `MidiOutSoundEngine` L43; `lib/audio/latency_calibration.dart` (também
  ouve `PlayedNote`: **não** converter — a calibração não depende de tom).
- `lib/settings/app_settings.dart` (padrão das chaves).

## O que fazer

1. **Comportamento por teclado** em `AppSettings`: mapa
   `nome do dispositivo → {out: bool?, in: bool?}` (chave
   `midi_keyboard_transpose`). `null` = ainda não conferido (Q06 preenche).
   Enquanto não conferido, supor `out: false, in: false` (o mais comum entre
   os dois é desconhecido; a conferência corrige).
2. **Montar o `PitchFrame`** onde a partitura é aberta e sempre que mudar a
   transposição, o teclado conectado, a saída de som ou o monitor. Sem
   transposição: `PitchFrame.identity`.
3. **Casador**: `_onNote` converte `note.pitch` com `writtenFromReceived`
   **uma vez**, no topo, e usa o valor convertido em todas as chamadas.
4. **Agendador**: `_emit` manda `soundingFromWritten(e.pitch)` — ou, se o
   motor for o `MidiOutSoundEngine`, `outFromWritten(e.pitch)`. O agendador
   recebe o `PitchFrame` (ou uma função `int Function(int)`) e não sabe nada
   de transposição.
5. **Monitor**: `monitorFromReceived(note.pitch)`.
6. **Teclado desenhado** e nomes de nota na tela (nota errada, legenda):
   altura **escrita** — é a tecla que a pessoa aperta.
7. **Quando o som é só do app** (teclado sem som ou monitor ligado): o
   `PitchFrame` já resolve; a tela do Q08 usa `appIsSound` para trocar a
   instrução "TRANSPOSE +3" por "Nada a fazer no teclado: o app toca no tom
   original".

## Fora de escopo

Descobrir `out`/`in` (Q06). Avisos (Q07). Tela (Q08).

## Critérios de aceite

1. Teste com `FakeMidiInput` (como `test/practice_controller_test.dart`
   L63): hino em 3♭ transposto `-m3`; teclado que **não** transpõe a saída
   manda as notas escritas → modo espera e tempo real passam; teclado que
   **transpõe** manda as soadas → passam igual.
2. Teste do agendador: com `-m3`, o motor do app recebe pitch = escrita + 3;
   com `MidiOutSoundEngine` e `in: true`, recebe a escrita.
3. Teste do monitor nos dois tipos de teclado.
4. Sem transposição, todos os testes de hoje passam sem mudança.

## Notas de execução

(vazio)
