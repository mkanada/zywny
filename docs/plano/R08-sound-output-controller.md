# R08 — `SoundOutputController`

**Repo:** zywny · **Depende de:** R07 · **Decisão necessária:** não

## Objetivo

Primeiro dos quatro passos que desmontam `_ScoreHomePageState` (achado 5
da revisão). Tudo o que decide **por onde sai o som** — os dois motores,
a saída em uso, o `.sf2`, o monitor MIDI — sai da tela para um
`ChangeNotifier` testável sem widget.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 5.
- `lib/main.dart` nos trechos abaixo (linhas do commit `fac579c`; confira
  com `graft skeleton lib/main.dart` antes, porque R03–R07 mexeram nele).

## Contexto que você precisa

- Estado (L255–L390): `_appEngine`, `_midiOutEngine`, o getter `_engine`
  (escolhe pelo `_output`), `_output`, `_soundOn`, `_soundSetting`,
  `_autoSoundDone`, `_loadingSoundFont`, `_soundFonts`, `_customSoundFont`,
  `_midiMonitor`, `_midiMonitorOn`.
- Métodos: `_newMidiMonitor` L897; `_toggleSound` L2075,
  `_userToggleSound` L2104, `_restoreSound` L2113, `_ensureEngine` L2138,
  `_openAppEngine` L2151, `_ensureMidiOutEngine` L2181, `_applyOutput`
  L2205, `_setUseScoreInstruments` L2250, `_toggleMidiMonitor` L2256,
  `_disableMidiMonitor` L2274, `_onMidiDeviceChanged` L2291,
  `_tearDownMidiOutEngine` L2457, `_syncMidiMonitorToDevice` L2469,
  `_pickEngineWithSoundFont` L2494, `_chooseSoundFont` L2499,
  `_resetSoundFont` L2523.
- Acoplamento com a reprodução: `_toggleSound` pausa/retoma o
  `_scheduler` e troca o relógio do `_player`. Isso **fica na tela** neste
  passo (o R10 leva para o `PlaybackController`): o controller avisa que o
  som ligou/desligou ou que o motor mudou, e a tela religa o agendador.
- `test/support/practice_fakes.dart` já tem `FakeSoundEngine` e
  `FakeMidiInput`.
- `openAppSoundEngine` está em `lib/audio/engine_opener.dart` desde o R03.

## O que fazer

1. `lib/app/sound_output_controller.dart` (`ChangeNotifier`): recebe
   `AppSettings`, `MidiDeviceManager` e uma fábrica de motor (para o
   teste); expõe `engine`, `output`, `soundOn`, `loadingSoundFont`,
   `customSoundFont`, `midiMonitorOn` e as ações acima, com os mesmos
   nomes sem o `_`. Descarta os motores no `dispose`.
2. A tela cria o controller no `initState`, ouve-o com
   `ListenableBuilder`/`addListener` onde hoje faz `setState`, e chama-o
   no lugar dos métodos movidos.
3. `test/sound_output_controller_test.dart`: trocar de saída preserva o
   motor do app; o motor MIDI é recriado quando o dispositivo muda; o
   monitor segue o dispositivo; `dispose` fecha os dois motores.

## Fora de escopo

Agendador, player, contagem, metrônomo (R10). Mudar comportamento: é
extração fiel.

## Critérios de aceite

1. Nenhum dos métodos listados existe mais em `main.dart`; `wc -l
   lib/main.dart` cai pelo menos 300 linhas.
2. `just analyze` e `just test` limpos, com o teste novo.
3. No app: ligar e desligar o som, trocar entre sintetizador e teclado
   MIDI e voltar, ligar o monitor — tudo como antes **(manual)**.

## Notas de execução

