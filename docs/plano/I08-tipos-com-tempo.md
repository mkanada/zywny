# I08 — Tipos com tempo: `rhythm` e `play-score`

**Repo:** zywny · **Status:** concluído · **Depende de:** I03, I09 · **Decisão necessária:** não

## Objetivo

Os dois tipos que andam no tempo (ou, no `play-score`, também no modo
espera), com as chaves `speed`, `hand`, `measures`, `mode` e `bpm`. Fecha os
exercícios das lições 6, 7, 9 e 10.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): tabela de tipos e `pass`.
- `lib/main.dart` `_startTrailStage` L919–L996: velocidade
  (`scheduler.setSpeed`), metrônomo (`scheduler.metronomeOn`), contagem
  (`practice.start(countIn: …)` e `_playPlayerAfterCount`), cores, latência.
- `lib/practice/practice_controller.dart`: `range`/`rangeJumps` (J04/J08),
  `rhythmToleranceMs`, `mode`.
- `lib/practice/hand.dart` (L9–L25: `Hand` → pautas do aluno e do app).
- `lib/audio/metronome.dart` (`metronomeBeats`), `lib/practice/count_in_overlay.dart`.
- `score_bridge/lib/src/score_timeline.dart` (`measures`, `MeasureInfo`
  `startMs`/`endMs`, `measureIndexAt`).
- O executor e o aluno simulado do I03.

## Contexto que você precisa

- `speed` do `pass` compara com a **velocidade escolhida pelo aluno** na
  rodada (`scheduler.speed`, 1,0 = escrito). A tela do exercício ganha o
  mesmo controle de andamento da gaveta do treino (porcentagem), começando
  no `pass.speed` (ou 100%). O aluno pode treinar mais devagar — a rodada
  roda, mostra o resultado e diz "faltou andamento: 70% de 100%".
- `bpm`: muda o andamento **escrito** da rodada. Nos sorteios (`rhythm`) o
  gerador do I02 escreve o `bpm` na partitura (`<sound tempo>` /
  `<metronome>`; padrão 80). No `play-score` com `bpm`, a velocidade 1,0
  passa a ser esse `bpm` — converta para `speed` relativo ao andamento do
  arquivo e anote como o I02 viu o andamento chegar no `timemap`.
- `rhythm` toca **uma altura só** (`note`, padrão C4): é o tempo real
  (T03) de uma pauta com uma nota repetida, avaliado pelas janelas de
  `rhythmToleranceMs`. Contagem de um compasso e metrônomo **sempre**
  ligados (é o que se ensina).
- `play-score`:
  - `hand`: `right` → `Hand.direita`, `left` → `Hand.esquerda`, `both`
    (padrão) → `Hand.ambas`. Com `right`/`left` numa partitura de duas
    pautas, o app **toca a outra mão** (como no treino), porque o som de
    acompanhamento ajuda; partitura de uma pauta ignora `hand` (a pauta é
    do aluno).
  - `mode: wait` (padrão) usa o modo espera, sem contagem e sem `speed`;
    `realtime` usa o tempo real com contagem e o metrônomo das
    configurações.
  - `measures: "5-12"`: compassos **escritos** (o número da partitura,
    não a ocorrência) — converta para `range` com o `ScoreTimeline` (primeira
    ocorrência de cada um); repetições dentro do intervalo seguem o caminho
    da trilha (J01/J08: sem repetições, saltos como `rangeJumps`). Fora da
    partitura: o validador com `--render` (I12) pega; aqui, erro claro na
    tela.

## O que fazer

1. **`RhythmKind`** — `pickFigures` + `rhythmScore` (sorteio) ou `abc`.
   Com `abc`, as alturas são as escritas e são avaliadas como estão (o autor
   escreve uma nota repetida); `note` junto com `abc` é erro do validador
   (acrescente no I01 se faltar) e a especificação diz isso. `ScoreRound`
   em tempo real, `Hand` da pauta única.
2. **`PlayScoreKind`** — partitura de `abc` ou `file`, `hand`, `mode`,
   `measures`, `bpm` como acima.
3. Na `ExerciseScreen`: controle de andamento, contagem (a do U09, número
   grande na metade direita), metrônomo, o play/stop da rodada e o
   "ouvir antes" (o mesmo "ouvir o trecho" do U03, sem avaliar).
4. Aluno simulado em tempo real: toca cada evento no instante certo do
   relógio falso (com a latência calibrada = 0), com desvio opcional
   (`lateMs`) e com velocidade escolhida (`speed`).

## Fora de escopo

Tipos por pergunta (I07); trilha (fase J) dentro de um curso; transposição
(fase Q não se aplica a cursos — I00).

## Critérios de aceite

1. `test/exercise_timed_test.dart`, semente fixa, render real quando a
   `libverovio.so` existir:
   - `rhythm` sorteado: tudo no tempo → aprova; 40% fora da janela →
     reprova;
   - `play-score` `mode: realtime`, `pass.speed: 100`: aluno a 50% →
     reprova com "faltou andamento", a 100% → aprova;
   - `play-score` `hand: right` numa partitura de duas pautas: só a pauta 1
     é avaliada e o agendador toca a pauta 2 (o `FakeSoundEngine` recebe
     as notas dela);
   - `measures: "2-3"`: só os eventos desses compassos entram no total;
   - `mode: wait`: `speed` não existe e a rodada passa no modo espera.
2. **(manual)** no celular deitado com o teclado MIDI: uma rodada de
   `rhythm` e uma de `play-score` em tempo real, contagem e metrônomo
   audíveis e na hora certa.
3. `just analyze` e `just test` limpos.

## Notas de execução

Concluído. `just analyze` limpo; `just test` limpo (571 passando, 4
pulados/manuais, com a `libverovio.so` real).

**O que existe**

- `lib/course/exercise/timed_kinds.dart` — `RhythmKind` (sorteio com
  `pickFigures` + `rhythmScore` com `bpm`, ou `abc` do autor; sempre em
  tempo real, `Hand.direita`) e `PlayScoreKind` (`abc` completo ou
  `file:`, `hand`, `mode`, `measures`, `bpm`). `note` com `abc` já era
  erro do validador (I01, sem mudança).
- `lib/course/exercise/exercise_round.dart` — `ScoreRound` com
  `measures` (só estes compassos escritos), `bpm` (o 1,0 passa a ser
  esse `bpm`) e `copyWith(speed:)` (o andamento escolhido).
- `lib/course/exercise/score_round_runner.dart` — `exerciseRange`
  (compassos escritos via `TrailPath`: primeira ocorrência de cada um,
  saltos como `rangeJumps`; fora da partitura: erro claro), mão única
  ignora `hand` (pauta 1 do aluno), `bpm` convertido pela velocidade
  relativa ao primeiro `tempo` do timemap (120 sem ele), `beats` +
  metrônomo no tempo real (`rhythm` sempre ligado; `play-score`, o das
  configurações) e `start()` com um compasso de contagem no tempo real.
- `lib/course/ui/exercise_screen.dart` — controle de andamento (começa
  no `pass.speed`, 25–200%), contagem (a do U09, número grande na metade
  direita via `CountInOverlay`), play/stop (recomeça sem registrar) e
  "ouvir antes" (as duas mãos, sem avaliar, e recomeça).
- Aluno simulado (`simulated_student.dart`): `playTimedRound(runner,
  ..., {wrongEvery, lateMs})` — cada evento no instante certo do
  relógio falso (latência 0), com atraso opcional.
- Testes: `test/exercise_timed_test.dart` (critério 1, os cinco itens).

**Escolhas onde o I00/I08 não diziam**: `measures` via `TrailPath`
(números lógicos = escritos nas partituras simples; com anacruse colada
podem divergir — erro claro só se fora de 1–N); ouvir usa um agendador
à parte (só áudio, sem mover o player); velocidade clamp 25–200%.

**Manual (critério 2, pendente)**: no celular deitado com o teclado
MIDI, uma rodada de `rhythm` e uma de `play-score` em tempo real, com
contagem e metrônomo audíveis e na hora.
