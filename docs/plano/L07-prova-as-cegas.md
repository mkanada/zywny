# L07 — Prova às cegas e marca "de cor"

**Repo:** zywny · **Depende de:** L06 · **Decisão necessária:** nenhuma

## Objetivo

As três últimas etapas da trilha do decorar: a música inteira, em tempo
real, com a **partitura coberta**. Aprovada a 100% do andamento, o hino
ganha a marca **de cor**.

## Ler antes (só isto)

- [L00](L00-trilha-do-decorar.md): "Prova às cegas", "Aprovação".
- `lib/memo/memo_controller.dart` e a cola do L06 em `lib/main.dart`.
- `lib/main.dart` `_buildScoreArea` e o comentário sobre `_onBoxSize` em
  `build` (a área da partitura não pode mudar de tamanho).
- `lib/audio/metronome.dart` (as batidas, para o indicador visual).
- `lib/trail/trail_path.dart` (número do compasso lógico em `ms`).
- `lib/ui/phone_chrome.dart` (`PhoneCountersPill`).

## Contexto que você precisa

- A cobertura é um **widget por cima** da área da partitura, do mesmo
  tamanho dela. A partitura continua montada por baixo: não desmonte o
  `ScoreView` nem mexa no tamanho da caixa (dispararia re-render, e o
  player ainda vira as páginas para o resumo abrir no lugar certo).
- O que a cobertura mostra: número do compasso lógico atual ("Compasso 7
  de 20"), a batida (um ponto que acende no tempo, o 1 mais forte), e os
  contadores de acerto e erro que já existem. Nada de nota, pausa
  substituta, nota fantasma ou cor de veredito.
- Durante a contagem inicial a cobertura mostra a contagem.
- Sem revelação: o `PracticeController` roda sem colunas escondidas e sem
  `StandInController` (é o tempo real do J04, puro). Os destaques de
  veredito ficam por baixo da cobertura; limpe-os no fim.
- **Resumo**: porcentagem, compassos com erro, e "ver a partitura" — fecha
  a cobertura e deixa a partitura inteira à vista, sem iniciar nada.
- **De cor**: `cega.100` aprovada. Pulada não vale. O resumo dessa etapa
  comemora com uma linha, sem animação elaborada.
- A cobertura só aparece com a etapa armada ou rodando. Etapa `cega.*`
  selecionada e parada: partitura visível, com um aviso de que ela será
  coberta ao começar.

## O que fazer

1. `lib/memo/memo_blind_cover.dart`: o widget da cobertura, alimentado
   pela posição do agendador, pelas batidas e pelo caminho.
2. `MemoController`: executar `cega.*` (intervalo = caminho inteiro, sem
   sumiço), `deCor` no progresso.
3. Resumo com "ver a partitura"; linha de comemoração em `cega.100`.
4. Tirar o "em breve" do L06.
5. Testes de widget.

## Fora de escopo

- Reforço dos compassos errados; revisão em outro dia.
- Gravar ou reproduzir o que o aluno tocou.
- Biblioteca (L08).

## Critérios de aceite

1. Teste de widget: etapa `cega.50` rodando → a cobertura está por cima,
   mostra o compasso, e nenhuma nota da partitura aparece na imagem.
2. Teste: o número do compasso avança com a posição e é o do compasso
   **lógico** (anacruse não conta sozinha).
3. Teste: o tamanho da caixa da partitura não muda ao cobrir e descobrir
   (nenhum `renderScoreToVsb` a mais).
4. Teste: `cega.100` aprovada → `deCor` gravado; reprovada ou pulada →
   não.
5. Teste: "ver a partitura" no resumo → cobertura fora, nenhuma coluna
   escondida, nada tocando.
6. Teste: parar no meio da prova → cobertura fora, nada registrado.
7. **(manual, celular em paisagem)** Hino 1, prova a 50%: dá para se
   localizar só com o número do compasso e a batida? Anote o que faltou
   (a letra da estrofe, por exemplo) — é a informação para uma eventual
   segunda versão da cobertura.
8. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
