# Y01 — Nota fantasma no treino (lado zywny de G03–G05)

**Repo:** zywny (`score_bridge/` + `lib/`) · **Depende de:** N03, T02 e G04d/G05
(bridge) · **Decisão necessária:** não · **Status: concluído** (2026-09-29;
verificação visual no app pendente)

Contrato: `docs/nota-para-zywny-fantasma.md` e a §10 de
`docs/formato/especificacao-v1.md`, **no bridge**
(`/home/mauricio/rust_projects/verovio_flutter_bridge`). Decisões D-FANT-* em
`docs/plano/G03-visao-geral-nota-fantasma.md` de lá.

## O que foi feito

1. `just native` com o `main` do bridge que já traz G04 (`pitchpos.json`,
   geometria de pauta, `restsOn`/`restsOff`).
2. `score_bridge` — modelo/parser: `VsbDocument.pitchPos` (`VsbPitchPos`,
   `PitchEvent`), `SceneNode.staffGeometry` (`StaffGeometry`) e
   `SceneNode.staffRef`, `VsbManifestFiles.pitchpos`.
3. `score_bridge/lib/src/ghost.dart` — `VsbDocument.ghostsFor(expectedIds,
   wrongKeys, page)`: porta da §10 (8 passos). Aceita ids expandidos.
4. `score_bridge/lib/src/ghost_layer.dart` — `GhostController` (ciclo de
   vida: fade 150 ms, mínimo 250 ms na tela, parâmetros do host) e
   `GhostPainter` (overlay por cima da página, glifos pelo `GlyphCache`).
   `ScoreView`/`ScorePageView` ganharam o parâmetro `ghosts`.
5. `PracticeController(ghosts:)` — tecla errada → `press`; note-off →
   `release`; passo novo → `setExpected` (todas as notas do acorde); `stop` →
   `clear`. `lib/main.dart` cria o `GhostController` e o liga ao `ScoreView`.
6. Fixtures: `score_bridge/test/fixtures/fantasma/` (os 9 `.vsb` e o
   `vetores.json` do bridge) e `test/fixtures/satie-fantasma.vsb`.

## Testes

- `score_bridge/test/ghost_test.dart`: os **26 vetores** (resumo exato,
  números a ±0,5).
- `score_bridge/test/ghost_layer_test.dart`: ciclo de vida com relógio
  simulado.
- `test/practice_controller_test.dart`: tecla errada vira fantasma na coluna
  do passo; certa não.
- `test/vsb_render_test.dart`: MEI → FFI → `.vsb` → `pitchPos` → fantasma.

## Pendente / decisões abertas

- **Ver no app** (`just run`, teclado MIDI): cor, fade e posição do marcador
  de oitava são convenção visual.
- Modo espera não tem pausa como passo; fantasma durante pausa (D-FANT-PAUSA,
  `restsOn`) entra com T03 (tempo real).
- O destaque vermelho da nota esperada (T02) continua ligado junto com a
  fantasma; decidir se some.
