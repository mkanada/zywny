# L02 — `score_bridge`: esconder colunas (nota, barra, linha suplementar)

**Repo:** zywny (`score_bridge/`) · **Depende de:** G09 do bridge (regra
normativa e vetores) · **Decisão necessária:** nenhuma

## Objetivo

Uma API no `score_bridge` para **esconder um conjunto de notas** e
devolvê-las, sem recompilar a página a cada mudança e sem deixar pista da
altura. Ainda sem a pausa substituta (L03).

## De onde vem a regra

O que apagar para uma nota sumir de verdade é regra do **formato**, não
deste passo: está na §11 da especificação do `.vsb`, escrita, provada contra
o Verovio e entregue com vetores de teste pelo repo do bridge
(`/home/mauricio/rust_projects/verovio_flutter_bridge`, passos G07–G09 de
`docs/plano/`). Este passo é a **porta Dart** dela. Se G09 ainda não está
`concluído` lá, pare: não invente a regra aqui.

## Ler antes (só isto)

- [L00](L00-trilha-do-decorar.md): "O que some" e "Fatos medidos".
- No bridge: `docs/nota-para-zywny-sumico.md` (G09) e a §11 de
  `docs/formato/especificacao-v1.md`, regras 1–3.
- `score_bridge/lib/src/score_controller.dart` L1-L50 (modelo de cor e ids
  não-animáveis) e L163-L221 (`setColor`, `setColors`, `clearColor`).
- `score_bridge/lib/src/scene_walk.dart` inteiro (percurso, cor herdada,
  `kOverrideExemptClasses`).
- `score_bridge/lib/src/segmentation.dart` (itens estáticos × dinâmicos) e
  `score_bridge/lib/src/page_layers.dart` (`_pictureAt`, `paint`).
- `score_bridge/lib/src/ghost.dart` L116-L172 (índice por página: como
  achar o `staff` e o `notehead` de uma nota — reaproveite).
- `score_bridge/test/ghost_test.dart` (como os vetores do bridge são lidos
  num teste) e `score_bridge/test/fixtures/sumico/` (copiados em G09).

## Contexto que você precisa

- Esconder a **nota** já funciona hoje: `setColor(id, transparente)` no id
  do nó `note` leva junto cabeça, haste, colchete, acidente, articulação e
  pontos (são filhos). A letra (`verse`) fica, por
  `kOverrideExemptClasses`. Ids do timemap são animáveis: não há
  recompilação de `Picture`.
- **Duas pistas sobram**, e este passo existe por causa delas:
  1. **Barra de ligação** (regra 2 da §11): as formas filhas diretas do
     grupo `beam` somem quando toda `note` descendente está escondida.
     Pintar o `id` do `beam` de transparente **não serve**: pinta as notas
     filhas por herança. É preciso apagar só as folhas diretas.
  2. **Linhas suplementares** (regra 3 da §11): cada traço é uma forma
     própria, sem id, dentro de `ledgerLines above`/`below`, filho de
     `staff`. Um traço pertence às notas da mesma pauta cuja cabeça ele
     cobre em x e cujo `loc` (`pitchpos.json`) alcança a linha dele; some
     quando todas as donas estão escondidas. O Verovio só funde traços do
     mesmo acorde (`LedgerLine::AddDash`), e o bridge varreu o corpus para
     confirmar que as donas de um traço são sempre da mesma coluna — os
     números estão na nota de G09.
- Barra e traços estão em segmentos **estáticos** (`Picture`): apagá-los
  recompila a página, ou exige promovê-los a dinâmicos. Meça
  (`pictureBuilds`) e escolha; o L05 esconde no começo da etapa e revela
  uma coluna por erro, então o custo por revelação é o que importa.
- Cor transparente **não** é "ausente": halo e toque (`onElementTap`) ainda
  enxergam o nó. Nota escondida não tem halo e não responde a toque.
- A continuação de uma nota ligada é uma `note` como outra qualquer e some
  pelo id (o chamador passa cabeça e continuações).

## O que fazer

1. API pública (exportada em `score_bridge/lib/score_bridge.dart`), no
   `ScoreController` ou num controlador irmão:
   `setHidden(Set<String> noteIds)`, `reveal(String id)`, `clearHidden()`,
   `isHidden(id)`. Uma notificação por chamada, como o resto do
   controller. Ids expandidos (`-rend<N>`) resolvem pela regra de sempre.
2. Formas de barra e traços a apagar **derivados** do conjunto de notas,
   pela §11 — o chamador passa só notas.
3. Destaque sobre nota escondida: `highlight` num id escondido **não**
   pinta a nota (o L05 pisca a pausa, não a nota). Revelar devolve o
   comportamento normal.
4. Testes contra `fixtures/sumico/vetores.json` e testes de pintura.

## Fora de escopo

- A pausa substituta (L03).
- Escolher o que esconder (L01) e quando revelar (L05).
- Mudar a §11 ou o formato: divergência entre a regra e o que se vê na
  tela é achado para o bridge (registre e avise), não para remendar aqui.

## Critérios de aceite

1. Teste: os casos de `vetores.json` — para cada conjunto escondido, as
   notas, formas de barra e traços apagados são os do vetor.
2. Teste de pintura: esconder uma nota fora de barra → nenhum pixel da
   nota (cabeça, haste, acidente) na imagem; a letra dela continua.
3. Teste de pintura: barra com 2 notas, uma escondida → barra visível; as
   duas → barra some; revelar uma → barra volta.
4. Teste de pintura: coluna com linha suplementar escondida ao lado de
   coluna visível com linha suplementar → só o traço da escondida some.
5. Teste: `clearHidden()` devolve a página pixel a pixel ao estado sem
   esconder nada.
6. Teste: esconder 50 notas de uma página de uma vez e revelar uma a uma →
   o número de recompilações de `Picture` está nas notas.
7. Teste: `highlight` em nota escondida não a mostra; depois de `reveal`,
   mostra.
8. `cd score_bridge && flutter test` e `just analyze` limpos.

## Notas de execução

_(preencher ao executar)_
