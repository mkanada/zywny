# Q04 — Progresso separado por tom

**Repo:** zywny · **Depende de:** Q03 · **Decisão necessária:** não
(D-TRP-PROGRESSO decidida: separado)

## Objetivo

Cada tom de uma música tem a sua trilha e a sua pontuação. O tom original
continua com as chaves de hoje, sem migração.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "Progresso separado por tom".
- `lib/library/library_keys.dart` (todo), `lib/library/piece_progress.dart`
  (`PieceProgressStore` L28: mapa id → `{t, s}` em `lib_progress_<bib>`),
  `lib/trail/trail_progress.dart` (`TrailProgressStore` L270: `ensureLoaded`,
  `summary`, `load`, `save`, `reset`), o J09 (progresso na biblioteca) e quem
  chama esses stores (`graft callers TrailProgressStore`).

## O que fazer

1. `progressIdFor(String pieceId, Transposition? t)` em `library_keys.dart`:
   `pieceId` quando `t == null`; `'$pieceId@${t.interval}'` senão. É a
   **única** forma de montar o id; `trailKeyFor` e a pontuação recebem esse
   id.
2. Trilha: a tela da partitura carrega e grava a trilha pelo id do tom em
   uso. Trocar de tom troca de trilha.
3. Pontuação (`recordScore`): pelo id do tom. `markOpened` (`lastOpened`,
   "Continuar", "Recentes") continua pelo `pieceId` puro.
4. Biblioteca (J09): o resumo de cada música é o do tom em uso
   (`effectiveTransposition`, Q03). `load` passa a pedir esses ids; ler as
   `PieceSettings` de todas as músicas só para isso é caro — guardar o tom em
   uso junto do `lastOpened` no mapa de `lib_progress_<bib>` (campo novo
   `tr`) e usar a chave geral quando ausente.
5. "Também estudada": função que lista os tons com trilha começada de uma
   música (os ids `<id>@…` presentes + o original), para a tela do Q08.
6. Confirmação ao trocar de tom com trilha em andamento: a lógica (há
   trilha começada no tom atual e nenhuma no novo?) fica aqui; o diálogo, no
   Q08.
7. Remover biblioteca (D-BIB-REMOVER) continua sem apagar nada; reinstalar
   recupera todos os tons.

## Fora de escopo

Decorar (fase L ainda não existe): o L04 usa `progressIdFor` quando for
escrito — anote isso nas notas de execução do L00/L04 se eles já existirem
como arquivo.

## Critérios de aceite

1. Testes: trilha no original e em Dó independentes; voltar ao original
   reencontra a trilha; a chave antiga (`trail_<bib>_<id>`) continua lida
   sem migração; biblioteca mostra o resumo do tom em uso; "também
   estudada" lista os tons certos.
2. `just analyze` e `just test` limpos.

## Notas de execução

### Resultado (2026-10-06): concluído

Arquivos: `lib/library/library_keys.dart` (`progressIdFor`, `pieceIdOfProgressId`,
`toneOfProgressId`), `lib/library/piece_progress.dart` (campo `tr`, `forTone`,
`transposeChoice`, `setTranspose`), `lib/trail/trail_progress.dart`
(`loadMissing`, `studiedTones`, `toneChangeStartsOver`), `lib/library/library_screen.dart`,
`lib/library/library_sort.dart` (`progressOf`), `lib/main.dart`.
Teste novo: `test/progresso_por_tom_test.dart` (16 casos).

**Decisões de execução**
- **Quem monta o id.** `trailKeyFor(bib, id)` e `recordScore(id, …)` recebem o
  *id de progresso*; só `progressIdFor` o monta. `TrailController.pieceId` passou
  a carregar esse id (o nome ficou, o comentário diz).
- **A tela da música usa o tom da gravura que está na tela**
  (`_renderedTransposition`), não o pedido: a trilha é montada depois de cada
  render (`_setupTrail`), então trocar de tom troca de trilha sozinho.
- **`tr` guarda a escolha da música, não o tom resolvido.** É o
  `PieceSettings.transpose` (intervalo, `P1` ou ausente), na entrada do id puro
  de `lib_progress_<bib>`. A biblioteca resolve com `effectiveTransposition` +
  a chave geral, então ligar "abrir já sem acidentes" muda o tom mostrado em
  todas as músicas sem escolha própria, sem reler as configurações de cada uma.
  Escrito ao abrir (`markOpened(id, transpose:)`) e quando a música muda a
  escolha (`setTranspose`, pelo `onPieceSettingsChanged`).
  Limite: no caso da chave geral a biblioteca usa a faixa do catálogo (27–86)
  para escolher a direção; só difere da tela se uma biblioteca estourar o
  teclado numa direção (trítono, 6♯/6♭), e aí a trilha mostrada seria a da
  outra direção até a pessoa abrir.
- **`lastOpened` é por música.** A entrada de um tom (`<id>@-m3`) só guarda a
  nota (`s`): `recordScore` não lhe dá `lastOpened`, senão "Continuar" apontaria
  para um id que não é música. `forTone` junta a abertura da música com a nota
  do tom.
- **Biblioteca.** `sortedPieces(…, progressOf:)` ordena pela nota do tom em
  uso; a linha, o cartão "Continuar" e a trilha usam `_toneInUse`. Depois de
  abrir uma música e de fechar as configurações gerais, `_syncTrails` lê só as
  trilhas dos tons que passaram a estar em uso (`loadMissing`, sem reler as 469).
- `onPracticeScore` passou a `void Function(int score, Transposition?)`
  (`PracticeScoreCallback`): a pontuação precisa do tom.
- **Para o Q08:** `TrailProgressStore.studiedTones(pieceId)` devolve os tons com
  etapa feita (original primeiro); `toneChangeStartsOver(pieceId, de, para)`
  diz se o diálogo "Em Dó a trilha começa do zero…" cabe (há etapa feita no tom
  atual e nenhuma no novo). O diálogo é do Q08. A confirmação de "Trocar o
  corte?" (J06) também passou a zerar só a trilha do tom em uso.
- **Fase L:** o L04 ainda não foi executado; a nota de que o decorar usa
  `progressIdFor` está nas notas de execução de `L04-plano-e-progresso-do-decorar.md`.

**Critérios**
1. Trilha no original e em Dó independentes; reset de um não mexe no outro;
   chave antiga (`trail_<bib>_<id>`) lida como o original; pontuação por tom
   (não rebaixa); "última aberta" não vê entrada de tom; biblioteca mostra o
   tom em uso (chave geral, "Não" vence, escolha da música); "também estudada"
   lista os tons certos (e não confunde `001` com `0010`). ✔
2. `just analyze` e `just test`: ver o fim das notas do Q05.
