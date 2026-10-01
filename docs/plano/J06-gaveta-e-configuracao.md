# J06 — Tela: lista de etapas, pular, refazer e configuração de N

**Repo:** zywny · **Depende de:** J05 · **Decisão necessária:** nenhuma

## Objetivo

Dar ao aluno a visão do todo e o controle: uma gaveta com todos os trechos
e etapas (aprovadas, puladas, trancadas), a possibilidade de refazer uma
etapa antiga, e a configuração do número de compassos por trecho — geral e
por música.

## Ler antes (só isto)

- [J00](J00-trilha-de-estudo.md): "Corte em trechos", "Pular e refazer",
  "Interface".
- `lib/trail/trail_controller.dart` e `lib/trail/trail_widgets.dart` (J05).
- `lib/ui/phone_chrome.dart` L363-L492 (`PhoneOptionsDrawer` — o padrão
  visual de gaveta) e as linhas `PhoneToggleRow`/`PhoneSliderRow`/
  `PhoneActionRow`.
- `lib/settings/general_settings_panel.dart` (onde entra o N geral).
- `lib/main.dart` `_buildOptionsDrawer` L1503 (onde entra o N da música) e
  o `PopScope` em `build` L1801 (o "voltar" fecha gavetas primeiro).

## Contexto que você precisa

- A gaveta abre com um toque na faixa da trilha. Em paisagem no celular
  ela é uma coluna lateral rolável, como a gaveta de opções; o "voltar" do
  aparelho tem de fechá-la (acrescente ao `canPop` do `PopScope`).
- Um hino de 16 compassos com N = 5 tem 4 trechos e 51 etapas. A lista
  **agrupa por trecho**: cada trecho é uma linha ("Trecho 2 · compassos
  5–9 · 7/12") que expande para as etapas. O trecho da etapa atual abre
  expandido; a fase final é o último grupo.
- Estados visuais: aprovada (com a melhor %), pulada (marca própria, sem
  cor de erro), atual, trancada. Tocar numa etapa aberta a seleciona na
  faixa e fecha a gaveta; trancada não responde.
- N por música: seletor (3 a 20, ou campo numérico — o J00 não fixa
  máximo; limite o controle ao número de compassos lógicos da música) com
  a opção "usar o padrão (N)". N geral: nas configurações gerais.
- Mudar o N **efetivo** de uma música com progresso (por qualquer um dos
  dois caminhos) invalida a trilha dela:
  - Pela configuração da música: diálogo "Isto reinicia a trilha deste
    hino" antes de aplicar.
  - Pela configuração geral: afeta todas as músicas sem N próprio. O
    diálogo avisa uma vez; a trilha de cada música é descartada quando ela
    for aberta (o J03 já descarta progresso com `n` diferente).
- "Reiniciar trilha" é uma ação da gaveta, com confirmação.

## O que fazer

1. Gaveta da trilha (widget em `lib/trail/trail_widgets.dart`), ligada ao
   `TrailController`.
2. Selecionar etapa aberta para refazer; o resumo de uma etapa refeita
   oferece "voltar à etapa atual".
3. "Pular etapa" também na gaveta, para a etapa atual.
4. N da música na gaveta de opções; N geral em
   `general_settings_panel.dart`; diálogos de confirmação; "Reiniciar
   trilha".
5. Testes de widget.

## Fora de escopo

- Fase final e reforço (J07) — o grupo "Fase final" aparece na lista, mas
  quem o faz funcionar é o J07.
- Biblioteca (J09).

## Critérios de aceite

1. Teste de widget: a gaveta lista os trechos com contagem "feitas/total";
   o trecho atual vem expandido; etapa trancada não é selecionável.
2. Teste de widget: selecionar uma etapa aprovada, refazer com nota pior →
   continua aprovada com a melhor %; com nota melhor → a % sobe.
3. Teste de widget: mudar o N da música com progresso → diálogo; cancelar
   mantém tudo; confirmar zera a trilha e refaz o corte.
4. Teste de widget: "usar o padrão" volta ao N geral.
5. Teste de widget: "Reiniciar trilha" zera só aquele hino.
6. **(manual, celular em paisagem)** A gaveta rola bem com 50+ etapas e o
   "voltar" do aparelho a fecha antes de sair da partitura.
7. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
