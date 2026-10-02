# U08 — Cores do destaque: primeira nota, mão do app, legenda

**Repo:** zywny (`lib/` + `score_bridge/`) · **Depende de:** — ·
**Decisão necessária:** nenhuma

## Objetivo

Cada cor na pauta quer dizer uma coisa só, do primeiro instante da etapa ao
último, e o aluno tem onde consultar o que cada uma quer dizer. Achado A8 e
parte do E3; sugestão A8.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A8**.
- Telas `32` (primeiro acorde verde, contador em 0), `37` (verde durante a
  contagem), `33` (mão esquerda no mesmo azul da direita; nota fantasma
  laranja).
- `lib/practice/practice_colors.dart` (inteiro, 35 linhas).
- `lib/main.dart`: `_startTrailStage` L788-L865 — o `player.seek` de L818,
  o `player.play()` de L854 e a cor de L857 —; `_togglePractice`
  L1190-L1242 (mesma ordem: `seek` L1209, `play` L1233, cor L1236);
  `_endTrailRun` L992-L1005; `_onSettingsChanged` L428-L433.
- `score_bridge/lib/src/score_player.dart`: `highlightColor` L208, os dois
  pontos que a usam (L381, no avanço, e L421, no `seek`).
- `lib/practice/practice_controller.dart`: `_onVerdict` L588-L638.
- `lib/practice/hand.dart` (`studentStaves`, `appStaves`).
- `lib/music/performance_track.dart` L11-L39 (`SoundEvent.id`, `staff`,
  `tied`).
- `lib/trail/trail_widgets.dart`: `TrailDrawer.build` L350-L432.

## Contexto que você precisa

- Seis cores têm significado no treino:

  | Cor | Constante | Significa |
  | --- | --- | --- |
  | azul | `kPracticePendingColor` | esperada agora |
  | verde | `kPracticeCorrectColor` (= destaque da reprodução) | certa |
  | âmbar | `kPracticeOffBeatColor` | fora do tempo |
  | vermelho | `kPracticeWrongColor` | errada (pisca na esperada mais próxima) |
  | cinza | `kPracticeMissedColor` | perdida |
  | laranja | `kDefaultGhostColor` (score_bridge) | a tecla errada, como nota fantasma |

  A legenda só existe, e em parte, nas configurações (tela 07).
- **Defeito da primeira nota.** `player.seek` (L818) acende as notas do
  instante de partida com a `highlightColor` daquele momento — a da
  reprodução, verde. A cor de "esperada" só é aplicada depois do `play()`
  (L857). O mesmo em `_togglePractice`.
- **Mão do app.** O `ScorePlayer` acende **todas** as notas do instante com
  uma cor só. Numa etapa de uma mão, as notas da outra (que o agendador
  toca: `hand.appStaves`) ficam no azul de "toque esta".
- O `ScorePlayer` não sabe de pautas; quem sabe é o zywny
  (`PerformanceTrack`: id → `staff`). Notas ligadas: a cadeia acende junta
  (`mergeTies`) e os ids da continuação estão em `SoundEvent.tied`.
- A nota perdida hoje é só um cinza que some em 500 ms
  (`kPracticeMissedHold`).

## O que fazer

1. **Primeira nota.** Em `_startTrailStage` e `_togglePractice`, definir
   `player.highlightColor = _settings.practicePendingColor` **antes** do
   `player.seek`. Conferir que `_endTrailRun`/`_endPractice` devolvem a cor
   da reprodução (já fazem).
2. **Mão do app.** `ScorePlayer` ganha `Color? Function(String id)?
   highlightColorOf` (consultado nos dois pontos que usam `highlightColor`;
   `null` → `highlightColor`). O zywny monta o conjunto de ids das pautas
   do app (com as cadeias de ligadura) e devolve um cinza
   (`kPracticeAppHandColor`, novo em `practice_colors.dart`, mais claro que
   o de perdida) para eles. Sem treino, ou com `Hand.ambas`, o retorno é
   `null`.
3. **Legenda.** Widget `PracticeLegend` (uma linha de bolinha + palavra:
   esperada, certa, fora do tempo, errada, perdida), com as cores **de
   agora** (`AppSettings`). Entra no rodapé da gaveta da trilha, acima de
   "Reiniciar trilha", e no resumo do treino livre.
4. **Não só cor.** A nota perdida ganha um "×" pequeno sobre a cabeça
   enquanto o cinza dura (overlay por id, como no U02; se o custo for
   alto, registre e deixe para o U12).
5. Testes: (a) `score_bridge` — `highlightColorOf` vence `highlightColor`
   no avanço e no `seek`; (b) zywny — o conjunto de ids da mão do app para
   `Hand.direita`/`esquerda`/`ambas` num fixture de `PerformanceTrack`; (c)
   widget — `PracticeLegend` mostra os cinco rótulos.

## Fora de escopo

- Mudar as cores padrão ou o seletor de cor.
- A contagem (U09 cuida de nada acender durante ela).
- Paleta para daltônicos (as cores continuam configuráveis).

## Critérios de aceite

1. Teste (`score_bridge`): com `highlightColorOf` devolvendo cinza para um
   id, `controller.colorOf(id)` é cinza depois do `seek` e depois de
   avançar; os outros ids ficam com `highlightColor`.
2. Teste: ids da mão do app corretos nos três casos de `Hand`.
3. `just telas`: na tela 32 o primeiro acorde da mão direita está **azul**;
   a mão esquerda, cinza. Na 33, idem.
4. `just telas`: a gaveta da trilha (31) mostra a legenda sem empurrar
   "Reiniciar trilha" para fora da tela em 411 dp de altura.
5. Fora do treino (tela 23, tocando) o destaque continua na cor da
   reprodução, nas duas mãos.
6. `cd score_bridge && flutter test`, `just analyze` e `just test` limpos.

## Notas de execução

- **Primeira nota:** `_paintForPractice` (em `lib/main.dart`) põe a cor de
  "esperada" **antes** do `seek`, na etapa e no treino livre.
- **Mão do app:** `ScorePlayer.highlightColorOf` (score_bridge) recebe o id
  **da cena** (o `-rend<N>` já resolvido por `sceneIdOf`, senão a segunda
  passagem de um compasso repetido escaparia do cinza). `appHandNoteIds`
  (`lib/practice/app_hand.dart`) devolve os ids das pautas do app com as
  ligaduras; `kPracticeAppHandColor` é o cinza claro novo.
- **Legenda:** `PracticeLegend` (`lib/ui/practice_legend.dart`) no rodapé da
  gaveta da trilha (`TrailDrawer.footer`) e no resumo do treino livre
  (`showPracticeSummary(legend:)`).
- **"×" da nota perdida (item 4): não feito.** Exige overlay por id de
  notas, com tempo de vida; o passo permitia adiar para o U12, e é lá que
  ele entra.
- O `score_player_test.dart` do bridge é pulado inteiro sem o corpus; o
  teste novo (`score_bridge/test/highlight_color_of_test.dart`) usa só o
  fixture do repositório e roda.
- Critérios 1, 2 e 6 passam. 3–5 (`just telas`) não foram rodados; a
  altura da legenda na gaveta em 411 dp não foi conferida.
