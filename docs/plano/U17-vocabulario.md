# U17 — Vocabulário das configurações

**Repo:** zywny · **Depende de:** U15 · **Decisão necessária:** nenhuma

## Objetivo

Os rótulos das configurações e dos diálogos falam a língua de quem estuda
piano, não a de quem programou o app. Só texto: nenhum comportamento muda.
Achado D1 (e o D2, de carona); sugestão D1.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a tabela da sugestão **D1** — ela é a
  especificação deste passo.
- Telas `07`, `08`, `18`, `43`, `44`.
- `lib/settings/general_settings_panel.dart`: `_rows` L138-L286,
  `_changeTrailN` L291-L305, `_ColorRow` L398-L439, `_SliderRow` L444-L491.
- `lib/practice/practice_tools.dart`: `_CalibrationDialogState.build`
  L205-L251.
- `lib/trail/trail_widgets.dart`: `TrailNSelector` L559-L604.
- `lib/main.dart`: os rótulos de `_buildOptionsDrawer` L2154-L2292 ("Usar o
  padrão da trilha", "Layout deste hino (avançado)", "Metrônomo (com som do
  app)").
- `lib/layout_panel.dart` L70-L100 (título e tooltips do painel).
- Quem depende dos textos: `test/settings_test.dart` (L196-L330),
  `test/widget_test.dart` (L58, L94-L106) e
  `integration_test/telas_celular_test.dart` (`'Som do app'`, `'Nota
  destacada'`, `'Latência do teclado'`, `'Painel do monitor MIDI'`, `'Mais
  compassos por trecho'`, `'Layout deste hino (avançado)'`,
  `'Configurações gerais'`).

## Contexto que você precisa

- A tabela da sugestão D1 tem 19 linhas: rótulo de hoje → rótulo novo. Siga
  a tabela; onde um rótulo novo não couber (linha de 360 dp, painel de
  360 dp de largura na partitura), encurte mantendo o sentido e registre nas
  notas.
- As ações à direita das linhas ("trocar", "escolher", "calibrar") são
  `Text` simples em `trailing`. Passam a ter inicial maiúscula e a cor de
  destaque (`kAccent`), peso 600 — para lerem como botão. A linha inteira
  continua sendo o alvo do toque.
- O seletor de saída do som (`SegmentedButton<SoundOutput>`) não tem rótulo:
  ganha "O som sai por" acima, e os segmentos viram "Celular" e "Teclado".
- "N próprio" aparece no diálogo de confirmação (`_changeTrailN`); "N" é
  nome de variável.
- O painel "Layout deste hino" é ferramenta de bancada (mostra pixels e
  milímetros). Aqui só muda o nome da entrada na gaveta e o título do
  painel; o conteúdo fica.
- O U15 já trocou "Dispositivo" por "Teclado MIDI" e os textos do seletor.
  Não refaça.
- Tooltips também são texto de interface (leitor de tela, e o roteiro das
  telas navega por eles).
- Não renomeie identificadores de código, chaves de preferência nem
  comentários: só o que aparece na tela.

## O que fazer

1. Aplicar a tabela em `general_settings_panel.dart`, `practice_tools.dart`
   (diálogo de ajuste do atraso), `trail_widgets.dart` (`TrailNSelector`),
   `main.dart` (gaveta) e `layout_panel.dart` (título).
2. Ações à direita com cara de botão (um widget pequeno, `_RowAction`, para
   não repetir estilo).
3. Rótulo "O som sai por" e segmentos "Celular"/"Teclado".
4. Atualizar os testes e o roteiro das telas com os textos novos.
5. Passar um `grep` nos termos antigos em `lib/` (fora de comentários) para
   conferir que nenhum ficou: "Soundfont", "soundfont" em texto de tela,
   "Program Change", "Monitor MIDI", "Latência", "halo", "Haste", "N
   próprio", "Dispositivo".

## Fora de escopo

- Reorganizar as configurações (ordem, seções, o que aparece por qual
  porta).
- O seletor de cor.
- Traduzir o app para outros idiomas.
- Mensagens de erro técnicas (`som: erro ao iniciar (…)`): ficam, são
  diagnóstico.

## Critérios de aceite

1. Todos os rótulos da tabela D1 estão como na coluna da direita (ou com o
   desvio anotado).
2. `grep -rnE "Soundfont do|Program Change|Monitor MIDI|Latência do
   teclado|Largura do halo|Haste de virada|N próprio" lib/ --include=*.dart
   | grep -v "^\S*:\s*///"` não acha texto de tela.
3. Teste de widget: no painel de configurações em 360 dp de largura nenhum
   título quebra em mais de duas linhas e nada estoura.
4. `just telas`: telas 07, 08, 18, 43 e 44 refeitas conferem; o roteiro
   passa.
5. `just analyze` e `just test` limpos.

## Notas de execução

- A tabela D1 foi aplicada sem desvios de texto em
  `general_settings_panel.dart`, `practice_tools.dart` (o diálogo agora é
  "Ajustar o atraso"; o botão do seletor do teclado também), `trail_widgets.dart`
  ("Compassos por trecho da trilha"), `main.dart` e `layout_panel.dart`.
- `_RowAction` (em `general_settings_panel.dart`): "Trocar", "Conectar" /
  "Trocar" e "Ajustar" em `kAccent`, peso 600. "O som sai por" ganhou rótulo
  e os segmentos viraram "Celular" e "Teclado".
- Além da tabela, para o critério 2 do passo (`grep` sem texto de tela):
  o painel "Monitor MIDI" virou "Teclas que chegam"; no layout largo, o
  tooltip "Monitor MIDI" virou "Ver as teclas que chegam", o do painel de
  layout "Ajustes da partitura" e o do botão de instrumentos "Trocar o timbre
  do teclado (usa o instrumento da partitura)" / "Voltar ao timbre do
  teclado". "Metrônomo (com som do app)" virou "Metrônomo (com som)" (o
  "som do app" deixou de existir). O subtítulo do timbre do piano diz só
  "padrão" (sem o nome TimGM6mb), como a tabela.
- A mensagem de erro "não consegui usar esse soundfont (…)" não mudou
  (diagnóstico, fora de escopo). Os nomes das fotos do roteiro
  (`08-configuracoes-mudar-o-padrao`, `44-calibrar-latencia`) também ficaram:
  o U19 refaz o conjunto.
- Testes e roteiro atualizados com os textos novos; o título "Som" aparece
  duas vezes (cabeçalho e linha), então os testes identificam a linha pelo
  subtítulo "o app toca a música".
- O critério 3 foi testado numa janela de 360 dp com a fonte de quadrados
  do teste (mais larga que a real): nenhum título passa de duas linhas.
  Critérios 1, 2, 3 e 5 passam; o 4 (`just telas`) não foi rodado.
