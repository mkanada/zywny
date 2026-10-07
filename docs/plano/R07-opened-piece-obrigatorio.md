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


Feito em 2026-10-06.

- `ScoreHomePage({required this.opened, …})`; `OpenedPiece` não mudou. Na
  tela, um getter `_piece` substitui os `widget.opened?.piece`; `_scoreName`
  e `_scoreXml` deixaram de ser anuláveis. Saíram o `_settings.load()` da
  tela, os três descartes condicionais, o `if (opened == null) return` de
  `_setPieceTrailN`/`_chooseTranspose`, a mensagem "Trilha indisponível sem
  uma música aberta", o `if (widget.opened != null)` em volta do N da
  trilha na gaveta e o título "nenhuma partitura" da barra do desktop. O
  status inicial `nenhuma partitura` ficou: vale até a primeira gravura.
- `test/support/score_page_fakes.dart`: `RecordingRenderer` (o de
  `settings_test`, com o `next`/`empty` que o `transpor_tela_test` tinha),
  `fakePiece` e `fakeOpenedPiece`. O fake cria o que o teste não passar
  (configurações com os padrões, sem `load()` — o mesmo que ler
  preferências vazias —, store da trilha e gerenciador MIDI) e o descarta
  num `addTearDown` feito por ele mesmo; o que o teste passar é do teste.
- `test/widget_test.dart` abre um hino de mentira (244, "Ó Vem à Igreja
  Comigo"). Só o primeiro teste dependia de **não** haver partitura ("sem
  hino, a tela fica vazia"): virou "a tela grava o hino na primeira caixa e
  oferece voltar à biblioteca" — antes do primeiro layout, status
  `nenhuma partitura` e nada desenhado; depois do layout, a página na
  tela. Os de zoom e painéis como camadas não mudaram.
- `settings_test` (três testes de painéis + grupo do transpor) e
  `transpor_tela_test` usam o helper; os `_RecordingRenderer` locais saíram.
- Aceite: os dois `grep` não acham nada; `just analyze` limpo; `just test`
  878 passaram, 10 pulados. **Critério 3 (manual, teclado MIDI) pendente.**
