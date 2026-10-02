# U12 — Resumos: erros na pauta e frases no lugar de milissegundos

**Repo:** zywny · **Depende de:** U02, U05 · **Decisão necessária:** nenhuma

## Objetivo

Depois de uma passagem, o aluno **vê** na pauta onde errou, e o resumo do
treino livre fala português em vez de estatística. Achados B2 e B3;
sugestões B2 e B3.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e as sugestões **B2** e **B3**.
- Telas `34`, `39` (resumos da etapa) e `42` (resumo do treino livre).
- `lib/trail/trail_widgets.dart`: `showStageSummary` L130-L247.
- `lib/practice/practice_tools.dart`: `showPracticeSummary` L256-L343.
- `lib/practice/practice_report.dart` (225 linhas): `MeasureStats`
  L23-L59, `meanDeltaMs`, `meanAbsDeltaMs`, `stdDevMs`, `worstMeasures`
  L215-L224.
- `lib/main.dart`: `_onTrailStageDone` L870-L939, `_trailBadLogical`
  L975-L982, `_endPractice` L1246-L1269, `_repeatWorst` L1277-L1285.
- `lib/practice/practice_controller.dart`: `_record` L580-L586 (a que
  compasso um veredito pertence).
- `lib/trail/stage_result.dart` (`badMeasures`).
- O mecanismo de overlay por compasso feito no U02.
- `test/trail_widgets_test.dart`, `test/practice_report_test.dart`.

## Contexto que você precisa

- **Erros na pauta.** `StageResult.badMeasures` são ocorrências de
  `ScoreTimeline.measures`; `_trailBadLogical` converte para o número do
  compasso do caminho. O resumo lista os números e nada mais. O U02 deixou
  pronto o desenho de um widget sobre o retângulo de um compasso.
- **Defeito a investigar.** Na tela 39, uma etapa do trecho "compassos 1–5"
  listou erro no compasso **6**. A gaveta e o resumo usam a mesma numeração
  (`LogicalMeasure.number`), então o 6 é um veredito atribuído a um
  compasso fora do intervalo. Suspeita: em `_record`, uma nota `missed` ou
  atrasada do fim do intervalo é carimbada com
  `measureIndexAt(_lastPlayedMusicalMs)`, que já passou de `range.endMs`.
  Reproduza num teste de `PracticeController` com `range` antes de corrigir.
- **Resumo do treino livre.** Mostra "Em média 100 ms atrasado (desvio
  100 ms, regularidade ±38 ms)" e uma linha por compasso com três
  contagens. Os números continuam úteis para quem quer — atrás de um
  "detalhes".
- Limiares das frases (iniciais; confira com as janelas de D-TREINO —
  ±75 ms "certo"): média dentro de ±30 ms → "No tempo."; acima → "Você
  está entrando atrasado."; abaixo → "…adiantado."; desvio-padrão acima de
  60 ms → acrescenta "O pulso está irregular.". No ritmo, as mesmas frases.
- `MeasureStats.index` é ocorrência; o resumo escreve `index + 1` e, se
  `pass > 1`, "(2ª vez)". No treino livre a música tem repetições, então
  essa numeração fica.
- Os resumos são folhas inferiores (`showModalBottomSheet`). O U18 os leva
  para a lateral; aqui eles continuam folhas, e as marcas ficam na pauta
  **depois** de fechar o resumo.

## O que fazer

1. Corrigir o veredito fora do intervalo (com o teste que o reproduz).
2. Marcas de erro na pauta: depois de uma passagem (etapa ou treino livre
   avaliado), os compassos com erro ganham um fundo `kBadColor` a ~12% até
   o próximo play, troca de etapa ou saída. Um estado só
   (`_errorMeasureIds`), alimentado por `StageResult.badMeasures` e por
   `PracticeReport.measures` com erro.
3. `showStageSummary`: a linha dos compassos vira "Erros nos compassos 6 e
   8 — marcados na partitura." (ou "Nenhum compasso com erro."). Junte os
   números em português ("1, 2 e 3"; faixa contínua vira "1 a 5").
4. `showPracticeSummary`: título com a precisão; as quatro contagens em uma
   linha (como hoje); a frase do tempo; "Deram mais trabalho: compassos 4,
   1 e 2."; o botão de repetir; "Detalhes" abre/fecha o bloco com os
   números de hoje (média, desvio, regularidade e a linha por compasso).
5. Função pura para as frases (`practiceTimingPhrase(report)`), testada nos
   limites.
6. Atualizar `test/trail_widgets_test.dart` e o roteiro das telas se algum
   texto usado para navegar mudou (`find.textContaining('Precisão')`
   continua valendo).

## Fora de escopo

- Trocar a folha inferior por painel lateral (U18).
- A porcentagem e o texto da meta (U05).
- Estatísticas ao longo do tempo (histórico de passagens).

## Critérios de aceite

1. Teste: passagem em tempo real com `range`, última nota perdida →
   nenhum compasso fora de `[first, last]` em `badMeasures`.
2. Teste: `practiceTimingPhrase` em −50, 0, +50 ms e com desvio de 80 ms.
3. Teste de widget: `showPracticeSummary` não mostra "ms" até abrir
   "Detalhes".
4. Teste de widget: `showStageSummary` com erros em 1, 2, 3 e 6 escreve "1
   a 3 e 6".
5. `just telas`: depois do resumo 39 fechado, os compassos com erro estão
   marcados; ao apertar play, a marca some.
6. `just analyze` e `just test` limpos; o roteiro das telas passa.

## Notas de execução

- **Defeito do compasso fora do intervalo: reproduzido e corrigido.** Uma
  tecla sem alvo (veredito `wrong`, sem `eventId`) apertada na folga depois
  do fim do intervalo era carimbada com o compasso de `_lastPlayedMusicalMs`,
  que já era o vizinho de fora (teste: `badMeasures` ganhava o compasso 3 num
  trecho de 1–2). `PracticeController._measureAt` agora prende o instante ao
  intervalo (último compasso do trecho; primeiro, se for antes do início).
  Isto explica o "6" da tela 39 só como hipótese: o roteiro não foi refeito.
- **Marcas na pauta:** `_errorMeasureIds`/`_errorStageId` em `lib/main.dart`,
  um fundo `kBadColor` a 12% pelo overlay do U02. Aparecem depois da
  passagem (etapa, bloco de reforço e treino livre avaliado) e somem no
  próximo play/etapa/ouvir, ao trocar de etapa (inclusive "Próxima etapa" no
  resumo) e ao abrir outro hino.
- **Frases:** `lib/practice/measure_text.dart` (`joinMeasureNumbers`,
  `practiceTimingPhrase`; limiares 30 ms e 60 ms, constantes nomeadas).
  Resumo da etapa: "Erros nos compassos 1 a 3 e 6 — marcados na partitura."
  / "Nenhum compasso com erro.". Resumo do treino livre: frase do tempo,
  "Deram mais trabalho: compassos 4, 1 e 2." e os números atrás de
  "Detalhes".
- Critérios 1–4 e 6 passam (`flutter test`, `just analyze`); o 5 (`just
  telas`) não foi rodado.
