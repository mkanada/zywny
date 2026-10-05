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

(vazio)
