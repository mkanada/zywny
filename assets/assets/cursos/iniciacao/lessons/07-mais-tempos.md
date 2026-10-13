---
id: mais-tempos
title: Colcheia, ponto e outros compassos
requires: [figuras-e-pausas]
---

## A colcheia

A **colcheia** vale meio tempo: cabem duas num tempo. Quando andam
juntas, uma barra liga as hastes. Conte "um e, dois e": uma colcheia cai
no número, a outra no "e".

```zywny-score
clef: treble
time: 4/4
abc: "C C/2C/2 C C/2C/2 | C/2C/2 C/2C/2 C2"
caption: Semínimas e colcheias, duas colcheias por tempo
```

## Dois por quatro

Em **2/4**, cada compasso tem dois tempos: conte um, dois, sem parar
entre os compassos. A colcheia também tem pausa, que cala meio tempo.

```zywny-score
clef: treble
time: 2/4
abc: "C C/2C/2 | C/2 z/2 C | C z"
caption: Em 2/4, com pausa de colcheia e de semínima
```

```zywny-exercise
id: l7-colcheias-2-4
type: rhythm
title: Colcheias em 2 por 4
time: 2/4
figures: [quarter, eighth, quarter-rest, eighth-rest]
measures: 4
bpm: 80
pass: {accuracy: 85, speed: 90}
```

## Três por quatro e o ponto

Em **3/4**, cada compasso tem três tempos, como numa valsa.

O **ponto** depois da nota soma metade do valor dela. A mínima pontuada
vale três tempos e enche um compasso de 3/4. A semínima pontuada vale um
tempo e meio, e quase sempre vem com uma colcheia para fechar dois
tempos.

```zywny-score
clef: treble
time: 3/4
abc: "C3 | C2 C | C3/2 C/2 C | C3"
caption: Mínima pontuada, mínima, semínima pontuada e colcheia
```

## A ligadura

A **ligadura** é um arco entre duas notas iguais: toque a primeira e
segure até o fim da segunda, mesmo que ela passe da barra.

O exercício junta o ponto e a ligadura, em 3/4, numa tecla só.

```zywny-score
clef: treble
time: 3/4
abc: "C2 C- | C C2"
caption: A ligadura soma a última semínima do compasso à primeira do outro
```

```zywny-exercise
id: l7-ponto-3-4
type: rhythm
title: O ponto em 3 por 4
time: 3/4
abc: "C2 C | C3/2 C/2 C | C3 | C2 C- | C C2 | C3"
bpm: 80
pass: {accuracy: 85, speed: 90}
```

## Seis por oito

Em **6/8**, conte as colcheias: seis em cada compasso, em dois grupos de
três. A semínima pontuada vale três colcheias; a mínima pontuada, seis.

Esse compasso é só para reconhecer: responda quantos tempos vale cada
figura, contando a colcheia como um.

```zywny-score
clef: treble
time: 6/8
abc: "C/2C/2C/2 C3/2 | C3"
caption: Três colcheias, semínima pontuada e mínima pontuada
```

```zywny-exercise
id: l7-tempos-6-8
type: count-beats
title: Tempos em 6 por 8
time: 6/8
figures: [eighth, dotted-quarter, dotted-half]
count: 8
pass: {accuracy: 90}
```

## Para revisar

Um vídeo para revisar as figuras. Ele mostra também a semicolcheia, que
vale metade da colcheia e fica para depois deste curso.

```zywny-video
link: https://www.youtube.com/watch?v=qjmJQov61rg
caption: "Figuras musicais: semínima, mínima, colcheia e semicolcheia"
```
