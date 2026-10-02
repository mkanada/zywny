# U07 — Barra lateral com os valores da etapa

**Repo:** zywny · **Depende de:** U03 · **Decisão necessária:** nenhuma

## Objetivo

Na trilha, a barra lateral mostra o andamento **da etapa** e conta os
compassos na mesma numeração da gaveta e do resumo. Nada nela mostra um
valor que a etapa ignora. Achado A7; sugestão A7.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A7**.
- Telas `37` e `38` (etapa a 50% e de duas mãos; a barra diz "100%
  andamento" e "Dir. mão") e `21` (treino livre, onde a barra de hoje está
  certa).
- `lib/ui/phone_chrome.dart`: `PhoneRail` L19-L119, `_RailButton`
  L121-L168.
- `lib/main.dart`: o `ValueListenableBuilder` que monta a `PhoneRail` em
  `_buildPhoneBody` L2105-L2140, `_measureCount` L1890-L1893,
  `_openMeasureJump` L1895-L1940.
- `lib/trail/trail_path.dart`: `TrailPath.logical`, `logicalOf(occurrence)`
  L64-L71, `LogicalMeasure.number` L45.
- `lib/trail/trail_stage.dart`: `TrailStage.speed` (`null` no modo espera),
  `phase.hand`.

## Contexto que você precisa

- Hoje a barra tem seis alvos: play, reiniciar, compasso, andamento, mão e
  ⋯. "Andamento", "mão" e "⋯" abrem a mesma gaveta de opções.
- `tempoPercent` e `handLabel` vêm de `_speed` e `_hand`, que são do
  **treino livre**; a etapa da trilha usa `stage.speed` e `stage.phase.hand`
  sem gravar nada (J05).
- O compasso da barra é `player.currentMeasureIndex + 1` de
  `player.timeline.measureCount`: ocorrências da música **expandida**
  (hino 5: 56). A trilha numera os compassos do **caminho**, sem repetições
  (`LogicalMeasure.number`; hino 5: bem menos). Na mesma tela convivem "5 de
  56" na barra e "compassos 5–9" na gaveta.
- Depois do U03 a barra da trilha já tem o botão "ouvir".
- Altura disponível para a barra em 360 dp de altura de tela: ~296 dp
  (360 − 24 da barra de status − 40 do título). Play 52 + ouvir 48 +
  reiniciar 40 + compasso 48 + andamento 48 + ⋯ 48 = 284 + 24 de margem.
  Cabe justo: não acrescente um sétimo item.
- "Ir para compasso" (`_openMeasureJump`) trabalha em ocorrências. Na
  trilha, com a etapa parada, ele continua valendo (é só navegação), mas o
  rótulo precisa falar a numeração do caminho.

## O que fazer

1. `PhoneRail` ganha um modo trilha (parâmetro, ou um construtor
   `PhoneRail.trail`): play · ouvir · reiniciar · compasso · andamento da
   etapa · ⋯. Sem "mão".
2. Andamento da etapa: "50%" / "75%" / "100%" com a legenda "da etapa"; no
   modo espera, "livre" com a legenda "sem tempo". **Não** é botão (sem
   `InkWell`, sem tooltip de ação).
3. Compasso na trilha: `path.logicalOf(ocorrência atual)` → "5 de N", com
   N = `path.measureCount`. Quando a ocorrência atual não pertence ao
   caminho (repetição, só acontece no treino livre), mostre a numeração de
   hoje.
4. "Ir para o compasso" na trilha: título e controle em compassos do
   caminho (1..N); converte para a ocorrência ao aplicar.
5. No treino livre a barra fica como hoje.
6. Testes de widget da `PhoneRail` nos dois modos; teste da conversão
   ocorrência → compasso do caminho com o fixture de
   `test/trail_path_test.dart`.

## Fora de escopo

- O conteúdo da gaveta de opções (U11).
- Mudar andamento ou mão **da etapa** (são da trilha, não do aluno).
- O layout largo.

## Critérios de aceite

1. Teste de widget: modo trilha com `stage.speed == 0.5` mostra "50%" e não
   mostra "mão"; tocar em "50%" não chama `onOptions`.
2. Teste de widget: etapa do modo espera mostra "livre".
3. Teste: com o caminho do fixture, a ocorrência do compasso 5 do corpo
   mostra o número do caminho, igual ao que a gaveta escreve para o trecho.
4. `just telas`: na tela 37 a barra diz 50%; nas telas da trilha o total de
   compassos da barra é o do caminho, não 56.
5. Treino livre (tela 21): barra idêntica à de hoje.
6. Em 640×360 a barra não estoura (teste de widget com essa janela).
7. `just analyze` e `just test` limpos; o roteiro das telas passa.

## Notas de execução

- `PhoneRail.stageTempo`/`stageTempoCaption` ligam o modo trilha: o
  andamento da etapa é um `_RailReadout` (sem toque, sem dica de ação) e o
  botão de mão some. Etapa do modo espera: "livre" / "sem tempo".
- `TrailPath.numberOf(occurrence)` e `startMsOfNumber(number)` fazem a
  conversão; a barra mostra "N de total" do caminho e "Ir para o compasso"
  fala a mesma numeração (fora do caminho, cai na numeração de hoje).
- Critérios 1, 2, 3, 6 e 7 (`flutter test`, `just analyze`) passam. 4 e 5
  (`just telas`) não foram rodados.
