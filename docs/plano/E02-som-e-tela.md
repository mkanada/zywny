# E02 — `listen-note`: tocar o som e a tela da pergunta

**Repo:** zywny · **Depende de:** E01 · **Decisão necessária:** não (D-OUV
no [E00](E00-exercicios-de-ouvido.md))

## Objetivo

Na tela do exercício `listen-note`:

- a nota da pergunta (com a referência antes, se houver) **toca sozinha**
  quando a pergunta aparece;
- o botão **"Ouvir de novo"** (e as teclas espaço ou R do computador) toca
  outra vez;
- o aluno responde no teclado MIDI (`input: keyboard`) ou nos botões com o
  nome (`input: buttons`);
- sem motor de som, um aviso aparece e o exercício continua.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md) e [E01](E01-formato-e-rodada.md)
  (`SoundCue`, `Question.sound`, `ListenNoteSpec`).
- `packages/zywny_audio/lib/sound_engine.dart` (51 linhas).
- `lib/course/ui/question_body.dart`: L36–L180 (estado, `_onMidi`,
  `_answerButton`, `_afterAnswer`), L219–L290 (`build`), L360–L407
  (`_findKeyPrompt`, o molde visual) e L497–L529 (`_buttons`,
  `_buttonLabel`).
- `lib/course/ui/exercise_screen.dart`: L460–L480 (como o "ouvir o trecho"
  abre o motor) e L605–L620 (onde o `QuestionBody` é criado).
- `test/support/practice_fakes.dart` (`FakeSoundEngine`, `FakeMidiInput`).
- `test/exercise_question_screens_test.dart`: L117–L131 (`_makeDeps`) e o
  teste `'find-key: a tecla errada aparece com o nome'` (L654).

## Contexto que você precisa

- O motor de som é um `SoundEngine`, e a tela do curso o obtém com
  `widget.deps.ensureEngine()`, que devolve `null` se não houver som. Ele
  pode ser o sintetizador do app ou o teclado MIDI (saída), e o código
  daqui não precisa saber qual.
- Chame `engine.start()` **uma vez**, dentro de `try { … } on Object {}`,
  como faz `exercise_screen.dart:470`: um motor já aberto lança erro, e o
  erro pode ser ignorado.
- Os tempos de `ScheduledMidi.at` estão em segundos do relógio do motor.
  Comece em `engine.earliestScheduleSeconds`.
- Nota ligada: `0x90, altura, 90`. Nota desligada: `0x80, altura, 0`. O
  canal é o 0, o mesmo da música (o 9 é o do metrônomo).
- `_afterAnswer()` já é chamado **toda vez** que a pergunta muda: acerto, e
  também `tick()` ao estourar o `time-limit`. É o lugar certo para disparar
  o som da pergunta nova. Compare `_session.index` com o índice que já
  tocou, porque o estouro chama `_afterAnswer` duas vezes para a mesma
  pergunta (ao começar a revelação e ao acabar).

## O que fazer

### 1. Tocar os sons — `lib/course/exercise/cue_player.dart` (novo)

```dart
// E02 — toca os sons de uma pergunta (`Question.sound`) num SoundEngine.

import 'package:zywny_audio/sound_engine.dart';

import 'exercise_round.dart';

/// Silêncio entre um [SoundCue] e o seguinte.
const double kCueGapSeconds = 0.3;

/// Cala o que estiver soando e agenda [cues], um depois do outro, a partir
/// de `engine.earliestScheduleSeconds`. Devolve quanto tudo dura, em
/// segundos (0 sem sons).
double playCues(SoundEngine engine, List<SoundCue> cues, {int velocity = 90}) {
  engine.allNotesOff();
  if (cues.isEmpty) return 0;
  final start = engine.earliestScheduleSeconds;
  var at = start;
  final events = <ScheduledMidi>[];
  for (final cue in cues) {
    for (final pitch in cue.pitches) {
      events.add(ScheduledMidi(at, 0x90, pitch, velocity));
    }
    for (final pitch in cue.pitches) {
      events.add(ScheduledMidi(at + cue.seconds, 0x80, pitch, 0));
    }
    at += cue.seconds + kCueGapSeconds;
  }
  engine.schedule(events);
  return at - kCueGapSeconds - start;
}
```

### 2. O motor chega ao `QuestionBody`

a. `lib/course/ui/question_body.dart`: acrescente ao construtor o parâmetro
**opcional** `this.ensureEngine` e o campo:

```dart
  /// Abre o som (`listen-note`); `null` = sem som.
  final Future<SoundEngine?> Function()? ensureEngine;
```

(importe `package:zywny_audio/sound_engine.dart` e
`../exercise/cue_player.dart`.)

b. `lib/course/ui/exercise_screen.dart`, no `QuestionBody(` (perto de
L610): passe `ensureEngine: widget.deps.ensureEngine,`.

### 3. Estado e som em `_QuestionBodyState`

Acrescente:

```dart
  SoundEngine? _engine;
  bool _engineStarted = false;
  bool _noSound = false;
  int? _playedIndex;
  Timer? _cueTimer;

  bool get _isListen => widget.spec is ListenNoteSpec;

  /// Respostas pelo teclado MIDI: `find-key` e `listen-note` com
  /// `input: keyboard`.
  bool get _usesKeyboard =>
      _isFindKey ||
      (widget.spec is ListenNoteSpec &&
          (widget.spec as ListenNoteSpec).input == AnswerInput.keyboard);

  /// Toca a pergunta atual depois de [delay].
  void _scheduleCue(Duration delay) {
    _cueTimer?.cancel();
    _cueTimer = Timer(delay, () => unawaited(_playCurrent()));
  }

  /// Toca os sons da pergunta atual (de novo, se já tocou).
  Future<void> _playCurrent() async {
    final question = _session.current;
    if (question == null || question.sound.isEmpty) return;
    final index = _session.index;
    var engine = _engine;
    if (engine == null) {
      engine = await widget.ensureEngine?.call();
      if (!mounted) return;
      if (engine == null) {
        setState(() => _noSound = true);
        return;
      }
      _engine = engine;
    }
    if (!_engineStarted) {
      _engineStarted = true;
      try {
        await engine.start();
      } on Object {
        // Já aberto: segue.
      }
      if (!mounted) return;
    }
    // A pergunta mudou enquanto o motor abria: quem mudou já agendou.
    if (_session.index != index) return;
    playCues(engine, question.sound);
    _playedIndex = index;
    if (_noSound) setState(() => _noSound = false);
  }
```

Mudanças nos métodos existentes:

- **`initState`**: troque `if (_isFindKey) {` (a inscrição no MIDI) por
  `if (_usesKeyboard) {`. No fim, acrescente
  `if (_isListen) _scheduleCue(const Duration(milliseconds: 400));`.
- **`dispose`**: acrescente `_cueTimer?.cancel();` e
  `_engine?.allNotesOff();` (o som para ao sair).
- **`_afterAnswer`**: no ramo `else` (rodada não acabou), antes do
  `setState`, acrescente:
  ```dart
      if (_isListen && _session.index != _playedIndex) {
        // Espera a tecla do aluno soar antes da próxima pergunta.
        _scheduleCue(const Duration(milliseconds: 700));
      }
  ```
  No ramo `if (_session.done)`, acrescente `_cueTimer?.cancel();`.
- **`build`**:
  - no `onKeyEvent`, **antes** de `_keyToButton`, acrescente:
    ```dart
        if (_isListen &&
            (event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.keyR)) {
          unawaited(_playCurrent());
          return KeyEventResult.handled;
        }
    ```
  - na escolha do topo, acrescente o ramo
    `else if (_isListen) { children.add(_listenPrompt(question)); }` antes
    do `else` que chama `_scoreView`;
  - troque `if (!_isFindKey) {` (os botões) por `if (!_usesKeyboard) {`.
- **`_buttonLabel`**: troque `if (widget.spec is NameNoteSpec) {` por
  `if (widget.spec is NameNoteSpec || widget.spec is ListenNoteSpec) {`.

### 4. `_listenPrompt` (novo, ao lado de `_findKeyPrompt`)

```dart
  Widget _listenPrompt(Question question) {
    final spec = widget.spec as ListenNoteSpec;
    final naming = widget.settings.noteNaming;
    final keyboard = spec.input == AnswerInput.keyboard;
    final reference = spec.reference;
    final expected = question.expectedPitch;
    final how = keyboard
        ? (question.anyOctave
              ? 'Toque a tecla (vale qualquer oitava).'
              : 'Toque a tecla na oitava certa.')
        : 'Escolha o nome.';
    return Column(
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.hearing, size: 56, color: kInkCaption),
        const SizedBox(height: 8),
        Text(
          'Que nota é esta?',
          textAlign: TextAlign.center,
          style: serifDisplay(fontSize: 28),
        ),
        if (reference != null) ...[
          const SizedBox(height: 4),
          Text(
            'Antes soa o ${noteLabel(reference, naming, withOctave: true)}, '
            'de referência.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: kInkCaption),
          ),
        ],
        // Estouro do tempo no teclado: mostra a nota certa.
        if (_session.revealing && keyboard && expected != null) ...[
          const SizedBox(height: 8),
          Text(
            midiLabel(expected, naming, withOctave: !question.anyOctave),
            style: serifDisplay(fontSize: 48)
                .copyWith(color: widget.settings.highlightColor),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _session.revealing
              ? null
              : () => unawaited(_playCurrent()),
          icon: const Icon(Icons.volume_up),
          label: const Text('Ouvir de novo'),
        ),
        const SizedBox(height: 8),
        Text(
          how,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: kInkCaption),
        ),
        if (_noSound)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Sem som: confira a saída de som nas configurações.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kBadColor,
              ),
            ),
          ),
        if (keyboard) ...[
          const SizedBox(height: 8),
          const Icon(Icons.piano, size: 28, color: kInkCaption),
        ],
      ],
    );
  }
```

`noteLabel` e `midiLabel` já estão importados no arquivo (o
`_findKeyPrompt` e o `_buttonLabel` os usam). Se faltar import, copie o
de onde eles vêm.

## Testes

1. **`test/cue_player_test.dart`** (novo), com `FakeSoundEngine` de
   `test/support/practice_fakes.dart`:
   - `playCues(engine, [SoundCue([60]), SoundCue([64])])` com `engine.now =
     0`: `allNotesOffCalls == 1`; `scheduled` tem 4 eventos, nesta ordem:
     `(0.02, 0x90, 60)`, `(1.02, 0x80, 60)`, `(1.32, 0x90, 64)`,
     `(2.32, 0x80, 64)` (compare `at` com `closeTo(…, 1e-9)`); o valor
     devolvido é `closeTo(2.3, 1e-9)`;
   - um `SoundCue([60, 64, 67])` agenda três notas ligadas no mesmo `at`;
   - lista vazia: devolve 0, `scheduled` vazio, `allNotesOffCalls == 1`.
2. **`test/exercise_question_screens_test.dart`**, dois `testWidgets` novos
   no molde do `'find-key: a tecla errada aparece com o nome'`:
   - **teclado**: `'id: o\ntype: listen-note\ntitle: Ouça\nnotes:
     [E4]\nreference: C4\n'`, teclado conectado (`_makeDevices(connected:
     true)`), um `FakeSoundEngine engine` passado ao `_makeDeps`. Depois de
     ~20 `pump(50 ms)`: `find.text('Ouvir de novo')` aparece; nos
     `engine.scheduled`, as alturas das notas ligadas (`status == 0x90`)
     são `[60, 64]`. Toque em `'Ouvir de novo'`, dê `pump()`: as notas
     ligadas agora são `[60, 64, 60, 64]`. `midi.press(64)` e espere, como
     o teste do `name-note` espera, `'Exercício aprovado!'`.
   - **botões**: `'…notes: [C4, D4]\ninput: buttons\nchoices: [C, D]\n'`
     **sem** teclado (`connected: false`): não aparece `'Conecte o
     teclado'`; toque em `'Dó'` e depois em `'Ré'` → `'Exercício
     aprovado!'`; as notas ligadas foram `[60, 62]` (a segunda pergunta
     tocou sozinha, depois de um `pump` de 800 ms).
   - **sem som**: um `_makeDeps` cujo `ensureEngine` devolve `null` (crie a
     variante direto no teste, com `CourseScreenDeps(…)`): aparece `'Sem
     som: confira a saída de som nas configurações.'`.

## Fora de escopo

- Mudar `QuestionSession` (a regra de acerto é a mesma do `find-key`).
- Contar o `time-limit` só depois do som acabar: o curso usa limites
  folgados (20 s).
- Ecoar no som do app a tecla que o aluno tocou: o teclado já soa sozinho.

## Critérios de aceite

1. `flutter analyze` sem avisos novos.
2. `flutter test test/cue_player_test.dart test/exercise_question_screens_test.dart` passa.
3. `flutter test` passa inteiro.
4. `just telas` (as capturas do celular) sem falha nova. Se ele já falhava
   antes deste passo, anote o que falhava e compare.

## Notas de execução

Feito em 2026-10-13, sem commit. Critérios 1–3 passam; o 4 (`just telas`)
**não rodou** e o celular ficou sem o app (ver abaixo).

**Resultados dos critérios de aceite:**

1. `flutter analyze`: "No issues found!" (depois de incluir os testes novos).
2. `flutter test test/cue_player_test.dart test/exercise_question_screens_test.dart`:
   "All tests passed!" (4 testes novos em `cue_player_test.dart`; 3 em
   `exercise_question_screens_test.dart`: teclado, botões sem teclado e sem
   som).
3. `flutter test` inteiro: "All tests passed!" (+1010, ~11 pulados; no E01
   eram +1003).
4. `just telas`: **não concluído**, por dois motivos, nessa ordem:
   - A receita fixa `-d android`, e o aparelho (SM M146B, Wi-Fi) não casou com
     esse nome. Passei o id com `just telas -d 192.168.0.192:42195`.
   - Com o id, o build de perfil compilou (66,7 s), mas a instalação falhou com
     `INSTALL_FAILED_VERSION_DOWNGRADE`: o aparelho tinha
     `versionCode 2004` e o projeto é `1.0.3+4`. Em seguida o Flutter
     disse "Uninstalling old version..." e eu parei o processo ainda durante a
     instalação. Depois disso, `adb shell pm list packages br.com.kanada`
     **não lista mais o app** no aparelho. Os dados locais dele (bibliotecas
     instaladas e progresso) podem ter sido apagados junto. Não reinstalei nada.
   - As capturas em `docs/telas/celular/` não foram tocadas (o `TELAS_DIR` das
     tentativas apontou para o scratchpad). Nenhum PNG foi gerado.

**Desvios do texto:**

- Espaço e R só repetem o som fora da revelação (`!_session.revealing` no
  `onKeyEvent`). O botão "Ouvir de novo" já fica desabilitado nessa hora, e o
  atalho segue a mesma regra.
- `_listenPrompt` e `_playCurrent` seguiram o texto sem outras mudanças.

**Para o E03 e para quem roda `just telas`:**

- `just telas` **não serve** com build de número menor que o instalado: o
  Flutter desinstala o app antigo antes de instalar o novo, e isso apaga os
  dados do aluno. Antes de rodar, confira `adb shell pm list packages
  br.com.kanada` e o `versionCode` no aparelho, e use um `--build-number`
  maior que o instalado.
- A receita `telas` tem `-d android` fixo; sem o nome exato do aparelho, ele
  falha antes de compilar. Passe `-d <id>` em `ARGS`.
- O roteiro já falhava no HEAD ("não chegou a: o hino"), segundo a nota
  registrada antes deste passo. Por isso o aceite 4 não tem linha de base
  limpa para comparar.
