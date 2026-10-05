# I00 — Lições de terceiros e o curso inicial: especificação e índice da fase I

O zywny vira uma **plataforma de lições**. Um professor escreve um curso em
**markdown com marcas**: o texto, as figuras, o áudio, o vídeo e os
exercícios com seus critérios de aceite. O zywny apresenta o conteúdo, roda o
exercício no teclado (MIDI ou da tela) e diz se a pessoa passou. A sequência,
as explicações e o que se cobra ficam com o autor.

O primeiro curso escrito nesse formato é o **curso inicial** (teclado, pauta,
claves, notas, acidentes e tempos). Ele não tem caminho especial no código:
é o cliente número um da plataforma e o seu teste de aceite.

Este arquivo é a proposta (escrita em 2026-10-04, depois de o usuário pedir
"lições conduzidas por terceiros") e o índice dos passos I01–I13. **As
decisões D-LIC-\* estão abertas.** Os arquivos dos passos são escritos depois
delas. Quem executa um passo lê o `README.md`, **este arquivo** e o arquivo do
passo.

Prefixo **I** (de iniciação): não colide com os prefixos do zywny nem com os
do bridge (F/S/R/A/E/P/G).

## A divisão de papéis

| O autor (professor) decide | O zywny garante |
| --- | --- |
| Os cursos, as lições e a ordem (quem depende de quem) | Mostrar texto, imagem, partitura, áudio e vídeo no celular, na Web e no desktop |
| O texto das explicações | Um conjunto fixo de **tipos de exercício**, cada um com seus parâmetros |
| Qual tipo de exercício, com quais notas, ritmos ou partitura | Gerar a rodada (partitura sorteada ou a do autor), tocar, ouvir o teclado |
| Os critérios de aceite (precisão, andamento, mão, rodadas) | Avaliar com as regras do treino de hoje e guardar o progresso |
| A mídia que acompanha | Validar o curso e apontar o erro pela linha, antes de chegar ao aluno |

O que não está na coluna da direita **não existe na plataforma**: o autor não
programa, não escreve HTML e não busca nada na rede sem a pessoa tocar num
link.

## O formato (rascunho v1)

Um curso é uma pasta. Na distribuição, a pasta vira um pacote (I04).

```
iniciacao/
  curso.md                 ← front matter do curso + a apresentação
  licoes/
    01-o-teclado.md
    02-pauta-e-clave-de-sol.md
    …
  midia/                   ← imagens, áudio, partituras (.musicxml, .abc)
```

`curso.md`:

```markdown
---
formato: 1
id: iniciacao
titulo: Primeiros passos ao piano
autor: zywny
versao: 1
licoes: [o-teclado, pauta-e-clave-de-sol, clave-de-sol, clave-de-fa, …]
---

Neste curso você aprende a ler partitura do zero.
```

Uma lição (`licoes/02-pauta-e-clave-de-sol.md`):

````markdown
---
id: pauta-e-clave-de-sol
titulo: A pauta e a clave de sol
requer: [o-teclado]
---

A pauta tem **cinco linhas** e quatro espaços. Quanto mais alta a nota, mais
aguda ela soa.

```zywny-partitura
clave: sol
abc: "C D E F G"
```

A clave de sol marca o **Sol** na segunda linha.

![A clave de sol](midia/clave-de-sol.png)

```zywny-audio
arquivo: midia/sol.ogg
legenda: O Sol da segunda linha
```

```zywny-exercicio
id: ler-do-ao-sol
tipo: tocar-notas
titulo: Toque as notas
clave: sol
notas: {sorteio: C4-G4, quantidade: 12}
aceite: {precisao: 90}
```
````

Regras do formato:

- **Markdown comum** para o texto: títulos, negrito, itálico, listas, links e
  imagens. HTML não é interpretado (aparece como texto).
- **Marcas = blocos cercados com linguagem `zywny-…` e corpo YAML.** Num
  editor ou no GitHub, a lição continua legível: as marcas aparecem como
  blocos de código.
- O front matter traz `formato: 1`. Chave desconhecida é **erro** no
  validador (pega erro de digitação); formato maior que o do app é recusado
  com "atualize o zywny".
- Ids (`id` de curso, lição e exercício) são estáveis: o progresso é guardado
  por eles. Mudar o texto de uma lição não apaga o progresso; mudar o id,
  sim.

### Marcas de conteúdo

| Marca | Mostra | Parâmetros principais |
| --- | --- | --- |
| `zywny-partitura` | Uma partitura pequena, com toque para ouvir | `abc` (notação em linha), ou `arquivo` (`.musicxml`/`.abc` da pasta); `clave`, `armadura`, `compasso`, `destaque` |
| `zywny-teclado` | O teclado desenhado, com teclas marcadas | `de`/`ate` (faixa), `marcar` (notas), `nomes` (sim/não) |
| `zywny-audio` | Um tocador | `arquivo` (`.ogg`/`.mp3` da pasta), `legenda` |
| `zywny-video` | Um vídeo | `arquivo` ou `link` (depende de D-LIC-VIDEO), `legenda` |
| imagem markdown | A imagem | `![legenda](midia/x.png)`, só arquivo da pasta |

### Marca de exercício e tipos

`zywny-exercicio` com `id`, `tipo`, `titulo`, os parâmetros do tipo e
`aceite`.

| Tipo | O aluno | Modo | Parâmetros |
| --- | --- | --- | --- |
| `achar-tecla` | Vê um nome ("Ré") e toca a tecla | Pergunta a pergunta | `notas`, `oitava: qualquer\|exata` |
| `tocar-notas` | Lê cada nota na pauta e toca | Espera (T02) | `clave`, `armadura`, `notas` (lista ou sorteio), `acidentes` |
| `nomear-nota` | Lê a nota e toca o botão com o nome | Pergunta a pergunta | os de `tocar-notas`, `opcoes` |
| `ritmo` | Toca uma tecla no ritmo escrito | Tempo real (T03), contagem e metrônomo | `compasso`, `figuras` (sorteio) ou `abc`, `andamento`, `nota` |
| `contar-tempos` | Toca o botão com quantos tempos vale a figura destacada | Pergunta a pergunta | `compasso`, `figuras` |
| `tocar-partitura` | Toca uma partitura do autor | Espera ou tempo real | `arquivo` ou `abc`, `mao`, `modo`, `andamento`, `compassos` |
| `escolha` | Responde uma pergunta de múltipla escolha | Pergunta a pergunta | `pergunta`, `opcoes`, `certa`, figura opcional |

`notas` aceita lista fixa (`[C4, E4, G4]`) ou sorteio
(`{sorteio: C4-G5, quantidade: 12, so: linhas}`). Nomes em notação
científica (C4 = dó central) no arquivo; na tela, Dó-Ré-Mi (D-LIC-NOMES).

### Critérios de aceite (`aceite`)

| Chave | Significado | Padrão |
| --- | --- | --- |
| `precisao` | Porcentagem mínima numa rodada (regra do J02: `correct / total`; nas perguntas, acertos na 1ª tentativa) | 90 |
| `rodadas` | Quantas rodadas aprovadas, seguidas | 1 |
| `andamento` | Andamento mínimo, em % do escrito (`tocar-partitura`, `ritmo`) | 100 |
| `mao` | `direita`, `esquerda`, `ambas` | `ambas` |
| `tempo-max` | Segundos por pergunta (só nos tipos por pergunta) | sem limite |

Dois exemplos do que um professor escreve, sem código novo:

- "Toque o Minueto em Sol, mão direita, a 75%, com 85%":
  `tipo: tocar-partitura`, `arquivo: midia/minueto.musicxml`, `mao: direita`,
  `aceite: {precisao: 85, andamento: 75}`.
- "Três rodadas seguidas de clave de fá sem errar":
  `tipo: tocar-notas`, `clave: fa`, `aceite: {precisao: 100, rodadas: 3}`.

As escolhas do primeiro plano (D-INI-ORDEM, D-INI-APROVACAO, D-INI-OITAVA,
D-INI-CURRICULO) deixam de ser decisões do app: viram `requer`, `aceite`,
`oitava` e o conteúdo do curso, nas mãos do autor.

## O curso inicial como teste da plataforma

Cinco regras fazem do curso inicial o teste de aceite do formato e do motor.

1. **Sem atalho.** O curso inicial é uma pasta no formato v1, lida pelo mesmo
   leitor que um curso de terceiros. Se ele precisa de algo que o formato não
   tem, o formato ganha a marca (documentada na especificação), e o curso
   usa a marca. Proibido `if (curso == 'iniciacao')`.
2. **Cobertura do formato.** Um teste (`test/course_coverage_test.dart`) lê o
   curso inicial e confere que **toda** marca, **todo** tipo de exercício e
   **toda** chave de `aceite` aparecem ao menos uma vez. Marca nova sem uso no
   curso inicial reprova o teste. Assim o curso é também o exemplo vivo para
   os professores.
3. **Aluno simulado.** Para cada exercício do curso, um teste roda uma rodada
   com semente fixa e um teclado MIDI falso: tocando tudo certo, aprova;
   errando acima do limite, reprova; a 50% do andamento pedido, reprova pelo
   `andamento`. É o teste de ponta a ponta dos critérios, sem aparelho.
4. **Cursos quebrados.** `test/fixtures/cursos/` traz cursos com erros de
   propósito (marca desconhecida, YAML inválido, arquivo ausente, `requer`
   circular, ABC que não renderiza, id repetido). Cada um tem a mensagem
   esperada do validador, com arquivo e linha. É o que o professor vai ver.
5. **Um curso de fora.** Antes de fechar a fase, o usuário escreve (ou
   encomenda) uma lição curta, sem olhar o código, só com a especificação
   para professores. O que ele tropeçar vira correção na especificação ou no
   validador.

O conteúdo do curso inicial cresce junto com a plataforma: cada passo que
traz um tipo de exercício escreve as lições que o usam (tabela dos passos).

### Currículo do curso inicial

| # | Lição (`id`) | Explica | Exercícios | Exercita da plataforma |
| --- | --- | --- | --- | --- |
| 1 | `o-teclado` | Grupos de 2 e 3 teclas pretas; o Dó; as teclas brancas; o dó central | `achar-tecla` (qualquer oitava) | texto, `zywny-teclado`, `achar-tecla`, `oitava` |
| 2 | `pauta-e-clave-de-sol` | 5 linhas, 4 espaços; agudo e grave; a clave de sol | `tocar-notas` C4–G4, `nomear-nota` | `zywny-partitura` com `abc`, imagem, áudio, sorteio |
| 3 | `clave-de-sol` | Linhas e espaços; linhas suplementares | `tocar-notas` C4–G5, `so: linhas`/`so: espacos` | `rodadas`, `tempo-max` |
| 4 | `clave-de-fa` | O Fá na 4ª linha; linhas e espaços | `tocar-notas` G2–C4 | `clave: fa` |
| 5 | `pauta-dupla` | Chave, as duas claves, o dó central entre elas | `tocar-notas` nas duas pautas | sistema de piano, `requer` com duas lições |
| 6 | `figuras-e-pausas` | Semibreve, mínima, semínima e as pausas; 4/4 | `ritmo`, `contar-tempos` | `ritmo` com sorteio, metrônomo, `andamento` |
| 7 | `mais-tempos` | Colcheia, ponto, ligadura; 2/4 e 3/4 | `ritmo` com `abc` | `zywny-video` (contar em voz alta) |
| 8 | `acidentes` | Sustenido, bemol, bequadro; vale até a barra | `tocar-notas` com `acidentes`, `escolha` | `escolha` |
| 9 | `armadura` | Armadura de 1 e 2 acidentes | `tocar-partitura` com `abc` | `armadura`, `modo: espera` |
| 10 | `juntando-tudo` | Altura e ritmo ao mesmo tempo | `tocar-partitura` de um `.musicxml` da pasta, uma mão, depois as duas | `arquivo`, `mao`, `modo: tempo-real` |

## O que já existe e será reaproveitado

| Peça | Onde | Uso |
| --- | --- | --- |
| Render de partitura em bytes, nativo e Web | `ScoreRenderRequest` (`lib/render/score_renderer.dart` L14: `source: Uint8List`, `fileName`) | Partituras das marcas e dos exercícios |
| Leitor de ABC no Verovio | `verovio/src/ioabc.cpp` no fork | `abc:` em linha, sem escrever conversor. **A conferir em I02:** detecção pelo cabeçalho `X:`, alcance (ligaduras, quiálteras, duas vozes) e se o `midi.json` sai certo |
| Modo espera e tempo real | `PracticeController` (`lib/practice/practice_controller.dart`) | `tocar-notas`, `ritmo`, `tocar-partitura` |
| Contagem, metrônomo | `lib/audio/metronome.dart`, `lib/practice/count_in_overlay.dart` | `ritmo`, `tocar-partitura` |
| Avaliação e porcentagem | `lib/trail/stage_result.dart` (J02) | `precisao` |
| Progresso por id | `TrailProgress`/`TrailProgressStore` (`lib/trail/trail_progress.dart`) | Modelo do progresso por curso |
| Pacote `.zywny` | `lib/library/library_envelope.dart`, `library_package.dart`, `library_installer.dart`, `library_blob_store*.dart` (B01–B05) | Distribuir cursos (com a confiança de D-LIC-CONFIANCA) |
| Teclado desenhado | `PianoKeyboardPainter` (`lib/midi/piano_keyboard.dart`, sem toque hoje) | `zywny-teclado` e teclado da tela |
| Entrada de notas | `MidiInputService`, `PlayedNote` (`lib/midi/midi_input_service.dart` L15–L50) | O teclado da tela é mais uma fonte |
| Teclado MIDI falso dos testes de tela | roteiro de `just telas` | Aluno simulado |

O que **não** existe e entra como dependência: renderizar markdown
(`markdown` + widgets próprios, ou `flutter_markdown`), YAML (`yaml`), tocar
áudio de arquivo e, se D-LIC-VIDEO pedir, vídeo (o `video_player` não roda no
Linux; `media_kit` roda nas quatro plataformas).

O modo "ritmo com qualquer tecla" (T05) saiu no commit `bb39786`. Por isso o
tipo `ritmo` toca **uma altura só** escrita na pauta (`nota`, padrão C4) e usa
o tempo real de hoje.

## Decisões

| Id | Pergunta | Recomendação | Status |
| --- | --- | --- | --- |
| D-LIC-MARCAS | Sintaxe das marcas | Blocos cercados ` ```zywny-… ` com YAML: legíveis em qualquer editor e no GitHub, sem parser de markdown estendido. Alternativas: diretivas `:::exercicio{…}` (mais bonitas, pouco suportadas) ou comentários HTML (somem na prévia do editor) | **aberta** |
| D-LIC-IDIOMA | Chaves e valores do formato em português ou inglês? | Português (`tipo: tocar-notas`, `aceite`), como o app; o `formato:` permite aceitar sinônimos em inglês depois | **aberta** |
| D-LIC-CONFIANCA | Quem pode publicar um curso? Hoje o app só instala pacote assinado pela **sua** chave privada (D-BIB-CIFRA) | (a) cursos aceitos **sem assinatura**, instalados com o aviso "curso de terceiros, não verificado", e o formato não executa nada (só texto, mídia da pasta, partituras); (b) só cursos que você assina; (c) uma chave por professor, cadastrada por você. Recomendo (a): é o que torna o zywny uma plataforma | **aberta** |
| D-LIC-VIDEO | Vídeo no curso | `link` aberto no navegador/YouTube na v1 (zero dependência, pacote pequeno); arquivo de vídeo dentro do pacote só numa v2, com `media_kit` | **aberta** |
| D-LIC-NOTACAO | Notação em linha | ABC (o Verovio já lê, professores conhecem) mais arquivos `.musicxml`; sem notação própria | **aberta** |
| D-LIC-AUTORIA | Como o professor vê a lição enquanto escreve | Validador na linha de comando (`zywny-curso validar pasta/`) e, no app desktop e na Web, "Abrir pasta de curso" com botão Recarregar | **aberta** |
| D-LIC-INICIAL | O curso inicial vem no app ou como pacote? | No app (é pequeno, é nosso e é o que a pessoa faz quando o app está vazio), lido do mesmo jeito que uma pasta de terceiros | **aberta** |
| D-LIC-NOMES | Nomes das notas na tela | Dó-Ré-Mi por padrão, opção C-D-E nas configurações; o arquivo sempre usa C4 | **aberta** |
| D-LIC-SEM-TECLADO | Os exercícios funcionam sem teclado MIDI? | Sim: teclado de duas oitavas na tela; os tipos por pergunta usam botões | **aberta** |
| D-LIC-ENTRADA | Onde ficam os cursos no app | Um item "Cursos" na biblioteca e o cartão do curso inicial na tela sem biblioteca | **aberta** |

## Passos

| Passo | Título | Depende de | Lições do curso inicial que fecha | Status |
| --- | --- | --- | --- | --- |
| I01 | Especificação v1 para professores (`docs/licoes/formato-v1.md`) e leitor + validador (Dart puro: front matter, marcas, YAML, mensagens com arquivo e linha) | D-LIC-MARCAS, D-LIC-IDIOMA | — (fixtures quebradas) | pendente |
| I02 | Partituras das marcas: ABC no Verovio (conferir alcance), gerador de MusicXML para sorteios, tempo de render | I01, D-LIC-NOTACAO | — | pendente |
| I03 | Motor de exercícios: interface do tipo (gerar rodada, avaliar, critérios `aceite`), `tocar-notas` em modo espera, resumo da rodada, aluno simulado | I02 | 2, 3, 4 (só exercícios) | pendente |
| I04 | Pacote de curso: `.zywny` de tipo curso, instalar, guardar, a confiança de D-LIC-CONFIANCA, `just pacote-curso` | I01, D-LIC-CONFIANCA | — | pendente |
| I05 | Leitor de lição: markdown seguro, imagem, `zywny-partitura`, `zywny-teclado`, `zywny-audio`, `zywny-video` | I01, I02, D-LIC-VIDEO | 1–5 (texto) | pendente |
| I06 | Teclado da tela como entrada de notas | D-LIC-SEM-TECLADO | — | pendente |
| I07 | Tipos por pergunta: `achar-tecla`, `nomear-nota`, `contar-tempos`, `escolha`; `tempo-max` | I03, I06 | 1, 8 | pendente |
| I08 | Tipos com tempo: `ritmo`, `tocar-partitura`; `andamento`, `mao`, `rodadas` | I03 | 6, 7, 9, 10 | pendente |
| I09 | Progresso por curso, `requer`, telas do curso e da lição, entrada (D-LIC-ENTRADA) | I03, I05 | — | pendente |
| I10 | Curso inicial completo: as 10 lições revisadas, mídia, embutido no app (D-LIC-INICIAL) | I05, I07, I08 | 1–10 | pendente |
| I11 | Testes da plataforma: cobertura do formato, aluno simulado em todo exercício, cursos quebrados | I10 | — | pendente |
| I12 | Autoria: validador na linha de comando e "Abrir pasta de curso" com Recarregar | I05, I09, D-LIC-AUTORIA | — | pendente |
| I13 | Conferência: `just telas`, `just web-smoke`, aceite no celular, e a lição escrita por alguém de fora | todos os I | — | pendente |

Ordem sugerida: I01 → I02 → I03 (a primeira lição já roda num teste) → I05
e I09 (já dá para abrir uma lição no app) → I06, I07, I08 → I10 → I11 → I04 e
I12 (abrir para terceiros) → I13. O I04 vem tarde de propósito: o formato só
fica público depois que o curso inicial inteiro passou por ele.

Riscos a medir cedo:
1. **ABC no Verovio** (I02): se o leitor não cobrir o que o curso precisa, o
   plano B é o autor anexar `.musicxml`, e o curso inicial usa o gerador de
   MusicXML do I02.
2. **Tempo de render** de uma partitura curta no celular (I02): acima de
   ~300 ms, a próxima rodada é renderizada enquanto a atual roda.
3. **Formato público é para sempre**: tudo que entrar na v1 terá de ser lido
   pelos apps futuros. Na dúvida, fica fora da v1.

## Fora de escopo da fase I

- Editor visual de lições no app (o professor escreve markdown).
- Loja, busca ou baixar cursos por URL (instalação por arquivo, como no B05).
- Turmas, professor vendo o progresso do aluno, envio de gravações.
- Lógica do autor (condições, ramificações, pontuação própria).
- Intervalos, escalas, ouvido e dinâmica no curso inicial.
- Curso em outra língua que não o português (o formato não impede).
