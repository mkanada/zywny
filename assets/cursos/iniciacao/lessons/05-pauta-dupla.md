---
id: pauta-dupla
title: A pauta dupla
requires: [clave-de-sol, clave-de-fa]
---

## Duas pautas de mãos dadas

O piano lê duas pautas ao mesmo tempo. Em cima, a clave de sol para a
mão direita. Embaixo, a clave de fá para a esquerda.

A chave no começo abraça as duas. O dó central mora no meio, entre elas.

![A pauta dupla](media/pauta-dupla.png)

## O dó central no meio

O mesmo Dó aparece nas duas claves: acima da pauta de fá e abaixo da de
sol. Veja como ele se repete.

```zywny-score
clef: treble
abc: "C D E"
highlight: [C4]
caption: O dó central na clave de sol
```

## Toque nas duas

Leia nas duas pautas. A nota abaixo do Dó central vai para a de fá, as
demais para a de sol. O app não toca a outra mão por você.

```zywny-score
clef: bass
abc: "C D E"
highlight: [C3]
caption: O dó central na clave de fá
```

```zywny-exercise
id: l5-duas-pautas
type: play-notes
title: Nas duas pautas
clef: grand
notes: {random: G2-G4, count: 12}
pass: {accuracy: 90}
```

## O Dó nas duas mãos

Uma sequência curta e fixa para sentir a troca de pauta. Toque com calma,
uma mão de cada vez se precisar.

```zywny-exercise
id: l5-do-central
type: play-notes
title: O Dó nas duas mãos
clef: grand
notes: [C3, C4, E4, G3]
pass: {accuracy: 90}
```
