# R07 — `OpenedPiece` obrigatório

**Repo:** zywny · **Depende de:** R05 · **Decisão necessária:** não

## Objetivo

A tela de partitura deixa de ser dona dos recursos compartilhados (achado
6 da revisão). `ScoreHomePage.opened` vira obrigatório; as configurações,
o store da trilha e o gerenciador MIDI vêm sempre de fora e quem os cria é
quem os descarta. Os testes que abriam a tela vazia passam a usar fakes.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 6.
- `lib/main.dart` L140–L165 (`ScoreHomePage`) e os trechos abaixo.

## Contexto que você precisa

- `OpenedPiece` está em `lib/app/library_screen.dart` depois do R05 (era
  `lib/library/library_screen.dart` L44). Campos obrigatórios: `piece`,
  `scoreXml`, `midiDeviceManager`, `onPracticeScore`, `appSettings`,
  `pieceSettings`, `onPieceSettingsChanged`, `trailProgress`.
- Em `main.dart` (linhas do commit `fac579c`), a posse dupla:
  - criação: `_settings` L212, `_trailStore` L312, `_midiDeviceManager`
    L381, todos `widget.opened?.x ?? X()`;
  - `if (widget.opened == null) unawaited(_settings.load())` L464;
  - descarte condicional em `dispose` L617, L622, L626;
  - ~25 usos de `widget.opened?.` e o caminho "sem partitura"
    (`_scoreXml == null`, L181/L654/L937).
- Quem constrói `ScoreHomePage` sem `opened`: `test/widget_test.dart` L24 e
  `test/settings_test.dart` L467, L508, L532. Com `opened`:
  `test/settings_test.dart` L362 e `test/transpor_tela_test.dart` L375.
  O app (`main.dart` L132) sempre passa.
- `test/settings_test.dart` L60 já tem um `_RecordingRenderer` que devolve
  `test/fixtures/erik-satie.vsb` sem tocar o Verovio — o fake a reusar.

## O que fazer

1. `test/support/score_page_fakes.dart`: `RecordingRenderer` (o de
   `settings_test`, movido) e `fakeOpenedPiece({…})`, que monta um
   `OpenedPiece` com `AppSettings`, `TrailProgressStore` e
   `MidiDeviceManager` novos e devolve também quem os descarta
   (`addTearDown` no teste).
2. `ScoreHomePage({required this.opened, …})`; tirar os `?.`/`??` e os
   descartes condicionais. `_settings.load()` da tela some (quem cria as
   configurações carrega).
3. Os quatro testes que abriam a tela vazia passam a usar o fake. O que
   eles conferem (zoom e painéis como camadas, painéis separados) não
   muda; se algum dependia de **não** haver partitura, ajustar a
   expectativa e anotar nas notas.
4. `settings_test` e `transpor_tela_test` usam o helper novo.

## Fora de escopo

Mudar `OpenedPiece` de arquivo ou de forma. Extrair controllers (R08+).

## Critérios de aceite

1. `grep -n "widget.opened?" lib/main.dart` e `grep -n "opened == null"
   lib/main.dart` não acham nada.
2. `just analyze` e `just test` limpos.
3. Abrir e fechar um hino no app (`just run`) três vezes seguidas, com o
   teclado MIDI conectado: o teclado continua conectado na biblioteca
   depois de voltar **(manual)**.

## Notas de execução

