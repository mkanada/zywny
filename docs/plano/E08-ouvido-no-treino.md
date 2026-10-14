# E08 — Ouvido no treino de leitura: depois de cada leitura e "só ouvido"

**Repo:** zywny · **Depende de:** E07 · **Decisão necessária:** não
(D-LEI-ONDE, D-LEI-PROGRESSO, D-LEI-TAREFA e D-LEI-SOOUVIDO no
[E00](E00-exercicios-de-ouvido.md))

## Objetivo

1. **Depois de cada leitura.** No treino de leitura à primeira vista, quando
   o aluno termina uma partitura, o botão do painel diz **"Agora, de
   ouvido"**. A pergunta seguinte é sobre **a mesma partitura**: o zywny a
   toca com uma diferença e o aluno diz em que compasso. Depois da revelação
   (E07), a próxima leitura começa direto, sem painel. A pergunta de ouvido
   **não conta** para subir de passo; o passo guarda os acertos de ouvido à
   parte, e a barra mostra "ouvido 3 de 4".
2. **Opção de desligar.** O cartão do treino na lista de cursos ganha a
   chave "Ouvido depois de cada leitura" (ligada por padrão).
3. **Só ouvido.** O mesmo cartão ganha o botão **"Só ouvido"**, que abre um
   treino **sem teclado MIDI**: rodadas de 5 perguntas "Onde mudou?", cada
   uma com uma partitura nova, nos mesmos 80 passos, com progresso próprio.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md) (segunda parte e D-LEI),
  [E05](E05-mudanca-e-frase.md) (`sightListenQuestion`) e
  [E07](E07-listen-score-tela.md) (a revelação).
- `lib/sight_reading/sight_reading_source.dart`: todo (142 linhas).
- `lib/sight_reading/sight_progress.dart`: todo (89 linhas).
- `lib/course/ui/exercise_source.dart`: todo (128 linhas).
- `lib/course/ui/exercise_screen.dart`: L97–L194 (estado, `initState`,
  `_onKeyboardChanged`), L233–L262 (`_newRound` até a rodada de
  perguntas), L404–L426 (`_finishRound`), L515–L692 (`build`,
  `_questionFlow`, `_scoreFlow`) e L967–L1071 (`_ResultPanel`).
- `lib/course/ui/courses_screen.dart`: L22–L140 (`CoursesScreen` e
  `_SightReadingCard`).
- `lib/app/library_screen.dart:1598` (onde o cartão é ligado).
- `test/sight_reading_source_test.dart`, `test/sight_reading_screen_test.dart`
  e `test/sight_reading_entry_test.dart`, como molde.

## Contexto que você precisa

- `ExerciseScreen` escolhe o corpo pela **origem**: `_isQuestion =>
  widget.source.isQuestion` (L145). O treino hoje só tem rodadas de
  partitura, e `_questionFlow` (L569) só funciona com `CourseExerciseSource`
  (precisa do `spec` e dos arquivos do curso para o `QuestionBody`).
- `_scoreFlow` mede a caixa da partitura e chama `onPaper` (L659), que
  pede uma rodada nova quando a medida muda e nada está rodando. Enquanto a
  rodada de ouvido carrega, a tela pode estar no corpo de partitura e
  `onPaper` pode pedir **outra** rodada. Por isso o `nextRound` do treino
  tem de devolver a mesma rodada de ouvido se for chamado de novo antes de
  ela terminar (veja o item 2).
- `SightReadingSource._round(step, seed)` monta a leitura com
  `generateSight(step, Random(seed))`; `sightListenQuestion(step, seed)`
  (E05) gera a **mesma** partitura com a mesma semente. Guarde `_lastStep`
  e `_lastSeed` da leitura (já guardados para o "Tocar de novo").
- `SightProgress.afterRound` volta um progresso novo, com `clean` zerado,
  ao subir de passo.

## O que fazer

### 1. A origem fica mais geral — `exercise_source.dart`

Acrescente a `ExerciseSource`:

```dart
  /// O `spec` que o `QuestionBody` usa nas rodadas de perguntas (tipo,
  /// `time-limit`); `null` se a origem não tem perguntas.
  ExerciseSpec? get questionSpec;

  /// Os arquivos que o `QuestionBody` lê (figuras da `choice`).
  CourseFiles? get questionFiles;

  /// A rodada que acabou de terminar emenda na próxima, sem painel.
  bool get chainsNextRound;

  /// O texto do botão que pede a próxima rodada no painel.
  String get nextRoundLabel;
```

`CourseExerciseSource`: `spec`, `loaded.files`, `false` e `'Outra
rodada'`.

### 2. O treino com ouvido — `sight_reading_source.dart`

- O construtor recebe `bool earOn = true`.
- Estado: `bool _earNext = false` (a próxima rodada é de ouvido) e `bool
  _lastWasEar = false` (a última rodada entregue foi de ouvido).
- `nextRound`:
  - com `_earNext`, devolva
    `QuestionRound([sightListenQuestion(_lastStep!, _lastSeed!)])` e marque
    `_lastWasEar = true`. **Não** desligue `_earNext` aqui (ver o
    "Contexto");
  - senão, a leitura de hoje, com `_lastWasEar = false`.
- `recordRound`:
  - de ouvido: `progress = progress.withEar(hit: result.hits ==
    result.total)`, `_earNext = false`, grave;
  - de leitura: como hoje, e depois `_earNext = earOn`.
- `verdict` de ouvido: `roundPassed: hit`, `streak: progress.clean`,
  `exercisePassed: false`, `reason`: `'ouvido: certo de primeira'` ou
  `'ouvido: não foi de primeira'`.
- `isQuestion` continua `false` (a primeira rodada é de leitura).
- `questionSpec`: um `ListenScoreSpec` montado na hora, com `id:
  'leitura-ouvido'`, `title: 'Onde mudou?'`, `pass: PassCriteria(accuracy:
  100)`, `line: 0`, `step: _lastStep!.name`, `change: ScoreChange.pitch`
  (não é usado: a pergunta já vem pronta), `answer: ScoreAnswer.measure`,
  `count: 1`. `questionFiles`: `MemoryCourseFiles(const {})`.
- `chainsNextRound`: `_lastWasEar`.
- `nextRoundLabel`: `_earNext ? 'Agora, de ouvido' : 'Outra rodada'`.
- `canRepeatRound`: só depois de uma leitura (`_lastSeed != null &&
  !_lastWasEar`).
- `goal`: acrescente `' · ouvido ${p.earHits} de ${p.earTotal}'` quando
  `earTotal > 0`.

### 3. O progresso — `sight_progress.dart`

- `SightProgress` ganha `earHits` e `earTotal` (padrão 0), lidos do JSON
  com 0 quando faltam (o progresso já gravado continua valendo).
- `SightProgress withEar({required bool hit})` soma 1 a `earTotal` e, se
  `hit`, a `earHits`.
- `afterRound` **mantém** os dois enquanto o passo é o mesmo (hoje ele cria
  `SightProgress(level:, sub:, clean:)` e perderia os campos: passe
  `earHits` e `earTotal` adiante, e devolva `this` na rodada com erro como
  já faz) e os **zera** ao subir de passo.
- `SightReadingStore` ganha:
  - `Future<bool> loadEarOn()` e `Future<void> saveEarOn(bool on)`, chave
    `'sight_reading_ear_on'`, padrão `true`;
  - `Future<SightProgress> loadListen()` e `Future<void>
    saveListen(SightProgress p)`, chave `'sight_listen_progress'` (o
    progresso do "só ouvido"; usa `level`, `sub` e `clean`, e ignora os
    campos de ouvido).

### 4. A tela — `exercise_screen.dart`

- `_isQuestion` passa a ser `widget.source.isQuestion || _questionRound !=
  null`.
- `_questionFlow`: troque `if (source is! CourseExerciseSource) return …`
  por `source.questionSpec` e `source.questionFiles` (sem eles, a caixa
  vazia de hoje). O `QuestionBody` recebe esses dois.
- `_finishRound`: depois do `recordRound`, se `widget.source.chainsNextRound`
  (leia **antes** do `recordRound` e guarde), não mostre o painel: chame
  `_newRound(_loadWidthPx ?? 1800)`.
- `_ResultPanel` ganha `retryLabel` (o texto de `nextRoundLabel`), usado
  nos dois `onRetry` (aprovado e não aprovado). `_questionFlow` e
  `_scoreFlow` passam `widget.source.nextRoundLabel`.

### 5. Só ouvido — `lib/sight_reading/sight_listen_source.dart` (novo)

```dart
/// O treino "só ouvido": rodadas de [kSightListenCount] perguntas "Onde
/// mudou?", sem teclado, nos 80 passos, com progresso próprio.
class SightListenSource implements ExerciseSource { … }

const kSightListenCount = 5;

/// Acertos de primeira para a rodada contar como limpa (D-LEI-SOOUVIDO).
const kSightListenClean = 4;
```

- `title`: `'Ouvido ${progress.step.name}'`; `id`: o nome do passo;
  `goal`: `'$left ${left == 1 ? 'limpa' : 'limpas'} para subir'`, como a
  leitura.
- `needsMidi: false`, `isQuestion: true`, `isRealtime: false`,
  `alwaysMetronome: false`, `startSpeed: 1.0`, `bestPercent: null`,
  `canRepeatRound: false`, `chainsNextRound: false`, `nextRoundLabel:
  'Outra rodada'`.
- `nextRound(rng)`: `QuestionRound` com 5 `sightListenQuestion(step,
  rng.nextInt(1 << 31))`.
- `verdict`: limpa com `hits >= kSightListenClean`; `reason` como na
  leitura (`'passo 3a concluído'`, `'2 de 3 rodadas limpas'`, `'menos de 4
  de primeira: a rodada não conta para subir'`).
- `recordRound`: `progress.afterRound(wasClean: …)` e `store.saveListen`.
- `questionSpec`: `ListenScoreSpec` como no item 2, com `count: 5` e
  `pass: PassCriteria(accuracy: 80)`.
- `openSightListening(context, deps, {store})`, no molde de
  `openSightReading`.

`openSightReading` passa a ler `store.loadEarOn()` e entregar `earOn` ao
`SightReadingSource`.

### 6. O cartão — `courses_screen.dart`

- `CoursesScreen` ganha `onSightListening` (como `onSightReading`) e
  `SightReadingStore? sightStore` (para os testes; `null` usa um novo).
- `_SightReadingCard` vira `StatefulWidget`. Embaixo do título e do
  subtítulo de hoje:
  - uma linha com `FilledButton` **"Ler e tocar"** (abre
    `onSightReading`) e `OutlinedButton` **"Só ouvido"** (abre
    `onSightListening`; escondido se for `null`);
  - um `SwitchListTile` compacto **"Ouvido depois de cada leitura"**, que lê
    `loadEarOn()` ao abrir e grava com `saveEarOn`.
  - O toque no cartão inteiro deixa de abrir a leitura (os botões fazem
    isso).
- `lib/app/library_screen.dart:1598`: passe também `onSightListening:
  (context) => openSightListening(context, widget.deps)`.

## Testes

1. `sight_progress_test.dart`: `withEar`; JSON antigo (sem os campos)
   lê `earHits == earTotal == 0`; subir de passo zera os dois.
2. `sight_reading_source_test.dart`:
   - leitura → `recordRound` → `nextRound` é uma `QuestionRound` de 1
     pergunta, cujo `compare.scoreBytes` é **igual** aos bytes da leitura
     anterior (mesma partitura);
   - `nextRound` duas vezes seguidas, antes do `recordRound`, devolve a
     mesma pergunta;
   - depois do `recordRound` de ouvido, `nextRound` é leitura de novo;
   - com `earOn: false`, leitura segue leitura;
   - a rodada de ouvido não muda `level`, `sub` nem `clean`; muda
     `earHits`/`earTotal`; o `goal` mostra "ouvido 1 de 1";
   - `nextRoundLabel` é "Agora, de ouvido" depois de uma leitura.
3. `sight_listen_source_test.dart` (novo): 5 perguntas por rodada; 4 de
   primeira contam como limpa e 3 não; 3 limpas sobem um passo; grava em
   `'sight_listen_progress'` e não mexe em `'sight_reading_progress'`.
4. `sight_reading_screen_test.dart`: depois de uma leitura certa, o painel
   tem "Agora, de ouvido"; tocá-lo mostra "Em que compasso soou
   diferente?"; responder certo e tocar "Próxima" leva **direto** à próxima
   leitura (sem painel).
5. `sight_reading_entry_test.dart`: o cartão tem "Ler e tocar", "Só
   ouvido" e a chave; desligar a chave grava `false`; "Só ouvido" abre a
   tela sem pedir teclado (sem `_KeyboardGate`).
6. `test/camadas_test.dart` passa.

## Fora de escopo

- Responder pela nota (E10) e ditado (E09).
- Mostrar o progresso de ouvido fora da barra (lista de passos, gráfico).
- Escolher o passo do "só ouvido" à mão.

## Critérios de aceite

1. `flutter analyze` sem avisos novos; `flutter test` inteiro passa.
2. Manual (Linux, com teclado MIDI): duas leituras seguidas, cada uma
   seguida da pergunta de ouvido sobre a mesma partitura; a barra mostra
   "ouvido N de M"; desligar a chave no cartão tira a pergunta.
3. Manual (celular, **sem** teclado): "Só ouvido" abre, toca e conta; ao
   fazer 3 rodadas limpas, o título passa ao passo seguinte.

## Notas de execução

(Preencha ao executar.)
