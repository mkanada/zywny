# Revisão de código — qualidade e divisão em pacotes (06/10/2026)

Revisão do código inteiro de `lib/` e do grafo de imports entre as pastas.
As perguntas eram duas: como está a qualidade do código, e se dá para
dividir o app em projetos menores — e como.

Resumo: o código é bem testado e bem comentado, mas `lib/main.dart` virou
uma classe-deus e as pastas de `lib/` têm ciclos de dependência. Dá para
dividir em pacotes de um workspace Dart, **depois** de quebrar os ciclos.

Este documento é a especificação da **fase R**: o que está aberto e por
quê. O trabalho está dividido nos passos R01–R17 (tabela no fim), um
arquivo por passo em `docs/plano/`, no formato dos outros passos (ver
`docs/plano/README.md`, "Como executar um passo"). Quem executa um passo R
lê este documento e o arquivo do passo.

Os achados 1–4 (três bugs e os caminhos absolutos) já foram corrigidos nos
commits `685b26b` e `fac579c` e saíram daqui. A numeração dos que ficaram
foi mantida, para bater com os commits e as notas.

## O que está bom

- 85 arquivos de teste no app e 39 no `score_bridge`; a suíte do app roda
  em ~2 minutos (875 testes).
- Comentários cuidadosos, que explicam o porquê das decisões.
- Diferenças de plataforma isoladas por import condicional
  (`*_native.dart`, `*_web.dart`, `*_stub.dart`).
- `score_bridge` já é um pacote separado.
- `lib/course/format` é Dart puro (16 arquivos, nenhum import de Flutter) e
  o CLI `tool/zywny_course.dart` já o usa.

## Achados abertos

| # | Achado | Passos |
|---|--------|--------|
| 5 | `_ScoreHomePageState` com ~3650 linhas | R08–R11 |
| 6 | Posse dupla de recursos só para teste | R07 |
| 7 | Ciclo audio → settings → practice → audio | R03 |
| 8 | Ciclos practice ↔ trail, course ↔ library e os outros entre pastas | R04–R06 |
| 9 | `music/` depende de `course/` | R02 |
| 10 | Mockup dentro do pacote do app | R12 |

### 5. `main.dart` é uma classe-deus

`lib/main.dart` tem 3823 linhas; `_ScoreHomePageState` (L172) sozinha
ocupa ~3650, com ~110 métodos e ~80 `setState`. Ela cuida de gravura,
reprodução, dois motores de áudio, MIDI, monitor, trilha, treino,
transposição, loop, metrônomo, zoom e layout. Toda mudança (os Q04–Q08, por
exemplo) cai no mesmo arquivo e no mesmo estado mutável, e o ciclo de vida
de som + trilha + gravura não se testa isolado.
`lib/app/library_screen.dart`, com 1899 linhas, vai pelo mesmo caminho
(sem passo por enquanto; o R05 só a mudou de pasta).

**Como resolver:** extrair `ChangeNotifier`s, e a tela vira composição —
um passo para cada:

- `SoundOutputController` — `_appEngine`, `_midiOutEngine`, `_applyOutput`,
  som ligado/desligado, `.sf2`, monitor MIDI (R08);
- `ScoreRenderSession` — render, fila de render, transposição (R09);
- `PlaybackController` — player, agendador, contagem, loop, metrônomo (R10);
- `TrailRunner` — `_setupTrail` … `_endTrailRun` (R11).

É o que mais rende, antes de qualquer divisão em pacotes.

### 6. Posse dupla de recursos

`_settings`, `_trailStore` e `_midiDeviceManager` são criados e descartados
pela própria tela quando `widget.opened == null` — caminho que só existe
para testes de widget. Se outro chamador abrir `ScoreHomePage` sem
`OpenedPiece`, ou um teste passar `OpenedPiece` com stores próprios, eles
vazam ou são descartados duas vezes.

**Como resolver:** `OpenedPiece` obrigatório; os testes injetam fakes.

### 7. Ciclo audio → settings → practice → audio

`AppSettings` importa `practice_controller`, `practice_colors`,
`trail_stage` e `course/note_names` só por enums e constantes. Como
`audio/engine_opener` lê as configurações e `practice` usa o agendador de
`audio`, fecha-se o ciclo. `audio/latency_calibration` também importa
`midi/midi_input_service`, e `midi` importa `audio/sound_engine` — outro
ciclo, audio ↔ midi.

**Como resolver:** mover `PracticeMode` e `kDefaultRhythmToleranceMs` para
um arquivo-folha; `trail_stage.dart` e `study_mode.dart` passam a depender
dele, e não do controller. Tirar `engine_opener` de `lib/audio` (é cola do
app) e `latency_calibration` também (é treino, não motor).

### 8. Ciclos entre as outras pastas

- `practice_controller.dart` importa `trail/stage_result.dart`, que importa
  `practice/practice_report.dart`.
- `course_store`/`course_installer` usam `library_blob_store` e o envelope
  da biblioteca, e `library_screen` importa as telas de curso.
- Os painéis de `settings/` (`general_settings_panel`, `courses_section`,
  `libraries_section`) importam curso, biblioteca e MIDI, e as telas de
  curso importam `settings/app_settings` — ciclo settings ↔ course.
- `midi/transpose_check.dart` importa `settings` e `ui`; `ui/phone_chrome`
  e `ui/transpose_widgets` importam `practice` e `trail`.
- As pastas internas importam arquivos soltos da raiz de `lib/`:
  `diag_log.dart` (audio, midi, render), `native_paths.dart` (audio,
  render), `verovio_render.dart`/`verovio_resources.dart` (render) e
  `layout_options.dart` (course, settings).

**Como resolver:** `StageResult` e `WaitTally` vão para `practice/` e a
trilha fica só com a regra dos 90% (R04); as telas que juntam tudo
(`library_screen`, os painéis de configuração) saem para uma pasta `lib/app/`,
e `library` fica só com armazenamento e cripto (R05); os arquivos soltos vão
para as pastas a que pertencem (R06).

### 9. `music/` depende de `course/`

`lib/music/transposition.dart` importa `course/format/note_name.dart` e
`course/note_names.dart`; `lib/music/tone_choices.dart` e
`lib/ui/transpose_widgets.dart` também. `music` deveria ser a base (usada
por midi, practice, trail, library).

**Como resolver:** mover `note_name`/`note_names` para `music/` e fazer
`course` depender de `music`. Atenção: `course/format` também usa o
`note_name` (`course_model`, `field_reader`, `mark_parser`), então o pacote
`zywny_course_format` vai depender de `zywny_music` — por isso `zywny_music`
vem antes na divisão (R13 antes do R14).

### 10. Mockup dentro do app

`assets/mockup/*.png` (2 arquivos, 120 KB), `lib/mockup/` (6 arquivos),
`main_mockup.dart` e `lesson_debug_main.dart` (2307 linhas ao todo) moram
no pacote do app: os PNG entram em todo APK e em todo build Web, e `lib/`
mistura três pontos de entrada.

**Como resolver:** mover para `apps/zywny_mockup` com os próprios assets —
é também o primeiro passo natural do workspace (R12).

## Divisão em pacotes

Dart 3.6+ aceita pub workspaces (o app está no SDK `^3.13.3`): o
`pubspec.yaml` da raiz declara `workspace:` e cada pacote fica em
`packages/`. Pré-requisitos: os ciclos quebrados (R02–R06) e o teste de
camadas (R01) verde, para eles não voltarem. Os pacotes, nesta ordem:

1. **`zywny_music`** — `lib/music` com `note_name` e `note_names`, em Dart
   puro (R13). A `PerformanceTrack` **não** entra: importa `score_bridge`,
   que é um pacote Flutter, e arrastaria o Flutter para o formato de curso
   e para o CLI.
2. **`zywny_course_format`** — `lib/course/format`, que já é Dart puro,
   sem o `course_render_check`, que depende do Verovio (R14).
3. **`zywny_audio`** — interface `SoundEngine`, motores nativo e web,
   agendador, metrônomo e a `PerformanceTrack`, junto com
   `native/zywny_audio` e `web_src` (R15).
4. **`zywny_midi`** — serviço de entrada, gerenciador de dispositivos e
   `midi_out_sound_engine`. Seletores e painéis de tela ficam no app (R16).
5. **`zywny_library`** — envelope, pacote, blob store, store, installer e
   `piece`, sem a tela (R17).

Practice e trail ficam no app, e talvez para sempre: cada pacote a mais
custa manutenção. Também ficam no app as telas, `settings`, `main` e `ui`.

## Observação de design

A chave que cifra as bibliotecas sai da chave pública embutida no build. Na
versão Web publicada, isso faz a cifra valer só como ofuscação. Está
documentado; fica registrado aqui para não ser esquecido.

## Passos, na ordem de implementação

| Passo | O que faz | Achado | Depende de |
|-------|-----------|--------|------------|
| [R01](../plano/R01-teste-de-camadas.md) | Teste de camadas, com os desvios de hoje listados | 7–9 | — |
| [R02](../plano/R02-nomes-de-nota-em-music.md) | `note_name`/`note_names` para `music/` | 9 | R01 |
| [R03](../plano/R03-configuracoes-sem-ciclo.md) | `AppSettings` só com folhas; `engine_opener` e `latency_calibration` fora de `audio/` | 7 | R02 |
| [R04](../plano/R04-pratica-sem-trilha.md) | `StageResult`/`WaitTally` em `practice/`; a trilha fica com os 90% | 8 | R01 |
| [R05](../plano/R05-telas-do-app-em-lib-app.md) | `library_screen` e painéis de configuração em `lib/app/` | 8 | R03 |
| [R06](../plano/R06-arquivos-soltos-da-raiz.md) | Arquivos soltos da raiz de `lib/` nas suas pastas; lista de desvios vazia | 8 | R03, R04, R05 |
| [R07](../plano/R07-opened-piece-obrigatorio.md) | `OpenedPiece` obrigatório; testes com fakes | 6 | R05 |
| [R08](../plano/R08-sound-output-controller.md) | `SoundOutputController` | 5 | R07 |
| [R09](../plano/R09-score-render-session.md) | `ScoreRenderSession` | 5 | R08 |
| [R10](../plano/R10-playback-controller.md) | `PlaybackController` | 5 | R09 |
| [R11](../plano/R11-trail-runner.md) | `TrailRunner` | 5 | R10 |
| [R12](../plano/R12-workspace-e-mockup.md) | Workspace na raiz; mockup em `apps/zywny_mockup` | 10 | — |
| [R13](../plano/R13-pacote-zywny-music.md) | Pacote `zywny_music` | — | R06, R12 |
| [R14](../plano/R14-pacote-zywny-course-format.md) | Pacote `zywny_course_format` | — | R13 |
| [R15](../plano/R15-pacote-zywny-audio.md) | Pacote `zywny_audio` | — | R13 |
| [R16](../plano/R16-pacote-zywny-midi.md) | Pacote `zywny_midi` | — | R15 |
| [R17](../plano/R17-pacote-zywny-library.md) | Pacote `zywny_library` | — | R13 |

Por que esta ordem: o teste de camadas vem primeiro, para que cada ciclo
quebrado fique quebrado. R02 vem antes do R03 porque `AppSettings` importa
`NoteNaming`. Os controllers (R08–R11) vêm depois dos ciclos porque mexem
nos mesmos imports de `main.dart`, e o R07 antes deles porque deixa claro
quem é dono de cada recurso. R12–R17 podem esperar: o app não ganha nada
visível com eles, só fronteiras que o compilador confere. R04 não depende
de R02/R03 e pode ser adiantado; o R12 não depende de nada.
