---
id: figuras-e-pausas
title: Tempo, compasso e figuras
requires: [pauta-dupla]
---

## O pulso

A música anda sobre um pulso regular, como o tique-taque de um relógio.
Cada batida é um **tempo**.

Ouça e conte junto, batendo o pé: um, dois, três, quatro. Aqui o
primeiro tempo de cada grupo soa mais agudo, para você ouvir onde o grupo
começa.

```zywny-audio
file: media/compasso.ogg
caption: Dois grupos de quatro tempos
```

## O compasso

Na pauta, as **barras** cortam a música em **compassos** do mesmo
tamanho. Os dois números do começo são a fórmula de compasso: em 4/4, o
de cima diz que cada compasso tem quatro tempos; o de baixo, que a
semínima vale um tempo.

```zywny-score
clef: treble
time: 4/4
abc: "C C C C | C C C C"
caption: "Dois compassos de 4/4: quatro semínimas em cada um"
```

Às vezes aparece um **C** no lugar do 4/4. É o mesmo compasso, com outro
desenho.

```zywny-score
clef: treble
time: C
abc: "C C C C"
caption: O C vale o mesmo que 4/4
```

## Semibreve, mínima e semínima

A forma da nota diz quanto ela dura. A **semínima** (cheia, com haste)
vale um tempo; a **mínima** (vazada, com haste), dois; a **semibreve**
(vazada, sem haste), quatro: o compasso inteiro.

Segure cada nota até o fim do valor dela, contando os tempos.

```zywny-score
clef: treble
time: 4/4
abc: "C4 | C2 C2 | C C C C"
caption: "Semibreve, mínimas e semínimas: quatro tempos em cada compasso"
```

## O silêncio também conta

Cada figura tem uma **pausa** do mesmo valor: um silêncio que também se
conta. A pausa de semínima cala um tempo; a de mínima, dois; a de
semibreve, o compasso inteiro.

```zywny-score
clef: treble
time: 4/4
abc: "C z C z | C2 z2 | z4 | C4"
caption: Pausas de semínima, de mínima e de semibreve
```

## Quanto vale

Antes de tocar, responda: quantos tempos vale a figura destacada? Pausa
conta igual: diga quanto dura o silêncio. São dez segundos por pergunta.

```zywny-exercise
id: l6-quanto-vale
type: count-beats
title: Quantos tempos
time: 4/4
figures: [whole, half, quarter, whole-rest, half-rest, quarter-rest]
count: 8
pass: {accuracy: 90, time-limit: 10}
```

## Toque no ritmo

Agora toque o dó central no ritmo escrito. O app conta antes de começar,
e o metrônomo marca os tempos até o fim. Toque no começo de cada nota e
fique em silêncio nas pausas.

```zywny-exercise
id: l6-ritmo-basico
type: rhythm
title: Toque no ritmo
time: 4/4
figures: [whole, half, quarter, whole-rest, half-rest, quarter-rest]
measures: 4
bpm: 70
note: C4
pass: {accuracy: 85, speed: 100}
```
