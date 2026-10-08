---
id: o-teclado
title: O teclado
---

## As pretas andam em grupos

Olhe o seu teclado. As teclas pretas se repetem em grupos de **duas** e
de **três**, sempre alternando.

Esses grupos são o mapa do teclado: por eles você se acha sem contar
teclas.

```zywny-keyboard
from: C3
to: C5
caption: Grupos de duas e de três pretas, alternando
```

## Onde está o Dó

A tecla branca logo à esquerda de cada grupo de **duas** pretas é um Dó.
Há um Dó em cada grupo, do começo ao fim do teclado.

```zywny-keyboard
from: C3
to: C5
mark: [C3, C4, C5]
caption: Os Dós, à esquerda de cada grupo de duas pretas
```

## Grave e agudo

Para a esquerda o som fica mais **grave**; para a direita, mais
**agudo**.

Ouça um Dó de cada região, do grave ao agudo. Depois toque os Dós do seu
teclado na mesma ordem.

```zywny-audio
file: media/dos.ogg
caption: Cinco Dós, do grave ao agudo
```

## As brancas têm nome

As brancas seguem sempre a mesma ordem: Dó, Ré, Mi, Fá, Sol, Lá, Si, e
de novo Dó. Dó, Ré e Mi ficam em volta do grupo de duas pretas; Fá, Sol,
Lá e Si, em volta do grupo de três.

```zywny-keyboard
from: C4
to: C5
names: true
caption: As sete brancas, de Dó a Dó
```

Primeiro ache Dó, Ré e Mi; depois todas as brancas, sorteadas. Nestes
dois exercícios vale a tecla em qualquer altura do teclado.

```zywny-exercise
id: l1-achar-do
type: find-key
title: Ache o Dó, o Ré e o Mi
notes: [C4, D4, E4]
octave: any
pass: {accuracy: 80}
```

```zywny-exercise
id: l1-achar-brancas
type: find-key
title: Ache as brancas
notes: {random: C4-B4, count: 10}
octave: any
pass: {accuracy: 80}
```

## O dó central e as oitavas

De um Dó até o próximo é uma **oitava**: as mesmas notas se repetem a
cada oitava, mais graves ou mais agudas.

O Dó do meio do teclado é o **dó central** (num piano de 88 teclas, o
quarto Dó a partir da esquerda). Ele é a sua casa: ache-o pelo grupo de
duas pretas, sem olhar.

```zywny-keyboard
from: C3
to: C5
mark: [C4]
names: true
caption: O dó central, entre a oitava de baixo e a de cima
```

## A oitava certa

Na partitura cada nota é uma tecla só, numa oitava só. Por isso a oitava
tem número: o dó central é o **Dó4**, e as notas dele até o próximo Si
também são 4 (Ré4, Mi4…). A oitava de baixo é a 3; a de cima, a 5.

Agora o nome vem com o número, e só vale a tecla daquela oitava.

```zywny-exercise
id: l1-oitava-certa
type: find-key
title: Na oitava certa
notes: {random: C3-B4, count: 10}
octave: exact
pass: {accuracy: 80}
```
