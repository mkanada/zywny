# Q00 — Transpor para ler sem acidentes: especificação e índice da fase Q

A pessoa pode **transpor a música para um tom sem sustenidos nem bemóis na
armadura**. Ela lê e toca as teclas do tom fácil. O app diz **qual
transposição ajustar no teclado** (o botão TRANSPOSE dos teclados digitais)
para que a música volte a soar no tom original.

Exemplo: hino em Mi♭ maior (3 bemóis). O app mostra a partitura em Dó maior,
uma terça menor abaixo, e diz: **"No teclado: TRANSPOSE +3. A tecla Dó vai
soar Mi♭."** A pessoa toca as teclas de Dó maior e o teclado soa em Mi♭, junto
com o acompanhamento do app.

Este arquivo é a especificação (escrita em 2026-10-04, a pedido do usuário)
e o índice dos passos Q01–Q08. **As decisões D-TRP-\* foram tomadas pelo
usuário em 2026-10-04** (tabela "Decisões"). Quem executa um passo lê o
`README.md`, **este arquivo** e o arquivo do passo.

Prefixo **Q**: não colide com os prefixos do zywny nem com os do bridge
(F/S/R/A/E/P/G).

## As três alturas

Com a transposição ligada, cada nota tem três alturas. O plano inteiro é
manter as três separadas e converter num lugar só.

| Altura | O que é | Exemplo (Mi♭ → Dó, `k = −3`) |
| --- | --- | --- |
| **escrita** | O que está na partitura transposta e a tecla que a pessoa aperta | Dó4 = 60 |
| **soada** | O que se ouve: o tom original | Mi♭4 = 63 = escrita − k |
| **recebida** | O número que o teclado manda pelo MIDI | 60 **ou** 63, conforme o modelo do teclado (ver abaixo) |

`k` é o deslocamento da partitura em semitons (negativo = desceu). O teclado
precisa de **TRANSPOSE = −k**.

### O problema do MIDI do teclado

Teclados diferentes tratam a própria transposição de jeitos diferentes:

- **Muda só o som interno**: a tecla Dó soa Mi♭, mas o MIDI sai como 60.
- **Muda também a saída MIDI**: o MIDI sai como 63.
- **Muda o que entra pelo MIDI** (as notas que o app manda para o teclado
  soar, M03): em alguns modelos sim, em outros não.

Não dá para saber pelo nome do aparelho. O app **descobre na conferência**
(Q06) e guarda a resposta **por teclado** (nome do dispositivo MIDI), nas
configurações gerais. Daí em diante:

- **casador** (`PracticeController._onNote`, `lib/practice/practice_controller.dart`
  L473): recebe a nota já convertida para a altura **escrita**. Se o teclado
  transpõe a saída, soma `k`; se não, deixa como veio. O resto do treino (T01–T05,
  trilha J, decorar L) não muda: compara escrita com escrita.
- **som do app** (agendador K04 e motores K02/W04): toca a altura **soada**.
- **monitor** (`MidiMonitor._onNote`, `lib/midi/midi_monitor.dart` L30): toca
  a altura soada da nota recebida.
- **saída para o teclado** (M03, `MidiOutSoundEngine`): manda a soada se o
  teclado **não** transpõe a entrada; manda a escrita se transpõe.

Uma classe pequena e pura (`PitchFrame`: `k`, "teclado transpõe a saída?",
"teclado transpõe a entrada?") faz as quatro conversões e tem teste de tabela.
Ninguém mais soma semitom solto pelo código.

### Quando o som é do app, não há nada a fazer no teclado

Se o teclado não tem som próprio (controlador) ou o som vem do app (monitor
ligado), o próprio app toca a altura soada e a pessoa **não mexe no teclado**.
A tela diz isso em vez da instrução de TRANSPOSE.

## Como escolher a transposição

A armadura inicial já está no catálogo: `Piece.fifths`
(`lib/library/piece.dart` L77, como o `<fifths>` do MusicXML). Para zerar a
armadura, a música anda **−fifths quintas**. Isso fixa a grafia (Mi♭ vira Dó,
não Si♯) e vale igual para maior e menor (3 bemóis vão para Dó maior ou Lá
menor sem precisar saber o modo). Das duas direções, fica a **menor** (|k| ≤ 6).

| Armadura original | Partitura | Intervalo (Verovio) | `k` | No teclado |
| --- | --- | --- | --- | --- |
| 1♯ (Sol / Mi m) | sobe 4ª justa | `P4` | +5 | −5 |
| 2♯ (Ré / Si m) | desce 2ª maior | `-M2` | −2 | +2 |
| 3♯ (Lá / Fá♯ m) | sobe 3ª menor | `m3` | +3 | −3 |
| 4♯ (Mi / Dó♯ m) | desce 3ª maior | `-M3` | −4 | +4 |
| 5♯ (Si / Sol♯ m) | sobe 2ª menor | `m2` | +1 | −1 |
| 6♯ (Fá♯ / Ré♯ m) | trítono (D-TRP-DIRECAO) | `-A4` ou `d5` | ∓6 | ±6 |
| 7♯ (Dó♯ / Lá♯ m) | desce uníssono aumentado | `-A1` | −1 | +1 |
| 1♭ (Fá / Ré m) | desce 4ª justa | `-P4` | −5 | +5 |
| 2♭ (Si♭ / Sol m) | sobe 2ª maior | `M2` | +2 | −2 |
| 3♭ (Mi♭ / Dó m) | desce 3ª menor | `-m3` | −3 | +3 |
| 4♭ (Lá♭ / Fá m) | sobe 3ª maior | `M3` | +4 | −4 |
| 5♭ (Ré♭ / Si♭ m) | desce 2ª menor | `-m2` | −1 | +1 |
| 6♭ (Sol♭ / Mi♭ m) | trítono (D-TRP-DIRECAO) | `A4` ou `-d5` | ±6 | ∓6 |
| 7♭ (Dó♭ / Lá♭ m) | sobe uníssono aumentado | `A1` | +1 | −1 |

Além do padrão "sem acidentes", a pessoa pode escolher **qualquer um dos 12
tons** numa lista que mostra, para cada um, a armadura resultante e a
instrução do teclado (ex.: "1♯ · teclado −2"). Isso cobre quem prefere um tom
com um acidente e menos deslocamento.

**Faixa**: depois de transpor, a nota mais grave e a mais aguda precisam
caber no teclado. Hoje o app supõe 88 teclas (`PianoKeyboardPainter`
L21–L22, A0–C8). Se a direção escolhida passar da faixa, usa a outra; se as
duas passarem, avisa.

**Mudança de tom no meio**: a transposição é uma só para a música inteira (o
TRANSPOSE do teclado é um só). A segunda armadura pode continuar com
acidentes. O app não tenta otimizar isso na v1; avisa "a partir do compasso N
a armadura tem 2♯". **É barato** (Q01): vem do `key` de cada nota no
`pitchpos.json` + a ordem dos `measureOn` do timemap, sem render a mais
(40–440 µs por hino). No catálogo são 38 hinos de 469, e em 35 deles a armadura
que sobra tem **mais** acidentes que a do trecho original (26 chegam a 5 ou
mais): o aviso importa.

**O catálogo de hinos só tem armaduras de 5♭ a 4♯** (Q01): as linhas +5, ±6 e
±7 da tabela não aparecem em hino nenhum; foram conferidas por ida e volta
com um hino em Dó, e valem para outras bibliotecas.

## Onde a transposição acontece

**No Verovio, na hora de gerar o `.vsb`.** O fork já tem a opção `transpose`
(`verovio/src/options.cpp` L1685, aplicada em `Toolkit::LoadData`,
`src/toolkit.cpp` L872, por `Doc::TransposeDoc`, `src/doc.cpp` L1656). Aceita
um intervalo (`-m3`) ou um tom (`C`). Usamos o **intervalo**, calculado pelo
app: o tom-alvo do Verovio parte da tônica, e em música menor sem `<mode>`
ele erraria (Dó menor em vez de Lá menor).

Passar `{"transpose": "-m3"}` em `VsbRenderRequest.options`
(`lib/verovio_render.dart` L15) muda de uma vez:

- a cena: armadura, notas, acidentes, cifras;
- o timemap e o `midi.json` (N01): pitches já na altura **escrita**. O
  documento expandido das repetições (`Toolkit::SetMidiDoc`, L288) é
  importado do MEI já transposto, então também sai transposto — **Q01
  conferiu que não transpõe duas vezes** (417 hinos com repetição, 152.135
  notas, todas deslocadas uma vez só);
- a Web: o worker (`web/verovio_worker.js` L40) passa as mesmas opções ao
  WASM.

Os `xml:id` são sorteados de novo **a cada render**, com ou sem transposição
(o app não passa `xmlIdSeed`; Q01 mediu), então nada que o app guarda usa id
de nota: a trilha (J) guarda por trecho (`t<N>.<fase>`) e os destaques vivem
numa renderização só. Por isso trilha, decorar (L) e destaques **funcionam
igual** na partitura transposta: o `midi.json`, o timemap e a cena trazem o
mesmo número de notas, na mesma ordem, com os mesmos tempos. (Com a mesma
semente os ids dos elementos musicais ficam iguais entre original e
transposto; quem precisar disso passa `xmlIdSeed` nas opções.) O progresso,
porém, é **separado por tom** (D-TRP-PROGRESSO, abaixo).

## Progresso separado por tom

Decisão do usuário (D-TRP-PROGRESSO): original e transposta têm **progressos
independentes**, porque a mão aprende outras teclas. Como a lista permite
qualquer um dos 12 tons, o progresso é **por tom** (por intervalo), não só
"original" contra "transposta".

- **Chave**: o tom original mantém as chaves de hoje, sem migração
  (`trailKeyFor`, `lib/library/library_keys.dart` L9: `trail_<bib>_<id>`).
  Um tom transposto acrescenta o intervalo: `trail_<bib>_<id>@-m3`. O mesmo
  sufixo vale para a pontuação (`PieceProgressStore`, mapa id → `{t, s}` em
  `lib_progress_<bib>`: entrada `<id>@-m3`) e, quando existir, para o
  decorar (L04). Uma função só (`progressIdFor(pieceId, transpose)`) monta o
  id; ninguém concatena à mão.
- **"Última aberta"** (`lastOpened`, cartão "Continuar") continua **por
  música**, não por tom: abrir a música em Dó conta como abrir a música.
- **A biblioteca** mostra o progresso do **tom em uso** de cada música (o
  de `PieceSettings.transpose`, ou o da chave geral). Na tela da música, quem
  tem progresso em outro tom vê "Também estudada: original, 3 de 8 trechos".
- **Trocar de tom** com uma trilha em andamento pede confirmação: "Em Dó a
  trilha começa do zero. A do tom original fica guardada."

## Na tela

- **Onde liga**: na gaveta de opções da música (U11), item **"Transpor"**:
  "Não (3♭)" / "Sem acidentes" / "Escolher…" (D-TRP-NOME). Guardado por música em
  `PieceSettings` (`lib/settings/piece_settings.dart` L18), campo novo
  `transpose` (o intervalo, `null` = original). Ligar regrava o `.vsb` como
  qualquer mudança de layout (`_commitLayout`, `lib/main.dart` L2065).
- **Selo na partitura**, sempre visível enquanto transposta: "Mi♭ → Dó ·
  teclado +3". Tocar no selo abre a conferência.
- **Conferência no teclado** (Q06), ao ligar e quando o teclado conectado
  ainda não foi conferido:
  1. "No seu teclado, ajuste **TRANSPOSE para +3**." (com uma ajuda curta e
     genérica de onde fica o botão; nada de prometer o caminho de cada marca);
  2. "Toque o **Dó central**." Teclado de tela mostra a tecla;
  3. o app lê o número que chegou:
     - **63** (= 60 − k): o teclado transpõe a saída MIDI e está certo.
       Guarda "transpõe a saída" para este teclado;
     - **60**: ou o teclado não transpõe a saída, ou a pessoa não ajustou.
       Pergunta de ouvido: o app toca Mi♭4 pelo próprio som e pergunta
       "Soou igual à sua tecla?". Sim → guarda "não transpõe a saída";
       não → volta ao passo 1;
     - **outro valor**: "Seu teclado parece estar em +x. Ajuste para +3.";
  4. se o app também toca pelo teclado (M03): manda duas notas e pergunta
     "Qual soou igual à sua tecla Dó, a 1ª ou a 2ª?" → guarda "transpõe a
     entrada".
- **Lembrete de voltar ao normal**: ao abrir uma música **sem** transposição
  depois de uma transposta, ou ao sair do app com uma transposta aberta:
  "Volte o TRANSPOSE do teclado para 0." Se o teclado transpõe a saída MIDI,
  o app **vê** que ele ainda está deslocado (próximo item) e só avisa quando
  precisa.
- **Detector de deslocamento** (vale para qualquer música, transposta ou
  não): se as últimas N notas erradas estão todas a uma mesma distância d ≠ 0
  das certas, o app diz "Parece que o teclado está transposto em d. Ajuste
  para 0" (ou para o valor pedido). Pega o caso comum de esquecer o
  TRANSPOSE ligado de ontem — **só em teclado que transpõe a saída MIDI**:
  nos outros o número que chega não muda, e quem cobre é o lembrete.

## O que já existe e será reaproveitado

| Peça | Onde | Uso aqui |
| --- | --- | --- |
| Transposição do Verovio | fork: `options.cpp` L1685, `Doc::TransposeDoc`, `transposition.cpp` | Toda a partitura, timemap e MIDI |
| Opções por música | `PieceSettings` (L18), `PieceSettingsStore` (L133) | Guardar o intervalo |
| Opções passadas ao render | `VsbRenderRequest.options`, `_renderInIsolate` L63; `web/verovio_worker.js` L32 | Passar `transpose` |
| Armadura no catálogo | `Piece.fifths`, `keySignatureLabel` (`piece.dart` L168) | Calcular o intervalo e escrever "3♭" |
| Entrada MIDI | `PlayedNote`, `FlutterMidiInputService._emitNote` (`midi_input_service.dart` L125) | Converter para a altura escrita |
| Treino | `PracticeController._onNote` L473, `WaitModeSession.noteOn`, `RealtimeSession.noteOn` | Não muda: recebe a escrita |
| Monitor e saída MIDI | `MidiMonitor` (L15), `MidiOutSoundEngine` | Tocar a soada |
| Teclado desenhado | `PianoKeyboardPainter` | Mostrar a tecla do teste |
| Gaveta de opções | U11 | O item "Transpor" |
| Chaves de progresso | `library_keys.dart` (`trailKeyFor` L9), `PieceProgressStore`, `TrailProgressStore` (`trail_progress.dart` L270) | Progresso por tom |

## Decisões

Todas tomadas pelo usuário em 2026-10-04.

| Id | Pergunta | Decisão |
| --- | --- | --- |
| D-TRP-ALVO | Para onde transpor por padrão | Armadura **sem acidentes** (Dó maior / Lá menor), mais a lista dos 12 tons para quem quiser outro |
| D-TRP-DIRECAO | Subir ou descer | O menor deslocamento (\|k\| ≤ 6). No trítono (6♯/6♭), **descer**, salvo se sair da faixa do teclado |
| D-TRP-SOM | Em que tom o app toca (acompanhamento, "ouvir o trecho", monitor) | No **original**, para casar com o teclado transposto. Sem modo "só leitura" na fase Q |
| D-TRP-ESCOPO | Por música ou para todas | **Por música** (`PieceSettings`), mais uma **chave geral** "abrir as músicas já sem acidentes", desligada por padrão |
| D-TRP-PROGRESSO | O progresso vale com e sem transposição? | **Separado**: cada tom tem o seu progresso (seção "Progresso separado por tom") |
| D-TRP-CONFERIR | Quando conferir o teclado | Na **primeira vez por teclado** (comportamento guardado pelo nome do dispositivo) e quando a pessoa toca no selo; o detector de deslocamento cobre o resto |
| D-TRP-NOME | Como chamar na tela | **"Transpor"** na gaveta: "Não (3♭)" / "Sem acidentes" / "Escolher…"; no selo, "Mi♭ → Dó · teclado +3". Nomes Dó-Ré-Mi |
| D-TRP-LICOES | Lições da fase I podem travar o tom? | **Fora da fase Q**. Se a fase I quiser, uma lição declara `tom: original` e o app esconde o item |

## Passos

| Passo | O que entrega | Depende de | Estado |
| --- | --- | --- | --- |
| [Q01](Q01-verovio-transpondo.md) | Medir o Verovio transpondo: cena, timemap, `midi.json`, alternates e repetições coerentes em hinos de cada armadura; sem transposição dupla no doc expandido; tempo de render; mudança de armadura no meio | — | **concluído** (2026-10-06): 469 hinos, 0 problemas; ver as descobertas nas notas |
| [Q02](Q02-calculo-da-transposicao.md) | Cálculo puro: `Transposition` (intervalo, `k`, armadura resultante, instrução do teclado, faixa) e `PitchFrame` (as conversões); testes de tabela | — | **concluído** (2026-10-06) |
| [Q03](Q03-guardar-e-renderizar.md) | Guardar e renderizar: `PieceSettings.transpose`, chave geral, `transpose` no render (nativo e Web) | Q01, Q02 | pendente |
| [Q04](Q04-progresso-por-tom.md) | Progresso por tom: `progressIdFor`, trilha e pontuação com sufixo, biblioteca mostra o tom em uso | Q03 | pendente |
| [Q05](Q05-as-alturas-no-app.md) | As alturas no app: casador recebe a escrita; agendador, monitor e saída MIDI tocam a soada; comportamento por teclado guardado | Q02, Q03 | pendente |
| [Q06](Q06-conferencia-no-teclado.md) | Conferência no teclado: instrução, "toque o Dó", teste de ouvido, teste da entrada MIDI | Q05 | pendente |
| [Q07](Q07-lembretes-e-detector.md) | Lembrete de voltar ao normal e detector de deslocamento (vale para toda música) | Q05 | pendente |
| [Q08](Q08-tela-e-aceite.md) | Tela (item "Transpor", lista dos 12 tons, selo, "também estudada"), `just telas` e aceite manual com o teclado do usuário | Q04, Q06, Q07 | pendente |

### Critérios de aceite da fase

1. Um hino em Mi♭ abre transposto em Dó: armadura vazia, cifras transpostas,
   mesmos compassos e as mesmas notas, nos mesmos tempos, que o original.
2. Com o teclado em +3, tocar as teclas de Dó maior passa no modo espera e no
   tempo real, **nos dois tipos de teclado** (que transpõe a saída MIDI e que
   não transpõe), testados com MIDI falso.
3. "Ouvir o trecho" e o acompanhamento soam em Mi♭.
4. Transpor uma música com trilha em andamento começa uma trilha nova em
   Dó; voltar ao original reencontra a trilha original onde ela estava.
5. Esquecer o teclado em +3 numa música sem transposição gera o aviso do
   detector em até N notas (teclado que transpõe a saída MIDI) ou o
   lembrete de voltar a 0 (teclado que não transpõe).
6. Desligar a transposição volta à partitura original: mesmo layout, mesmas
   notas e tempos. (Não é byte a byte: os ids mudam a cada render, como em
   qualquer re-render; com a mesma semente os membros do `.vsb` saem iguais
   — Q01.)

## Riscos

- **Comportamento do TRANSPOSE por marca**: a tabela de três alturas parte do
  que se sabe de forma geral. O aceite manual (Q08) com o teclado real do
  usuário é o que vale; se aparecer um quarto comportamento, o `PitchFrame`
  ganha uma linha.
- **Faixa do TRANSPOSE**: muitos teclados vão de −12 a +12; alguns só de −6 a
  +5. Com |k| ≤ 6 o caso ruim é só o trítono, por isso a direção dele é
  decisão.
- **Instrumentos transpositores** (`transSemi` no MusicXML): irrelevante no
  repertório de piano de hoje. Se aparecer, a transposição do app soma à do
  instrumento; Q01 só registra.
- **Grafia estranha**: transpor por intervalo mantém a grafia relativa, então
  um Fá♭ no original pode virar um Ré♭♭. É raro em hinos: Q01 contou 11 hinos
  de 469 com dobrados depois de transpor (41 notas; 3 hinos, 6 notas, já tinham
  no original).

## Fora de escopo da fase Q

- Transpor por oitava (só tom).
- Mudar a transposição no meio da música (uma por música).
- Ler ou mandar o TRANSPOSE do teclado por MIDI (SysEx/RPN de afinação grossa
  varia por fabricante); a pessoa ajusta no botão.
- Transpor partituras de lições (fase I) e exercícios gerados.
