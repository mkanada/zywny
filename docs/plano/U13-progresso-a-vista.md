# U13 — Progresso à vista: gaveta, linha do hino e pontuação

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** nenhuma

## Objetivo

O quanto da trilha está feito aparece como barra — na gaveta e na
biblioteca —, nunca cortado por reticências; a pontuação tem rótulo e só
existe quando há pontuação. Achados B4, C1, C2 e parte do E3; sugestões B4,
C1 e C2.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e as sugestões **B4**, **C1** e **C2**.
- Telas `02` (600 linhas de "● —"), `27` e `46` ("há 3 dias · …",
  "13/7…", cartão "Trecho 2/6 · Nota…"), `31` e `36` (gaveta da trilha).
- `lib/library/library_screen.dart`: `_continueCard` L340-L412, `_list`
  L448-L478, `_HymnRow` L481-L594.
- `lib/library/library_sort.dart`: `whenStudied` L113-L124,
  `scoreBandColor` L127-L132.
- `lib/library/hymn_progress.dart` (`bestScore`, `lastOpened`).
- `lib/trail/trail_progress.dart`: `TrailProgress` L102-L264 (`done`,
  `total`, `skipped`, `finalApproved`, `resume`), `TrailResume` L54-L98.
- `lib/trail/trail_widgets.dart`: `TrailDrawer` L318-L556 (`build`
  L350-L432, `_segmentGroup` L434-L453), `trailResumeText` L607-L609.
- `test/library_test.dart`, `test/trail_drawer_test.dart`.
- [J09](J09-progresso-na-biblioteca.md): o que a biblioteca já mostra e por
  quê (as puladas à parte são requisito).

## Contexto que você precisa

- A linha do hino tem 64 dp de altura fixa (`itemExtent: 64`, 600 linhas):
  não cresça a linha.
- Segunda linha de hoje, tudo num texto só com elipse no fim:
  `compositor · nível N · quando · feitas/total · puladas`. O que é cortado
  é sempre o fim — o progresso.
- À direita: marca de trilha concluída (`check_circle`), bolinha colorida
  pela faixa da pontuação (`scoreBandColor`: ≥ 85 verde, ≥ 60 âmbar, senão
  cinza; nunca estudado, bege) e o número, ou "—".
- "Pontuação" = melhor precisão de um treino **livre** avaliado
  (`HymnProgress.bestScore`). Não se mistura com a trilha (J09).
- Largura útil em retrato de 360 dp: 360 − 32 (margens) − 44 (número) =
  284 dp para título + coluna da direita.
- A biblioteca não monta `TrailPlan` (J09, critério 4): tudo vem do resumo
  guardado (`done`, `total`, `skipped`, `resume`).
- A gaveta da trilha mostra "12/12" por trecho e não tem total. O total
  está em `plan.stages.length`; as feitas, em `progress.doneCount(plan)`.
- A ordenação "Pontuação" continua usando `bestScore`.

## O que fazer

1. `TrailProgressBar` (em `lib/trail/trail_widgets.dart`): barra fina de
   duas cores — feitas (`kAccent`) e, dentro delas, as puladas num tom mais
   claro (`kAccentSoftBg` com borda) —, sobre o fundo `kBorderSoft`.
   Parâmetros: `done`, `skipped`, `total`.
2. Gaveta da trilha: cabeçalho com a barra e "13 de 75 etapas" (+ "· 1
   pulada"), acima do botão "Pular etapa atual".
3. `_HymnRow`:
   - segunda linha = `Row`: compositor em `Flexible` com elipse; depois,
     sem elipse, " · nível N" e " · quando"; com pontuação, " · melhor
     94%";
   - coluna da direita (largura fixa ~72 dp): com trilha iniciada, a
     `TrailProgressBar` (48 dp) e "13/75" embaixo, mais " · 1 pul." se
     houver; com a trilha concluída, a barra cheia e o ✓; sem trilha
     iniciada, **nada** (some a bolinha e o "—").
4. Cartão "Continuar": três linhas — "CONTINUAR", título, e a etapa
   ("Trecho 2/6 · Notas da direita") numa linha própria; "Hino 5 · hoje ·
   melhor 78%" como quarta linha menor, ou junto do título se faltar
   altura. A barra de progresso do hino na base do cartão.
5. Remover `scoreBandColor` se ninguém mais usar (a cor deixa de carregar a
   informação sozinha); a ordenação não muda.
6. Atualizar `test/library_test.dart` (os testes do J09 procuram o texto
   "12/51 · 2 puladas" na linha) e `test/trail_drawer_test.dart`.

## Fora de escopo

- Ordenação e busca (U14); cartão de primeiro uso (U16).
- Estatísticas agregadas ("você concluiu 14 hinos").
- Tempo estimado por etapa.

## Critérios de aceite

1. Teste de widget (360 dp de largura): hino com compositor de 30
   caracteres, nível, "há 3 semanas", melhor 78 e trilha 13/75 com 1
   pulada — o progresso e as puladas aparecem **inteiros**; quem tem
   elipse é o compositor.
2. Teste de widget: hino nunca aberto não tem nada na coluna da direita.
3. Teste de widget: trilha concluída → barra cheia e marca de concluído.
4. Teste de widget: gaveta com 13 de 75 feitas e 1 pulada mostra o texto e
   a barra.
5. Teste: a biblioteca continua sem importar `trail_plan.dart` (o teste do
   J09 que confere isso continua passando).
6. `just telas`: telas 02, 27, 31 e 46 refeitas conferem; nenhuma linha da
   27 termina em "…" no progresso.
7. **(manual, retrato, 360 dp)** A linha não quebra nem empurra o título.
8. `just analyze` e `just test` limpos; o roteiro das telas passa.

## Notas de execução

- `TrailProgressBar` e `trailProgressText` em `lib/trail/trail_widgets.dart`.
  A gaveta da trilha ganhou o cabeçalho "13 de 75 etapas · 1 pulada" com a
  barra, acima de "Pular etapa atual".
- Linha da biblioteca: a segunda linha é o compositor (cede, com
  reticências) e o resto (" · nível N · quando · melhor 94%") sem
  reticências; o progresso foi para uma coluna fixa de 84 dp à direita
  (barra de 48 dp e "13/75 · 1 pul." embaixo, com `FittedBox` para nunca
  cortar). Sem trilha iniciada a coluna fica vazia (some a bolinha e o "—");
  concluída, barra cheia e o ✓. `scoreBandColor` saiu; a ordenação por
  pontuação não mudou.
- Cartão "Continuar": a etapa em que parou ganhou linha própria, "Hino N ·
  quando · melhor X%" ficou menor, e a barra do hino fecha o cartão.
- **Limite do 360 dp:** a linha tem ~188 dp para título + segunda linha
  (328 de largura útil − número − coluna da direita). No pior caso (nível +
  quando + melhor) o "resto" mede ~235 dp: nele o compositor some e é o
  próprio resto que ganha reticências. O progresso (coluna da direita) nunca
  é cortado. Se isso incomodar no aparelho, o caminho é tirar "melhor" da
  segunda linha ou encurtar `whenStudied`.
- Nos testes de widget o texto sai em Ahem (muito mais largo que a fonte
  real), então o critério 1 foi testado numa janela de 760 dp conferindo a
  regra (compositor cede; resto e progresso inteiros), não os 360 dp. Os
  testes do J09 (`library_test.dart`) foram ajustados aos textos novos.
- Critérios 1–5 e 8 passam; 6 e 7 não foram conferidos (emulador/aparelho).
