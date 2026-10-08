---
id: clave-de-fa
title: A clave de fá
requires: [clave-de-sol]
---

## O Fá da quarta linha

Os sons graves, da mão esquerda, se escrevem na **clave de fá**. Os dois
pontinhos dela ficam um acima e outro abaixo da quarta linha: ali mora o
Fá, o Fá logo abaixo do dó central.

```zywny-score
clef: bass
abc: "F,4"
highlight: [F3]
caption: O Fá da quarta linha
```

## Linhas e espaços

Na clave de fá os nomes mudam de lugar. As linhas são **Sol, Si, Ré, Fá,
Lá**; os espaços, **Lá, Dó, Mi, Sol**, sempre de baixo para cima.

Se travar, parta do Fá da clave: o espaço logo acima é o Sol; o logo
abaixo, o Mi.

```zywny-score
clef: bass
abc: "G,, B,, D, F, A,"
caption: "As linhas: Sol, Si, Ré, Fá e Lá"
```

```zywny-score
clef: bass
abc: "A,, C, E, G,"
caption: "Os espaços: Lá, Dó, Mi e Sol"
```

## O dó central, por cima

O dó central também aparece aqui, numa linha suplementar **acima** da
pauta. É a mesma tecla do dó central da clave de sol, só que escrita na
outra pauta.

```zywny-score
clef: bass
abc: "G, A, B, C"
highlight: [C4]
caption: Subindo até o dó central, na clave de fá
```

## A posição de Dó da mão esquerda

A mão esquerda também tem posição de Dó, uma oitava abaixo: dedo 5 no
Dó3 e dedo 1 no Sol3. Na esquerda, o polegar fica do lado agudo.

```zywny-keyboard
from: C3
to: C4
mark: [C3, D3, E3, F3, G3]
names: true
caption: "Mão esquerda: dedo 5 no Dó3, dedo 1 no Sol3"
```

```zywny-exercise
id: l4-posicao-de-do
type: play-notes
title: Do Dó ao Sol, no grave
clef: bass
notes: {random: C3-G3, count: 12}
pass: {accuracy: 90}
```

## Toda a clave de fá

Agora a pauta inteira, do Sol da primeira linha até o dó central. A mão
precisa andar; o exercício espera. Para fixar, são três rodadas aprovadas
seguidas.

```zywny-exercise
id: l4-linhas-fa
type: play-notes
title: Toque no grave
clef: bass
notes: {random: G2-C4, count: 12}
pass: {accuracy: 90, rounds: 3}
```
