# I09 — Progresso por curso, `requires` e as telas do curso, da lição e do exercício

**Repo:** zywny · **Depende de:** I03, I05 · **Decisão necessária:** não
(D-LIC-ENTRADA: item "Cursos" na biblioteca + cartão na tela sem
biblioteca; D-LIC-SEM-TECLADO; D-LIC-NOMES)

## Objetivo

Depois deste passo, dá para **abrir um curso no app** e fazer os
exercícios `play-notes`: entrar pela biblioteca, ver as lições com o
estado de cada uma, ler a lição (I05), tocar num exercício, fazer rodadas
com o teclado MIDI e ver o progresso guardado. Os outros tipos entram na
mesma tela no I07 e no I08.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): "Decisões" (ENTRADA, SEM-TECLADO,
  NOMES) e o risco 4.
- `lib/trail/trail_progress.dart` (`TrailProgress` L104, `TrailProgressStore`
  L270: o modelo de progresso por id e como ele é guardado).
- `lib/library/library_screen.dart`: `_content` L344–L384 (onde entram o
  item "Cursos" e o cartão), `_noLibraryCard` L388–L426, `_continueCard`
  L521, `_lockPortrait` L160, `_open` L218.
- `lib/main.dart`: `_openAppEngine` L1817–L1843 e `_pickEngineWithSoundFont`
  (como o motor de som é aberto), `_startTrailStage` L919–L996 (a
  montagem do treino), o uso de `MidiDevicePickerButton`/`MidiStatusPill`
  (`lib/midi/midi_device_picker.dart` L13, L50).
- `lib/course/exercise/score_round_runner.dart` e `pass_check.dart` (I03).
- `lib/ui/phone_chrome.dart` (barra do título e o modo imersivo do celular
  deitado).

## Contexto que você precisa

- Celular: **lista e lição em retrato** (como a biblioteca), **exercício
  em paisagem** (como a partitura) — memória "alvo celular, paisagem".
- O `MidiDeviceManager` é um só no app (a biblioteca passa o mesmo para a
  partitura via `OpenedPiece`); a tela do exercício recebe o mesmo.
- Risco 4 do I00: **não** coloque o exercício dentro da `ScoreHomePage`.
  Extraia de `main.dart` o mínimo para abrir o motor de som e a latência
  calibrada (uma função ou classe em `lib/audio/`, usada pelos dois), e
  monte a tela do exercício por fora. Não refatore mais nada de
  `main.dart`.
- Curso aberto da memória (o curso inicial vem no I10; rascunho no I12;
  instalado no I04): a tela recebe um `LoadedCourse(course, files,
  origin: builtIn|installed|draft)` e não sabe de onde ele veio, salvo para
  a faixa de rascunho e para não guardar progresso de rascunho.

## O que fazer

1. **Progresso** — `lib/course/course_progress.dart`:
   - `ExerciseRecord(passed, streak, bestPercent, lastAt)` por id de
     exercício; `CourseProgress(courseId, records, lastLessonId)`;
     derivados: `lessonDone(lesson)` = todos os exercícios aprovados (lição
     sem exercício: feita ao ser aberta até o fim, ou ao tocar "Concluir");
     `lessonOpen(lesson)` = todo `requires` feito; contagens para a lista.
   - `CourseProgressStore` (`ChangeNotifier`) em `shared_preferences`,
     chave `course_progress:<courseId>` (JSON), como o
     `TrailProgressStore`; e `MemoryCourseProgressStore` para rascunho e
     testes. Exercício ou lição que sumiu do curso: o registro fica guardado
     e é ignorado (volta se o id voltar).
   - Aprovado uma vez, **fica aprovado**: refazer depois não tira o
     selo; a melhor % sobe, não desce.
2. **Lista de cursos** — `CoursesScreen` (retrato): um cartão por curso
   (título, autor, "3 de 10 lições", barra de progresso, "Continuar: <lição>"),
   o embutido primeiro. Nesta etapa só o embutido (I10) e, para testar, um
   curso de fixture.
3. **Tela do curso** — `CourseScreen`: a apresentação (corpo do
   `course.md`, pelo `MarkdownView` do I05) recolhível, e a lista de lições
   na ordem, cada uma com estado: feita ✓, aberta (com "2 de 3 exercícios"),
   bloqueada 🔒 com "Depois de: <títulos que faltam>". Tocar numa
   bloqueada mostra o motivo e oferece **abrir assim mesmo** (só ler — a
   trava é de sequência sugerida, não de acesso; o exercício de uma lição
   bloqueada também roda, mas o cartão avisa).
4. **Tela da lição** — `LessonScreen`: o `LessonView` do I05, com barra
   "‹ curso" e, no fim, "Próxima lição ›" quando houver. Os cartões de
   exercício mostram o estado do progresso e abrem a tela do exercício.
   Guarda `lastLessonId`.
5. **Tela do exercício** — `ExerciseScreen` (paisagem no celular):
   - Barra: título do exercício, "rodada 2", a meta ("meta 90% · 2 de 3
     seguidas"), sair.
   - Tipos MIDI sem teclado conectado: a tela mostra "Conecte o teclado" com
     o botão do U15 (`showMidiDevicePicker`) e nada mais; conectou,
     segue.
   - Corpo do `ScoreRound`: a partitura (o `ScoreController` do executor
     do I03) ocupando a largura, a contagem/metrônomo quando o modo tiver
     tempo (I08 usa), o "esperado agora" na cor das configurações.
   - Fim da rodada: um painel com o resultado na linguagem do U12
     ("11 de 12 de primeira · 91%"), o `reason` do `PassCheck`, as notas
     erradas marcadas na pauta (como no resumo do U12), e os botões
     **Outra rodada** (nova semente) / **Voltar à lição**. Aprovou o
     exercício: o painel diz e o botão principal vira "Voltar à lição".
   - Os tipos por pergunta (I07) e com tempo (I08) plugam o seu corpo aqui
     por um `switch` no tipo — deixe o ponto de extensão pronto.
6. **Entrada** (D-LIC-ENTRADA):
   - Na biblioteca com músicas: um item **"Cursos"** entre o cabeçalho e a
     busca (`_content` L350), uma linha compacta com o curso em andamento
     ("Cursos · Primeiros passos ao piano · 3 de 10") que abre a
     `CoursesScreen`.
   - Na tela sem biblioteca (`_noLibraryCard`): um segundo cartão, acima do
     de instalar, **"Comece pelo curso inicial"** ("Aprenda a ler partitura
     do zero, no seu teclado.") com o botão "Começar", que abre o curso
     direto na primeira lição aberta.
7. **Nomes das notas** nas configurações gerais
   (`lib/settings/general_settings_panel.dart`): "Nomes das notas:
   Dó-Ré-Mi / C-D-E", ligado à chave do I05.

## Fora de escopo

Os tipos por pergunta (I07) e com tempo (I08); instalar curso por arquivo
(I04); rascunho (I12); o conteúdo do curso inicial (I10).

## Critérios de aceite

1. `test/course_progress_test.dart`: aprovação e `streak` gravados e
   relidos; `lessonOpen` com `requires` de duas lições; registro órfão
   ignorado e recuperado; aprovado continua aprovado após reprovar.
2. `test/course_screens_test.dart` (widgets): a lista mostra o estado
   certo; lição bloqueada mostra o motivo e abre com "assim mesmo"; sem
   teclado, o exercício MIDI mostra "Conecte o teclado"; com o
   `FakeMidiInput`, uma rodada `play-notes` toda certa termina com o painel
   de aprovado e grava o progresso.
3. A biblioteca sem músicas mostra o cartão do curso inicial; com músicas,
   o item "Cursos" (testes em `test/library_start_test.dart` /
   `library_test.dart`).
4. **(manual)** no celular (`just run-android`): entrar pela biblioteca,
   ler uma lição em retrato, fazer uma rodada `play-notes` em paisagem com
   o teclado MIDI, voltar e ver o progresso.
5. `main.dart` não cresceu além das linhas da extração do motor de som
   (registre o antes/depois do `wc -l`).
6. `just analyze` e `just test` limpos.

## Notas de execução

(vazio)
