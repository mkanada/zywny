# L05 — `PracticeController`: passagem com sumiço e revelação

**Repo:** zywny · **Depende de:** J04, L02, L03 · **Decisão necessária:**
nenhuma

## Objetivo

Uma passagem única em tempo real (J04) que começa com um conjunto de
colunas escondidas, pisca a pausa quando o aluno acerta e **revela** a
coluna quando ele erra.

## Ler antes (só isto)

- [L00](L00-trilha-do-decorar.md): "Durante a passagem", "Aprovação".
- `lib/practice/practice_controller.dart`: construtor L41-L82, `_onVerdict`
  L433-L482, `_nearestEventId` L486, `stop` L282, `dispose` L547, e o
  intervalo de passagem única do J04.
- `lib/practice/practice_colors.dart`.
- `lib/memo/memo_columns.dart` (L01).
- A API de esconder (L02) e o `StandInController` (L03).
- `test/practice_controller_test.dart`.

## Contexto que você precisa

- O sumiço é **só visual**. A sessão (`RealtimeSession`), as janelas de
  tolerância e o `StageResult` não mudam: a passagem é avaliada como
  qualquer tempo real do J04.
- O `PracticeController` recebe as colunas escondidas prontas (o L01
  escolheu). Dentro dele é preciso ir de `eventId` → coluna: um veredito
  numa nota da coluna vale para a coluna inteira.
- Tabela do L00, por veredito, quando a coluna está escondida:

  | Veredito | Pausa | Notas |
  | --- | --- | --- |
  | `correct` | pisca `kPracticeCorrectColor` | continuam escondidas |
  | `early`, `late` | pisca `kPracticeOffBeatColor` | continuam escondidas |
  | `wrong` (coluna de `_nearestEventId`) | sai | reveladas, `kPracticeWrongColor` fixa |
  | `missed` | sai | reveladas, `kPracticeMissedColor` fixa |

- Uma coluna tem até duas notas e os vereditos chegam um por nota. A
  coluna é revelada no **primeiro** `wrong`/`missed`; a pausa pisca em
  verde só quando **todas** as notas da coluna deram `correct` (uma certa
  e uma perdida é coluna revelada).
- "Fixa até o fim da passagem": hoje os vereditos usam `highlight`
  (animação que solta). A coluna revelada usa cor fixa (`setColor`), que
  o fim da passagem limpa.
- `wrong` sem coluna por perto (`_nearestEventId` devolve `null`) não
  revela nada.
- **Limpeza**: `stop`, `finish`, fim do intervalo e `dispose` devolvem a
  partitura inteira (`clearHidden`, `clear` das pausas, cores fixas da
  revelação). Nenhuma nota pode ficar escondida depois de sair da etapa —
  é o equivalente visual da "nota presa" (risco 4 do README).
- A nota fantasma continua como está no tempo real.
- Cor nova: `kMemoRestColor` em `practice_colors.dart` — distinta de verde,
  azul (pendente), vermelho, âmbar, cinza e do laranja da fantasma. Um
  violeta serve; confira o contraste no fundo da página.

## O que fazer

1. Parâmetros opcionais no `PracticeController`: as colunas escondidas e o
   `StandInController`. Sem eles, nada muda (modo livre e trilha de estudo
   intactos).
2. Esconder e pôr as pausas em `start`; tabela de vereditos acima;
   limpeza.
3. `ValueListenable<int>` com o número de colunas reveladas (a faixa do
   L06 mostra "3 reveladas").
4. Testes em `test/practice_controller_test.dart`, com controladores
   falsos ou os reais sem página.

## Fora de escopo

- Prova às cegas (L07): lá não há pausa nem revelação.
- Mudar a avaliação, as janelas ou o `StageResult`.
- Sumiço no modo espera e no modo ritmo.

## Critérios de aceite

1. Teste: passagem com 4 colunas escondidas, tudo tocado no tempo → 4
   piscadas verdes na pausa, nenhuma nota revelada, resultado 100%.
2. Teste: tecla errada no instante de uma coluna escondida → coluna
   revelada em vermelho, pausa removida, e continua revelada depois de
   outras notas tocadas.
3. Teste: coluna escondida não tocada → revelada em cinza depois da
   janela (`missed`).
4. Teste: coluna de duas notas, uma `correct` e outra `missed` → revelada;
   as duas `correct` → pausa verde, escondida.
5. Teste: `early` numa coluna escondida → pausa âmbar, coluna escondida, e
   o resultado conta erro.
6. Teste: `stop` no meio, `finish` e `dispose` → nenhum id escondido,
   nenhuma pausa, nenhuma cor fixa sobrando.
7. Teste: sem os parâmetros novos, os testes existentes passam sem
   mudança.
8. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
