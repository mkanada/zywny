# E03 — `listen-note`: especificação do formato e aceite manual

**Repo:** zywny · **Depende de:** E02 · **Decisão necessária:** não

## Objetivo

O professor encontra o tipo `listen-note` na especificação do formato, e o
exercício funciona de verdade no Linux, no celular e na Web.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md) e [E01](E01-formato-e-rodada.md)
  (a tabela de chaves e as regras de "só vale com").
- `docs/licoes/formato-v1.md`: L224–L330 (a seção 6 até o `name-note`) e
  L425–L442 (a seção 7, `pass`).
- A memória "Instalar no celular pelo Wi-Fi", se o celular for usado
  (build arm64, `adb` em `~/Android/Sdk`).

## O que fazer

### 1. `docs/licoes/formato-v1.md`

a. Na tabela de tipos (perto da L231), acrescente depois da linha do
`choice`:

```markdown
| `listen-note` | ouve uma nota e toca a tecla (ou escolhe o nome) | teclado MIDI, ou só a tela com `input: buttons` |
```

b. Na tabela do `pass` (L438), acrescente `` `listen-note` `` à última
coluna do `time-limit`.

c. Na tabela do sorteio (L255), troque "12 (10 no `find-key`)" por "12 (10
no `find-key` e no `listen-note`)".

d. Depois da seção `### choice` (e antes de `### Figuras`), acrescente:

````markdown
### `listen-note`

O zywny toca a nota (antes, a de referência, se houver) e o aluno descobre
qual foi. A nota toca sozinha a cada pergunta; **Ouvir de novo** (ou a
tecla espaço) repete quantas vezes o aluno quiser, sem perder ponto.

```zywny-exercise
id: ouvir-achar
type: listen-note
title: Ouça e ache a tecla
notes: {random: C4-B4, count: 8}
reference: C4
input: keyboard
octave: any
```

| Chave | Valor | Padrão |
| --- | --- | --- |
| `notes` | lista ou sorteio (seção "Notas") | — (obrigatória) |
| `reference` | uma nota tocada antes de cada pergunta | nenhuma |
| `input` | `keyboard` (toca a tecla) ou `buttons` (escolhe o nome) | `keyboard` |
| `octave` | `any` ou `exact`, como no `find-key`; só com `input: keyboard` | `any` |
| `key` | tom do sorteio; só com `input: keyboard` | Dó maior |
| `choices` | letras dos botões, como no `name-note`; só com `input: buttons` | `[C, D, E, F, G, A, B]` |

Sem `reference`, o aluno precisa reconhecer a nota sozinha, o que pouca
gente consegue. Use uma referência no começo. Com `input: buttons`, as
notas são naturais e cada uma precisa de um botão, como no `name-note`.
Como vale o acerto de primeira, tocar teclas para procurar conta como erro:
uma `accuracy` mais baixa (60) costuma servir.
````

Não acrescente nada à seção "11. Erros comuns" (um teste confere aquela
lista).

### 2. Aceite manual

Faça e anote em "Notas de execução" o que viu em cada um:

1. **Linux, som do app, teclado MIDI conectado**: `just run`, abra o curso
   inicial, lição 1, "Ouça e ache a tecla". O dó central soa, depois a
   nota. "Ouvir de novo" e a barra de espaço repetem. A tecla certa
   aprova; a errada mostra "Você tocou …".
2. **Linux, saída pelo teclado MIDI** (configurações → saída de som =
   teclado): a nota sai pelo teclado.
3. **Linux, sem teclado**: "Ouça e diga o nome" funciona só com os botões
   e com as teclas C, D e E do computador.
4. **Celular** (Android, Wi-Fi): o mesmo do item 1, em pé e deitado. O
   botão "Ouvir de novo" cabe sem rolar.
5. **Web** (`just web-smoke` e depois o navegador): o exercício de botões
   toca. Na Web, o som só começa depois de um toque, porque é regra do
   navegador. Anote se a primeira nota se perde e, se perder, registre como
   pendência (não corrija neste passo).

Se o usuário estiver presente, peça a ele os itens 1, 2 e 4 (o teclado
real é dele). Senão, deixe-os como **aceite manual pendente** na tabela do
E00.

### 3. Status

Marque E01–E03 conforme o resultado na tabela do
[E00](E00-exercicios-de-ouvido.md) e na tabela de passos do
[README](README.md).

## Critérios de aceite

1. `flutter test test/course_validator_test.dart` passa (a seção 11 não
   mudou).
2. Os cinco itens do aceite manual anotados (feitos ou pendentes, com o
   motivo).

## Notas de execução

Feito em 2026-10-13, sem commit. Critérios 1 e 2 passam. O aceite manual
ficou parcialmente com o usuário: os itens 1, 2 e 4 dependem de ouvido e do
celular dele.

**Resultados dos critérios de aceite:**

1. `flutter test test/course_validator_test.dart`: "All tests passed!" (20
   testes; a seção 11 não mudou).
2. Os cinco itens estão anotados abaixo, cada um feito ou pendente com o
   motivo.

**Exemplos da seção `### listen-note` (validados fora do repo):** um curso
de rascunho com o exemplo da doc (`input: keyboard`, com `reference`) e um
com `input: buttons` passou em `dart run tool/zywny_course.dart validate`
(saída 0). Um `octave` com `input: buttons` foi recusado com "`octave` só
vale com `input: keyboard`", então o validador leu a marca.

**Aceite manual:**

1. **Linux, som do app, teclado MIDI:** pendente com o usuário. Daqui não dá
   para ouvir o som nem tocar o teclado.
2. **Linux, saída pelo teclado MIDI:** pendente com o usuário, pelo mesmo
   motivo.
3. **Linux, sem teclado:** feito em parte. `_keyToButton`
   (`lib/course/ui/question_body.dart`) manda C, D e E para os botões. Um
   teste de widget temporário apertou essas três teclas num `listen-note`
   com `input: buttons` e o exercício foi aprovado. A cópia do teste foi
   apagada. A janela do Linux não foi aberta; isso fica com o usuário.
4. **Celular:** pendente, e o app não está no aparelho. O `adb` vê o
   aparelho (192.168.0.192:42195), mas `pm list packages br.com.kanada` vem
   vazio, como em 13/10. Não instalei nada: reinstalar e restaurar é decisão
   do usuário (ver as notas do E02).
5. **Web:** `just web-smoke` passou (build release e 22 checagens ok, com
   MIDI, tutorial, biblioteca no IndexedDB, som do Play, monitor e saída
   MIDI; `exit=0`). O smoke não toca o `listen-note`. Se o botão de nota soa
   no navegador e se a primeira nota se perde, precisa de ouvido: fica
   registrado como pendência, sem correção neste passo.

**Desvios do texto:** nenhum. As alterações da doc seguiram o item 1 da
especificação, e o padrão de `count` (10) e a regra de `time-limit` foram
conferidos no código antes de escrever.
