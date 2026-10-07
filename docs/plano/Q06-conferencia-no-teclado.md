# Q06 — Conferência no teclado

**Repo:** zywny · **Depende de:** Q05 · **Decisão necessária:** não
(D-TRP-CONFERIR decidida: primeira vez por teclado + ao tocar no selo)

## Objetivo

Um fluxo curto que diz à pessoa qual TRANSPOSE ajustar, confere pelo MIDI
(ou de ouvido) que ela ajustou, e descobre de uma vez como aquele teclado
trata a própria transposição.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "O problema do MIDI do teclado" e o
  item "Conferência no teclado" em "Na tela".
- `lib/midi/piano_keyboard.dart` (`PianoKeyboardPainter`, para mostrar a
  tecla), `lib/midi/midi_device_manager.dart` (nome do dispositivo
  conectado), `lib/audio/latency_calibration.dart` (exemplo de fluxo que
  escuta `PlayedNote` com prazo), U17 (vocabulário) e U18 (visual).

## O que fazer

Uma folha (bottom sheet no celular, diálogo no desktop) com estados:

1. **Instrução**: "No seu teclado, ajuste o **TRANSPOSE para +3**." Ajuda
   curta e genérica: "Costuma ser um botão TRANSPOSE ou uma função no menu;
   veja o manual do seu teclado." Nada de caminho por marca.
2. **Toque o Dó central**: o teclado desenhado mostra Dó4. Escuta a
   próxima nota-on (prazo de 30 s; sem nota → "Não chegou nada do teclado.
   Ele está conectado?").
3. **Resultado**, com `p` = pitch recebido e `k` da transposição:
   - `p == 60 − k`: o teclado transpõe a saída e está certo. Guarda
     `out: true`. Pronto (ou vai ao 4).
   - `p == 60`: ambíguo. **Teste de ouvido**: o app toca Mi♭4 (60 − k) pelo
     próprio som e pergunta "Soou igual à sua tecla Dó?". Sim → `out:
     false`; Não → "Confira o TRANSPOSE: precisa ser +3" e volta ao 1. Se o
     app não tem som disponível (Web sem gesto, motor desligado), aceitar a
     palavra da pessoa ("Já ajustei") e guardar `out: false`.
   - outro valor `60 + d`: "Seu teclado parece estar em d (ex.: +2). Ajuste
     para +3."
     Guarda `out: true` (só quem transpõe a saída manda deslocado) e volta
     ao 1.
4. **Entrada MIDI** (só se a saída de som é o teclado, M03): o app manda
   ao teclado duas notas, uma de cada vez — a escrita (Dó4) e a soada
   (Mi♭4) — e pergunta "Qual soou igual à sua tecla Dó: a 1ª ou a 2ª?". A 1ª
   → o teclado transpõe a entrada (`in: true`); a 2ª → `in: false`.
5. Grava `out`/`in` em `AppSettings` pelo nome do dispositivo (Q05) e
   remonta o `PitchFrame`.

Quando abre sozinha: ao ligar a transposição ou abrir uma música
transposta, **se o teclado conectado ainda não foi conferido**. Depois, só
pelo selo (Q08). Sem teclado conectado: não abre; o selo mostra a instrução.
Quando o som é só do app (`appIsSound`): não abre — nada a ajustar.

## Fora de escopo

O detector de deslocamento e o lembrete de voltar a 0 (Q07). O selo e a
gaveta (Q08).

## Critérios de aceite

1. Testes de widget com MIDI falso nos três caminhos do passo 3 e nas duas
   respostas do passo 4; `AppSettings` guarda o resultado pelo nome do
   dispositivo.
2. Teclado já conferido: abrir outra música transposta não abre a folha.
3. Prazo sem nota mostra a mensagem e deixa tentar de novo.

## Notas de execução

### Resultado (2026-10-06): concluído

Arquivos: `lib/midi/transpose_check.dart` (a leitura da tecla `classifyCheckKey`,
a decisão `shouldAutoCheckTranspose` e a folha `showTransposeCheck`),
`lib/settings/app_settings.dart` (`KeyboardTransposeBehavior.isChecked`),
`lib/main.dart` (`_maybeCheckTranspose`, `_openTransposeCheck`, `_playOwnTone`,
`_playKeyboardTone`). Teste novo: `test/transpose_check_test.dart` (26 casos).

**Decisões de execução**
- **Diálogo central, não folha inferior**, no celular e no desktop: a regra do
  U18 diz que "o que pede uma resposta antes de continuar é diálogo central" e
  que a folha inferior cobre a pauta em paisagem. (O texto acima falava em
  bottom sheet.)
- **Instrução e "toque o Dó" são duas telas.** A escuta só começa em "Já
  ajustei": quem toca antes de ajustar não gasta a leitura.
- **Outras oitavas do Dó** (`60 ± 12n`) não são lidas como TRANSPOSE ±12: a
  tela pede "o Dó do meio do teclado" e não guarda nada. Tocar o Dó do lado é um
  engano bem mais comum que um TRANSPOSE de ±12, que nem cabe na faixa (|k| ≤ 6).
- **O que se guarda é a última descoberta**, só quando a pessoa chega a
  "Concluir": fechar no meio não grava nada. Se o app não pergunta pela entrada
  (som não sai pelo teclado), o `shiftsIn` que já estava guardado fica como
  estava.
- **Teste de ouvido** usa só o sintetizador do app **já aberto** (o app o deixa
  armado ao abrir a música); com a saída no teclado e o motor do app fechado, ou
  sem som, vale "Já ajustei" e guarda `shiftsOut: false`. Toca no canal do
  monitor (16), que a partitura não usa.
- **Teste da entrada** manda as notas cruas ao teclado (60 e `60 − k`) no canal
  1, com 1,2 s entre elas; só dá para responder depois das duas. "Ouvir de
  novo" repete.
- **Quando abre sozinha** (`_maybeCheckTranspose`): depois de cada gravura com
  transposição e quando um teclado se conecta, se ele não foi conferido, o som
  não é só do app e a pessoa não a fechou antes **nesta tela**. Uma por teclado
  por tela: quem fecha não é incomodado a cada regravação, mas é perguntado de
  novo na próxima música transposta, até responder. `_openTransposeCheck` é o
  que o selo do Q08 vai chamar (sem teclado, sem transposição na tela ou com o
  monitor ligado, não abre).

**Critérios**
1. Os três caminhos do passo 3 (63, 60 com ouvido sim/não/sem som, outro
   valor), as duas respostas do passo 4 e o `AppSettings` por nome do
   dispositivo: `test/transpose_check_test.dart`. ✔
2. Teclado já conferido não abre (`shouldAutoCheckTranspose`, testada com o
   `AppSettings`). A decisão é função pura; a ligação com a tela (`main.dart`)
   não tem teste de widget, só o aceite manual do Q08. ✔ (parcial)
3. Prazo sem nota: mensagem e "Tentar de novo". ✔
