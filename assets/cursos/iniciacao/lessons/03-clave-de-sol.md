---
id: clave-de-sol
title: A clave de sol por dentro
requires: [pauta-e-clave-de-sol]
---

## Linhas e espaços

Na clave de sol, as linhas são Mi, Sol, Si, Ré e Fá, de baixo para cima.

Os espaços são Fá, Lá, Dó e Mi. Decore aos poucos: o exercício cobra só
as linhas primeiro, depois só os espaços.

```zywny-score
clef: treble
abc: "E G B"
highlight: [E4, G4, B4]
caption: Notas em linhas
```

## Linhas suplementares

O Dó central mora numa linha curta fora da pauta. Ela se chama linha
suplementar.

Notas acima do Sol da segunda linha sobem para fora da pauta do mesmo
jeito. Veja e ouça antes de tocar.

```zywny-score
clef: treble
abc: "F A c"
highlight: [F4, A4]
caption: Notas em espaços
```

## Só linhas

Toque só notas em linhas, do Dó central ao Sol agudo. Duas rodadas
seguidas para fixar.

```zywny-exercise
id: l3-linhas
type: play-notes
title: Só linhas
clef: treble
notes: {random: C4-G5, count: 12, only: lines}
pass: {accuracy: 90, rounds: 2}
```

## Só espaços

Agora só espaços. O mesmo caminho, as mesmas duas rodadas seguidas.

```zywny-exercise
id: l3-espacos
type: play-notes
title: Só espaços
clef: treble
notes: {random: C4-G5, count: 12, only: spaces}
pass: {accuracy: 90, rounds: 2}
```

## Rápido nos nomes

Leia a nota e toque o botão com o nome, com dez segundos por pergunta.
Estourou, conta como erro e a lição mostra a certa.

```zywny-exercise
id: l3-nomes-rapidos
type: name-note
title: Nomes contra o relógio
clef: treble
notes: {random: C4-A4, count: 8}
choices: [C, D, E, F, G, A]
pass: {accuracy: 90, time-limit: 10}
```
