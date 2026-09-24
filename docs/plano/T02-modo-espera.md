# T02 — Modo espera + escolha de mão + app toca a outra

**Repo:** zywny · **Depende de:** T01, K04, M01 · **Decisão necessária:** não

## Objetivo

A primeira experiência de treino completa: o aluno escolhe a mão (direita,
esquerda, ambas), o app toca a outra mão, a partitura **para** em cada acorde
da mão do aluno até ele acertar, e as notas mudam de cor (certa/errada).

## Ler antes (só isto)

- `lib/practice/practice_session.dart` (T01).
- `lib/audio/score_audio_scheduler.dart` e `AudioPlaybackClock` (K04).
- `score_bridge/lib/src/score_controller.dart`: API de cor por id (procure
  `setColor`/`highlight`/`clearHighlights` — confira os nomes reais com
  `grep -n "void " score_bridge/lib/src/score_controller.dart`).
- `lib/main.dart` `build` e a barra do Play.

## Contexto que você precisa

- **Relógio no modo espera**: o `AudioPlaybackClock` ganha um "freio": antes
  de cruzar o `onMs` do próximo passo pendente, a posição **para** ali (o
  clock devolve `min(posição, onMs do passo pendente)`) e o agendador **não
  agenda** além desse ponto (os eventos da outra mão também esperam). Quando
  o passo conclui, nova âncora a partir daquele `onMs` e segue. Isso é o
  C01 critério 3 (posição parada) usado de verdade.
- Eventos da mão do app que começam **no mesmo instante** do passo do aluno
  tocam quando o aluno acerta (juntos), não antes.
- Filtro de mão no agendador: `track.startingIn(..., staves: appStaves)`.
  Com "ambas as mãos" o app não toca nada (só metrônomo, T04).
- Cores (defina constantes num lugar só): esperado agora = cor de destaque
  atual (amarelo do player); certo = verde; errado = vermelho **piscando** na
  nota esperada mais próxima (a nota errada não existe na partitura);
  concluído = volta à cor normal com fade. Use as animações do
  `ScoreController` (release com duração) — não crie outro motor.
- Nota errada também pode ser mostrada no teclado desenhado de M01 (vermelho
  na tecla tocada), o que é mais claro que na partitura.
- Passo com mais de uma pauta ("ambas"): todas as notas das duas mãos no
  mesmo onset formam um passo (T01).
- Piano digital: o aluno ouve o próprio teclado; o app só toca a outra mão.
  Controlador sem som: M02 (monitor) ligado.
- Botões: Play vira "Praticar" quando um dispositivo MIDI está conectado
  e o modo treino está ativo; seletor de mão ao lado.

## O que fazer

1. Modo treino na UI (mão, iniciar/parar), `PracticeController` que liga
   `MidiInputService` → `WaitModeSession` → cores + freio do relógio +
   agendador filtrado.
2. Teste de widget com `FakeMidiInput` e `FakeSoundEngine`: tocar as notas
   certas avança a posição do player; errada não avança.

## Fora de escopo

- Tempo real e pontuação (T03). Loop/metrônomo (T04).

## Critérios de aceite

1. Teste de widget do item 2 verde.
2. **(manual, Linux, VMPK ou teclado)** Gymnopédie mão direita: o app toca a
   esquerda, espera cada nota da direita, cores corretas; nota errada
   aparece em vermelho e não avança.
3. **(manual)** Virada de página acontece normalmente no modo espera
   (inclusive nas repetições).
4. `just analyze` e `just test` limpos.

## Notas de execução

(preencher)
