# I02 — Partituras das lições: ABC no Verovio, cabeçalho e gerador de rodadas

**Repo:** zywny (medições no fork do bridge, sem mudar o fork salvo
necessidade) · **Depende de:** I01 · **Decisão necessária:** não
(D-LIC-NOTACAO decidida: ABC em linha + `.musicxml`)

## Objetivo

Toda partitura de uma lição sai de um lugar só: uma função que recebe a
marca ou a rodada e devolve **bytes** para o `ScoreRenderRequest`. Três
fontes:

1. `abc:` em linha (com cabeçalho montado pelo app quando o autor escreve só
   o corpo);
2. `file:` `.musicxml` da pasta (passa direto);
3. **rodadas sorteadas** (`play-notes`, `name-note`, `rhythm`,
   `count-beats`): um gerador de MusicXML em Dart puro.

E duas medições que decidem o resto da fase: **o que o ABC do Verovio
cobre** e **quanto custa renderizar** uma partitura curta no celular.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): "O formato (v1)", marcas e tipos,
  e "Riscos a medir cedo" 1 e 2.
- `lib/render/score_renderer.dart` (52 linhas: `ScoreRenderRequest`,
  `createScoreRenderer`).
- `test/vsb_render_test.dart` L1–L60: como um teste renderiza de verdade
  pela `libverovio.so` do bridge (e se pula quando ela não existe).
- `lib/music/performance_track.dart` `PerformanceTrack.fromDocument` L102.

## Contexto que você precisa

- O `Toolkit` do fork detecta ABC quando o texto começa com `X` ou `%a`
  (`verovio/src/toolkit.cpp` ~L212); o leitor é `verovio/src/ioabc.cpp`
  (1820 linhas). `NO_ABC_SUPPORT` é `OFF` no CMake; confira que os builds
  **Android** (`tool/build_verovio_android.sh`) e **Web**
  (`verovio/bindings/js/build_wasm.sh` no bridge) também não o desligam.
- O `.vsb` traz `midi.json` (G01/G02) e o `timemap`; o treino precisa dos
  dois. Uma partitura que renderiza sem `midi.json` não serve para
  exercício.
- O `fileName` do `ScoreRenderRequest` é só para mensagens e o arquivo
  temporário do nativo — mas a **extensão** pode mudar a detecção do
  formato no nativo: use `.abc` para ABC e `.musicxml` para MusicXML e
  confira os dois caminhos (nativo e Web).
- Posições das notas na pauta (linhas e espaços), por clave: clave de sol,
  linhas E4 G4 B4 D5 F5; clave de fá, linhas G2 B2 D3 F3 A3. Linhas
  suplementares contam como linha (C4 na clave de sol é linha).

## O que fazer

1. **Alcance do ABC** — monte `test/fixtures/abc/` com um arquivo por
   recurso que o curso inicial e um professor comum usam: notas e oitavas
   (`C, c c'`), figuras e `L:`, pausas, ponto, ligadura de valor (`-`),
   quiáltera (`(3`), acidentes e bequadro (`^ _ =`), armaduras (`K:G`,
   `K:Bb`, `K:Am`), compassos `M:2/4 3/4 4/4 6/8 C`, anacruse, barras de
   repetição, **clave de fá** (`K:C clef=bass`), **duas vozes/pautas**
   (`V:1 clef=treble`, `V:2 clef=bass`, `%%score {1 2}`), acorde (`[CEG]`),
   texto/letra (`w:`). Para cada um, renderize com a CLI do fork e pelo app
   (nativo; Web numa conferência) e anote numa tabela: desenha certo? o
   `midi.json` tem as alturas e durações certas? a pauta vira staff 1/2
   como o `Hand` espera (`lib/practice/hand.dart` L9–L25: direita = staff
   1)? O que não funcionar vira **limite documentado** em
   `docs/licoes/formato-v1.md` ("para duas pautas, use um `.musicxml`") ou,
   se for barato, correção no fork (com os passos do plano do bridge).
2. **`lib/course/score/abc_source.dart`** — `abcSource(body, {clef, key,
   time, unit})` monta o ABC completo quando o corpo não começa com `X:`:
   `X:1`, `M:` (de `time`, padrão `4/4`; `none` quando a marca não diz e a
   rodada não tem ritmo), `L:1/4`, `K:<tom> clef=<treble|bass>`; `grand`
   com as duas vozes e `%%score`, **se** o passo 1 mostrar que funciona —
   senão, `clef: grand` com `abc:` de corpo vira erro do validador (volte ao
   I01 e acrescente) e o `grand` só existe nos sorteios (MusicXML).
3. **`lib/course/score/round_score.dart`** — gerador de MusicXML 4.0
   (`score-partwise`, uma parte, 1 ou 2 pautas), Dart puro:
   - `notesScore(List<Pitch> notes, {clef, key, time})`: uma nota por
     tempo (semínimas em 4/4, 4 por compasso), com barras; os acidentes
     **escritos** seguem a regra "vale até a barra" (sustenido repetido no
     mesmo compasso não se reescreve; voltar ao natural no mesmo compasso
     escreve o bequadro). Em `grand`, nota < C4 vai para a pauta 2 (fá) e o
     resto para a 1, com pausa invisível ou espaço na outra pauta.
   - `rhythmScore(List<Figure> figures, {time, pitch})`: figuras numa
     altura só, colcheias com barra de ligação em pares, compassos
     completos.
   - `pickNotes(NoteRange range, {count, only, clef, accidentals, Random
     rng})` e `pickFigures(List<Figure> allowed, {measures, time, rng})`:
     sorteio determinístico pela semente; sem a mesma nota duas vezes
     seguidas; `only: lines|spaces` relativo à clave; `accidentals` sorteia
     teclas pretas e as escreve como sustenido (`sharps`), bemol (`flats`)
     ou misturado com bequadros (`mixed`).
   - Cada nota gerada tem um **id estável** (`xml:id`/`id` do MusicXML que o
     Verovio preserva? confira) para o destaque do `name-note` e do
     `count-beats` (I07). Se o Verovio não preservar, devolva a ordem das
     notas e case pelo `midi.json`/`timemap` na ordem — anote qual dos dois.
4. **`lib/course/score/lesson_score.dart`** — `Future<LessonScoreSource>
   scoreSourceFor(...)` para marca (`ScoreMark`) e para rodada: devolve
   `{bytes, fileName}`; o `file:` lê da `CourseFiles` do I01.
5. **Tempo de render** — meça (`Stopwatch` em volta do `render`, 10
   repetições, mediana) para: 12 notas em 3 compassos; 4 compassos de
   ritmo; duas pautas com 12 notas. No **Linux**, na **Web** (Chromium) e
   no **celular** (`just run-android` em release/profile, aparelho do
   usuário). Anote nas notas de execução e corrija o risco 2 do I00 se o
   número contrariar os ~300 ms.
6. Opções de layout para partitura pequena: largura da tela, sem
   cabeçalho, sem número de compasso, `adjustPageHeight`. Deixe as opções
   prontas numa função (`lessonScoreOptions(width)`) para o I05 e o I09.

## Fora de escopo

Mostrar a partitura numa lição (I05) ou no exercício (I09); o sorteio por
tipo de exercício (cada tipo usa estas funções no I03/I07/I08).

## Critérios de aceite

1. Tabela do alcance do ABC nas notas de execução, com o que vira limite na
   especificação (e a especificação atualizada).
2. `test/round_score_test.dart`: o MusicXML gerado renderiza pela
   `libverovio.so` (pulado se ela não existir, como no
   `vsb_render_test.dart`) e o `midi.json` tem exatamente as alturas
   sorteadas, na ordem; mesma semente → mesma rodada; `only: lines` só dá
   linhas; "vale até a barra" escreve o bequadro quando precisa.
3. `test/abc_source_test.dart`: cabeçalho montado para cada clave e tom; ABC
   com `X:` passa intacto.
4. Tempos de render medidos nas três plataformas, nas notas.
5. `just analyze` e `just test` limpos.

## Notas de execução

(vazio)
