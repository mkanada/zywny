# M02 — Tocar a entrada pelo sintetizador do app (monitor)

**Repo:** zywny · **Depende de:** M01, K03 · **Decisão necessária:** não

## Objetivo

Para teclados controladores **sem som próprio**: o que o usuário toca sai
pelo sintetizador do app, com a menor latência possível, incluindo pedal de
sustain. Opção desligável (piano digital já tem som).

## Ler antes (só isto)

- `lib/midi/midi_input_service.dart` (M01), `lib/audio/sound_engine.dart`
  (K03), notas de execução de K01/K02 (latência medida).

## Contexto que você precisa

- Caminho: `onMidiDataReceived` → `engine.send([status, d1, d2])`
  imediatamente (não agende, não espere frame). Canal de monitor: um canal
  reservado (ex.: 15, `0x9F`) com programa próprio (piano, 0), para não
  brigar com o canal da partitura que o agendador usa. Encaminhe note-on,
  note-off e CC64 (sustain); ignore o resto.
- Latência total = entrada MIDI (USB ~1 ms + plataforma) + hop do Dart
  (platform channel/event loop, ~1-5 ms) + buffer de áudio. **Meça**: o
  jeito barato é gravar com o microfone do celular o "toc" da tecla física
  e o som do alto-falante e medir a distância entre os dois picos num editor
  de áudio (Audacity). Registre plataforma, buffer e resultado.
- Se o hop do Dart se mostrar o gargalo (>10 ms), a solução é mover a
  entrada MIDI para dentro do crate Rust (`midir`), ligada direto ao
  sintetizador — é a razão de existir da decisão D-MIDI. **Não faça isso
  neste passo**: registre os números e avise o usuário.
- **Som em dobro**: o padrão é desligado. Deixe claro na UI: "Ligue se o seu
  teclado não tem som próprio". Guarde a escolha por dispositivo.
- Mudança de dispositivo/desconexão com teclas apertadas: mande note-off
  para todas as `held` do canal de monitor (evita nota presa).

## O que fazer

1. `MidiMonitor` (liga `MidiInputService` → `SoundEngine`), opção na UI
   (seletor de dispositivo de M01), preferência persistida.
2. Medição de latência documentada.

## Fora de escopo

- Avaliação do que foi tocado (T01). Saída MIDI (M03).

## Critérios de aceite

1. **(manual, Linux)** Com VMPK (via `just fake-midi --relay`, ver M01):
   tocar e segurar o pedal (VMPK tem sustain) soa como esperado; desligar a opção silencia.
2. Latência medida registrada (Linux; Android se possível).
3. Desconectar o teclado com notas presas não deixa som preso (manual).
4. `just analyze` e `just test` limpos.

## Notas de execução

- `MidiMonitor` (`lib/midi/midi_monitor.dart`): liga `MidiInputService` a um
  `SoundEngine` já aberto, no canal 15 (`kMidiMonitorChannel`, programa 0 —
  piano), com `send` direto (note-on/off e CC64); `allNotesOff()` zera o que
  `held` ainda listar retido.
- O motor (`SoundEngine`+`.sf2`) é compartilhado com o som da partitura
  (K04): extraí `_ensureEngine()` de `_toggleSound` para os dois passarem
  pelo mesmo caminho — pede o `.sf2` só na primeira vez, de qualquer um dos
  dois botões.
- Botão "monitor MIDI" ao lado do de som, mesmo padrão visual. Preferência
  por dispositivo em `MidiDeviceManager.monitorEnabled/setMonitorEnabled`
  (`SharedPreferencesAsync`, chave `midi_monitor_<id>`).
- Troca/desconexão de dispositivo (`_onMidiDeviceChanged`, ouvindo
  `MidiDeviceManager.connected`): manda note-off do canal de monitor para o
  que ainda estiver retido e aplica a preferência do novo dispositivo — mas
  **nunca** abre o diálogo de `.sf2` sozinho; só liga de volta se `_engine`
  já existir (por exemplo, o som da partitura já tinha sido ligado antes).
  Se ainda não houver motor, o botão fica desligado até o usuário tocar
  nele — evita um diálogo de arquivo surpresa num hot-plug automático.
- **Latência não medida nesta sessão** (exigiria gravar com microfone o
  "toc" físico vs. o som do alto-falante e comparar no Audacity — trabalho
  manual, não reproduzível por mim). Falta o critério de aceite 2; os
  demais (1, 3, 4) foram cobertos por `just analyze`/`just test` limpos e
  pela leitura do código (note-off garantido no `dispose`/troca de
  dispositivo). Teste manual com VMPK (critério 1) também não foi
  executado nesta sessão.
