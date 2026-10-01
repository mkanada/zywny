# J00 — Trilha de estudo: especificação e índice da fase J

A **trilha** transforma o estudo de uma música num jogo de fases: a música é
cortada em trechos curtos que se sobrepõem, cada trecho passa por uma
sequência fixa de etapas, e a etapa seguinte só abre quando a anterior foi
aprovada (ou pulada, com registro). No fim vem a música inteira.

Este arquivo é a especificação (decidida com o usuário em 2026-10-01) e o
índice dos passos J01–J09. Quem executa um passo lê o `README.md`, **este
arquivo** e o arquivo do passo.

## Vocabulário

| Termo | Significado |
| --- | --- |
| **caminho** | A música sem repetições: cada compasso uma vez, na ordem em que se lê, usando a casa de 2ª vez. É uma lista de ocorrências de `ScoreTimeline.measures` |
| **compasso lógico** | Unidade de contagem do corte. Um compasso incompleto (anacruse) não conta sozinho: gruda no vizinho |
| **trecho** | Intervalo de N compassos lógicos seguidos do caminho |
| **fase** | Tipo de exercício: notas da direita, notas da esquerda, notas juntas, ritmo da direita, ritmo da esquerda, tudo junto no ritmo |
| **degrau** | Andamento de uma fase com tempo: 50%, 75% ou 100% do original |
| **etapa** | Um trecho × uma fase × (um degrau, se houver). É a unidade que se aprova, pula e guarda |
| **fase final** | A música inteira (o caminho todo), tudo junto no ritmo, nos três degraus |
| **reforço** | Blocos montados em volta dos compassos errados depois de reprovar na fase final |

## Regras

### Corte em trechos

- N = compassos lógicos por trecho. Mínimo 3, sem máximo prático (20 é
  válido). Valor geral em `AppSettings`, padrão **5**; cada música pode ter o
  seu em `HymnSettings`.
- Trechos vizinhos compartilham **1** compasso lógico. Avanço = N − 1.
- Com M compassos lógicos, os trechos começam em 0, N−1, 2(N−1), … enquanto
  o início for menor que M − 1. O último vai até o fim e pode ficar **menor
  que N** (trecho curto, mínimo 2: o compartilhado e um novo). Se M ≤ N, há
  um trecho só.
  - M = 8, N = 3 → `[0-2] [2-4] [4-6] [6-7]`.
  - M = 7, N = 3 → `[0-2] [2-4] [4-6]`.
- A anacruse (compasso incompleto no início) gruda no compasso 1.
- Sem repetições: ver "Caminho" abaixo.
- Mudar N numa música que já tem progresso pede confirmação e **zera a
  trilha** daquela música.

### Etapas de um trecho (nesta ordem)

| # | Fase | Modo (`PracticeMode`) | Mão (`Hand`) | Andamento | O que soa |
| --- | --- | --- | --- | --- | --- |
| 1 | Notas da direita | `wait` | `direita` | livre (espera) | aluno + app toca a esquerda |
| 2 | Notas da esquerda | `wait` | `esquerda` | livre (espera) | aluno + app toca a direita |
| 3 | Notas juntas | `wait` | `ambas` | livre (espera) | só o aluno |
| 4–6 | Ritmo da direita | `rhythm` | `direita` | 50%, 75%, 100% | piano mágico + app toca a esquerda |
| 7–9 | Ritmo da esquerda | `rhythm` | `esquerda` | 50%, 75%, 100% | piano mágico + app toca a direita |
| 10–12 | Tudo junto no ritmo | `realtime` | `ambas` | 50%, 75%, 100% | só o aluno |

- Nas etapas com tempo (4–12 e a fase final): **1 compasso de contagem
  inicial e metrônomo ligado**, sempre, independentemente da configuração do
  modo livre.
- Trecho em que uma mão não tem nota nenhuma (ou partitura de pauta única):
  as etapas daquela mão **e** as de "juntas"/"tudo junto" duplicadas não são
  geradas — sobra notas + ritmo (3 degraus) da mão que existe. Não contam
  como puladas.
- Um trecho só abre quando todas as etapas do anterior estão aprovadas ou
  puladas.

### Fase final

- Caminho inteiro, `realtime`, `ambas`, três etapas: 50%, 75%, 100%.
- Abre depois do último trecho.
- **Reprovou** → o app monta o reforço com os erros dessa tentativa:
  1. Compassos lógicos com algum erro, vizinhos entre si, viram um bloco.
  2. Cada bloco ganha um compasso sem erro antes e um depois (quando
     existem).
  3. Bloco com menos de 3 compassos cresce até 3 (para a frente; no fim da
     música, para trás).
  4. Blocos que se tocam ou se sobrepõem se fundem.
- Cada bloco é treinado com tudo junto no ritmo, **no degrau em que
  reprovou**, até 90%. Depois disso a tentativa da fase final abre de novo.
- Os blocos do reforço não são guardados: valem só até a próxima tentativa
  da fase final (fechar a música descarta).

### Aprovação

- **90% de acertos, fixo.** Uma passagem basta.
- Modo espera: acerto = **passo** (nota ou acorde) completado sem nenhuma
  tecla errada enquanto estava pendente. Precisão = passos de primeira /
  passos do trecho. Recomeço do acorde por falta de simultaneidade
  (`kWaitChordWindowMs`) não é erro.
- Tempo real: acerto = veredito `correct`. `early`, `late`, `wrong` e
  `missed` são erro. Precisão = `correct / total` (o `PracticeReport.accuracy`
  de hoje).
- Ritmo: acerto = onset `correct`. `early`, `late`, `missed` **e `extra`**
  são erro: precisão = `correct / (total + extra)`. (Sem isso, bater teclas
  sem parar aprovaria.)
- Janelas de tolerância: as que já existem (D-TREINO, D-RITMO). Não mudam.

### Pular e refazer

- Pula-se **uma etapa por vez** (a atual). Fica marcada `pulada`.
- Qualquer etapa já aberta pode ser refeita. Guarda-se a **melhor**
  porcentagem; refazer nunca tira a aprovação. Pulada que depois passa vira
  `aprovada`.
- Blocos do reforço e degraus da fase final também podem ser pulados.

### Interface (celular em paisagem é o alvo)

- A trilha é a tela padrão da música. Os modos livres de hoje (espera,
  tempo real, ritmo, loop A-B, escolha de mão, andamento) continuam, num
  menu secundário, e **não** alteram a trilha.
- Durante a etapa: uma faixa fina na partitura ("Trecho 2/6 · Notas
  juntas"). Um toque abre a lista completa numa gaveta.
- Fim da passagem: resumo com a porcentagem e os compassos com erro.
  Aprovado: "próxima etapa" e "repetir". Reprovado: "tentar de novo" e
  "pular".
- A biblioteca mostra o progresso de cada hino (etapas concluídas / total)
  e uma marca quando a fase final a 100% foi aprovada.

### Dados

- Um aluno por aparelho, `SharedPreferencesAsync`, sem perfis nem
  sincronização. Chave pelo número do hino: a trilha persiste para os hinos
  da biblioteca.
- 90% e os degraus 50/75/100 são constantes do código, não configuração.

## Caminho: a música sem repetições

Medido nos 600 hinos de `assets/hinos/` em 2026-10-01 (`grep` no MusicXML):

| Fato | Hinos |
| --- | --- |
| Têm ritornelo (`<repeat>`) | 540 |
| Têm casas de 1ª/2ª vez (`<ending>`) | 112 |
| Têm D.C., D.S., segno ou coda | 0 |
| Têm algum compasso `implicit="yes"` | 316 |
| Têm duas partes de uma pauta cada (P1, P2) | 600 |

- O hino típico é **introdução + `|: corpo :|` tocado 3 vezes** (as
  estrofes). Ex.: hino 1, introdução de 4 compassos e ritornelo do compasso
  5 ao 20 com `times="3"`. Por isso "sem repetições" não é detalhe: quase
  toda música da biblioteca repete.
- `ScoreTimeline.measures` é a música **expandida** (uma `MeasureInfo` por
  ocorrência, com `pass` e `isJump`). O caminho escolhe, para cada compasso,
  a **primeira ocorrência**, e descarta os compassos de casas que não são a
  última.
  - Sem D.C./D.S., a ordem das primeiras ocorrências é a ordem do documento.
  - Casa não final: num salto **para a frente** (`isJump`, compasso nunca
    tocado antes), os compassos do documento entre a ocorrência anterior e
    o destino são a casa descartada.
- **Continuidade**: um intervalo do caminho só pode ser tocado pelo
  agendador de hoje se as ocorrências forem vizinhas em
  `ScoreTimeline.measures` (ms contíguos). `X |: A B :|` dá `X A1 B1`,
  contíguo. `|: A B [1 C] :| [2 D]` dá `A1 B1 D`, com um **salto** entre B1
  e D. Dois ritornelos seguidos também dão salto.
- Até o J08 (saltos no agendador), a trilha só é oferecida quando o caminho
  é contíguo. Nas outras músicas a tela diz que a trilha ainda não está
  disponível e abre no modo livre. O J01 mede quantos hinos caem em cada
  caso.
- **Compassos `implicit`** não são só anacruse: hinos partem um compasso em
  dois na barra de repetição ou no fim de linha. Regra: compasso incompleto
  no início gruda no seguinte; o J01 mede os demais casos e aplica "metade
  final de um compasso partido gruda na metade inicial".

## O que já existe e será reaproveitado

| Peça | Onde |
| --- | --- |
| Três modos, escolha de mão, app toca a outra mão | `lib/practice/practice_controller.dart` (`PracticeMode`, `Hand.studentStaves`/`appStaves`) |
| Sessões puras | `lib/practice/practice_session.dart` (`WaitModeSession`, `RealtimeSession`), `lib/practice/rhythm_session.dart` |
| Loop A-B (hoje dá voltas sem parar) | `PracticeController.setLoop`, `ScoreAudioScheduler.setLoop`, `_setLoop` em `lib/main.dart` |
| Resumo por compasso | `lib/practice/practice_report.dart` (`PracticeReport`, `MeasureStats`) — hoje **não** há resumo no modo espera |
| Contagem inicial e metrônomo | `lib/audio/metronome.dart`, `ScoreAudioScheduler.play(countIn:)` |
| Configuração geral e por hino | `lib/settings/app_settings.dart`, `lib/settings/hymn_settings.dart` |
| Progresso por hino (última abertura, melhor nota) | `lib/library/hymn_progress.dart` |
| Tela da partitura e gaveta do celular | `lib/main.dart` (`_togglePractice` L679, `_endPractice` L732, `_buildOptionsDrawer` L1503), `lib/ui/phone_chrome.dart` |

## Passos

| Passo | Título | Depende de | Status |
| --- | --- | --- | --- |
| [J01](J01-caminho-e-trechos.md) | Caminho sem repetições e corte em trechos (Dart puro) | — | pendente |
| [J02](J02-avaliacao-da-etapa.md) | Avaliação da etapa e blocos de reforço (Dart puro) | — | pendente |
| [J03](J03-modelo-e-progresso.md) | Modelo da trilha, desbloqueio e progresso persistente | J01 | pendente |
| [J04](J04-passagem-unica.md) | `PracticeController`: passagem única de um intervalo, com resultado | J02 | pendente |
| [J05](J05-tela-da-etapa.md) | Tela: executar uma etapa (faixa, resumo, avançar) | J03, J04 | pendente |
| [J06](J06-gaveta-e-configuracao.md) | Tela: lista de etapas, pular, refazer e configuração de N | J05 | pendente |
| [J07](J07-fase-final-e-reforco.md) | Fase final e reforço | J05 | pendente |
| [J08](J08-saltos-no-caminho.md) | Saltos no caminho: músicas com casas e vários ritornelos | J04, J07 | pendente |
| [J09](J09-progresso-na-biblioteca.md) | Progresso da trilha na biblioteca | J03 | pendente |

Ordem sugerida: J01 e J02 (independentes) → J03 e J04 → J05 → J06, J07 e
J09 → J08. A trilha fica utilizável no fim do J05; o J08 só amplia o
conjunto de músicas.

## Fora de escopo da fase J

- Trilha **com** repetições (tocar as estrofes).
- Perfis, sincronização, exportação do progresso.
- Estrelas, pontos, conquistas.
- Porcentagem de aprovação e degraus configuráveis.
- Cortar trechos por frase musical em vez de contagem fixa.
