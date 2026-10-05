---
id: armadura
title: Armadura
requires: [acidentes]
---

## Um sustenido no começo

A armadura mora no começo da pauta e vale a peça inteira. Em Sol maior o
Fá é sempre sustenido, sem precisar escrever.

Veja a figura e toque as notas do tom. O Fá que sair no sorteio já soa
sustenido.

![Armadura de Sol maior](media/armadura-sol.png)

```zywny-score
clef: treble
key: G
time: 4/4
abc: "G A B c"
caption: Sol maior tem um sustenido
```

## Um bemol no começo

Em Fá maior o Si é sempre bemol. A mesma ideia, do outro lado.

![Armadura de Fá maior](media/armadura-fa.png)

```zywny-score
clef: treble
key: F
time: C
abc: "F G A Bb"
caption: Fá maior em compasso C
```

## Dois acidentes

Ré maior tem dois sustenidos. Si bemol maior tem dois bemóis. O sorteio
usa as notas do tom: você ouve a armadura valendo.

```zywny-score
clef: treble
key: D
time: 4/4
abc: "D E F# G"
caption: Ré maior tem dois sustenidos
```

```zywny-score
clef: treble
key: Bb
time: 4/4
abc: "Bb C D Eb"
caption: Si bemol maior tem dois bemóis
```

## Toque em Sol e Fá

Duas sequências no tom, uma com um sustenido e outra com um bemol. Sem
pressa: o ouvido aprende a armadura antes dos dedos.

```zywny-exercise
id: l9-sol-maior
type: play-notes
title: Em Sol maior
clef: treble
key: G
notes: {random: C4-G4, count: 12}
pass: {accuracy: 90}
```

```zywny-exercise
id: l9-fa-maior
type: play-notes
title: Em Fá maior
clef: treble
key: F
notes: {random: C4-G4, count: 12}
pass: {accuracy: 90}
```

## Nomes no tom

Leia a nota com a armadura valendo e toque o botão com o nome. O Fá que
você vê já soa sustenido, mas o nome continua Fá.

```zywny-exercise
id: l9-nomes-em-sol
type: name-note
title: Nomes em Sol maior
clef: treble
key: G
notes: {random: C4-G4, count: 8}
pass: {accuracy: 90}
```

## A peça em Ré

Toque a partitura que o professor escreveu, em Ré maior, no modo espera.
O app espera cada nota: sem andamento, sem pressa.

```zywny-exercise
id: l9-peca-em-re
type: play-score
title: A peça em Ré
abc: |
  X:1
  T:Peca em Re
  M:4/4
  L:1/4
  K:D
  D E F# G|A B A G|
hand: right
mode: wait
pass: {accuracy: 90}
```

## Quantos acidentes

Responda quantos sustenidos tem Sol maior, olhando a figura. Quinze
segundos por pergunta.

```zywny-exercise
id: l9-quantos-acidentes
type: choice
title: Quantos sustenidos
question: Quantos sustenidos tem Sol maior?
options: [0, 1, 2]
answer: 1
image: media/armadura-sol.png
pass: {accuracy: 90, time-limit: 15}
```
