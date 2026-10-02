# U15 — Conectar o teclado: orientação e estado

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** nenhuma

## Objetivo

Quem ainda não conectou o teclado descobre como; quem conectou vê isso
escrito, não só num ponto colorido. Achado C5 e parte do E3; sugestão C5.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **C5**.
- Telas `02` e `27` (o botão do teclado: ícone + ponto cinza ou verde), `06`
  (seletor vazio) e `29` (conectado, com "native" embaixo do nome).
- `lib/midi/midi_device_picker.dart` (123 linhas, inteiro):
  `MidiDevicePickerButton` L8-L40, `showMidiDevicePicker` L44-L123.
- `lib/midi/midi_device_manager.dart` (180 linhas): `devices`, `connected`,
  `lastError`, `refresh` L38, `_autoConnectCandidate`, `connect`,
  `disconnect`.
- `lib/library/library_screen.dart`: `_header` L273-L311, `_MidiPill`
  L635-L680.
- `lib/settings/general_settings_panel.dart` L197-L209 (a linha
  "Dispositivo").
- [M01](M01-entrada-midi.md): "Contexto" (USB por OTG funciona sem
  permissão; BLE é pacote à parte, **pendente**).
- `test/midi_device_manager_test.dart`.

## Contexto que você precisa

- O teclado **conecta sozinho** ao ser plugado (um único dispositivo com
  fio, ou o último usado) — o aluno normalmente não precisa do seletor. O
  seletor serve para ver o estado, trocar e desconectar.
- Seletor vazio hoje: "Nenhum dispositivo MIDI encontrado." e "Fechar".
- Sob o nome do aparelho aparece `device.type.wireValue`: "native", "BLE",
  "virtual", "own-virtual", "network", "unknown" — nomes de protocolo.
- O mesmo objeto tem três nomes no app: "Dispositivo MIDI" (título do
  seletor), "Teclado MIDI" (configurações e tooltips) e "Dispositivo" (linha
  das configurações).
- Bluetooth: o plugin BLE não está no app (M01). Um teclado Bluetooth
  pareado no Android pode até aparecer pelo sistema; não prometa nem
  proíba mais do que "ainda não funciona por Bluetooth" — e só diga isso no
  Android, onde é verdade hoje. Confira no M01 antes de escrever o texto.
- `MidiDeviceManager.refresh()` é pública e segura para chamar de um botão
  (ela mesma serializa chamadas concorrentes).
- O seletor é usado em três lugares: biblioteca (botão do cabeçalho),
  configurações gerais (linha do teclado) e layout largo
  (`MidiDevicePickerButton`, com "Calibrar latência"). A mudança vale para
  os três.
- O roteiro das telas abre o seletor por
  `find.byTooltip('Conectar teclado MIDI')` e
  `find.byTooltip('Teclado MIDI: Teclado digital')` e fecha por
  `find.text('Fechar')`.

## O que fazer

1. `midiDeviceTypeLabel(MidiDeviceType)` em `lib/midi/`: serial → "USB",
   ble → "Bluetooth", network → "Rede", virtual/ownVirtual → "Virtual",
   unknown → "" (sem subtítulo). Teste.
2. `showMidiDevicePicker`:
   - título "Teclado MIDI";
   - vazio: ícone `Icons.piano_off`, "Nenhum teclado encontrado", o
     parágrafo de orientação da sugestão C5 e o botão "Procurar de novo"
     (`deviceManager.refresh()`; mostra progresso enquanto roda);
   - com aparelhos: o conectado diz "Conectado · USB"; os outros, "Toque
     para conectar · USB"; no conectado, a ação "Desconectar" explícita (hoje
     é o próprio toque na linha, sem aviso);
   - erro (`lastError`): a mensagem de hoje, com uma frase em português na
     frente ("Não deu para conectar.").
3. `_MidiPill` da biblioteca: ícone + palavra. Desconectado:
   `Icons.piano_off` + "Conectar"; conectado: `Icons.piano` + ✓ (ou o nome
   curto do teclado, se couber em 360 dp). O ponto colorido sai. Mantenha
   os tooltips (o roteiro e os leitores de tela usam).
4. Linha das configurações: "Teclado MIDI" / nome ou "nenhum conectado" /
   ação "Conectar" ou "Trocar".
5. Testes de widget do seletor nos três estados (vazio, um desconectado, um
   conectado) com um `MidiDeviceManager` de teste; do `_MidiPill` nos dois
   estados (precisa deixar de ser privado, ou testar pela `LibraryScreen`).

## Fora de escopo

- Suporte a Bluetooth (BLE).
- Calibração do atraso (o botão continua onde está; o U17 troca o rótulo).
- Entrada por microfone.

## Critérios de aceite

1. Teste: `midiDeviceTypeLabel` para os seis tipos.
2. Teste de widget: seletor vazio mostra a orientação e "Procurar de novo";
   tocar chama `refresh` (conte as leituras de `devices` no falso).
3. Teste de widget: seletor com teclado conectado mostra "Conectado · USB"
   e "Desconectar"; não existe o texto "native".
4. Teste de widget: o botão da biblioteca mostra "Conectar" sem teclado e
   muda ao conectar.
5. `grep -rn "Dispositivo MIDI" lib/` não acha nada.
6. `just telas`: telas 06, 27 e 29 refeitas conferem; o roteiro passa.
7. `just analyze` e `just test` limpos.

## Notas de execução

- `midiDeviceTypeLabel` e `midiHelpText` em `lib/midi/midi_labels.dart` /
  `midi_device_picker.dart`. A orientação só fala de Bluetooth no Android
  (`defaultTargetPlatform`): o M01 deixa o plugin BLE pendente.
- Seletor: título "Teclado MIDI"; vazio com `piano_off`, "Nenhum teclado
  encontrado", a orientação e "Procurar de novo" (chama `refresh()`, com
  progresso); aparelhos com "Conectado · USB" / "Toque para conectar · USB";
  no conectado, o botão "Desconectar" (o toque na linha deixou de
  desconectar); erro com "Não deu para conectar." na frente.
- `MidiStatusPill` (público, em `midi_device_picker.dart`) substitui o
  `_MidiPill`: ícone + "Conectar" / "Teclado ✓", sem o ponto colorido; os
  tooltips ficaram (`Conectar teclado MIDI`, `Teclado MIDI: <nome>`). No
  cabeçalho da biblioteca ele fica num `FittedBox`: com a palavra o botão
  ficou mais largo e a linha estourava nos testes (fonte Ahem, mais larga que
  a real); no aparelho, em 360 dp, o contador "N hinos" é quem perde espaço.
  O botão do layout largo (`MidiDevicePickerButton`) ganhou os mesmos
  tooltips.
- Configurações: linha "Teclado MIDI" / nome ou "nenhum conectado" /
  "Conectar" ou "Trocar". O cabeçalho da seção e a linha se chamam igual
  (o U17 revê o vocabulário).
- Critérios 1–5 e 7 passam (`grep "Dispositivo MIDI" lib/` vazio). O 6
  (`just telas`) não foi rodado.
