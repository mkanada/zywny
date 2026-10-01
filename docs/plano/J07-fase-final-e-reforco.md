# J07 — Fase final e reforço

**Repo:** zywny · **Depende de:** J05 (e usa J02) · **Decisão necessária:**
nenhuma

## Objetivo

Fechar a trilha: depois do último trecho, a música inteira com as duas
mãos no ritmo, a 50%, 75% e 100%. Quando o aluno reprova, o app o manda
treinar exatamente onde errou — blocos em volta dos compassos com erro,
sempre com um compasso bom de cada lado — antes de tentar de novo.

## Ler antes (só isto)

- [J00](J00-trilha-de-estudo.md): "Fase final", "Aprovação".
- `lib/trail/reinforcement.dart` e `lib/trail/stage_result.dart` (J02).
- `lib/trail/trail_controller.dart` e o resumo da etapa (J05).
- `lib/trail/trail_path.dart` (J01: ocorrência → compasso lógico).

## Contexto que você precisa

- As três etapas `final.50/75/100` já existem no plano (J03). Aqui elas
  passam a funcionar: intervalo = o caminho inteiro.
- `StageResult.badMeasures` vem em **ocorrências**; converta para compasso
  lógico pelo caminho antes de chamar `reinforcementBlocks`.
- O reforço é um **estado transitório do `TrailController`**, não etapas
  do plano e não persistido:
  - Reprovou na `final.X` → lista de blocos, cada um `pendente`.
  - Cada bloco roda como uma etapa comum: `realtime`, `ambas`, andamento
    X, intervalo do bloco, contagem e metrônomo. Aprova com 90%, pode ser
    pulado.
  - Com todos os blocos aprovados ou pulados, a `final.X` abre de novo.
  - Fechar a música descarta o reforço; ao voltar, a `final.X` está aberta
    para uma tentativa nova (que, se reprovar, gera reforço novo).
- Erro em quase todos os compassos → os blocos se fundem num só, que é a
  música inteira. Não há reforço útil: mostre só "tentar de novo" e a
  sugestão de refazer os trechos.
- Reprovar sem nenhum compasso com erro identificado não deve acontecer;
  se acontecer, mesmo tratamento: só "tentar de novo".
- A faixa mostra "Reforço 1/3 · compassos 6–9 · 75%". Na gaveta (J06), o
  grupo "Fase final" lista os blocos enquanto existirem.
- Aprovar `final.100` conclui a trilha: é o que a biblioteca marca (J09).

## O que fazer

1. `TrailController`: estado de reforço (blocos, andamento, índice atual),
   transições descritas acima.
2. Resumo da fase final reprovada: em vez de "tentar de novo", o botão
   principal é "treinar os trechos com erro (N)"; "pular" continua lá.
3. Faixa e gaveta mostrando o reforço.
4. Tela de conclusão ao aprovar `final.100` (simples: mensagem e voltar à
   biblioteca ou continuar em treino livre).
5. Testes de widget e de `TrailController`.

## Fora de escopo

- Guardar histórico de tentativas ou estatística entre sessões ("os
  compassos que este aluno mais erra ao longo dos dias") — a estatística é
  a da tentativa reprovada.
- Reforço dentro dos trechos comuns.
- Caminho com saltos (J08).

## Critérios de aceite

1. Teste: `final.50` reprovada com erros nos compassos lógicos 7 e 8 de 20
   → um bloco `[6-9]` a 50%; aprovado o bloco, a `final.50` reabre.
2. Teste: erros em 3 e 12 → dois blocos; pular o primeiro e aprovar o
   segundo → `final.50` reabre; o pulo do bloco **não** marca a `final.50`
   como pulada.
3. Teste: `final.75` aprovada → `final.100` abre, sem reforço.
4. Teste: blocos fundidos cobrindo a música inteira → sem reforço, só
   "tentar de novo".
5. Teste: descartar o controlador no meio do reforço e recriar → sem
   reforço, `final.X` aberta.
6. Teste: `final.100` aprovada → `TrailProgress.finalApproved` e tela de
   conclusão.
7. **(manual)** Hino 1 completo a 50%, errando de propósito dois compassos
   afastados: os dois blocos aparecem, cada um com os vizinhos certos.
8. `just analyze` e `just test` limpos.

## Notas de execução (J07, 2026-10-01)

Implementado: reforço transitório em `TrailController` (`startReinforcement`
a partir da final reprovada, `recordBlockDone`/`skipBlock`, etapa sintética
`reforco.N` com `isReinforcement`), plano com final (`includeFinal: true`
na tela), resumo com "Treinar os trechos com erro (N)" (`train`), tela de
conclusão da `final.100` e blocos no grupo "Fase final" da gaveta. Testes:
`test/trail_reinforcement_test.dart` (6: critérios 1–6) + widgets
(resumo-trem, conclusão, blocos na gaveta). `just analyze` e `just test`
limpos (176 testes, 1 manual pulado).

- Blocos rodam como etapa comum (realtime, ambas, degrau reprovado,
  contagem+metrônomo) com resumo próprio; pulo de bloco não marca a final;
  todos feitos reabrem a final. Sem reforço útil (peça inteira ou sem
  compassos) vale só "tentar de novo".
- Faixa mostra "Reforço 1/3 · compassos 6–9 · 75%"; fechar a música
  descarta (controlador refeito ao abrir).
- Manual no aparelho (critério 7): hino 1 a 50% errando dois compassos
  afastados, conferindo os dois blocos com os vizinhos.
