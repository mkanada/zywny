---
id: armadura
title: Armadura
requires: [acidentes]
---

## Um sustenido no começo

Quando uma música usa sempre Fá sustenido, a partitura não escreve o ♯
em cada Fá: põe um ♯ só, logo depois da clave, na linha do Fá. Isso é a
**armadura**.

A armadura vale para todo Fá, em qualquer altura, até o fim da peça, e
não só até a barra. Com um sustenido na armadura, a música está em **Sol
maior**.

```zywny-score
clef: treble
key: G
time: 4/4
abc: "G A B c | d c B A | G F G2"
highlight: [F#4]
caption: Em Sol maior, o Fá destacado é sustenido, sem sinal nenhum
```

## Um bemol no começo

Com um ♭ na armadura, na linha do Si, todo Si é bemol: a música está em
**Fá maior**.

```zywny-score
clef: treble
key: F
time: 4/4
abc: "F G A B | c B A G | F4"
highlight: [Bb4]
caption: Em Fá maior, todo Si é bemol
```

## Que tom é este

Para saber o tom, olhe a armadura antes da primeira nota. Sem nada, Dó
maior. Um sustenido, Sol maior. Um bemol, Fá maior.

```zywny-exercise
id: l9-que-tom
type: choice
title: Que tom é este
question: Pela armadura, em que tom está esta música?
options: [Dó maior, Sol maior, Fá maior]
answer: Fá maior
image: media/armadura-fa.png
pass: {accuracy: 90, time-limit: 15}
```

## O nome continua o mesmo

A armadura muda a tecla, não o lugar da nota na pauta. Em Sol maior, a
nota na quinta linha toca Fá sustenido, mas ela continua sendo o Fá da
pauta.

Os botões trazem só o nome da linha ou do espaço. Responda pelo lugar da
nota.

```zywny-exercise
id: l9-nomes-em-sol
type: name-note
title: Nomes em Sol maior
clef: treble
key: G
notes: {random: D4-F5, count: 8}
pass: {accuracy: 90}
```

## Toque com a armadura

Agora toque com a armadura valendo. Em Sol maior, todo Fá é a preta à
direita do Fá. Em Fá maior, todo Si é a preta à esquerda do Si.

```zywny-exercise
id: l9-sol-maior
type: play-notes
title: Em Sol maior
clef: treble
key: G
notes: {random: D4-D5, count: 12}
pass: {accuracy: 90}
```

```zywny-exercise
id: l9-fa-maior
type: play-notes
title: Em Fá maior
clef: treble
key: F
notes: {random: C4-C5, count: 12}
pass: {accuracy: 90}
```

## Armaduras com mais acidentes

Uma armadura pode ter mais de um acidente, e todos valem a peça inteira.
Ré maior tem dois sustenidos, Fá e Dó. Si bemol maior tem dois bemóis, Si
e Mi.

Você vai encontrá-las nas peças da biblioteca: leia a armadura antes de
começar.

```zywny-score
clef: treble
key: D
time: 4/4
abc: "D E F G | A B c d"
caption: Ré maior, com Fá e Dó sustenidos
```

```zywny-score
clef: treble
key: Bb
time: 4/4
abc: "B, C D E | F G A B"
caption: Si bemol maior, com Si e Mi bemóis
```
