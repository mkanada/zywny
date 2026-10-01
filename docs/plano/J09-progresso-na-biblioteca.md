# J09 — Progresso da trilha na biblioteca

**Repo:** zywny · **Depende de:** J03 · **Decisão necessária:** nenhuma

## Objetivo

Na lista de hinos, cada hino mostra o quanto da trilha está feito e uma
marca quando a música foi concluída (fase final a 100% aprovada).

## Ler antes (só isto)

- [J00](J00-trilha-de-estudo.md): "Interface", "Dados".
- `lib/library/library_screen.dart` (643 linhas): a linha do hino, o cartão
  "Continuar", `_open` L124.
- `lib/library/hymn_progress.dart` e `lib/library/library_sort.dart`
  (ordenações "Recentes" e "Pontuação").
- `lib/trail/trail_progress.dart` (J03: `TrailProgressStore`, e o resumo
  `doneCount`/`total` guardado no JSON).
- `test/library_test.dart`.

## Contexto que você precisa

- A biblioteca é usada em **retrato** no celular e lista 600 hinos: nada
  de montar caminho/plano aqui. O resumo (`feitas`, `total`, `concluída`)
  vem pronto do JSON da trilha de cada hino (J03). Carregue os resumos de
  uma vez só, como `HymnProgressStore.load` faz.
- "Feitas" = aprovadas + puladas (é o que destrava a trilha). Mostre as
  puladas à parte quando houver ("12/51 · 2 puladas"), para o registro do
  pulo ser visível — é requisito do usuário.
- Hino sem trilha iniciada não mostra nada (a linha fica como hoje).
- A "Pontuação" de hoje (`HymnProgress.bestScore`, melhor precisão de um
  treino livre) continua existindo e não se mistura com a trilha.
- O cartão "Continuar" pode dizer em que etapa o hino parou ("Trecho 2/4 ·
  Ritmo da esquerda 75%") se o rótulo estiver no resumo guardado — avalie
  guardar o rótulo da etapa atual junto com o resumo.
- A biblioteca precisa se atualizar quando o aluno volta da partitura
  (`TrailProgressStore` é `ChangeNotifier`).

## O que fazer

1. Leitura em lote dos resumos no `TrailProgressStore`.
2. Linha do hino: barra fina ou texto "12/51", marca de concluído, puladas.
3. Cartão "Continuar" com a etapa atual.
4. (Opcional) ordenação ou filtro "Em andamento".
5. Testes em `test/library_test.dart`.

## Fora de escopo

- Reiniciar ou editar a trilha a partir da biblioteca.
- Estatísticas agregadas ("você concluiu 14 hinos").

## Critérios de aceite

1. Teste de widget: hino com 12 de 51 etapas feitas, 2 puladas → a linha
   mostra o progresso e as puladas; hino sem trilha → linha como hoje.
2. Teste de widget: hino com `final.100` aprovada → marca de concluído.
3. Teste: voltar da partitura depois de aprovar uma etapa atualiza a linha
   sem reabrir a biblioteca.
4. Teste: abrir a biblioteca com 600 hinos não monta nenhum `TrailPlan`.
5. **(manual, celular em retrato)** A linha do hino não quebra nem
   empurra o título em 360 dp de largura.
6. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
