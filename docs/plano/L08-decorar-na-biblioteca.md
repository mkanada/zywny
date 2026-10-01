# L08 — Decorar na biblioteca

**Repo:** zywny · **Depende de:** J09, L04 · **Decisão necessária:** nenhuma

## Objetivo

Na lista de hinos, mostrar quais o aluno sabe **de cor** e, para os que
estão no meio do caminho, quanto falta.

## Ler antes (só isto)

- [L00](L00-trilha-do-decorar.md): "Interface", "Dados".
- [J09](J09-progresso-na-biblioteca.md) e as notas de execução dele.
- `lib/library/library_screen.dart` (a linha do hino depois do J09),
  `lib/library/library_sort.dart`.
- `lib/memo/memo_progress.dart` (L04: resumo `feitas`/`total`/`puladas`/
  `deCor` guardado no JSON, leitura em lote).
- `test/library_test.dart`.

## Contexto que você precisa

- A biblioteca é usada em **retrato**, com 600 hinos: nada de montar
  `MemoPlan` aqui. Os resumos vêm prontos do store, carregados de uma vez.
- A linha do hino já carrega, depois do J09, o progresso e a marca de
  conclusão da trilha de estudo. O decorar entra **sem** uma segunda
  barra: uma marca própria para "de cor" (distinta da de concluído) e, se
  a trilha do decorar foi começada e não terminou, um texto curto
  ("decorar 14/75"). Hino que nunca abriu o decorar não mostra nada a
  mais.
- Puladas aparecem, como no J09 ("decorar 14/75 · 2 puladas").
- O cartão "Continuar" continua falando da trilha de estudo (é a tela
  padrão do hino).
- A biblioteca se atualiza ao voltar da partitura (o store é
  `ChangeNotifier`).

## O que fazer

1. Carregar os resumos do decorar junto com os da trilha de estudo.
2. Linha do hino: marca "de cor" e o texto de andamento.
3. Filtro ou ordenação "De cor" ao lado dos que o J09 criou (se criou).
4. Testes em `test/library_test.dart`.

## Fora de escopo

- Estatísticas agregadas ("você sabe 14 hinos de cor").
- Reiniciar o decorar a partir da biblioteca.
- Lembrete de revisão.

## Critérios de aceite

1. Teste de widget: hino com `deCor` → marca; hino com 14 de 75 e 2
   puladas → texto; hino sem decorar → linha igual à do J09.
2. Teste: a marca "de cor" e a de trilha de estudo concluída aparecem
   juntas sem se confundir (rótulos de acessibilidade diferentes).
3. Teste: voltar da partitura depois de aprovar `cega.100` atualiza a
   linha sem reabrir a biblioteca.
4. Teste: abrir a biblioteca com 600 hinos não monta nenhum `MemoPlan`.
5. **(manual, celular em retrato)** Com as duas marcas e os dois textos, a
   linha não quebra nem empurra o título em 360 dp de largura.
6. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
