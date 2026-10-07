# Q07 — Lembrete de voltar ao normal e detector de deslocamento

**Repo:** zywny · **Depende de:** Q05 · **Decisão necessária:** não

## Objetivo

Evitar o erro mais provável da fase: o teclado ficar com o TRANSPOSE errado
— esquecido de ontem, ou não ajustado hoje.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "Lembrete de voltar ao normal" e
  "Detector de deslocamento" em "Na tela".
- `lib/practice/practice_controller.dart` (`_onNote` L473, `_wrongPitches`)
  e `lib/practice/practice_session.dart` (`NoteVerdict` L18, `PracticeStep`
  L50: o que é nota certa e nota errada em cada modo).

## O que fazer

1. **Detector** (classe pura `ShiftDetector`, em `lib/practice/`): recebe,
   para cada nota errada, a nota esperada mais próxima no momento (no modo
   espera, as notas do passo; no tempo real, as da janela) e a recebida.
   Se as últimas **N = 6** notas erradas têm todas a mesma distância
   `d ≠ 0` (|d| ≤ 12) e nenhuma nota certa entre elas, dispara uma vez por
   sessão. N é constante nomeada; ajustar no aceite manual (Q08).
2. Mensagem (faixa no topo da partitura, some sozinha em 8 s ou ao tocar):
   - música sem transposição: "Parece que o teclado está transposto em
     ±|d|. Ajuste o TRANSPOSE para 0.";
   - música transposta: "Parece que o TRANSPOSE está em X. Ajuste para +3."
     (X = valor pedido + d, conforme o `PitchFrame`).
   Vale para **toda** música, transposta ou não — é o caso de esquecer o
   TRANSPOSE ligado. Só funciona em teclado que transpõe a saída MIDI
   (`out: true` ou ainda não conferido): nos outros, o TRANSPOSE errado
   muda o som mas não o número que chega, e o casador não vê erro nenhum.
   Esse caso é do lembrete (passo 3). Num teclado ainda não conferido, o
   disparo do detector é também a prova de que ele transpõe a saída:
   guardar `out: true`.
3. **Lembrete de voltar a 0**: ao abrir uma música **sem** transposição
   logo depois de uma transposta (na mesma execução do app), e o teclado
   não transpõe a saída (`out: false` ou não conferido): "Se ajustou o
   TRANSPOSE para a música anterior, volte para 0." Com `out: true`, o app
   não avisa por suposição: o detector vê o deslocamento de verdade.
4. Lembrete ao sair: **não** fazer (no celular, sair do app não tem um
   momento confiável). Anotar a razão.

## Fora de escopo

Ler o TRANSPOSE do teclado por MIDI (fora da fase Q).

## Critérios de aceite

1. Testes do `ShiftDetector`: 6 erros a +3 disparam; uma nota certa no
   meio zera; erros espalhados não disparam; dispara só uma vez.
2. Teste de widget: música sem transposição com o teclado falso em +3 mostra
   a faixa em até 6 notas erradas.
3. Lembrete de voltar a 0 aparece só no caso do passo 3.

## Notas de execução

### Resultado (2026-10-06): concluído

Arquivos: `lib/practice/shift_detector.dart` (`ShiftDetector`, `ShiftNotice`,
`shiftNoticeFor`, `shiftIsAlreadyRight`, `shouldRemindTransposeReset`),
`lib/practice/shift_banner.dart` (a faixa), `lib/practice/practice_controller.dart`
(`shiftDetector`, `onShift`), `lib/settings/app_settings.dart`
(`lastPieceTransposed`), `lib/main.dart` (`_shiftNotice`, `_shiftDetector`,
`_onShiftDetected`, `_maybeRemindTransposeReset`). Teste novo:
`test/shift_detector_test.dart` (35 casos).

**Decisões de execução**
- **O detector não compara com a nota esperada mais próxima, e sim com todas as
  do momento** (o acorde do passo; as da janela de 400 ms no tempo real). Com a
  mais próxima, o primeiro teste com o fixture (acorde Si–Ré–Fá♯) mostrou que o
  detector nunca dispararia em música em acordes — quase todo hino: com o
  teclado em +3 chegam Ré (acerta), Fá (a −1 do Fá♯, a +3 do Ré) e Lá (a +3 do
  Fá♯), e a distância à mais próxima alterna entre −1 e +3. Cada erro leva o
  conjunto de distâncias possíveis; vale o `d` que está em **todos** os erros
  seguidos (com uma nota esperada só, é "a mesma distância" do plano). Havendo
  mais de um, o de menor módulo.
- **Acerto por acaso não zera.** No tempo real o Ré acima vira `correct` na hora
  (no modo espera só quando o acorde fecha) e zeraria a conta a cada acorde.
  `ShiftDetector.correct(distances)` ignora o acerto que o `d` em curso explica
  (a tecla apertada seria outra nota do mesmo acorde). Um acorde tocado certo
  sempre zera: a nota mais grave (d > 0) ou a mais aguda (d < 0) não é
  explicada por `d`.
- **Quem vigia**: só teclado que transpõe a saída ou ainda não conferido, e com
  o som que sai do teclado (não com o monitor ligado) — o `enabled` do detector.
  Nos outros o TRANSPOSE errado não muda o número que chega.
- **Uma vez por sessão de treino**: o detector é um só por tela e é rearmado
  (`rearm`) a cada `PracticeController` novo.
- **O texto usa o TRANSPOSE atual do teclado**, não só a distância: num teclado
  conferido que transpõe a saída é `d − k` (valor pedido + d, como no plano); num
  não conferido (o `PitchFrame` ainda soma nada) a distância *é* o TRANSPOSE.
- **Teclado não conferido que dispara**: guarda `shiftsOut: true` (só quem
  transpõe a saída manda o número deslocado), mantendo o `shiftsIn` que já
  houvesse. Se ele já estava no valor pedido (`d == −k`, o app ainda supunha que
  não transpõe), só aprende isso: não há o que avisar (`shiftIsAlreadyRight`).
- **Lembrete** (`lastPieceTransposed`, em memória no `AppSettings`, que a
  biblioteca compartilha entre as telas): a cada gravura, se a anterior era
  transposta e esta não (abrir outra música, ou desligar a transposição na mesma
  tela), com teclado conectado que não transpõe a saída e som não só do app. Só
  o texto "Se ajustou o TRANSPOSE para a música anterior, volte para 0." — e não
  some ao tocar (só em 8 s ou ao tocar a faixa), para dar tempo de ler.
- **Lembrete ao sair: não existe.** No celular sair do app não é um momento
  confiável (a pessoa troca de app, a tela apaga, o sistema mata o processo sem
  aviso); o lembrete de voltar a 0 na música seguinte cobre o caso.
- **A faixa** some em 8 s, ao tocar a próxima nota (a que fez o aviso nascer
  chega na mesma entrega e não conta) ou ao tocar nela.
- N continua 6 (`kShiftDetectorNotes`); com acordes de três notas e teclado
  deslocado isso é por volta de dois acordes. Ajustar no aceite do Q08.

**Critérios**
1. `ShiftDetector`: 6 erros a +3 disparam; uma nota certa no meio zera; erros
   espalhados não disparam; só uma vez; mais o caso do acorde. ✔
2. Teste de widget: `PracticeController` real (modo espera) sobre a partitura
   de teste com um teclado falso em +3 e o `ShiftBanner` que a tela usa: a faixa
   aparece no 6º erro com o texto do plano. A ligação em `main.dart` (o
   `FlutterMidiInputService` não é injetável) não tem teste de widget, só o
   aceite manual do Q08. ✔ (parcial)
3. Lembrete só no caso do passo 3: `shouldRemindTransposeReset` testada nos sete
   casos (conferido que transpõe, anterior normal, esta transposta, sem
   teclado, som do app). ✔
