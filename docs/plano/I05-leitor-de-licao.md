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

Concluído em 2026-10-05. `just analyze` limpo; `just test` limpo (529
passando, 4 pulados/manuais, com a `libverovio.so` real — nenhum teste de
lição pulado).

**O que existe**

- `lib/course/note_names.dart` — `NoteNaming` (`latin`|`letters`),
  `noteLabel(Pitch, naming, {withOctave})` ("Dó", "Fá♯", "Si♭4" / "C", "F♯",
  "B♭4"), `pitchFromMidi`/`midiLabel`. `AppSettings.noteNaming` (chave
  `ui_note_naming`, padrão `latin`); o interruptor nas configurações é do I09.
- `lib/course/ui/markdown_view.dart` — AST do `markdown` (dart-lang 7.3.1,
  Dart puro) → widgets, estilos do tema (títulos em `serifDisplay`, corpo 16
  sp altura 1,4). `html`/`inlineHtml` e tabelas viram texto literal, nunca
  interpretados. Links: `url_launcher` 6.3.3 (`LaunchMode.externalApplication`),
  só `https://` (resto recusado em silêncio); imagens: bytes da `CourseFiles`
  (`Image.memory`), legenda = texto alternativo.
- `lib/course/ui/score_mark_view.dart` — partitura pequena: bytes do I02 com
  `lessonScoreOptions(largura)`, `ScoreView` (contínuo, sem rolagem própria —
  a rolagem é a da lição), `highlight` pinta as notas daquelas alturas na cor
  de destaque, legenda embaixo. Toque = ouvir do começo
  (`ScoreAudioScheduler` + `PerformanceTrack`, o sintetizador do app, mesmo
  caminho do "ouvir o trecho" U03); tocar de novo para (sem parada
  automática). Altura estimada enquanto renderiza; erro vira a caixa "Não
  consegui desenhar esta partitura" com arquivo e linha. O `SoundEngine` vem
  pronto de quem chama (app ou teclado MIDI, de `AppSettings.output`).
- `lib/midi/piano_keyboard.dart` generalizado: faixa (`lowest`/`highest`,
  padrão A0–C8), `marked` com cor própria, `names: true` escreve o nome na
  tecla branca marcada (`noteLabel`). O monitor chama com 88 teclas, sem
  mudança visível (teste "desenha igual a antes"). Altura proporcional à
  largura (`KeyboardMarkView`, ~6,35 por tecla branca, como um teclado real).
- `lib/course/ui/lesson_audio.dart` + `audio_mark_view.dart` — tocador
  compacto (play/pausa, barra, tempo, legenda); `SingleAudioPlay` garante um
  só por vez na lição. Escolha medida abaixo: **`audioplayers` (`BytesSource`)**,
  sem restrição a `.mp3` (`.ogg` e `.mp3` valem na v1).
- `lib/course/ui/video_mark_view.dart` — cartão com ícone, legenda e domínio
  ("youtube.com"); toque abre fora do app, sem miniatura (seria rede sem toque).
- `lib/course/ui/exercise_card.dart` — `ExerciseCard(spec, state, onStart)`:
  título, pedido em uma linha, meta, estado e "Precisa do teclado" (tipos MIDI
  sem teclado). `onStart` só chega como callback (o I09 navega).
- `lib/course/ui/lesson_view.dart` — título + blocos na ordem, ~640 dp
  centralizados no desktop/Web.
- Entrada provisória (item 9, o mais barato): **`lib/lesson_debug_main.dart`**
  (fora do `main.dart`, que compila para a Web e não pode importar `dart:io`):
  `flutter run -d linux --no-enable-impeller -t lib/lesson_debug_main.dart
  --dart-entrypoint-args="--licao <pasta> <id>"`. O I09 substitui pelas telas.
- Fixture `test/fixtures/cursos/licao-i05/` (válida; um aviso de HTML de
  propósito) com `.mp3` e `.ogg` reais (seno 440 Hz, 0,5 s, gerados com ffmpeg).
- Testes: `test/note_names_test.dart` (12 sons, duas grafias, oitava,
  ♯/♭) e `test/lesson_view_test.dart` (tudo aparece, HTML como texto, link no
  abridor falso, sem-teclado, retrato 390×844 sem estouro, monitor igual).

**`flutter_markdown` (conferido no pub.dev na hora, como pede o passo)**:
descontinuado pelo time do Flutter em 2025 (6 anos sem release relevante;
a página sugere `flutter_markdown_plus` como substituto) — não usado, como
o passo manda. Anotado também no topo de `markdown_view.dart`.

**Áudio nas quatro plataformas (escolha do pacote)**

| Plataforma | `.ogg` | `.mp3` | A partir de bytes | O que pediu |
| --- | --- | --- | --- | --- |
| Linux (Pop!_OS, GStreamer 1.24.2) | sim | sim | sim (`BytesSource`) | nada: `libgstogg`/`libgstvorbis`/`libav` já instalados |
| Android (ExoPlayer) | sim | sim | sim | nada (bytes locais, sem permissão) |
| Web | sim (Chrome/Edge) | sim (incl. Safari) | sim (Blob `audio/ogg`/`audio/mpeg`) | nada |
| Windows (Media Foundation) | sim | sim | sim | nada (sem build Windows neste passo) |

Medido por capability dos backends do `audioplayers` 6.8.1 + `gst-inspect-1.0`
no Pop!_OS (a partitura toca pelo sintetizador, não por aqui — isto é só o
`zywny-audio`). Nenhum `.ogg` mudo em nenhuma plataforma: a especificação
continua com `.ogg`/`.mp3` (I01), sem restrição.

**Manual (critério 4, parcialmente)**: a fixture abre no teste de widget em
retrato 390×844 sem estouro; partitura renderizada de verdade (midi.json com
as alturas), toque-para-ouvir e áudio cobertos com motor/tocador falsos. Falta
abrir a lição 2 de verdade no Linux, na Web e no celular físico (sem aparelho
conectado neste passo, como no I02) — roteiro: `lib/lesson_debug_main.dart`
com `--licao <pasta> <id>` no desktop, `just web-smoke` + navegador na Web,
`just run-android` no aparelho.
