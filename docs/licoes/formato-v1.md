# Formato de curso do zywny — versão 1

Este documento é para quem **escreve** um curso (professor, autor). Você não
precisa saber programar nem ler o código do zywny: um curso é uma pasta de
arquivos de texto. O zywny mostra o conteúdo, roda os exercícios no teclado
MIDI e diz se o aluno passou. O que ele ensina, em que ordem e o que cobra de
cada exercício é decisão sua.

As **chaves** do formato (`type`, `pass`, `notes`…) e os valores
(`play-notes`, `treble`…) são em inglês. O **texto** das lições fica na sua
língua. As mensagens do validador vêm em português.

Para conferir o que escreveu, rode o validador (precisa do Dart instalado):

```
dart run tool/zywny_course.dart validate minha-pasta
```

Ele imprime uma linha por problema — `arquivo:linha: erro: mensagem` — e
termina com código 1 se houver erro. **Avisos** não impedem o curso; **erros**
sim.

## 1. A pasta do curso

```
iniciacao/
  course.md                ← dados do curso + a apresentação
  lessons/
    01-o-teclado.md        ← uma lição por arquivo
    02-pauta-e-clave-de-sol.md
  media/                   ← imagens, áudio e partituras (.musicxml)
```

- `course.md` e a pasta `lessons/` são obrigatórios; `media/` é opcional.
- O nome do arquivo da lição não importa (o número na frente é só para você
  ordenar); quem manda é o `id` dentro dele.
- Todo caminho de arquivo é **relativo à pasta do curso**, com `/`:
  `media/clave-de-sol.png`. Caminhos que saem da pasta (`../x.png`, `/x.png`,
  `https://…`) são erro.
- Arquivos em UTF-8.

## 2. `course.md`

```markdown
---
format: 1
id: iniciacao
title: Primeiros passos ao piano
author: zywny
version: "1"
lessons: [o-teclado, pauta-e-clave-de-sol, clave-de-sol]
---

Neste curso você aprende a ler partitura do zero.
```

| Chave | O que é |
| --- | --- |
| `format` | **Obrigatória.** Sempre `1` (a versão deste documento). Um número maior que o do app é recusado: "Este curso pede uma versão mais nova do zywny." |
| `id` | **Obrigatória.** Identificador do curso (veja "Ids"). O progresso do aluno é guardado por ele. |
| `title` | **Obrigatória.** O nome na tela. |
| `author` | **Obrigatória.** Quem escreveu. |
| `version` | **Obrigatória.** Texto livre (`"1"`, `2026.10`); só é mostrado. Um número sem aspas vale. |
| `lessons` | **Obrigatória.** Os `id`s das lições, **na ordem da tela**. |

O texto depois do front matter é a apresentação do curso. Ele só tem
markdown: marcas `zywny-…` não valem em `course.md`.

**Chave desconhecida é erro** — assim um erro de digitação é pego. O validador
sugere a mais parecida: "chave desconhecida `acuracy` — você quis dizer
`accuracy`?".

## 3. Uma lição

```` markdown
---
id: pauta-e-clave-de-sol
title: A pauta e a clave de sol
requires: [o-teclado]
---

A pauta tem **cinco linhas** e quatro espaços. Quanto mais alta a nota, mais
aguda ela soa.

```zywny-score
clef: treble
abc: "C D E F G"
highlight: [G4]
```

```zywny-exercise
id: ler-do-ao-sol
type: play-notes
title: Toque as notas
clef: treble
notes: {random: C4-G4, count: 12}
pass: {accuracy: 90}
```
````

Front matter da lição:

| Chave | O que é |
| --- | --- |
| `id` | **Obrigatória.** Único no curso e igual ao que está em `lessons` de `course.md`. |
| `title` | **Obrigatória.** O nome na tela. |
| `requires` | Lições que convém fazer antes. Só `id`s de lições **anteriores** na ordem de `lessons`, sem ciclo. É uma sequência **sugerida**: o aluno ainda pode abrir a lição. |

Uma lição em `lessons/` que não está na lista de `course.md` é um **aviso**
(ela não entra no curso).

### Ids

Ids de curso, lição e exercício seguem `^[a-z0-9-]{1,40}$`: de 1 a 40 letras
minúsculas sem acento, números e hífens. São **estáveis**: o progresso do
aluno é guardado por eles. Mudar o texto de uma lição não apaga o progresso;
**mudar o id, sim**. O id de um exercício é único **no curso inteiro**.

## 4. O texto (markdown)

Vale o markdown comum: títulos (`#` a `###`), parágrafos, **negrito**,
*itálico*, listas, citações, linha horizontal, `código em linha`, links e
imagens.

Fica **fora da v1**:

- tabelas;
- HTML — aparece como texto e o validador **avisa**;
- imagem de fora da pasta (erro);
- link que não seja `https://` (erro).

Imagens: `![legenda](media/x.png)`, só da pasta do curso, em `.png`, `.jpg`
ou `.webp`. O arquivo precisa existir.

## 5. Marcas

Uma **marca** é um bloco de código cercado com o nome `zywny-…` e, dentro,
chaves e valores no formato YAML. A marca abre numa linha que é **exatamente**
` ```zywny-nome ` (sem espaço antes) e fecha na próxima linha que é só
` ``` `. Num editor de texto ou no GitHub a lição continua legível: as marcas
aparecem como blocos de código.

Para **mostrar** uma marca como exemplo sem que ela funcione, escreva-a
dentro de um bloco de código maior (quatro crases, ou `~~~`) — como este
documento faz.

Regras do YAML que mais pegam gente:

- `chave: valor`, com espaço depois dos dois-pontos.
- Indente com espaços, **nunca com tabulação**.
- Texto com `:` ou que começa com `[`, `{`, `*` vai entre aspas.
- Verdadeiro e falso são `true` e `false` (`yes` e `no` não valem).
- Para ABC com várias linhas, use `|` e recue as linhas.

### `zywny-score` — uma partitura pequena

O aluno toca nela para ouvir.

````markdown
```zywny-score
clef: treble
abc: "C D E F G"
highlight: [G4]
caption: O Sol na segunda linha
```
````

| Chave | Valor | Padrão |
| --- | --- | --- |
| `abc` | ABC em linha (veja "Partituras") | — |
| `file` | `.musicxml` da pasta | — |
| `clef` | `treble`, `bass` ou `grand` (as duas pautas) | `treble` |
| `key` | tom (veja "Tons e fórmulas de compasso") | sem armadura |
| `time` | fórmula de compasso | `4/4` |
| `highlight` | lista de notas para destacar | nenhuma |
| `caption` | legenda | — |

Informe **`abc` ou `file`** — um dos dois, nunca os dois. `clef`, `key` e
`time` só valem com um `abc` **sem** `X:`; um `abc` com `X:` e um `.musicxml`
já trazem o cabeçalho.

### `zywny-keyboard` — o teclado desenhado

````markdown
```zywny-keyboard
from: C4
to: C5
mark: [C4]
names: true
caption: O dó central
```
````

| Chave | Valor | Padrão |
| --- | --- | --- |
| `from`, `to` | a faixa do teclado, da mais grave para a mais aguda | `C3` a `C5` |
| `mark` | teclas marcadas (dentro da faixa) | nenhuma |
| `names` | `true` escreve o nome em todas as teclas brancas da faixa | `false` |
| `caption` | legenda | — |

### `zywny-audio` — um tocador

````markdown
```zywny-audio
file: media/sol.ogg
caption: O Sol da segunda linha
```
````

`file` (obrigatório): arquivo `.ogg` ou `.mp3` da pasta. `caption` é opcional.

### `zywny-video` — um cartão que abre o vídeo

````markdown
```zywny-video
link: https://www.youtube.com/watch?v=exemplo
caption: Contando em voz alta
```
````

`link` (obrigatório): endereço `https://…`. O zywny não toca o vídeo: abre no
navegador quando o aluno toca no cartão.

## 6. Exercícios — `zywny-exercise`

Todo exercício tem `id`, `type`, `title` e, se quiser, `pass`. As outras
chaves dependem do `type`.

| `type` | O aluno | Precisa de |
| --- | --- | --- |
| `find-key` | vê um nome ("Ré") e toca a tecla | teclado MIDI |
| `play-notes` | lê cada nota na pauta e toca | teclado MIDI |
| `name-note` | lê a nota destacada e toca o botão com o nome | só a tela |
| `rhythm` | toca uma tecla no ritmo escrito | teclado MIDI |
| `count-beats` | toca o botão com quantos tempos vale a figura destacada | só a tela |
| `play-score` | toca uma partitura que você escreveu | teclado MIDI |
| `choice` | responde uma pergunta de múltipla escolha | só a tela |

O zywny **não tem teclado na tela**. Os tipos que pedem teclado MIDI mostram
"Conecte o teclado" quando não há um; os de botões funcionam sem MIDI.

### Notas: `notes`

`notes` aceita uma **lista fixa** ou um **sorteio**:

```yaml
notes: [C4, E4, G4]
notes: {random: C4-G5, count: 12}
notes: {random: C4-G5, count: 12, only: lines}
```

| Chave do sorteio | Valor | Padrão |
| --- | --- | --- |
| `random` | faixa `grave-aguda`, como `C4-G5` (as duas pontas valem) | — (obrigatória) |
| `count` | quantas notas, de 1 a 60 | 12 (10 no `find-key`) |
| `only` | `lines` (só notas em linhas da pauta) ou `spaces` (só espaços) | todas |

Notas se escrevem em notação científica: `C4` é o dó central, `F#4`, `Bb3`
(um sustenido ou um bemol, no máximo). O piano vai de `A0` a `C8`. Na tela o
zywny mostra Dó-Ré-Mi (ou C-D-E, nas configurações); no arquivo é sempre
`C4`.

`only` conta em relação à pauta e é igual nas duas claves; o dó central fica
numa linha (a suplementar). A faixa precisa ter pelo menos duas notas do tipo
pedido.

### `find-key`

````markdown
```zywny-exercise
id: achar-teclas
type: find-key
title: Ache a tecla
notes: {random: C4-B4, count: 10}
octave: any
```
````

| Chave | Valor | Padrão |
| --- | --- | --- |
| `notes` | **obrigatória** | — |
| `octave` | `any` (qualquer oitava serve) ou `exact` (só a oitava escrita) | `any` |

### `play-notes`

````markdown
```zywny-exercise
id: clave-de-fa
type: play-notes
title: Toque as notas na clave de fá
clef: bass
notes: {random: G2-C4, count: 12}
pass: {accuracy: 100, rounds: 3}
```
````

| Chave | Valor | Padrão |
| --- | --- | --- |
| `clef` | `treble`, `bass` ou `grand` | `treble` |
| `key` | tom | sem armadura |
| `notes` | **obrigatória** | — |
| `accidentals` | `none`, `sharps`, `flats` ou `mixed` — que teclas pretas o sorteio usa e como escreve | `none` |

`accidentals` só vale com **sorteio**. Numa lista fixa, escreva a nota com `#`
ou `b` (`F#4`).

### `name-note`

| Chave | Valor | Padrão |
| --- | --- | --- |
| `clef`, `key` | como no `play-notes` | `treble`, sem armadura |
| `notes` | **obrigatória**, **só notas naturais** | — |
| `choices` | letras dos botões, de `A` a `G`, na sua ordem (pelo menos 2) | `[C, D, E, F, G, A, B]` |

Toda nota que o exercício pode usar precisa ter botão em `choices`; senão a
pergunta ficaria sem resposta e o validador avisa.

### `rhythm`

O aluno toca **uma tecla só** (`note`) no ritmo escrito, com contagem e
metrônomo. Escolha **`figures`** (o zywny sorteia o ritmo) **ou `abc`**
(você escreve o ritmo):

````markdown
```zywny-exercise
id: ritmo-basico
type: rhythm
title: Toque no ritmo
figures: [whole, half, quarter, quarter-rest]
measures: 4
bpm: 70
pass: {accuracy: 85, speed: 100}
```
````

| Chave | Valor | Padrão |
| --- | --- | --- |
| `time` | fórmula de compasso | `4/4` |
| `figures` | figuras do sorteio (veja abaixo) | — |
| `measures` | quantos compassos sorteados, de 1 a 8 | `4` |
| `abc` | o ritmo escrito por você | — |
| `bpm` | andamento, de 30 a 240 | `80` |
| `note` | a altura tocada (só no sorteio) | `C4` |

Com `abc`, `figures`, `measures` e `note` não valem (o ritmo é o escrito). Cada
figura precisa caber em um compasso do `time`.

### `count-beats`

| Chave | Valor | Padrão |
| --- | --- | --- |
| `time` | fórmula de compasso | `4/4` |
| `figures` | **obrigatória** | — |
| `count` | quantas perguntas, de 1 a 40 | `8` |

### `play-score`

O aluno toca uma partitura que você escreveu:

````markdown
```zywny-exercise
id: minueto-direita
type: play-score
title: O Minueto, mão direita
file: media/minueto.musicxml
hand: right
mode: realtime
measures: "1-8"
pass: {accuracy: 85, speed: 75}
```
````

| Chave | Valor | Padrão |
| --- | --- | --- |
| `abc` ou `file` | a partitura (um dos dois) | — |
| `hand` | `right`, `left` ou `both` — o que o aluno toca | `both` |
| `mode` | `wait` (o app espera cada nota) ou `realtime` (no andamento, com contagem e metrônomo) | `wait` |
| `bpm` | andamento escrito, de 30 a 240 | o da partitura |
| `measures` | só estes compassos escritos: `5` ou `"5-12"` | a partitura toda |

No `play-score` use um `abc` **completo**, começando por `X:` — esta marca
não tem `clef`, `key` nem `time` para montar o cabeçalho. Escreva
`measures` entre aspas quando for uma faixa.

### `choice`

````markdown
```zywny-exercise
id: quantos-tempos
type: choice
title: Uma pergunta
question: Quantos tempos vale uma mínima em 4/4?
options: [1, 2, 4, Nenhuma das anteriores]
answer: 2
image: media/minima.png
```
````

| Chave | Valor |
| --- | --- |
| `question` | **obrigatória** — o texto da pergunta |
| `options` | **obrigatória** — pelo menos 2, **na ordem em que você escrever** |
| `answer` | **obrigatória** — igual a uma das `options` |
| `image` | uma imagem da pasta (opcional) |
| `abc` | uma partitura pequena em ABC (opcional) |

Use `image` **ou** `abc`, nunca os dois. Há uma pergunta por exercício;
a rodada vale 100% ou 0%.

### Figuras

`figures` aceita: `whole` (semibreve), `half` (mínima), `quarter`
(semínima), `eighth` (colcheia), `dotted-half` (mínima pontuada),
`dotted-quarter` (semínima pontuada) e as pausas `whole-rest`, `half-rest`,
`quarter-rest`, `eighth-rest`. Colcheias sorteadas saem em pares.

## 7. Critérios de aceite: `pass`

`pass` diz quando o aluno passou. Tudo é opcional:

```yaml
pass: {accuracy: 90, rounds: 3}
```

| Chave | Significado | Padrão | Faixa | Vale em |
| --- | --- | --- | --- | --- |
| `accuracy` | porcentagem mínima de acertos numa rodada (nas perguntas e no modo espera, só os acertos **de primeira**) | `90` | 1–100 | todos |
| `rounds` | quantas rodadas aprovadas **seguidas** | `1` | 1–10 | todos |
| `speed` | andamento mínimo, em % do escrito (ou do `bpm`) | `100` | 25–200 | `rhythm` e `play-score` com `mode: realtime` |
| `time-limit` | segundos por pergunta; estourou, conta como erro | sem limite | 1–120 | `find-key`, `name-note`, `count-beats`, `choice` |

`speed` num `play-score` em modo `wait` é erro: "o modo espera não tem
andamento".

## 8. Tons e fórmulas de compasso

`key` aceita os tons maiores `C`, `G`, `D`, `A`, `E`, `B`, `F#`, `C#`, `F`,
`Bb`, `Eb`, `Ab`, `Db`, `Gb`, `Cb` e os menores com `m`: `Am`, `Em`, `Bm`,
`F#m`, `C#m`, `G#m`, `D#m`, `A#m`, `Dm`, `Gm`, `Cm`, `Fm`, `Bbm`, `Ebm`,
`Abm`. Só a armadura importa.

`time` aceita `4/4`, `3/4`, `2/4`, `6/8` e `C`.

## 9. Partituras

Há duas maneiras:

- **ABC em linha** (`abc:`). Se não começa com `X:`, é só o corpo das notas
  e o zywny monta o cabeçalho com `clef`, `key` e `time` da marca. Se começa
  com `X:`, é um ABC completo e `clef`, `key` e `time` ficam proibidos.
- **Arquivo `.musicxml`** da pasta (`file:`).

Os cursos **não são transpostos** pelo zywny: a partitura aparece como você
escreveu.

> O alcance do leitor de ABC (ligaduras, quiálteras, duas vozes) está sendo
> medido no passo I02; limites que apareçam serão escritos aqui. Para duas
> pautas de verdade, use um `.musicxml`.

## 10. Receitas

**Um exercício de clave de fá, três rodadas seguidas sem errar:**

````markdown
```zywny-exercise
id: fa-sem-errar
type: play-notes
title: Clave de fá, sem errar
clef: bass
notes: {random: G2-C4, count: 12}
pass: {accuracy: 100, rounds: 3}
```
````

**Tocar o Minueto em Sol, mão direita, a 75%, com 85%:**

````markdown
```zywny-exercise
id: minueto
type: play-score
title: Minueto, mão direita
file: media/minueto.musicxml
hand: right
mode: realtime
pass: {accuracy: 85, speed: 75}
```
````

## 11. Erros comuns

O validador diz o arquivo e a linha. As mensagens mais comuns:

- `` chave desconhecida `acuracy` — você quis dizer `accuracy`? `` — Corrija a chave (as chaves são em inglês).
- `` marca desconhecida `zywny-exercicio` — você quis dizer `zywny-exercise`? `` — O nome da marca é em inglês.
- `` A marca `zywny-audio` não foi fechada… `` — Falta a linha só com três crases no fim da marca.
- `` YAML inválido: … `` — A linha indicada tem um problema de YAML: colchete sem fechar, `:` no meio do texto sem aspas, tabulação.
- `` falta a chave obrigatória `id`… `` — Toda marca de exercício precisa de `id`, `type` e `title`.
- `` id de exercício repetido `x` (também em …) `` — O id é único no curso; mude um dos dois (e lembre que mudar o id apaga o progresso daquele exercício).
- `` `requires` forma um ciclo: a → b → a `` — Duas lições dependem uma da outra.
- `` `requires` cita a lição `x`, que vem depois… `` — `requires` só aponta para lições anteriores na ordem de `lessons`.
- `` o arquivo `media/x.png` não existe na pasta do curso. `` — Confira o nome e o caminho; ponha o arquivo em `media/`.
- `` o link `http://…` não vale `` — Links do texto só podem ser `https://…`.
- `` o modo espera não tem andamento… `` — Tire `speed` do `pass` ou use `mode: realtime`.
- `` `answer` (`c`) precisa ser igual a uma das `options`: … `` — A resposta é o texto de uma das opções, igual.
- `` um `abc` com `X:` já traz o cabeçalho: tire `clef`… `` — Com ABC completo, o cabeçalho é seu.
- `` `H4` não é uma nota… `` — Notas vão de `C` a `B`, com `#` ou `b`, e a oitava.
- (aviso) `` HTML não é interpretado e aparece como texto. `` — Use markdown em vez de HTML.
