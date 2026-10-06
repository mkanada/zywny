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

### Resultado (2026-10-06): concluído

Arquivos: `lib/settings/piece_settings.dart` (`transpose`, `kTransposeNone`),
`lib/settings/app_settings.dart` (`transposeByDefault`),
`lib/settings/effective_transposition.dart` (novo: `effectiveTransposition`,
`kCatalogLowestMidi`/`kCatalogHighestMidi` = 27/86), `lib/main.dart`.
Testes: `test/effective_transposition_test.dart` (novo), `test/settings_test.dart`
(JSON, chave geral e a fiação da tela), `test/vsb_render_test.dart` (render real).

**Critérios**
1. `PieceSettings`: ida e volta de `-m3` e `P1`, lixo descartado (`P3`, `m4`,
   `P8`, texto, número; `+p4` vira `P4`; `-P1` é descartado). `effectiveTransposition`:
   música × chave geral, música sem armadura, `fifths == 0`, escolha que vence
   a chave, direção pela faixa. ✔
2. `vsb_render_test.dart`: frase em Mi♭ maior (3♭, com repetição, 16 notas
   contando as `-rend`) com `-m3`: todas as notas k = −3 abaixo uma vez só,
   mesmos tempos, pauta/camada/ligadura e timemap, mesmas páginas, armadura da
   primeira nota com 3 → 0 acidentes. A partitura está escrita no teste (sem
   depender do Hymn_Grabber). ✔
3. Sem transposição **nenhuma** opção nova vai ao Verovio: conferido no que a
   tela pede ao renderizador (`ScoreHomePage(renderer:)`, novo, só para teste;
   o teste quebra se a opção sair do `_renderAndShow`). No render, o original sem
   a opção é o que o Q01 mediu; mesma semente → mesmos ids. ✔
4. `just web-smoke`: passa (15 ok). O smoke não usa `transpose`; conferi o wasm
   à parte em Node (`vrvToolkit_setOptions` com `{"transpose":"-m3"}` no hino
   013: aceita, 561 notas, primeira altura 70 → 67). ✔

**Como ficou**
- O render nativo e o Web **já repassavam** `ScoreRenderRequest.options` ao
  Verovio sem lista de permitidos (`_renderInIsolate`, `WebScoreRenderer`,
  `verovio_worker.js`): nada mudou neles; a opção só entra em `main.dart`
  (`_renderAndShow` e `_effectiveOptions`, o "copiar opções").
- `_pieceSettingsWith` passa `transpose: _stored.transpose`, senão gravar o
  andamento apagaria a escolha. O Q08 troca `_stored.transpose` por um campo
  mutável quando houver tela.
- A faixa vem do `midi.json` da última gravura (`_originalRange`, já descontado o
  `k` da gravura); se a direção da chave geral mudar com a faixa real, grava de
  novo (uma vez: a faixa não muda entre gravuras). **Só vale para a chave geral**:
  um intervalo escolhido na música nunca troca de direção. Esse re-render **não
  tem teste** (precisa de uma partitura com nota abaixo de 27 ou acima de 86 e
  armadura de trítono); a decisão da direção em si está coberta em
  `effective_transposition_test.dart`.
- Ligar/desligar a chave geral com um hino aberto regrava o hino
  (`_onSettingsChanged`, quando a transposição de agora difere da gravada).
  Sem tela ainda: a chave só muda por código/teste até o Q08.

**O que o próximo passo precisa saber**
- Até o Q04 o progresso (trilha, pontuação) **é compartilhado** entre tons:
  com a chave geral ligada a trilha do hino transposto cai na mesma chave do
  original. Até o Q05 o app **toca a altura escrita** (transposta), não a
  soada. Por isso a chave geral não deve ser ligada fora de teste.
- `Piece` sem `fifths`: a chave geral não age; um intervalo guardado vale
  mesmo assim (não precisa da armadura).
- O Q04 pode ler `effectiveTransposition(piece, pieceSettings, appSettings)`
  (já na faixa do catálogo; é um valor puro) para montar o `progressIdFor`.

