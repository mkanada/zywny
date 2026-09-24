# N02 — `score_bridge`: modelo e parser de `notes.json`

**Repo:** verovio_flutter_bridge (`score_bridge/`) · **Depende de:** N01 ·
**Decisão necessária:** não

## Objetivo

`VsbDocument.notes`: mapa `id (expandido) → NoteInfo`, lido de
`notes.json` quando o pacote o traz. Fixtures regeneradas. O zywny passa a
recebê-lo (a `libverovio.so` refeita).

## Ler antes (só isto)

- `docs/formato/especificacao-v1.md` §2.7 (escrita em N01).
- `score_bridge/lib/src/parser.dart` L50-L130 (como `meta`/`timemap`/
  `alternates` são lidos do zip e do JSON único).
- `score_bridge/lib/src/model.dart`: `VsbDocument` (L167-L215), `VsbMeta` e
  `VsbManifest` (procure `class VsbManifest`, `files`).
- `score_bridge/lib/score_bridge.dart` (exports).

## Contexto que você precisa

- Padrão existente: `manifest.files.<x>` opcional → se presente, ler a entrada
  do zip, `json.decode`, `parseXDocument(decoded, path: 'x')` com erros de
  formato apontando o caminho JSON. Copie o de `meta`.
- `alternates` é **preguiçoso** (`late final` + loader) porque custava 4,6× o
  parse. `notes` é pequeno (uma linha por nota: ~10 mil no corpus inteiro) —
  leia direto, mas **meça** o tempo de parse com
  `score_bridge/tool/measure_parse_time.dart` (roda com `flutter test`, não
  `dart run`) antes e depois e registre.
- Modelo sugerido (imutável, como o resto do `model.dart`):

  ```dart
  enum TieRole { none, start, continuation }   // start opcional: ver N01
  class NoteInfo {
    final String id;          // id expandido, igual ao timemap
    final int pitch;          // MIDI 0-127, já com 8va/transposição
    final int staff;          // n da pauta (1 = de cima; piano: 1 = MD, 2 = ME)
    final int layer;
    final int channel;        // 0-15
    final int program;        // 0-127 (GM)
    final int velocity;       // 1-127
    final TieRole tie;
    final String? tieHead;    // id da 1ª nota da cadeia, se continuation
    final bool ornament;      // trinado/tremolo expandido no MIDI
  }
  // VsbDocument:
  final Map<String, NoteInfo> notes;   // vazio quando não há notes.json
  ```
- Fixtures em `score_bridge/test/fixtures/` (`erik-satie.vsb`,
  `maple-leaf-rag.vsb`, `mazurka.vsb` e as de `repeticoes/`): regenere com o
  CLI de N01 usando **as mesmas flags** com que foram geradas (procure nas
  notas de P01c/P04c/P05 do plano do bridge, ex.: `-x 42` = `--xml-id-seed
  42`). Confira com `git diff --stat` que só mudou o que devia.
- No zywny: `just native` refaz a `libverovio.so`; `pubspec` usa `path:`,
  então nada a publicar.

## O que fazer

1. `NoteInfo`, `TieRole`, `VsbDocument.notes`, parser (zip e JSON único),
   exports.
2. Regenerar fixtures.
3. Testes: parse de fixture; nota ligada; id `-rend2`; pacote sem
   `notes.json` → mapa vazio sem erro; `notes.json` malformado → erro com
   caminho.
4. No zywny: `just native`, rodar o app, conferir (em modo `--debug`,
   `print` temporário ou teste) que `document.notes` vem cheio.

## Fora de escopo

- Juntar com o timemap em eventos tocáveis (N03).

## Critérios de aceite

1. `cd score_bridge && flutter test` verde, com os testes novos.
2. Para cada fixture com timemap: todo id de nota em `timemap[].on` tem
   `NoteInfo` (mesma regra de exceções de N01).
3. Tempo de parse antes/depois registrado (mesma peça, mesma máquina).
4. zywny: `just analyze`, `just test` limpos; app abre e toca como antes.

## Notas de execução

(preencher)
