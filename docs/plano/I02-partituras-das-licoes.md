# I02 — Partituras das lições: ABC no Verovio, cabeçalho e gerador de rodadas

**Repo:** zywny (medições no fork do bridge; **o fork foi alterado**, ver notas) · **Status:** concluído, falta medir no celular · **Depende de:** I01 · **Decisão necessária:** não
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

Concluído em 2026-10-04, **exceto a medição de tempo no celular** (nenhum
aparelho conectado: `adb devices` vazio e sem serviço mdns). O roteiro está
pronto em `integration_test/lesson_score_timing_test.dart`
(`flutter test integration_test/lesson_score_timing_test.dart -d <aparelho>`);
cole o resultado na tabela de tempos abaixo. `just test` (491) e `just analyze`
limpos.

### Bug do fork achado e corrigido (o mais importante deste passo)

O leitor de ABC (`verovio/src/ioabc.cpp`) guardava a armadura em variáveis
**globais** (`keyPitchAlter`, `keyPitchAlterAmount`) e só as atualizava quando
o `K:` tinha acidentes. No mesmo processo, um ABC em Dó maior ou Lá menor
depois de um ABC com bemóis **herdava os bemóis** (Si♭, Mi♭): alturas erradas
no `midi.json`, sem aviso. A CLI não mostra (um processo por arquivo); o app
mostra — no Linux, no Android (a `.so` é uma só por processo) e na Web (o
worker mantém o módulo wasm). A correção são 10 linhas no fork:
`ABCInput::Import` zera as duas variáveis e o ramo `else` do `K:` também.

- **Está só no working tree do bridge** (`/home/mauricio/rust_projects/verovio_flutter_bridge`,
  `verovio/src/ioabc.cpp`), sem commit — o usuário decide.
- Refeitos com a correção: `just native` (Linux), `tool/build_verovio_web.sh`
  (`web/verovio/`) e `tool/build_verovio_android.sh` (arm64-v8a e x86_64).
  Quem clonar o bridge de novo **precisa refazer os três**; sem isso, os
  testes de `test/abc_source_test.dart` (inclusive a REGRESSÃO) falham.
- O wasm refeito foi conferido em Node (Si♭ e depois Lá menor na mesma
  instância: 69, 71, 72…, certo).

### Alcance do ABC (critério 1)

Fixtures em `test/fixtures/abc/` (uma por recurso); cada linha foi conferida
**desenhando** (CLI → SVG → PNG, folha de contato) e pelo `midi.json` (pelo
app nativo, `test/abc_source_test.dart`; na Web, em Node/wasm: o mesmo
resultado em todos os arquivos conferidos). Também é igual no Android: é o
mesmo código C++.

| Recurso | Fixture | Desenha | `midi.json` | Pauta (`s`) | Veredito |
| --- | --- | --- | --- | --- | --- |
| notas e oitavas `C, c c'` | `oitavas` | certo | 48…89 certo | 1 | ok |
| figuras, `L:` | `figuras` | certo | 500/1000/500/2000/250 ms | 1 | ok |
| pausas `z` | `pausas` | certo | a nota seguinte começa depois | 1 | ok |
| ponto | `ponto`, `ponto-34` | certo | 750/250 ms | 1 | ok |
| ligadura `-` | `ligadura` | certo | **uma** nota com a duração somada | 1 | ok |
| quiáltera de colcheias | `quialtera` | certo (o "3") | 166,7 ms cada | 1 | ok |
| quiáltera de **semínimas** | `quialtera-seminima` | **sem o "3"** | 500 ms cada (devia ser 333) | 1 | **limite** (o `(3` só vale em notas "barráveis") |
| `^ _ =` | `acidentes` | certo | 61, 63, 66, 70, 70, 69… certo | 1 | ok |
| `K:G`, `K:Bb`, `K:Am` | `armadura-*` | certo | certo | 1 | ok |
| `M:2/4 3/4 4/4 6/8 C` | `compasso-*` | certo | 6/8 com colcheia = 250 ms | 1 | ok |
| anacruse | `anacruse` | certo | começa em 0 | 1 | ok |
| repetição `\|: :\|` | `repeticao` | certo | 16 notas (o trecho duas vezes) | 1 | ok |
| clave de fá `K:C clef=bass` | `clave-fa`, `clave-fa-tom` | certo | 48…60, 53… | 1 | ok |
| clave inline `[K:bass]` | `clave-fa-inline` | **errado** (clave de sol + Si) | 47 (Si), não 48 | 1 | **limite** |
| acorde `[CEG]` | `acorde` | certo | 3 notas no mesmo instante | 1 | ok |
| letra `w:` | `letra` | certo | — | 1 | ok |
| `Q:1/4=60` | `tempo` | certo (aviso "não totalmente") | 1000 ms | 1 | ok |
| `V:1`/`V:2` + `%%score {1 2}` | `duas-pautas` | **errado** (um sistema, depois outro) | vozes **em sequência**, não juntas | tudo 1 | **limite** — o validador recusa (`abc_limits.dart`) |
| duas vozes numa pauta | `duas-vozes-uma-pauta` | **errado** | em sequência | 1 | **limite** (idem) |
| corpo sem cabeçalho | `corpo-puro` | não carrega | — | — | **limite** (por isso `abcSource` monta o cabeçalho) |

O `X:` e o `T:` são necessários: sem `T:` o leitor avisa "Title field
missing". **`M:none` desenha um "0"** no lugar da fórmula; sem a linha `M:` a
pauta sai limpa e o `midi.json` sai igual — é o que `abcSource` faz quando a
marca não tem `time`. Os limites estão no `formato-v1.md` (§9) e nos testes
`LIMITE:` de `test/abc_source_test.dart`: se o fork os consertar, esses testes
falham e a especificação precisa ser atualizada.

Consequências para o formato (aplicadas): `clef: grand` **saiu** da marca
`zywny-score` (nem ABC nem `.musicxml` o permitem — o `grand` só existe nos
sorteios); o validador recusa ABC com mais de uma voz (`V:`), em qualquer
chave `abc`; e `figures` que não preenchem um compasso do `time` (ou só
pausas) viraram erro (`figure_rules.dart`).

### O que foi feito

- `lib/course/score/abc_source.dart` — `abcSource(body, {clef, key, time,
  unit})` (cabeçalho `X: T: L: [M:] K:<tom> clef=…`; `X:` passa intacto;
  `grand` lança). `utf8Bytes`.
- `lib/course/score/round_score.dart` — `notesScore`, `rhythmScore`,
  `pickNotes`, `pickFigures`, `roundNoteId(i)` (= `zn{i+1}`).
- `lib/course/score/key_signature.dart` — `KeySignature.parse(key).alterOf(letra)`.
- `lib/course/score/lesson_score.dart` — `scoreSourceFor(source, files, {clef,
  key, time})`, `fromMusicXml(xml)`, `lessonScoreLayout(widthPx)` /
  `lessonScoreOptions` (página, `adjustPageHeight`, sem cabeçalho/rodapé,
  margens 40, `unit: 6`).
- `lib/course/format/figure_rules.dart` e `abc_limits.dart` (validador).
- Testes: `test/abc_source_test.dart` (cabeçalhos + alcance pela libverovio +
  limites + regressão), `test/round_score_test.dart` (sorteio, vale-até-a-barra,
  render real: alturas, ids, pautas e tempos em ms), fixture `erro-abc/`.

### Decisões do gerador (o I03/I07/I08 devem seguir)

- **`Pitch` do sorteio é a nota que soa.** Com `key: G`, a letra F sai como
  F#; o acidente **escrito** só aparece se a nota difere do que a armadura e o
  compasso já valem (por letra e oitava; zera na barra; volta ao natural
  escreve o bequadro). Notas **fixas** do autor também são as que soam
  (`F4` em Sol aparece com bequadro).
- **`only: lines|spaces`** vale para a letra (`Pitch.onLine`), igual nas duas
  claves; `pickNotes` não recebe `clef`.
- **`accidentals` ≠ `none`**: a cada nota, 50% de chance de ser tecla preta
  (sustenido, bemol ou qualquer, conforme o modo) e o resto, as naturais da
  faixa. Nunca E#, B#, Cb, Fb. Escolha minha (o I00 dizia só "sorteia teclas
  pretas"): sem as brancas o aluno não veria o bequadro. Revisável.
- Sem a mesma nota duas vezes seguidas. Mesma `Random` com semente, mesma rodada.
- **`rhythmScore`**: `bpm` conta o tempo da fórmula (semínima pontuada em 6/8);
  colcheias saem em pares com barra (em 6/8, grupos de três); clave de sol se
  a nota é ≥ A3 (57), senão de fá. `pickFigures` garante compassos completos,
  colcheias em par e **ao menos uma nota por compasso**; lança se as figuras
  não fecham o compasso.
- **Ids**: o Verovio **preserva** o `id` da nota do MusicXML: `zn1…` chega ao
  `midi.json` e ao timemap. O I07 destaca a nota da vez por `roundNoteId(i)`
  (o i-ésimo **evento de nota**; pausa não conta).
- **Duas pautas**: nota abaixo de C4 (`diatonic < 28`) vai para a pauta 2. Na
  outra pauta fica um espaço (`<forward>`), e, se a pauta fica **vazia no
  compasso inteiro**, uma pausa de compasso **invisível** — um `forward` puro
  fazia o Verovio atribuir as notas à pauta errada (`s`) no `midi.json`.
- `midi.json` ordena por `onMs`, depois pauta, camada e altura.

### Tempos de render (critério 4; risco 2 do I00: ~300 ms)

Página 1800 px (celular em paisagem ≈ 2054), `lessonScoreOptions`, mediana de
10 repetições depois de uma de aquecimento.

| Caso | Linux (nativo, ciclo completo do app) | Web (wasm no V8/Node, sem o worker) | Celular |
| --- | --- | --- | --- |
| 12 notas, 3 compassos | 23 ms | 50 ms | **a medir** |
| 4 compassos de ritmo | 25 ms | 48 ms | **a medir** |
| duas pautas, 12 notas | 23 ms | 48 ms | **a medir** |

Primeira render do processo: 98 ms no Linux e 170 ms no wasm (carrega a
biblioteca). O risco 2 não se confirma no desktop (≈ 10× abaixo de 300 ms);
um celular costuma ser 3–6× mais lento, o que ainda deixaria < 200 ms, mas
**é estimativa até alguém rodar o integration_test no aparelho**. Se o número
real passar de 300 ms, o I03 renderiza a próxima rodada enquanto a atual roda.
A Web foi medida só no wasm (Node); o worker soma a cópia dos bytes e o
`JSON.parse` do `.vsb`.

### Não feito

- Medição no celular (acima).
- Conferência visual na Web (Chromium) do desenho do ABC: o wasm foi conferido
  por `midi.json`, não por imagem.
