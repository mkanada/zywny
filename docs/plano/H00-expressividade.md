# H00 — Execução expressiva (regras do KTH, humanização 1/f, rubato)

**Repo:** zywny (+ um passo no bridge) · **Status:** pesquisa concluída
(2026-09-26), **nada implementado** · **Quando:** depois da 1.0 (não faz parte
de V01) · **Decisões necessárias:** sim, ver "Decisões" no fim.

Este arquivo é autossuficiente: reúne a pesquisa das ferramentas existentes,
o que o `.vsb` do zywny oferece hoje, o desenho da integração e a quebra em
passos H01…H06 (+ G03 no bridge). Ao executar um passo H, leia o README do
plano (Convenções, Fatos), este arquivo inteiro, e siga as regras de
execução do README (parar em decisão aberta, notas de execução, sem commit).

Prefixo **H** (humanização): não colide com X/N/C/K/M/T/W/V (zywny) nem com
F/S/R/A/E/P/G (bridge).

## Objetivo

Hoje o play toca a partitura "de máquina": tempo métrico exato e velocity
praticamente constante. Queremos uma execução que soe humana e musical:

1. **dinâmica** (respeitar p/f/crescendo escritos, destacar a melodia,
   acento métrico);
2. **agógica** (rubato em arco de frase, ritardando final, fermatas);
3. **microtiming** (flutuações de ~10 ms com correlação de longo alcance —
   ruído 1/f —, em vez de nada ou de jitter branco).

Tudo **determinístico e baseado em regras** (sem aprendizado de máquina),
controlável por um parâmetro global "expressividade" e por um `k` por regra.

## Pesquisa: o que existe e o que dá para aproveitar

Repositórios clonados e lidos em 2026-09-26 (licenças conferidas no próprio
código, não em resumo de terceiros).

| Projeto | Linguagem | Licença | Uso no zywny |
| --- | --- | --- | --- |
| **Director Musices** (KTH) — `github.com/docfry/Director-Musices` | Common Lisp (`dm-source/rules/*.lsp`) | **Artistic License** (cabeçalho dos `.lsp`, `DIRECTORMUSICES.LICENSE.txt`) | Referência das regras e dos valores padrão. Reimplementar em Dart; as fórmulas estão transcritas abaixo. |
| **pDM** (DM em tempo real, Pure Data) | Pd | — | Só a ideia de UX: sliders de `k` mudando a execução ao vivo. Aqui: mudar `k` recalcula (ms) e reancora o agendador como num seek. |
| **holgerhennig/humanizer** | MATLAB/Octave | **CC BY-NC-SA 4.0** (readme e cada `.m`) | **Não copiar nem portar o código** (NC é incompatível com app possivelmente comercial). Reimplementar a partir dos artigos (Hennig, PNAS 111:12974, 2014; PLoS ONE 6:e26457, 2011). O algoritmo é curto, está descrito abaixo em palavras próprias. |
| **scoremill** — `github.com/CharlesCNorton/scoremill` | Python (`scoremill.py`, ~4 900 linhas) | **MIT** (2026) | Fórmulas simples, copiáveis: acento no tempo forte, voicing, rubato senoidal por N compassos. Não lê MIDI/MusicXML (notação textual própria), então só as fórmulas servem. |

Correção de uma sugestão anterior: a ideia de "ler um `.mid` com `midly` em
Rust e reescrever" **não se aplica** ao zywny. O app não usa `.mid`: as notas
chegam em Dart via `midi.json` → `PerformanceTrack`. As regras moram em Dart.

### Director Musices: regras e valores (transcritos do código)

Unidades do DM: `dr` = duração em ms, `ndr` = duração nominal (de partitura)
em ms, `sl` = nível em **dB** (relativo), `dro` = encurtamento de articulação
(ms). `k` (`quant`) é o multiplicador da regra (1 = valor nominal).

Paleta padrão (`rulepalettes/default.pal`):

```
(HIGH-LOUD 1.0)
(MELODIC-CHARGE 1.0 :AMP 1 :DUR 1 :VIBAMP 1)
(HARMONIC-CHARGE 1.0 :AMP 1 :DUR 1 :VIBFREQ 1)
(DURATION-CONTRAST 1.0 :AMP 1 :DUR 1)
(DURATION-CONTRAST-ART-DR 1.0)
(DOUBLE-DURATION 1.0)
(PUNCTUATION 1.1 :DUR 1 :DUROFF 1 :MARKPHLEVEL7 NIL)
(PHRASE-ARCH 1.5 :PHLEVEL 5 :TURN 0.3 :NEXT 1.3 :AMP 2)
(PHRASE-ARCH 1.5 :PHLEVEL 6 :TURN 2 :AMP 2 :LAST 0.2)
(NORMALIZE-SL T)
(NORMALIZE-DR T)
(FINAL-RITARD 1.0)
sync-rule-list: MELODIC-SYNC   ; as outras vozes seguem o timing da melodia
```

**High Loud** (`rules/frules2.lsp`, versão ativa = a última `defun`): por
trilha, `sl += k · (pitch − média_de_pitch_da_trilha) / 4` dB. Ou seja,
+1 dB a cada terça maior acima da média, com k = 1.

**Duration Contrast** (`frules2.lsp`, `duration-contrast1` +
`-short-soft` + `-short-short`): para cada nota (não pausa) com duração `dr`
(ms):

```
30 < dr ≤ 200   : c = −11/170 · (dr − 30)          (0 … −11)
200 < dr ≤ 400  : c = −4/200 · (400 − dr) − 7      (−11 … −7)
400 < dr < 600  : c = −7/200 · (600 − dr)          (−7 … 0)
senão           : c = 0
sl += k·amp · 0.075 · c      (dB; até ≈ −0,8 dB)
dr += k·dur · 1.5 · c        (ms; até ≈ −16 ms: nota curta mais curta)
```

**Double Duration** (`frules2.lsp`): nota que dura metade da anterior e é
seguida por uma mais longa (padrão semínima pontuada + colcheia, ou longa-curta),
não em pausa, `dr < 1000`: `Δ = 0.12 · k · ndr`, `dr += Δ` e a anterior
`dr −= Δ` (o contraste de 2:1 fica menor).

**Final Ritard** (`rules/FinalRitard.lsp`, última `defun`, `q = 3`):
cobre os últimos `L = 1300 · k` ms nominais da peça. Com `x ∈ [0,1]` a
posição normalizada dentro desse trecho, o tempo segue o modelo de
Friberg & Sundberg (1999):

```
v(x)   = [1 + (v_end^q − 1) · x]^(1/q)       tempo relativo (1 = original)
v_end  = 1 / (1 + 3k)                        k = 1 → último instante a 25% do tempo
tempo executado acumulado (normalizado, integral de 1/v):
t(x)   = q/((q−1)·K) · (1 + K·x)^((q−1)/q) − q/((q−1)·K),   K = v_end^q − 1
cada nota i no trecho: dr_i = dr_i · ndrtot · (t(xoff_i) − t(xon_i)) / ndr_i
```

**Phrase Arch** (`rules/phrasearch.lsp`, `phrase-arch-mark-ddr` +
`phrase-arch-apply`): para cada frase de nível `phlevel` (marcas
`phrase-start`/`phrase-end`, **obrigatórias**; sem elas a regra não faz
nada):

```
início da frase:  Δdur = +0.10·k·acc     Δnível = −0.5·k·amp·acc  dB
pico (turn):      Δdur = 0               Δnível = 0
fim da frase:     Δdur = +0.20·k         Δnível = −1.0·k·amp      dB
  (fim também de frase de nível −1: × next; de nível −2: × 2next)
turn: inteiro = índice da nota; float = fração da duração da frase;
      negativo = ms antes do fim
rampa entre os pontos: curva potência (power = 2) no tempo nominal
aplicação: dr *= (1 + dur·Δdur);  sl −= Δnível   (k negativo inverte)
last: multiplica o Δdur da última nota (0.2 na paleta: a última nota
      da frase de nível 6 quase não alonga)
```

Com a paleta (k = 1.5, amp = 2): começo de frase +15% mais lento e −1,5 dB;
fim +30% mais lento e −3 dB; meio no tempo e no nível de referência. Dois
níveis sobrepostos (5 = subfrase, turn em 30%; 6 = frase, turn na 3ª nota).

**Punctuation** (`rules/Punctuation.lsp`): segmentação melódica automática
(marca micropausas/limites de frase por pesos de intervalo, duração,
padrões). Parâmetros opacos (`mark-punctuation 2 −4 10 9 9 5 5 4 3 1.2 1 …`);
reimplementar só se a heurística simples de frase (H04) não bastar.

**Fora de escopo por custo**: Melodic Charge e Harmonic Charge (precisam de
tonalidade e análise harmônica acorde a acorde); vibrato/entonação (piano).

Normalização (`NORMALIZE-SL`/`-DR`): depois de todas as regras, o DM
recentra o nível médio e a duração total. Aqui: normalizar o `sl` para média
0 dB e escalar o warp para que a duração total não mude mais que o
ritardando final (opcional; decidir em H04).

### Humanização 1/f (Hennig), descrita para reimplementação

Achado dos artigos: os desvios de timing de músicos não são ruído branco; a
série de desvios tem espectro ~1/f^α (correlação de longo alcance), e
ouvintes preferem esse ruído ao branco. Parâmetros típicos do humanizer:
**σ = 10 ms**, **α = 1**.

Algoritmo (em palavras, não é tradução do `.m`):

1. Gerar N amostras de ruído com densidade espectral `S(f) = 1/f^α`:
   amplitudes `sqrt(S(f))` para f em (0, ½], fase uniforme em [0, 2π),
   componente DC = 0, espectro espelhado conjugado, FFT inversa → série real.
   Alternativa sem FFT: soma de vários AR(1) com constantes de tempo em
   escala geométrica (aproximação de 1/f), ou Voss-McCartney.
2. Normalizar para desvio padrão σ.
3. Suavizar os saltos grandes: onde `|x[n] − x[n−1]| > 2σ`, reduzir o salto
   pela metade; renormalizar para σ.
4. Aplicar `x[n]` como **deslocamento de onset** do n-ésimo "tatum"
   (grupo de notas simultâneas), não por nota: notas do mesmo acorde andam
   juntas (ver também "espalhamento de acorde" abaixo).
5. Duas mãos: o humanizer tem modos "same" (mesma série), "sep" (séries
   independentes) e "couple"/"mics" (duas séries acopladas, peso W ≈ 0,5). No
   piano, uma pessoa só: usar **a mesma série nas duas mãos + um pequeno
   termo independente por mão** (σ₂ ≈ 3 ms) é o ponto de partida sensato.

Semente fixa por peça + contador de execução: toques diferentes a cada play,
mas reprodutível em teste.

### scoremill: fórmulas (MIT, `scoremill.py` L3290-L3330 e L3390-L3400)

```
expressive:
  nota no tempo forte (downbeat)       vel += 3
  contorno melódico                    vel += clamp((pitch_top − média)/4, −6, +6)
  nota mais aguda de um acorde         vel += 5
humanize = h:
  vel += rand(−2, 2);  onset += rand(−h, h) · 4 ticks     (ruído branco)
rubato(depth d, phrase P compassos, shape):
  x = (posição_em_compassos mod P) / P
  arch:   bpm *= 1 + d·sin(π·x);   se x > 0.85: bpm *= 1 − 1.2·d
  cradle: bpm *= 1 − d·sin(π·x)
fermata: bpm /= 1.55 no trecho da fermata
```

Útil como **primeira versão** do arco: não precisa de análise de frase
(frase = P compassos fixos, padrão 2).

## O que o zywny oferece hoje (medido em 2026-09-26)

- `midi.json` (via `VsbMidi`/`MidiNote`, bridge
  `score_bridge/lib/src/model.dart` L124): `id, onMs, offMs, pitch, staff,
  layer, channel, program, velocity, tied, ornament`. Chaves no JSON: `id,
  on, off, p, s, l, v, tied`.
- **Velocity praticamente constante**: `maple-leaf-rag.vsb` só tem 85 (1 343
  notas) e 90 (1 225); `erik-satie.vsb` tem 90 em todas as 455. Motivo:
  `GenerateMIDIFunctor::VisitNote` (fork, `src/midifunctor.cpp` ~L838) usa
  `note->HasVel() ? GetVel() : MIDI_VELOCITY`; **não há** tratamento de
  `dynam`, `hairpin`, articulação, `slur` nem `fermata` no
  `midifunctor.cpp` (grep sem resultado).
- `timemap.json` (`TimemapEntry`): `tstamp` (ms), `qstamp` (semínimas,
  **cumulativo e monotônico mesmo com repetições expandidas**: Gymnopédie vai
  a 234 q com `-rend2` a partir de q = 117), `on`/`off` (ids, com `-rend<N>`),
  `measureOn` (id do compasso que começa ali), `tempo` (BPM, só onde muda).
  Os ids de `on` batem com os `id` de `midi.json`.
- Portanto dá para derivar **sem mexer no fork**: posição métrica de cada
  nota (interpolando `tstamp → qstamp` no `onMs`), inícios de compasso,
  duração do compasso em semínimas (≈ métrica), duração nominal em
  semínimas, nota mais aguda por pauta/onset (≈ melodia), última nota,
  pausas (lacunas sem nota soando).
- **Não dá** (precisa do fork, G03): dinâmicas escritas, hairpins,
  staccato/acento/tenuto, ligaduras de expressão (slur, melhor aproximação de
  frase disponível na partitura), fermatas, respirações/cesuras.
- Pedal já vem (`VsbMidi.pedal` → `PerformanceTrack.pedal`), mas o agendador
  do K04 ainda não o agenda (verificar antes de H03; não é deste plano).

### Pontos de código (estado em 2026-09-26)

| O quê | Onde |
| --- | --- |
| Eventos tocáveis | `lib/music/performance_track.dart`: `SoundEvent` L11, `PerformanceTrack` L67, `startingIn` L154, `chords` L178, `chordToleranceMs = 30` L69 |
| Agendador | `lib/audio/score_audio_scheduler.dart`: `_musicalAt` L72, `_deviceAt` L75, `_reanchor` L78, `play` L91, `seek` L114, `setSpeed` L125, `pump` L169 (monta `ScheduledMidi` de `e.onMs`/`e.offMs`/`e.velocity` em L182-L186), `_kNoteOffLeadSeconds = 0.001` L23 |
| Relógio do destaque | `lib/audio/audio_playback_clock.dart` L11: `positionMs => scheduler.positionMs` |
| Ligação na UI | `lib/main.dart`: `PerformanceTrack.fromDocument` L293, `ScoreAudioScheduler(...)` L397, `AudioPlaybackClock(scheduler)` L399 |
| Motor | `native/zywny_audio/src/engine.rs` L118: `process_midi_message(0, e.msg[0], …)` — **canal fixo 0** (bug anotado em K04); não afeta H, mas peças multicanal soarão erradas até ser corrigido |

## Desenho

### Onde roda

**Dart puro**, pasta nova `lib/music/expression/`. Motivos: os dados já estão
em Dart (`PerformanceTrack`); o cálculo roda **uma vez por peça** (≈ 2,5 mil
notas no maior fixture → milissegundos); a Web (fase W) precisa do mesmo
código sem wasm extra; testável com `flutter test` como N03/K04. O motor Rust
**não muda** (ele só recebe `ScheduledMidi` com velocity e instante).

```
VsbDocument ──► PerformanceTrack (N03, intocado)
      │                │
      └─ timemap ──► ScoreFacts (H01)  ── fatos por evento: qstamp, beat,
                       │                  nível métrico, compasso, melodia,
                       │                  frase, dinâmica escrita (G03)…
                       ▼
                 ExpressionRules (H03-H05), cada uma com k
                       │
                       ▼
                 ExpressivePerformance
                   ├─ TimeWarp  (musical ms ↔ ms executado; global)
                   └─ por evento: velocity final, Δonset (ms), fator de duração
                       │
                       ▼
     ScoreAudioScheduler (K04) usa warp + ajustes ─► SoundEngine
     AudioPlaybackClock usa warp⁻¹ ─► ScorePlayer (destaque segue o rubato)
```

### Separação essencial: warp global × ajuste por nota

Se o rubato só mexesse no `onMs` de cada nota, o destaque visual (que lê a
posição **musical** do relógio) sairia de sincronia com o som. Por isso:

- **`TimeWarp`** (tempo global): função **estritamente crescente, linear
  por trechos**, `performed = warp(musical)`, com inversa exata. Recebe
  tudo que é agógica compartilhada pelas duas mãos: arco de frase, final
  ritard, fermata, deriva lenta 1/f do andamento. É o equivalente do
  `MELODIC-SYNC` do DM: a curva é calculada sobre a melodia e **todas** as
  vozes a seguem.
  - Representação: pontos `(musicalMs, performedMs)` nos onsets
    (≈ `timemap` entries). Entre eles, linear. Busca binária nos dois
    sentidos.
  - Construção: cada regra de tempo produz um fator de duração por intervalo
    entre onsets consecutivos (`dr *= 1 + Δ`); os fatores multiplicam; o warp
    é a soma acumulada das durações executadas.
  - Invariante: fator > 0 sempre (clamp em, por exemplo, [0.25, 4]).
- **Ajustes por evento** (pequenos, invisíveis no destaque): Δvelocity,
  Δonset (melodia adiantada ~10-20 ms, espalhamento de acorde, componente
  independente do ruído 1/f), fator de duração/articulação (Duration
  Contrast, staccato, legato).

### Integração no agendador (H02)

Mudança mínima e localizada em `ScoreAudioScheduler`, mantendo a janela em
**tempo musical** (`startingIn` continua igual):

```dart
// âncora passa a guardar posição executada
_perfT0 = warp.toPerformed(_musicalT0);
double _musicalAt(double dev) =>
    warp.toMusical(_perfT0 + (dev - _deviceT0) * 1000 * _speed);
double _deviceAtPerformed(double perfMs) =>
    _deviceT0 + (perfMs - _perfT0) / (1000 * _speed);

// em pump(), por evento e (com ajustes adj = perf.of(e)):
onAt  = _deviceAtPerformed(warp.toPerformed(e.onMs)  + adj.onsetMs);
offAt = _deviceAtPerformed(warp.toPerformed(e.offMs) + adj.onsetMs
                           + adj.durationDeltaMs) - lead;
vel   = adj.velocity;
```

- Com `TimeWarp.identity` e ajustes nulos, o comportamento tem de ser
  **idêntico** ao de hoje (critério de H02: toda a suíte do K04 passa sem
  mudar nenhum número).
- `AudioPlaybackClock` não muda: `scheduler.positionMs` já sai de
  `_musicalAt`, que passa a desfazer o warp.
- `seek(toMs)`, `play(fromMs)`: continuam recebendo ms **musicais**
  (vindos do `ScorePlayer.seekToElement`); a âncora converte.
- **Δonset negativo** (nota adiantada): o evento é pedido pela janela
  musical, mas soa antes. Garantir `|Δonset| ≤ 50 ms` (bem abaixo do
  `lookahead` de 250 ms) e manter o `_clamp` em `earliest` (nunca descartar).
  Consultar `startingIn(_scheduledUpToMs, horizonMs + maxLeadMs)` evita o
  atraso no começo da janela.
- **Mesma tecla religada**: com Δonset e mudança de duração, o note-off da
  nota anterior pode cair depois do note-on seguinte da mesma tecla e canal.
  O renderer (não o agendador) garante, por `(channel, pitch)`:
  `offPerformed(anterior) ≤ onPerformed(seguinte) − 1 ms`. Os 2 casos do
  Maple Leaf Rag já sobrepostos na fonte (ver notas do K04) continuam como
  estão.
- **Trocar `k`/expressividade durante o play**: recalcular
  `ExpressivePerformance` (síncrono, é rápido) e fazer como `setSpeed`:
  `allNotesOff`, reancorar na posição **musical** atual e voltar a encher a
  janela.

### Velocity: modelo de nível

As regras trabalham em **dB relativos** (como o DM). No fim:

```
sl_total = Σ regras (dB)  → normalizar média para 0 dB (opcional)
vel = clamp(round(v_ref · 10^(sl_total / 40)), 1, 127)
```

`v_ref` = velocity da nota (do `midi.json`, ou da dinâmica escrita quando
houver G03). O expoente `/40` supõe amplitude ∝ velocity² (curva comum
de GM); **calibrar com o rustysynth** em H03: medir o RMS de uma nota de piano
do `.sf2` em velocity 20…127, ajustar a curva dB→velocity e registrar aqui.

Tabela de dinâmicas escritas (G03 → H06), ponto de partida (velocity):
`ppp 20, pp 33, p 49, mp 64, mf 80, f 96, ff 112, fff 124`; hairpin =
interpolação linear da velocity entre a dinâmica de partida e a de chegada
(ou ±2 degraus se não houver chegada).

### Regras do subconjunto inicial

Faixas "k = 1" abaixo; o global "expressividade" multiplica todos os k.

| # | Regra | Dados | Saída | Especificação |
| --- | --- | --- | --- | --- |
| R1 | Acento métrico | beat (H01) | Δvel | tempo 1 do compasso +2 dB, tempos fortes secundários +1 dB, contratempos 0 (≈ scoremill +3 vel) |
| R2 | Voicing de melodia | melodia (H01) | Δvel, Δonset | nota de melodia +3 dB; outras notas do mesmo acorde da pauta −1 dB; melodia adiantada ≈ −15 ms ("melody lead") só se a pauta de baixo tem onset simultâneo |
| R3 | High Loud | pitch | Δvel | DM: `+(pitch − média_da_pauta)/4` dB |
| R4 | Duration Contrast | ms nominais | Δvel, Δdur | DM, fórmulas acima |
| R5 | Double Duration | durações | warp | DM, fórmula acima (fator nos intervalos, entra no warp) |
| R6 | Final Ritard | fim da peça | warp | DM, `q = 3`, `L = 1300·k` ms, `v_end = 1/(1+3k)` |
| R7 | Arco de frase | frases (H01) | warp + Δvel | versão A (scoremill, frase = P compassos) em H04; versão B (DM Phrase Arch com slurs/heurística) depois |
| R8 | Fermata | G03 | warp | duração × 1,55 (scoremill) a × 2 na nota com fermata; pequena cesura depois |
| R9 | Ruído 1/f | tatums (acordes) | warp (componente comum, deriva lenta) + Δonset (componente por mão) | Hennig: σ = 10 ms, α = 1; limitar |Δ| a 2σ |
| R10 | Espalhamento de acorde | acordes (`chords`) | Δonset | notas do mesmo acorde ±3-5 ms em torno do onset (grave primeiro) |
| R11 | Articulação escrita | G03 | Δdur | staccato: dur × 0,5 (mín. 60 ms); tenuto: × 1,0; normal: −5% entre notas diferentes (legato leve) |
| R12 | Dinâmica escrita | G03 | v_ref | tabela acima + hairpins |

**Frase sem marcas (H04, versão A):** frase = P compassos (P = 2 ou 4,
escolhido pela métrica: compassos curtos → 4), alinhada ao primeiro compasso
completo (tratar anacruse). Heurística para refinar sem G03: fronteira
preferida onde há pausa em todas as pautas ou nota da melodia com duração ≥
2× a mediana local (é o núcleo do que `Punctuation` faz).

### Interação com o treino (T01-T04)

- **Modo "ouvir"** (play normal): tudo ligado.
- **Modo espera (T02)** e **tempo real (T03)**: o timing expressivo
  atrapalha (o app toca a outra mão; o avaliador compara com o tempo
  escrito). Recomendação: nesses modos, **só as regras de velocity** (R1-R4,
  R12) e warp identidade. Se um dia o warp valer no treino, o avaliador do
  T03 tem de comparar contra `warp.toPerformed(onMs)`, não `onMs`.
- A decisão é do usuário (D-EXPR-MODOS).

## Passos

Cada passo segue o formato dos demais (Objetivo / O que fazer / Critérios /
Notas de execução). Quando o primeiro for executado, crie os arquivos
`H01-…md` etc. a partir das seções abaixo e adicione as linhas na tabela
de passos do README.

### H01 — `ScoreFacts`: fatos musicais por evento (Dart puro)

- `lib/music/expression/score_facts.dart`. Entrada: `VsbDocument` (timemap)
  + `PerformanceTrack`.
- Por `SoundEvent` (índice paralelo a `track.events`): `qOn`, `qOff`
  (semínimas, interpolando `tstamp→qstamp` linearmente nos pontos do
  timemap), índice do compasso, `beatInMeasure` (em semínimas),
  `measureLengthQ`, nível métrico (downbeat / tempo forte / tempo / fração),
  `isMelody` (maior pitch entre os onsets simultâneos da pauta 1, tolerância
  `chordToleranceMs`), `isLast`.
- Lista de compassos com `startMs`, `startQ`, `lengthQ` (de `measureOn`).
- Critérios: Gymnopédie: compasso 3/4 → `measureLengthQ == 3` em todos os
  compassos completos; `qOn` de um `-rend2` = `qOn` da passagem 1 + 117.
  Maple Leaf Rag 2/4: downbeats nos múltiplos de 2 q. Peça sem `midi.json`:
  fatos vazios, sem exceção.

### H02 — `TimeWarp` + ajustes no agendador (sem regras ainda)

- `lib/music/expression/time_warp.dart` (`identity`, `fromDurationFactors`,
  `toPerformed`, `toMusical`, busca binária) e
  `lib/music/expression/expressive_performance.dart` (warp + ajustes por
  evento; `ExpressivePerformance.neutral(track)`).
- `ScoreAudioScheduler` recebe um `ExpressivePerformance` opcional
  (padrão = neutro) e aplica como descrito em "Integração no agendador";
  método `setPerformance(...)` que reancora como `setSpeed`.
- Critérios: suíte do K04 inalterada e verde com o neutro;
  `toMusical(toPerformed(x)) == x` (±1e-6) em 1 000 pontos aleatórios com um
  warp não trivial; com warp que dobra o tempo de um trecho, o agendador
  agenda os eventos desse trecho com o dobro do espaçamento e
  `positionMs` volta exatamente ao `onMs` musical no instante em que a nota
  soa; teste de mesma tecla (off ≤ on seguinte) com Δonset aleatórios.

### H03 — Regras de velocity (R1-R4) + curva dB→velocity

- `lib/music/expression/rules/…`, uma classe por regra com `k`; soma em dB;
  conversão dB→velocity calibrada no rustysynth (registrar a curva medida
  aqui).
- Critérios: com k = 0 tudo igual ao neutro; Maple Leaf Rag: velocity média
  da melodia > média do acompanhamento; downbeats com velocity média maior
  que os contratempos; nenhum valor fora de 1-127. **(manual)** ouvir
  Gymnopédie com e sem, registrar impressão.

### H04 — Regras de tempo (R5, R6, R7 versão A, R8 se G03 existir)

- Fatores de duração por intervalo → `TimeWarp.fromDurationFactors`.
- Critérios: Final Ritard reproduz `v(x)` (comparar o tempo local
  executado com a fórmula, erro < 1%); duração total da peça aumenta só o
  esperado pelo ritard (± o arco, se não normalizado); arco em frase de 2
  compassos: tempo local no meio da frase > início > fim. **(manual)** ouvir.

### H05 — Ruído 1/f (R9) e espalhamento de acorde (R10)

- Gerador 1/f^α próprio (FFT via pacote `fftea`, ou soma de AR(1) — decidir
  pelo tamanho da dependência); semente por peça.
- Critérios: σ medido ≈ σ pedido (±10%); inclinação do espectro log-log ≈
  −α (±0,2) numa série de 4 096 amostras; mesma semente → mesma série;
  acordes: nenhuma nota a mais de 5 ms do onset original pela R10.

### G03 (bridge) — marcas expressivas no `midi.json`

- No fork: estender o gravador de eventos (`SetEventLog`, G01) ou um
  functor novo para emitir, com o mesmo relógio em ms do `midi.json`:
  `dynamics[] {id, ms, staff, value: "pp"|…}`, `hairpins[] {id, startMs,
  endMs, staff, form: "cres"|"dim"}`, por nota `artic: [...]`
  (`stacc`, `acc`, `ten`, `marc`), `slurs[] {id, startId, endId}` (ou
  `startMs/endMs` + staff), `fermatas[] {id, ms}`. Com repetição expandida,
  um registro por passagem (ids `-rend<N>`, como as notas).
- Atualizar spec `docs/formato/especificacao-v1.md` §2.7, schema, fixtures e
  `score_bridge` (`VsbMidi`) — mudança aditiva, `version` continua 1.
- Seguir o plano/convenções **do bridge** (prefixo G já é de lá).

### H06 — Dinâmicas, articulações, fermatas e frases escritas (R7 B, R8, R11, R12)

- Consome G03: `v_ref` por dinâmica/hairpin; articulação; fermata no warp;
  Phrase Arch do DM com frases = slurs longos (≥ 1 compasso) na melodia,
  dois níveis como na paleta padrão.
- Critérios: peça do corpus com p/f escritos → velocity média no trecho
  `f` > no trecho `p`; staccato encurta; fermata alonga o compasso.

### Depois (opcional)

- UI: slider "expressividade" (0 = máquina, 1 = padrão, 1,5 = exagerado) no
  painel de opções; opcional painel avançado com k por regra (pDM).
- Persistir preferências por peça.
- Punctuation completo, Melodic/Harmonic Charge (precisam de tonalidade).

## Decisões

| Id | Pergunta | Bloqueia | Recomendação | Status |
| --- | --- | --- | --- | --- |
| D-EXPR-MODOS | Em quais modos a expressão vale? | H02 (onde ligar), T02/T03 | Ouvir: tudo; treino: só velocity, warp identidade | **aberta** |
| D-EXPR-PADRAO | Vem ligada por padrão? Com que intensidade? | H03 | Ligada no modo ouvir, expressividade 1,0 | **aberta** |
| D-EXPR-G03 | Fazer G03 (fork) antes ou depois da 1.0? | H06 | Depois da 1.0; H01-H05 não dependem dele | **aberta** |
| D-EXPR-FFT | Dependência para FFT (`fftea`) ou gerador sem FFT? | H05 | Sem FFT (soma de AR(1)) se a inclinação medida bater; senão `fftea` | **aberta** |

## Riscos

1. **Dessincronização som × destaque** se algum efeito de tempo global for
   aplicado como Δonset em vez de entrar no `TimeWarp`. Regra: acima de
   ±50 ms, ou afetando todas as vozes, vai para o warp.
2. **Notas presas / cortadas** com offsets: o invariante por `(canal,
   pitch)` é do renderer e tem teste próprio (H02).
3. **Exagero**: regras somadas podem soar caricatas. Mitigação:
   expressividade global e normalização de nível/duração; ouvir sempre com
   as duas peças do corpus.
4. **Licença**: nada do humanizer (CC BY-NC-SA) entra no repo, nem traduzido
   linha a linha; só o algoritmo descrito aqui. DM (Artistic) e scoremill
   (MIT) podem ser citados; anote a origem da fórmula no comentário do
   código.
5. **Canal fixo 0 no motor** (`engine.rs` L118, K04): não bloqueia H, mas
   peças multicanal soam erradas até ser corrigido.

## Fontes

- Director Musices: <https://github.com/docfry/Director-Musices> (regras em
  `dm-source/rules/`, paletas em `rulepalettes/`); visão geral: Bresin,
  Friberg & Sundberg, "Director Musices: The KTH Performance Rules System"
  (<https://www.diva-portal.org/smash/get/diva2:1246181/FULLTEXT01.pdf>);
  Friberg, Bresin & Sundberg, "Overview of the KTH rule system for musical
  performance", *Advances in Cognitive Psychology* 2(2-3), 2006; Friberg &
  Sundberg, "Does music performance allude to locomotion? A model of final
  ritardandi derived from measurements of stopping runners", *JASA* 105(3),
  1999.
- Humanizer: <https://github.com/holgerhennig/humanizer>; H. Hennig, PNAS
  111:12974 (2014); Hennig et al., PLoS ONE 6:e26457 (2011); Hennig,
  Fleischmann & Geisel, *Physics Today* 65:64 (2012).
- scoremill: <https://github.com/CharlesCNorton/scoremill> (`scoremill.py`).
- pDM / clj-dm: <http://odyssomay.github.io/clj-dm/>,
  <https://www.speech.kth.se/music/performance/download/>.
