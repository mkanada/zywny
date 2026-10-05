# Q06 — Conferência no teclado

**Repo:** zywny · **Depende de:** Q05 · **Decisão necessária:** não
(D-TRP-CONFERIR decidida: primeira vez por teclado + ao tocar no selo)

## Objetivo

Um fluxo curto que diz à pessoa qual TRANSPOSE ajustar, confere pelo MIDI
(ou de ouvido) que ela ajustou, e descobre de uma vez como aquele teclado
trata a própria transposição.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "O problema do MIDI do teclado" e o
  item "Conferência no teclado" em "Na tela".
- `lib/midi/piano_keyboard.dart` (`PianoKeyboardPainter`, para mostrar a
  tecla), `lib/midi/midi_device_manager.dart` (nome do dispositivo
  conectado), `lib/audio/latency_calibration.dart` (exemplo de fluxo que
  escuta `PlayedNote` com prazo), U17 (vocabulário) e U18 (visual).

## O que fazer

Uma folha (bottom sheet no celular, diálogo no desktop) com estados:

1. **Instrução**: "No seu teclado, ajuste o **TRANSPOSE para +3**." Ajuda
   curta e genérica: "Costuma ser um botão TRANSPOSE ou uma função no menu;
   veja o manual do seu teclado." Nada de caminho por marca.
2. **Toque o Dó central**: o teclado desenhado mostra Dó4. Escuta a
   próxima nota-on (prazo de 30 s; sem nota → "Não chegou nada do teclado.
   Ele está conectado?").
3. **Resultado**, com `p` = pitch recebido e `k` da transposição:
   - `p == 60 − k`: o teclado transpõe a saída e está certo. Guarda
     `out: true`. Pronto (ou vai ao 4).
   - `p == 60`: ambíguo. **Teste de ouvido**: o app toca Mi♭4 (60 − k) pelo
     próprio som e pergunta "Soou igual à sua tecla Dó?". Sim → `out:
     false`; Não → "Confira o TRANSPOSE: precisa ser +3" e volta ao 1. Se o
     app não tem som disponível (Web sem gesto, motor desligado), aceitar a
     palavra da pessoa ("Já ajustei") e guardar `out: false`.
   - outro valor `60 + d`: "Seu teclado parece estar em d (ex.: +2). Ajuste
     para +3."
     Guarda `out: true` (só quem transpõe a saída manda deslocado) e volta
     ao 1.
4. **Entrada MIDI** (só se a saída de som é o teclado, M03): o app manda
   ao teclado duas notas, uma de cada vez — a escrita (Dó4) e a soada
   (Mi♭4) — e pergunta "Qual soou igual à sua tecla Dó: a 1ª ou a 2ª?". A 1ª
   → o teclado transpõe a entrada (`in: true`); a 2ª → `in: false`.
5. Grava `out`/`in` em `AppSettings` pelo nome do dispositivo (Q05) e
   remonta o `PitchFrame`.

Quando abre sozinha: ao ligar a transposição ou abrir uma música
transposta, **se o teclado conectado ainda não foi conferido**. Depois, só
pelo selo (Q08). Sem teclado conectado: não abre; o selo mostra a instrução.
Quando o som é só do app (`appIsSound`): não abre — nada a ajustar.

## Fora de escopo

O detector de deslocamento e o lembrete de voltar a 0 (Q07). O selo e a
gaveta (Q08).

## Critérios de aceite

1. Testes de widget com MIDI falso nos três caminhos do passo 3 e nas duas
   respostas do passo 4; `AppSettings` guarda o resultado pelo nome do
   dispositivo.
2. Teclado já conferido: abrir outra música transposta não abre a folha.
3. Prazo sem nota mostra a mensagem e deixa tentar de novo.

## Notas de execução

(vazio)
