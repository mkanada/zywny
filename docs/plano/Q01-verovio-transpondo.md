# Q01 — Medir o Verovio transpondo

**Repo:** zywny (medição; código no bridge só se algo quebrar) · **Depende
de:** — · **Decisão necessária:** não (D-TRP-\* decididas no Q00)

## Objetivo

Confirmar, com números, que a opção `transpose` do fork gera um `.vsb`
inteiro e coerente na altura **escrita**, para que os passos seguintes
confiem nele sem conferir de novo.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "As três alturas", "Como escolher a
  transposição", "Onde a transposição acontece".
- README, "Fork do Verovio" (tabela do mapa do código).

## Contexto que você precisa

- A opção: `verovio/src/options.cpp` L1685 (`m_transpose`), aplicada em
  `Toolkit::LoadData` (`src/toolkit.cpp` L872) por `Doc::TransposeDoc`
  (`src/doc.cpp` L1656). Sintaxe do intervalo
  (`Transposer::IsValidIntervalName`, `src/transposition.cpp` L2051):
  `(-|\+?)([Pp]|M|m|[aA]+|[dD]+)([1-9][0-9]*)` — `-m3`, `P4`, `-A4`, `d5`,
  `A1`.
- O doc expandido das repetições (`Toolkit::SetMidiDoc`, L288) é importado do
  MEI do doc **já transposto** (`MEIInput::Import(GetMEI())`), sem passar de
  novo por `LoadData`. Por isso não deve transpor duas vezes — mas confira.
- Hinos em MusicXML: `/home/mauricio/IdeaProjects/Hymn_Grabber/musicxml/`
  (584 arquivos). CLI: `verovio/tools/verovio -r verovio/data` no bridge.
- **Já medido (2026-10-04, CLI, hino `013`, 3♭, `--transpose=-m3`)**: MIDI
  com as mesmas 561 notas, todas 3 semitons abaixo (63→60, 70→67…); a
  armadura passou de 24 `keyAccid` para 0; acidentes **visíveis** continuaram
  7 (5 bequadros viraram sustenidos, 2 bemóis viraram bequadros). Os
  elementos `accid` totais subiram de 136 para 245, mas os novos são
  gestuais (sem glifo). Falta medir o caminho do app (`.vsb`).

## O que fazer

1. Script de medição em `tool/` (Python, como os outros) que, para uma
   amostra de hinos de **cada armadura presente** no catálogo (de −7 a +7,
   o que existir), gera o `.vsb` original e o transposto pelo intervalo da
   tabela do Q00 (CLI `-t vsb --transpose=…`), e compara:
   - `midi.json` (o ex-`notes.json` do N01): mesmo número de notas, mesmos
     ids, `p` = original + k em **todas**;
   - `timemap`: mesmos `tstamp`, mesmos ids em `on`/`off`;
   - cena: armadura inicial vazia; contagem de acidentes visíveis antes e
     depois; nenhum dobrado sustenido/bemol (ou quantos);
   - repetições: num hino com ritornelo (ver `corpus/repeticoes` no bridge),
     ids `-rend<N>` iguais e pitch deslocado **uma vez só**;
   - `alternates` (se o hino tiver): mesmos ids.
2. Mudança de armadura no meio: listar os hinos com mais de uma armadura e
   a armadura que sobra depois de transpor. Dizer se dá para ler isso do
   `.vsb` (para o aviso "a partir do compasso N…" do Q00) e a que custo.
3. Tempo de render no app (Linux, `renderScoreToVsb`) com e sem transposição,
   em 3 hinos; diferença esperada desprezível.
4. Determinismo: renderizar o original duas vezes e comparar os bytes (o
   critério 6 da fase depende disso). Se não for determinístico, dizer o que
   muda e trocar o critério por "mesmos `midi.json`/timemap".
5. Faixa: a nota mais grave e a mais aguda do catálogo depois de transpor,
   para cada direção — quantos hinos sairiam de A0–C8 (esperado: nenhum) e
   de um teclado de 61 teclas (C2–C7).

## Fora de escopo

Mudar o app (Q03 em diante). Mexer no fork — só se um critério falhar; nesse
caso, o conserto vai para o plano do bridge (prefixo G) e este passo anota.

## Critérios de aceite

1. Tabela por armadura nas notas de execução: hinos testados, notas, todas
   deslocadas por k, ids iguais, acidentes visíveis antes/depois.
2. Repetição sem transposição dupla, com o hino citado.
3. Tempos medidos e resposta sobre determinismo.
4. Lista dos hinos com mudança de armadura e a decisão sobre o aviso.

## Notas de execução

### Resultado (2026-10-06): concluído

**Como foi medido.** Dois instrumentos, os dois versionados:

- `tool/medir_transposicao.py` — o CLI do fork (`-t vsb --transpose=…`), **o
  catálogo inteiro** (não uma amostra): os 600 hinos de `musicxml/` +
  `musicxml_special/`, 131 sem armadura, **469 transpostos** pela tabela do
  Q00 (310.636 notas), em ~2 min com 4 processos. Opções: `--amostra N`,
  `--hinos 013 200`, `--tabela`, `--determinismo`, `--json`. Sai 0 só se
  nenhum hino falhar.
- `test/transposicao_render_manual_test.dart` — o caminho do app
  (`renderScoreToVsb` com `options: {'transpose': …}`, a `libverovio.so`
  do app): `Q01_TRANSPOSE=1 flutter test test/transposicao_render_manual_test.dart`.

O CLI (`verovio/tools/verovio`, de 04/10 14:11) e a `libverovio.so` (04/10
23:30) são anteriores aos dois últimos commits do fork em `src/` (vsb-json
com timemap; armadura do ABC): nenhum toca MusicXML nem `-t vsb`, e o teste
do app deu o mesmo que o CLI nos quatro hinos que repetiu.

**Critério 1 — tabela por armadura** (todos os hinos de cada armadura; "tudo
igual" = `midi.json` com as mesmas entradas, tempo, pauta, camada e
ligaduras e `p` = original + k em todas, `timemap` idêntico, ids dos
elementos musicais iguais, armadura inicial desenhada vazia, `pitchpos`
com `p = altura(pn, o, alt) + sh`):

| Armadura | Intervalo | k | Hinos | Notas | Tudo igual | Armadura inicial desenhada | Acidentes visíveis antes → depois | Dobrados antes → depois |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1♯ | `P4` | +5 | 86 | 60.426 | 86/86 | 1 → 0 | 1457 → 1457 | 0 → 2 |
| 2♯ | `-M2` | −2 | 85 | 47.199 | 85/85 | 2 → 0 | 1249 → 1249 | 0 → 14 |
| 3♯ | `m3` | +3 | 39 | 27.459 | 39/39 | 3 → 0 | 461 → 461 | 0 → 0 |
| 4♯ | `-M3` | −4 | 41 | 28.878 | 41/41 | 4 → 0 | 502 → 502 | 0 → 3 |
| 1♭ | `-P4` | −5 | 123 | 80.830 | 123/123 | 1 → 0 | 1842 → 1842 | 0 → 0 |
| 2♭ | `M2` | +2 | 41 | 30.797 | 41/41 | 2 → 0 | 608 → 608 | 0 → 0 |
| 3♭ | `-m3` | −3 | 37 | 24.039 | 37/37 | 3 → 0 | 578 → 578 | 0 → 6 |
| 4♭ | `M3` | +4 | 12 | 8.269 | 12/12 | 4 → 0 | 285 → 285 | 2 → 12 |
| 5♭ | `-m2` | −1 | 5 | 2.739 | 5/5 | 5 → 0 | 82 → 82 | 4 → 4 |

- **O catálogo só tem armaduras de 5♭ a 4♯.** As linhas +5, ±6 e ±7 da
  tabela não existem em hino nenhum; `--tabela` as exercita levando o hino
  002 (Dó maior) ao tom de cada uma das 14 linhas (MEI transposto pelo
  intervalo da linha oposta) e de volta pela linha: nas 14, a armadura
  desenhada no tom da linha tem |f| acidentes, a de volta é vazia e a
  grafia (letra e alteração de cada nota), os ids e a altura (original + k
  de ida + k de volta) voltam ao do hino original. O Verovio aceita todos
  os intervalos da tabela (`-A4`, `-d5`, `A1`, `-A1`, `m2`…).
- **Acidentes visíveis**: o total de glifos E260–E264 é o mesmo antes e
  depois em todas as armaduras, mas muda de tipo (no 013, 5 bequadros viram
  sustenidos e 2 bemóis viram bequadros). Os `accid` a mais na cena (136 →
  245 no 013) são gestuais, sem glifo.
- Nada ficou de fora no `midi.json`: as repetições, as sequências
  alternativas e a ligadura (`tied`) saem iguais (ver critério 2).

**Critério 2 — repetição sem transposição dupla.** 417 hinos têm ids
`-rend<N>` (152.135 notas expandidas): em todos, cada nota expandida tem o
mesmo id e o mesmo tempo e **k exatamente uma vez** (417/417). O documento
expandido (`SetMidiDoc`) sai do MEI já transposto, como o Q00 supunha. Maior:
hino 367 (1.068 notas `-rend`, 4 sequências alternativas). Os 87 hinos com
`alternates` de mais de uma sequência saem com os mesmos ids (ignorados os
`accid`, que a transposição acrescenta). Nenhum hino do catálogo tem
ornamento expandido (`orn`).

**Critério 3 — tempo e determinismo.**

- Render pelo app (Linux, `renderScoreToVsb`, mediana de 5 depois de aquecer):

  | Hino | Notas | Original | Transposto |
  | --- | --- | --- | --- |
  | 013 (3♭, `-m3`) | 561 | 260 ms | 185 ms |
  | 001 (2♯, `-M2`) | 567 | 248 ms | 268 ms |
  | 367 (2♭, `M2`) | 1.477 | 536 ms | 566 ms |
  | 031 (1♯, `P4`) | 747 | 383 ms | 414 ms |

  De −29% a +8%: a transposição não custa tempo que se perceba (o 013
  ficar mais rápido não foi investigado).
- **Os ids do Verovio mudam a cada render, com ou sem transposição.** Dois
  renders do mesmo MusicXML diferem em `scene.json`, `timemap.json`,
  `midi.json`, `pitchpos.json` e `alternates.json`; só `glyphs.json`,
  `meta.json` e `manifest.json` ficam iguais. Descontados os ids (incluindo
  os `systemMilestoneEnd <id>` da classe), a cena é a mesma: o layout é
  determinístico. O app não passa `xmlIdSeed`.
- **Com a mesma semente (`xmlIdSeed`: `--xml-id-seed=1` no CLI) os
  membros do `.vsb` saem iguais** (original duas vezes; transposto duas
  vezes), e original × transposto têm os mesmos ids nos elementos
  musicais (`note`, `chord`, `rest`, `measure`, `staff`, `layer`, `syl`,
  `verse`, `harm`, `beam`, `barLine` e os `accid` que já existiam). Os
  elementos criados no layout (`stem`, `dots`, `clef`, `keySig`, `system`,
  `mNum`, `meterSig`) ganham outro id, porque os `accid` gestuais novos
  consomem a sequência. O arquivo `.vsb` inteiro ainda pode diferir: são só os
  16 bytes do carimbo de hora do zip (resolução de 2 s), conferido byte a byte.
- **Consequência: o critério 6 do Q00 ("byte a byte") não vale como estava
  escrito**; o Q00 foi corrigido para "mesma partitura": mesmo layout, mesmas
  notas e tempos, ids novos como em qualquer render. Nada que o app guarda
  usa id de nota (a trilha guarda por trecho: `t<N>.<fase>`,
  `trail_plan.dart`), então trilha, decorar e destaques não são afetados — a
  frase "os `xml:id` não mudam" do Q00 foi trocada por isso. Quem precisar de
  ids estáveis entre original e transposto (Q05–Q07 não precisam) passa
  `xmlIdSeed` em `VsbRenderRequest.options`; o teste do app confere que a
  opção é aceita.

**Critério 4 — mudança de armadura no meio.** 38 dos 469 hinos têm mais
de uma armadura (35 com duas, 2 com três, 1 com quatro). **Dá para ler do
`.vsb` sem nada novo**: o `key` de cada nota no `pitchpos.json` (a armadura
vigente) + a ordem dos `measureOn` do timemap (só os ids sem `-rend`) dão o
compasso de cada mudança e a armadura que sobra; reproduz o `<fifths>` do
MusicXML (compasso e valor) em 469/469 hinos. Custo: um laço sobre timemap e
pitchpos já carregados, 40–440 µs por hino em Dart (média de 100 passadas),
sem render a mais. **O aviso "a partir do compasso N a armadura tem X♯" é
barato e vale a pena**: em 35 dos 38 hinos a armadura que sobra tem **mais**
acidentes que a do trecho original, e em 26 chega a 5 ou mais (5♭ em 18
ocorrências, 7♯ em 8, 2♯ em 10) — o app não deve fingir que a música "ficou
sem acidentes". Não otimizado na v1 (escolher o tom do trecho mais longo):
fica como ideia para o Q08. Os 38 hinos, com a armadura (quintas) de cada
mudança antes → depois de transpor (`cN` = compasso N): 031 c20 −4→−5;
050 c29 +1→+2; 054 c50 +3→+7; 069 c39 +1→+2; 076 c41 +3→+7; 115 c28 −1→−5;
135 c44 +1→+2; 162 c30 +4→+7; 210 c28 +1→+2; 225 c28 −1→−5; 239 c49 −4→−5;
243 c28 −4→−5; 248 c43 +1→+2; 250 c28 −4→−5; 258 c40 +4→+3, c58 +1→0, c75
+4→+3; 281 c10 −1→−3, c26 +2→0; 282 c41 −3→−5; 297 c48 +1→+2; 327 c26 −1→−5;
394 c44 −3→−5; 396 c31 +3→+7; 440 c21 −4→−5; 455 c22 −1→−5; 461 c71 −3→−5;
466 c35 −1→−5; 468 c35 −1→+2; 477 c26 −4→−5; 488 c47 −3→−5; 509 c12 +3→+7,
c20 −2→+2; 530 c25 −3→−5; 537 c13 −3→−5; 538 c13 +4→+7; 548 c32 +4→+3; 567
c23 +2→+7; 568 c21 −1→+2; 570 c27 +4→+2; 577 c18 +2→+7; 600 c26 −1→−5.

**Dobrados** (alteração ±2 na nota): 3 hinos já tinham no original (6 notas);
depois de transpor, **11 de 469 hinos** (41 notas): 488 (14, dobrado bemol),
054 (5), 162 (4), 567 (4), 076 (3), 396 (3), 031, 538 e 600 (2 cada), 327 e
443 (1 cada). Quase todas aparecem desenhadas (`E263`/`E264`); as que não, o
acidente do compasso já cobria. Raro, como o Q00 supunha; nenhum hino mistura
dobrado sustenido e dobrado bemol. Quem quer evitar escolhe outro tom na
lista dos 12 (Q08).

**Critério 5 — faixa.** Tabela de direção do Q00 (a que sai de
`toNoAccidentals` sem estouro):

- 88 teclas (A0–C8, 21–108): original de 27 a 86; depois de transpor,
  de 24 a 88 (hinos 019 e 036). **Nenhum hino estoura**, nem na direção da
  tabela nem na oposta, exceto 3 hinos na oposta (que o Q02 só usa se a
  preferida estourar, o que não acontece). Então, para hino, o parâmetro de
  faixa do `toNoAccidentals` nunca troca a direção; o Q03 pode chamar com a
  faixa do catálogo (27–86) quando ainda não tem o `midi.json` do original, e
  corrigir só se uma biblioteca de clássicos estourar (não medida aqui).
- 61 teclas (C2–C7, 36–96): **44 hinos já não cabem no original** (notas
  abaixo de C2); a direção da tabela deixa 97 de fora, a oposta 146, e com a
  regra do Q02 (troca de direção se estoura) ficam 3 de fora. Se o app
  passar a aceitar teclado de 61 teclas (hoje supõe 88: `PianoKeyboardPainter`
  L21–L22), a regra já está pronta (`keyLow`/`keyHigh`).

**Instrumento transpositor** (`<transpose>` no MusicXML): nenhum dos 600
hinos tem; `sh` do pitchpos fica 0.

**Para os próximos passos**
- Q02 pode seguir como escrito; a tabela do Q00 está certa nas 14 linhas.
- Q03: ler `midi.json` onde o plano diz `notes.json`; o critério 3 ("`.vsb`
  igual ao de antes") compara notas, timemap e layout, não bytes; não foi
  preciso mexer no fork, então nada vai para o plano do bridge (G).
- Q08: o aviso de mudança de armadura sai do `pitchpos`+timemap (ver acima);
  a lista dos 12 tons pode mostrar "dobrados" como motivo para escolher
  outro.
