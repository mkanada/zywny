# N01 — Fork: eventos MIDI no `.vsb` (pitch, tempo, ligadura, pedal)

**Repo:** verovio_flutter_bridge (C++ + spec) · **Depende de:** — ·
**Decisão necessária:** não · **Status: concluído** (via G01, 2026-09-25)

## Este passo mudou de repositório

Todo o trabalho de N01 é código do fork (C++) e da especificação do
formato — nenhuma linha é do zywny. Foi detalhado e executado **lá**, como
**G01**:

- `docs/plano/G01-gravador-de-notas-midi.md` no repo
  `verovio_flutter_bridge` (`/home/mauricio/rust_projects/verovio_flutter_bridge`).

A letra **G** é nova no plano do bridge (as fases de lá são F/S/R/A/E/P) e
foi escolhida por não colidir com nenhum prefixo usado nos dois planos.

## O que mudou em relação ao plano original (importante para N03)

**G01 não gravou o `notes.json` original** (atributos por nota, tempo só no
timemap). Durante a execução, o usuário decidiu por um formato mais rico —
`midi.json` — que grava o **fluxo de eventos que o exportador MIDI do
Verovio emite**, já com:

- tempo em **ms** por evento (`on`/`off`/`t`), no mesmo relógio do timemap;
- **ligaduras já fundidas**: a nota principal carrega `tied: [...]` com os
  ids de continuação; o host não precisa mais juntar cadeia nenhuma;
- **ornamentos já expandidos**: trinado/tremolo viram várias entradas com o
  mesmo `id` e `orn: true` — o host não expande nada;
- **pedal** incluído (`pedal[]`, sustain down/up).

Isso **simplifica N03** (`PerformanceTrack`): a fusão de ligadura e a
expansão de ornamento, que N03 previa fazer em Dart, já vêm prontas do
bridge. Reveja N03 antes de implementá-lo — o arquivo daquele passo ainda
descreve o design antigo (notes.json + timemap) e precisa ser atualizado
para `VsbMidi`/`MidiNote` (G02).

Também foi encontrado e corrigido no fork um bug real de dois relógios
divergentes (D-RELOGIO, Chopin Étude: `scoreDef/@midi.bpm` conflitando com
um `<tempo>` no compasso 1) — ver as notas de execução de G01 se precisar
do detalhe.

## O que fica aqui

Nada além deste ponteiro: N01 não tem "O que fazer" nem "Critérios de
aceite" próprios do zywny.

## Notas de execução

G01 concluído em 2026-09-25 no bridge (ver notas de execução de lá para os
números completos). Nenhum ajuste específico do zywny foi necessário além
de atualizar a terminologia em N02/N03 (`notes.json` → `midi.json`,
`NoteInfo` → `MidiNote`/`VsbMidi`).
