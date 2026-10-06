# I13 — Conferência da fase I

**Repo:** zywny · **Depende de:** I01–I12 · **Decisão necessária:** não

## Objetivo

Fechar a fase como se fecha uma fase de tela: fotos novas, fumaça na Web,
o curso inicial feito no celular por uma pessoa, e a **regra 5 do I00**:
uma lição escrita por alguém de fora, só com a especificação e o modo
rascunho.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md) inteiro.
- [U00](U00-ux-do-celular.md) "Como conferir uma mudança de tela"
  (`just telas`).
- `integration_test/telas_celular_test.dart` (o roteiro das fotos; `_wait`
  L126) e `tool/web_smoke/smoke.mjs` (a fumaça da Web).

## O que fazer

1. **`just telas`** — o roteiro ganha as telas da fase I, sem biblioteca
   instalada e com ela: cartão "Comece pelo curso inicial" (tela vazia);
   item "Cursos" na biblioteca; lista de cursos; tela do curso com uma
   lição feita, uma aberta e uma bloqueada; a lição 2 (retrato, rolada até a
   partitura e até o cartão do exercício); a tela de um exercício
   `play-notes` (paisagem) antes e depois da rodada (com o teclado falso do
   roteiro); um `name-note`; um `choice`; "Conecte o teclado". Fotos em
   `docs/telas/celular/` com os nomes no padrão das outras.
2. **Achados** — percorra as fotos com os princípios do U00 (legível no
   celular deitado, nada cobrindo a pauta, botões alcançáveis) e anote o
   que destoar das telas da biblioteca e do treino. Correção pequena: faça.
   Grande: vira passo novo (I14…) no I00.
3. **`just web-smoke`** — a fumaça abre o curso inicial, a lição 1 e um
   exercício de botões (sem MIDI no headless; o Web MIDI falso do W04, se
   der, para um `play-notes`).
4. **(manual, aparelho)** o curso inicial inteiro no celular com o
   teclado MIDI (I10 critério 5, se ainda não feito), anotando tempo por
   lição e onde travou.
5. **(manual, usuário) — a lição de fora (regra 5).** O usuário (ou alguém
   que ele chamar) escreve uma lição curta **sem olhar o código**: só
   `docs/licoes/formato-v1.md`, um editor de texto e o modo rascunho (I12)
   no desktop ou na Web. Sugestão de tema: "Mão esquerda: Dó, Fá e Sol na
   clave de fá", com um `play-notes`, um `choice` e um `play-score` curto.
   Cada tropeço (mensagem obscura, regra não escrita, exemplo que faltou)
   vira correção na especificação ou no validador, listada nas notas.
6. **Fechamento** — marque os passos no I00 e no `README.md`, atualize a
   memória do projeto e o mapa do código do README com `lib/course/`.

## Critérios de aceite

1. Fotos novas em `docs/telas/celular/` e a lista de achados nas notas.
2. `just web-smoke` verde.
3. Curso inicial feito no celular (registro do tempo e dos tropeços).
4. A lição de fora roda no rascunho sem ajuda, depois das correções; os
   tropeços e as correções, nas notas.
5. `just analyze` e `just test` limpos.

## Notas de execução

Parte automática concluída (itens 1–3); manuais 4–5 com o usuário.

**1. `just telas` verde (60 fotos).** O roteiro ganhou o 3º ato `cursos da
fase I` (`integration_test/telas_celular_test.dart`): cartão "Comece pelo
curso inicial" sem biblioteca (47), lição 1 pelo cartão (48), linha "Cursos"
(49), lista (50), tela do curso com feita/aberta/bloqueadas (51), lição 2
(52–54), porta "Conecte o teclado" (55), `name-note` (56), `choice` (57–58)
e `play-notes` antes/depois com o teclado falso (59–60, 100%). Fotos em
`docs/telas/celular/` (47–60 novas; 01–46 refeitas no mesmo giro) e seção
"Cursos da fase I" em `docs/telas/INDICE.md`. Para rodar limpo foi preciso:
garantir `hinos.zywny` na pasta privada do app antes de abrir (emulador
limpo não tem biblioteca e o 1º teste esperava ` hinos`); seed do histórico
a partir dos ids reais do plano (`_plan.stages`, 75 etapas, fases `tempoD` —
os ids fixos antigos de 51 etapas/`ritmoD` punham o teste 2 numa etapa de
ritmo tocada como espera); rolar o painel de configurações até "Trilha de
estudo"/"Cores" (cresceu com as seções Bibliotecas/Cursos); ajudantes
`_scrollTo` (rolável explícito + primeiro de duplicadas) e `_startExercise`
(abre pelo botão do próprio cartão — o título não é tocável e o "Começar"
genérico abria outro exercício).

**2. Achados (princípios do U00) e correções feitas.**
- Progresso de curso perdido no restart: `CourseProgressStore.ensureLoaded`
  existia mas ninguém chamava — a lista e a lição mostravam 0. Agora
  `_loadCourses` e `LessonScreen.initState` carregam e o `ensureLoaded`
  avisa a UI (`lib/course/course_progress.dart`, `lib/library/library_screen.dart`,
  `lib/course/ui/lesson_screen.dart`).
- `&quot;` literal na apresentação do curso (foto 51): `md.Document()` com
  `encodeHtml` padrão em `lib/course/ui/markdown_view.dart` (só display;
  teste novo `test/lesson_markdown_view_test.dart`).
- `allNotesOff()` explodia `start() não foi chamado` no `dispose` (teardown
  do teste 3): virou no-op sem áudio aberto no nativo e na Web
  (`lib/audio/native_sound_engine.dart`, `lib/audio/web_sound_engine.dart`).
- Sem correção: a porta "Conecte o teclado" só aparece se o teclado cair com
  o exercício abrindo — sem teclado o cartão já avisa "Precisa do teclado"
  com o Começar desabilitado (foto 54), comportamento aceitável; "rodada 2"
  na foto 55 (o contador conta a abertura interrompida), cosmético; foto 58
  com o spinner da partitura ainda carregando (assíncrono normal).

**3. `just web-smoke` verde (15 oks).** A fumaça abre o curso inicial sem
biblioteca, a lição 1 e (com biblioteca) a lista e a tela do curso
(`tool/web_smoke/smoke.mjs`: blocos de curso + `tapBig`, que prefere botão
e resolve semânticas duplicadas; a volta à biblioteca recarrega a página; o
hino 1 abre pelo título — as coordenadas fixas quebraram com os cartões
"Cursos"/"Comece por aqui").

**Pendente (manual).** Item 4: curso inicial inteiro no celular com teclado
MIDI (critério 5 do I10), anotando tempo por lição e travas. Item 5: a lição
de fora (regra 5 do I00) — build Web publicado e APK gerado neste passo
para o teste. Cada tropeço vira correção abaixo.

**APK (medida exata do I10).** `app-arm64-v8a-release.apk`: 46 MB (2026-09-29,
antes do I10) → 49 MB agora (`libapp.so` 5,5 → 8,3 MB: a plataforma de
cursos inteira; o curso em si tem 102 KB). O `just build-apk` sem split saiu
com 72 MB porque leva as `.so` x86_64 do emulador junto — para o celular,
use o split arm64.

**4. Curso no celular (em andamento, 2026-10-05).** Achados do usuário e
correções:
- **Queda sem aviso na lição 2** (duas partituras ABC): o leitor de ABC do
  Verovio guarda estado em globais (`ioabc.cpp:71` `abcLine`, `dataKey`…);
  dois isolates lendo ABC juntos abortavam com `std::out_of_range`. Os
  renders agora vão em fila (`lib/verovio_render.dart`); teste
  `test/verovio_render_queue_test.dart` (no PC a corrupção só gera avisos,
  não derruba — o aceite é no aparelho).
- **Saída de som ignorada no curso:** a lição e o exercício abriam sempre o
  sintetizador do app; agora seguem `AppSettings.output` (teclado MIDI
  conectado → `MidiOutSoundEngine`), como a `ScoreHomePage`
  (`_ensureCourseEngine` em `lib/library/library_screen.dart`). O
  `zywny-audio` (arquivo gravado) continua no alto-falante.
- **Orientação:** com o teclado no cabo, girar o celular a cada tela
  incomodava. Biblioteca e fluxo de cursos inteiro (lista, curso, lição,
  exercício) seguem o aparelho (`kFollowDeviceOrientations`,
  `lib/ui/orientation.dart`); só a partitura do hino trava em paisagem.
- **Barra de botões do Android cobria o fim** da lista de cursos, da tela
  do curso e da lição: fundo com `viewPaddingOf(context).bottom`
  (a lista de hinos já tinha). Conferido no aparelho.
- **Partitura do curso miúda:** no celular usa o `unit` dos hinos
  (`kPhoneUnit`, em `lessonScoreLayout`) e é ampliada 1,3× vezes o tamanho
  do texto (`lessonScorePaperPx`, `lib/course/ui/course_chrome.dart`): o
  papel fica mais estreito e o `ScoreView` estica até a caixa. A da lição
  redesenha quando o texto ou a largura mudam.
- **Aumentar as letras:** botão "Aa" no curso e na lição
  (`AppSettings.courseTextScale`, 85–200%, vale também no exercício). O
  `RichText` do markdown não lia o `MediaQuery`: agora recebe o
  `textScaler`.
- **Cabeçalho em paisagem:** celular deitado → barra de 44; no curso e na
  lição ela some ao rolar para baixo (`CourseScrollScaffold`, `SliverAppBar`
  flutuante).
- **Exercício sem mostrar o erro:** a tecla errada vira nota fantasma na
  pauta, como nos hinos (`ScoreRoundRunner.ghosts`, 1,5 s na tela); contador
  "N erros" durante a rodada e, no resultado, "N erros · seu melhor: X%" /
  "novo recorde".
- **Tela escurecendo no exercício:** `WakelockPlus` enquanto a tela do
  exercício está aberta.
- **"Ache a tecla" sem dizer o que foi tocado:** a tecla errada aparece
  com o nome por 2 s ("Você tocou Mi — tente de novo."; mesma nota em
  outra oitava no `octave: exact` é dito assim).
- Pendente: "play sem som" na lição 2 — não reproduzido pelo log; rever
  com a saída nova.
