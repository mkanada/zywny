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

(vazio)
