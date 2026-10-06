# Q03 — Guardar a transposição e renderizar transposto

**Repo:** zywny · **Depende de:** Q01, Q02 · **Decisão necessária:** não
(D-TRP-ESCOPO decidida)

## Objetivo

A música abre transposta quando a pessoa escolheu isso (por música) ou
quando a chave geral manda (para as que não têm escolha própria). A
partitura, o timemap e o `midi.json` saem na altura escrita.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "Onde a transposição acontece" e a
  linha D-TRP-ESCOPO.
- Notas de execução do Q01.
- `lib/settings/piece_settings.dart` (`PieceSettings` L18, `toJson` L66,
  `fromJson`), `lib/settings/app_settings.dart` (padrão das chaves, `load`
  L246), `lib/verovio_render.dart` (`VsbRenderRequest` L15), o renderizador
  Web (`lib/render/score_renderer_web.dart`, `web/verovio_worker.js` L32) e
  `lib/main.dart` `_renderAndShow`/`_commitLayout` (L2065).

## O que fazer

1. `PieceSettings.transpose`: `String?` com o intervalo; JSON `'tr'`. Três
   estados: ausente (segue a chave geral), `'P1'` (a pessoa escolheu "Não" —
   vence a chave geral) e um intervalo. `Transposition.parse('P1')` devolve
   `null` (não é transposição): trate o `'P1'` **antes** de chamar `parse`.
   `fromJson` descarta o que não é `'P1'` nem `Transposition.parse` aceita.
   `isDefault` passa a considerar o campo.
2. `AppSettings.transposeByDefault` (`bool`, chave `score_transpose_default`,
   padrão `false`): "Abrir as músicas já sem acidentes".
3. Função única `effectiveTransposition(Piece, PieceSettings, AppSettings)
   → Transposition?`: escolha da música; senão, a chave geral com
   `toNoAccidentals(piece.fifths, …)`; `P1` ou `fifths == 0` → `null`. A
   faixa (nota mais grave/aguda) vem do `midi.json` do original quando já
   renderizado; na primeira vez, usa a faixa do catálogo de hinos (27–86, nada
   estoura A0–C8 em direção nenhuma: Q01) e corrige depois de renderizar se uma
   biblioteca estourar (clássicos não foram medidos).
4. O render recebe `'transpose': t.interval` nas opções, no nativo e na
   Web. Sem transposição, **nenhuma** opção nova vai ao Verovio (o `.vsb`
   original fica equivalente ao de hoje, critério 3).
5. Música sem `fifths` no catálogo: a opção não aparece (Q08 esconde) e a
   chave geral não age.

## Fora de escopo

Som, casador, progresso (Q04/Q05), tela (Q08). Por enquanto a escolha só
entra por teste ou pela chave geral.

## Critérios de aceite

1. Testes de `PieceSettings` (ida e volta do JSON, `P1`, lixo descartado) e
   de `effectiveTransposition` (as combinações música × chave geral).
2. Teste de render (`test/vsb_render_test.dart` ou vizinho, Linux): hino em
   3♭ com `-m3` → `midi.json` com todas as notas k abaixo e armadura vazia.
3. Sem transposição, o `.vsb` do mesmo hino é equivalente ao de antes do
   passo: mesmas notas e tempos, mesmo layout (os ids mudam a cada render, e
   o arquivo difere no carimbo de hora do zip — Q01; para comparar por id,
   passe a mesma semente `xmlIdSeed` nos dois).
4. `just web-smoke` passa.

## Notas de execução

(vazio)
