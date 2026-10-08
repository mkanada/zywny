---
id: pauta-e-clave-de-sol
title: A pauta e a clave de sol
requires: [o-teclado]
---

## Cinco linhas

A música se escreve na **pauta**: cinco linhas e os quatro espaços entre
elas. Conte sempre de baixo para cima: a primeira linha é a de baixo.

Cada nota mora numa linha ou num espaço. Quanto mais alta na pauta, mais
agudo o som. Toque na partitura para ouvir a escada subir.

```zywny-score
clef: treble
abc: "E F G A B c d e f"
caption: Da primeira à quinta linha, passando pelos espaços
```

## A clave de sol

O desenho no começo da pauta é a **clave de sol**. Ela se enrola na
segunda linha e diz: aqui mora o Sol, o Sol logo acima do dó central.

Sabendo onde está o Sol, você acha as vizinhas. O espaço logo acima é o
Lá; o espaço logo abaixo, o Fá. Subir um degrau na pauta é ir para a
branca vizinha da direita.

```zywny-score
clef: treble
abc: "F G A"
highlight: [G4]
caption: Fá, Sol e Lá em volta da segunda linha
```

## O dó central

Abaixo da pauta ainda cabem notas. O dó central fica numa linha curtinha
só dele, a **linha suplementar**. Logo acima dela vem o Ré, encostado na
pauta; na primeira linha, o Mi.

Do dó central ao Sol são cinco notas: Dó, Ré, Mi, Fá e Sol.

```zywny-score
clef: treble
abc: "C D E F G"
highlight: [C4]
caption: Do Dó ao Sol na clave de sol
```

## A posição de Dó

Os dedos têm número, nas duas mãos: polegar 1, indicador 2, médio 3,
anelar 4 e mínimo 5.

Ponha o polegar direito no dó central e um dedo em cada branca até o
Sol: é a **posição de Dó**. Cada nota fica com o seu dedo, e você não
precisa olhar para a mão.

```zywny-keyboard
from: C4
to: C5
mark: [C4, D4, E4, F4, G4]
names: true
caption: "Mão direita: dedo 1 no Dó, dedo 5 no Sol"
```

## Leia e toque

Leia cada nota e toque, com a mão na posição de Dó. Não precisa ser
rápido: precisa ser de primeira na maioria das vezes.

Depois leia a nota destacada e responda pelo botão com o nome dela. Esse
exercício não usa o teclado, só a tela.

```zywny-exercise
id: l2-tocar-do-sol
type: play-notes
title: Toque do Dó ao Sol
clef: treble
notes: {random: C4-G4, count: 12}
accidentals: none
pass: {accuracy: 80}
```

```zywny-exercise
id: l2-nomes-do-sol
type: name-note
title: Que nota é esta
clef: treble
notes: {random: C4-G4, count: 8}
choices: [C, D, E, F, G]
pass: {accuracy: 80}
```
