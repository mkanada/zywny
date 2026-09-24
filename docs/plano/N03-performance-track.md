# N03 — `PerformanceTrack`: eventos tocáveis por id, com ligaduras e mãos

**Repo:** zywny · **Depende de:** N02 · **Decisão necessária:** não

## Objetivo

Uma estrutura Dart pura, construída uma vez por `.vsb`, que responde a tudo
que som, MIDI e treino precisam perguntar sobre "o que soa quando":

- lista ordenada de **eventos de som** `{id, pitch, onMs, offMs, staff,
  channel, program, velocity}` — um por **tecla apertada** (ligaduras já
  fundidas);
- consultas por janela de tempo e por pauta (mão);
- "acordes" (grupos de notas com o mesmo `onMs`) para o treino.

## Ler antes (só isto)

- `score_bridge/lib/src/model.dart`: `TimemapEntry` (L633) e o `NoteInfo` de
  N02.
- `score_bridge/lib/src/score_timeline.dart`: `entries`, `durationMs`,
  `measures` (só a assinatura; `graft skeleton` ou `grep -n`).
- Este README (seção Fatos, "Tempo").

## Contexto que você precisa

- `TimemapEntry.tstamp` em ms (andamento original), `on`/`off` com ids de
  **nota** (pausas vêm em `restsOn/Off`, ignore). A mesma nota pode aparecer
  com ids `-rend1`, `-rend2`… nas passagens de uma repetição: cada id é uma
  execução diferente, com seu próprio tempo — trate como notas distintas.
- Ligadura (N01/N02): a nota com `tie == continuation` **não** gera evento
  próprio; ela estende o `offMs` da cabeça (`tieHead`) até o seu próprio off.
  Cadeias de 3+ notas existem. Se o `tieHead` não estiver nos eventos (dado
  estranho), trate a nota como evento normal e conte o caso.
- Nota com `on` sem `off` correspondente (não deve acontecer): feche no
  `durationMs` e registre em contador de anomalias.
- Mesma tecla religada antes do off anterior (vozes diferentes, uníssono):
  mantenha os dois eventos; quem agenda (K04) manda note-off antes do novo
  note-on da mesma tecla/canal.
- Acorde para o treino: eventos da mesma pauta com `onMs` a ≤ 30 ms um do
  outro (arpejos escritos não são acorde; `arpeg` do Verovio já aparece como
  onsets escalonados no timemap).
- Piano: pauta 1 = mão direita, pauta 2 = mão esquerda. Partituras com mais
  pautas (canto + piano) existem: exponha as pautas presentes e seus rótulos
  numéricos; o nome da mão é UI (T02).
- Local sugerido: `lib/music/performance_track.dart` (pasta nova
  `lib/music/`). Sem Flutter além de `foundation` — testável com
  `flutter test` puro.

## O que fazer

```dart
class SoundEvent { String id; int pitch; double onMs; double offMs; int staff;
                   int channel; int program; int velocity; bool ornament; }
class Chord { double onMs; int staff; List<SoundEvent> notes; }

class PerformanceTrack {
  factory PerformanceTrack.fromDocument(VsbDocument doc);
  List<SoundEvent> get events;          // ordenado por onMs, depois pitch
  double get durationMs;
  Set<int> get staves;
  Iterable<SoundEvent> startingIn(double fromMs, double toMs, {Set<int>? staves});
  Iterable<SoundEvent> soundingAt(double ms, {Set<int>? staves});
  List<Chord> chords({required Set<int> staves});
  Map<String, int> get anomalies;       // contadores para diagnóstico
}
```

`startingIn` é `[fromMs, toMs)` e usa busca binária (o agendador chama a cada
~25 ms).

## Fora de escopo

- Agendamento e som (K04). Casamento de notas do aluno (T01).

## Critérios de aceite

1. Testes unitários com `.vsb` do corpus (copie 2-3 fixtures do bridge para
   `test/fixtures/` do zywny, ou gere com o CLI): contagem de eventos =
   nº de notas não-continuação; soma de durações coerente.
2. Teste de ligadura: uma nota ligada atravessando a barra gera **um** evento
   com `offMs` = off da última da cadeia (crie um MEI mínimo em
   `test/fixtures/` se o corpus não tiver um caso claro; o Gymnopédie tem
   ligaduras na mão esquerda).
3. Teste de repetição: Gymnopédie tem eventos `-rend2` com os mesmos pitches
   da passagem 1, deslocados no tempo.
4. `startingIn` bate com um filtro linear em 1 000 janelas aleatórias.
5. `anomalies` vazio nas peças do corpus (ou cada caso explicado nas notas).
6. `just analyze` e `just test` limpos.

## Notas de execução

(preencher)
