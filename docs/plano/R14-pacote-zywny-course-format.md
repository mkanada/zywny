# R14 — Pacote `zywny_course_format`

**Repo:** zywny · **Depende de:** R13 · **Decisão necessária:** não

## Objetivo

O formato dos cursos (I01: leitor, modelo, validador, marcas) num pacote
Dart puro, `packages/zywny_course_format`, usado pelo app e pelo CLI
`tool/zywny_course.dart`. Quem escreve curso ganha uma ferramenta que não
puxa o app inteiro.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): "Divisão em
  pacotes".
- [R13](R13-pacote-zywny-music.md): as notas de execução.

## Contexto que você precisa

- `lib/course/format/` tem 16 arquivos (15 depois do R02, que levou o
  `note_name.dart`). Pacotes externos: `meta`, `yaml`, `archive`
  (`course_files.dart`) e `web` (só `web_directory_course_files.dart`).
- Usa `NoteName` (`course_model`, `field_reader`, `mark_parser`), que
  agora está em `zywny_music`.
- **Fica no app:** `course_render_check.dart`, que importa
  `../score/abc_source.dart` e é usado pelo `validate --render` do CLI (I12)
  com o Verovio. Vai para `lib/course/course_render_check.dart`.
- `web_directory_course_files.dart` é importado só por
  `lib/course/draft/draft_folder_web.dart` (import condicional). Fica no
  pacote se o `package:web` não atrapalhar o `dart test` na VM; senão vai
  para `lib/course/draft/` e anotar.
- `tool/zywny_course.dart` importa `package:zywny/course/format/…`, o
  `course_render_check` e `package:zywny/render/verovio_paths.dart` (depois
  do R06).

## O que fazer

1. `packages/zywny_course_format/` (`resolution: workspace`; depende de
   `zywny_music`, `meta`, `yaml`, `archive`), com os arquivos e os testes
   do formato (`course_reader_test`, `abc_limits`, `mark_parser`… — `grep
   -rl "course/format" test`).
2. `course_render_check.dart` para `lib/course/`; imports corrigidos em
   todo o repo.
3. `just curso-validar` continua chamando `tool/zywny_course.dart`; o
   comando sem `--render` só precisa do pacote.
4. O grupo "formato" sai do teste de camadas (o pacote o garante).

## Fora de escopo

Mudar o formato ou as mensagens do validador.

## Critérios de aceite

1. `cd packages/zywny_course_format && dart test` verde, sem o Flutter.
2. `just curso-validar validate assets/cursos/iniciacao` e o mesmo com
   `--render` dão o resultado de antes.
3. `just analyze`, `just test` e `just web-smoke` limpos.

## Notas de execução

