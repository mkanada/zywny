# R05 — As telas que juntam tudo em `lib/app/`

**Repo:** zywny · **Depende de:** R03 · **Decisão necessária:** não

## Objetivo

Quebrar os ciclos course ↔ library e course ↔ settings (achado 8 da
revisão). As telas que juntam várias áreas — a biblioteca e o painel de
configurações gerais — saem das pastas de armazenamento e vão para uma
pasta nova, `lib/app/`, no topo. `lib/library/` fica só com armazenamento,
formato e cripto; `lib/settings/` fica com o modelo das configurações.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 8.
- [R01](R01-teste-de-camadas.md): as linhas `// R05` e a regra de `app/**`.

## Contexto que você precisa

- `lib/library/library_screen.dart` (1899 linhas) é o único arquivo de
  `library/` que importa `course/` (11 arquivos), `audio/`, `midi/`,
  `settings/`, `trail/` e `ui/`. O resto de `library/` só importa `music/`.
  Ele também declara `OpenedPiece` (L44), que `main.dart` usa.
- `course/course_store.dart` e `course/course_installer.dart` usam o
  envelope, o blob store, o store e o installer da biblioteca: esse sentido
  (curso → armazenamento da biblioteca) é o certo e fica.
- Em `lib/settings/`, os painéis `general_settings_panel.dart`,
  `courses_section.dart` e `libraries_section.dart` importam `course/`
  (store, installer, rascunho), `library/` (store, installer) e `midi/`
  (gerenciador, seletor). As telas de curso (`course/ui/course_chrome`,
  `course_flow`, `question_body`) importam `settings/app_settings.dart`.
  Daí o ciclo settings ↔ course.
- Quem importa `library_screen.dart`: `main.dart` e 14 testes (`grep -rl
  library/library_screen.dart test integration_test`). Quem importa
  `general_settings_panel.dart`: `main.dart`, `library_screen.dart`,
  `test/settings_test.dart`, `test/settings_vocabulary_test.dart`;
  `courses_section.dart` também é importado por
  `test/course_install_test.dart`.

## O que fazer

1. `git mv lib/library/library_screen.dart lib/app/library_screen.dart`.
   `OpenedPiece` vai junto (não precisa de arquivo próprio agora; o R07
   mexe nele).
2. `git mv` de `general_settings_panel.dart`, `courses_section.dart` e
   `libraries_section.dart` para `lib/app/`. Ficam em `lib/settings/`:
   `app_settings.dart`, `piece_settings.dart`,
   `effective_transposition.dart` e `color_picker.dart` (este é um widget
   pequeno, sem import do app).
3. Corrigir os imports em `lib/`, `test/` e `integration_test/`.
4. Tirar `library/library_screen.dart` da exceção do grupo biblioteca no
   teste do R01, que passa a cobrir `library/` inteira. (Não há linhas
   `// R05` na lista de desvios: a tela é exceção do grupo, e nada importa
   `app/` hoje.)

## Fora de escopo

Dividir `library_screen.dart` em arquivos menores (fica anotado na
revisão, sem passo). Mudar a interface de qualquer tela.

## Critérios de aceite

1. `grep -rn "course/\|audio/\|midi/\|settings/\|trail/" lib/library` não
   acha nada.
2. `grep -rln "course/" lib/settings` não acha nada.
3. `just analyze`, `just test` e `just telas` limpos (as fotos não mudam).

## Notas de execução


2026-10-06:

- `git mv` de `library/library_screen.dart` e de `settings/`
  `general_settings_panel.dart`, `courses_section.dart` e
  `libraries_section.dart` para `lib/app/`. `OpenedPiece` foi junto.
- Os imports `../outra_pasta/...` dos quatro arquivos não mudaram (mesma
  profundidade); só os da pasta antiga viraram `../library/...` e
  `../settings/...`, e `library_screen` passou a importar
  `general_settings_panel.dart` como vizinho.
- `main.dart`, 15 testes e `integration_test/telas_celular_test.dart`
  corrigidos; `test/library_test.dart` também lê o fonte por caminho
  (`File('lib/app/library_screen.dart')`).
- `test/camadas_test.dart`: o grupo biblioteca cobre `library/` inteira.
  `_desviosConhecidos` não mudou (5 linhas, todas R06).
- Caminhos atualizados em `docs/telas/INDICE.md`, `docs/plano/README.md`
  (tabela de onde fica cada coisa) e no achado 5 da revisão.
- Aceite: os dois `grep` vazios; `just analyze` sem avisos; `just test`
  878 passaram, 10 pulados. `just telas` **não rodou**: o celular aparece
  no `adb mdns services`, mas o `adb connect` deu "Connection refused".
  Como a mudança só move arquivos, as fotos não devem mudar; rodar quando
  o celular estiver conectado.
