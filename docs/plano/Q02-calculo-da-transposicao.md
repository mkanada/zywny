# Q02 — Cálculo da transposição e as três alturas

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** não
(D-TRP-ALVO, D-TRP-DIRECAO decididas)

## Objetivo

Duas classes puras, sem Flutter, com teste de tabela: `Transposition` (que
intervalo usar e o que dizer à pessoa) e `PitchFrame` (converter entre as
alturas escrita, soada e recebida). Todo o resto da fase usa só elas.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "As três alturas", "O problema do
  MIDI do teclado", "Como escolher a transposição" (a tabela).
- `lib/library/piece.dart` L77 (`fifths`) e L168 (`keySignatureLabel`).

## O que fazer

1. `lib/music/transposition.dart`:
   - `Transposition` imutável: `interval` (texto do Verovio, ex. `-m3`),
     `semitones` (`k`), `fifthsDelta` (quantas quintas andou), `keyboard`
     (= −k, o valor do TRANSPOSE).
   - `Transposition.toNoAccidentals(int fifths, {required int lowest,
     required int highest, int keyLow = 21, int keyHigh = 108})`: a linha da
     tabela do Q00 (andar −fifths quintas, o menor |k|; no trítono, descer —
     D-TRP-DIRECAO), trocando de direção se a música transposta sair de
     `keyLow..keyHigh`. `fifths == 0` devolve `null` (nada a transpor).
   - `Transposition.toFifths(int from, int to, …)`: a mesma conta para
     qualquer tom da lista (D-TRP-ALVO); `toNoAccidentals` é `toFifths(f, 0)`.
   - `Transposition.parse(String interval)`: lê o que foi guardado; inválido
     → `null`.
   - Nomes para a tela, em Dó-Ré-Mi com ♯/♭: `fromKeyName`/`toKeyName` a
     partir das quintas (tônica maior; o selo não diz o modo), `keyboardLabel`
     ("+3", "−5", com o sinal tipográfico), `soundsLike(int writtenPitch)`
     ("a tecla Dó vai soar Mi♭").
   - `resultingFifths(int fifths)` para a lista dos 12 tons ("1♯ · teclado
     −2").
2. `lib/music/pitch_frame.dart`: `PitchFrame(k, {bool keyboardShiftsOut,
   bool keyboardShiftsIn, bool appIsSound})` com:
   - `writtenFromReceived(int p)` — para o casador;
   - `soundingFromWritten(int p)` — para o agendador e o motor do app;
   - `monitorFromReceived(int p)` — para o `MidiMonitor`;
   - `outFromWritten(int p)` — para a saída MIDI ao teclado (M03);
   - `PitchFrame.identity` (k = 0) — o caminho de hoje, sem custo.
   A tabela de verdade das conversões vai em comentário e em teste.
3. Testes (`test/transposition_test.dart`, `test/pitch_frame_test.dart`):
   as 14 linhas da tabela do Q00 (intervalo, k, teclado), os dois trítonos
   com e sem estouro de faixa, `parse` de válidos e inválidos, os nomes, e as
   conversões nos 2 × 2 casos de teclado (transpõe ou não a saída / a
   entrada).

## Fora de escopo

Guardar, renderizar, tela. Descobrir o comportamento do teclado (Q06).

## Critérios de aceite

1. `just analyze` e `just test` limpos; os testes de tabela cobrem as 14
   armaduras.
2. Nenhum outro arquivo do app soma semitons para transposição (este passo
   não liga nada ainda).

## Notas de execução

### Resultado (2026-10-06): concluído

Arquivos: `lib/music/transposition.dart` (`Transposition`),
`lib/music/pitch_frame.dart` (`PitchFrame`), `test/transposition_test.dart`
(33 casos) e `test/pitch_frame_test.dart` (11 casos, entre eles uma conta de
ponta a ponta por linha da tabela e por tipo de teclado).

**Critérios**
1. `flutter analyze` sem avisos; `flutter test` inteiro: 730 passaram, 10
   pulados (os manuais), nenhuma falha. As 14 linhas da tabela (intervalo,
   `k`, TRANSPOSE, `fifthsDelta`) e os 225 pares de armaduras de −7 a +7 estão
   cobertos. ✔
2. Nenhum outro arquivo do app soma semitons por causa da transposição (só
   os dois acima mencionam "transpos" em `lib/`); nada foi ligado. ✔

**Como o cálculo funciona (e por que o intervalo sai certo em todo par)**
- Uma transposição é o par (`fifthsDelta`, `semitones`). As quintas decidem a
  grafia, e `k ≡ 7 · fifthsDelta (mod 12)` deixa só duas escolhas, uma para cada
  direção. `toFifths` escolhe a de menor |k| (trítono: desce) e troca de
  direção só se a música (`lowest`/`highest` **do original**) sair de
  `keyLow..keyHigh`.
- O nome do intervalo (`interval`) não sai dos semitons: sai da posição na
  cadeia de quintas (`_ascendingName`): o número vem de `4·c mod 7` e a qualidade
  de quantas vezes passou de 7 quintas. Descendo, é o ascendente de −`fifthsDelta`
  com o sinal de menos (`-m3` = descer o `m3` ascendente, que anda −3 quintas).
  `parse` faz o caminho de volta, e o teste confirma que `parse(t.interval) == t`
  nos 225 pares e nas duas direções de cada um.
- `PitchFrame` guarda a tabela de verdade no comentário da classe; `appIsSound`
  desliga os dois comportamentos do teclado (o TRANSPOSE fica em 0, a recebida é
  a escrita e ao teclado se manda a soada).

**O que foi além do escrito no passo**
- `Transposition.fits({lowest, highest, keyLow, keyHigh})`: quando nenhuma
  direção cabe, `toFifths` devolve a preferida e a tela (Q08) usa `fits` para
  avisar ("se as duas passarem, avisa", Q00). O objeto continua um valor puro.
- `Transposition.keyName(fifths)` estático, mais `fromKeyName`/`toKeyName`
  (aceitam `naming:` — `NoteNaming.latin` por padrão, `letters` se a pessoa
  escolheu C–D–E). O nome vale para qualquer posição na cadeia: depois de ±7
  vira dobrado (`Sol♯` para 8♯, `Fá♯♯` para 13).
- `soundsLike` soletra pela cadeia de quintas, não por semitons: Dó → Mi♭ e
  não Ré♯ ("a tecla Dó♯ vai soar Mi" em Mi♭→Dó). Os testes conferem a classe de
  altura do som contra `escrita − k` nas 14 linhas.
- `==`/`hashCode`/`toString` nas duas classes (valor puro).

**O que o próximo passo precisa saber**
- `Transposition.parse('P1')` devolve `null` (P1/`-P1` não transpõem; assim
  também `d1`, `P3`, `m4`, oitava `P8` e tudo composto acima de `d8`): o Q03
  guarda `'P1'` para "a pessoa escolheu Não" e tem de tratá-lo **antes** de
  chamar `parse` (anotado no Q03).
- `parse` devolve o texto canônico em `interval` (`+P4`, `p4` → `P4`; `a4` →
  `A4`) e aceita o que o Verovio aceita (`+`, `P`/`p`, `A`/`a`, `d`/`D`,
  repetidos: `AA1`).
- `toFifths(f, f)` e `toNoAccidentals(0)` devolvem `null`. Os pares de 6♭ ↔ 6♯
  (`delta` = ±12, `k` = 0) são só uma troca de grafia (`-d2`); não têm outra
  direção e não devem aparecer na lista dos 12 tons.
- A faixa vem de quem chama: hinos cabem em A0–C8 em qualquer direção da
  tabela (Q01), então o Q03 pode passar a faixa do catálogo (27–86).
