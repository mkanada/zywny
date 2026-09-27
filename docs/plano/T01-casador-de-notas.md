# T01 — `PracticeSession`: acordes esperados e casador (Dart puro)

**Repo:** zywny · **Depende de:** N03 · **Decisão necessária:** não
(as tolerâncias numéricas de D-TREINO entram como parâmetros, com os valores
recomendados de padrão)

## Objetivo

O núcleo do treino, **sem UI e sem hardware**: dada a trilha (N03), as mãos
que o aluno vai tocar e uma sequência de notas tocadas com tempo musical,
dizer o que foi certo, errado, adiantado, atrasado ou perdido — nos dois
modos: **espera** (o tempo não anda até o acorde certo) e **tempo real**.

## Ler antes (só isto)

- `lib/music/performance_track.dart` (N03): `SoundEvent`, `Chord`,
  `chords(staves:)`.
- `lib/midi/midi_input_service.dart` (M01) — só o tipo `PlayedNote` (se M01
  ainda não existe, defina aqui um tipo equivalente e M01 adapta).

## Contexto que você precisa

- **Unidade de trabalho = acorde** (`Chord`: notas da mesma pauta com o
  mesmo onset, N03). Se o aluno toca as duas mãos, junte os acordes das duas
  pautas com o mesmo `onMs` num "passo" único.
- **Modo espera** (o mais importante para aprender):
  - Estado: índice do passo atual, conjunto de teclas do passo ainda não
    tocadas.
  - Nota tocada que pertence ao passo → marca certa. Nota fora → "errada"
    (não avança). Quando todas foram tocadas (em qualquer ordem, dentro de
    uma janela de 300 ms entre a primeira e a última — acordes não precisam
    ser simultâneos perfeitos), o passo é concluído → avança.
  - Tecla ainda segurada do passo anterior que também é do próximo (nota
    repetida): exige **soltar e apertar de novo** (note-off antes). Nota
    ligada (N01/N03) não aparece como passo novo — nada a fazer.
  - Saída: `ValueListenable<PracticeStep>` (passo atual, notas faltando) e
    stream de `NoteVerdict {eventId?, pitch, kind: correct|wrong|early|late|missed, deltaMs}`.
- **Modo tempo real**:
  - Converter o tempo da nota tocada para ms musicais usando a âncora do
    agendador (K04): `musical = musicalT0 + (tocadaSeg - latênciaEntrada -
    deviceT0) * 1000 * speed`. O casador recebe já em ms musicais (a
    conversão é da camada de cima) — mantenha-o puro.
  - Para cada nota tocada: candidata = evento esperado de mesmo pitch, ainda
    não casado, com `|onMs - tocadaMs|` mínimo dentro de `janelaMax`.
    As janelas são definidas em ms **de parede** (padrão `janelaOk` 75 ms,
    `janelaMax` 150 ms) e convertidas para ms musicais multiplicando por
    `speed` (a 0,5× a música anda devagar, e 75 ms de parede = 37,5 ms
    musicais). `|delta| ≤ janelaOk` → `correct`; ≤ `janelaMax` →
    `early`/`late`; sem candidata → `wrong`.
  - Evento esperado cujo `onMs + janelaMax` passou sem casar → `missed`
    (disparado por `tick(musicalNowMs)`).
  - Ornamentos (`ornament == true`) e apojaturas: não cobrados na 1.0
    (D-TREINO) — nem `missed`, nem `wrong` se o pitch for de um ornamento
    próximo; documente a regra exata.
- Pedal e velocity: não avaliados na 1.0 (guarde velocity no veredito para o
  futuro).
- Sessão com **mãos**: `staves` do aluno; o que não é do aluno é tocado pelo
  app (T02) e **não** entra na avaliação.
- Loop (T04) reinicia a sessão num trecho: exponha `resetTo(musicalMs)`.

## O que fazer

`lib/practice/practice_session.dart` (`WaitModeSession`,
`RealtimeSession`, tipos de veredito e de passo) + testes extensos em
`test/practice/`.

## Fora de escopo

- UI, cores na partitura, relógio (T02/T03). Pontuação agregada (T03).

## Critérios de aceite

1. Espera: acorde de 3 notas tocado em qualquer ordem dentro de 300 ms
   avança; com uma errada no meio, avança igual e registra 1 `wrong`.
2. Espera: nota repetida exige soltar/apertar (teste com a mesma tecla
   segurada → não avança).
3. Tempo real: tocar a Gymnopédie (pauta 1) "perfeita" a partir do próprio
   track (gere as notas tocadas dos eventos, com ruído gaussiano σ=20 ms)
   → ≥ 99% `correct`, 0 `wrong`.
4. Tempo real: pular um compasso inteiro → exatamente os eventos desse
   compasso como `missed`.
5. Tempo real a `speed` 0.5: mesmas janelas de parede (teste com deltas
   escolhidos na fronteira).
6. `just analyze` e `just test` limpos.

## Notas de execução

- `lib/practice/practice_session.dart`: `NoteVerdict`/`PracticeVerdictKind`
  (tipos comuns), `PracticeStep` (passo do modo espera, com `remaining`
  republicado a cada nota certa — a UI destaca só o que falta sem trocar de
  passo), `WaitModeSession` e `RealtimeSession`.
- **`WaitModeSession`**: `forStaves(track, staves:)` funde os `Chord` de N03
  (`PerformanceTrack.chords`) por pauta, agrupando os que caem no mesmo
  `onMs` num só passo, e descarta notas de ornamento (`SoundEvent.ornament`)
  — não entram nos passos, o aluno não precisa tocá-las (D-TREINO). Nota
  repetida entre passos consecutivos: `_blocked` é `held ∩ remaining`
  calculado ao entrar no passo novo; enquanto a tecla não passar por
  `noteOff`, um novo `noteOn` do mesmo pitch é ignorado (nem conta, nem gera
  veredito) — é o "soltar e apertar de novo" do enunciado.
- **Janela de 300 ms do modo espera não é prazo**: modo espera não tem
  `missed` (o enunciado só define isso para tempo real) — a janela só
  aparece no `deltaMs` do veredito (tempo desde a primeira nota certa do
  acorde). Documentando aqui porque diverge de uma leitura possível do
  enunciado como "acorde expira depois de 300 ms".
- **`RealtimeSession`**: candidato = evento pendente de mesmo pitch com
  `|delta| ≤ janelaMax` (musical, `janela de parede × speed`) mais próximo;
  `≤ janelaOk` → `correct`, senão `early`/`late`. Ornamento: **entra como
  candidato** (para uma nota tocada perto dele não virar `wrong`), mas se
  casar é consumido **sem emitir veredito** (nem `correct` nem `wrong`); e
  em `tick`, ornamento cuja janela expirou é descartado **sem** `missed`.
  Regra exata, por não haver ambiguidade depois: ornamento nunca aparece
  numa `NoteVerdict`, nem como `eventId` nem implicitamente.
- Ambos os streams de veredito são `broadcast(sync: true)` — a emissão é
  uma decisão pura e imediata de `noteOn`/`tick`/`noteOff`, sem I/O; síncrono
  evita que todo teste precise de `pumpEventQueue`/`await` só para ler o
  veredito que acabou de ser gerado.
- Testes: `test/practice_session_wait_test.dart` (passos sintéticos para os
  critérios 1-2, mais `forStaves` sobre `maple-leaf-rag.vsb` real) e
  `test/practice_session_realtime_test.dart` (critérios 3-5 sobre
  `erik-satie.vsb`/pauta 1 real — ruído gaussiano Box-Muller σ=20 ms para o
  critério 3, um miolo de eventos nunca tocado para o 4, deltas exatos na
  fronteira das janelas a `speed` 0.5 para o 5 — mais casos sintéticos de
  wrong/missed/ornamento/`resetTo`).
- Critérios 1-5 são todos automatizados (T01 é Dart puro, sem hardware) —
  `just analyze`/`just test` limpos (58 testes) fecha o critério 6 e, com
  eles, o passo inteiro. Nenhum critério manual pendente aqui.
