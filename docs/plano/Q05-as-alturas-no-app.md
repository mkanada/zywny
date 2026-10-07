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

### Resultado (2026-10-06): concluído

Arquivos: `lib/settings/app_settings.dart` (`KeyboardTransposeBehavior`,
`keyboardTransposeOf`, `setKeyboardTranspose`, chave `midi_keyboard_transpose`),
`lib/music/pitch_frame.dart` (`engineFromWritten`, `engineFromReceived`),
`lib/practice/practice_controller.dart` (`writtenFromReceived`),
`lib/audio/score_audio_scheduler.dart` (`pitchOf`), `lib/midi/midi_monitor.dart`
(`pitchOf`), `lib/midi/midi_monitor_panel.dart` (`heldPitchOf`), `lib/main.dart`
(`_pitchFrame`). Testes novos: `test/alturas_no_app_test.dart` (18 casos) e um
caso em `test/pitch_frame_test.dart`.

**Decisões de execução**
- **Funções, não o `PitchFrame`, nos consumidores.** O casador, o agendador e o
  monitor recebem um `int Function(int)`; quem sabe de transposição é só a
  tela, que monta o `PitchFrame` **a cada chamada** (getter `_pitchFrame`:
  `k` da gravura na tela, o comportamento do teclado conectado, e `appIsSound`
  = monitor ligado). Assim nada precisa ser "remontado quando muda o teclado,
  a saída ou o monitor": a função sempre lê o estado de agora.
- **O motor decide a regra** (`engineFromWritten(midiKeyboard:)`): o
  `MidiOutSoundEngine` recebe `outFromWritten`; o sintetizador do app, a soada.
  O mesmo vale para o monitor sobre cada motor.
- **`appIsSound` = monitor MIDI ligado** (é o único sinal que o app tem de "o
  som do teclado não vale"); `PitchFrame` com `appIsSound` ignora os dois
  comportamentos guardados do teclado.
- **Teclado não conferido** (`KeyboardTransposeBehavior.unknown`, `null`/`null`):
  o app supõe `shiftsOut: false`, `shiftsIn: false`, como o plano mandou; o Q06
  preenche pelo nome do dispositivo (`MidiDevice.name`).
- **Monitor: o note-off sai na altura do note-on** (guarda a altura mandada por
  tecla), para não deixar nota presa se a transposição mudar com a tecla
  apertada.
- **Teclado desenhado do painel "Teclas que chegam"** mostra a **escrita**
  (`heldPitchOf`), a mesma altura das teclas erradas (`wrongPitches`). A lista
  de mensagens do painel continua com o número cru que chegou. A calibração de
  latência (`latency_calibration.dart`) não converte, como mandava o plano.
- **Notas na tela (legenda, nota errada)**: o treino todo passou a falar em
  altura escrita, então o `wrongPitches` já é a escrita; não havia texto com
  nome de nota na tela da partitura para converter.
- Não foi tocado: o fluxo de cursos/lições (`question_body.dart`,
  `score_round_runner.dart`), que não tem transposição (D-TRP-LICOES).

**Critérios**
1. `FakeMidiInput`, modo espera e tempo real, `k = −3`: teclado que não
   transpõe (manda a escrita) e que transpõe (manda a soada) passam igual, sem
   erro; a tecla da soada num teclado que não transpõe vira nota errada. As
   alturas da partitura vêm da gravura sem transposição de `test/fixtures`
   fazendo o papel da escrita (o `midi.json` de uma gravura com `-m3` é isso:
   a altura já deslocada); o render transposto de verdade é do Q01/Q03. ✔
2. Agendador, `-m3`: o motor do app recebe escrita + 3, com note-off na mesma
   altura; `MidiOutSoundEngine` com `in: true` recebe a escrita, com `in: false`
   a soada. ✔
3. Monitor, nos dois teclados: Dó (60) num que não transpõe e 63 num que
   transpõe saem os dois como 63. ✔
4. Sem transposição todos os testes de antes passam sem mudança (a única
   mudança em teste foi a assinatura de `onPracticeScore`, do Q04). ✔
5. `flutter test`: 785 passam, 10 pulados, 0 falhas. `flutter analyze`: uma
   info que já existia (`test/course_coverage_test.dart:188`), nada novo. ✔
