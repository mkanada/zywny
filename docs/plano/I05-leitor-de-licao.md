# I05 — Leitor de lição: markdown seguro e as marcas de conteúdo

**Repo:** zywny · **Depende de:** I01, I02 · **Decisão necessária:** não
(D-LIC-VIDEO: só link; D-LIC-NOMES: Dó-Ré-Mi com opção C-D-E)

## Objetivo

Um widget `LessonView(lesson, files)` que desenha uma lição inteira numa
coluna rolável, no celular em **retrato** (como a biblioteca), na Web e no
desktop: o texto markdown com o visual do app, imagens da pasta, partituras
pequenas com toque para ouvir, o teclado desenhado, o tocador de áudio e o
cartão de vídeo. Os exercícios aparecem como **cartões** (título, tipo,
meta) — o que acontece ao tocar neles é do I09.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): "Regras do formato" e "Marcas de
  conteúdo".
- `lib/course/format/course_model.dart` (I01: `LessonBlock` e as marcas).
- `lib/course/score/lesson_score.dart` e `lessonScoreOptions` (I02).
- `lib/midi/piano_keyboard.dart` (93 linhas, `PianoKeyboardPainter`).
- `lib/ui/theme.dart` (`buildAppTheme` L87, `serifDisplay`, as cores
  `kInk*`, `kSurface`, `kBorderSoft`) e `lib/ui/widgets.dart`.
- `lib/settings/app_settings.dart` L32–L60 e `load` L246 (padrão das
  chaves).

## Contexto que você precisa

- Use o pacote **`markdown`** (dart-lang, Dart puro) para o AST e desenhe
  os widgets aqui. **Não** use `flutter_markdown` (descontinuado pelo time
  do Flutter em 2025; confira no pub.dev na hora e anote) nem nada que
  interprete HTML. Nós `html`/`inlineHtml` viram texto literal.
- Elementos suportados (I00): títulos `#`–`###`, parágrafo, `**negrito**`,
  `*itálico*`, listas (com aninhamento de 1 nível), citação, `---`, `código`
  em linha, links, imagens. Bloco de código comum (não `zywny-`) aparece em
  fonte monoespaçada, sem destaque de sintaxe.
- Links: `url_launcher` (dependência nova), abre **fora** do app, só
  `https://` (o validador já garante; aqui, recuse em silêncio o resto).
  Nada é buscado na rede sem toque.
- Imagens: bytes da `CourseFiles` (`Image.memory`), largura máxima = a da
  coluna, legenda = o texto alternativo, abaixo, em `kInkCaption`.
- Áudio de arquivo: **não existe** no app hoje (o motor do K é
  sintetizador). Escolha o pacote medindo nas **quatro** plataformas — Linux,
  Android, Web e (quando houver) Windows — tocando `.ogg` e `.mp3` **a
  partir de bytes** (na Web não há arquivo). Candidato: `audioplayers`
  (`BytesSource`; Linux via GStreamer — confira se o Pop!_OS do usuário toca
  sem instalar nada). Registre a escolha e o que cada plataforma pediu. Se
  nenhum tocar `.ogg` em todas, restrinja a especificação a `.mp3` (I01) —
  é melhor do que um áudio mudo.
- O som do "toque para ouvir" da partitura é o **sintetizador do app**
  (`SoundEngine`), não um arquivo: o mesmo caminho do "ouvir o trecho" (U03)
  — `ScoreAudioScheduler` com o `PerformanceTrack` da partitura. Respeite
  a saída de som escolhida (app ou teclado MIDI) de `AppSettings`.

## O que fazer

1. **Nomes das notas** — `lib/course/note_names.dart`:
   `noteLabel(Pitch p, NoteNaming naming, {withOctave})` → "Dó", "Fá♯",
   "Si♭4" / "C", "F♯", "B♭4". `AppSettings.noteNaming` (`latin`|`letters`,
   chave `ui_note_naming`, padrão `latin`). O interruptor nas configurações
   é do I09; aqui só a chave e o valor.
2. **`lib/course/ui/markdown_view.dart`** — AST do `markdown` → widgets,
   com os estilos do tema (títulos em `serifDisplay`, corpo 16 sp com
   altura 1,4 no celular). Um `TextBlock` vira um `Column` de blocos.
3. **`lib/course/ui/score_mark_view.dart`** — partitura pequena: renderiza
   os bytes do I02 com `lessonScoreOptions(largura)`, mostra com o
   `ScoreView` do `score_bridge`, `highlight` pinta as notas daquelas
   alturas (cor de destaque das configurações), legenda embaixo. Toque =
   ouvir do começo; tocar de novo para. Enquanto renderiza, um espaço
   reservado com a altura estimada (sem pular a rolagem); erro de render
   vira uma caixa "Não consegui desenhar esta partitura" com o arquivo e a
   linha da marca (o professor vê no rascunho).
4. **`zywny-keyboard`** — generalize o `PianoKeyboardPainter` para uma
   faixa (`lowest`/`highest`, hoje fixos em A0–C8) e um conjunto `marked`
   com cor própria e, com `names: true`, o nome na tecla branca marcada
   (`noteLabel`). O monitor MIDI continua chamando com 88 teclas, sem
   mudança visível. Altura proporcional à largura, como um teclado real.
5. **`zywny-audio`** — tocador compacto: play/pausa, barra de progresso,
   tempo, legenda. Um só toca por vez na lição.
6. **`zywny-video`** — cartão com ícone de vídeo, a legenda e o domínio do
   link ("youtube.com"); toque abre fora do app. Sem miniatura (seria
   buscar na rede).
7. **Cartão de exercício** — `ExerciseCard(spec, state, onStart)`: título,
   o que se pede em uma linha ("Toque as notas · clave de sol · 12 notas"),
   a meta ("meta 90% · 3 rodadas seguidas"), estado (não feito / aprovado
   com a melhor %), e "Precisa do teclado" quando o tipo é MIDI e não há
   teclado (D-LIC-SEM-TECLADO). Aqui `onStart` só chega como callback.
8. **`lib/course/ui/lesson_view.dart`** — junta tudo: título da lição,
   os blocos na ordem, espaçamento do tema, largura máxima de leitura
   (~640 dp) centralizada no desktop/Web.
9. Uma entrada provisória para ver o resultado antes do I09: um teste de
   widget e uma rota de depuração (`--dart-entrypoint-args=--licao
   <pasta> <id>` no desktop, ou o que for mais barato) — anote qual.

## Fora de escopo

Navegação entre lições e progresso (I09); executar o exercício (I03/I09);
vídeo dentro do app (D-LIC-VIDEO); teclado tocável (D-LIC-SEM-TECLADO).

## Critérios de aceite

1. `test/lesson_view_test.dart` com uma lição de fixture que tem **todos**
   os elementos do markdown e as quatro marcas de conteúdo: tudo aparece,
   HTML aparece como texto, link chama o `url_launcher` (falso no teste).
2. `test/note_names_test.dart`: os 12 sons nas duas grafias, com e sem
   oitava, sustenido e bemol.
3. O monitor MIDI desenha igual a antes (teste de widget ou captura).
4. **(manual)** a lição 2 do I00 (escrita como fixture) aberta no Linux, na
   Web e no celular em retrato: partitura nítida, toque para ouvir soa,
   áudio toca, vídeo abre o navegador. Pacote de áudio escolhido e o que
   cada plataforma pediu, nas notas.
5. `just analyze` e `just test` limpos.

## Notas de execução

(vazio)
