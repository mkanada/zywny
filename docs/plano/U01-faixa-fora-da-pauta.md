# U01 — A faixa da trilha sai de cima da pauta

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** D-FAIXA

## Objetivo

Nada cobre o topo da área da partitura: as cifras da primeira linha aparecem
inteiras e os painéis "Layout deste hino" e "Configurações gerais" abrem com
o cabeçalho à vista. A informação da trilha passa a morar na barra do
título. Achado A3; sugestão A3.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A3** de
  `docs/ux/sugestoes-ux-celular.md`.
- Telas `11`, `17`, `18`, `30`, `43` de `docs/telas/celular/`.
- `lib/main.dart`: `_buildPhoneTitleBar` L1966-L1987, `_trailStrip`
  L1993-L2021, `_trailMessage` L2054-L2068, `_buildPhoneBody` L2073-L2147
  (a faixa é o `Positioned` de L2091-L2097), e os painéis flutuantes de
  `_buildScoreArea` (os `Positioned(top: 8, …)` de L2381-L2470: monitor
  MIDI, layout e configurações).
- `lib/ui/phone_chrome.dart`: `PhoneTitleBar` L181-L241, `PhoneStatusPill`
  L277-L315, `PhoneCountersPill` L322-L371.
- `lib/trail/trail_widgets.dart`: `TrailStrip` L48-L118, `trailStripTextFor`
  L23-L26, `trailStateText` L30-L37.
- `test/trail_widgets_test.dart` (grupo `TrailStrip`, L30-L67).

## Contexto que você precisa

- Hoje a faixa (34 dp) é desenhada **sobre** a área da partitura, de
  propósito: assim ela não muda a caixa para a qual a página é gravada e não
  dispara re-render (J05). O efeito colateral é que ela cobre o topo da
  página (as cifras) e o cabeçalho dos painéis, que são ancorados em
  `top: 8` da mesma área.
- **D-FAIXA, recomendação (a):** levar a informação para a barra do título.
  Em paisagem a barra tem ~830 dp de largura e o título ocupa ~290. A área
  da partitura fica com a altura de hoje — **a caixa não muda, não há
  re-render** nem ao alternar trilha ↔ treino livre.
- **Alternativa (b):** manter a faixa e transformar o `Positioned` numa
  linha própria do `Column`, **sempre presente** (vazia ou com "Treino
  livre"), para a caixa não mudar ao alternar. Custa 34 dp de pauta.
- O layout largo (L2564) continua com a `TrailStrip` de hoje. Não a apague.
- O play da faixa repete o botão grande da barra lateral
  (`PhoneRail.onPlayPause` já chama `_startTrailStage` na trilha, L2112).
  Na barra do título ele não entra.
- O selo de acertos e o selo de modo já são `trailing` da barra do título
  (L1973-L1985). O bloco da trilha entra **antes** deles.
- O roteiro das telas abre a gaveta da trilha tocando no centro da
  `TrailStrip` (`_openTrailDrawer`) e começa a etapa por
  `find.byTooltip('Começar etapa')`: os dois precisam continuar funcionando
  (o tooltip existe também no botão da barra lateral).

## O que fazer (via a)

1. Widget novo em `lib/trail/trail_widgets.dart`, `TrailTitleChip`: o texto
   da etapa (`trailStripTextFor`) + o estado (`trailStateText`) + um "▾",
   numa linha com elipse; toque = `onTap` (abre a gaveta). Alvo de toque de
   40 dp de altura (a altura da barra).
2. `PhoneTitleBar` ganha um parâmetro `center` (ou reaproveita `trailing`):
   o título continua com `Expanded`, mas com largura máxima; o bloco da
   trilha fica entre o título e os selos, `Flexible`, cortando antes do
   título.
3. `_buildPhoneBody`: tirar o `Positioned` da faixa. `_buildPhoneTitleBar`:
   montar o `TrailTitleChip` a partir do que `_trailStrip()` usa hoje. As
   mensagens de `_trailMessage` ("Trilha indisponível neste hino — treino
   livre", "Fase final em breve") viram texto simples no mesmo lugar.
4. No treino livre com trilha disponível, o mesmo lugar mostra "Treino
   livre"; toque = voltar à trilha (`trail.setFreeMode(false)`).
5. Atualizar `_openTrailDrawer` do roteiro
   (`integration_test/telas_celular_test.dart`) para tocar no
   `TrailTitleChip`.
6. Testes de widget do `TrailTitleChip` e da `PhoneTitleBar` com título
   longo em 844×390 e em 640×360 (o título encolhe antes; nada estoura).

## Fora de escopo

- O layout largo.
- Mudar o conteúdo do selo (U05) ou acrescentar "ouvir" (U03) e o
  alto-falante (U04) — eles entram na mesma barra depois.
- Reancorar os painéis flutuantes em outra posição (U18 troca o tipo de
  superfície).

## Critérios de aceite

1. Teste de widget: `PhoneTitleBar` com título de 40 caracteres, etapa
   "Trecho 2/6 · Tudo junto no ritmo 75% · 98%" e um selo, em 640×360 — sem
   `RenderFlex overflow`; o texto da etapa aparece por inteiro ou com
   elipse, o título com elipse.
2. Teste de widget: tocar no texto da etapa chama `onTap`.
3. `just telas` (em diretório de scratch): nas telas 11, 30 e 32 as cifras
   da primeira linha aparecem inteiras; nas 17 e 18 o painel mostra o
   título e os botões do cabeçalho inteiros.
4. Abrir e fechar a trilha ↔ treino livre **não** imprime
   `_renderAndShow: renderScoreToVsb(...)` de novo no log (a caixa não
   mudou).
5. O roteiro das telas passa inteiro.
6. `just analyze` e `just test` limpos.

## Notas de execução

- D-FAIXA decidida pelo usuário: **(a)**, barra do título.
- `TrailTitleChip` (em `trail_widgets.dart`) + parâmetro `center` em
  `PhoneTitleBar`: título e chip dividem o espaço em partes iguais e cortam
  com reticências. `_trailChip()` em `main.dart` monta o chip; `_trailStrip()`
  segue só no layout largo. No treino livre com trilha o chip diz "Treino
  livre" e o toque volta à trilha.
- O roteiro das telas foi atualizado (`TrailTitleChip` no lugar de
  `TrailStrip`), mas **não foi rodado**: critérios 3–5 pendentes. Os
  critérios 1, 2 e 6 passam (`flutter test`, `just analyze`).
- `dart format` reformatou também `trail_widgets.dart` e
  `test/trail_widgets_test.dart` inteiros; o ruído foi mantido.
