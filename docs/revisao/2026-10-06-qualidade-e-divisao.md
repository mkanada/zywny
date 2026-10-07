# Revisão de código — qualidade e divisão em pacotes (06/10/2026)

Revisão do código inteiro de `lib/` e do grafo de imports entre as pastas,
feita sobre o commit `0498706` (Q04–Q08). As perguntas eram duas: como está
a qualidade do código, e se dá para dividir o app em projetos menores — e
como.

Resumo: o código é bem testado e bem comentado, mas `lib/main.dart` virou
uma classe-deus e as pastas de `lib/` têm ciclos de dependência. Dá para
dividir em pacotes de um workspace Dart, **depois** de quebrar os ciclos.
Antes de qualquer pacote, rende mais quebrar `main.dart` em controllers.

## Situação dos achados

| # | Achado | Tipo | Situação |
|---|--------|------|----------|
| 1 | Gravura sem páginas quebra o `setState` de `_renderAndShow` | bug | corrigido |
| 2 | `findAudioLibrary` sem proteção de plataforma | bug | corrigido |
| 3 | Opções do Verovio montadas em dois lugares | bug latente | corrigido |
| 4 | Caminhos absolutos para `/home/mauricio/...` | portabilidade | corrigido |
| 5 | `_ScoreHomePageState` com ~3650 linhas | estrutura | aberto |
| 6 | Posse dupla de recursos só para teste | estrutura | aberto |
| 7 | Ciclo audio → settings → practice → audio | estrutura | aberto |
| 8 | Ciclos practice ↔ trail e course ↔ library | estrutura | aberto |
| 9 | `music/` depende de `course/` | estrutura | aberto |
| 10 | Mockup dentro do pacote do app | estrutura | aberto |

## O que está bom

- 85 arquivos de teste no app e 39 no `score_bridge`; a suíte do app roda
  em ~2 minutos (875 testes).
- Comentários cuidadosos, que explicam o porquê das decisões.
- Diferenças de plataforma isoladas por import condicional
  (`*_native.dart`, `*_web.dart`, `*_stub.dart`).
- `score_bridge` já é um pacote separado.
- `lib/course/format` é Dart puro (16 arquivos, nenhum import de Flutter) e
  o CLI `tool/zywny_course.dart` já o usa.

## Bugs (corrigidos nesta revisão)

### 1. Gravura sem páginas

`_renderAndShow` (`lib/main.dart`) fazia
`_pageIndex.clamp(0, document.pages.length - 1)` dentro do `setState` que
troca a partitura. Com um `.vsb` sem páginas (o parser do `score_bridge`
aceita lista vazia), o `clamp(0, -1)` lançava `ArgumentError` no meio do
`setState`: `_player` e `_track` já eram do documento novo, `_document`
ainda era o antigo, e o player antigo já tinha sido descartado.

**Correção:** o documento vazio é recusado logo depois do `await`, antes de
desmontar o player. O erro cai no `catch` com o estado intacto: na primeira
gravação a tela mostra "Não deu para abrir… a gravura veio sem páginas";
numa regravação a partitura anterior continua inteira. Testes em
`test/transpor_tela_test.dart`.

O segundo `clamp` (o `initialPage` do `ScoreView`) já era protegido por
`hasPage`.

### 2. `findAudioLibrary` sem proteção de plataforma

`findVerovioLibrary` recusava plataformas fora de Linux/Android;
`findAudioLibrary` não, e procurava `.so` no Windows e no macOS, terminando
num `StateError` que mandava rodar `tool/build_audio_linux.sh`.

**Correção:** a mesma proteção de plataforma de `findVerovioLibrary`
(`lib/native_paths.dart`). Quando o K06 (motor no Windows) for feito, essa
função ganha o caso da `.dll`.

### 3. Opções do Verovio em dois lugares

`_renderAndShow` remontava à mão o mapa de opções (layout, `transpose`,
`vsbDebug`) que `_effectiveOptions()` já montava para o painel de cópia.
Uma opção nova posta só num dos lugares chegaria ao painel e não ao
Verovio, ou o contrário.

**Correção:** `_renderAndShow` usa `_effectiveOptions()` e só tira a
largura e a altura da página, que vão à parte no `ScoreRenderRequest`.

## Portabilidade (corrigido)

### 4. Caminhos absolutos

A dependência `verovio` do `pubspec.yaml` aponta para
`/home/mauricio/rust_projects/verovio_flutter_bridge/...`, e o mesmo
caminho aparece em:

- `lib/native_paths.dart` (fallback de desenvolvimento da `libverovio.so`);
- `test/support/render_helper.dart`;
- `tool/build_verovio_linux.sh`, `build_verovio_android.sh`,
  `build_verovio_web.sh`, `build_verovio_assets.sh`,
  `build_mockup_images.sh`, `build_course_media.sh`,
  `build_hymn_assets.py`, `medir_transposicao.py` e `zywny_course.dart`.

Em qualquer outra máquina, em CI ou para outro usuário, `flutter pub get`
falha antes de compilar. Isso também impede montar o workspace da divisão
abaixo.

**Como resolver:** trazer o bridge para dentro do repositório (git
submodule ou subtree, como já foi feito com `score_bridge/`) e usar caminho
relativo; ou um caminho relativo vizinho (`../verovio_flutter_bridge`) mais
uma variável de ambiente (`VEROVIO_BRIDGE`) lida pelos scripts, num lugar
só.

**Correção (feita):** a segunda opção. O bridge e o Hymn_Grabber são
procurados ao lado do repositório (`../verovio_flutter_bridge`,
`../Hymn_Grabber`; um symlink basta — ver "Repositórios vizinhos" no
README). `VEROVIO_BRIDGE` e `HYMN_GRABBER` sobrescrevem, cada um lido num
lugar só por linguagem: `tool/verovio_bridge.sh` (scripts),
`verovioBridgeDir()` em `lib/native_paths.dart` (app e CLI),
`test/support/render_helper.dart` (testes) e `linux/CMakeLists.txt`. O
`pubspec.yaml` e o `pubspec.lock` usam o caminho relativo. A lista acima
estava incompleta: `linux/CMakeLists.txt`, o README e mais seis testes
também tinham o caminho, e o `CHROME_BIN` padrão apontava para
`/home/mauricio/bin`.

## Estrutura (aberto)

### 5. `main.dart` é uma classe-deus

`lib/main.dart` tem ~3800 linhas; `_ScoreHomePageState` sozinha ocupa
~3650, com ~110 métodos e ~80 `setState`. Ela cuida de gravura, reprodução,
dois motores de áudio, MIDI, monitor, trilha, treino, transposição, loop,
metrônomo, zoom e layout. Toda mudança (os Q04–Q08, por exemplo) cai no
mesmo arquivo e no mesmo estado mutável, e o ciclo de vida de som + trilha
+ gravura não se testa isolado. `lib/library/library_screen.dart`, com 1899
linhas, vai pelo mesmo caminho.

**Como resolver:** extrair `ChangeNotifier`s, e a tela vira composição:

- `ScoreRenderSession` — render, fila de render, transposição;
- `PlaybackController` — player, agendador, contagem, loop;
- `SoundOutputController` — `_appEngine`, `_midiOutEngine`, `_applyOutput`;
- `TrailRunner` — `_startTrailStage` … `_endTrailRun`.

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
`audio`, fecha-se o ciclo.

**Como resolver:** mover `PracticeMode`, `kDefaultRhythmToleranceMs`, as
cores padrão, `TrailPhase`/`kTrail*` e `NoteNaming` para arquivos-folha
sem dependências; tirar `engine_opener` de `lib/audio` (é cola do app).

### 8. Ciclos practice ↔ trail e course ↔ library

- `practice_controller.dart` importa `trail/stage_result.dart`, que importa
  `practice/practice_report.dart`.
- `course_store`/`course_installer` usam `library_blob_store` e o envelope
  da biblioteca, e `library_screen` importa as telas de curso.

**Como resolver:** o controller emite `PracticeReport` e a trilha converte
em `StageResult` do lado dela; `library_screen` sai de `lib/library` para
uma camada de "home" do app, e `library` fica só com armazenamento e
cripto.

Ainda há os ciclos audio ↔ midi e as pastas internas (audio, midi, render)
importando arquivos soltos da raiz de `lib/`.

### 9. `music/` depende de `course/`

`lib/music/transposition.dart` importa `course/format/note_name.dart` e
`course/note_names.dart`; `lib/ui/transpose_widgets.dart` também. `music`
deveria ser a base (usada por midi, practice, trail, library).

**Como resolver:** mover `note_name`/`note_names` para `music/` e fazer
`course` depender de `music`.

### 10. Mockup dentro do app

`assets/mockup/*.png`, `lib/mockup/` (~1600 linhas), `main_mockup.dart` e
`lesson_debug_main.dart` moram no pacote do app: os PNG entram em todo APK
e em todo build Web, e `lib/` mistura três pontos de entrada.

**Como resolver:** mover para `apps/zywny_mockup` (ou `example/`) com os
próprios assets — é também o primeiro passo natural do workspace.

## Divisão em pacotes

Dart 3.6+ aceita pub workspaces: o `pubspec.yaml` da raiz declara
`workspace:` e cada pacote fica em `packages/`. Ordem sugerida:

0. **Pré-requisitos:** resolver o achado 4 (caminhos absolutos) e quebrar
   os ciclos (7–9). Criar um teste que barre imports proibidos entre
   camadas, para eles não voltarem.
1. **`zywny_course_format`** — só mover `lib/course/format`, que já é Dart
   puro. Usado pelo app e por `tool/zywny_course.dart`. O
   `course_render_check`, que depende do Verovio, fica fora.
2. **`zywny_music`** — `lib/music` mais `note_name` e `note_names`.
3. **`zywny_audio`** — interface `SoundEngine`, motores nativo e web,
   agendador, metrônomo, junto com `native/zywny_audio` e `web_src`. O
   `engine_opener` fica no app (depende das configurações e do MIDI).
4. **`zywny_midi`** — serviço de entrada, gerenciador de dispositivos e
   `midi_out_sound_engine`. Seletores e painéis de tela ficam no app.
5. **`zywny_library`** — envelope, pacote, blob store, store, installer e
   `piece`, sem a tela.
6. **practice e trail** — só depois dos ciclos quebrados, e talvez nunca:
   cada pacote a mais custa manutenção.

Fica no app: as telas, `settings`, `main` e `ui`.

## Observação de design

A chave que cifra as bibliotecas sai da chave pública embutida no build. Na
versão Web publicada, isso faz a cifra valer só como ofuscação. Está
documentado; fica registrado aqui para não ser esquecido.

## Ordem sugerida para o que está aberto

1. ~~Caminhos absolutos (4).~~ Feito.
2. Ciclos (7, 8, 9) e o teste de camadas.
3. Quebrar `main.dart` em controllers (5) e tornar `OpenedPiece`
   obrigatório (6).
4. Mockup para fora (10) e, então, os pacotes do workspace.
