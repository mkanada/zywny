# U09 — A contagem sai de cima do primeiro compasso

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** D-CONTAGEM

## Objetivo

Durante a contagem, o aluno enxerga inteiro o compasso em que vai entrar, e
nada na pauta está aceso. Achado A9; sugestão A9.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A9**.
- Telas `22` e `37`.
- `lib/practice/count_in_overlay.dart` (130 linhas, inteiro):
  `kCountInColor`, `kCountInGrowth`, `kCountInBlur`, `countInOpacityAt`,
  `_number`.
- `lib/main.dart`: onde o `CountInOverlay` entra em `_buildScoreArea`
  (`Positioned.fill`, L2367-L2373), `_startSilentCountIn` L1053-L1101,
  `_startTrailStage` L788-L865 (`practice.start(countIn: timed)` e o
  `player.seek`).
- `lib/audio/metronome.dart`: `countInBeats` L108, `countInTickAt` L165,
  `CountInTick`.
- `score_bridge/lib/src/score_player.dart`: `seek` L394-L421.
- `test/count_in_overlay_test.dart`.

## Contexto que você precisa

- A contagem foi desenhada de propósito grande e central (commit "Contagem
  obrigatória com número regressivo sobre a partitura"): o número ocupa
  ~62% da altura da caixa, cresce 60% e desfoca até o tempo seguinte. Do
  banco do piano ele se lê bem. O problema é **onde** ele fica: o centro
  horizontal da caixa cai sobre o 2º–3º compasso, e o crescimento com
  desfoque espalha a mancha até o primeiro.
- **D-CONTAGEM, recomendação (a):** manter o número grande, mas na metade
  **direita** da caixa, sem crescer nem desfocar, com opacidade máxima de
  50%. **(b):** quatro pontos de pulso na barra do título. **(c):** como
  está.
- A etapa começa no primeiro compasso da página (à esquerda) na grande
  maioria dos casos — depois do U02, a página já é a do trecho. Um trecho
  pode começar no meio da página: aí o número deveria ir para o lado
  oposto ao do primeiro compasso do trecho. Se isso custar caro, fique com
  a direita fixa e anote.
- **Nada aceso durante a contagem.** O `player.seek` para o início acende
  as notas daquele instante (é o que mostra a "esperada" no modo espera).
  Nas passagens **com** contagem, essas notas devem ficar apagadas até o
  primeiro tempo. O modo espera não tem contagem e continua acendendo.
- O `CountInOverlay` lê a contagem por um retorno (`read`) a cada quadro;
  ele não sabe de páginas nem de compassos.

## O que fazer (via a)

1. `CountInOverlay`: parâmetro de alinhamento horizontal (padrão: centro,
   para o layout largo); no celular, o número centrado na metade direita.
   Sem `Transform.scale`, sem `ImageFiltered`; a opacidade é
   `0.5 * countInOpacityAt(p)`. As constantes `kCountInGrowth` e
   `kCountInBlur` saem se ninguém mais as usar.
2. Tamanho: no máximo 45% da altura da caixa (cabe na metade direita sem
   encostar na barra lateral).
3. Notas apagadas na contagem: nas passagens com `countIn`, depois do
   `seek`, apagar os destaques (`_controller.clearHighlights()`) e fazer o
   player reacender as notas do instante de partida quando a música de
   fato começa. Verifique se o player já reaplica as entradas do instante
   inicial ao sair da contagem; se não, a correção é em
   `score_bridge/lib/src/score_player.dart` (um `seek` que não acende, ou
   um reaplicar no `play`) — com teste lá.
4. Atualizar `test/count_in_overlay_test.dart` (o teste "mostra o tempo que
   falta e esmaece até o próximo" continua; some a verificação de escala,
   se houver) e acrescentar: alinhado à direita, o centro do número fica
   além da metade da caixa.
5. O roteiro das telas fotografa a contagem por `_shotCountIn`, que procura
   o `Opacity` do overlay e espera a opacidade passar de 0,9: com o teto de
   0,5 o limiar tem de mudar (0,45).

## Fora de escopo

- Quantos tempos se conta e o som dos cliques (`countInBeats`).
- A contagem do layout largo (fica central).

## Critérios de aceite

1. Teste de widget: com alinhamento à direita, o `Text` do número está
   inteiro na metade direita da caixa; a opacidade nunca passa de 0,5.
2. Teste de widget: não há `ImageFiltered` nem `Transform` na árvore do
   overlay.
3. `just telas`: nas telas 22 e 37 o primeiro compasso está inteiro à
   vista e **nenhuma** nota está acesa.
4. `just telas`: na primeira foto depois da contagem (38) as notas do
   primeiro tempo acendem normalmente.
5. Modo espera (tela 32): a nota esperada continua acesa desde o começo.
6. `just analyze` e `just test` limpos (e `cd score_bridge && flutter test`
   se o player mudou); o roteiro das telas passa.

## Notas de execução

- D-CONTAGEM decidida pelo usuário: **(a)**.
- `CountInOverlay(phone: true)`: número na metade direita (`Alignment(0.5,
  0)`), até 45% da altura, sem escala nem desfoque, opacidade máxima
  `kCountInPhoneMaxOpacity` = 0,5. O layout largo mantém a contagem
  central. O número fica **sempre** à direita (não vai para o lado oposto
  ao do primeiro compasso do trecho quando ele começa no meio da página):
  o passo permitia isso.
- **Nada aceso na contagem:** `ScoreAudioScheduler.isCountingIn` (novo;
  `countInTick` é `null` também antes do 1º clique soar) e
  `_playPlayerAfterCount` em `lib/main.dart`: com contagem em curso o
  player só é solto quando ela acaba, depois de apagar o destaque do
  instante de partida e de um `seek` que o reacende. O `score_bridge` não
  mudou — o player não reaplicava as entradas do instante inicial, então o
  `seek` no fim da contagem faz esse papel. Vale na etapa, no treino livre
  e no play com som. O play mudo (`_startSilentCountIn`) já soltava o
  player só no fim.
- O roteiro passou a esperar opacidade > 0,45 (e < 0,25 no esmaecido).
- Critérios 1 e 2 e 6 passam (`flutter test`, `just analyze`; o
  `score_bridge` não mudou). 3–5 (`just telas`) **não foram rodados**: o
  `_playPlayerAfterCount` só se confirma no aparelho/emulador, em especial
  que a haste e o compasso corrente não "pulem" ao sair da contagem.
