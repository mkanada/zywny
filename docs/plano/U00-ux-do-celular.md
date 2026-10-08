# U00 — UX do celular: índice da fase U

A fase **U** executa as sugestões de
[`docs/ux/sugestoes-ux-celular.md`](../ux/sugestoes-ux-celular.md), que
respondem aos achados altos e médios de
[`docs/ux/estudo-ux-celular.md`](../ux/estudo-ux-celular.md). As telas de
referência estão em `docs/telas/celular/` (46 fotos do app num celular
Android; o README de lá diz como refazer).

Quem executa um passo lê o `README.md`, **este arquivo**, a seção da
sugestão citada no passo e o arquivo do passo. Não precisa ler o estudo
inteiro.

## Princípios (valem para todos os passos)

1. **A pauta é do aluno.** Nada fica por cima do que ele precisa ler.
2. **O que a tela mostra é o que vale agora** — andamento, mão, acertos e
   número de compasso são os da etapa em curso, na conta do resultado.
3. **Sempre há um próximo passo**: a tela diz o que fazer e dá o atalho.

## Alvo e limites

- **Celular em paisagem** na partitura (`_buildPhoneBody`, largura menor que
  `kPhoneLayoutMaxWidth` = 1000) e **em retrato** na biblioteca. O layout
  largo (banco de testes do desktop, `build` de `lib/main.dart` a partir da
  L2505) **não muda** nesta fase, salvo quando o passo disser.
- A fase U não muda regra de trilha (J00) nem de treino (D-TREINO,
  D-RITMO): só o que a tela mostra e como se chega às coisas.
- `lib/main.dart` tem 2832 linhas. Widget novo vai em `lib/ui/`,
  `lib/trail/trail_widgets.dart` ou `lib/library/`; em `main.dart` fica a
  cola.
- Texto novo de interface é em português, frase com inicial maiúscula e sem
  jargão (ver [U17](U17-vocabulario.md)).

## Como conferir uma mudança de tela

Três níveis, do mais barato ao mais caro:

1. **Teste de widget** (`flutter test`), com os falsos de MIDI e de
   preferências de `test/widget_test.dart` L27-L47 (`_installFakeMidiAndPreferencesPlatforms`,
   L43). `_phone(tester)` (L73)
   põe a janela em 844×390. A `ScoreHomePage` com hino aberto **não** roda
   em `flutter test` (o Verovio é FFI): teste os widgets soltos
   (`TrailStrip`, `PhoneRail`, `showStageSummary`…), como
   `test/trail_widgets_test.dart` faz.
2. **Roteiro das telas** (`just telas`, ~4 min num emulador): roda o app de
   verdade e fotografa. O roteiro é
   `integration_test/telas_celular_test.dart`; um teclado MIDI falso
   (`_FakeKeyboard`) toca o que a etapa espera. Se o passo muda um rótulo ou
   um botão que o roteiro usa para navegar (`find.byTooltip('Mais opções')`,
   `find.text('Treino livre')`…), **o roteiro é atualizado no mesmo passo**.
   Emulador sem janela e sem gravar nada no AVD:
   `emulator -avd Medium_Phone_2 -read-only -no-window -no-audio &`.
3. **(manual)** no aparelho, com teclado de verdade — só onde o critério
   pedir.

As fotos de `docs/telas/celular/` são refeitas de uma vez no
[U19](U19-refazer-as-telas.md), não a cada passo. Durante um passo, grave as
fotos de conferência fora do repositório:
`TELAS_DIR=<diretório de scratch> just telas`.

## Fatos (medidos em 2026-10-02)

- Emulador `Medium_Phone_2`: 1080×2400 px, 411×914 dp. Em paisagem a área
  do Flutter tem ~24 dp a menos no topo (barra de status; a tela não usa
  modo imersivo).
- Tela da partitura no celular, de cima para baixo: barra do título
  (`kPhoneTitleBarHeight` = 40 dp), área da partitura; à direita, a barra
  lateral (`kPhoneRailWidth` = 84 dp). A faixa da trilha
  (`kTrailStripHeight` = 34 dp) é um `Positioned` **sobre** a área da
  partitura (`_buildPhoneBody`, `lib/main.dart` L2091-L2097).
- A página é gravada para a caixa da partitura (`_onBoxSize` L545,
  `_fittedPage` L360): mudar a altura da caixa em mais de 2% **regrava** o
  hino (~3,7 s no emulador). Por isso o que entra e sai da tela não pode
  mudar o tamanho da caixa.
- Notação no celular: `unit` = 12 (`kPhoneUnit`, `lib/layout_options.dart`
  L403), o topo do controle da gaveta (4,5–12). Cabe **um** sistema de
  ~4 compassos por página; o terço de baixo da caixa fica vazio.
- Hino 5 (o do roteiro): 56 ocorrências de compasso na música expandida e
  6 trechos de 5 compassos; cada trecho tem 12 etapas quando as duas mãos
  têm notas, e a fase final soma 3.
- `score_bridge/` vive neste repositório (subtree do bridge). Passo que mexe
  nele roda também `cd score_bridge && flutter test`.
- `test/native_sound_engine_test.dart` falhou uma vez na suíte completa e
  passou sozinho (disputa pelo dispositivo de áudio, não investigada). Se
  acontecer, rode-o isolado antes de concluir que quebrou algo.

## Decisões da fase

Estão na tabela **Decisões** do `README.md`, com a recomendação de cada uma:
D-FAIXA (U01), D-OUVIR (U03), D-SOM (U04), D-SELO (U05), D-VIRADA (U06),
D-CONTAGEM (U09), D-SISTEMAS (U10), D-MODOS (U11), D-ORDEM (U14). Passo com
decisão aberta **para e pergunta** antes de escrever código (regra 3 do
README).

## Achado → passo

| Achado | Gravidade | Passo |
| --- | --- | --- |
| A1 Sem teclado, a tela padrão é um beco | alta | U03 |
| A2 O som nasce desligado, e nada avisa | alta | U04 |
| A3 A faixa da trilha cobre a partitura e os painéis | alta | U01 |
| A4 A partitura não mostra o trecho da etapa | alta | U02 |
| A5 O selo de acertos não prevê o resultado | alta | U05 |
| A6 A virada de página esconde o que vem a seguir | alta | U06 |
| A7 A barra lateral mostra o que a etapa não usa | média | U07 |
| A8 A primeira nota acende na cor de "certa" | média | U08 |
| A9 A contagem cobre os compassos | média | U09 |
| A10 Sobra tela e falta música | média | U10 |
| A11 O modelo de modos da gaveta | média | U11 |
| B1 "Faltou 80%" | média | U05 |
| B2 Compassos com erro só em números | média | U12 |
| B3 Resumo do treino livre em milissegundos | média | U12 |
| B4 A trilha não mostra o todo | média | U13 |
| C1 A linha do hino corta o progresso | média | U13 |
| C2 Bolinha e número sem legenda | média | U13 |
| C3 A seta da ordenação | média | U14 |
| C4 A busca não explica o que achou | média | U14 |
| C5 Conectar o teclado | média | U15 |
| C6 O primeiro uso | média | U16 |
| D1 Vocabulário | média | U17 |
| E1 Dois visuais | média | U18 |
| E2 Quatro tipos de superfície | média | U18 |
| E3 Estado só por cor | média | U08, U13, U15 |

Os achados baixos do estudo (A12, A13, B5, D2–D4, E4) não têm passo.

## Passos

| Passo | Título | Depende de | Decisão | Status |
| --- | --- | --- | --- | --- |
| [U01](U01-faixa-fora-da-pauta.md) | A faixa da trilha sai de cima da pauta | — | D-FAIXA | concluído (critérios 3–5, no emulador, aguardando verificação) |
| [U02](U02-a-pauta-mostra-o-trecho.md) | A pauta mostra o trecho da etapa | — | — | concluído (critérios 2–5, no emulador, aguardando verificação) |
| [U03](U03-ouvir-o-trecho.md) | Ouvir o trecho, e o que fazer sem teclado | U01 | D-OUVIR | concluído (critérios 3–5, no emulador e no aparelho, aguardando verificação) |
| [U04](U04-som-ligado-e-indicador.md) | Som ligado por padrão e indicador | U01 | D-SOM | concluído (critérios 3–5, no emulador e no aparelho, aguardando verificação) |
| [U05](U05-selo-na-regua-do-resultado.md) | O selo e o resumo na mesma régua | U01 | D-SELO | concluído (critério 5, no emulador, aguardando verificação) |
| [U06](U06-virada-legivel.md) | Virada de página que deixa ler adiante | — | D-VIRADA | dispensado (D-VIRADA = c, como está) |
| [U07](U07-barra-lateral-da-trilha.md) | Barra lateral com os valores da etapa | U03 | — | concluído (critérios 4–5, no emulador, aguardando verificação) |
| [U08](U08-cores-do-destaque.md) | Cores do destaque: primeira nota, mão do app, legenda | — | — | concluído (sem o "×" da nota perdida, adiado; critérios 3–5, no emulador, aguardando verificação) |
| [U09](U09-contagem-fora-do-primeiro-compasso.md) | A contagem sai de cima do primeiro compasso | — | D-CONTAGEM | concluído (critérios 3–5, no emulador, aguardando verificação) |
| [U10](U10-aproveitar-a-tela.md) | Aproveitar a tela: imersivo, centro, dois sistemas | U01 | D-SISTEMAS | concluído (parte 1 no emulador, aguardando verificação; partes 2 e 3 sem mudança, por decisão) |
| [U11](U11-gaveta-de-opcoes.md) | Gaveta de opções: um seletor de modo, e o que vale na trilha | — | D-MODOS | concluído (critério 5, no emulador, aguardando verificação) |
| [U12](U12-resumos-legiveis.md) | Resumos: erros na pauta e frases no lugar de milissegundos | U02, U05 | — | concluído (critério 5, no emulador, aguardando verificação) |
| [U13](U13-progresso-a-vista.md) | Progresso à vista: gaveta, linha do hino e pontuação | — | — | concluído (critérios 6–7, no emulador e no aparelho, aguardando verificação) |
| [U14](U14-ordenar-e-buscar.md) | Biblioteca: ordenar e buscar | — | D-ORDEM | concluído (critério 6, no emulador, aguardando verificação) |
| [U15](U15-conectar-o-teclado.md) | Conectar o teclado: orientação e estado | — | — | concluído (critério 6, no emulador, aguardando verificação) |
| [U16](U16-primeiro-uso.md) | Primeiro uso: cartão de começo | U13, U15 | — | concluído (critério 5, no emulador, aguardando verificação) |
| [U17](U17-vocabulario.md) | Vocabulário das configurações | U15 | — | concluído (critério 4, no emulador, aguardando verificação) |
| [U18](U18-um-visual-so.md) | Um visual só: tema e superfícies | U12 | — | concluído (critérios 5–6, no emulador e no aparelho, aguardando verificação) |
| [U19](U19-refazer-as-telas.md) | Refazer as telas e conferir os achados | todos os U | — | concluído (fotos refeitas; achados conferidos na seção "Depois da fase U" do estudo) |
| [U20](U20-sobre-e-tutorial.md) | "Sobre o Zywny" e tutorial de primeiro uso | U16, U17 | — | concluído (código, testes e Web; aceite no aparelho pendente) |

Ordem sugerida: **U01 → U02 → U03 e U04 → U05** (os achados altos que não
dependem de teste com aluno) → U08 e U07 → U06 → U09, U10, U11 → U12 → a
biblioteca (U13 → U14, U15 → U16) → U17 → U18 → U19.

U13–U15 (biblioteca) não tocam na tela da partitura e podem ser feitos em
qualquer momento, em paralelo com o resto.

## Fora de escopo da fase U

- O layout largo (desktop e web).
- Regras da trilha, tolerâncias do treino, porcentagem de aprovação.
- Teste com alunos — o estudo diz o que só ele responde; a fase U deixa o
  app pronto para ele.
- Animações de conquista, sons de acerto. (O tutorial de primeiro uso estava
  aqui e foi pedido depois: [U20](U20-sobre-e-tutorial.md).)
- Os achados baixos do estudo.
