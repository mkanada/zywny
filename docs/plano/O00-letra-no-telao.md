# O00 — Letra no telão, em sincronia com o pianista

**Repo:** zywny (+ um passo no bridge) · **Status:** pesquisa e proposta
(2026-10-07), **nada implementado** · **Quando:** depois da 1.0 ·
**Decisões necessárias:** sim, ver "Decisões" no fim.

**Revisado** em 2026-10-07 contra o contrato da letra do Hymn_Grabber
(`Hymn_Grabber/docs/formato-da-letra.md`, LT01; decisão D-LT-O00).

**Revisado de novo** em 2026-10-07 (decisões D-LT-FONTE e D-LT-O00-2 do
Hymn_Grabber, `Hymn_Grabber/docs/letra/LT00-letra-no-telao.md`): o texto do
telão **vem do catálogo de letras do app**, já em estrofes e versos e na ordem
cantada; a partitura só diz **quando** cada verso começa (as âncoras). O passo
G e o O01 mudam de acordo.

Este arquivo é autossuficiente: reúne o problema, o que o zywny e os hinos já
oferecem, a pesquisa sobre seguir uma execução ao vivo, o desenho proposto e
uma quebra preliminar em passos O01…O08 (+ um passo G no bridge). Ao executar
um passo O, leia o README do plano (Convenções, Fatos), este arquivo inteiro,
e siga as regras de execução do README (parar em decisão aberta, notas de
execução, sem commit).

Prefixo **O**: não colide com X/N/C/K/M/T/W/V/J/L/U/B/I/Q/R/H/Y/Z (zywny)
nem com F/S/R/A/E/P/G (bridge).

## O problema

Na igreja do usuário o instrumental dos hinos é um playback, e programas
próprios tocam o playback e projetam a letra em sincronia — fácil, porque o
tempo do playback é fixo. Com o zywny, muitos pianistas passarão a tocar ao
vivo. Queremos que o zywny **projete a letra acompanhando o que o pianista
está tocando**, com o andamento, as pausas e os erros de uma execução real.

## O que já existe (medido em 2026-10-07)

- **A letra já está nos hinos.** No Hymn_Grabber, os 600 hinos têm
  `<lyric>` por nota: 581 em `musicxml/` e 19 em `musicxml_special/` (os
  outros arquivos dessas pastas não são hinos). Hoje o `number` é a ordem da
  linha no compasso (`<lyric name="1" number="1">`, `"2"`, `"3"`…); o contrato
  pede a passagem (ver abaixo). O hino 001 tem 46, 49 e 49 sílabas nas 3
  estrofes (144 no total).
- **O texto do telão vem do catálogo do app, com âncoras** (Hymn_Grabber
  LT07, LT03 e LT08, feitos em 2026-10-07). O catálogo traz os 600 hinos em
  estrofes e versos, **na ordem cantada e já desdobrada** (estrofe, coro,
  estrofe, coro…; o coro vem por extenso a cada vez): 14.035 versos, 357 hinos
  com coro. Para cada verso, `Hymn_Grabber/musicxml/NNN.letra.json` guarda a
  **âncora**: a nota da 1ª sílaba, na passagem certa, como `k` (índice do
  compasso na música desdobrada, contando a introdução), `compasso` (o
  `number` do `<measure>`), `passagem` e `tempo` (em semínimas, como fração).
  13.641 versos (97,2%) têm a âncora na 1ª palavra, 359 numa palavra seguinte
  do verso e 35 não têm instante (`inicio` nulo); 407 hinos têm todos os
  versos na 1ª palavra. A letra do MusicXML continua sendo desenhada sob as
  notas, mas não é mais a fonte do telão.
- **As estrofes já viraram repetições.** O extrator
  (`Hymn_Grabber/docs/plano-extrator.md`, seção "Repetição das estrofes") dá
  a cada linha de letra uma passagem: o hino sem repetição escrita ganha
  `<repeat direction="backward" times="N"/>` no último compasso (N = número
  de estrofes); casas "1."/"2." e "1.*"/"2.*" levam as passagens em que são
  tocadas. A introdução (marcas da fonte `MusiCasaSimb`) toca uma vez e as
  estrofes voltam ao 1º compasso da peça.
- **A partitura já desenha a letra.** O Verovio desenha os nós de classe
  `verse` como filhos da nota; o host os deixa fora do destaque
  (`kOverrideExemptClasses`, `score_bridge/lib/src/scene_walk.dart:37`), e
  há a opção "Tamanho da letra" (`lyricSize`,
  `lib/render/layout_options.dart:352`).
- **A ordem de execução já é conhecida.** `ScoreTimeline.measures`
  (`score_bridge/lib/src/score_timeline.dart`) lista cada compasso uma vez
  **por passagem**, com `pass`. Logo, **`<lyric number="N">` é a passagem N**,
  com a letra da estrofe cantada nela. Não é sempre a estrofe N: em 496, a
  passagem 3 canta a estrofe 1 de novo (contrato em
  `Hymn_Grabber/docs/formato-da-letra.md`, item 1; ver Riscos).
- **O que falta:**
  1. o `.vsb` **não** leva a letra estruturada nem as âncoras — a spec
     `docs/formato/especificacao-v1.md` do bridge só cita `lyricist`. A
     letra existe apenas como glifos na cena. O que falta levar é o
     `NNN.letra.json` do Hymn_Grabber (versos e âncoras), e não mais sílabas
     por nota;
  2. um **seguidor** de execução livre. O `WaitModeSession` e o
     `RealtimeSession` (`lib/practice/practice_session.dart`) são casadores
     de treino: o primeiro espera o acorde exato (janela de 300 ms) e não
     avança no erro; o segundo supõe que o tempo anda no relógio do app.
     Nenhum serve para um pianista que conduz o andamento.

## Pesquisa

### Seguir uma execução (score following)

- **Simbólico (MIDI) é o caso fácil.** Os métodos clássicos são HMM sobre os
  eventos da partitura e *Online Time Warping* (OLTW, Dixon; variante com
  andamento de Arzt). A biblioteca **Matchmaker** (JKU, 2025, Python,
  código aberto) implementa OLTW-Dixon, OLTW-Arzt e HMM e serve de
  referência de algoritmo e de método de avaliação (conjuntos ASAP, Batik,
  Vienna4x22). A latência de processamento é desprezível (< 4 ms por
  evento).
- **Áudio (piano acústico, microfone)** é bem mais difícil: o erro mediano
  do OLTW sobre áudio fica em ~90–150 ms nos melhores casos e há perdas de
  rastreio. A abordagem recente é transcrever o áudio para notas e então
  seguir no nível simbólico (Peter, Hu e Widmer, 2025). **Fora de escopo**
  aqui; o zywny já pressupõe teclado MIDI.
- **The ACCompanion** (acompanhador automático de piano, JKU) mostra o
  mesmo desenho: seguidor + previsão de andamento para agir *antes* do
  evento.

### Programas de projeção usados em igrejas

- **Holyrics** (o mais comum no Brasil): playlist de músicas, projeção,
  controle pelo celular e um **API Server** (usado pelo módulo do Bitfocus
  Companion: `GetNextSongPlaylist`, etc.). A documentação da API está
  incompleta, segundo os próprios mantenedores.
- **Quelea**, **OpenSong** (tem API remota), **ProPresenter**,
  **MediaShout**: projeção de letra por slides, troca manual ou por tempo.
- **SDA Hymnal MLC** (iOS): toca o instrumental em MIDI e projeta a letra
  por AirPlay/HDMI — é o equivalente do "playback com letra" de hoje.
- Nenhum deles segue um pianista ao vivo; a troca de slide é manual ou presa
  a um áudio de tempo fixo.

## Desenho proposto

Três partes independentes, ligadas por uma "posição" (onde estamos no hino
desdobrado):

```
fonte da posição            letra em slides            telão
(playback do zywny   ──►   (slide atual,       ──►   (página na rede local,
 ou seguidor MIDI)          próximo slide)            2ª tela, Holyrics…)
```

### 1. Letra em slides, a partir do catálogo e das âncoras

- **Levar os versos ancorados ao zywny** (passo G, simplificado): o
  `NNN.letra.json` do Hymn_Grabber vai para o pacote (`.vsb` ou o formato da
  biblioteca, B01/B02) como está: a lista de versos na ordem cantada, cada um
  com `ordem`, `coro`, `linha`, `texto`, `ancora` e `inicio` (`k`,
  `compasso`, `passagem`, `tempo`). Não há mais sílabas por nota, `syllabic`
  ou `@wordpos`, elisão nem `extend`. **Exceção:** o destaque da sílaba
  (karaokê, D-TEL-VISUAL) precisa de sílaba por nota, que o catálogo não tem;
  se essa opção for escolhida, o passo G volta a exportar a letra da
  partitura (e o LT06 do Hymn_Grabber entra).
- **No zywny (Dart puro):**
  - os versos já vêm prontos: não é preciso juntar sílabas em palavras nem
    cortar frases por pontuação. Montar os slides de 2 linhas a partir dos
    versos (teto de caracteres por linha);
  - converter `k` + `tempo` em posição no hino desdobrado e em ms, pelo
    `ScoreTimeline` do zywny. **A conferir no O01:** o `k` do Hymn_Grabber
    (índice da música desdobrada, que conta também a introdução) tem de ser o
    índice de `ScoreTimeline.measures`; testar nos 600 hinos;
  - `ancora` diz a precisão: `"1a palavra"` é a nota certa; `"palavra N"` é
    mais tarde que o começo do verso; `"nenhuma"` (`inicio` nulo) não tem
    instante, e o zywny decide (por exemplo, trocar no fim do verso anterior);
  - o coro vem marcado (`coro`: true) e por extenso a cada vez que é cantado,
    na ordem cantada: o zywny não precisa procurar `name="coro"` na
    partitura;
  - cada slide guarda a âncora do 1º verso que cobre: é isso que liga slide e
    música.
- **Correção manual:** se o corte em slides ficar ruim num hino, uma
  sobreposição opcional dentro do pacote `.zywny` (fase B) ajusta as quebras.

### 2. Fontes da posição

**2a. Playback do zywny (primeiro, sem risco).** O `ScorePlayer` já sabe a
posição em ms e a passagem; a letra só acompanha. Isso já substitui os
programas de playback de hoje e testa as partes 1 e 3 sem depender do
seguidor.

**2b. Seguidor do pianista (`LiveFollower`, Dart puro, novo).**

- **Estados:** os passos (acordes, `PerformanceTrack.chords`) do hino
  desdobrado **segundo o roteiro** (abaixo), com as notas de cada passo e a
  nota da melodia (voz de cima).
- **Modelo:** HMM em linha (algoritmo forward). A cada `PlayedNote`, a
  crença se espalha entre "fica", "avança 1" e "pula alguns", ponderada
  pelo tempo decorrido em relação ao esperado pelo **andamento estimado**
  (média móvel da razão entre o intervalo real e o escrito). A observação
  pontua o quanto a nota combina com o passo:
  - a melodia pesa mais que o acompanhamento;
  - a mesma classe de altura em outra oitava conta (o pianista dobra o
    baixo);
  - nota que não existe no passo é penalizada, mas não derruba.
- **Silêncio** (fermata, respiração entre estrofes, "amém") mantém a
  posição.
- **Relocalização:** quando a confiança cai por alguns eventos seguidos,
  procurar no hino inteiro as últimas 4–6 notas da melodia (índice de
  n-gramas). Isso cobre o pianista que pula um trecho ou repete o coro.
- **Estrofes têm as mesmas notas.** O seguidor não distingue a 2ª da 3ª
  pelo que ouve. Por isso existe o **roteiro**: antes do culto define-se
  "hino 123, com introdução, estrofes 1, 2 e 4". O seguidor desdobra o
  hino nessa ordem, e na relocalização prefere a estrofe esperada. Um botão
  "estrofe N" corrige na hora.
- **Tolerância como vantagem:** a letra muda por frase, não por nota.
  Basta saber em que frase estamos e **trocar o slide um pouco antes** da
  próxima frase (previsão pelo andamento — a congregação precisa ler antes
  de cantar), como faz um operador humano.

### 3. O telão (ordem recomendada)

1. **Página servida pelo próprio aparelho na rede local.** O zywny abre um
   servidor HTTP + WebSocket e mostra um QR code com
   `http://<ip-local>:<porta>`. Qualquer navegador abre: o computador do
   projetor, uma smart TV, ou uma **fonte de navegador do OBS** (útil para a
   transmissão do culto). A página recebe "slide atual / próximo slide" e
   pode ter um modo operador (botões de correção).
   *Não* dá para usar a versão do GitHub Pages: uma página HTTPS não abre
   `ws://` na rede local (conteúdo misto bloqueado).
2. **Segunda tela do próprio aparelho:** `Presentation` do Android
   (HDMI/USB-C), ou uma janela em tela cheia no monitor do projetor no
   desktop.
3. **Integração com o Holyrics** (API Server): o zywny mandaria trocar o
   slide. Depende de os slides do Holyrics baterem com os do zywny e de uma
   API ainda mal documentada. Fica por último.

## Riscos conhecidos

- **Âncoras faltando ou imprecisas.** A ordem dos versos vem do catálogo e
  não depende mais do `number` do `<lyric>`; o risco passou para as âncoras:
  das 14.035, 359 estão numa palavra depois da 1ª e 35 não têm instante. Os
  piores hinos (458, 514, 405, 248, 525, 336, 159, 033) têm erro de texto ou
  coro sem marca na partitura (LT05 e LT09 do Hymn_Grabber melhoram isso).
  Hinos com casas, coro de uma linha, estrofe de duas linhas (496, 461, 473,
  513) e repetição implícita (506, 496, 473) seguem como os casos a conferir
  no O01, porque `k` e `passagem` dependem do desdobramento.
- **Introdução:** pianistas costumam tocar uma introdução própria (ou só os
  últimos compassos). O seguidor não deve trocar o slide da 1ª estrofe
  durante a introdução; a relocalização precisa saber que a introdução é
  opcional.
- **Arranjo livre:** quem improvisa, modula na última estrofe ou toca só
  acordes derruba o casamento por notas. A modulação pode ser tratada como
  transposição (a fase Q já tem o cálculo); acordes sem melodia precisam de
  observação por classe de altura.
- **Hinos sem letra:** nenhum no corpus (os 600 têm letra). Se um hino vier
  sem letra, o telão diz que não há letra; nada mais.
- **Direitos:** as letras têm direitos de terceiros, como as partituras;
  seguem a mesma regra do pacote de hinos (B00: o app não traz hino nenhum).
  No Hymn_Grabber, os `NNN.letra.json` trazem o texto do catálogo (CPB) e
  ficam no git (D-LT-ROTEIRO); no zywny devem entrar só nos pacotes, nunca no
  app.

## Passos (preliminares)

| Passo | Título | Depende de |
| --- | --- | --- |
| G (bridge, nº a definir) | Levar os versos ancorados (`NNN.letra.json`) ao pacote/`.vsb` + spec | — |
| O01 | Letra em slides (Dart puro): versos → slides de 2 linhas; `k` + `tempo` → posição no hino desdobrado; testes no corpus, inclusive `k` × `ScoreTimeline` | G |
| O02 | Roteiro do hino: estrofes escolhidas, com/sem introdução; desdobrar o `PerformanceTrack` nessa ordem | O01 |
| O03 | Telão: servidor HTTP/WebSocket local, página do telão, QR code | O01 |
| O04 | Letra seguindo o playback do zywny (fonte 2a) — **primeira entrega** | O02, O03 |
| O05 | Corpus de execuções reais: gravar os pianistas em MIDI, anotar as trocas de slide certas | — |
| O06 | `LiveFollower` (Dart puro): HMM, andamento, relocalização; medido contra O05 | O02, O05 |
| O07 | Letra seguindo o pianista (fonte 2b) + correção manual (estrofe, avançar/voltar) | O04, O06 |
| O08 | Segunda tela (Android `Presentation`, janela no desktop) | O04 |
| (depois) | Integração com o Holyrics; seguir piano acústico pelo microfone | — |

**Dependência do Hymn_Grabber:** O01, O02 e O04 precisam do LT08 do Hymn_Grabber
(que usa o LT07 e o LT03), feito em 2026-10-07: ele grava
`Hymn_Grabber/musicxml/NNN.letra.json`. O LT02 (`number` = passagem) só importa
para a letra desenhada sob as notas, não para o telão.

**Medida do seguidor (O05/O06):** a porcentagem de trocas de slide feitas
antes da 1ª sílaba da frase seguinte e não antes de ~1 tempo do fim da frase
atual. A recuperação, depois de um trecho pulado, é medida em número de
notas.

## Decisões

| Id | Pergunta | Opções |
| --- | --- | --- |
| D-TEL-CANAL | Por onde a letra chega ao telão primeiro? | página na rede local (recomendado) · 2ª tela do aparelho · Holyrics |
| D-TEL-VISUAL | Como mostrar? | slide de 2 linhas · slide + destaque da sílaba (karaokê) · configurável |
| D-TEL-ROTEIRO | Quem monta o roteiro (estrofes, introdução)? | o pianista no aparelho · o operador pela página do telão · os dois |
| D-TEL-LIVRE | Quanto o pianista se afasta da partitura? | toca como está · introdução própria · improvisa/modula — define a tolerância do seguidor |

## Fontes

- Matchmaker: An Open-Source Library for Real-Time Piano Score Following and
  Systematic Evaluation — https://arxiv.org/html/2510.10087v1
- Pairing Real-Time Piano Transcription with Symbol-level Tracking for
  Precise and Robust Score Following — https://arxiv.org/pdf/2505.05078
- The ACCompanion: an automatic piano accompanist —
  https://arxiv.org/pdf/2304.12939
- Online Score Following (WAC 2024) —
  https://www.mit.edu/~mcaren/papers/Online_Score_Following___WAC_2024.pdf
- Holyrics — https://holyrics.com.br ; API, issue do módulo do Companion —
  https://github.com/bitfocus/companion-module-limagiran-holyrics/issues/9
- Quelea — https://signpath.org/projects/quelea
- OpenSong API — https://opensong.org/development/api/
- SDA Hymnal MLC — https://apps.apple.com/vu/app/id6759757430
