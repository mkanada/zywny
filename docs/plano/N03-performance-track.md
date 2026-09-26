# N03 — `PerformanceTrack`: eventos tocáveis por id, com ligaduras e mãos

**Repo:** zywny · **Depende de:** N02 · **Decisão necessária:** não

## Revisão de 2026-09-25 (antes de executar)

G01/G02 (no bridge) mudaram de design a meio caminho: em vez de um
`notes.json` com atributos por nota (deixando o host juntar ligadura e
timemap), o bridge agora grava `midi.json` com o **fluxo de eventos que o
exportador MIDI emite** — `VsbDocument.midi` (`VsbMidi?`): `notes`
(`List<MidiNote>`, uma por tecla apertada, **ligaduras já fundidas** em
`tied`, **ornamentos já expandidos** com `ornament: true`) e `pedal`
(`List<MidiPedal>`), tudo já em **ms** no relógio do timemap.

Isso elimina a parte mais delicada do design original deste passo: N03
**não precisa mais** juntar `TimemapEntry` com atributos de nota, nem
resolver cadeia de ligadura (`tieHead`/`continuation`), nem expandir
ornamento — G02 já entrega um evento por tecla, pronto. `PerformanceTrack`
vira principalmente uma camada de **consulta** (janela de tempo, pauta,
acordes) sobre uma lista que já vem correta, mais a exposição do pedal.

## Objetivo

Uma estrutura Dart pura, construída uma vez por `.vsb`, que responde a tudo
que som, MIDI e treino precisam perguntar sobre "o que soa quando":

- lista ordenada de **eventos de som** `{id, pitch, onMs, offMs, staff,
  channel, program, velocity, ornament}` — um por **tecla apertada**
  (já vem assim de `VsbMidi.notes`);
- eventos de **pedal** (`VsbMidi.pedal`, já ordenado por tempo);
- consultas por janela de tempo e por pauta (mão);
- "acordes" (grupos de notas com o mesmo `onMs`) para o treino.

## Ler antes (só isto)

- `score_bridge/lib/src/model.dart` (no bridge): `MidiNote`, `MidiPedal`,
  `PedalDir`, `VsbMidi` (`notesOf`), `VsbDocument.midi` — procure as
  classes, são pequenas (G02, `docs/plano/G02-notas-no-score-bridge.md` de
  lá tem o modelo completo).
- Este README (seção Fatos, "Tempo").

## Contexto que você precisa

- `MidiNote.onMs`/`offMs` já são o relógio final (ligadura fundida,
  ornamento expandido) — **não** precisa mais olhar `TimemapEntry` para
  montar eventos de som. O timemap continua sendo a fonte do **destaque
  visual** (`ScorePlayer`/`ScoreController`, já prontos), não do som.
- Repetição: a mesma nota aparece com ids `-rend1`, `-rend2`… nas
  passagens — cada id em `notes` já é uma execução distinta, com seu
  próprio `onMs`/`offMs`. Trate como eventos independentes (nada a fundir
  aqui, G02 já faz isso por passagem).
- Ornamento: uma nota de trinado/tremolo aparece como **várias** entradas em
  `notes` com o **mesmo** `id` e `ornament: true` (é assim que G02 documenta
  `VsbMidi.notesOf`). Para o treino (T01/T03), decidir se essas entradas
  contam como um evento tocável ou só como som de fundo é **decisão de
  T01**, fora deste passo — aqui só exponha o campo `ornament` para quem
  consumir decidir.
- Mesma tecla religada antes do off anterior (vozes diferentes, uníssono):
  mantenha os dois eventos; quem agenda (K04) manda note-off antes do novo
  note-on da mesma tecla/canal.
- Acorde para o treino: eventos da mesma pauta com `onMs` a ≤ 30 ms um do
  outro (arpejos escritos não são acorde; `arpeg` do Verovio já aparece como
  onsets escalonados).
- Piano: pauta 1 = mão direita, pauta 2 = mão esquerda. Partituras com mais
  pautas (canto + piano) existem: exponha as pautas presentes e seus rótulos
  numéricos; o nome da mão é UI (T02).
- Peça sem `midi.json` (`document.midi == null`, ex.: doc sem timemap
  usável): `PerformanceTrack` fica vazio (`events`/`pedal` vazios,
  `durationMs = 0`), não é erro.
- Local sugerido: `lib/music/performance_track.dart` (pasta nova
  `lib/music/`). Sem Flutter além de `foundation` — testável com
  `flutter test` puro.

## O que fazer

```dart
class SoundEvent { String id; int pitch; double onMs; double offMs; int staff;
                   int channel; int program; int velocity; bool ornament; }
class PedalEvent { String id; double timeMs; PedalDir dir; int staff; int channel; }
class Chord { double onMs; int staff; List<SoundEvent> notes; }

class PerformanceTrack {
  factory PerformanceTrack.fromDocument(VsbDocument doc);
  List<SoundEvent> get events;          // ordenado por onMs, depois pitch
  List<PedalEvent> get pedal;           // ordenado por timeMs
  double get durationMs;
  Set<int> get staves;
  Iterable<SoundEvent> startingIn(double fromMs, double toMs, {Set<int>? staves});
  Iterable<SoundEvent> soundingAt(double ms, {Set<int>? staves});
  List<Chord> chords({required Set<int> staves});
}
```

`startingIn` é `[fromMs, toMs)` e usa busca binária (o agendador chama a cada
~25 ms). `PerformanceTrack.fromDocument` é essencialmente um adaptador de
`VsbMidi` — mapeie `MidiNote`/`MidiPedal` para `SoundEvent`/`PedalEvent`
(mesmos campos, tipos já compatíveis) e construa os índices de consulta.

## Fora de escopo

- Agendamento e som (K04). Casamento de notas do aluno (T01). Decidir se
  entradas `ornament: true` exigem toque do aluno (T01/T03).
- Qualquer fusão de ligadura ou expansão de ornamento — já vêm prontas de
  G02.

## Critérios de aceite

1. Testes unitários com `.vsb` do corpus (copie 2-3 fixtures do bridge para
   `test/fixtures/` do zywny, ou gere com o CLI, ou reuse a integração de
   `test/vsb_render_test.dart`): contagem de `events` = contagem de
   `VsbMidi.notes` da mesma peça (mapeamento 1:1, sem perda nem duplicação).
2. Teste de repetição: Gymnopédie tem eventos `-rend2` com os mesmos pitches
   da passagem 1, deslocados no tempo (já vem assim de G02 — o teste aqui é
   que `PerformanceTrack` não perde nem funde esses ids).
3. `startingIn` bate com um filtro linear em 1 000 janelas aleatórias.
4. `chords` agrupa corretamente numa peça com acordes conhecidos do corpus.
5. Peça sem `midi.json`: `PerformanceTrack` vazio, sem lançar exceção.
6. `just analyze` e `just test` limpos.

## Notas de execução (2026-09-25)

- Implementado em `lib/music/performance_track.dart`: `SoundEvent`,
  `PedalEvent`, `Chord` e `PerformanceTrack` exatamente como na seção "O que
  fazer" (nenhum campo além dos listados; `layer` do `MidiNote` não é
  exposto em `SoundEvent`, conforme o contrato do passo). Sem Flutter além
  de `foundation` (`@immutable`).
- `startingIn` usa busca binária (`_lowerBound`) sobre `events` (ordenado
  por `onMs`); `soundingAt` é uma varredura linear com corte antecipado
  (`onMs > ms` interrompe) — não precisa de busca binária porque não é
  chamada em loop de agendamento como `startingIn` (ver "O que fazer").
- `chords`: agrupamento por pauta com âncora no primeiro evento do grupo
  (nota entra no acorde corrente se `onMs - âncora <= 30 ms`; senão abre
  novo acorde). Critério de aceite 4 verificado com acordes reais e
  conhecidos do corpus (Maple Leaf Rag, pauta 2: `onMs=0` → pitches
  {39, 51}; `onMs=600` → {51, 56, 60}), obtidos inspecionando
  `midi.json` diretamente.
- Fixtures: copiadas de `score_bridge/test/fixtures/` (bridge) para
  `test/fixtures/` do zywny — `erik-satie.vsb` (repetição), `maple-leaf-rag.vsb`
  (geral/acordes/busca binária), `r13-um-compasso.vsb` (peça mínima, 3 notas).
  Criada também `r13-sem-midi.vsb`: cópia de `r13-um-compasso.vsb` com
  `midi.json` removido do zip e a chave `files.midi` tirada de
  `manifest.json` (script Python ad hoc, não versionado), para exercitar o
  critério 5 (`document.midi == null`) sem precisar gerar um `.vsb` novo
  pelo CLI.
- Testes em `test/performance_track_test.dart`, carregando os `.vsb` direto
  com `VsbDocument.fromBytes` (sem passar pela FFI/render) — mais rápido e
  cobre só o que este passo precisa. Critérios 1, 2, 3, 4 e 5 têm um teste
  cada; critério 6 (`just analyze`/`just test`) rodado manualmente, limpo
  (23 testes no total, incluindo a suíte já existente).
- `just test` completo demora ~35 s por causa do teste de `startingIn`
  (1 000 janelas × filtro linear sobre 2 568 eventos do Maple Leaf Rag);
  aceitável para CI local, mas se crescer considerar reduzir para 200-300
  janelas.
- Nada a corrigir no README/passos futuros: os fatos de N02 sobre
  `VsbMidi`/`MidiNote`/`MidiPedal` bateram exatamente com o código do
  bridge.
