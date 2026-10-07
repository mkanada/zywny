# R17 — Pacote `zywny_library`

**Repo:** zywny · **Depende de:** R13 (e R05, que tirou a tela de
`lib/library/`) · **Decisão necessária:** não

## Objetivo

O armazenamento das bibliotecas instaláveis (fase B) num pacote Flutter,
`packages/zywny_library`: envelope cifrado e assinado, o zip de dentro, o
blob store, o store, o installer, a peça e as chaves de progresso. Os
cursos (`course_store`, `course_installer`) passam a usá-lo como pacote.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): "Divisão em
  pacotes" e "Observação de design".
- [B00](B00-bibliotecas-instalaveis.md): só o formato do pacote.

## Contexto que você precisa

- Depois do R05, `lib/library/` só importa `music/`. Arquivos e pacotes
  externos de cada um:
  - `library_envelope` (`cryptography`; lê a chave de
    `String.fromEnvironment('ZYWNY_LIBRARY_KEY')` L11 — o `--dart-define`
    vale para pacotes também, conferir no build);
  - `library_package` (`archive`), `library_installer` (`file_selector`),
    `library_store`, `piece_progress`, `legacy_migration`
    (`shared_preferences`), `library_blob_store` com `_native`
    (`path_provider`) e `_web` (`web`);
  - `piece`, `library_keys`, `library_sort`, `library_term_scope`
    (`InheritedWidget`, só `flutter/widgets`).
- Usuários fora da pasta: `course/course_store`, `course/course_installer`,
  `trail/trail_progress`, `trail/trail_widgets`, `settings/` (store,
  installer, `piece`, `library_keys`), `app/`, `main.dart`, e 25 arquivos de
  teste (`grep -rl package:zywny/library/ test`).
- Os scripts Python (`tool/library_crypto.py`, `tool/build_library.py`,
  `tool/build_hymn_assets.py`) geram os pacotes e não importam Dart; só
  conferir se algum comentário cita o caminho.

## O que fazer

1. `packages/zywny_library/` (`resolution: workspace`; depende de
   `zywny_music` e dos pacotes externos acima), com os arquivos e os
   testes que só falam do armazenamento (`library_envelope`,
   `library_package`, `legacy_migration`, `piece_keys`…). Testes de tela
   da biblioteca ficam no app.
2. Imports corrigidos em todo o repo.
3. O grupo "biblioteca" sai do teste de camadas. Se o teste de camadas
   ficar sem grupo nenhum, ele continua só com as regras soltas
   (`practice` ↛ `trail`, `app_settings` só folhas, ninguém importa
   `app/`).

## Fora de escopo

Mudar a cifra (ver "Observação de design" da revisão), o formato `ZYWN` ou
a migração. Pacotes de `practice`/`trail`: a revisão recomenda não fazer.

## Critérios de aceite

1. `just analyze` e `just test` limpos; os testes do pacote rodam com
   `flutter test` dentro dele.
2. `just pacote-hinos` gera o pacote e o app o instala por arquivo, como
   no B05 **(manual)**.
3. `just web-smoke` limpo (o blob store da Web).

## Notas de execução

