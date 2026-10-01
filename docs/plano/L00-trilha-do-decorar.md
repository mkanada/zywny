# L00 — Trilha do decorar: especificação e índice da fase L

A **trilha do decorar** é uma segunda trilha, opcional, para quem já toca a
música e quer sabê-la de cor. A partitura aparece inteira e, etapa após
etapa, mais notas dão lugar a uma **pausa colorida**; o aluno toca o que
lembra. No fim vem a prova com a partitura coberta.

Este arquivo é a especificação (decidida com o usuário em 2026-10-01) e o
índice dos passos L01–L08. Quem executa um passo lê o `README.md`, o
[J00](J00-trilha-de-estudo.md) (a trilha de estudo, de onde vêm caminho,
trechos, aprovação e progresso), **este arquivo** e o arquivo do passo.

O que depende do fork do Verovio e do formato `.vsb` — glifos de pausa, a
figura da nota, a regra do que apagar e de onde desenhar a pausa — está
planejado **no repo do bridge**
(`/home/mauricio/rust_projects/verovio_flutter_bridge/docs/plano/`), como
**G07** (visão geral), **G08a–G08c** e **G09**. L02 e L03 são a porta Dart
do que sai de lá.

## Vocabulário

Vale o vocabulário do J00 (caminho, compasso lógico, trecho, etapa, degrau).
A mais:

| Termo | Significado |
| --- | --- |
| **coluna** | As notas de **uma pauta** que começam no mesmo instante (as duas vozes da mão, nos hinos). É a unidade que some |
| **sumiço** | Quanto da música está escondido numa etapa: 25%, 50%, 75% ou 100% das colunas |
| **pausa substituta** | A pausa desenhada no lugar de uma coluna escondida, numa cor própria |
| **revelar** | Devolver à tela as notas de uma coluna escondida, depois de um erro |
| **prova às cegas** | A música inteira com a partitura coberta |
| **de cor** | Marca do hino cuja prova às cegas a 100% do andamento foi aprovada |

## Regras

### Onde ela mora

- É **independente** da trilha de estudo: não exige nada dela e não mexe no
  progresso dela. Entra-se por "Trilha do decorar" na gaveta de opções da
  partitura; a trilha de estudo continua sendo a tela padrão.
- Só existe onde a trilha de estudo existe: hino da biblioteca com caminho
  utilizável (contíguo até o J08).
- Usa o **mesmo corte** da trilha de estudo: os mesmos trechos, com o mesmo
  N efetivo (`trailMeasures`). Mudar N zera as duas trilhas daquela música
  (a confirmação do J06 passa a dizer isso).

### O que some

- A unidade é a **coluna**. Uma coluna escondida some inteira: cabeças,
  hastes, acidentes, pontos, a continuação de uma ligadura e as linhas
  suplementares dela. A barra de ligação (colchete) some quando **todas** as
  notas dela estão escondidas.
- Ficam na tela: pauta, clave, armadura, fórmula de compasso, barras de
  compasso, pausas de verdade, a letra do hino e as notas que não sumiram.
- No lugar da coluna entra **uma** pausa substituta por pauta, com a figura
  da nota **mais curta** da coluna, na posição normal de pausa, na cor
  `kMemoRestColor` (constante, diferente das cores de veredito e do azul da
  pendente). Ela mostra o ritmo; a altura é o que se lembra.
- **Sorteio fixo e aninhado.** Dentro de cada compasso lógico as colunas
  recebem uma ordem pseudoaleatória que depende só do número do compasso,
  da pauta e da posição da coluna — não do hino aberto, do dia nem do id da
  nota. No sumiço `p` somem as primeiras `⌈p × colunas do compasso⌉`. Logo:
  - o que sumiu a 25% continua sumido a 50%, 75% e 100%;
  - a mesma coluna some igual no trecho, no trecho vizinho (compasso
    compartilhado) e na música inteira;
  - cada compasso tem a sua parte escondida — nada de um compasso todo
    escrito ao lado de um todo vazio.
- Ornamentos e apojaturas não são cobrados (D-TREINO) e não somem.

### Etapas

Todas em tempo real (`PracticeMode.realtime`), as duas mãos
(`Hand.ambas`), só o aluno soa, com **1 compasso de contagem e metrônomo
ligado**.

| Bloco | Intervalo | Etapas | Ids |
| --- | --- | --- | --- |
| Cada trecho | o trecho | sumiço 25, 50, 75, 100 × andamento 50, 75, 100% = **12** | `t0.s25.50` … `t0.s100.100` |
| Música inteira | o caminho todo | os mesmos 12 | `inteira.s25.50` … `inteira.s100.100` |
| Prova às cegas | o caminho todo | andamento 50, 75, 100% = **3** | `cega.50`, `cega.75`, `cega.100` |

- Ordem: sumiço por fora, andamento por dentro — `s25.50`, `s25.75`,
  `s25.100`, `s50.50`, … Cada sumiço novo recomeça devagar.
- Desbloqueio, pular e refazer: iguais aos do J00 (uma etapa por vez, a
  pulada fica registrada, guarda-se a melhor porcentagem, refazer nunca tira
  a aprovação).
- Tamanho: um hino de 20 compassos lógicos com N = 5 tem 5 trechos →
  60 + 12 + 3 = **75 etapas**. É muito; o pulo existe para isso, e o L06
  mede quanto tempo leva um trecho.

### Durante a passagem

- Coluna escondida tocada certa (`correct`): a **pausa** pisca em verde; a
  nota continua escondida.
- `early`/`late`: a pausa pisca em âmbar; a nota continua escondida (a
  memória estava certa, o tempo não).
- `wrong` (a coluna mais perto da tecla errada) ou `missed`: a coluna é
  **revelada** — a pausa sai, as notas voltam na cor do veredito e ficam
  assim até o fim da passagem.
- Notas visíveis: como no tempo real de hoje.
- Sair da etapa (fim, parar, trocar de etapa) devolve a partitura inteira.

### Prova às cegas

- A área da partitura fica coberta. Aparecem só o número do compasso lógico
  atual, a batida do metrônomo e os contadores de sempre.
- Nada é revelado durante a prova. O resumo, no fim, mostra a porcentagem e
  os compassos com erro, e tem um botão para ver a partitura.
- `cega.100` aprovada → o hino ganha a marca **de cor**.
- Não há reforço automático (J07) nesta trilha: reprovou, o aluno refaz a
  prova ou volta às etapas dos trechos.

### Aprovação

- **90%, fixo**, uma passagem basta, pela regra de tempo real do J00:
  `correct / total`. `early`, `late`, `wrong` e `missed` são erro.
- Conta a passagem inteira do intervalo, notas visíveis e escondidas.

### Dados

- Progresso próprio, um JSON por hino (`memo_<número>`), no mesmo formato
  do progresso da trilha de estudo, com o N usado.
- Sumiços 25/50/75/100, degraus 50/75/100 e os 90% são constantes.

### Interface (celular em paisagem é o alvo)

- A faixa, o resumo e a gaveta de etapas são os da trilha de estudo (J05,
  J06), com outro plano: "Decorar · Trecho 2/5 · 50% escondido · 75%".
- A biblioteca mostra o progresso do decorar e a marca **de cor**, ao lado
  do que o J09 mostra.

## Fatos medidos (2026-10-01)

Cena de `score_bridge/test/fixtures/Chopin_Etude_Op10_No9.vsb` e os 600
hinos de `assets/hinos/` (`grep` no MusicXML):

| Fato | Onde / quanto |
| --- | --- |
| O nó `note` (tem `id`) contém `notehead`, `stem`, `accid`, `artic`, `dots` | pintar o id da nota de transparente esconde tudo isso |
| A letra (`verse`) é filha da nota mas fica fora da troca de cor | `kOverrideExemptClasses` em `score_bridge/lib/src/scene_walk.dart` — a sílaba **não** some com a nota |
| A barra de ligação é um caminho solto dentro do grupo `beam` (com `id`), irmão das notas | 340 de 353 notas do estudo estão dentro de `beam`; esconder as notas deixa a barra |
| Linhas suplementares: grupos `ledgerLines above`/`below`, filhos de `staff`, **sem id**; cada traço é uma forma própria | não dá para escondê-las por id; a regra geométrica é a §11 da spec (G08a/G08c do bridge) |
| Pausa de verdade: `g class="rest"` com um uso de glifo (`Leipzig:E4E6`) | — |
| A cena **não** traz a figura (duração notada) da nota | virá em `pitchpos.json` (`dur`, `dots`) — decisão D-SUM-FIGURA, G08a/G08b do bridge |
| `glyphs.json` só tem os glifos usados, mais os reservados | `BridgeDeviceContext::AddReservedGlyphs`, `verovio/src/bridgedevicecontext.cpp` L1254 (hoje: cabeça preta, acidentes, 8va/15ma); as pausas entram em G08b do bridge |
| Hinos com duas vozes por pauta, sem `<chord/>` | 598 de 600 — a coluna típica são duas notas em camadas diferentes |
| Hinos com ponto de aumento / ligadura / quiáltera | 586 / 349 / 52 |
| Figuras nos hinos | semínima 77 599, mínima 66 762, colcheia 46 982, semibreve 8 960, semicolcheia 7 515, fusa 4 |
| O `score_bridge` é um `git subtree` dentro do zywny | `pubspec.yaml` L52; a origem é o repo do bridge |

## O que já existe e será reaproveitado

| Peça | Onde |
| --- | --- |
| Caminho, compassos lógicos, trechos | `lib/trail/` (J01) |
| `StageResult`, 90%, compassos com erro | J02 |
| Etapa, plano, progresso, store | J03 |
| Passagem única de um intervalo em tempo real | J04 |
| Faixa, resumo, gaveta de etapas | J05, J06 |
| Cor por id e destaque | `ScoreController` (`setColors`, `clearColor`, `highlight`) |
| Camada desenhada por cima da página, com glifos do documento | `GhostController`/`GhostPainter`, `score_bridge/lib/src/ghost_layer.dart` |
| Vereditos do tempo real e cores | `PracticeController._onVerdict` (`lib/practice/practice_controller.dart` L433), `lib/practice/practice_colors.dart` |

## Passos

| Passo | Título | Depende de | Status |
| --- | --- | --- | --- |
| [L01](L01-sorteio-do-sumico.md) | Colunas e sorteio do sumiço (Dart puro) | J01 | pendente |
| [L02](L02-esconder-notas.md) | `score_bridge`: esconder colunas (nota, barra, linha suplementar) | G09 (bridge) | pendente |
| [L03](L03-pausa-substituta.md) | `score_bridge`: pausa substituta colorida | L02, G09 (bridge) | pendente |
| [L04](L04-plano-e-progresso-do-decorar.md) | Plano, desbloqueio e progresso do decorar | J03, L01 | pendente |
| [L05](L05-passagem-com-sumico.md) | `PracticeController`: passagem com sumiço e revelação | J04, L02, L03 | pendente |
| [L06](L06-tela-do-decorar.md) | Tela: entrar na trilha do decorar e executar etapas | J05, J06, L04, L05 | pendente |
| [L07](L07-prova-as-cegas.md) | Prova às cegas e marca "de cor" | L06 | pendente |
| [L08](L08-decorar-na-biblioteca.md) | Decorar na biblioteca | J09, L04 | pendente |

Ordem sugerida: G08a → G08b → G08c → G09 **no bridge** (não esperam a fase
J e podem começar já) → L02 → L03; em paralelo, L01 → L04; depois L05 → L06
→ L07 e L08. A trilha fica utilizável no fim do L06.

## Fora de escopo da fase L

- Revisão espaçada (o app pedir a prova de novo dias depois).
- Reforço automático dos compassos errados.
- Decorar com uma mão só, ou com repetições (estrofes).
- Sumiço adaptativo (esconder o que o aluno acertou).
- Esconder a letra, as ligaduras de expressão ou o dedilhado.
- Sumiços, degraus e porcentagem de aprovação configuráveis.
