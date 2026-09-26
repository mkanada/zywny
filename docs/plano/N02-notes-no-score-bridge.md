# N02 — `score_bridge`: modelo e parser de eventos MIDI (`midi.json`)

**Repo:** verovio_flutter_bridge (`score_bridge/`) + zywny ·
**Depende de:** N01 · **Decisão necessária:** não · **Status: concluído**
(2026-09-25)

## Este passo mudou de repositório (em parte)

`score_bridge/` é um pacote **do bridge**, não do zywny (o zywny só o usa
por `path:` no `pubspec.yaml`). O modelo, o parser, as fixtures e os testes
de `midi.json` (antes chamado `notes.json` — ver N01) foram detalhados e
executados **lá**, como **G02**:

- `docs/plano/G02-notas-no-score-bridge.md` no repo
  `verovio_flutter_bridge` (`/home/mauricio/rust_projects/verovio_flutter_bridge`).

G02 expõe `VsbDocument.midi` (`VsbMidi?`): `notes` (`List<MidiNote>`, uma
por tecla apertada — ligaduras já fundidas em `tied`, ornamentos já
expandidos com `ornament: true` e o mesmo `id` repetido) e `pedal`
(`List<MidiPedal>`), com `onMs`/`offMs`/`timeMs` prontos no relógio do
timemap. `notesOf(id)` resolve tanto a cabeça quanto uma continuação de
ligadura para a(s) nota(s) correspondente(s).

## O que foi feito aqui (zywny)

1. `just native` — refeita a `libverovio.so` a partir do bridge com
   G01/G02 (18 MB, build OK).
2. `flutter pub get` (path dependency, sem mudança de versão a resolver).
3. `just analyze` — limpo.
4. `just test` — 15/15 verde.
5. `test/vsb_render_test.dart`: acrescentei `expect(document.midi, isNotNull)`
   e `expect(document.midi!.notes, isNotEmpty)` ao teste de integração
   ponta a ponta existente (MEI → FFI → `.vsb` → parser), em vez de um
   `print` descartável — prova que `document.midi` chega populado pelo
   caminho real (isolate + FFI), não só no bridge isoladamente.

Não rodei o app interativamente (sem display neste ambiente); a integração
ponta a ponta acima cobre o mesmo caminho de código que `_renderAndShow`
usa em `lib/main.dart`.

## Fora de escopo

- Modelo, parser, fixtures e testes de `midi.json` (G02, no bridge).
- Juntar eventos em `PerformanceTrack`/agendar som (N03 — **revise o design
  desse passo antes de implementar**: o `midi.json` novo já funde ligaduras
  e expande ornamentos, o que N03 previa fazer sozinho).

## Critérios de aceite

1. `just analyze`, `just test` limpos. ✅
2. App abre e toca como antes (sem regressão visual/funcional) — coberto
   indiretamente pelos testes existentes (`layout_options_test.dart`,
   `widget_test.dart`) continuarem verdes; não verificado interativamente.

## Notas de execução

Ver "O que foi feito aqui" acima. Nenhuma anomalia encontrada. Próximo
passo do plano: **N03**, mas com o design atualizado (ver nota em N01).
