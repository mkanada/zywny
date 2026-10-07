# R16 — Pacote `zywny_midi`

**Repo:** zywny · **Depende de:** R15 · **Decisão necessária:** não

## Objetivo

A camada MIDI sem tela num pacote Flutter, `packages/zywny_midi`: o
serviço de entrada, o gerenciador de dispositivos, a saída MIDI como
`SoundEngine` e o monitor. Os seletores e painéis ficam no app.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): "Divisão em
  pacotes".
- [R15](R15-pacote-zywny-audio.md): as notas de execução (sobretudo onde
  ficou o `diag_log`).

## Contexto que você precisa

- Vão para o pacote (o grupo "midi" do R01): `midi_input_service.dart`,
  `midi_device_manager.dart` (usa `shared_preferences`),
  `midi_out_sound_engine.dart` (implementa `SoundEngine`),
  `midi_monitor.dart`, `midi_labels.dart` e `web_midi_access*.dart` (import
  condicional, Web MIDI do W03). Pacotes externos: `flutter_midi_command`,
  `web`, `shared_preferences`.
- Ficam no app: `midi_device_picker.dart`, `midi_monitor_panel.dart`,
  `piano_keyboard.dart` (telas; importam `ui/theme`). O
  `transpose_check.dart` já saiu para `practice/` no R06.
- Os testes usam `FakeMidiInput` (`test/support/practice_fakes.dart`) e um
  `MidiCommandPlatform` falso (`test/settings_test.dart`,
  `test/widget_test.dart`). Os fakes que só o pacote usa vão com ele; os
  que o app também usa ficam em `test/support/`.
- Lembrete do M01: o plugin só vê portas de hardware no Linux (VMPK e
  `virmidi` não servem), então o teste manual precisa do teclado.

## O que fazer

1. `packages/zywny_midi/` (`resolution: workspace`; depende de
   `zywny_audio`, `zywny_music`, `flutter_midi_command`, `web`,
   `shared_preferences`), com os arquivos e testes acima.
2. Imports corrigidos em `lib/`, `test/` e `apps/`.
3. O grupo "midi" sai do teste de camadas.

## Fora de escopo

Mudar a reconexão, a latência ou a escolha de dispositivo.

## Critérios de aceite

1. `just analyze` e `just test` limpos; os testes do pacote rodam com
   `flutter test` dentro dele.
2. No app, com o teclado: conectar, tocar com o monitor ligado, desconectar
   e reconectar sozinho **(manual)**.

## Notas de execução

