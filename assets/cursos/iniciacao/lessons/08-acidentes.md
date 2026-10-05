---
id: acidentes
title: Acidentes
requires: [mais-tempos]
---

## Sustenido sobe, bemol desce

O sustenido sobe meio tom. O bemol desce meio tom. Eles moram antes da
nota, na mesma linha ou espaço.

Veja o Sol sustenido e toque. Depois compare com o Sol natural.

```zywny-score
clef: treble
abc: "G ^G G|"
highlight: [G4]
caption: Sol, Sol sustenido e Sol de novo
```

## O bequadro anula

O bequadro anula o acidente até a barra do compasso. Passou da barra, a
nota volta ao normal.

Nunca saem Mi sustenido nem Dó bemol com os nomes que usamos aqui: o
sorteio evita esses casos.

```zywny-score
clef: treble
abc: "B _B B|"
highlight: [B4]
caption: Si, Si bemol e Si de novo
```

## Vale até a barra

Um acidente vale até a barra, como na partitura de verdade. Na mesma
compasso a nota continua alterada sem precisar escrever de novo.

```zywny-score
clef: treble
abc: "C ^C =C|"
highlight: [C4]
caption: Dó, Dó sustenido e Dó natural na mesma barra
```

## Toque com sustenidos

Só teclas com sustenido no sorteio, em média metade das notas. O resto
são naturais, para você ver o bequadro aparecer.

```zywny-exercise
id: l8-sustenidos
type: play-notes
title: Com sustenidos
clef: treble
notes: {random: C4-G4, count: 12}
accidentals: sharps
pass: {accuracy: 90}
```

## Toque com bemóis

Agora com bemóis. A mesma lógica, o mesmo cuidado com a barra.

```zywny-exercise
id: l8-bemois
type: play-notes
title: Com bemóis
clef: treble
notes: {random: C4-G4, count: 12}
accidentals: flats
pass: {accuracy: 90}
```

## Misturado e o bequadro

Sustenidos e bemóis juntos, duas rodadas seguidas. Depois responda o que
o bequadro faz.

```zywny-exercise
id: l8-misturados
type: play-notes
title: Misturado
clef: treble
notes: {random: C4-G4, count: 12}
accidentals: mixed
pass: {accuracy: 90, rounds: 2}
```

```zywny-exercise
id: l8-bequadro
type: choice
title: Para que serve o bequadro
question: O que o bequadro faz?
options: [Anula o acidente até a barra, Sobe meio tom, Desce meio tom]
answer: Anula o acidente até a barra
abc: "C ^C =C"
pass: {accuracy: 90, time-limit: 20}
```
