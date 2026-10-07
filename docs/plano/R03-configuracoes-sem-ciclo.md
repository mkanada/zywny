# R03 — Configurações e áudio sem ciclo

**Repo:** zywny · **Depende de:** R02 · **Decisão necessária:** não

## Objetivo

Quebrar os ciclos audio → settings → practice → audio e audio ↔ midi
(achado 7 da revisão). `AppSettings` passa a importar só arquivos-folha, e
`lib/audio/` deixa de importar `settings/` e `midi/`.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 7.
- [R01](R01-teste-de-camadas.md): as linhas `// R03` da lista de desvios.

## Contexto que você precisa

- `lib/settings/app_settings.dart` L8–L14 importa:
  - `NoteNaming` de `music/note_names.dart` (depois do R02 já é folha);
  - `kPractice{Correct,Pending,Wrong}Color` de `practice/practice_colors.dart`
    (já é folha: só importa Flutter);
  - `PracticeMode`, `kDefaultRhythmToleranceMs` de
    `practice/practice_controller.dart` (L25 e L27) — o controller importa
    o agendador de `audio/`, `midi/` e `trail/`: **é este que fecha o ciclo**;
  - `TrailPhase`, `kTrailDefaultMeasures`, `kTrailMinMeasures`,
    `kTrailSpeeds` de `trail/trail_stage.dart`, que por sua vez importa
    `practice_controller.dart` só por `PracticeMode`.
- `practice/study_mode.dart` também importa `practice_controller` só por
  `PracticeMode`.
- `lib/audio/engine_opener.dart` (37 linhas) tem três funções:
  `openAppSoundEngine` (só áudio: `createSoundEngine` + `SoundFontStore`),
  `soundOutputKey` e `calibratedInputLatency` (usam `SoundOutput` de
  `app_settings` e `MidiDeviceManager`). Quem usa: `main.dart` L2052 e
  L2495, `library/library_screen.dart` L250, `course/ui/exercise_screen.dart`
  L283.
- `lib/audio/latency_calibration.dart` (111 linhas) importa
  `midi/midi_input_service.dart`; usado por `practice/practice_tools.dart`
  L7 e por `test/score_audio_scheduler_test.dart`.

## O que fazer

1. `lib/practice/practice_mode.dart` (folha, sem imports do app):
   `PracticeMode` e `kDefaultRhythmToleranceMs`, com os comentários que
   estão no controller. `practice_controller.dart` faz `export
   'practice_mode.dart';` para os outros 13 usuários não mudarem.
2. `app_settings.dart`, `trail/trail_stage.dart` e `practice/study_mode.dart`
   importam `practice_mode.dart` direto. Com isso `trail_stage.dart` vira
   folha (só `hand.dart` e `practice_mode.dart`).
3. `engine_opener.dart`: `openAppSoundEngine` fica em `lib/audio/` (no mesmo
   arquivo, sem os imports de `midi` e `settings`). `soundOutputKey` e
   `calibratedInputLatency` vão para `lib/practice/input_latency.dart`.
4. `git mv lib/audio/latency_calibration.dart lib/practice/` e corrigir os
   imports (inclusive o do teste).
5. Apagar da lista de desvios do R01 as linhas `// R03`; tirar
   `engine_opener.dart` e `latency_calibration.dart` das exceções do grupo
   áudio, que agora as cobre inteiras.

## Fora de escopo

Os painéis de `settings/` (R05). `midi/transpose_check.dart` (R06).
Mudar o que qualquer função faz.

## Critérios de aceite

1. `grep -n "^import '\.\./" lib/audio/*.dart` só mostra `../music/` e os
   arquivos soltos da raiz (`diag_log`, `native_paths`, que saem no R06).
2. `app_settings.dart` não importa `practice_controller.dart` nem nada de
   `audio/`, `midi/`, `library/`, `course/`.
3. `just analyze` e `just test` limpos; o teste de camadas passa sem as
   linhas `// R03`.

## Notas de execução

2026-10-06:

- `lib/practice/practice_mode.dart` novo, só com `PracticeMode` e
  `kDefaultRhythmToleranceMs`; `practice_controller.dart` faz `export
  'practice_mode.dart'` e os outros usuários ficaram como estavam. O
  comentário "Como o treino conduz o tempo (T03)" estava em cima da
  constante; agora fica em cima do enum, que é o que ele descreve.
- `app_settings.dart`, `trail/trail_stage.dart` e `practice/study_mode.dart`
  importam `practice_mode.dart` direto.
- `soundOutputKey` e `calibratedInputLatency` agora estão em
  `lib/practice/input_latency.dart` (importado por `main.dart` e
  `course/ui/exercise_screen.dart`, que só usava essa parte do
  `engine_opener`). `engine_opener.dart` ficou só com `openAppSoundEngine`.
- `git mv` de `latency_calibration.dart` para `practice/`; imports corrigidos
  em `practice_tools.dart` e `test/score_audio_scheduler_test.dart`.
- No teste de camadas, o grupo áudio cobre agora `audio/` inteira (exceto o
  painel de depuração); a linha `// R03` saiu de `_desviosConhecidos`.
  Sobram 7 (R04: 1, R06: 6).
- Aceite: `lib/audio/` só importa `../music/`, `../diag_log.dart` e
  `../native_paths.dart`; `app_settings.dart` só importa `music/`,
  `practice_colors`, `practice_mode` e `trail_stage`; `just analyze` sem
  avisos; `just test` 878 passaram, 10 pulados.
