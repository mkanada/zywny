# I00 — Lições de terceiros e o curso inicial: especificação e índice da fase I

O zywny vira uma **plataforma de lições**. Um professor escreve um curso em
**markdown com marcas**: o texto, as figuras, o áudio, o link de vídeo e os
exercícios com seus critérios de aceite. O zywny apresenta o conteúdo, roda o
exercício no teclado MIDI e diz se a pessoa passou. A sequência, as
explicações e o que se cobra ficam com o autor.

O primeiro curso escrito nesse formato é o **curso inicial** (teclado, pauta,
claves, notas, acidentes e tempos). Ele não tem caminho especial no código:
é o cliente número um da plataforma e o seu teste de aceite.

Este arquivo é a especificação (proposta em 2026-10-04; **decisões D-LIC-\*
tomadas pelo usuário em 2026-10-04**) e o índice dos passos I01–I13. Quem
executa um passo lê o `README.md`, **este arquivo** e o arquivo do passo.

Prefixo **I** (de iniciação): não colide com os prefixos do zywny nem com os
do bridge (F/S/R/A/E/P/G).

## A divisão de papéis

| O autor (professor) decide | O zywny garante |
| --- | --- |
| Os cursos, as lições e a ordem (quem depende de quem) | Mostrar texto, imagem, partitura, áudio e link de vídeo no celular, na Web e no desktop |
| O texto das explicações | Um conjunto fixo de **tipos de exercício**, cada um com seus parâmetros |
| Qual tipo de exercício, com quais notas, ritmos ou partitura | Gerar a rodada (partitura sorteada ou a do autor), tocar, ouvir o teclado |
| Os critérios de aceite (precisão, andamento, rodadas, tempo por pergunta) | Avaliar com as regras do treino de hoje e guardar o progresso |
| A mídia que acompanha | Validar o curso e apontar o erro pela linha, antes de chegar ao aluno |

O que não está na coluna da direita **não existe na plataforma**: o autor não
programa, não escreve HTML e não busca nada na rede sem a pessoa tocar num
link.

**Quem publica** (D-LIC-CONFIANCA): só cursos que **o usuário assina**, com a
mesma chave das bibliotecas (D-BIB-CIFRA). O professor escreve a pasta,
confere no modo rascunho (I12) e manda para o usuário, que gera o pacote. O
app instalado nunca instala curso sem assinatura.

## O formato (v1)

As chaves e os valores do formato são **em inglês** (D-LIC-IDIOMA); o texto
das lições fica na língua do autor (o curso inicial, em português). A
especificação para professores ([`docs/licoes/formato-v1.md`](../licoes/formato-v1.md),
escrita no I01) é em português e é a referência; a tabela abaixo é o resumo.

Um curso é uma pasta. Na distribuição, a pasta vira um pacote `.zywny` (I04).

```
iniciacao/
  course.md                ← front matter do curso + a apresentação
  lessons/
    01-o-teclado.md
    02-pauta-e-clave-de-sol.md
    …
  media/                   ← imagens, áudio, partituras (.musicxml)
```

`course.md`:

```markdown
---
format: 1
id: iniciacao
title: Primeiros passos ao piano
author: zywny
version: "1"
lessons: [o-teclado, pauta-e-clave-de-sol, clave-de-sol, clave-de-fa, …]
---

Neste curso você aprende a ler partitura do zero.
```

Uma lição (`lessons/02-pauta-e-clave-de-sol.md`):

````markdown
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

A clave de sol marca o **Sol** na segunda linha.

![A clave de sol](media/clave-de-sol.png)

```zywny-audio
file: media/sol.ogg
caption: O Sol da segunda linha
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

Regras do formato:

- **Markdown comum** para o texto: títulos (`#` a `###`), parágrafos,
  negrito, itálico, listas, citações, linha horizontal, código em linha,
  links e imagens. Fica fora da v1: tabelas, HTML (aparece como texto e o
  validador avisa), imagem de fora da pasta.
- **Marcas = blocos cercados ` ```zywny-… ` com corpo YAML**
  (D-LIC-MARCAS). A marca abre numa linha que é exatamente ` ```zywny-nome `
  na coluna 0 e fecha na próxima linha que é exatamente ` ``` `. Num editor ou
  no GitHub a lição continua legível: as marcas aparecem como blocos de
  código.
- O front matter do curso traz `format: 1`. **Chave desconhecida é erro** no
  validador (pega erro de digitação); `format` maior que o do app é recusado
  com "atualize o zywny".
- Ids (de curso, lição e exercício) seguem `^[a-z0-9-]{1,40}$` e são
  estáveis: o progresso é guardado por eles. Mudar o texto de uma lição não
  apaga o progresso; mudar o id, sim. Id de exercício é único **no curso**.
- Notas no arquivo em notação científica: `C4` = dó central, `F#4`, `Bb3`
  (um sustenido ou um bemol no máximo). Na tela, Dó-Ré-Mi por padrão
  (D-LIC-NOMES).
- Partituras: **ABC em linha** (`abc:`) ou **arquivo `.musicxml`** da pasta
  (`file:`) (D-LIC-NOTACAO). Um `abc:` que não começa com `X:` é só o corpo:
  o app monta o cabeçalho com `clef`, `key` e `time` (I02). Um `abc:` com
  `X:` é ABC completo e as três chaves ficam proibidas.
- Os cursos **não são transpostos** pela fase Q: a partitura de uma lição
  aparece sempre como o autor escreveu (D-TRP-LICOES fica sem uso na v1).

### Marcas de conteúdo

| Marca | Mostra | Chaves |
| --- | --- | --- |
| `zywny-score` | Uma partitura pequena, com toque para ouvir | `abc` **ou** `file`; `clef` (`treble`\|`bass`; sem `grand`: o ABC não faz duas pautas, I02), `key`, `time`, `highlight` (notas), `caption` |
| `zywny-keyboard` | O teclado desenhado, com teclas marcadas | `from`, `to` (faixa, padrão C3–C5), `mark` (notas), `names` (`true`\|`false`), `caption` |
| `zywny-audio` | Um tocador | `file` (`.ogg`/`.mp3` da pasta), `caption` |
| `zywny-video` | Um cartão que abre o vídeo no navegador (D-LIC-VIDEO) | `link` (`https://…`), `caption` |
| imagem markdown | A imagem | `![legenda](media/x.png)` — `.png`, `.jpg`, `.webp`, só da pasta |

`key`: nome do tom maior (`C`, `G`, `D`, `A`, `E`, `B`, `F#`, `C#`, `F`,
`Bb`, `Eb`, `Ab`, `Db`, `Gb`, `Cb`) ou menor com `m` (`Am`, `Em`, …) — só a
armadura importa. `time`: `4/4`, `3/4`, `2/4`, `6/8`, `C`.

### Marca de exercício e tipos

`zywny-exercise` com `id`, `type`, `title`, as chaves do tipo e `pass`.

| `type` | O aluno | Entrada | Modo | Chaves do tipo |
| --- | --- | --- | --- | --- |
| `find-key` | Vê um nome ("Ré") e toca a tecla | MIDI | Pergunta a pergunta | `notes`, `octave` (`any`\|`exact`) |
| `play-notes` | Lê cada nota na pauta e toca | MIDI | Espera (T02) | `clef`, `key`, `notes`, `accidentals` (`none`\|`sharps`\|`flats`\|`mixed`) |
| `name-note` | Lê a nota destacada e toca o botão com o nome | botões | Pergunta a pergunta | `clef`, `key`, `notes` (só naturais), `choices` |
| `rhythm` | Toca uma tecla no ritmo escrito | MIDI | Tempo real (T03), contagem e metrônomo | `time`, `figures` + `measures` (sorteio) **ou** `abc`; `bpm`, `note` |
| `count-beats` | Toca o botão com quantos tempos vale a figura destacada | botões | Pergunta a pergunta | `time`, `figures`, `count` |
| `play-score` | Toca uma partitura do autor | MIDI | Espera ou tempo real | `abc` **ou** `file`; `hand` (`right`\|`left`\|`both`), `mode` (`wait`\|`realtime`), `bpm`, `measures` |
| `choice` | Responde uma pergunta de múltipla escolha | botões | Pergunta a pergunta | `question`, `options`, `answer`, `image` ou `abc` (opcional) |

`notes` aceita lista fixa (`[C4, E4, G4]`) ou sorteio
(`{random: C4-G5, count: 12, only: lines}`; `only`: `lines`\|`spaces`,
relativo à clave). `figures`: `whole`, `half`, `quarter`, `eighth`,
`dotted-half`, `dotted-quarter` e as pausas `whole-rest`, `half-rest`,
`quarter-rest`, `eighth-rest` (colcheias sorteadas saem em pares).

**Sem teclado na tela** (D-LIC-SEM-TECLADO): os tipos com entrada MIDI pedem
"Conecte o teclado" quando não há teclado; os de botões (`name-note`,
`count-beats`, `choice`) funcionam sem MIDI. A Web no Safari/iOS (sem Web
MIDI) fica só com os de botões.

### Critérios de aceite (`pass`)

| Chave | Significado | Padrão | Vale em |
| --- | --- | --- | --- |
| `accuracy` | Porcentagem mínima numa rodada (`hits * 100 ~/ total`, como o J02; nas perguntas e no modo espera, acertos **de primeira**) | 90 | todos |
| `rounds` | Quantas rodadas aprovadas, **seguidas** | 1 | todos |
| `speed` | Andamento mínimo, em % do escrito (ou do `bpm`) | 100 | `rhythm`, `play-score` com `mode: realtime` |
| `time-limit` | Segundos por pergunta; estourou, conta como erro | sem limite | `find-key`, `name-note`, `count-beats`, `choice` |

A mão (`hand`) é **chave do tipo** `play-score`, não de `pass`: ela diz o
que se toca, e a rodada só existe naquela mão.

Dois exemplos do que um professor escreve, sem código novo:

- "Toque o Minueto em Sol, mão direita, a 75%, com 85%":
  `type: play-score`, `file: media/minueto.musicxml`, `hand: right`,
  `mode: realtime`, `pass: {accuracy: 85, speed: 75}`.
- "Três rodadas seguidas de clave de fá sem errar":
  `type: play-notes`, `clef: bass`, `pass: {accuracy: 100, rounds: 3}`.

As escolhas do primeiro plano (D-INI-ORDEM, D-INI-APROVACAO, D-INI-OITAVA,
D-INI-CURRICULO) deixam de ser decisões do app: viram `requires`, `pass`,
`octave` e o conteúdo do curso, nas mãos do autor.

## O curso inicial como teste da plataforma

Cinco regras fazem do curso inicial o teste de aceite do formato e do motor.

1. **Sem atalho.** O curso inicial é uma pasta no formato v1 (em
   `assets/cursos/iniciacao/`, embutida no app — D-LIC-INICIAL), lida pelo
   mesmo leitor que um curso de terceiros. Se ele precisa de algo que o
   formato não tem, o formato ganha a chave (documentada na especificação),
   e o curso usa a chave. Proibido `if (curso == 'iniciacao')`.
2. **Cobertura do formato.** Um teste (`test/course_coverage_test.dart`) lê o
   curso inicial e confere que **toda** marca, **todo** tipo de exercício e
   **toda chave** do vocabulário (inclusive as de `pass`) aparecem ao menos
   uma vez. A lista vem das tabelas do validador, não de uma cópia: chave
   nova sem uso no curso inicial reprova o teste. Assim o curso é também o
   exemplo vivo para os professores.
3. **Aluno simulado.** Para cada exercício do curso, um teste roda uma rodada
   com semente fixa e um teclado MIDI falso (ou toques falsos nos botões):
   tocando tudo certo, aprova; errando acima do limite, reprova; abaixo do
   `speed` pedido, reprova pelo andamento. É o teste de ponta a ponta dos
   critérios, sem aparelho.
4. **Cursos quebrados.** `test/fixtures/cursos/` traz cursos com erros de
   propósito (marca desconhecida, YAML inválido, arquivo ausente, `requires`
   circular, ABC que não renderiza, id repetido, …). Cada um tem a mensagem
   esperada do validador, com arquivo e linha. É o que o professor vai ver.
5. **Um curso de fora.** Antes de fechar a fase, o usuário escreve (ou
   encomenda) uma lição curta, sem olhar o código, só com a especificação
   para professores e o modo rascunho. O que ele tropeçar vira correção na
   especificação ou no validador.

O conteúdo do curso inicial cresce junto com a plataforma: cada passo que
traz um tipo de exercício escreve as lições que o usam (tabela dos passos).

### Currículo do curso inicial

| # | Lição (`id`) | Explica | Exercícios | Exercita da plataforma |
| --- | --- | --- | --- | --- |
| 1 | `o-teclado` | Grupos de 2 e 3 pretas; o Dó; grave e agudo; as brancas; a oitava e o dó central (Dó4) | `find-key` (`octave: any`), `find-key` com `octave: exact` | texto, `zywny-keyboard` (`mark`, `names`, `from`/`to`), `zywny-audio`, `find-key` |
| 2 | `pauta-e-clave-de-sol` | 5 linhas, 4 espaços; a clave de sol; o dó central na linha suplementar; os dedos e a posição de Dó | `play-notes` C4–G4, `name-note` com `choices` | `zywny-score` com `abc` e `highlight`, sorteio |
| 3 | `clave-de-sol` | Linhas e espaços da clave de sol; linhas suplementares; a primeira melodia | `play-notes` C4–G5 `only: lines`/`only: spaces`, `name-note` com `time-limit`, `play-score` com `abc` | `rounds`, `time-limit`, `mode: wait` |
| 4 | `clave-de-fa` | O Fá na 4ª linha; linhas e espaços; o dó central por cima; a posição de Dó da esquerda | `play-notes` C3–G3 e G2–C4 | `clef: bass` |
| 5 | `pauta-dupla` | Chave, as duas claves, o dó central entre elas, as duas mãos em posição de Dó | `play-notes` nas duas pautas (lista fixa e sorteio) | imagem, `clef: grand`, `requires` com duas lições |
| 6 | `figuras-e-pausas` | Pulso, compasso e barra, 4/4 e C; semibreve, mínima, semínima e as pausas | `count-beats`, `rhythm` sorteado | `figures`, `measures`, `bpm`, `note`, `speed`, `time: C`, metrônomo |
| 7 | `mais-tempos` | Colcheia; 2/4; ponto e 3/4; ligadura; 6/8 só para reconhecer | `rhythm` sorteado, `rhythm` com `abc`, `count-beats` em 6/8 | `zywny-video`, `time` |
| 8 | `acidentes` | Tom e meio tom; sustenido, bemol, bequadro; vale até a barra | `play-notes` com `accidentals: sharps`, `flats` e `mixed`; `choice` | `accidentals`, `zywny-score` com `file`, `choice` com `abc` |
| 9 | `armadura` | Armadura de um sustenido e de um bemol; que tom é; dois acidentes, só para reconhecer | `choice` com `image`, `name-note` com `key`, `play-notes` com `key` | `key` |
| 10 | `juntando-tudo` | Altura e ritmo ao mesmo tempo, nas duas pautas | `play-score` de um `.musicxml`: direita só as notas e no ritmo, esquerda, as duas mãos só as notas e no ritmo | `file`, `hand`, `measures`, `mode`, link |

## O que já existe e será reaproveitado

| Peça | Onde | Uso |
| --- | --- | --- |
| Render de partitura em bytes, nativo e Web | `ScoreRenderRequest` (`lib/render/score_renderer.dart` L14: `source: Uint8List`, `fileName`) | Partituras das marcas e dos exercícios |
| Leitor de ABC no Verovio | `verovio/src/ioabc.cpp` no fork (1820 linhas; `Toolkit` detecta ABC quando o texto começa com `X:` ou `%a`, `src/toolkit.cpp` ~L212) | `abc:` em linha, sem escrever conversor. **A conferir em I02:** alcance (ligaduras, quiálteras, duas vozes, `%%score`) e se o `midi.json` sai certo |
| Modo espera e tempo real, passagem única | `PracticeController` (`lib/practice/practice_controller.dart` L39; `range` + `onRangeDone` + `stageResult` do J04) | `play-notes`, `rhythm`, `play-score` |
| Contagem, metrônomo | `lib/audio/metronome.dart`, `lib/practice/count_in_overlay.dart` | `rhythm`, `play-score` |
| Avaliação e porcentagem | `StageResult`, `WaitTally` (`lib/trail/stage_result.dart`, J02) | `accuracy` (com o limiar do autor, não o `kTrailPassAccuracy`) |
| Progresso por id | `TrailProgress`/`TrailProgressStore` (`lib/trail/trail_progress.dart`) | Modelo do progresso por curso |
| Pacote `.zywny` | `lib/library/library_envelope.dart`, `library_package.dart`, `library_installer.dart`, `library_blob_store*.dart` (B01–B05) | Distribuir cursos, com a mesma chave (D-LIC-CONFIANCA) |
| Teclado desenhado | `PianoKeyboardPainter` (`lib/midi/piano_keyboard.dart`, 88 teclas fixas, sem toque) | `zywny-keyboard` (ganha faixa e marcas) |
| Entrada de notas | `MidiInputService`, `PlayedNote` (`lib/midi/midi_input_service.dart` L15–L50) | Todos os tipos com MIDI |
| Teclado MIDI falso dos testes | `FakeMidiInput`, `FakeSoundEngine` (`test/practice_controller_test.dart` L32–L100) | Aluno simulado |
| Conectar o teclado | U15 (`lib/midi/midi_device_picker.dart`) | "Conecte o teclado" nos tipos com MIDI |

O que **não** existe e entra como dependência: `yaml` (hoje só transitivo),
`markdown` (Dart puro; o app desenha os widgets — I05), `url_launcher` (link
de vídeo e links do texto), tocar áudio de arquivo (I05 escolhe e mede o
pacote nas quatro plataformas).

O modo "ritmo com qualquer tecla" (T05) saiu no commit `bb39786`. Por isso o
tipo `rhythm` toca **uma altura só** escrita na pauta (`note`, padrão C4) e
usa o tempo real de hoje.

## Decisões

Tomadas pelo usuário em 2026-10-04.

| Id | Pergunta | Decisão |
| --- | --- | --- |
| D-LIC-MARCAS | Sintaxe das marcas | Blocos cercados ` ```zywny-… ` com YAML |
| D-LIC-IDIOMA | Chaves e valores do formato em português ou inglês? | **Inglês** (`type: play-notes`, `pass: {accuracy: 90}`); o texto das lições na língua do autor; a especificação para professores em português |
| D-LIC-CONFIANCA | Quem pode publicar um curso? | **Só cursos que o usuário assina**, com a chave das bibliotecas (D-BIB-CIFRA). Sem curso de terceiros sem assinatura no app instalado |
| D-LIC-VIDEO | Vídeo no curso | **Só `link`** na v1 (abre no navegador/YouTube); arquivo de vídeo no pacote fica para uma v2 |
| D-LIC-NOTACAO | Notação em linha | ABC em linha + arquivos `.musicxml`; sem notação própria |
| D-LIC-AUTORIA | Como o professor vê a lição enquanto escreve | Validador na linha de comando + **modo rascunho no desktop e na Web**: "Abrir pasta de curso", faixa "rascunho, não verificado", Recarregar, nada instalado, progresso só na memória (I12). No Android, não |
| D-LIC-INICIAL | O curso inicial vem no app ou como pacote? | **No app** (`assets/cursos/iniciacao/`), lido pelo mesmo leitor de uma pasta de terceiros |
| D-LIC-NOMES | Nomes das notas na tela | Dó-Ré-Mi por padrão, opção C-D-E nas configurações; o arquivo sempre usa C4 |
| D-LIC-SEM-TECLADO | Os exercícios funcionam sem teclado MIDI? | **Não há teclado na tela.** Os tipos que tocam notas exigem MIDI; os de botões (`name-note`, `count-beats`, `choice`) funcionam sem ele. O I06 foi dispensado |
| D-LIC-ENTRADA | Onde ficam os cursos no app | Um item "Cursos" na biblioteca e o cartão do curso inicial na tela sem biblioteca |

## Passos

| Passo | Título | Depende de | Lições do curso inicial que fecha | Status |
| --- | --- | --- | --- | --- |
| [I01](I01-formato-e-validador.md) | Especificação v1 para professores, leitor e validador (Dart puro), `zywny_course validate` | — | — (fixtures quebradas) | **concluído** |
| [I02](I02-partituras-das-licoes.md) | Partituras: ABC no Verovio (alcance), cabeçalho ABC, gerador de MusicXML das rodadas, tempo de render | I01 | — | **concluído** (falta medir no celular) |
| [I03](I03-motor-de-exercicios.md) | Motor de exercícios: rodada, `pass`, `play-notes` em modo espera, aluno simulado | I02 | 2–5 (só exercícios `play-notes`) | **concluído** |
| [I04](I04-pacote-de-curso.md) | Pacote de curso: `.zywny` assinado, instalar, guardar, remover, `just pacote-curso` | I01, I09 | — | **concluído** (código; manual Linux/Web/celular pendente, ver notas do I04) |
| [I05](I05-leitor-de-licao.md) | Leitor de lição: markdown seguro, imagem, as quatro marcas de conteúdo, nomes das notas | I01, I02 | 1–5 (texto) | **concluído** (2026-10-05; manual no aparelho pendente, ver notas do I05) |
| [I06](I06-teclado-da-tela.md) | Teclado da tela como entrada de notas | — | — | **dispensado** (D-LIC-SEM-TECLADO) |
| [I07](I07-tipos-por-pergunta.md) | Tipos por pergunta: `find-key`, `name-note`, `count-beats`, `choice`; `time-limit` | I03, I09 | 1, 8 | **concluído** (manual no aparelho pendente) |
| [I08](I08-tipos-com-tempo.md) | Tipos com tempo: `rhythm`, `play-score`; `speed`, `hand`, `measures`, `mode` | I03, I09 | 6, 7, 9, 10 | **concluído** (manual no aparelho pendente) |
| [I09](I09-telas-e-progresso.md) | Progresso por curso, `requires`, telas do curso, da lição e do exercício, entrada na biblioteca | I03, I05 | — | **concluído** (2026-10-06; manual no aparelho pendente) |
| [I10](I10-curso-inicial.md) | Curso inicial completo: as 10 lições revisadas, mídia, embutido no app | I05, I07, I08 | 1–10 | **concluído** (2026-10-06; código + conteúdo; manual no aparelho pendente, critérios 4–5) |
| [I11](I11-testes-da-plataforma.md) | Testes da plataforma: cobertura do formato, aluno simulado em todo exercício, cursos quebrados | I10 | — | **concluído** (2026-10-06; código; sem manual — o passo não pede aparelho) |
| [I12](I12-autoria-e-rascunho.md) | Autoria: `validate --render` e modo rascunho (desktop e Web) com Recarregar | I05, I09 | — | **concluído** (código; manual Linux/Web pendente, ver notas do I12) |
| [I13](I13-conferencia.md) | Conferência: `just telas`, `just web-smoke`, aceite no celular, a lição escrita por alguém de fora | todos os I | — | em andamento (parte automática concluída; manuais 4–5 com o usuário, ver notas do I13) |

Ordem sugerida: I01 → I02 → I03 (a primeira lição já roda num teste) → I05
e I09 (já dá para abrir uma lição no app) → I07, I08 → I10 → I11 → I04 e
I12 (abrir para terceiros) → I13. O I04 vem tarde de propósito: o formato só
fica público depois que o curso inicial inteiro passou por ele.

Riscos a medir cedo:
1. **ABC no Verovio** (I02): se o leitor não cobrir o que o curso precisa, o
   plano B é o autor anexar `.musicxml`, e o curso inicial usa o gerador de
   MusicXML do I02. O que o ABC não cobre entra na especificação como
   limite, não como erro misterioso.
2. **Tempo de render** de uma partitura curta no celular (I02): acima de
   ~300 ms, a próxima rodada é renderizada enquanto a atual roda (I03).
3. **Formato público é para sempre**: tudo que entrar na v1 terá de ser lido
   pelos apps futuros. Na dúvida, fica fora da v1.
4. **`main.dart` tem 3318 linhas** e concentra o treino (motor de som,
   agendador, `PracticeController`). A tela do exercício (I09) **não** cresce
   dentro dele: o que for comum é extraído para funções pequenas e
   reaproveitado, sem reescrever a `ScoreHomePage`.

## Fora de escopo da fase I

- Editor visual de lições no app (o professor escreve markdown).
- Loja, busca ou baixar cursos por URL (instalação por arquivo, como no B05).
- Turmas, professor vendo o progresso do aluno, envio de gravações.
- Lógica do autor (condições, ramificações, pontuação própria).
- Teclado de piano na tela (D-LIC-SEM-TECLADO).
- Vídeo dentro do pacote (D-LIC-VIDEO; v2 com `media_kit`).
- Intervalos, escalas, ouvido e dinâmica no curso inicial.
- Curso em outra língua que não o português (o formato não impede).
