# E00 — Exercícios de ouvido

**Fase E** (de *escutar*). Origem: [Z00](Z00-planos-futuros.md), "Exercícios
de ouvido". O zywny toca uma nota (ou duas) e o aluno descobre qual foi:
tocando a tecla no teclado MIDI ou escolhendo o nome num botão.

Quem executa um passo E lê o [README](README.md) (seções **Como executar um
passo** e **Convenções**), este arquivo e o arquivo do passo. Nada mais.

## O que já existe (levantado em 2026-10-13)

Quase tudo. A fase só **liga** peças que já funcionam:

| Peça | Onde | Para quê |
| --- | --- | --- |
| Tipos de exercício do curso | `ExerciseType` em `packages/zywny_course_format/lib/course_model.dart:85` | o tipo novo `listen-note` entra aqui |
| Leitura das chaves de cada tipo | `_buildExercise` em `packages/zywny_course_format/lib/mark_parser.dart:364` | monta o `ListenNoteSpec` |
| Chaves aceitas por tipo | `_typeKeys` em `packages/zywny_course_format/lib/vocabulary.dart:248` | validação e mensagens de erro |
| Gerar a rodada | `exerciseKinds` e `notesOf` em `lib/course/exercise/exercise_kind.dart:27` e `:54` | sorteia as notas (respeita `key`) |
| Pergunta e resposta | `Question`, `QuestionRound` em `lib/course/exercise/exercise_round.dart:75–128` | resposta por tecla (`expectedPitch`, `anyOctave`) ou botão (`answers`, `correct`) |
| Conferência | `QuestionSession` em `lib/course/exercise/question_session.dart` | acerto de primeira, `time-limit`, revelação |
| Tela de perguntas | `QuestionBody` em `lib/course/ui/question_body.dart` | entrada MIDI, botões, atalhos de teclado do computador |
| Tocar um som | `SoundEngine.schedule` / `allNotesOff` em `packages/zywny_audio/lib/sound_engine.dart` | toca a nota da pergunta |
| Abrir o som na tela do curso | `CourseScreenDeps.ensureEngine` em `lib/course/ui/course_flow.dart:42` | já respeita a saída escolhida (som do app ou teclado MIDI) |
| Motor de som falso para teste | `FakeSoundEngine` em `test/support/practice_fakes.dart:8` | grava tudo que foi agendado em `scheduled` |
| Aluno simulado | `answerQuestions` em `test/support/simulated_student.dart` | já responde qualquer `QuestionRound` |

O que **falta**: um tipo de exercício que toque um som a cada pergunta, o
botão "Ouvir de novo" e o exercício no curso inicial.

## Decisões (D-OUV)

Recomendações deste plano, tomadas em 2026-10-13. O usuário pode trocar
qualquer uma **antes** do E01. Depois de começar, não decida de novo.

| Id | Pergunta | Decisão |
| --- | --- | --- |
| D-OUV-LUGAR | Tipo de exercício do curso, ou fase da trilha de estudo (J)? | **Tipo de exercício do curso** (`listen-note`). Ele reaproveita a sessão, a tela, o progresso e o aluno simulado. Uma trilha J de ouvido fica para depois. |
| D-OUV-REF | Nota de referência antes da nota da pergunta? | **Opcional**, pela chave `reference: C4`. Sem referência, o exercício pede ouvido absoluto, que pouca gente tem. O curso inicial sempre usa `reference`. |
| D-OUV-ENTRADA | Como o aluno responde? | `input: keyboard` (padrão) toca a tecla. `input: buttons` escolhe o nome (só notas naturais, como o `name-note`), e funciona sem teclado e na Web. |
| D-OUV-ERRO | Tocar teclas para procurar conta como erro? | **Sim**, a mesma regra do `find-key`: só vale o acerto de primeira. O curso usa `accuracy` baixa (60). |
| D-OUV-REPETIR | Quantas vezes dá para ouvir? | A nota toca sozinha quando a pergunta aparece. **"Ouvir de novo"** (botão, espaço ou R) não tem limite e não tira ponto. |
| D-OUV-SAIDA | Por onde sai o som? | Pela saída escolhida no app (`ensureEngine`). Sem motor, aparece um aviso e o exercício continua (dá para responder, mas sem som). |
| D-OUV-INTERVALO | Intervalos e acordes? | Intervalos no E04 (`listen-interval`, por botões). Acordes ficam fora da fase. |

## O formato novo (resumo; os detalhes estão nos passos)

````markdown
```zywny-exercise
id: l1-ouvir-achar
type: listen-note
title: Ouça e ache a tecla
notes: {random: C4-B4, count: 8}
reference: C4
input: keyboard
octave: any
pass: {accuracy: 60}
```
````

| Chave | Valor | Padrão | Vale com |
| --- | --- | --- | --- |
| `notes` | lista fixa ou sorteio, como no `find-key` | — (obrigatória) | sempre |
| `reference` | uma nota (`C4`) | nenhuma | sempre |
| `input` | `keyboard` ou `buttons` | `keyboard` | sempre |
| `octave` | `any` ou `exact` | `any` | só `input: keyboard` |
| `key` | tom (`G`, `F`…), para o sorteio | C | só `input: keyboard` |
| `choices` | letras dos botões | `[C, D, E, F, G, A, B]` | só `input: buttons` |

## Passos

| Passo | Título | Depende de | Status |
| --- | --- | --- | --- |
| [E01](E01-formato-e-rodada.md) | `listen-note`: formato, rodada (Dart puro) e curso inicial | — | concluído |
| [E02](E02-som-e-tela.md) | `listen-note`: tocar o som e a tela da pergunta | E01 | feito, sem commit (`just telas` pendente) |
| [E03](E03-aceite.md) | `listen-note`: especificação do formato e aceite manual | E02 | feito, sem commit (aceite manual pendente: itens 1, 2 e 4 com o usuário; 3 e 5 em parte) |
| [E04](E04-intervalos.md) | `listen-interval`: ouvir e nomear intervalos | E03 | feito, sem commit (aceite manual pendente: lições 8 e 10, com o usuário) |
| [E05](E05-mudanca-e-frase.md) | Ouvido na leitura: a frase que soa e a mudança sorteada (Dart puro) | E04 | feito, sem commit (sem tela; 11a e 11b não têm acidente, ver notas) |
| [E06](E06-listen-score-formato.md) | `listen-score`: formato, rodada e curso inicial | E05 | pendente |
| [E07](E07-listen-score-tela.md) | `listen-score`: a tela (partitura por pergunta, som e revelação) | E06 | feito, sem commit (aceite manual pendente: itens 3 e 4, com o usuário) |
| [E08](E08-ouvido-no-treino.md) | Ouvido no treino de leitura: depois de cada leitura e "só ouvido" | E07 | feito, sem commit (aceite manual pendente: itens 2 e 3, com o usuário) |
| [E09](E09-ditado-com-ritmo.md) | Ditado com o ritmo dado (`answer: dictation`) | E07 | feito, sem commit (aceite manual pendente: lição 3, com o usuário) |
| [E10](E10-tocar-na-nota.md) | Responder tocando na nota da partitura (`answer: note`) | E07 | feito, sem commit (aceite manual pendente: itens 3 e 4, no celular, com o usuário) |

## Segunda parte: ouvido junto com a leitura (E05–E10)

Proposta de 2026-10-13, aceita pelo usuário no mesmo dia. **A mesma
partitura serve para ler e para ouvir.** O zywny gera uma partitura com o
gerador do treino de leitura à primeira vista (`generateSight`, em
`lib/sight_reading/`), mostra a partitura e toca uma versão dela que pode
ter **uma** diferença: uma nota em outra altura, um ritmo trocado ou um
acidente da armadura esquecido. O aluno diz onde está a diferença. A
partitura escrita é a referência: ninguém precisa de ouvido absoluto.

O que muda para o aluno:

- **No treino de leitura**, depois de cada partitura tocada, vem uma
  pergunta de ouvido sobre ela: "O zywny toca o que você leu, com uma
  diferença. Em que compasso?". Há também um modo **só ouvido**, que
  funciona sem teclado MIDI.
- **No curso**, um tipo novo, `listen-score`, usa os mesmos passos do treino
  (`step: 4c`) para montar as perguntas.

O que já existe e é reaproveitado:

| Peça | Onde | Para quê |
| --- | --- | --- |
| Gerador da leitura | `generateSight` em `lib/sight_reading/sight_generator.dart:63` | as notas, em graus, por pauta e compasso |
| Os 80 passos | `sightSteps` e `sightStep` em `lib/sight_reading/sight_steps.dart:81` e `:549` | figuras, padrões, tom e andamento de cada passo |
| A partitura | `sightScoreXml` em `lib/sight_reading/sight_score.dart:17` | MusicXML com as duas pautas |
| Pergunta com partitura | `QuestionRound.scoreBytes`, `Question.highlightId` em `lib/course/exercise/exercise_round.dart` | o `name-note` já mostra partitura e destaca nota |
| Ids que o Verovio preserva | `roundNoteId` em `lib/course/score/round_score.dart:24` (`<note id="zn1">`) | destacar a nota que mudou |
| Som da pergunta e "Ouvir de novo" | `playCues` em `lib/course/exercise/cue_player.dart`, `_playCurrent` em `lib/course/ui/question_body.dart:141` | o E02 |
| Origem das rodadas | `ExerciseSource` em `lib/course/ui/exercise_source.dart:15` | o treino de leitura já é uma origem (`SightReadingSource`) |
| Toque numa nota | `ScoreView.onElementTap` em `score_bridge/lib/src/score_view.dart:362` | E10 |

### Decisões (D-LEI)

| Id | Pergunta | Decisão |
| --- | --- | --- |
| D-LEI-ONDE | No treino, o ouvido entra depois de cada leitura ou num modo separado? | **Depois de cada leitura**, ligado por padrão, com opção de desligar. Mais um modo **só ouvido**, sem teclado. (Usuário, 2026-10-13.) |
| D-LEI-PROGRESSO | A pergunta de ouvido conta para subir de passo na leitura? | **Não.** O ouvido tem a contagem própria (acertos de primeira no passo). A leitura continua sendo a régua. (Usuário, 2026-10-13.) |
| D-LEI-TAREFA | Primeira tarefa | **"Onde mudou?"**, respondida pelo compasso (botões 1 a 4). "Igual ou diferente?" só no curso, nas primeiras lições. (Usuário, 2026-10-13.) |
| D-LEI-TONICA | Tocar o acorde da tônica antes da frase? | **Sim.** (Usuário, 2026-10-13.) |
| D-LEI-DITADO | Ditado com o ritmo dado: agora ou depois da 1.0? | O passo (E09) está escrito; executar **depois do E08**. O usuário pode adiá-lo para depois da 1.0. |
| D-LEI-ANDAMENTO | Em que andamento a frase soa? | O do passo, mas **nunca abaixo de 72**: a semibreve do 1a duraria 8 s a 30 bpm (hoje, a 60 bpm, dura 4 s). O curso pode trocar com `bpm`. |
| D-LEI-MUDANCA | Quão grande é a mudança de altura? | Até o nível 6, **2 ou 3 graus**; do 7 em diante, **1 ou 2**. A **primeira nota** da frase nunca muda (é a âncora, junto com o acorde). |
| D-LEI-SOOUVIDO | Progresso do modo só ouvido | Os mesmos 80 passos, com **progresso próprio**. Uma rodada tem 5 perguntas; é limpa com 4 ou mais de primeira; 3 limpas sobem um passo, como na leitura. |
| D-LEI-NOTA | Quando a resposta passa do compasso para a nota (E10)? | No curso, quando o autor pedir (`answer: note`). No modo só ouvido, **do nível 7 em diante**. Depois de cada leitura, continua o compasso. |

As decisões D-LEI-ANDAMENTO, D-LEI-MUDANCA, D-LEI-SOOUVIDO e D-LEI-NOTA são
recomendações deste plano. O usuário pode trocar qualquer uma antes do
passo que a usa.

### Ordem

E05 → E06 → E07 → E08. E09 e E10 dependem só do E07 e podem ir em
qualquer ordem depois dele.

## Fora da fase E

- Acordes (maior, menor…): um `listen-chord` no molde do E04, depois.
- Ditado de melodia **sem** o ritmo dado (o E09 dá o ritmo).
- `listen-score` com uma partitura do autor (`abc` ou `file`) em vez de um
  passo gerado: mudar uma partitura qualquer pede ler o MusicXML em notas.
- Trilha de estudo (J) de ouvido.
- Respeitar o TRANSPOSE do teclado (fase Q) no som da pergunta: o som sai
  na altura escrita.
