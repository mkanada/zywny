# J08 — Saltos no caminho: músicas com casas e vários ritornelos

**Repo:** zywny (pode tocar no `score_bridge` — ver abaixo) · **Depende
de:** J04, J07 · **Decisão necessária:** **D-SALTO** (abaixo), a resolver
com a medição do J01

## Objetivo

Liberar a trilha para as músicas cujo caminho sem repetições **não** é
contíguo na linha do tempo expandida: casas de 1ª/2ª vez (112 dos 600
hinos) e dois ou mais ritornelos seguidos. Até aqui essas músicas abrem só
no modo livre.

## Ler antes (só isto)

- [J00](J00-trilha-de-estudo.md): "Caminho".
- As notas de execução do [J01](J01-caminho-e-trechos.md) (quantos hinos
  têm salto e de que tipo) e do [J04](J04-passagem-unica.md).
- `lib/audio/score_audio_scheduler.dart` inteiro: `setLoop`, `pump`,
  `_segments` (âncoras antigas ainda audíveis) — o loop já é um salto do
  fim para o início do mesmo intervalo, sem falha no áudio.
- `lib/practice/practice_controller.dart`: `_restartLoop`, `_tick`.
- `score_bridge/lib/src/score_player.dart` (`seek`) e
  `score_bridge/lib/src/score_timeline.dart` (`view`, `isJump` — o que o
  player exibe numa ocorrência depois de salto).

## Contexto que você precisa

- Exemplo: `|: A B [1 C] :| [2 D] E`. Expandido: `A1 B1 C A2 B2 D E`.
  Caminho: `A1 B1 D E`, com salto entre o fim de `B1` e o início de `D`.
  Um trecho `[B, D]` precisa tocar `B1` e continuar em `D` sem buraco.
- **D-SALTO — duas formas de resolver:**
  - (a) **Salto no agendador**: generalizar o loop para uma lista de
    segmentos `[(startMs, endMs), …]` tocados em sequência; ao fim de um, o
    horizonte continua no início do próximo. As sessões recebem só os
    eventos dos segmentos; o controlador leva o `ScorePlayer` ao destino
    (`seek`) como `onLoopRestart` faz hoje. Custo: agendador, controlador,
    metrônomo (as batidas também saltam) e a conversão tecla → ms musical
    perto do salto.
  - (b) **Última passagem em vez da primeira**: para `|: … [1] :| [2]`, a
    última passagem (`A2 B2 D E`) **é contígua**. Trocar a escolha de
    ocorrências do caminho para "a passagem em que o compasso é seguido
    pela casa final" resolve as casas sem tocar no agendador. Não resolve
    introdução + ritornelo com casas (`X |: A [1 B] :| [2 C]` → `X` e
    `A2 C` não são vizinhos) nem dois ritornelos seguidos.
  - Recomendação: decidir pelos números do J01. Se (b) cobre quase todos
    os hinos com salto, faça (b) e deixe o resto no modo livre; senão, (a).
- Com (a), a intersecção de 1 compasso entre trechos continua valendo
  através do salto — é justamente o que o aluno precisa treinar (a volta
  da casa).
- A virada de página/visão do `ScorePlayer` depois de um salto segue a
  regra de `MeasureInfo.view`; confira que um `seek` para depois do salto
  exibe a página certa.

## O que fazer

1. Ler a medição do J01, resolver D-SALTO com o usuário, registrar na
   tabela de decisões do README.
2. Implementar a forma escolhida.
3. Remover a regra "trecho não atravessa salto" do `cutSegments` (J01) e o
   aviso de trilha indisponível para os casos agora cobertos (J05).
4. Rodar de novo a ferramenta de medição do J01: quantos hinos ainda
   ficam sem trilha, e por quê.

## Fora de escopo

- Tocar as repetições (estrofes).
- D.C., D.S., coda (nenhum hino tem; se uma partitura externa tiver, a
  trilha continua indisponível para ela).

## Critérios de aceite

1. Teste: caminho `A B D E` com salto antes de `D` → o trecho que cobre
   `B, D` toca `B1` e depois `D`, sem nenhum evento de `C` nem de `A2`
   agendado, nas três modalidades (espera, tempo real, ritmo).
2. Teste: no tempo real, um toque logo depois do salto casa com a nota
   certa de `D` (a conversão para ms musical respeita o salto).
3. Teste: o metrônomo não clica no intervalo saltado.
4. Teste: todos os testes de J01–J07 continuam passando.
5. **(manual)** Um hino com casas de 1ª/2ª vez (ex.: hino 10): o trecho
   que cruza a casa toca direto na casa de 2ª vez, a partitura acompanha,
   sem falha audível no salto.
6. A medição atualizada está nas notas, com o número de hinos sem trilha.
7. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
