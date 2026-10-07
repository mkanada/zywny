# R13 — Pacote `zywny_music`

**Repo:** zywny · **Depende de:** R12 (workspace) e R06 (ciclos quebrados)
· **Decisão necessária:** não

## Objetivo

O primeiro pacote do workspace: a base musical em Dart puro (nomes de
nota, transposição, conversão de alturas, a lista de tons), em
`packages/zywny_music`. Daqui em diante o compilador, e não só o teste de
camadas, impede `music` de importar o app.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): "Divisão em
  pacotes".
- [R12](R12-workspace-e-mockup.md): as notas de execução (como ficou o
  workspace).

## Contexto que você precisa

- Depois do R02, `lib/music/` tem: `note_name.dart`, `note_names.dart`,
  `transposition.dart`, `pitch_frame.dart`, `tone_choices.dart` (só
  `package:meta`) e `performance_track.dart`.
- **`performance_track.dart` não é Dart puro**: importa
  `package:flutter/foundation.dart` e `package:score_bridge` (um pacote
  Flutter). Se entrar aqui, `zywny_music` e, por tabela,
  `zywny_course_format` (que depende dele) passam a exigir o Flutter, e
  o CLI `tool/zywny_course.dart` deixa de ser só Dart. Por isso ele **não
  entra**: fica em `lib/music/` até o R15, que o leva para `zywny_audio`
  (o agendador é o principal consumidor). São 24 arquivos que o importam.
- `test/` tem os testes de `transposition`, `pitch_frame`, `note_names` e
  `tone_choices` (`grep -rl "music/" test`).

## O que fazer

1. `packages/zywny_music/` com `pubspec.yaml` (`resolution: workspace`,
   só `meta`), `lib/` com os cinco arquivos puros e `test/` com os testes
   deles. Entra na lista `workspace:` da raiz; o app depende dele por path.
2. Imports `../music/x.dart` e `package:zywny/music/x.dart` viram
   `package:zywny_music/x.dart` em `lib/`, `test/`, `tool/` e `apps/`.
3. O grupo "music" do teste de camadas passa a valer só para
   `performance_track.dart` (ou sai, se o arquivo já não importa nada do
   app).
4. `just test` passa a rodar também `packages/zywny_music` (`dart test`
   lá dentro, ou o `flutter test` da raiz com o caminho).

## Fora de escopo

`performance_track.dart` (R15). Mudar a API de qualquer classe.

## Critérios de aceite

1. `cd packages/zywny_music && dart test` verde, sem o Flutter no
   `pubspec.yaml`.
2. `just analyze` e `just test` limpos na raiz.

## Notas de execução


Feito em 2026-10-07.

- `packages/zywny_music/`: `pubspec.yaml` (`resolution: workspace`; só
  `meta`, com `test` e `lints` de dev), `analysis_options.yaml`
  (`package:lints/recommended.yaml`), `lib/` com `note_name`, `note_names`,
  `transposition`, `pitch_frame` e `tone_choices` (movidos com `git mv`, a
  API igual), `test/` com `note_names_test`, `pitch_frame_test` e
  `transposition_test` (de `flutter_test` para `package:test`). Os testes de
  `tone_choices` ficam no app: estão em `transpor_tela_test` junto com a
  tela.
- Raiz: `packages/zywny_music` na lista `workspace:` e como dependência por
  path. Imports `music/x.dart` (relativos e `package:zywny/music/…`)
  viraram `package:zywny_music/x.dart` em 36 arquivos de `lib/`, `test/`,
  `tool/` e `apps/`.
- `lib/music/` ficou só com `performance_track.dart` (R15). O grupo "music"
  do teste de camadas ficou, com um comentário: hoje só cobre esse arquivo,
  que não importa nada do app.
- `just test` roda também os pacotes: `dart test` nos de Dart puro (sem
  `sdk: flutter` no `pubspec.yaml`), `flutter test` nos outros.
- Aceite: `cd packages/zywny_music && dart test` 52 passaram, sem o Flutter
  no `pubspec.yaml`; `dart analyze` lá e `just analyze` na raiz limpos;
  `just test` na raiz verde (845 + 52).
