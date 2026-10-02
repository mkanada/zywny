# U03 — Ouvir o trecho, e o que fazer sem teclado

**Repo:** zywny · **Depende de:** U01 · **Decisão necessária:** D-OUVIR

## Objetivo

Na trilha, o aluno pode **ouvir** o trecho da etapa a qualquer momento. Sem
teclado conectado, a tela diz isso antes do toque e o play toca o trecho em
vez de reclamar. Achado A1; sugestão A1.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A1**.
- Telas `11` e `12`.
- `lib/main.dart`: `_startTrailStage` L788-L865 (o aviso de L798-L805),
  `_togglePlay` L1015-L1047, `_attachAudio` L1343-L1355, `_ensureEngine`
  L1513-L1522, `_endTrailRun` L992-L1005, `_onEntry` L1298-L1307,
  `_buildPhoneBody` L2105-L2140 (o que o play da barra lateral faz em cada
  modo), `_onMidiDeviceChanged` L1666-L1674.
- `lib/audio/score_audio_scheduler.dart`: `setStaves` L246, `setStopAt`
  L252 (teto de passagem única, J04), `play` L298, `pause` L318, `seek`
  L331.
- `lib/ui/phone_chrome.dart`: `PhoneRail` L19-L119.
- `lib/midi/midi_device_picker.dart`: `showMidiDevicePicker` L44.

## Contexto que você precisa

- Hoje, play na trilha sem teclado = `SnackBar` "conecte um teclado MIDI
  primeiro" (L801-L803; há outra igual em L1561, na saída MIDI). Ouvir só
  existe no treino livre, modo "Ouvir".
- **D-OUVIR, recomendação:** "ouvir" é ação própria da trilha, sempre
  disponível, **e** o play grande, sem teclado, ouve. Alternativa: só trocar
  a barra de aviso por uma com o botão "Conectar".
- Ouvir o trecho = tocar `[stage.startMs, stage.endMs)` com som, as duas
  mãos (`scheduler.setStaves(null)`), sem `PracticeController`, sem
  contagem, e parar sozinho no fim, voltando ao início do trecho. É o que a
  etapa faz menos a avaliação: `_ensureEngine` → `_attachAudio` →
  `player.seek` → `scheduler.setStopAt(endMs)` → `player.play()` +
  `scheduler.play(startMs, speed: …)`.
- Andamento do ouvir: o da etapa (`stage.speed`); nas etapas do modo espera
  (`speed == null`), 100%.
- O som do ouvir é **forçado**, como o da etapa (não depende de "Som do
  app"); ao terminar, volta ao estado do aluno — veja como `_endTrailRun`
  devolve andamento e metrônomo.
- Trechos com salto no caminho (J08): a etapa passa `rangeJumps` ao
  `PracticeController`, que chama `scheduler.setJumps`. O ouvir precisa do
  mesmo (`trailStageGaps`, `lib/trail/trail_plan.dart` L17-L31).
- Depois do U01 o texto da etapa está na barra do título. O aviso "sem
  teclado" é mais um item ali.
- O U07 redesenha a barra lateral da trilha; aqui só entra o botão novo.

## O que fazer

1. `_listenTrailStage()` em `lib/main.dart`: começa ou para o ouvir.
   Estado próprio (`_listening`), que entra em `_setPlaying`. Ao chegar em
   `stage.endMs` (o agendador para no teto; veja como `_onEntry` percebe o
   fim), pausa e volta a `stage.startMs`.
2. Botão "Ouvir o trecho" na `PhoneRail` (ícone `Icons.hearing` ou
   `Icons.headphones`, 48 dp), só na trilha, abaixo do play. Enquanto ouve,
   vira "Parar".
3. Play grande na trilha: com teclado, pratica (como hoje); **sem teclado,
   ouve**. Tooltip: "Ouvir o trecho".
4. Aviso na barra do título quando não há teclado: um item
   `Icons.piano_off` + "Conecte o teclado para praticar"; toque =
   `showMidiDevicePicker`. Some sozinho ao conectar
   (`_midiDeviceManager.connected` já é escutado).
5. Tirar a `SnackBar` de L801-L803 (o caminho que a mostrava deixa de
   existir). A de L1561 fica.
6. Ouvir e praticar são exclusivos: começar um para o outro. Ouvir não toca
   no progresso da trilha nem em `onPracticeScore`.
7. Roteiro das telas: a foto `12-trilha-pede-teclado` passa a ser
   `12-ouvindo-o-trecho` (play sem teclado → ouvindo); atualizar o README de
   `docs/telas/celular/` no U19.
8. Testes de widget: `PhoneRail` no modo trilha mostra o botão de ouvir e
   chama o retorno; o aviso de teclado aparece e some com
   `MidiDeviceManager.connected`.

## Fora de escopo

- Ouvir no treino livre (já existe: modo "Ouvir").
- Som ligado por padrão (U04).
- Redesenho completo da barra lateral (U07).

## Critérios de aceite

1. Teste de widget: barra lateral na trilha com o botão "Ouvir o trecho";
   tocar chama o retorno; em modo livre o botão não existe.
2. Teste de widget: sem teclado, a barra do título mostra o aviso; com
   teclado, não.
3. `just telas`: play na trilha sem teclado **toca** (nota destacada na
   foto 12) e não há barra preta.
4. **(manual, com som)** Ouvir o trecho 2 do hino 5: soam as duas mãos, do
   compasso 5 ao 9, e para sozinho, voltando ao 5. "Som do app" desligado
   não impede.
5. **(manual)** Hino com casa de 1ª/2ª vez dentro do trecho: o ouvir pula a
   casa descartada, como a etapa.
6. Ouvir não altera `TrailProgress` (teste de controlador ou conferência
   pela gaveta).
7. `just analyze` e `just test` limpos; o roteiro das telas passa.

## Notas de execução

- D-OUVIR decidida pelo usuário: ouvir como ação própria **e** o play sem
  teclado ouve.
- `_listenTrailStage`/`_stopListening` em `lib/main.dart` (fim do trecho
  detectado por um `Timer` de 50 ms sobre `player.position`; o teto do
  agendador só corta o áudio, o relógio segue). `PhoneRail.onListen` e
  `PhoneKeyboardNotice` em `lib/ui/phone_chrome.dart`. A `SnackBar` de
  "conecte um teclado" da trilha saiu.
- Ouvir deixa `_soundOn` ligado (como a etapa já fazia); o U04 trata do
  padrão do som.
- O botão novo cabe na barra lateral em 844×390 e 640×360 (teste de widget);
  o U07 redesenha a barra.
- Critérios 1, 2 e 7 (parcial: `just test`/`just analyze` limpos) passam.
  Critérios 3–6 (roteiro das telas e manuais com som) **não foram rodados**.
  O roteiro foi atualizado: a foto 12 virou `12-ouvindo-o-trecho`.
