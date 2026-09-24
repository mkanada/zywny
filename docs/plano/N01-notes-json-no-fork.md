# N01 — Fork: `notes.json` no `.vsb` (pitch, pauta, canal, ligadura)

**Repo:** verovio_flutter_bridge (C++ + spec) · **Depende de:** — ·
**Decisão necessária:** não

## Objetivo

O timemap diz **quando** cada id liga e desliga, mas não **qual nota** é.
Acrescentar ao `.vsb` um arquivo opcional `notes.json` com, por id de nota
(expandido, `-rend<N>`, os mesmos do timemap): altura MIDI, pauta, camada,
canal, programa, velocity e papel na ligadura. É a base de tocar (K04), de
mandar MIDI (M03) e de avaliar o aluno (T01).

## Ler antes (só isto)

- No bridge: `CLAUDE.md` (convenções) e `docs/formato/especificacao-v1.md`
  §2 a §2.6 (L25-L318) e §9 (compatibilidade).
- `verovio/src/toolkit.cpp` `Toolkit::RenderToBridgeFile` (~L2364-L2450) e
  `RenderToBridgeJson` (mesmo padrão, JSON único).
- `verovio/src/doc.cpp` `Doc::ExportMIDI` (~L450-L620).
- `verovio/src/midifunctor.cpp` `GenerateMIDIFunctor::VisitNote` (L807-L905)
  e `GetMIDIPitch` (L1149); `verovio/include/vrv/midifunctor.h`
  `GenerateMIDIFunctor` (~L349-L480).
- `verovio/include/vrv/bridgewriter.h` / `src/bridgewriter.cpp`
  `WriteManifest` (L622) e `WriteMeta` (modelo de um writer pequeno).

## Contexto que você precisa

- **Por que não `getMIDIValuesForElement`**: ele usa `note->GetMIDIPitch()`
  sem argumentos, ignorando `transSemi` (instrumento transpositor) e 8va/8vb
  (`HandleOctave` → `m_octaveShift`). O `GenerateMIDIFunctor` aplica os dois
  (`GetMIDIPitch(note)` = `note->GetMIDIPitch(m_transSemi, m_octaveShift)`,
  ou afinação customizada). O corpus tem 8va (classe `octave` no Chopin
  Étude e no Clair de Lune) — use-os no teste.
- **Estratégia recomendada** (mínima, sem duplicar lógica): um "gravador"
  opcional no `GenerateMIDIFunctor`:
  - `struct MIDINoteRecord { std::string id; int pitch; int staff; int layer;
    int channel; int program; int velocity; bool tieContinuation; bool
    expanded; }` (em `midifunctor.h`).
  - `void SetNoteLog(std::vector<MIDINoteRecord> *log)`; `nullptr` por padrão
    → zero mudança de comportamento no MIDI.
  - Em `VisitNote`, gravar **antes** dos `return` de ligadura secundária
    (`GetScoreTimeTiedDuration() < 0` → `tieContinuation = true`, grava e
    retorna como hoje). Notas `HasSameasLink` e cue puladas não entram.
    `velocity == 0` (silenciosa) não entra. Nota de trinado/tremolo
    (`m_expandedNotes`) entra uma vez com o pitch principal e
    `expanded = true`.
  - `staff = m_staffN`, `layer = m_layerN`, `channel = m_midiChannel`,
    `program` = `m_instrDef && m_instrDef->HasMidiInstrnum() ?
    GetMidiInstrnum() : 0`.
  - `Doc::ExportMIDI(smf::MidiFile *, std::vector<MIDINoteRecord> *noteLog =
    nullptr)` repassa o ponteiro para cada `GenerateMIDIFunctor` que ele cria
    no laço por pauta/camada.
  - `Toolkit::RenderToBridgeFile`/`RenderToBridgeJson`: `SetMidiDoc()`, rodar
    `m_midiDoc->ExportMIDI(&scratchMidi, &log)` num `smf::MidiFile` descartado
    e serializar `log`.
- **Ids**: o `m_midiDoc` é o documento expandido; seus ids são exatamente os
  do timemap (inclusive `-rend<N>`). Critério 2 prova isso.
- **Ligadura**: o timemap traz **toda** nota, inclusive a secundária, com
  on/off próprios. Com `tieContinuation`, o Dart (N03) junta a cadeia: soa do
  `on` da primeira até o `off` da última; o aluno aperta só a primeira.
  Para achar a cabeça da cadeia, grave também `tieHead`: o id da primeira nota
  (percorra `Tie::GetStart/GetEnd` — ver `InitTimemapTiesFunctor::VisitTie`
  L313 — ou, mais simples, mantenha no functor um mapa `pitch+staff →
  id da última nota com ligadura aberta`; escolha e documente).
- **Formato proposto** (mesma regra de omissão do timemap: sem notas, sem
  arquivo nem entrada no manifest; aditivo, `version` continua `1`):

  ```json
  { "notes": [
      {"id":"n1a2b","p":64,"s":1,"l":1,"c":0,"pg":0,"v":90},
      {"id":"n9f-rend2","p":52,"s":2,"l":1,"c":0,"pg":0,"v":90,"tie":"cont","th":"n77-rend2"},
      {"id":"n33","p":71,"s":1,"l":1,"c":0,"pg":0,"v":90,"orn":true}
  ]}
  ```
  Chaves curtas porque o corpus tem ~10 mil notas; campos com valor padrão
  podem ser omitidos se a spec disser (decida e documente na spec). Ordem:
  por id do timemap não é necessária — o Dart indexa por id.
- `manifest.files.notes = "notes.json"`; no JSON único, propriedade `notes`.
  `WriteManifest` ganha `bool hasNotes` (atualize as duas chamadas).
- Atualize `docs/formato/especificacao-v1.md` (nova §2.7, tabela do manifest,
  histórico de revisões com data) e `docs/formato/schema-v1.json`
  (`$defs/notesDocument`).
- Saídas de teste em `compare/out/n01/`.

## O que fazer

1. Gravador no `GenerateMIDIFunctor` + parâmetro em `Doc::ExportMIDI`.
2. `BridgeWriter::WriteNotes` + manifest + zip + JSON único.
3. Spec e schema.
4. Script de verificação (Python 3 da máquina, sem dependências — leia o
   `.mid` com um parser mínimo ou use `verovio -t midi` + `mido` se estiver
   instalado; registre qual).

## Fora de escopo

- Qualquer código Dart (N02). Velocity de dinâmicas (`p`, `f`) — o Verovio
  não converte; fica `MIDI_VELOCITY` salvo `@vel` explícito.
- Pedal, CCs, andamento (o andamento já está no `tstamp`).

## Critérios de aceite

1. `verovio -t vsb` nas 10 peças do corpus gera `notes.json`; `-t svg` e os
   `scene.json`/`glyphs.json`/`timemap.json` ficam **byte-idênticos** aos de
   antes (compare com uma geração feita antes da mudança).
2. Para cada peça: todo id em `timemap[].on` que é nota tem entrada em
   `notes.json` (exceto notas silenciosas/cue, contadas e listadas); nenhum
   id em `notes.json` fora do timemap.
3. **Pitch = MIDI**: o multiconjunto `(onset arredondado, pitch)` das notas
   **sem** `tie:"cont"` e sem `orn` bate com os note-on do `verovio -t midi`
   da mesma peça (onset em ms do timemap vs. tick convertido pelo andamento —
   ou compare só a sequência ordenada de pitches por pauta). Divergência zero
   no Chopin Étude e no Clair de Lune (8va).
4. Gymnopédie e Maple Leaf Rag: ids `-rend2` presentes com o mesmo pitch da
   passagem 1.
5. `score_bridge` continua lendo os pacotes novos (`flutter test` verde —
   leitor antigo ignora o arquivo extra).
6. Spec/schema atualizados; um `notes.json` do corpus valida contra o schema.

## Notas de execução

(preencher)
