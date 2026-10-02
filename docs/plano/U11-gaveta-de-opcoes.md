# U11 — Gaveta de opções: um seletor de modo, e o que vale na trilha

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** D-MODOS

## Objetivo

A gaveta ⋯ mostra só o que tem efeito no modo em que o aluno está, e os
quatro modos do treino livre são escolhidos num controle só. Achado A11;
sugestão A11.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A11**.
- Telas `14`, `15`, `16` (gaveta na trilha), `24` e `40` (no treino livre;
  na 40, "Tempo real" ligado com o seletor em "Espera").
- `lib/ui/phone_chrome.dart`: `PhoneOptionsDrawer` L376-L505,
  `PhoneToggleRow` L508-L539, `PhoneActionRow` L595-L635.
- `lib/ui/widgets.dart`: `Segmented<T>` L8 em diante.
- `lib/main.dart`: `_trainingMode` L222 e `_practiceMode` L228-L229,
  `_setTrainingFromDrawer` L1877-L1887, `_trainingPillText` L1943-L1960,
  `_buildOptionsDrawer` L2154-L2292, `_canTrain` L352-L353.
- `lib/practice/practice_controller.dart`: `enum PracticeMode` L27.
- `test/settings_test.dart` L253-L293 (a gaveta no celular, sem hino) e
  `test/widget_test.dart` L184-L252.
- `integration_test/telas_celular_test.dart`: `_openOptions`,
  `_optionsItem`, `_toggle` e os pontos que os usam.

## Contexto que você precisa

- Hoje o modo do treino livre é a combinação de dois estados:
  - `_trainingMode` (o seletor "Ouvir | Espera"): `false` = ouvir;
  - `_practiceMode` (`wait`, `realtime`, `rhythm`), mudado por dois
    interruptores, "Tempo real" e "Ritmo", que se desligam um ao outro.
  Com `_trainingMode == true` e `_practiceMode == realtime`, o seletor
  continua mostrando "Espera".
- `_setTrainingFromDrawer` tem efeitos de carona: ao ligar o treino, a mão
  sai de "Ambas" para "Direita" e o andamento vai a 80%; ao desligar, volta
  a "Ambas" e 100%. Preserve-os na troca Ouvir ↔ qualquer modo de treino,
  mas **não** ao trocar entre os três modos de treino.
- `_practiceMode` é configuração geral gravada (`AppSettings`);
  `_trainingMode` não é gravado.
- Na trilha, Modo, Mão e Andamento não têm efeito (a etapa manda), mas são
  as três primeiras coisas da gaveta. O alternador "Treino livre" / "Voltar
  à trilha" está abaixo da dobra em telas de 360 dp de altura.
- Com a etapa ou o treino rodando, os interruptores de modo ficam
  desabilitados (`onChanged: _practice != null ? null : …`). O seletor novo
  herda isso.
- "Voltar à biblioteca" (L2285-L2289, o último item) repete a seta da barra do título.
- A gaveta tem 400 dp de largura: quatro segmentos de ~85 dp cabem com
  rótulos curtos ("Ouvir", "Espera", "Tempo real", "Ritmo").

## O que fazer

1. `enum StudyMode { listen, wait, realtime, rhythm }` (em
   `lib/practice/`), com a conversão de e para (`_trainingMode`,
   `_practiceMode`). Teste da ida e volta.
2. `PhoneOptionsDrawer`: o seletor passa a ser `Segmented<StudyMode>`; sob
   ele, uma linha de explicação do modo escolhido:
   - Ouvir — "O app toca; você acompanha."
   - Espera — "A música espera você acertar a nota."
   - Tempo real — "A música não espera; cada nota é avaliada."
   - Ritmo — "Qualquer tecla vale; só o tempo é avaliado."
3. Tirar os interruptores "Tempo real" e "Ritmo" de `_buildOptionsDrawer`.
   "Metrônomo" e "Repetir um trecho" ficam.
4. `PhoneOptionsDrawer` ganha `trailMode`: com trilha ativa, a gaveta abre
   com a seção TRILHA (o alternador "Treino livre") e **não mostra** Modo,
   Mão, Andamento, a seção TREINO nem "Repetir um trecho". No treino
   livre, mostra tudo, com "Voltar à trilha" no topo.
5. Tirar "Voltar à biblioteca" da gaveta.
6. `_trainingPillText` continua valendo (ele já descreve o modo).
7. Atualizar os testes que tocam nos interruptores e o roteiro das telas
   (`find.text('Espera')`, `_toggle('Tempo real (a música não espera)')`
   viram um toque no segmento).

## Fora de escopo

- Mudar o que cada modo faz, ou os efeitos de carona de mão e andamento.
- O painel de opções do layout largo.
- Vocabulário das configurações gerais (U17).

## Critérios de aceite

1. Teste: `StudyMode` ↔ (`_trainingMode`, `_practiceMode`) nas quatro
   combinações.
2. Teste de widget: escolher "Tempo real" deixa só esse segmento marcado e
   mostra a explicação dele; não existe mais interruptor "Tempo real".
3. Teste de widget: com `trailMode`, a gaveta não contém "MODO", "MÃO" nem
   "ANDAMENTO", e o alternador da trilha está visível sem rolar em 640×360.
4. Teste de widget: trocar de Espera para Ritmo não mexe em mão nem em
   andamento; trocar de Ouvir para Espera mexe como hoje.
5. `just telas`: as telas 14 e 40 refeitas conferem com 3 e 2.
6. `just analyze` e `just test` limpos; o roteiro das telas passa.
