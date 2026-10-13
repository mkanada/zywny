---
id: juntando-tudo
title: Juntando tudo
requires: [armadura]
---

## A peça

Até aqui você leu a altura e o ritmo em separado. Agora os dois andam
juntos, nas duas pautas, no começo da
[Ode à Alegria](https://pt.wikipedia.org/wiki/Ode_%C3%A0_Alegria), de
Beethoven, em Dó maior.

A direita canta a melodia na posição de Dó. A esquerda segura uma nota
longa por compasso. Toque na partitura para ouvir a peça inteira.

```zywny-score
file: media/ode-a-alegria.musicxml
caption: Ode à Alegria, 8 compassos em Dó maior
```

## Primeiro, só as notas

Comece pela mão direita, sem se preocupar com o tempo: o app espera cada
nota.

```zywny-exercise
id: l10-ode-direita-notas
type: play-score
title: A Ode, mão direita, só as notas
file: media/ode-a-alegria.musicxml
hand: right
mode: wait
pass: {accuracy: 90}
```

## Agora no ritmo

A mesma mão direita, agora no tempo, com contagem e metrônomo. O
exercício começa no andamento mínimo para passar; quando ficar fácil,
suba a velocidade na barra do exercício.

```zywny-exercise
id: l10-ode-direita
type: play-score
title: A Ode, mão direita
file: media/ode-a-alegria.musicxml
hand: right
mode: realtime
measures: "1-8"
bpm: 80
pass: {accuracy: 85, speed: 75}
```

## A mão esquerda

A esquerda alterna duas notas, uma por compasso: o Dó3 e o Sol logo
abaixo dele. Deixe o dedo 1 no Dó e o 5 no Sol, e conte os quatro tempos
de cada nota.

```zywny-exercise
id: l10-ode-esquerda
type: play-score
title: A Ode, mão esquerda
file: media/ode-a-alegria.musicxml
hand: left
mode: realtime
bpm: 80
pass: {accuracy: 85, speed: 75}
```

## As duas mãos

Junte as mãos primeiro sem relógio: quando duas notas caem juntas, o app
espera as duas. Depois, no ritmo.

Quando passar no último exercício, o curso está completo. Parabéns! Com
o que aprendeu, você já lê as peças mais simples da biblioteca.

```zywny-exercise
id: l10-ode-juntas-notas
type: play-score
title: A Ode, as duas mãos, só as notas
file: media/ode-a-alegria.musicxml
hand: both
mode: wait
pass: {accuracy: 90}
```

```zywny-exercise
id: l10-ode-juntas
type: play-score
title: A Ode, as duas mãos
file: media/ode-a-alegria.musicxml
hand: both
mode: realtime
bpm: 80
pass: {accuracy: 85, speed: 75}
```
