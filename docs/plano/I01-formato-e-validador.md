# I01 — Especificação v1, leitor e validador de curso (Dart puro)

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** não
(D-LIC-MARCAS, D-LIC-IDIOMA, D-LIC-NOTACAO decididas no I00)

## Objetivo

Três coisas que andam juntas:

1. `docs/licoes/formato-v1.md`: a especificação **para professores**, em
   português, com o vocabulário em inglês do I00 — é o que alguém de fora
   lê para escrever um curso (regra 5 do I00).
2. Um **leitor** que recebe os arquivos de uma pasta de curso e devolve o
   curso tipado (`Course` → `Lesson` → blocos de texto e marcas →
   `ExerciseSpec`), sem Flutter, sem disco, sem rede.
3. Um **validador** que junta todos os problemas, cada um com arquivo,
   linha e mensagem em português, e um comando de linha
   (`dart run tool/zywny_course.dart validate <pasta>`).

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): "O formato (v1)" inteiro (é o
  contrato deste passo) e "O curso inicial como teste da plataforma", regra 4.
- `lib/library/library_package.dart` L9–L23 e L115–L199: o estilo das
  mensagens (`LibraryFormatException`, português, aspas no nome do campo,
  "atualize o zywny").

## Contexto que você precisa

- `yaml` já está no `pubspec.lock` como transitivo: torne-o **direto** no
  `pubspec.yaml`. Ele dá `YamlNode.span.start.line` (base 0) — é assim que
  a linha do erro sai certa dentro de uma marca.
- O pacote `markdown` (dart-lang) **não** guarda número de linha no AST.
  Por isso o leitor corta o arquivo **antes** do markdown: front matter,
  depois uma varredura linha a linha que separa trechos de texto e marcas,
  guardando a linha de abertura de cada marca. O texto vai inteiro para o
  I05 desenhar; o leitor só precisa dele para os avisos (HTML, imagem
  remota, imagem ausente).
- Cercas: rastreie também as cercas comuns (` ``` ` e ` ```` ` com ou sem
  linguagem) para que um ` ```zywny-… ` dentro de um bloco de código de
  exemplo **não** vire marca. A marca abre só com ` ```zywny-nome ` exato na
  coluna 0 (espaços no fim tolerados) e fecha na próxima linha ` ``` `.
  Marca sem fechamento é erro na linha da abertura.
- YAML 1.2 do pacote `yaml`: `yes`/`no`/`on`/`off` são texto, não booleano.
  O validador exige `true`/`false` onde o tipo é booleano, e aceita número
  ou texto em `version` (sempre guardado como texto).
- Tudo aqui tem de rodar **fora do Flutter** (o comando de linha usa
  `dart run`): nada de `package:flutter/…` em `lib/course/format/`. Use
  `package:meta` para `@immutable`.

## O que fazer

1. **`lib/course/format/course_files.dart`** — a fonte dos arquivos:
   `abstract class CourseFiles { Future<List<String>> list(); Future<Uint8List> read(String path); String get label; }`
   (caminhos relativos com `/`). Implementações neste passo:
   `MemoryCourseFiles` (testes) e `ZipCourseFiles` (bytes de um zip, com
   o `archive` — o I04 usa). A de diretório (`dart:io`) fica em
   `lib/course/format/directory_course_files.dart`, importada só pelo
   comando de linha e pelo nativo (I12); a de assets, no I10.
2. **`lib/course/format/note_name.dart`** — `Pitch.parse('F#4')` →
   `{step: F, alter: 1, octave: 4, midi: 66}`; faixas `C4-G5`; `NoteRange`
   inclusivo; erro legível ("`H4` não é uma nota: use de C a B, com # ou b,
   e a oitava, como C4").
3. **`lib/course/format/vocabulary.dart`** — as **tabelas** do I00 como
   dados: para cada marca e cada `type`, as chaves permitidas, obrigatórias,
   o tipo de valor e os valores aceitos; as chaves de `pass` e em que tipos
   cada uma vale. O validador lê daqui e o teste de cobertura (I11) também:
   uma fonte só.
4. **`lib/course/format/course_model.dart`** — o modelo tipado e imutável:
   `Course` (front matter + corpo + `List<Lesson>` na ordem de `lessons`),
   `Lesson` (`id`, `title`, `requires`, `fileName`, `List<LessonBlock>`),
   `LessonBlock` = `TextBlock(markdown, line)` | `ScoreMark` |
   `KeyboardMark` | `AudioMark` | `VideoMark` | `ExerciseMark(ExerciseSpec)`.
   `ExerciseSpec` com `id`, `type` (enum), `title`, parâmetros tipados por
   tipo (uma classe por tipo, `sealed`) e `PassCriteria(accuracy, rounds,
   speed, timeLimit)` com os padrões do I00.
5. **`lib/course/format/course_reader.dart`** —
   `Future<CourseReadResult> readCourse(CourseFiles files)` →
   `{Course? course, List<CourseIssue> issues}`. `CourseIssue(severity:
   error|warning, file, line, message)`; `course` é `null` se houver erro.
   **Junte todos os erros**, não pare no primeiro (o professor corrige tudo
   de uma vez); só desista de um arquivo cujo front matter não se lê.
6. Validações (cada uma com teste e mensagem):
   - `course.md` existe; front matter entre `---` na linha 1; `format`
     presente, inteiro, ≤ 1 (maior: "Este curso pede uma versão mais nova do
     zywny."); `id`, `title`, `author`, `version`, `lessons` obrigatórios.
   - Chave desconhecida em qualquer front matter ou marca: erro, com
     sugestão quando houver uma chave parecida (distância de edição ≤ 2:
     "chave desconhecida `acuracy` — você quis dizer `accuracy`?").
   - Toda lição de `lessons` tem um arquivo em `lessons/*.md` com aquele
     `id`; arquivo em `lessons/` fora da lista: aviso. Id repetido (lição ou
     exercício no curso inteiro): erro nas duas linhas.
   - `requires`: só ids de lições do curso, sem ciclo (erro com o ciclo
     escrito: "a → b → a"), e só lições **anteriores** na ordem de
     `lessons` (a ordem é a da tela; depender de uma lição posterior é erro).
   - Marca desconhecida (` ```zywny-exercicio `): erro com sugestão; YAML
     inválido: erro na linha do YAML (linha da marca + linha do erro).
   - `file`, `image`, imagens markdown: o arquivo existe na pasta, com a
     extensão permitida; caminho com `..`, absoluto ou `http(s)://`: erro.
   - `link` de vídeo e links do texto: só `https://`.
   - Notas, faixas, `key`, `time`, `figures`, `measures` (`"1-8"`): formato
     e coerência (`from` ≤ `to`; faixa do sorteio com notas suficientes para
     `only`; `name-note` só com naturais; `answer` é uma das `options`;
     `abc` **ou** `file`, nunca os dois; `abc` com `X:` proíbe `clef`/`key`/
     `time`).
   - `pass`: valores no intervalo (`accuracy` 1–100, `rounds` 1–10,
     `speed` 25–200, `time-limit` 1–120) e só nos tipos em que valem
     (`speed` em `play-score` com `mode: wait` é erro: "o modo espera não tem
     andamento").
   - HTML no texto: **aviso** ("HTML não é interpretado e aparece como
     texto"). Imagem remota: erro.
   - O ABC renderiza? **Não** neste passo (precisa do Verovio): é o
     `--render` do I12.
7. **`tool/zywny_course.dart`** — `validate <pasta>`: imprime
   `arquivo:linha: erro|aviso: mensagem`, um por linha, ordenados, e sai com
   código 1 se houver erro. É o que o `just pacote-curso` (I04) e o
   professor usam. Receita `just curso-validar *ARGS` (repassa os
   argumentos: o I12 acrescenta `--render`).
8. **`docs/licoes/formato-v1.md`** — para professores: o que é um curso, a
   pasta, o front matter, as regras do markdown, **uma seção por marca e por
   tipo** com um exemplo completo e as chaves (obrigatória, padrão, valores),
   `pass`, notas e faixas, e "Erros comuns" com as mensagens do validador.
   Sem nada de código do app. Ligue do I00.
9. **Fixtures** em `test/fixtures/cursos/`: um curso mínimo válido
   (`minimo/`, duas lições, um exercício `play-notes`) e um curso quebrado
   por erro da lista do passo 6, cada um com `esperado.txt` (a saída exata
   do validador). O I11 completa a lista.

## Fora de escopo

Desenhar a lição (I05), gerar partitura (I02), rodar exercício (I03),
pacote (I04), renderizar o ABC para validar (I12).

## Critérios de aceite

1. `test/course_reader_test.dart`: o curso `minimo/` lido com o modelo
   esperado; uma marca dentro de um bloco ` ```` ` de exemplo não vira marca.
2. `test/course_validator_test.dart`: para cada pasta quebrada, a saída do
   validador é **igual** ao `esperado.txt` (arquivo, linha, mensagem).
3. `dart run tool/zywny_course.dart validate test/fixtures/cursos/minimo`
   sai com 0 e nada impresso; numa quebrada, código 1 e as linhas esperadas.
4. `lib/course/format/` não importa Flutter (um teste que lê os imports, ou
   o próprio `dart run` passando).
5. Alguém que não leu o código consegue, só com `formato-v1.md`, dizer como
   se escreve um exercício `play-notes` de clave de fá com três rodadas (o
   executor confere relendo a especificação de cabeça fria e anota o que
   faltou).
6. `just analyze` e `just test` limpos.

## Notas de execução

(vazio)
