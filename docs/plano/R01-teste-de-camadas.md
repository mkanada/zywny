# R01 — Teste de camadas

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** não

## Objetivo

Um teste que lê os imports de `lib/` e barra os que cruzam camadas no
sentido proibido. Os desvios que existem hoje entram numa lista de
exceções; cada passo R seguinte apaga as linhas que resolveu, e nenhum
ciclo quebrado volta.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achados 7, 8 e 9.

## Contexto que você precisa

- Nenhuma ferramenta de grafo de imports está no `pubspec.yaml`; o teste lê
  os arquivos com `dart:io` e uma regex sobre `import '...'`/`export
  '...'` relativos e `package:zywny/...`. Imports condicionais (`import
  'a.dart' if (dart.library.js_interop) 'b.dart'`) têm dois alvos.
- Hoje (commit `fac579c`) a raiz de `lib/` tem 10 arquivos soltos e há
  imports entre quase todas as pastas; os grupos que viram pacote (R13–R17)
  são subconjuntos de arquivos, não pastas inteiras (`library/` tem a tela
  junto com o armazenamento, `midi/` tem seletores de tela, `audio/` tem
  `engine_opener`).

## O que fazer

1. `test/camadas_test.dart`, Dart puro (sem `testWidgets`). Grupos por
   lista de caminhos ou prefixo, cada um com o que pode importar:

   | Grupo | Arquivos | Pode importar (além de si) |
   |-------|----------|----------------------------|
   | music | `music/**` | — |
   | formato | `course/format/**` menos `course_render_check.dart` | music |
   | áudio | `audio/**` menos `engine_opener.dart`, `latency_calibration.dart`, `sound_engine_debug_panel*.dart` | music, core |
   | midi | `midi/midi_input_service.dart`, `midi_device_manager.dart`, `midi_out_sound_engine.dart`, `midi_monitor.dart`, `midi_labels.dart`, `web_midi_access*.dart` | áudio, music, core |
   | biblioteca | `library/**` menos `library_screen.dart` | music, core |
   | core | `core/**` (nasce no R06) | — |

   Mais três regras soltas: `practice/**` não importa `trail/**`;
   `settings/app_settings.dart` só importa `music/**`,
   `practice/practice_mode.dart`, `practice/practice_colors.dart` e
   `trail/trail_stage.dart`; e ninguém importa `app/**` nem `mockup/**`
   além de `main.dart`, `main_mockup.dart` e a própria pasta.
2. Uma constante `_desviosConhecidos` com cada par `origem → alvo` que
   viola as regras hoje, agrupados por comentário com o passo que os
   resolve (`// R02`, `// R03`…). O teste falha se aparecer um desvio fora
   da lista **e** se um desvio da lista não existir mais (assim a lista
   não apodrece).
3. A mensagem de falha diz o par e a regra quebrada, em português.

## Fora de escopo

Mudar qualquer import de `lib/`. Regras para as telas (`course/ui`,
`practice`, `trail`) — elas ficam no app.

## Critérios de aceite

1. `just test` verde, com o teste novo passando sobre o código de hoje.
2. Acrescentar à mão um import proibido (ex.: `music/transposition.dart`
   importando `practice/hand.dart`) faz o teste falhar com mensagem clara;
   tirar um desvio da lista sem corrigir o código também.
3. `just analyze` limpo.

## Notas de execução

2026-10-06:

- `test/camadas_test.dart` (220 linhas, 3 testes): um confere o parser
  (import condicional com dois alvos, `package:zywny/`, comentário
  ignorado), outro as regras sobre um par proibido, e o terceiro varre
  `lib/`. Os grupos são predicados sobre o caminho relativo a `lib/`, como
  na tabela acima.
- Desvios de hoje: **12**, todos esperados pela revisão — R02: 4
  (`music/tone_choices` e `music/transposition` → `course/`,
  `settings/app_settings → course/note_names`); R03: 1 (`app_settings →
  practice_controller`); R04: 1 (`practice_controller →
  trail/stage_result`); R06: 6 (`audio/` → `native_paths`/`diag_log`,
  três de `midi/` → `diag_log`). Não há linhas `// R05`: a
  `library_screen` é exceção do grupo e ninguém importa `app/`; o R05 foi
  corrigido para dizer isso. O R02 citava `ui/transpose_widgets`, que não
  tem regra; corrigido também.
- Biblioteca (sem a tela) já só importa `music/`; os ciclos course ↔
  library vêm de `course/` importando `library/`, que não tem regra (curso
  fica no app).
- Aceite 2 conferido à mão: `import '../practice/hand.dart'` em
  `music/transposition.dart` → "Import proibido: music/transposition.dart
  → practice/hand.dart — a camada music não importa outras pastas de
  lib/."; tirar uma linha da lista → o mesmo aviso para o par; linha que
  não existe no código → "Desvio resolvido: … apague a linha".
- `just test`: 878 passaram, 10 pulados. `just analyze` pegava um
  `curly_braces_in_flow_control_structures` já commitado em
  `test/course_coverage_test.dart:188` (31f08ce); corrigido com chaves,
  agora sem avisos.
