# U18 — Um visual só: tema e superfícies

**Repo:** zywny · **Depende de:** U12 · **Decisão necessária:** nenhuma

## Objetivo

Diálogos, painéis e botões têm as cores e a forma do resto do app, e na
tela da partitura tudo o que ajusta ou mostra algo da partitura entra pela
lateral, deixando a pauta à vista. Achados E1 e E2; sugestões E1 e E2.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e as sugestões **E1** e **E2**.
- Telas `06`, `09`, `19`, `20`, `34`, `42` (fundo lavanda, botões
  arroxeados, folhas inferiores sobre a pauta) contra `02`, `14`, `31` (a
  identidade do app: bege, azul `kAccent`).
- `lib/ui/theme.dart` (65 linhas, inteiro).
- `lib/ui/phone_chrome.dart`: a casca da `PhoneOptionsDrawer` L401-L447
  (véu + painel de 400 dp à direita + cabeçalho com fechar).
- `lib/trail/trail_widgets.dart`: a mesma casca repetida em
  `TrailDrawer.build` L350-L395; `showStageSummary` L130-L247;
  `showTrailConclusion` L253-L286.
- `lib/practice/practice_tools.dart`: `showLoopSheet` L16-L93,
  `showPracticeSummary` L256-L343.
- `lib/main.dart`: `_openMeasureJump` L1895-L1940, `_openLoopSheet`
  L1391-L1406, os painéis flutuantes de `_buildScoreArea` (L2381-L2470), o
  `PopScope` de `build` L2487-L2504.
- `lib/layout_panel.dart` e `lib/settings/general_settings_panel.dart`
  (como desenham o próprio cartão: `Material`/`Card` + cabeçalho).

## Contexto que você precisa

### Tema (E1)

- `buildAppTheme` usa `ColorScheme.fromSeed(seedColor: kAccent)`: o
  Material deriva um primário **arroxeado e dessaturado** e superfícies
  lavanda. Por isso `FilledButton`, `Switch`, `Slider`, `AlertDialog` e
  `SwitchListTile` não têm a cor do app.
- Para compensar, cinco pontos do código forçam `activeColor: kAccent` ou
  `activeTrackColor: kAccent`, e as folhas passam `backgroundColor:
  kSurface` à mão. Com o tema
  certo, eles saem.
- A paleta está toda em constantes no topo de `theme.dart`.

### Superfícies (E2)

- Na tela da partitura do celular existem hoje quatro tipos: gaveta lateral
  (opções, trilha), cartão flutuante de 360 dp (layout, configurações,
  monitor MIDI), folha inferior (ir para compasso, repetir trecho, resumo
  da etapa, resumo do treino, conclusão da trilha) e diálogo central
  (teclado, atraso, confirmações, cor).
- Em paisagem (411 dp de altura) a folha inferior cobre a pauta de baixo —
  nas telas 19 e 20, enquanto o aluno escolhe compassos olhando para ela.
- **Regra:** o que ajusta ou mostra algo **da partitura** entra pela
  direita, num painel de 400 dp; o que pede uma resposta antes de continuar
  é diálogo central. Folha inferior não é usada na tela da partitura do
  celular.
- As folhas devolvem valor por `Navigator.pop` (`showModalBottomSheet<T>`);
  as gavetas de hoje são estado da tela (`_optionsOpen`, `_trailDrawerOpen`)
  dentro de um `Stack`, fechadas pelo `PopScope`. Para os resumos, que
  **devolvem uma ação**, o caminho mais curto é uma rota modal própria
  (`showGeneralDialog` com transição lateral, ou um `PopupRoute`) que
  desenha a mesma casca.
- O layout largo e a biblioteca (retrato) continuam com folhas e diálogos
  como hoje: a regra é da partitura no celular. As funções `show…` recebem
  o modo, ou há duas entradas.
- Depois do U12 os compassos com erro ficam marcados na pauta: com o resumo
  na lateral, as marcas ficam **visíveis ao lado** — é o ganho principal
  aqui.

## O que fazer

### Parte 1 — tema

1. `buildAppTheme`: `ColorScheme` escrito à mão (`ColorScheme.light(...)`
   ou `fromSeed(...).copyWith(...)`): `primary: kAccent`, `onPrimary`
   branco, `primaryContainer: kAccentSoftBg`, `surface: kSurface`,
   `surfaceContainer*` nos beges (`kLibraryCardBg`, `kChipBg`),
   `outline: kBorder`, `outlineVariant: kBorderSoft`, `error: kBadColor`.
2. Temas de componente: `dialogTheme` (fundo `kSurface`, raio 16),
   `bottomSheetTheme`, `filledButtonTheme`, `textButtonTheme`,
   `switchTheme`, `sliderTheme`, `segmentedButtonTheme`, `snackBarTheme`.
3. Remover as cores forçadas que o tema passou a cobrir.

### Parte 2 — superfícies

4. Extrair a casca comum: `PhoneSidePanel` (véu, painel de 400 dp, título,
   fechar, corpo rolável). `PhoneOptionsDrawer` e `TrailDrawer` passam a
   usá-la.
5. `showPhoneSidePanel<T>(context, title:, builder:)`: rota modal com a
   mesma casca, que devolve `T`.
6. No celular: "Ir para o compasso", "Repetir um trecho", o resumo da
   etapa, o resumo do treino e a conclusão da trilha usam
   `showPhoneSidePanel`. No layout largo, continuam como hoje.
7. Layout, configurações gerais e monitor MIDI (cartões flutuantes): no
   celular, dentro da mesma casca, à direita (o monitor fica à direita
   também; hoje abre à esquerda).
8. Atualizar os testes de `trail_widgets_test.dart` (o resumo deixa de ser
   `BottomSheet` no celular) e o roteiro (`_popRoute` continua fechando a
   rota).

## Fora de escopo

- Tema escuro.
- O seletor de cor e a biblioteca (retrato): continuam com diálogo e tela
  cheia.
- Mudar o conteúdo de qualquer painel.

## Critérios de aceite

1. Teste: `buildAppTheme().colorScheme.primary == kAccent`.
2. `grep -rn "activeColor: kAccent\|activeTrackColor: kAccent" lib/` não
   acha nada.
3. Teste de widget (844×390): o resumo da etapa aparece como painel à
   direita — a metade esquerda da tela não é coberta por ele.
4. Teste de widget: "Ir para o compasso" devolve o compasso escolhido pelo
   painel lateral.
5. `just telas`: nas telas 19, 20, 34, 39 e 42 a pauta aparece à esquerda
   do painel; nas 06, 09 e 44 o diálogo tem fundo branco e botão azul; o
   botão principal tem a mesma cor nas telas 20, 27 e 34.
6. O "voltar" do Android fecha o painel aberto antes de sair da partitura.
7. `just analyze` e `just test` limpos; o roteiro das telas passa.

## Notas de execução

### Parte 1 — tema
- `kAppColorScheme` (escrito à mão: `primary` = `kAccent`, superfícies e
  contêineres nos beges da paleta, `error` = `kBadColor`) e temas de
  componente em `lib/ui/theme.dart` (diálogo branco de raio 16, folha, botões
  preenchido/texto/contornado, interruptor, controle deslizante, botão
  segmentado, snackbar e progresso). Saíram todos os `activeColor: kAccent` /
  `activeTrackColor: kAccent` e os `backgroundColor: kSurface` das folhas —
  inclusive os de `lib/mockup/` (o `grep` do critério 2 olha `lib/` inteiro).
- Efeito colateral a conferir no aparelho: `surfaceTint` virou transparente e
  o `ColorScheme` deixou de vir da semente, então qualquer widget que lia
  cores derivadas muda de tom.

### Parte 2 — superfícies
- `PhoneSidePanel` (casca: véu opcional, painel de até 400 dp — no máximo 60%
  da largura —, título e fechar) em `lib/ui/side_panel.dart`; `PhoneOptionsDrawer`
  e `TrailDrawer` passaram a usá-la.
- `showPhoneSidePanel<T>`: rota modal (`showGeneralDialog`, entra pela
  direita), **sem escurecer a pauta**: o toque na pauta e o "voltar" do
  Android fecham. `showSheetOrSidePanel` escolhe entre ela e a folha inferior;
  `sheetBody` dá a margem/rolagem só à folha.
- No celular (`_phoneLayout` em `main.dart`) usam o painel lateral: "Ir para o
  compasso", "Repetir um trecho" (`showLoopSheet`), o resumo da etapa, o
  resumo do treino e a conclusão da trilha. No layout largo continuam folhas
  (as funções ganharam `sidePanel`, padrão `false`).
- Layout, configurações gerais e monitor MIDI (cartões flutuantes): no
  celular entram pela direita numa casca igual (`_scorePanel`); o monitor,
  que abria à esquerda, abre à direita. Seguem **não modais** (a pauta
  continua à esquerda) e não ganharam o título da casca — cada um já traz o
  seu. O "voltar" agora também fecha o monitor (antes só layout e
  configurações).
- Diálogos centrais (teclado, atraso, confirmações, cor) ficaram como
  diálogos, como a regra do passo manda.
- Critérios 1–4 e 6 (a parte do "voltar" dos painéis-rota) e 7 passam. O 5
  (`just telas`: pauta à esquerda do painel; diálogos com fundo branco e botão
  azul) **não foi rodado** — é a conferência que mais falta neste passo.
