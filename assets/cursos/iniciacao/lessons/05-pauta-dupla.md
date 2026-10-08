---
id: pauta-dupla
title: A pauta dupla
requires: [clave-de-sol, clave-de-fa]
---

## Duas pautas de mãos dadas

O piano se lê em duas pautas ao mesmo tempo, unidas por uma chave. Em
cima, a clave de sol, da mão direita; embaixo, a clave de fá, da
esquerda.

Leia as duas juntas, da esquerda para a direita. Notas uma em cima da
outra soam juntas.

![A pauta dupla](media/pauta-dupla.png)

## O dó central no meio

Entre as duas pautas fica o dó central. Ele pode aparecer em qualquer
uma: na linha suplementar abaixo da pauta de sol ou na de cima da pauta
de fá. É sempre a mesma tecla.

```zywny-score
clef: treble
abc: "C4"
highlight: [C4]
caption: O dó central na pauta de sol
```

```zywny-score
clef: bass
abc: "C4"
highlight: [C4]
caption: O mesmo Dó na pauta de fá
```

## As duas mãos em posição de Dó

Ponha as duas mãos em posição de Dó: a esquerda do Dó3 ao Sol3, a direita
do dó central ao Sol4. Entre os dois polegares sobram só o Lá e o Si.

Nos exercícios, o que fica abaixo do dó central vem na pauta de fá, para
a esquerda. O dó central e o que fica acima vêm na pauta de sol, para a
direita.

```zywny-exercise
id: l5-do-mi-sol
type: play-notes
title: Dó, Mi e Sol nas duas mãos
clef: grand
notes: [C3, E3, G3, C4, E4, G4, E4, C4, G3, E3, C3]
pass: {accuracy: 90}
```

```zywny-exercise
id: l5-duas-pautas
type: play-notes
title: Nas duas pautas
clef: grand
notes: {random: C3-G4, count: 12}
pass: {accuracy: 90}
```
