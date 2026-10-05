---
id: clave-de-fa
title: A clave de fá
requires: [clave-de-sol]
---

## O Fá da quarta linha

A clave de fá marca o Fá na quarta linha, contando de baixo para cima.

Ela cuida dos graves: a mão esquerda mora aqui. O desenho mostra onde
fica esse Fá.

```zywny-score
clef: bass
abc: "G, A, B, C"
highlight: [F3]
caption: A região grave e o Fá da quarta linha
```

![A clave de fá](media/clave-de-fa.png)

## Linhas e espaços no grave

As linhas na clave de fá são Sol, Si, Ré, Fá e Lá. Os espaços são Lá, Dó,
Mi e Sol.

É a mesma lógica da clave de sol, só que mais grave. Veja, ouça e toque.

```zywny-keyboard
from: C3
to: C4
mark: [C4]
names: true
caption: O dó central visto do grave
```

## Toque no grave

Toque as notas na clave de fá, do Sol grave ao Dó central. Três rodadas
seguidas sem errar para fixar.

```zywny-exercise
id: l4-linhas-fa
type: play-notes
title: Toque no grave
clef: bass
notes: {random: G2-C4, count: 12}
pass: {accuracy: 90, rounds: 3}
```

## A oitava certa

Agora ache a tecla na oitava exata, não em qualquer oitava. O dó central
conta como referência: ele está marcado no desenho acima.

```zywny-exercise
id: l4-oitava-certa
type: find-key
title: Na oitava exata
notes: {random: C3-B3, count: 8}
octave: exact
pass: {accuracy: 90, time-limit: 15}
```
