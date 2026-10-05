# Q07 — Lembrete de voltar ao normal e detector de deslocamento

**Repo:** zywny · **Depende de:** Q05 · **Decisão necessária:** não

## Objetivo

Evitar o erro mais provável da fase: o teclado ficar com o TRANSPOSE errado
— esquecido de ontem, ou não ajustado hoje.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "Lembrete de voltar ao normal" e
  "Detector de deslocamento" em "Na tela".
- `lib/practice/practice_controller.dart` (`_onNote` L473, `_wrongPitches`)
  e `lib/practice/practice_session.dart` (`NoteVerdict` L18, `PracticeStep`
  L50: o que é nota certa e nota errada em cada modo).

## O que fazer

1. **Detector** (classe pura `ShiftDetector`, em `lib/practice/`): recebe,
   para cada nota errada, a nota esperada mais próxima no momento (no modo
   espera, as notas do passo; no tempo real, as da janela) e a recebida.
   Se as últimas **N = 6** notas erradas têm todas a mesma distância
   `d ≠ 0` (|d| ≤ 12) e nenhuma nota certa entre elas, dispara uma vez por
   sessão. N é constante nomeada; ajustar no aceite manual (Q08).
2. Mensagem (faixa no topo da partitura, some sozinha em 8 s ou ao tocar):
   - música sem transposição: "Parece que o teclado está transposto em
     ±|d|. Ajuste o TRANSPOSE para 0.";
   - música transposta: "Parece que o TRANSPOSE está em X. Ajuste para +3."
     (X = valor pedido + d, conforme o `PitchFrame`).
   Vale para **toda** música, transposta ou não — é o caso de esquecer o
   TRANSPOSE ligado. Só funciona em teclado que transpõe a saída MIDI
   (`out: true` ou ainda não conferido): nos outros, o TRANSPOSE errado
   muda o som mas não o número que chega, e o casador não vê erro nenhum.
   Esse caso é do lembrete (passo 3). Num teclado ainda não conferido, o
   disparo do detector é também a prova de que ele transpõe a saída:
   guardar `out: true`.
3. **Lembrete de voltar a 0**: ao abrir uma música **sem** transposição
   logo depois de uma transposta (na mesma execução do app), e o teclado
   não transpõe a saída (`out: false` ou não conferido): "Se ajustou o
   TRANSPOSE para a música anterior, volte para 0." Com `out: true`, o app
   não avisa por suposição: o detector vê o deslocamento de verdade.
4. Lembrete ao sair: **não** fazer (no celular, sair do app não tem um
   momento confiável). Anotar a razão.

## Fora de escopo

Ler o TRANSPOSE do teclado por MIDI (fora da fase Q).

## Critérios de aceite

1. Testes do `ShiftDetector`: 6 erros a +3 disparam; uma nota certa no
   meio zera; erros espalhados não disparam; dispara só uma vez.
2. Teste de widget: música sem transposição com o teclado falso em +3 mostra
   a faixa em até 6 notas erradas.
3. Lembrete de voltar a 0 aparece só no caso do passo 3.

## Notas de execução

(vazio)
