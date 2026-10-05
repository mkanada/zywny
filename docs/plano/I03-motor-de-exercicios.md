# I03 — Motor de exercícios: rodada, critérios e `play-notes`

**Repo:** zywny · **Depende de:** I02 · **Decisão necessária:** não

## Objetivo

O núcleo que todo tipo de exercício usa, sem tela: gerar a **rodada**,
rodá-la contra uma entrada (MIDI ou botões), produzir o **resultado da
rodada** e decidir, com o `pass` do autor, se o exercício foi **aprovado**
(inclusive "N rodadas seguidas"). O primeiro tipo que roda de ponta a ponta
é `play-notes` em modo espera, testado por um **aluno simulado** com o
teclado MIDI falso dos testes.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): tipos de exercício, `pass`,
  "O curso inicial como teste", regra 3.
- `lib/practice/practice_controller.dart`: construtor L40–L98 (`range`,
  `onRangeDone`, `mode`, `hand`), `stageResult` L428, `start` L244,
  `dispose` L801.
- `lib/trail/stage_result.dart` (96 linhas: `StageResult`, `WaitTally`;
  **não** use `passed`/`kTrailPassAccuracy` — o limiar aqui é o do autor).
- `lib/main.dart` `_startTrailStage` L919–L996: como a trilha monta um
  `PracticeController` de passagem única (é o modelo a seguir, sem tela).
- `test/practice_controller_test.dart` L32–L130 e ~L150–L190:
  `FakeSoundEngine`, `FakeMidiInput`, `ScoreAudioScheduler(autoTick:
  false)`, como o tempo anda num teste (`engine.now += …`).

## Contexto que você precisa

- O modo espera da passagem única já devolve `StageResult` com `hits` =
  passos tocados **de primeira** e `total` = passos concluídos (J02/J04).
  Isso é exatamente a `accuracy` do I00: não reescreva a contagem.
- Rodar um exercício de partitura = renderizar os bytes do I02
  (`createScoreRenderer()`), `PerformanceTrack.fromDocument`, um
  `ScoreController(document: doc)`, um `ScoreAudioScheduler` e um
  `PracticeController` com `range` = a partitura inteira (ou os compassos
  do `measures`, no I08). No teste, o render real pela `libverovio.so` é
  aceitável (pula se não existir); para os testes rápidos, monte o
  `PerformanceTrack.fromEvents` à mão.
- `play-notes` usa `Hand.ambas` se a clave for `grand` e a mão da única
  pauta caso contrário (pauta 1 = `Hand.direita` — o `Hand` só escolhe
  pautas, não importa qual mão a pessoa usa de fato). O app **não** toca a
  outra mão.

## O que fazer

1. **`lib/course/exercise/exercise_round.dart`** — a rodada e o resultado:
   - `sealed class ExerciseRound` com `ScoreRound` (bytes da partitura +
     modo + mão + andamento + compassos) e `QuestionRound` (lista de
     perguntas — preenchida no I07).
   - `RoundResult(hits, total, speed)`: `percent` = `hits * 100 ~/ total`
     (como o `StageResult.percent`), `total == 0` conta como 100 (nada a
     tocar).
2. **`lib/course/exercise/exercise_kind.dart`** — a interface do tipo:
   `ExerciseRound generate(ExerciseSpec spec, CourseFiles files, Random
   rng)` (assíncrona se precisar ler `file:`). Um registro
   `exerciseKinds[ExerciseType]`; tipo sem implementação ainda lança
   `UnimplementedError` (o I07 e o I08 completam). Implemente aqui o
   `PlayNotesKind`: `pickNotes` + `notesScore` do I02, modo espera.
3. **`lib/course/exercise/pass_check.dart`** — `PassCheck.evaluate(spec,
   List<RoundResult> history)` → `{roundPassed, streak, exercisePassed,
   reason}`: a rodada passa se `percent ≥ accuracy` **e** (quando `speed`
   vale) `speed*100 ≥ pass.speed`; `streak` = rodadas aprovadas seguidas no
   fim do histórico; aprovado quando `streak ≥ rounds`. `reason` em
   português pronta para a tela ("faltou andamento: 50% de 100%",
   "82% de 90%", "2 de 3 rodadas seguidas").
4. **`lib/course/exercise/score_round_runner.dart`** — o executor sem tela
   de uma `ScoreRound`: recebe `MidiInputService`, `SoundEngine`,
   `ScoreRenderer`, configurações de treino (latência calibrada, tolerância
   — os mesmos campos que o `_startTrailStage` lê de `AppSettings`) e
   devolve `Future<RoundResult>` quando o `onRangeDone` disparar; `cancel()`
   para abandonar (sem resultado). Expõe o `ScoreController` e o
   `VsbDocument` para a tela do I09 desenhar. Sem `BuildContext`.
   - Cuidado do `_startTrailStage` L957–L963: o `onRangeDone` do modo
     espera dispara **dentro** de uma notificação; encerre num
     `scheduleMicrotask`.
5. **Próxima rodada adiantada**: se o I02 mediu render > 300 ms no
   celular, o executor gera e renderiza a rodada seguinte enquanto a atual
   roda (`prefetch`). Senão, anote e não faça.
6. **Aluno simulado** — `test/support/simulated_student.dart`:
   `playScoreRound(runner, midi, {wrongEvery, speed})` lê os eventos da
   pauta do aluno no `PerformanceTrack` e aperta/solta as teclas no
   `FakeMidiInput` (modo espera: em ordem, avançando o relógio; com
   `wrongEvery: n`, uma tecla errada antes de cada n-ésimo passo).
7. `test/exercise_play_notes_test.dart` com o curso `minimo/` do I01 (e, à
   medida que existirem, as lições 2–5 do curso inicial): semente fixa;
   tudo certo → aprova; um erro a cada 5 de 12 → 75% < 90% → reprova com
   `reason`; `rounds: 3` → aprova só na terceira seguida, e uma reprovada
   no meio zera o `streak`.

## Fora de escopo

Tela (I09), tipos por pergunta (I07), tempo real/`rhythm`/`play-score`
(I08), progresso guardado (I09).

## Critérios de aceite

1. Os testes do item 7 passam, com o render real quando a `libverovio.so`
   existir (registre se rodou com ou sem).
2. `PassCheck` com testes de mesa: limiar exato (90% de 90 passa, 89 não),
   `total == 0`, `speed` ignorado onde não vale, `streak` zerando.
3. Nenhum arquivo de `lib/course/exercise/` importa `main.dart` nem
   widgets (o executor recebe tudo por parâmetro).
4. `just analyze` e `just test` limpos.

## Notas de execução

(vazio)
