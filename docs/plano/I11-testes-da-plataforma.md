# I11 — Testes da plataforma: cobertura, aluno simulado e cursos quebrados

**Repo:** zywny · **Depende de:** I10 · **Decisão necessária:** não

## Objetivo

As regras 2, 3 e 4 do I00 viram testes que rodam no `just test` e impedem
a plataforma de andar sem o curso inicial (e vice-versa):

- **cobertura**: toda marca, todo tipo e toda chave do vocabulário
  aparecem no curso inicial;
- **aluno simulado**: todo exercício do curso inicial aprova tocando
  certo, reprova errando acima do limite e, onde há `speed`, reprova
  devagar;
- **cursos quebrados**: cada erro que o professor pode cometer tem uma
  fixture com a mensagem exata, arquivo e linha.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): "O curso inicial como teste da
  plataforma".
- `lib/course/format/vocabulary.dart` (I01, a fonte das tabelas).
- `test/support/simulated_student.dart` (I03, I07, I08).
- `test/course_validator_test.dart` e `test/fixtures/cursos/` (I01).

## Contexto que você precisa

- Os testes leem o curso pela **pasta** `assets/cursos/iniciacao/` (com a
  `DirectoryCourseFiles` do I01) — mesmo conteúdo do asset, sem precisar
  do `rootBundle`.
- Exercício com partitura precisa da `libverovio.so` para renderizar. Sem
  ela, o teste é **pulado** (como `test/vsb_render_test.dart`), não
  falha — mas registre no fim do `just test` quantos foram pulados, para
  ninguém achar que passou.
- Semente fixa por exercício (derivada do id: `id.hashCode` não serve — muda
  entre execuções na Web/VM? use um hash estável, ex. FNV-1a do id) para
  que uma falha seja reproduzível.

## O que fazer

1. **`test/course_coverage_test.dart`** — monta, a partir do
   `vocabulary.dart`, o conjunto de (marca, chave) e (tipo, chave) e de
   chaves de `pass`, e de **valores** enumerados que mudam comportamento
   (`clef`: treble/bass/grand; `mode`: wait/realtime; `octave`: any/exact;
   `hand`: right/left/both; `accidentals`; `only`); percorre o curso
   inicial e falha listando o que nunca apareceu ("`hand: left` não aparece
   no curso inicial"). Se um valor não tiver lugar didático no curso, a
   exceção é **explícita** no teste, com o motivo num comentário — e o
   usuário é avisado nas notas.
2. **`test/course_simulated_student_test.dart`** — para cada
   `ExerciseMark` do curso, três casos (gerados, um `test` por exercício e
   caso, nome = `lição/exercício: caso`):
   - certo → `exercisePassed` depois de `rounds` rodadas;
   - errado acima do limite (o aluno simulado calcula quantos erros
     derrubam abaixo de `accuracy`) → reprova a rodada;
   - onde `speed` vale: a 50% do pedido → reprova com o motivo de
     andamento; onde `time-limit` vale: deixar estourar todas → reprova.
3. **Cursos quebrados** — complete `test/fixtures/cursos/` até cobrir, no
   mínimo: marca desconhecida (com sugestão), chave desconhecida (com
   sugestão), YAML inválido, front matter sem `---`, `format: 2`, arquivo
   de mídia ausente, imagem remota, `link` `http://`, `requires` circular,
   `requires` de lição posterior, id repetido (lição e exercício), lição
   listada sem arquivo, `abc` e `file` juntos, `speed` em modo espera,
   nota inválida (`H4`), faixa invertida, `answer` fora das `options`,
   ABC que não renderiza (este depende do `--render` do I12 e da
   `libverovio.so`; pule se faltar). Cada pasta tem `esperado.txt`.
4. Um teste que lê `docs/licoes/formato-v1.md` e confere que **toda**
   mensagem de erro listada em "Erros comuns" existe nas fixtures (a
   especificação não promete mensagem que o validador não dá).

## Fora de escopo

Teste de tela no aparelho (I13). Desempenho.

## Critérios de aceite

1. Os três arquivos de teste passam; o número de testes gerados pelo
   aluno simulado e os pulados, nas notas.
2. Prova de que os testes mordem: (a) apagar o único `hand: left` do curso
   faz a cobertura falhar com a mensagem certa; (b) trocar o limiar do
   `PassCheck` para `>` faz o aluno simulado falhar num exercício de
   `accuracy: 100`; (c) mudar uma mensagem do validador faz a fixture
   falhar. Desfaça e registre.
3. `just analyze` e `just test` limpos.

## Notas de execução

Concluído em 2026-10-06 (código; sem manual — o passo não pede aparelho).
`just analyze` limpo; `just test` limpo (640 passando, 5 pulados, com a
`libverovio.so` real — antes 571/4; +67 do aluno simulado, +1 da cobertura,
+1 do "Erros comuns", +1 pulado do `erro-render`).

**O que existe**

- `test/course_coverage_test.dart` — lê `assets/cursos/iniciacao/` pela
  `DirectoryCourseFiles` e confere, a partir do `vocabulary.dart` (fonte
  única), marcas, tipos, (marca,chave), (tipo,chave), chaves de `pass` e do
  sorteio (`random`/`count`/`only`), valores (`clef` treble/bass/grand;
  `mode` wait/realtime; `octave` any/exact; `hand` right/left/both;
  `accidentals` none/sharps/flats/mixed; `only` lines/spaces; as 10 figuras;
  `time` 4/4–3/4–2/4–6/8–C; `key` G–F–D–Bb; chaves de `course.md`/lição;
  imagem e link markdown). O que conta é a chave **escrita** no YAML (via
  `scanLessonFile` + `yaml`), não o padrão do modelo.
- `test/course_simulated_student_test.dart` — 67 testes gerados (28
  exercícios: 28× certo + 28× errado + 6× andamento + 5× tempo; nomes
  `lição/exercício: caso`). Semente FNV-1a do id do exercício + índice da
  rodada (`id.hashCode` muda entre VM/Web). Certo roda `pass.rounds`
  vezes a 100%; errado usa `wrongEvery: 2` (~50%, abaixo de qualquer
  `accuracy` 80–90) e `1` com 1 pergunta; andamento toca certo a 50% e
  espera "faltou andamento: 50% de N%"; tempo estoura todas (`late: true`,
  0%). Partitura (`play-notes`, `rhythm`, `play-score`) pula sem a
  `libverovio.so`; pergunta nunca pula. Com a `.so` real: 67 passando,
  0 pulados.
- Fixtures: as 13 pastas do I01 já cobriam 18 dos 19 erros (marca/chave
  desconhecida com sugestão, YAML, sem front, `format: 2`, mídia ausente,
  imagem remota, `http://`, `requires` circular/posterior, id repetido
  lição+exercício, lição sem arquivo, `abc`+`file`, `speed` em espera, `H4`,
  faixa invertida, `answer` fora). Nova `test/fixtures/cursos/erro-render/`
  (ABC completo sem notas: passa no `readCourse`, falha no `--render` com
  MIDI vazio) com `esperado.txt` no formato do I12; pulada no
  `course_validator_test` até o `--render` existir.
- `test/course_validator_test.dart`: + teste "toda mensagem de Erros comuns
  existe nas fixtures" (lê `docs/licoes/formato-v1.md` §11, 15 mensagens,
  cada uma com trecho distintivo presente na especificação e em algum
  `esperado.txt`; se a seção ganhar mensagem, o `hasLength` quebra e força
  atualizar).

**Exceções explícitas (aviso ao usuário)**: só os tons. O curso usa G, F, D
e Bb (um sustenido, um bemol, dois sustenidos, dois bemóis); os outros 24
tons do formato (Cb, G#m, …) não têm lugar didático num curso para quem
nunca leu partitura — o teste exige só esses 4, com o motivo em comentário.
Todo o resto do vocabulário aparece sem exceção.

**Prova de mordida (feita e desfeita)**

- (a) `sed hand: left → right` na lição 10: cobertura falha com
  "`hand: left` não aparece no curso inicial". Desfeito.
- (b) `PassCheck` `>=` → `>`: `pass_check_test` falha em 3 testes de
  `accuracy: 100` (ex.: "100 exige tudo": 12/12 deixa de passar); sintético
  de aluno simulado com `accuracy: 100` e 1/1 também falha
  (`exercisePassed` falso). No curso (só 80–90) o simulado seguiria
  passando — por isso a prova usa `accuracy: 100`. Desfeito.
- (c) `lesson_scanner` "não foi fechada" → "NAO FECHADA TESTE":
  `erro-yaml` falha mostrando o diff na linha 13. Desfeito.
