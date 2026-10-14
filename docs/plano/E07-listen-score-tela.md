# E07 — `listen-score`: a tela (partitura por pergunta, som e revelação)

**Repo:** zywny · **Depende de:** E06 · **Decisão necessária:** não (D-LEI
no [E00](E00-exercicios-de-ouvido.md))

## Objetivo

A pergunta do `listen-score` funciona na tela do curso:

1. cada pergunta mostra **a sua** partitura (hoje a rodada tem uma só);
2. a frase toca sozinha quando a pergunta aparece (o acorde da tônica e
   depois a partitura, com a mudança), e "Ouvir de novo" repete;
3. depois da resposta certa (ou do tempo esgotado) vem a **revelação**: a
   nota que mudou fica destacada, uma frase diz o que mudou, e dois botões
   tocam "o que soou" e "o escrito". O aluno segue com **Próxima**.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md) (segunda parte), [E05](E05-mudanca-e-frase.md)
  (`ScoreComparison`, `TimedNote`, `playTimed`) e
  [E06](E06-listen-score-formato.md).
- [E02](E02-som-e-tela.md), itens 3 e 4: o som da pergunta.
- `lib/course/ui/question_body.dart`: L66–L132 (estado, `initState`,
  `dispose`), L135–L169 (`_scheduleCue`, `_playCurrent`), L194–L224
  (`_answerButton`, `_afterAnswer`), L226–L282 (`_applyHighlight`,
  `_loadScore`), L285–L366 (`build`), L485–L589 (`_listenPrompt`,
  `_intervalPrompt`, `_listenAgainButton`, `_noSoundNote`) e L616–L677
  (`_scoreView`).
- `lib/course/exercise/question_session.dart`: todo (135 linhas).
- `test/exercise_question_screens_test.dart`: `_makeDeps` (L117–L131) e um
  teste de `listen-interval` (procure `'Que intervalo é este?'`).

## Contexto que você precisa

- `QuestionSession` avança `index` **na resposta certa** e reinicia o
  relógio do `time-limit` ali mesmo (`_startAt`). No estouro, `tick` entra
  em revelação por `kAnswerRevealSeconds` (1,5 s) e depois avança.
  `_afterAnswer` é chamado nos dois casos.
- `_loadScore` desenha `widget.round.scoreBytes` **uma vez** (guarda em
  `_document`) e `_scoreView` só o chama na primeira medida
  (`_scoreWidthPx == null`). No `listen-score` a partitura é de cada
  pergunta (`question.compare!.scoreBytes`) e `round.scoreBytes` é nulo.
- `_applyHighlight` pinta por `highlightId`. O `listen-score` não usa
  `highlightId`: na revelação, pinte os `compare.changedIds`.
- `ScoreController.setColors({id: cor})` e `clearAll()` já existem (veja
  `_applyHighlight`).
- As cores: `widget.settings.practiceWrongColor` para a nota que mudou.

## O que fazer

### 1. Estado novo em `_QuestionBodyState`

```dart
  bool get _isListenScore => widget.spec is ListenScoreSpec;

  /// Índice da pergunta em revelação (`listen-score`), ou `null`.
  int? _reviewIndex;

  /// A última pergunta já revelada (para não revelar duas vezes).
  int _reviewedUpTo = -1;

  /// Os bytes da partitura desenhada agora (para saber quando trocar).
  Uint8List? _shownBytes;
```

- `_isListen` passa a incluir `_isListenScore`.
- A pergunta **mostrada** é `_reviewIndex != null ?
  widget.round.questions[_reviewIndex!] : _session.current`. Crie
  `Question? get _shown` e use-o no `build` e na partitura.

### 2. Partitura por pergunta

- Crie `({Uint8List bytes, String fileName})? get _scoreSourceOf(Question?
  q)`: `q?.compare` quando houver; senão `widget.round.scoreBytes` e
  `fileName` (os outros tipos continuam iguais).
- `_loadScore(widthPx)` passa a desenhar `_scoreSourceOf(_shown)`. A
  guarda `if (_document != null || _loadingScore) return;` vira: não faça
  nada se os bytes forem os mesmos de `_shownBytes`
  (`identical`) ou se já estiver carregando **esses** bytes. Ao trocar, solte
  o `_controller` e o `_viewController` antigos (como já faz) e grave
  `_shownBytes`.
- `_scoreView`: além da primeira medida, chame `_loadScore(widthPx)` quando
  os bytes da pergunta mostrada não forem os de `_shownBytes`. Enquanto
  carrega, mostre o quadro de espera que já existe (a altura não pula
  muito: as quatro partituras do mesmo passo têm a mesma altura).

### 3. Som

- `_playCurrent`: se `question.compare != null`, chame
  `playTimed(engine, question.compare!.played)` em vez de `playCues`. A
  guarda `question.sound.isEmpty` deixa passar quando há `compare`.
- Extraia de `_playCurrent` o trecho que abre o motor (`ensureEngine`,
  `start`, `_noSound`) para `Future<SoundEngine?> _openEngine()`, e use-o
  também nos botões da revelação:

```dart
  Future<void> _playReview(List<TimedNote> notes) async {
    final engine = await _openEngine();
    if (engine == null || !mounted) return;
    playTimed(engine, notes);
  }
```

### 4. A revelação

a. **Entrar.** Em `_afterAnswer`, logo no começo, depois do
`_applyHighlight()`:

```dart
    if (_isListenScore && _session.index - 1 > _reviewedUpTo) {
      _cueTimer?.cancel();
      _engine?.allNotesOff();
      setState(() => _reviewIndex = _session.index - 1);
      _paintReview();
      return; // `onDone` e a próxima pergunta esperam o "Próxima"
    }
```

Isso cobre a resposta certa e o fim da revelação do tempo esgotado (o
`tick` avança `index` e chama `_afterAnswer`).

b. **Pintar.** `_paintReview()`: `controller.clearAll()` e
`setColors({for (final id in compare.changedIds) id: practiceWrongColor})`.
Como a partitura da pergunta revelada é a mesma que estava na tela, não há
troca de partitura aqui. Chame-o também no fim de `_loadScore` quando
`_reviewIndex != null`.

c. **O relógio para.** No `Timer.periodic` do `time-limit` (em
`initState`), saia logo se `_reviewIndex != null`. Em `QuestionSession`,
crie:

```dart
  /// Recomeça a contar o tempo da pergunta atual (a tela ficou parada numa
  /// revelação que não é da sessão).
  void restartClock([double? now]) => _startAt = now ?? _lastTick ?? _now();
```

d. **O painel.** No `build`, quando `_reviewIndex != null`, em vez do
prompt e dos botões de resposta, mostre `_reviewPanel(question)`:

- o título: **"Certo!"** se a pergunta foi de primeira
  (`_session.firstTry[_reviewIndex!]`), senão **"Era aqui."** (se nada
  mudou: **"Era igual."**);
- a frase: com mudança, `'Compasso ${measure + 1}: ${description}.'` (por
  exemplo, "Compasso 3: uma nota soou mais aguda."); sem mudança, "O que
  soou foi exatamente o escrito.";
- a partitura (`_scoreView`), com a nota pintada;
- os botões: `OutlinedButton.icon` **"Ouvir o que soou"**
  (`_playReview(compare.played)`) e, só quando houve mudança,
  `OutlinedButton.icon` **"Ouvir o escrito"** (`_playReview(compare.written)`);
- `FilledButton` **"Próxima"** (ou **"Terminar"** na última pergunta), que
  chama `_closeReview()`.

Teclado do computador: Enter é "Próxima"; espaço e R tocam "o que soou"; E
toca "o escrito".

e. **Sair.** `_closeReview()`:

```dart
  void _closeReview() {
    _reviewedUpTo = _reviewIndex!;
    setState(() => _reviewIndex = null);
    if (_session.done) {
      _tickTimer?.cancel();
      widget.onDone(_session.result());
      return;
    }
    _session.restartClock();
    _applyHighlight();
    _scheduleCue(const Duration(milliseconds: 400));
  }
```

f. O `build` hoje devolve a roda de espera quando `_session.done`. Confira
`_reviewIndex` **antes**: a última pergunta ainda mostra a revelação.

### 5. O prompt da pergunta

`_listenPrompt`: no começo, se `_isListenScore`, devolva `_scorePrompt()`:

- o título: **"Em que compasso soou diferente?"** (`answer: measure`) ou
  **"Soou igual ao escrito?"** (`same-different`);
- a linha "Primeiro o acorde, depois a partitura." em `kInkCaption`;
- `_listenAgainButton()` e `_noSoundNote()` (os do E02/E04);
- a partitura (`_scoreView`).

Os botões de resposta já saem de `_buttons` (os rótulos são `'1'`…`'4'` ou
`'Igual'`/`'Diferente'`). No `build`, o ramo `_isListen` hoje não chama
`_scoreView`: para o `listen-score`, ele vem de dentro do `_scorePrompt`.

## Testes

Em `test/exercise_question_screens_test.dart`, um `group('listen-score')`.
Monte a rodada com `ListenScoreKind().generate(spec, files, Random(7))` e
ponha um `QuestionBody` direto (sem `ExerciseScreen`), com o
`FakeSoundEngine` e o renderizador de teste de `_makeDeps`. Assim o teste
sabe a resposta certa (`round.questions[i].correct`).

1. `step: 1c`, `answer: measure`, `count: 2`: aparece "Em que compasso soou
   diferente?" e os botões `1` a `4`; o motor recebeu as notas do acorde de
   Dó (60, 64, 67 e 48) e depois as da frase.
2. Tocar o botão errado e depois o certo: aparece a revelação com "Era
   aqui.", a frase com `Compasso`, e os botões "Ouvir o que soou", "Ouvir o
   escrito" e "Próxima". "Ouvir o escrito" agenda as notas de
   `compare.written`.
3. "Próxima" mostra a pergunta 2 e toca a frase dela; na revelação da
   última, o botão diz "Terminar", e tocá-lo chama `onDone` com `hits ==
   1` e `total == 2`.
4. `answer: same-different`, procure uma semente cuja primeira pergunta
   soe igual: a revelação diz "Era igual." (ou "Certo!") e **não** tem
   "Ouvir o escrito".
5. Com `pass: {time-limit: 2}`: deixe o tempo estourar; depois da revelação
   da sessão (1,5 s), aparece a revelação da tela; enquanto ela está
   aberta, o tempo não corre (espere mais 5 s: a pergunta seguinte não
   aparece sozinha).
6. Os testes de `listen-note` e `listen-interval` passam sem mudança.

## Fora de escopo

- O treino de leitura (E08).
- Ditado (E09) e resposta pela nota (E10).
- Desenhar o que soou na partitura (a revelação só destaca o escrito).

## Critérios de aceite

1. `flutter analyze` sem avisos novos; `flutter test` inteiro passa.
2. `just web-smoke` passa (não toca o `listen-score`, mas a tela de
   perguntas é a mesma).
3. Manual (Linux, com som): lição 2, "Igual ou diferente"; lição 6, "Onde o
   ritmo mudou"; lição 9, "A armadura esquecida". O acorde soa antes da
   frase; a frase sai no ritmo escrito; a revelação destaca a nota certa;
   "Ouvir o escrito" e "Ouvir o que soou" soam diferentes.
4. Manual (celular deitado e em pé): a partitura de quatro compassos cabe
   sem rolagem lateral e os quatro botões cabem numa linha.

## Notas de execução

**Resultado (13/10, sem commit):**

- `flutter analyze`: sem avisos.
- `flutter test` inteiro: `+1064 ~11`, verde (saída 0). O grupo
  `listen-score` (5 testes) está em `test/exercise_question_screens_test.dart`.
- `just web-smoke`: 21 ok, 0 falhas, saída 0. Não toca o `listen-score`,
  mas a tela de perguntas é a mesma.
- Aceite manual (itens 3 e 4) **não feito**: não há como ouvir o som nem
  girar o celular daqui. Fica com o usuário: lições 2, 6 e 9 no Linux, e
  a partitura de quatro compassos no celular, deitado e em pé.

**Desvios do plano:**

- `_scorePrompt` e `_reviewPanel` entram direto no `build`, e não dentro
  de `_listenPrompt`: os dois precisam dos `constraints` para o `_scoreView`.
- `_loadScore` roda a cada build e só pede ao renderizador quando os bytes
  mudam (`_requestedBytes`). Saíram `_loadingScore` e `_scoreWidthPx`. Enquanto
  a partitura nova carrega, aparece o quadro de espera (`_documentBytes`),
  e não a da pergunta anterior. Um desenho que chega depois da troca é
  descartado.
- Os controllers antigos são soltos depois do `setState`, não antes.
- A revelação pinta só os `changedIds`, com `practiceWrongColor`. O título
  é "Certo!" em `highlightColor` (de primeira); senão "Era aqui." ou "Era
  igual.", como no plano.
- Teclado na revelação: espaço e R tocam "o que soou"; E toca "o escrito"
  (só com mudança, como o botão). **Enter segue não tem teste automatizado**:
  o foco do Flutter nos botões tornaria o teste frágil. Conferir no aparelho
  com teclado.
- Os testes usam superfície de 800×1600: com 800×600 a partitura empurra os
  botões para fora da área visível.
- `waitReal` virou helper de arquivo (`_waitReal`), usado também pelo teste
  de "name-note" que já existia.

**Testes de `listen-score` (5):** frase tocando sozinha com o acorde e
"Ouvir de novo"; errou e acertou (revelação, pintura, "Ouvir o escrito",
tecla E); "Próxima" com a partitura da pergunta 2 e "Terminar" com `hits`
1 de 2; igual ou diferente com "Era igual." sem "Ouvir o escrito"; e
estouro do tempo (a revelação espera e o relógio para nela).
