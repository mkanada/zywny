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


Feito em 2026-10-07.

- `packages/zywny_course_format/`: `pubspec.yaml` (`resolution: workspace`;
  `zywny_music`, `meta`, `yaml`, `archive` e `web`; `test`/`lints` de dev),
  `lib/` com os 14 arquivos do formato (movidos com `git mv`, API igual),
  `test/course_reader_test.dart` (de `flutter_test` para `package:test`; a
  fixture `minimo` é lida de `../../test/fixtures/cursos/`, que continua do
  app porque o `course_validator_test` percorre todas).
- `web_directory_course_files.dart` ficou no pacote: o `package:web` não
  atrapalha o `dart test` na VM (nenhum teste do pacote o importa, e o
  `dart analyze` passa).
- `course_render_check.dart` foi para `lib/course/` (usa
  `score/abc_source.dart`); o CLI `tool/zywny_course.dart` o importa de lá.
- Imports corrigidos em 54 arquivos (`package:zywny/course/format/…` e os
  relativos viraram `package:zywny_course_format/…`). O grupo "formato" saiu
  do teste de camadas; o teste "o formato não importa Flutter" do
  `course_validator_test` passou a olhar `packages/zywny_course_format/lib`.
- Ficaram no app os testes que falam com o resto: `course_validator_test`
  (o `--render` usa o Verovio), `course_coverage_test` (lê
  `assets/cursos/iniciacao`, conteúdo do app) e os de tela.
- Aceite: `cd packages/zywny_course_format && dart test` 16 passaram, sem o
  Flutter; `just curso-validar validate assets/cursos/iniciacao` e o mesmo
  com `--render` saem 0 sem mensagens, e numa fixture `erro-*` sai 1 com os
  erros esperados; `just analyze` limpo; `just test` verde (829 + 16 + 52);
  `just web-smoke` limpo.
