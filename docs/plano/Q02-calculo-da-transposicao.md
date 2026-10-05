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

(vazio)
