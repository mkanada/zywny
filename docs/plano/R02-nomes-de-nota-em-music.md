# R02 — Nomes de nota em `music/`

**Repo:** zywny · **Depende de:** R01 · **Decisão necessária:** não

## Objetivo

`music/` passa a ser a base de verdade: não importa mais nada de `course/`.
O nome de nota (`NoteName`) e a grafia (`NoteNaming`, `kSharpSign`,
`kFlatSign`) mudam para `lib/music/`, e `course` passa a depender de
`music`. Achado 9 da revisão.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 9.
- [R01](R01-teste-de-camadas.md): as linhas `// R02` da lista de desvios.

## Contexto que você precisa

- `lib/course/format/note_name.dart` (140 linhas, só importa
  `package:meta`) e `lib/course/note_names.dart` (93 linhas, só importa
  `format/note_name.dart`) são folhas — mover não arrasta nada.
- Quem importa um dos dois (commit `fac579c`, 24 arquivos):
  - `lib/music/`: `transposition.dart`, `tone_choices.dart`;
  - `lib/course/`: `format/course_model.dart`, `format/field_reader.dart`,
    `format/mark_parser.dart`, `exercise/exercise_kind.dart`,
    `score/round_score.dart`, `ui/keyboard_mark_view.dart`,
    `ui/lesson_view.dart`, `ui/question_body.dart`;
  - outros de `lib/`: `midi/piano_keyboard.dart`, `midi/transpose_check.dart`,
    `settings/app_settings.dart`, `settings/general_settings_panel.dart`,
    `ui/transpose_widgets.dart`, `lesson_debug_main.dart`;
  - testes: `course_reader_test`, `exercise_timed_test`,
    `lesson_score_timing_manual_test`, `note_names_test`,
    `round_score_test`, `transposition_test`, e
    `integration_test/lesson_score_timing_test.dart`.
- `course/format` usa o `note_name` por dentro: por isso o pacote
  `zywny_course_format` (R14) vai depender de `zywny_music` (R13).

## O que fazer

1. `git mv lib/course/format/note_name.dart lib/music/note_name.dart` e
   `git mv lib/course/note_names.dart lib/music/note_names.dart`.
2. Corrigir os imports da lista acima. Sem `export` de compatibilidade no
   lugar antigo: o objetivo é que `course/` não seja mais caminho para isso.
3. `test/note_names_test.dart` não muda de nome; se houver teste do
   `note_name` com caminho no nome do arquivo, idem.
4. Apagar da lista de desvios do R01 as linhas `// R02` (agora
   `music/** → course/**` e `settings/app_settings → course/note_names`;
   `ui/` não tem regra no teste, então `ui/transpose_widgets` não aparece
   lá).

## Fora de escopo

Renomear tipos, mudar comportamento, mexer em `transposition.dart` além do
import.

## Critérios de aceite

1. `grep -rn "course/" lib/music` não acha nada.
2. `just analyze` e `just test` limpos; o teste de camadas passa sem as
   linhas `// R02`.
3. `just curso-validar validate assets/cursos/iniciacao` continua sem
   erros.

## Notas de execução

2026-10-06:

- Os dois `git mv` e 25 imports trocados (17 em `lib/`, 6 em `test/`, 1 em
  `integration_test/`, mais o `note_names.dart` → `note_name.dart` dentro
  de `music/`). A lista do contexto bateu com o código; nenhum outro
  arquivo usava os caminhos antigos (nem `tool/`).
- `course/format` agora importa `../../music/note_name.dart`
  (`course_model`, `field_reader`, `mark_parser`) — é a dependência que o
  R14 vai transformar em `zywny_course_format → zywny_music`.
- As 4 linhas `// R02` saíram de `_desviosConhecidos`; sobram 8 (R03: 1,
  R04: 1, R06: 6).
- Os documentos de passos já concluídos (I01, I05, I07) e a revisão ainda
  citam `lib/course/...note_name(s).dart`: ficaram como registro histórico.
- Aceite: `grep -rn "course/" lib/music` vazio; `just analyze` sem avisos;
  `just test` 878 passaram, 10 pulados; `just curso-validar validate
  assets/cursos/iniciacao` sai com 0.

