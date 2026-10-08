---
id: clave-de-sol
title: A clave de sol inteira
requires: [pauta-e-clave-de-sol]
---

## As linhas

Na clave de sol, as cinco linhas são, de baixo para cima: **Mi, Sol, Si,
Ré, Fá**.

De uma linha para a próxima, você pula uma nota: de Mi para Sol, pula o
Fá. No teclado, é pular uma branca.

```zywny-score
clef: treble
abc: "E G B d f"
caption: "As linhas: Mi, Sol, Si, Ré e Fá"
```

## Os espaços

Os quatro espaços são **Fá, Lá, Dó, Mi**. Também aqui, de um espaço para
o próximo, se pula uma nota.

```zywny-score
clef: treble
abc: "F A c e"
caption: "Os espaços: Fá, Lá, Dó e Mi"
```

## Fora da pauta

As notas mais graves ou mais agudas que a pauta usam **linhas
suplementares**, curtinhas, como a do dó central.

Em cima é igual: logo acima da quinta linha vem o Sol, e na primeira
linha suplementar de cima, o Lá.

```zywny-score
clef: treble
abc: "C D E | f g a"
caption: Dó, Ré e Mi embaixo; Fá, Sol e Lá em cima
```

## Linhas e espaços

Toque do dó central ao Sol de cima da pauta: primeiro só notas em linhas,
depois só em espaços. Cada exercício pede duas rodadas aprovadas
seguidas.

Fora da posição de Dó, a mão precisa andar. Mova-a sem pressa: o
exercício espera.

```zywny-exercise
id: l3-linhas
type: play-notes
title: Só linhas
clef: treble
notes: {random: C4-G5, count: 12, only: lines}
pass: {accuracy: 90, rounds: 2}
```

```zywny-exercise
id: l3-espacos
type: play-notes
title: Só espaços
clef: treble
notes: {random: C4-G5, count: 12, only: spaces}
pass: {accuracy: 90, rounds: 2}
```

## Rápido nos nomes

Leia a nota e toque o botão com o nome. Você tem dez segundos por
pergunta; se o tempo acabar, conta como erro e a resposta certa aparece.

```zywny-exercise
id: l3-nomes-rapidos
type: name-note
title: Nomes contra o relógio
clef: treble
notes: {random: C4-A5, count: 10}
pass: {accuracy: 90, time-limit: 10}
```

## Sua primeira melodia

Com a mão na posição de Dó você já toca uma música inteira. Só o Lá passa
do dedo 5: estique o mínimo até ele e volte.

Por enquanto, não se preocupe com quanto dura cada nota: o app espera
você tocar a certa. Se quiser, ouça antes pelo botão de ouvir.

```zywny-exercise
id: l3-brilha-brilha
type: play-score
title: Brilha, brilha, estrelinha
abc: |
  X:1
  T:Brilha, brilha, estrelinha
  M:4/4
  L:1/4
  K:C
  C C G G | A A G2 | F F E E | D D C2 |
  G G F F | E E D2 | G G F F | E E D2 |
  C C G G | A A G2 | F F E E | D D C2 |]
mode: wait
pass: {accuracy: 90}
```
