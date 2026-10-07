# O00 — Letra no telão, em sincronia com o pianista

**Repo:** zywny (+ um passo no bridge) · **Status:** pesquisa e proposta
(2026-10-07), **nada implementado** · **Quando:** depois da 1.0 ·
**Decisões necessárias:** sim, ver "Decisões" no fim.

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

- **A letra já está nos hinos.** No Hymn_Grabber, 581 dos 584 arquivos de
  `musicxml/` têm `<lyric>` por nota, numerados por estrofe
  (`<lyric name="1" number="1">`, `"2"`, `"3"`…); em `musicxml_special/`, 19
  dos 41. O hino 001 tem 46 sílabas em cada uma das 3 estrofes.
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
  **por passagem**, com `pass`. Logo, **passagem N ↔ estrofe N** (a
  conferir nos hinos com casas e coro; ver Riscos).
- **O que falta:**
  1. o `.vsb` **não** exporta a letra de forma estruturada — a spec
     `docs/formato/especificacao-v1.md` do bridge só cita `lyricist`. A
     letra existe apenas como glifos na cena;
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

### 1. Letra em slides, a partir da partitura

- **Exportar a letra no bridge** (passo G novo): para cada nota com letra,
  `noteId → [(estrofe, texto da sílaba, posição na palavra)]`, onde a
  posição vem do `syllabic` do MusicXML / `@wordpos` do MEI
  (`single|begin|middle|end`), mais elisão e prolongamento (`extend`). Mesmo
  espírito do `notes.json` (N01/G01).
- **No zywny (Dart puro):**
  - juntar sílabas em palavras e palavras em frases. Corte de frase:
    pontuação seguida de nota longa ou pausa; teto de caracteres por linha;
  - frases em slides de 2 linhas;
  - o coro (só uma linha de letra) repete em toda estrofe;
  - cada slide guarda o intervalo de eventos (no hino desdobrado) que cobre:
    é isso que liga slide e música.
- **Correção manual:** se o corte automático ficar ruim num hino, uma
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

- **Passagem ↔ estrofe** nos hinos com casas, coro de uma linha, estrofe de
  duas linhas (496, 461, 473, 513) e repetição implícita (506, 496, 473):
  conferir no corpus antes de confiar no mapeamento simples.
- **Introdução:** pianistas costumam tocar uma introdução própria (ou só os
  últimos compassos). O seguidor não deve trocar o slide da 1ª estrofe
  durante a introdução; a relocalização precisa saber que a introdução é
  opcional.
- **Arranjo livre:** quem improvisa, modula na última estrofe ou toca só
  acordes derruba o casamento por notas. A modulação pode ser tratada como
  transposição (a fase Q já tem o cálculo); acordes sem melodia precisam de
  observação por classe de altura.
- **Hinos sem letra** (3 em `musicxml/`, 22 em `musicxml_special/`): o
  telão diz que não há letra; nada mais.
- **Direitos:** as letras têm direitos de terceiros, como as partituras;
  seguem a mesma regra do pacote de hinos (B00: o app não traz hino nenhum).

## Passos (preliminares)

| Passo | Título | Depende de |
| --- | --- | --- |
| G (bridge, nº a definir) | Exportar a letra estruturada no `.vsb` (nota → estrofe → sílaba, `wordpos`) + spec | — |
| O01 | Letra em slides (Dart puro): sílabas → palavras → frases → slides; passagem → estrofe; testes no corpus | G |
| O02 | Roteiro do hino: estrofes escolhidas, com/sem introdução; desdobrar o `PerformanceTrack` nessa ordem | O01 |
| O03 | Telão: servidor HTTP/WebSocket local, página do telão, QR code | O01 |
| O04 | Letra seguindo o playback do zywny (fonte 2a) — **primeira entrega** | O02, O03 |
| O05 | Corpus de execuções reais: gravar os pianistas em MIDI, anotar as trocas de slide certas | — |
| O06 | `LiveFollower` (Dart puro): HMM, andamento, relocalização; medido contra O05 | O02, O05 |
| O07 | Letra seguindo o pianista (fonte 2b) + correção manual (estrofe, avançar/voltar) | O04, O06 |
| O08 | Segunda tela (Android `Presentation`, janela no desktop) | O04 |
| (depois) | Integração com o Holyrics; seguir piano acústico pelo microfone | — |

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
