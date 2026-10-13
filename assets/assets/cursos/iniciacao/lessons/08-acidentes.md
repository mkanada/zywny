---
id: acidentes
title: Acidentes
requires: [mais-tempos]
---

## Tom e meio tom

De uma tecla para a vizinha mais próxima, preta ou branca, a distância é
**meio tom**. Dois meios tons fazem um **tom**: de Dó para Ré é um tom,
com a preta no meio.

Entre Mi e Fá, e entre Si e Dó, não há preta: ali, de branca para branca,
já é meio tom.

```zywny-keyboard
from: C4
to: C5
mark: [E4, F4, B4, C5]
names: true
caption: "Mi e Fá, Si e Dó: meio tom sem preta no meio"
```

## Sustenido e bemol

O **sustenido** (♯) sobe a nota meio tom; o **bemol** (♭) desce meio
tom. O sinal vem antes da nota, na mesma linha ou espaço dela.

Quase sempre isso leva a uma tecla preta. A preta entre Fá e Sol tem dois
nomes: Fá sustenido e Sol bemol. Ouça: a segunda e a quarta nota soam
iguais.

```zywny-score
clef: treble
abc: "F ^F G _G"
caption: Fá, Fá sustenido, Sol e Sol bemol
```

## Vale até a barra

O acidente vale até a barra do compasso: a mesma nota, de novo no mesmo
compasso, continua alterada, sem precisar do sinal. Passou da barra, ela
volta ao natural.

```zywny-score
file: media/vale-ate-a-barra.musicxml
caption: O terceiro Fá também é sustenido; depois da barra, o Fá é natural
```

## O bequadro

O **bequadro** (♮) desfaz o acidente antes da barra: a nota volta a ser
natural ali mesmo.

```zywny-score
clef: treble
abc: "C ^C =C2"
caption: Dó, Dó sustenido e Dó natural de novo, com bequadro
```

## Leia com acidentes

Nestes exercícios, em média metade das notas é uma tecla preta: primeiro
só com sustenidos, depois só com bemóis, depois misturados. Lembre que o
sinal vale até a barra, e que o bequadro aparece quando a nota volta a
ser natural.

```zywny-exercise
id: l8-sustenidos
type: play-notes
title: Com sustenidos
clef: treble
notes: {random: C4-G4, count: 12}
accidentals: sharps
pass: {accuracy: 90}
```

```zywny-exercise
id: l8-bemois
type: play-notes
title: Com bemóis
clef: treble
notes: {random: C4-G4, count: 12}
accidentals: flats
pass: {accuracy: 90}
```

```zywny-exercise
id: l8-misturados
type: play-notes
title: Misturado
clef: treble
notes: {random: C4-G4, count: 12}
accidentals: mixed
pass: {accuracy: 90, rounds: 2}
```

## Para que serve o bequadro

Uma pergunta para fechar a lição.

```zywny-exercise
id: l8-bequadro
type: choice
title: Para que serve o bequadro
question: O que o bequadro faz com a terceira nota?
options: ["Anula o sustenido, e a nota volta ao natural", Sobe meio tom, Desce meio tom]
answer: "Anula o sustenido, e a nota volta ao natural"
abc: "C ^C =C2"
pass: {accuracy: 90, time-limit: 20}
```
