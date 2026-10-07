# R06 — Arquivos soltos da raiz de `lib/`

**Repo:** zywny · **Depende de:** R03, R04, R05 · **Decisão necessária:** não

## Objetivo

Fechar o achado 8 da revisão: cada arquivo solto da raiz de `lib/` vai
para a pasta a que pertence, e as pastas internas param de importar a
raiz. No fim, a raiz só tem os pontos de entrada e a lista de desvios do
teste de camadas (R01) fica **vazia**.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 8.
- [R01](R01-teste-de-camadas.md): o que sobrou na lista de desvios.

## Contexto que você precisa

Os arquivos soltos (commit `fac579c`) e quem os importa:

| Arquivo | Importado por | Vai para |
|---------|---------------|----------|
| `diag_log.dart` (84 linhas) | `audio/soundfont_store`, `midi/midi_device_manager`, `midi/midi_input_service`, `midi/midi_out_sound_engine`, `render/score_size_log`, `main` | `lib/core/diag_log.dart` |
| `native_paths.dart` (92 linhas) | `audio/native_sound_engine`, `render/score_renderer_native`, `test/native_sound_engine_test`, `test/support/render_helper`, `tool/zywny_course.dart` (comentário em `tool/build_verovio_android.sh`) | dividido: `findAudioLibrary` → `lib/audio/audio_library_path.dart`; `verovioBridgeDir` e `findVerovioLibrary` → `lib/render/verovio_paths.dart` |
| `verovio_render.dart` | `render/score_renderer*`, 7 testes | `lib/render/` |
| `verovio_resources.dart` | `native_paths`, `render/score_renderer_native`, comentário em `tool/build_verovio_assets.sh` | `lib/render/` |
| `layout_options.dart` | `verovio_render`, `layout_panel`, `render/score_renderer`, `course/score/lesson_score`, `settings/piece_settings`, `main`, 5 testes | `lib/render/` |
| `layout_panel.dart` | `main`, `test/library_vocabulary_test` | `lib/app/` |
| `splash_screen.dart` | `main`, `test/splash_screen_test` | `lib/app/` |

Ficam na raiz: `main.dart`, `main_mockup.dart` e `lesson_debug_main.dart`
(os dois últimos saem no R12).

Mais um, fora da raiz: `midi/transpose_check.dart` é o diálogo da
conferência no teclado (Q06): importa `settings/app_settings`, `ui/theme`,
`music/` e `piano_keyboard`. É usado por `main.dart`,
`practice/shift_detector.dart` (só `signedTranspose`) e
`test/transpose_check_test.dart`. Vai para `lib/practice/`.

## O que fazer

1. Os `git mv` da tabela, a divisão de `native_paths.dart` e os imports
   corrigidos em `lib/`, `test/`, `integration_test/` e `tool/` (inclusive
   os comentários que citam o caminho antigo; o README do repo também, se
   citar).
2. `git mv lib/midi/transpose_check.dart lib/practice/`.
3. O comentário de `findAudioLibrary` que fala do K06 (motor no Windows)
   continua junto da função.
4. Apagar da lista de desvios do R01 as linhas que sobraram. Se sobrar
   alguma que este passo não resolve, **pare e conte ao usuário** em vez de
   deixar a lista com ela.

## Fora de escopo

`ui/phone_chrome.dart` e `ui/transpose_widgets.dart` importarem `practice`
e `trail`: `ui/` fica no app e não tem regra no teste. Mudar comportamento.

## Critérios de aceite

1. `ls lib/*.dart` mostra só os três pontos de entrada.
2. A lista de desvios do teste de camadas está vazia (a constante pode
   ficar, vazia, para o próximo que precisar).
3. `just analyze` e `just test` limpos; `just curso-validar validate
   assets/cursos/iniciacao --render` e `just web-smoke` também.

## Notas de execução


2026-10-06:

- `git mv` para `lib/core/diag_log.dart`; `lib/render/verovio_render.dart`,
  `verovio_resources.dart` e `layout_options.dart`;
  `lib/app/layout_panel.dart` e `splash_screen.dart`; e
  `lib/midi/transpose_check.dart` → `lib/practice/`.
- `native_paths.dart` virou `lib/render/verovio_paths.dart` (`git mv`, fica
  o histórico de `verovioBridgeDir`/`findVerovioLibrary`) e
  `findAudioLibrary` saiu, com o comentário inteiro, para
  `lib/audio/audio_library_path.dart`. O comentário não citava o K06 (só
  K02/K03/K05); a referência a `[findVerovioLibrary]` virou texto com o
  caminho, porque o arquivo de áudio não importa o de render.
- Imports: `verovio_render` reexporta `page_size.dart` como vizinho;
  `transpose_check` importa `../midi/` para `midi_input_service` e
  `piano_keyboard`; `shift_detector` o importa como vizinho. 13 testes,
  `test/support/render_helper.dart` e `tool/zywny_course.dart` corrigidos;
  `integration_test/` não citava nenhum.
- Comentários com o caminho antigo: `main.dart`, `test/layout_options_test`,
  `tool/build_verovio_assets.sh`, `tool/build_verovio_android.sh`,
  `pubspec.yaml`, `README.md`, `docs/telas/INDICE.md` e a tabela de
  `docs/plano/README.md`. Os passos antigos (K03, X01, W02…) ficaram como
  estavam: registram o caminho da época.
- `test/camadas_test.dart`: `_desviosConhecidos` ficou vazio
  (`<String>{}`); nenhum desvio sobrou fora deste passo.
- Aceite: `ls lib/*.dart` só mostra `main.dart`, `main_mockup.dart` e
  `lesson_debug_main.dart`; `just analyze` sem avisos; `just test` 878
  passaram, 10 pulados; `curso-validar ... --render` saiu com 0; `just
  web-smoke` todo `ok`.
